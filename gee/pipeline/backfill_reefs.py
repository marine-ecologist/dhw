"""
backfill_reefs.py — Full architecture backfill via GEE
======================================================
Populates the complete GCS bucket structure:

gs://coral-dhw-gbr/
│
├── rasters/                         ← 5-band COGs (64×48, 0.25°)
│   └── {year}/{YYYYMMDD}.tif        bands: sst, sst_anomaly, hotspot, dhw, baa
│
├── reef_daily/                      ← Compact CSV per day (LABEL_ID + 5 values)
│   └── {year}/{YYYYMMDD}.csv
│
├── reef_timeseries/                 ← Per-product Parquet (all reefs × all dates)
│   ├── sst.parquet
│   ├── sst_anomaly.parquet
│   ├── hotspot.parquet
│   ├── dhw.parquet
│   └── baa.parquet
│
├── gbr_summary/                     ← GBR-wide daily summary
│   └── gbr_daily.csv
│
└── annual_max_dhw/                  ← Per-pixel annual maximum DHW
    ├── 1982/{year}1231.tif
    └── ...

Usage:
    # ── Reef extraction (main use case) ──────────────────────────
    # Process a date range (saves reef JSONs + BQ rows)
    python backfill_reefs.py --start 2024-01-01 --end 2024-12-31

    # Resume after interruption
    python backfill_reefs.py --start 1981-09-01 --end 2026-02-10 --resume

    # Skip BigQuery, save GCS files only
    python backfill_reefs.py --start 2024-01-01 --end 2024-12-31 --json-only

    # ── Raster COG exports ────────────────────────────────────────
    # Export raster COGs (async GEE export tasks)
    python backfill_reefs.py --rasters --start 2024-01-01 --end 2024-12-31

    # ── Annual max DHW ────────────────────────────────────────────
    python backfill_reefs.py --annual-max 2024
    python backfill_reefs.py --annual-max-range 1982 2025

    # ── Post-processing (after backfill) ──────────────────────────
    # Build per-reef time series files for frontend
    python backfill_reefs.py --build-reef-files

    # Build Parquet files from daily JSONs
    python backfill_reefs.py --build-parquet

    # Build GBR summary CSV
    python backfill_reefs.py --build-gbr-summary

    # Build everything (reef files + parquet + summary)
    python backfill_reefs.py --build-all

Prerequisites:
    pip install earthengine-api google-cloud-bigquery google-cloud-storage pyarrow pandas
"""

import ee
import os
import json
import io
import argparse
import time
import math
from datetime import date, timedelta
from pathlib import Path

# ── Config ───────────────────────────────────────────────────────────────────
GEE_PROJECT = os.environ.get('GEE_PROJECT', 'YOUR-GEE-PROJECT')
GCS_BUCKET = os.environ.get('GCS_BUCKET', 'YOUR-GCS-BUCKET')
ASSET_FOLDER = f'projects/{GEE_PROJECT}/assets/coral_dhw'
REEF_ASSET = f'{ASSET_FOLDER}/gbr_reefs'
MASK_ASSET = f'{ASSET_FOLDER}/gbr_mask'

BQ_TABLE = os.environ.get(
    'BQ_TABLE', f'{GEE_PROJECT}.coral_dhw.daily_summary')
BQ_REEF_TABLE = os.environ.get(
    'BQ_REEF_TABLE', f'{GEE_PROJECT}.coral_dhw.reef_daily')

DHW_WINDOW = 84
HS_THRESHOLD = 1.0
SCALE = 27830  # metres (~0.25°), for reduceRegion

# Grid spec (matches R gbr_mask raster: 64 rows × 48 cols)
EXPORT_CRS = 'EPSG:4326'
EXPORT_CRS_TRANSFORM = [0.25, 0, 141, 0, -0.25, -8.75]
EXPORT_BOUNDS = [141, -24.75, 153, -8.75]

PRODUCTS = ['sst', 'sst_anomaly', 'hotspot', 'dhw', 'baa']

# Task management
MAX_QUEUED_TASKS = 2500
TASK_CHECK_INTERVAL = 30
RASTER_BATCH_SIZE = 100
THROTTLE_PAUSE = 5

# Reef extraction
REEF_BATCH_SIZE = 50
PROGRESS_FILE = Path('backfill_reefs_progress.json')


# ══════════════════════════════════════════════════════════════════════════════
# EE INITIALISATION & ASSETS
# ══════════════════════════════════════════════════════════════════════════════

def init_ee():
    try:
        ee.Initialize(project=GEE_PROJECT)
    except Exception:
        ee.Authenticate()
        ee.Initialize(project=GEE_PROJECT)


def load_assets(need_reefs=True):
    """Load pre-computed climatology, mask, and optionally reef polygons."""
    bbox = ee.Geometry.Rectangle(EXPORT_BOUNDS)
    mask = ee.Image(MASK_ASSET).selfMask()  # 0→NoData, 1→valid
    mmm = ee.Image(f'{ASSET_FOLDER}/mmm_climatology')
    dc_image = ee.Image(f'{ASSET_FOLDER}/daily_climatology')

    reef_fc = None
    if need_reefs:
        reef_fc = ee.FeatureCollection(REEF_ASSET)
        reef_count = reef_fc.size().getInfo()
        print(f'  Loaded {reef_count} reef polygons')

    print(f'  Climatology + mask assets loaded.')
    return bbox, mask, reef_fc, mmm, dc_image


# ══════════════════════════════════════════════════════════════════════════════
# PRODUCT COMPUTATION
# ══════════════════════════════════════════════════════════════════════════════

def get_sst(target_date, bbox, mask):
    t1 = ee.Date(target_date.isoformat())
    t2 = t1.advance(1, 'day')
    img = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
           .select('sst').filterDate(t1, t2).filterBounds(bbox)
           .first())
    return img.multiply(0.01).updateMask(mask).rename('sst')


def get_anomaly(sst, target_date, dc_image):
    doy = min(target_date.timetuple().tm_yday, 366)
    dc = dc_image.select(f'dc_{doy:03d}').rename('dc_sst')
    return sst.subtract(dc).rename('sst_anomaly')


def get_hotspot(sst, mmm):
    return sst.subtract(mmm).max(0).rename('hotspot')


def get_dhw(target_date, mmm, bbox, mask):
    t_end = ee.Date(target_date.isoformat()).advance(1, 'day')
    t_start = ee.Date(target_date.isoformat()).advance(
        -(DHW_WINDOW - 1), 'day')
    hs_coll = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
               .select('sst').filterDate(t_start, t_end).filterBounds(bbox)
               .map(lambda img: img.multiply(0.01)
                    .subtract(mmm).max(0).rename('hotspot').updateMask(mask)))
    thresholded = hs_coll.map(
        lambda img: img.updateMask(img.gte(HS_THRESHOLD)).unmask(0))
    return thresholded.sum().divide(7).updateMask(mask).rename('dhw')


def compute_all_products(target_date, bbox, mask, mmm, dc_image):
    """Compute SST, SSTA, HotSpot, DHW, BAA for a single date."""
    sst = get_sst(target_date, bbox, mask)
    anomaly = get_anomaly(sst, target_date, dc_image)
    hotspot = get_hotspot(sst, mmm)
    dhw = get_dhw(target_date, mmm, bbox, mask)
    baa = get_baa(hotspot, dhw)
    return {'sst': sst, 'sst_anomaly': anomaly,
            'hotspot': hotspot, 'dhw': dhw, 'baa': baa}


# ── BAA = Bleaching Alert Area classification ────────────────────────────────
# Matches R categorize_baa():
#   0: No Stress        (HS ≤ 0)
#   1: Bleaching Watch   (0 < HS < 1, DHW < 4)
#   2: Bleaching Warning (HS ≥ 1, DHW < 4)
#   3: Alert Level 1     (HS ≥ 1, 4 ≤ DHW < 8)
#   4: Alert Level 2     (HS ≥ 1, 8 ≤ DHW < 12)
#   5: Alert Level 3     (HS ≥ 1, 12 ≤ DHW < 16)
#   6: Alert Level 4     (HS ≥ 1, 16 ≤ DHW < 20)
#   7: Alert Level 5     (HS ≥ 1, DHW ≥ 20)
def get_baa(hotspot, dhw):
    hs = hotspot.rename('hs')
    d = dhw.rename('d')
    baa = (ee.Image(0)
           .where(hs.gt(0).And(hs.lt(1)).And(d.lt(4)), 1)
           .where(hs.gte(1).And(d.lt(4)), 2)
           .where(hs.gte(1).And(d.gte(4)).And(d.lt(8)), 3)
           .where(hs.gte(1).And(d.gte(8)).And(d.lt(12)), 4)
           .where(hs.gte(1).And(d.gte(12)).And(d.lt(16)), 5)
           .where(hs.gte(1).And(d.gte(16)).And(d.lt(20)), 6)
           .where(hs.gte(1).And(d.gte(20)), 7)
           .updateMask(hs.mask())
           .rename('baa').toInt())
    return baa


# ══════════════════════════════════════════════════════════════════════════════
# RASTER EXPORT (COGs to GCS)
# ══════════════════════════════════════════════════════════════════════════════

def count_active_tasks():
    tasks = ee.data.getTaskList()
    return sum(1 for t in tasks if t.get('state') in ('READY', 'RUNNING'))


def wait_for_queue_space(target=MAX_QUEUED_TASKS):
    while True:
        active = count_active_tasks()
        if active < target:
            return active
        print(f'    Queue full ({active} tasks). Waiting {TASK_CHECK_INTERVAL}s ...')
        time.sleep(TASK_CHECK_INTERVAL)


def export_daily_cog(products, target_date, export_region):
    """Export single 5-band COG: sst, sst_anomaly, hotspot, dhw, baa."""
    date_str = target_date.strftime('%Y%m%d')
    file_path = f'rasters/{target_date.year}/{date_str}'

    combined = (products['sst'].toFloat().rename('sst')
                .addBands(products['sst_anomaly'].toFloat().rename('sst_anomaly'))
                .addBands(products['hotspot'].toFloat().rename('hotspot'))
                .addBands(products['dhw'].toFloat().rename('dhw'))
                .addBands(products['baa'].toFloat().rename('baa')))

    task = ee.batch.Export.image.toCloudStorage(
        image=combined,
        description=f'daily_{date_str}',
        bucket=GCS_BUCKET,
        fileNamePrefix=file_path,
        region=export_region,
        crs=EXPORT_CRS,
        crsTransform=EXPORT_CRS_TRANSFORM,
        maxPixels=1e8,
        formatOptions={'cloudOptimized': True}
    )
    task.start()
    return task.status()['id']


def backfill_rasters(start_date, end_date, resume=False):
    """Export raster COGs for a date range (async GEE tasks)."""
    init_ee()
    print('Loading assets ...')
    bbox, mask, _, mmm, dc_image = load_assets(need_reefs=False)
    export_region = bbox

    total_days = (end_date - start_date).days + 1
    print(f'Raster export: {start_date} → {end_date} ({total_days} days)')

    completed = load_progress() if resume else set()
    current = start_date
    processed = 0
    batch_count = 0

    while current <= end_date:
        date_str = current.isoformat()
        raster_key = f'raster_{date_str}'

        if raster_key in completed:
            current += timedelta(days=1)
            continue

        pct = ((current - start_date).days + 1) / total_days * 100

        try:
            products = compute_all_products(current, bbox, mask, mmm, dc_image)
            export_daily_cog(products, current, export_region)

            completed.add(raster_key)
            processed += 1
            batch_count += 1
            print(f'  [{pct:5.1f}%] {date_str}  5-band COG exported')

        except Exception as e:
            print(f'  [{pct:5.1f}%] {date_str}  ERROR: {e}')

        if batch_count >= RASTER_BATCH_SIZE:
            batch_count = 0
            save_progress(completed)
            active = count_active_tasks()
            print(f'  --- Checkpoint: {processed} processed, {active} tasks queued ---')
            if active > MAX_QUEUED_TASKS:
                wait_for_queue_space()
            else:
                time.sleep(THROTTLE_PAUSE)

        current += timedelta(days=1)

    save_progress(completed)
    print(f'\n✓ Raster export: {processed} days submitted.')
    print(f'  Monitor: https://code.earthengine.google.com/tasks')


# ══════════════════════════════════════════════════════════════════════════════
# REEF EXTRACTION (reduceRegions → JSON + BigQuery)
# ══════════════════════════════════════════════════════════════════════════════

def extract_reef_means(products, target_date, reef_fc):
    """
    Compute area-weighted mean per reef for SST, SSTA, HS, DHW.
    BAA derived from reef-level HS and DHW means.
    Returns list of dicts (LABEL_ID + 5 values, no date/GBR_NAME).
    """
    combined = (products['sst'].rename('sst')
                .addBands(products['sst_anomaly'].rename('sst_anomaly'))
                .addBands(products['hotspot'].rename('hotspot'))
                .addBands(products['dhw'].rename('dhw')))

    results = combined.reduceRegions(
        collection=reef_fc,
        reducer=ee.Reducer.mean(),
        scale=250
    ).getInfo()

    rows = []
    for feat in results['features']:
        p = feat['properties']
        s = round(p['sst'], 4) if p.get('sst') is not None else None
        a = round(p['sst_anomaly'], 4) if p.get('sst_anomaly') is not None else None
        h = round(p['hotspot'], 4) if p.get('hotspot') is not None else None
        d = round(p['dhw'], 4) if p.get('dhw') is not None else None

        # BAA from continuous reef-level means (matches R categorize_baa)
        if h is not None and d is not None:
            if h >= 1 and d >= 20:
                b = 7
            elif h >= 1 and d >= 16:
                b = 6
            elif h >= 1 and d >= 12:
                b = 5
            elif h >= 1 and d >= 8:
                b = 4
            elif h >= 1 and d >= 4:
                b = 3
            elif h >= 1:
                b = 2
            elif h > 0 and d < 4:
                b = 1
            else:
                b = 0
        else:
            b = None

        rows.append({
            'LABEL_ID': p.get('LABEL_ID', ''),
            'sst': s, 'sst_anomaly': a,
            'hotspot': h, 'dhw': d, 'baa': b
        })
    return rows


def compute_gbr_summary(reef_rows, target_date):
    """Compute GBR-wide mean ± 95% CI from reef-level data."""
    date_str = target_date.isoformat()
    summary = {'date': date_str}

    for var in PRODUCTS:
        values = [r[var] for r in reef_rows
                  if r.get(var) is not None and not isinstance(r[var], str)]
        n = len(values)
        if n > 0:
            mean_v = sum(values) / n
            if n > 1:
                std_v = math.sqrt(sum((x - mean_v)**2 for x in values) / (n - 1))
            else:
                std_v = 0
            ci95 = 1.96 * (std_v / math.sqrt(n)) if n > 0 else 0
            summary[f'{var}_mean'] = round(mean_v, 4)
            summary[f'{var}_std'] = round(std_v, 4)
            summary[f'{var}_ci95_lower'] = round(mean_v - ci95, 4)
            summary[f'{var}_ci95_upper'] = round(mean_v + ci95, 4)
            summary[f'{var}_n_reefs'] = n
        else:
            for s in ['mean', 'std', 'ci95_lower', 'ci95_upper']:
                summary[f'{var}_{s}'] = None
            summary[f'{var}_n_reefs'] = 0

    return summary


# ── GCS save functions ───────────────────────────────────────────────────────

REEF_CSV_FIELDS = ['LABEL_ID', 'sst', 'sst_anomaly', 'hotspot', 'dhw', 'baa']

_storage_client = None

def get_storage_client():
    """Lazy init of GCS client."""
    global _storage_client
    if _storage_client is None:
        from google.cloud import storage
        _storage_client = storage.Client(project=GEE_PROJECT)
    return _storage_client


def save_reef_csv(rows, target_date):
    """Save reef means as compact CSV: gs://bucket/reef_daily/{year}/{YYYYMMDD}.csv"""
    import csv
    import io

    date_str = target_date.strftime('%Y%m%d')
    blob_path = f'reef_daily/{target_date.year}/{date_str}.csv'

    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=REEF_CSV_FIELDS)
    writer.writeheader()
    writer.writerows(rows)

    client = get_storage_client()
    bucket = client.bucket(GCS_BUCKET)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(buf.getvalue(), content_type='text/csv')
    return blob_path


def save_to_bigquery_reef(rows, target_date):
    """Insert reef rows into BigQuery."""
    from google.cloud import bigquery
    date_str = target_date.isoformat()
    bq_rows = [{'date': date_str, **r} for r in rows]
    client = bigquery.Client(project=GEE_PROJECT)
    for i in range(0, len(bq_rows), 500):
        batch = bq_rows[i:i+500]
        errors = client.insert_rows_json(BQ_REEF_TABLE, batch)
        if errors:
            print(f'    BQ reef insert errors: {errors[:2]}')


def save_to_bigquery_summary(row):
    """Insert GBR summary row into BigQuery."""
    from google.cloud import bigquery
    client = bigquery.Client(project=GEE_PROJECT)
    errors = client.insert_rows_json(BQ_TABLE, [row])
    if errors:
        print(f'    BQ summary insert errors: {errors[:2]}')


# ── Progress tracking ────────────────────────────────────────────────────────

def load_progress():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            return set(json.load(f).get('completed', []))
    return set()


def save_progress(completed):
    with open(PROGRESS_FILE, 'w') as f:
        json.dump({'completed': sorted(completed)}, f)


# ══════════════════════════════════════════════════════════════════════════════
# MAIN BACKFILL LOOP
# ══════════════════════════════════════════════════════════════════════════════

def backfill(start_date, end_date, resume=False, json_only=False):
    """
    For each date:
      1. Compute SST, SSTA, HS, DHW, BAA on GEE
      2. Export 5-band raster COG to GCS (async)
      3. reduceRegions → reef means + BAA
      4. Save reef CSV to GCS (reef_daily/)
      5. Save reef rows to BigQuery (unless --json-only)
      6. Compute GBR summary → BigQuery (unless --json-only)
    """
    init_ee()
    print('Loading assets ...')
    bbox, mask, reef_fc, mmm, dc_image = load_assets(need_reefs=True)
    export_region = bbox

    total_days = (end_date - start_date).days + 1
    print(f'Backfill: {start_date} → {end_date} ({total_days} days)')
    print(f'  Mode: {"GCS only" if json_only else "GCS + BigQuery"}')

    completed = load_progress() if resume else set()
    if completed:
        print(f'  Resuming: {len(completed)} dates already done')

    current = start_date
    processed = 0
    errors = 0
    batch_count = 0

    while current <= end_date:
        date_str = current.isoformat()

        if date_str in completed:
            current += timedelta(days=1)
            continue

        pct = ((current - start_date).days + 1) / total_days * 100

        try:
            # 1. Compute products
            products = compute_all_products(current, bbox, mask, mmm, dc_image)

            # 2. Export 5-band raster COG (async)
            export_daily_cog(products, current, export_region)

            # 3. Extract reef means
            reef_rows = extract_reef_means(
                products, current, reef_fc)

            # 4. Save reef CSV
            save_reef_csv(reef_rows, current)

            # 5-6. BigQuery
            if not json_only:
                save_to_bigquery_reef(reef_rows, current)
                summary = compute_gbr_summary(reef_rows, current)
                save_to_bigquery_summary(summary)

            completed.add(date_str)
            processed += 1
            batch_count += 1

            sst_val = reef_rows[0]['sst'] if reef_rows else '?'
            print(f'  [{pct:5.1f}%] {date_str}  '
                  f'{len(reef_rows)} reefs  COG + CSV  SST={sst_val}')

        except Exception as e:
            errors += 1
            print(f'  [{pct:5.1f}%] {date_str}  ERROR: {e}')

        if batch_count >= REEF_BATCH_SIZE:
            batch_count = 0
            save_progress(completed)
            active = count_active_tasks()
            print(f'  --- Checkpoint: {processed} processed, {errors} errors, {active} GEE tasks ---')
            if active > MAX_QUEUED_TASKS:
                wait_for_queue_space()
            time.sleep(1)

        current += timedelta(days=1)

    save_progress(completed)
    print(f'\n{"═" * 60}')
    print(f'✓ Complete: {processed} days, {errors} errors.')
    print(f'{"═" * 60}')


# ══════════════════════════════════════════════════════════════════════════════
# ANNUAL MAX DHW
# ══════════════════════════════════════════════════════════════════════════════

def annual_max_dhw(year):
    """Compute per-pixel annual maximum DHW and export as COG."""
    init_ee()
    bbox, mask, _, mmm, _ = load_assets(need_reefs=False)
    export_region = bbox

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
              .select('sst').filterDate(t_start, t_end).filterBounds(bbox)
              .map(lambda img: img.multiply(0.01)
                   .subtract(mmm).max(0).rename('hotspot').updateMask(mask)))
        thr = hs.map(
            lambda img: img.updateMask(img.gte(HS_THRESHOLD)).unmask(0))
        return thr.sum().divide(7).updateMask(mask).rename('dhw')

    dhw_year = ee.ImageCollection(dates.map(dhw_for_date))
    max_dhw = dhw_year.max().rename('annual_max_dhw')

    date_str = f'{year}1231'
    task = ee.batch.Export.image.toCloudStorage(
        image=max_dhw.toFloat(),
        description=f'annual_max_dhw_{year}',
        bucket=GCS_BUCKET,
        fileNamePrefix=f'annual_max_dhw/{year}/{date_str}',
        region=export_region,
        crs=EXPORT_CRS,
        crsTransform=EXPORT_CRS_TRANSFORM,
        maxPixels=1e8,
        formatOptions={'cloudOptimized': True}
    )
    task.start()
    print(f'  Export task started for {year}.')


# ══════════════════════════════════════════════════════════════════════════════
# POST-PROCESSING: Build derived files from daily CSVs
# ══════════════════════════════════════════════════════════════════════════════

def build_reef_files():
    """
    Read all reef_daily/{year}/{date}.csv from GCS and reorganise
    into one JSON per reef: reef_timeseries/{LABEL_ID}.json
    Each file: [{date, sst, sst_anomaly, hotspot, dhw, baa}, ...]
    """
    import csv
    import io
    from google.cloud import storage
    client = storage.Client(project=GEE_PROJECT)
    bucket = client.bucket(GCS_BUCKET)

    print('Listing daily reef CSVs ...')
    blobs = sorted(bucket.list_blobs(prefix='reef_daily/'),
                   key=lambda b: b.name)
    csv_blobs = [b for b in blobs if b.name.endswith('.csv')]
    print(f'  Found {len(csv_blobs)} daily files')

    reef_data = {}  # LABEL_ID → list of daily records

    for i, blob in enumerate(csv_blobs):
        # Extract date from path: reef_daily/2024/20240101.csv
        fname = blob.name.split('/')[-1].replace('.csv', '')
        file_date = f'{fname[:4]}-{fname[4:6]}-{fname[6:8]}'

        text = blob.download_as_text()
        reader = csv.DictReader(io.StringIO(text))
        for row in reader:
            label = row['LABEL_ID']
            if label not in reef_data:
                reef_data[label] = []
            reef_data[label].append({
                'date': file_date,
                'sst': _safe_float(row.get('sst')),
                'sst_anomaly': _safe_float(row.get('sst_anomaly')),
                'hotspot': _safe_float(row.get('hotspot')),
                'dhw': _safe_float(row.get('dhw')),
                'baa': _safe_int(row.get('baa'))
            })
        if (i + 1) % 500 == 0:
            print(f'  Read {i + 1}/{len(csv_blobs)} files ...')

    print(f'  {len(reef_data)} unique reefs')

    for label, data in reef_data.items():
        data.sort(key=lambda r: r['date'])
        blob = bucket.blob(f'reef_timeseries/{label}.json')
        blob.upload_from_string(
            json.dumps(data, indent=None, separators=(',', ':')),
            content_type='application/json')

    print(f'✓ Wrote {len(reef_data)} reef files to reef_timeseries/')


def _safe_float(v):
    """Convert string to float, return None for empty/None."""
    if v is None or v == '' or v == 'None':
        return None
    return float(v)


def _safe_int(v):
    """Convert string to int, return None for empty/None."""
    if v is None or v == '' or v == 'None':
        return None
    return int(float(v))


def build_parquet():
    """
    Read all reef_daily/*.csv from GCS and create per-product
    Parquet files: reef_timeseries/{product}.parquet
    Columns: LABEL_ID, date, value
    """
    import pandas as pd
    from google.cloud import storage

    client = storage.Client(project=GEE_PROJECT)
    bucket = client.bucket(GCS_BUCKET)

    print('Reading daily reef CSVs for Parquet ...')
    blobs = sorted(bucket.list_blobs(prefix='reef_daily/'),
                   key=lambda b: b.name)
    csv_blobs = [b for b in blobs if b.name.endswith('.csv')]
    print(f'  Found {len(csv_blobs)} daily files')

    frames = []
    for i, blob in enumerate(csv_blobs):
        fname = blob.name.split('/')[-1].replace('.csv', '')
        file_date = f'{fname[:4]}-{fname[4:6]}-{fname[6:8]}'
        df = pd.read_csv(io.StringIO(blob.download_as_text()))
        df['date'] = file_date
        frames.append(df)
        if (i + 1) % 500 == 0:
            print(f'  Read {i + 1}/{len(csv_blobs)} ...')

    print(f'  Concatenating {len(frames)} frames ...')
    df = pd.concat(frames, ignore_index=True)
    df['date'] = pd.to_datetime(df['date']).dt.date

    for product in PRODUCTS:
        if product not in df.columns:
            continue
        subset = df[['LABEL_ID', 'date', product]].copy()
        subset = subset.rename(columns={product: 'value'})
        subset = subset.sort_values(['LABEL_ID', 'date'])

        local_path = f'/tmp/{product}.parquet'
        subset.to_parquet(local_path, index=False)

        blob = bucket.blob(f'reef_timeseries/{product}.parquet')
        blob.upload_from_filename(local_path)
        print(f'  ✓ {product}.parquet: {len(subset)} rows')

    print('✓ Parquet files uploaded.')


def build_gbr_summary():
    """
    Read all reef_daily/*.csv from GCS and compute GBR-wide
    daily summary (mean ± 95% CI across all reefs).
    Output: gbr_summary/gbr_daily.csv
    """
    import pandas as pd
    from google.cloud import storage

    client = storage.Client(project=GEE_PROJECT)
    bucket = client.bucket(GCS_BUCKET)

    print('Reading daily reef CSVs for GBR summary ...')
    blobs = sorted(bucket.list_blobs(prefix='reef_daily/'),
                   key=lambda b: b.name)
    csv_blobs = [b for b in blobs if b.name.endswith('.csv')]

    frames = []
    for blob in csv_blobs:
        fname = blob.name.split('/')[-1].replace('.csv', '')
        file_date = f'{fname[:4]}-{fname[4:6]}-{fname[6:8]}'
        df = pd.read_csv(io.StringIO(blob.download_as_text()))
        df['date'] = file_date
        frames.append(df)

    df = pd.concat(frames, ignore_index=True)

    summary_rows = []
    for d, grp in df.groupby('date'):
        row = {'date': d}
        for var in PRODUCTS:
            if var not in grp.columns:
                continue
            vals = pd.to_numeric(grp[var], errors='coerce').dropna()
            n = len(vals)
            if n > 0:
                mean_v = vals.mean()
                std_v = vals.std() if n > 1 else 0
                ci95 = 1.96 * (std_v / math.sqrt(n))
                row[f'{var}_mean'] = round(mean_v, 4)
                row[f'{var}_std'] = round(std_v, 4)
                row[f'{var}_ci95_lower'] = round(mean_v - ci95, 4)
                row[f'{var}_ci95_upper'] = round(mean_v + ci95, 4)
                row[f'{var}_n_reefs'] = n
            else:
                for s in ['mean', 'std', 'ci95_lower', 'ci95_upper']:
                    row[f'{var}_{s}'] = None
                row[f'{var}_n_reefs'] = 0
        summary_rows.append(row)

    summary_df = pd.DataFrame(summary_rows).sort_values('date')

    local_path = '/tmp/gbr_daily.csv'
    summary_df.to_csv(local_path, index=False)

    blob = bucket.blob('gbr_summary/gbr_daily.csv')
    blob.upload_from_filename(local_path)
    print(f'✓ GBR summary: {len(summary_df)} days → gbr_summary/gbr_daily.csv')


# ══════════════════════════════════════════════════════════════════════════════
# CLI
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Full architecture backfill via GEE',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Reef extraction for a date range
  python backfill_reefs.py --start 2024-01-01 --end 2024-12-31

  # Export raster COGs
  python backfill_reefs.py --rasters --start 2024-01-01 --end 2024-12-31

  # Annual max DHW
  python backfill_reefs.py --annual-max-range 1982 2025

  # Post-processing: build all derived files
  python backfill_reefs.py --build-all
        """)

    # Date range
    parser.add_argument('--start', type=str, help='Start date YYYY-MM-DD')
    parser.add_argument('--end', type=str, help='End date YYYY-MM-DD')
    parser.add_argument('--resume', action='store_true',
                        help='Resume from last checkpoint')
    parser.add_argument('--json-only', action='store_true',
                        help='GCS files only, skip BigQuery')

    # Rasters
    parser.add_argument('--rasters', action='store_true',
                        help='Export raster COGs (async GEE tasks)')

    # Annual max
    parser.add_argument('--annual-max', type=int,
                        help='Annual max DHW for one year')
    parser.add_argument('--annual-max-range', type=int, nargs=2,
                        metavar=('START_YEAR', 'END_YEAR'),
                        help='Annual max DHW for a range of years')

    # Post-processing
    parser.add_argument('--build-reef-files', action='store_true',
                        help='Build per-reef JSON files from daily JSONs')
    parser.add_argument('--build-parquet', action='store_true',
                        help='Build per-product Parquet files')
    parser.add_argument('--build-gbr-summary', action='store_true',
                        help='Build GBR-wide summary CSV')
    parser.add_argument('--build-all', action='store_true',
                        help='Build reef files + parquet + summary')

    args = parser.parse_args()

    # Post-processing
    if args.build_all:
        init_ee()
        build_reef_files()
        build_parquet()
        build_gbr_summary()
    elif args.build_reef_files:
        init_ee()
        build_reef_files()
    elif args.build_parquet:
        init_ee()
        build_parquet()
    elif args.build_gbr_summary:
        init_ee()
        build_gbr_summary()

    # Annual max
    elif args.annual_max:
        annual_max_dhw(args.annual_max)
    elif args.annual_max_range:
        y_start, y_end = args.annual_max_range
        for y in range(y_start, y_end + 1):
            try:
                annual_max_dhw(y)
            except Exception as e:
                print(f'  ERROR {y}: {e}')

    # Raster export
    elif args.rasters and args.start and args.end:
        backfill_rasters(
            start_date=date.fromisoformat(args.start),
            end_date=date.fromisoformat(args.end),
            resume=args.resume)

    # Reef extraction (default with dates)
    elif args.start and args.end:
        backfill(
            start_date=date.fromisoformat(args.start),
            end_date=date.fromisoformat(args.end),
            resume=args.resume,
            json_only=args.json_only)
    else:
        parser.print_help()