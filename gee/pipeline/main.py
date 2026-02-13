"""
main.py — Cloud Function entry point for the daily DHW pipeline.

Loads pre-computed climatology from EE assets (see precompute_climatology.py),
computes daily SST / anomaly / DHW, exports COGs to GCS, and logs
GBR-wide summary statistics to BigQuery.

Cloud Function config:
    Runtime:     python311
    Memory:      512 MB
    Timeout:     300 s
    Entry point: process_daily
    Trigger:     Pub/Sub topic (dhw-daily-trigger)
"""

import ee
import os
import json
import math
import base64
from datetime import date, timedelta

import functions_framework
from google.cloud import bigquery

# ── Configuration ────────────────────────────────────────────────────────────
GCS_BUCKET = os.environ.get('GCS_BUCKET', 'coral-dhw-gbr')
GEE_PROJECT = os.environ.get('GEE_PROJECT', 'your-gee-project')
BQ_TABLE = os.environ.get(
    'BQ_TABLE', f'{GEE_PROJECT}.coral_dhw.daily_summary')

ROI_COORDS = [141.0958, -24.70584, 153.2032, -8.926405]
ASSET_FOLDER = f'projects/{GEE_PROJECT}/assets/coral_dhw'

DHW_WINDOW = 84       # days (12 weeks)
HS_THRESHOLD = 1.0    # °C — only HS ≥ 1 contributes to DHW
SCALE = 27830         # metres (~0.25°)


# ── Earth Engine initialization ──────────────────────────────────────────────
def init_ee():
    """Initialize EE. Cloud Functions use the default service account."""
    try:
        ee.Initialize(project=GEE_PROJECT)
    except Exception:
        credentials, _ = None, None
        try:
            import google.auth
            credentials, _ = google.auth.default(
                scopes=['https://www.googleapis.com/auth/earthengine'])
        except Exception:
            pass
        ee.Initialize(credentials=credentials, project=GEE_PROJECT)


# ── Load pre-computed climatology from EE assets ─────────────────────────────
def load_climatology(roi):
    """
    Load MM, MMM, and daily climatology that were pre-exported as EE assets
    by precompute_climatology.py.

    Returns (mmm, dc_image):
        mmm:      ee.Image, single band 'mmm_sst'
        dc_image: ee.Image, 366 bands 'dc_001' ... 'dc_366'
    """
    mmm = ee.Image(f'{ASSET_FOLDER}/mmm_climatology')
    dc_image = ee.Image(f'{ASSET_FOLDER}/daily_climatology')
    return mmm, dc_image


# ── Check if OISST data exists for a date ────────────────────────────────────
def data_available(target_date, roi):
    t1 = ee.Date(target_date.isoformat())
    t2 = t1.advance(1, 'day')
    count = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
             .filterDate(t1, t2).filterBounds(roi).size().getInfo())
    return count > 0


# ── Get raw SST for a date ───────────────────────────────────────────────────
def get_sst(target_date, roi):
    t1 = ee.Date(target_date.isoformat())
    t2 = t1.advance(1, 'day')
    img = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
           .select('sst').filterDate(t1, t2).filterBounds(roi).first())
    return img.multiply(0.01).clip(roi).rename('sst')


# ── SST Anomaly = SST - daily climatology ────────────────────────────────────
def get_anomaly(sst, target_date, dc_image, roi):
    doy = target_date.timetuple().tm_yday   # 1-based
    doy = min(doy, 366)
    band_name = f'dc_{doy:03d}'
    dc = dc_image.select(band_name).rename('dc_sst')
    return sst.subtract(dc).rename('sst_anomaly')


# ── DHW = Σ(HS/7) over 84-day window, HS ≥ 1°C ─────────────────────────────
def get_dhw(target_date, mmm, roi):
    t_end = ee.Date(target_date.isoformat()).advance(1, 'day')
    t_start = ee.Date(target_date.isoformat()).advance(
        -(DHW_WINDOW - 1), 'day')

    hs_coll = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
               .select('sst')
               .filterDate(t_start, t_end)
               .filterBounds(roi)
               .map(lambda img: img.multiply(0.01)
                    .subtract(mmm).max(0)
                    .rename('hotspot').clip(roi)))

    # Only HS ≥ 1°C contributes
    thresholded = hs_coll.map(
        lambda img: img.updateMask(img.gte(HS_THRESHOLD)).unmask(0))

    return thresholded.sum().divide(7).rename('dhw')


# ── Export a single image as COG to GCS ──────────────────────────────────────
def export_cog(image, product, target_date, roi):
    date_str = target_date.strftime('%Y%m%d')
    file_path = f'{product}/{target_date.year}/{date_str}'

    task = ee.batch.Export.image.toCloudStorage(
        image=image.toFloat(),
        description=f'{product}_{date_str}',
        bucket=GCS_BUCKET,
        fileNamePrefix=file_path,
        region=roi,
        scale=SCALE,
        maxPixels=1e8,
        formatOptions={'cloudOptimized': True}
    )
    task.start()
    return task.status()['id']


# ── Compute GBR-wide summary stats ──────────────────────────────────────────
def compute_summary(sst, anomaly, dhw, target_date, roi):
    """
    Compute spatial mean, stdDev, count, and 95% CI for each product.
    95% CI = mean ± 1.96 × (stdDev / √n)
    """
    combined = (sst.rename('sst')
                .addBands(anomaly.rename('anomaly'))
                .addBands(dhw.rename('dhw')))

    stats = combined.reduceRegion(
        reducer=(ee.Reducer.mean()
                 .combine(ee.Reducer.stdDev(), sharedInputs=True)
                 .combine(ee.Reducer.count(), sharedInputs=True)),
        geometry=roi,
        scale=SCALE,
        maxPixels=1e8
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
            for suffix in ['mean', 'std', 'ci95_lower', 'ci95_upper']:
                row[f'{var}_{suffix}'] = None
            row[f'{var}_n_pixels'] = 0

    return row


def save_to_bigquery(row):
    client = bigquery.Client(project=GEE_PROJECT)
    errors = client.insert_rows_json(BQ_TABLE, [row])
    if errors:
        raise RuntimeError(f'BigQuery insert errors: {errors}')


# ── Cloud Function entry point ───────────────────────────────────────────────
@functions_framework.http
def process_daily_http(request):
    """HTTP trigger entry point (for testing)."""
    params = request.get_json(silent=True) or {}
    target_str = params.get('date')
    target = (date.fromisoformat(target_str) if target_str
              else date.today() - timedelta(days=1))
    return _run(target)


@functions_framework.cloud_event
def process_daily(cloud_event):
    """Pub/Sub trigger entry point (production)."""
    # Extract optional date from Pub/Sub message
    target = date.today() - timedelta(days=1)  # default: yesterday

    if cloud_event.data and 'message' in cloud_event.data:
        msg_data = cloud_event.data['message'].get('data', '')
        if msg_data:
            try:
                payload = json.loads(base64.b64decode(msg_data))
                if 'date' in payload:
                    target = date.fromisoformat(payload['date'])
            except (json.JSONDecodeError, ValueError):
                pass

    return _run(target)


def _run(target_date):
    """Core logic: compute products, export, save stats."""
    print(f'[DHW Pipeline] Processing {target_date.isoformat()}')

    init_ee()
    roi = ee.Geometry.Rectangle(ROI_COORDS)

    # Check data availability (OISST has ~1 day latency)
    if not data_available(target_date, roi):
        prev = target_date - timedelta(days=1)
        print(f'  No data for {target_date}, trying {prev}')
        if data_available(prev, roi):
            target_date = prev
        else:
            msg = f'No OISST data available for {target_date} or {prev}'
            print(f'  {msg}')
            return msg

    # Load pre-computed climatology
    mmm, dc_image = load_climatology(roi)

    # Compute products
    sst = get_sst(target_date, roi)
    anomaly = get_anomaly(sst, target_date, dc_image, roi)
    dhw = get_dhw(target_date, mmm, roi)

    # Export COGs to GCS (async — tasks run on GEE servers)
    task_ids = [
        export_cog(sst, 'sst', target_date, roi),
        export_cog(anomaly, 'sst_anomaly', target_date, roi),
        export_cog(dhw, 'dhw', target_date, roi),
    ]
    print(f'  Started 3 GEE export tasks: {task_ids}')

    # Compute and save GBR-wide summary (synchronous)
    row = compute_summary(sst, anomaly, dhw, target_date, roi)
    print(f'  GBR summary: SST={row["sst_mean"]}°C  '
          f'Anom={row["anomaly_mean"]}°C  '
          f'DHW={row["dhw_mean"]}°C-wk')

    try:
        save_to_bigquery(row)
        print(f'  Saved to BigQuery: {BQ_TABLE}')
    except Exception as e:
        print(f'  BigQuery error: {e}')
        # Fall back: print as JSON so Cloud Logging captures it
        print(f'  SUMMARY_JSON: {json.dumps(row)}')

    return json.dumps({
        'date': target_date.isoformat(),
        'tasks': task_ids,
        'summary': row
    })
