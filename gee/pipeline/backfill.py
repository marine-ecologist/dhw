"""
backfill.py — Process the full OISST record (1981–present)
==========================================================
Handles ~16,000+ days by:
  - Batching export tasks to stay under GEE's ~3,000 task queue limit
  - Writing summary stats to JSONL locally, then bulk-loading to BigQuery
  - Supporting resume from where it left off if interrupted
  - Processing year-by-year with progress tracking

Usage:
    # Full record
    python backfill.py --start 1981-09-01 --end 2026-02-10

    # Single year
    python backfill.py --start 2024-01-01 --end 2024-12-31

    # Resume after interruption (reads progress file)
    python backfill.py --start 1981-09-01 --end 2026-02-10 --resume

    # Export only (skip summary stats — much faster)
    python backfill.py --start 1981-09-01 --end 2026-02-10 --export-only

    # Summary stats only (no COG exports)
    python backfill.py --start 2024-01-01 --end 2024-12-31 --stats-only

    # Annual max DHW
    python backfill.py --annual-max 2024
    python backfill.py --annual-max-range 1982 2025

    # Export to Google Drive instead of GCS
    python backfill.py --start 2024-01-01 --end 2024-12-31 --dest drive

    # Load previously saved JSONL summaries into BigQuery
    python backfill.py --load-bq summaries/

Requirements:
    pip install earthengine-api google-cloud-bigquery

Notes:
    - DHW is unreliable for the first 84 days (before 1981-11-24) due to
      incomplete rolling window. These dates are still processed but flagged.
    - The 1985-2012 climatology is applied to all years, including pre-1985.
      This is consistent with CRW operational practice.
    - OISST v2.1 begins 1981-09-01. Earlier dates will have no data.
"""

import ee
import os
import math
import json
import argparse
import time
from datetime import date, timedelta
from pathlib import Path

# ── Config ───────────────────────────────────────────────────────────────────
GEE_PROJECT = os.environ.get('GEE_PROJECT', 'YOUR-GEE-PROJECT')
GCS_BUCKET = os.environ.get('GCS_BUCKET', 'YOUR-GCS-BUCKET')
ASSET_FOLDER = f'projects/{GEE_PROJECT}/assets/coral_dhw'

ROI_COORDS = [141.0958, -24.70584, 153.2032, -8.926405]
DHW_WINDOW = 84
HS_THRESHOLD = 1.0
SCALE = 27830

# Task management
MAX_QUEUED_TASKS = 2500        # stay under GEE's ~3000 limit
TASK_CHECK_INTERVAL = 30       # seconds between queue checks
BATCH_SIZE = 100               # dates to process before checking queue
THROTTLE_PAUSE = 5             # seconds between batches

# Output directories
SUMMARY_DIR = Path('summaries')
PROGRESS_FILE = Path('backfill_progress.json')


# ── EE Init ──────────────────────────────────────────────────────────────────
def init_ee():
    try:
        ee.Initialize(project=GEE_PROJECT)
    except Exception:
        ee.Authenticate()
        ee.Initialize(project=GEE_PROJECT)


# ── Load climatology ─────────────────────────────────────────────────────────
def load_climatology():
    print('Loading climatology from EE assets ...')
    mmm = ee.Image(f'{ASSET_FOLDER}/mmm_climatology')
    dc_image = ee.Image(f'{ASSET_FOLDER}/daily_climatology')
    print('  ✓ Climatology loaded.')
    return mmm, dc_image


# ── Task queue management ────────────────────────────────────────────────────
def count_active_tasks():
    """Count running + ready (queued) EE tasks."""
    tasks = ee.data.getTaskList()
    active = sum(1 for t in tasks
                 if t.get('state') in ('READY', 'RUNNING'))
    return active


def wait_for_queue_space(target=MAX_QUEUED_TASKS):
    """Block until the task queue has space."""
    while True:
        active = count_active_tasks()
        if active < target:
            return active
        print(f'    Queue full ({active} tasks). '
              f'Waiting {TASK_CHECK_INTERVAL}s ...')
        time.sleep(TASK_CHECK_INTERVAL)


# ── Product functions ────────────────────────────────────────────────────────
roi = None
mmm = None
dc_image = None


def get_sst(target_date):
    t1 = ee.Date(target_date.isoformat())
    t2 = t1.advance(1, 'day')
    img = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
           .select('sst').filterDate(t1, t2).filterBounds(roi).first())
    return img.multiply(0.01).clip(roi).rename('sst')


def get_anomaly(sst, target_date):
    doy = min(target_date.timetuple().tm_yday, 366)
    dc = dc_image.select(f'dc_{doy:03d}').rename('dc_sst')
    return sst.subtract(dc).rename('sst_anomaly')


def get_dhw(target_date):
    t_end = ee.Date(target_date.isoformat()).advance(1, 'day')
    t_start = ee.Date(target_date.isoformat()).advance(
        -(DHW_WINDOW - 1), 'day')
    hs_coll = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
               .select('sst').filterDate(t_start, t_end).filterBounds(roi)
               .map(lambda img: img.multiply(0.01)
                    .subtract(mmm).max(0)
                    .rename('hotspot').clip(roi)))
    thresholded = hs_coll.map(
        lambda img: img.updateMask(img.gte(HS_THRESHOLD)).unmask(0))
    return thresholded.sum().divide(7).rename('dhw')


# ── Export functions ─────────────────────────────────────────────────────────
def export_cog(image, product, target_date):
    date_str = target_date.strftime('%Y%m%d')
    task = ee.batch.Export.image.toCloudStorage(
        image=image.toFloat(),
        description=f'{product}_{date_str}',
        bucket=GCS_BUCKET,
        fileNamePrefix=f'{product}/{target_date.year}/{date_str}',
        region=roi, scale=SCALE, maxPixels=1e8,
        formatOptions={'cloudOptimized': True}
    )
    task.start()
    return task


def export_drive(image, product, target_date):
    date_str = target_date.strftime('%Y%m%d')
    task = ee.batch.Export.image.toDrive(
        image=image.toFloat(),
        description=f'{product}_{date_str}',
        fileNamePrefix=f'{product}_{date_str}',
        folder='coral_dhw_exports',
        region=roi, scale=SCALE, maxPixels=1e8
    )
    task.start()
    return task


# ── Summary stats ────────────────────────────────────────────────────────────
def compute_summary(sst, anomaly, dhw, target_date):
    combined = (sst.rename('sst')
                .addBands(anomaly.rename('anomaly'))
                .addBands(dhw.rename('dhw')))
    stats = combined.reduceRegion(
        reducer=(ee.Reducer.mean()
                 .combine(ee.Reducer.stdDev(), sharedInputs=True)
                 .combine(ee.Reducer.count(), sharedInputs=True)),
        geometry=roi, scale=SCALE, maxPixels=1e8
    ).getInfo()

    row = {'date': target_date.isoformat()}
    for var in ['sst', 'anomaly', 'dhw']:
        mean_v = stats.get(f'{var}_mean')
        std_v = stats.get(f'{var}_stdDev')
        count_v = stats.get(f'{var}_count')
        if mean_v is not None and count_v and count_v > 0:
            ci95 = 1.96 * (std_v / math.sqrt(count_v)) if std_v else 0
            row[f'{var}_mean'] = round(mean_v, 4)
            row[f'{var}_std'] = round(std_v, 4) if std_v else 0
            row[f'{var}_ci95_lower'] = round(mean_v - ci95, 4)
            row[f'{var}_ci95_upper'] = round(mean_v + ci95, 4)
            row[f'{var}_n_pixels'] = int(count_v)
        else:
            for s in ['mean', 'std', 'ci95_lower', 'ci95_upper']:
                row[f'{var}_{s}'] = None
            row[f'{var}_n_pixels'] = 0
    return row


def save_summary_jsonl(row, year):
    """Save summary row to a year-specific JSONL file."""
    SUMMARY_DIR.mkdir(exist_ok=True)
    filepath = SUMMARY_DIR / f'summary_{year}.jsonl'
    with open(filepath, 'a') as f:
        f.write(json.dumps(row) + '\n')


# ── Progress tracking ────────────────────────────────────────────────────────
def load_progress():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {'completed_dates': [], 'last_date': None}


def save_progress(progress):
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f)


# ── Main backfill loop ───────────────────────────────────────────────────────
def backfill(start_date, end_date, dest='gcs', resume=False,
             export_only=False, stats_only=False):
    global roi, mmm, dc_image

    init_ee()
    roi = ee.Geometry.Rectangle(ROI_COORDS)
    mmm, dc_image = load_climatology()

    export_fn = export_cog if dest == 'gcs' else export_drive

    # Calculate total days
    total_days = (end_date - start_date).days + 1
    print(f'Backfill: {start_date} → {end_date} ({total_days} days)')
    print(f'  Export to: {"GCS gs://" + GCS_BUCKET if dest == "gcs" else "Google Drive"}')
    print(f'  Mode: {"export only" if export_only else "stats only" if stats_only else "export + stats"}')

    # Resume support
    completed = set()
    if resume:
        progress = load_progress()
        completed = set(progress.get('completed_dates', []))
        if completed:
            print(f'  Resuming: {len(completed)} dates already completed.')

    # Process day by day
    current = start_date
    processed = 0
    errors = 0
    batch_count = 0

    while current <= end_date:
        date_str = current.isoformat()

        # Skip if already done (resume mode)
        if date_str in completed:
            current += timedelta(days=1)
            continue

        processed += 1
        batch_count += 1

        # Progress display
        elapsed_days = (current - start_date).days + 1
        pct = (elapsed_days / total_days) * 100
        year_str = current.strftime('%Y')

        try:
            sst = get_sst(current)

            if not stats_only:
                anomaly = get_anomaly(sst, current)
                dhw_img = get_dhw(current)

                export_fn(sst, 'sst', current)
                export_fn(anomaly, 'sst_anomaly', current)
                export_fn(dhw_img, 'dhw', current)

            if not export_only:
                if stats_only:
                    anomaly = get_anomaly(sst, current)
                    dhw_img = get_dhw(current)
                row = compute_summary(sst, anomaly, dhw_img, current)
                save_summary_jsonl(row, current.year)
                print(f'  [{pct:5.1f}%] {date_str}  '
                      f'SST={row["sst_mean"]}  '
                      f'Anom={row["anomaly_mean"]}  '
                      f'DHW={row["dhw_mean"]}')
            else:
                print(f'  [{pct:5.1f}%] {date_str}  exported')

            completed.add(date_str)

        except Exception as e:
            errors += 1
            print(f'  [{pct:5.1f}%] {date_str}  ERROR: {e}')

        # Batch management
        if batch_count >= BATCH_SIZE:
            batch_count = 0

            # Save progress
            save_progress({
                'completed_dates': list(completed),
                'last_date': date_str
            })

            if not stats_only:
                # Check task queue
                active = count_active_tasks()
                print(f'  --- Batch checkpoint: {processed} processed, '
                      f'{active} tasks queued, {errors} errors ---')

                if active > MAX_QUEUED_TASKS:
                    print(f'  Queue at {active}/{MAX_QUEUED_TASKS}. Waiting ...')
                    wait_for_queue_space()
                else:
                    time.sleep(THROTTLE_PAUSE)

        current += timedelta(days=1)

    # Final save
    save_progress({
        'completed_dates': list(completed),
        'last_date': (end_date).isoformat()
    })

    print(f'\n{"═" * 60}')
    print(f'✓ Backfill complete: {processed} days processed, {errors} errors.')
    if not stats_only:
        print(f'  Monitor exports: https://code.earthengine.google.com/tasks')
    if not export_only:
        print(f'  Summaries saved: {SUMMARY_DIR}/')
        print(f'  Load to BigQuery: python backfill.py --load-bq {SUMMARY_DIR}/')
    print(f'{"═" * 60}')


# ── Annual max DHW ───────────────────────────────────────────────────────────
def annual_max_dhw(year, dest='gcs'):
    global roi, mmm
    init_ee()
    roi = ee.Geometry.Rectangle(ROI_COORDS)
    mmm_img, _ = load_climatology()
    mmm = mmm_img

    export_fn = export_cog if dest == 'gcs' else export_drive

    print(f'Computing annual max DHW for {year} ...')
    start = ee.Date.fromYMD(year, 1, 1)
    n_days = ee.Date.fromYMD(year + 1, 1, 1).difference(start, 'day')

    dates = ee.List.sequence(0, n_days.subtract(1)).map(
        lambda offset: start.advance(offset, 'day'))

    def dhw_for_date(d):
        d = ee.Date(d)
        t_end = d.advance(1, 'day')
        t_start = d.advance(-(DHW_WINDOW - 1), 'day')
        hs = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
              .select('sst').filterDate(t_start, t_end).filterBounds(roi)
              .map(lambda img: img.multiply(0.01)
                   .subtract(mmm_img).max(0).rename('hotspot').clip(roi)))
        thr = hs.map(
            lambda img: img.updateMask(img.gte(HS_THRESHOLD)).unmask(0))
        return thr.sum().divide(7).rename('dhw')

    dhw_year = ee.ImageCollection(dates.map(dhw_for_date))
    max_dhw = dhw_year.max().rename('annual_max_dhw')

    target = date(year, 12, 31)
    export_fn(max_dhw, 'annual_max_dhw', target)

    max_val = max_dhw.reduceRegion(
        reducer=ee.Reducer.max(), geometry=roi,
        scale=SCALE, maxPixels=1e8).getInfo()
    print(f'  GBR annual max DHW ({year}): {max_val}')
    print(f'  Export task started.')


# ── Load JSONL summaries to BigQuery ─────────────────────────────────────────
def load_summaries_to_bigquery(summary_dir):
    """Bulk-load all JSONL summary files into BigQuery."""
    from google.cloud import bigquery

    bq_table = os.environ.get(
        'BQ_TABLE', f'{GEE_PROJECT}.coral_dhw.daily_summary')
    client = bigquery.Client(project=GEE_PROJECT)

    summary_path = Path(summary_dir)
    jsonl_files = sorted(summary_path.glob('summary_*.jsonl'))

    if not jsonl_files:
        print(f'No JSONL files found in {summary_dir}')
        return

    total_rows = 0
    for filepath in jsonl_files:
        rows = []
        with open(filepath) as f:
            for line in f:
                line = line.strip()
                if line:
                    rows.append(json.loads(line))

        if not rows:
            continue

        errors = client.insert_rows_json(bq_table, rows)
        if errors:
            print(f'  {filepath.name}: {len(rows)} rows, ERRORS: {errors[:3]}')
        else:
            print(f'  {filepath.name}: {len(rows)} rows loaded.')
        total_rows += len(rows)

    print(f'\n✓ Loaded {total_rows} total rows to {bq_table}')


# ── CLI ──────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Backfill coral DHW products from the full OISST record',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Full OISST record (exports only — fastest)
  python backfill.py --start 1981-09-01 --end 2026-02-10 --export-only

  # Full record with summary stats (slower, ~10s per day)
  python backfill.py --start 1981-09-01 --end 2026-02-10

  # Resume after interruption
  python backfill.py --start 1981-09-01 --end 2026-02-10 --resume

  # Stats only (no COG exports)
  python backfill.py --start 2020-01-01 --end 2024-12-31 --stats-only

  # Annual max DHW for a range of years
  python backfill.py --annual-max-range 1982 2025

  # Load saved summaries into BigQuery
  python backfill.py --load-bq summaries/
        """)

    parser.add_argument('--start', type=str, help='Start date YYYY-MM-DD')
    parser.add_argument('--end', type=str, help='End date YYYY-MM-DD')
    parser.add_argument('--dest', choices=['gcs', 'drive'], default='gcs',
                        help='Export destination (default: gcs)')
    parser.add_argument('--resume', action='store_true',
                        help='Resume from last checkpoint')
    parser.add_argument('--export-only', action='store_true',
                        help='Skip summary stats (much faster)')
    parser.add_argument('--stats-only', action='store_true',
                        help='Compute stats only, no COG exports')
    parser.add_argument('--annual-max', type=int,
                        help='Compute annual max DHW for one year')
    parser.add_argument('--annual-max-range', type=int, nargs=2,
                        metavar=('START_YEAR', 'END_YEAR'),
                        help='Compute annual max DHW for a range of years')
    parser.add_argument('--load-bq', type=str, metavar='DIR',
                        help='Load JSONL summaries from DIR into BigQuery')

    args = parser.parse_args()

    # Load summaries to BigQuery
    if args.load_bq:
        init_ee()  # not strictly needed but initialises project
        load_summaries_to_bigquery(args.load_bq)

    # Annual max DHW (single year)
    elif args.annual_max:
        annual_max_dhw(args.annual_max, args.dest)

    # Annual max DHW (range)
    elif args.annual_max_range:
        y_start, y_end = args.annual_max_range
        for y in range(y_start, y_end + 1):
            try:
                annual_max_dhw(y, args.dest)
            except Exception as e:
                print(f'  ERROR for {y}: {e}')

    # Date range backfill
    elif args.start and args.end:
        backfill(
            start_date=date.fromisoformat(args.start),
            end_date=date.fromisoformat(args.end),
            dest=args.dest,
            resume=args.resume,
            export_only=args.export_only,
            stats_only=args.stats_only
        )
    else:
        parser.print_help()