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
GCS_BUCKET = os.environ.get('GCS_BUCKET', 'YOUR-GCS-BUCKET')
GEE_PROJECT = os.environ.get('GEE_PROJECT', 'YOUR-GEE-PROJECT')
BQ_TABLE = os.environ.get(
    'BQ_TABLE', f'{GEE_PROJECT}.coral_dhw.daily_summary')

ROI_ASSET = f'projects/{GEE_PROJECT}/assets/coral_dhw/gbr_polygon'  # kept for legacy
MASK_ASSET = f'projects/{GEE_PROJECT}/assets/coral_dhw/gbr_mask'
REEF_ASSET = f'projects/{GEE_PROJECT}/assets/coral_dhw/gbr_reefs'
ASSET_FOLDER = f'projects/{GEE_PROJECT}/assets/coral_dhw'

BQ_REEF_TABLE = os.environ.get(
    'BQ_REEF_TABLE', f'{GEE_PROJECT}.coral_dhw.reef_daily')

DHW_WINDOW = 84       # days (12 weeks)
HS_THRESHOLD = 1.0    # °C — only HS ≥ 1 contributes to DHW

# ── Grid specification (matches R gbr_mask raster exactly) ───────────────────
# R raster: 64 rows × 48 cols, 0.25° resolution
# extent: xmin=141, xmax=153, ymin=-24.75, ymax=-8.75
# CRS: EPSG:4326 (WGS 84)
# Mask: 1 = ocean pixel to use, 0 = land/outside GBR
EXPORT_CRS = 'EPSG:4326'
EXPORT_CRS_TRANSFORM = [0.25, 0, 141, 0, -0.25, -8.75]  # [xRes, 0, xMin, 0, -yRes, yMax]
EXPORT_BOUNDS = [141, -24.75, 153, -8.75]                  # [xmin, ymin, xmax, ymax]
SCALE = 27830  # metres (~0.25°), used only for reduceRegion


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


# ── Load pre-computed climatology and mask from EE assets ─────────────────────
def load_climatology():
    """
    Load MMM, daily climatology, and binary ocean mask.

    Returns (mmm, dc_image, mask):
        mmm:      ee.Image, single band 'mmm_sst'
        dc_image: ee.Image, 366 bands 'dc_001' ... 'dc_366'
        mask:     ee.Image, binary (1=ocean, 0=land/outside GBR)
    """
    mmm = ee.Image(f'{ASSET_FOLDER}/mmm_climatology')
    dc_image = ee.Image(f'{ASSET_FOLDER}/daily_climatology')
    mask = ee.Image(MASK_ASSET).selfMask()  # 0→NoData, 1→valid
    return mmm, dc_image, mask


# ── Check if OISST data exists for a date ────────────────────────────────────
def data_available(target_date, bbox):
    t1 = ee.Date(target_date.isoformat())
    t2 = t1.advance(1, 'day')
    count = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
             .filterDate(t1, t2).filterBounds(bbox).size().getInfo())
    return count > 0


# ── Get raw SST for a date ───────────────────────────────────────────────────
def get_sst(target_date, bbox, mask):
    t1 = ee.Date(target_date.isoformat())
    t2 = t1.advance(1, 'day')
    img = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
           .select('sst').filterDate(t1, t2).filterBounds(bbox).first())
    return img.multiply(0.01).updateMask(mask).rename('sst')


# ── SST Anomaly = SST - daily climatology ────────────────────────────────────
def get_anomaly(sst, target_date, dc_image):
    doy = target_date.timetuple().tm_yday   # 1-based
    doy = min(doy, 366)
    band_name = f'dc_{doy:03d}'
    dc = dc_image.select(band_name).rename('dc_sst')
    return sst.subtract(dc).rename('sst_anomaly')


# ── HotSpot = max(SST - MMM, 0) ─────────────────────────────────────────────
def get_hotspot(sst, mmm):
    return sst.subtract(mmm).max(0).rename('hotspot')


# ── DHW = Σ(HS/7) over 84-day window, HS ≥ 1°C ─────────────────────────────
def get_dhw(target_date, mmm, bbox, mask):
    t_end = ee.Date(target_date.isoformat()).advance(1, 'day')
    t_start = ee.Date(target_date.isoformat()).advance(
        -(DHW_WINDOW - 1), 'day')

    hs_coll = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
               .select('sst')
               .filterDate(t_start, t_end)
               .filterBounds(bbox)
               .map(lambda img: img.multiply(0.01)
                    .subtract(mmm).max(0)
                    .rename('hotspot').updateMask(mask)))

    thresholded = hs_coll.map(
        lambda img: img.updateMask(img.gte(HS_THRESHOLD)).unmask(0))

    return thresholded.sum().divide(7).updateMask(mask).rename('dhw')


# ── BAA = Bleaching Alert Area classification ───────────────────────────────
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


# ── Export 5-band daily COG to GCS ───────────────────────────────────────────
def export_daily_cog(sst, anomaly, hotspot, dhw, baa, target_date, export_region):
    """Export single 5-band COG: sst, sst_anomaly, hotspot, dhw, baa."""
    date_str = target_date.strftime('%Y%m%d')
    file_path = f'rasters/{target_date.year}/{date_str}'

    combined = (sst.toFloat().rename('sst')
                .addBands(anomaly.toFloat().rename('sst_anomaly'))
                .addBands(hotspot.toFloat().rename('hotspot'))
                .addBands(dhw.toFloat().rename('dhw'))
                .addBands(baa.toFloat().rename('baa')))

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


# ── Compute GBR-wide summary stats ──────────────────────────────────────────
def compute_summary(sst, anomaly, hotspot, dhw, target_date, bbox):
    """
    Compute spatial mean, stdDev, count, and 95% CI for each product.
    95% CI = mean ± 1.96 × (stdDev / √n)
    """
    combined = (sst.rename('sst')
                .addBands(anomaly.rename('sst_anomaly'))
                .addBands(hotspot.rename('hotspot'))
                .addBands(dhw.rename('dhw')))

    stats = combined.reduceRegion(
        reducer=(ee.Reducer.mean()
                 .combine(ee.Reducer.stdDev(), sharedInputs=True)
                 .combine(ee.Reducer.count(), sharedInputs=True)),
        geometry=bbox,
        scale=SCALE,
        maxPixels=1e8
    ).getInfo()

    row = {'date': target_date.isoformat()}

    for var in ['sst', 'sst_anomaly', 'hotspot', 'dhw']:
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


# ── Reef-level extraction ────────────────────────────────────────────────────
def extract_reef_means(sst, anomaly, hotspot, dhw, target_date, reef_fc):
    """
    Compute area-weighted mean of each product for every reef polygon.
    BAA is derived from reef-level HS and DHW means.
    Returns list of dicts (LABEL_ID + 5 values).
    """
    combined = (sst.rename('sst')
                .addBands(anomaly.rename('sst_anomaly'))
                .addBands(hotspot.rename('hotspot'))
                .addBands(dhw.rename('dhw')))

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


def save_reef_to_bigquery(rows, target_date):
    """Insert reef-level rows into BigQuery reef_daily table."""
    date_str = target_date.isoformat()
    bq_rows = [{'date': date_str, **r} for r in rows]
    client = bigquery.Client(project=GEE_PROJECT)
    errors = client.insert_rows_json(BQ_REEF_TABLE, bq_rows)
    if errors:
        raise RuntimeError(f'BigQuery reef insert errors: {errors[:3]}')


def save_reef_csv_to_gcs(rows, target_date):
    """
    Save reef means as compact CSV to GCS.
    Path: gs://bucket/reef_daily/{year}/{YYYYMMDD}.csv
    Columns: LABEL_ID,sst,sst_anomaly,hotspot,dhw,baa
    """
    from google.cloud import storage
    import csv
    import io

    date_str = target_date.strftime('%Y%m%d')
    blob_path = f'reef_daily/{target_date.year}/{date_str}.csv'

    buf = io.StringIO()
    writer = csv.DictWriter(buf,
                            fieldnames=['LABEL_ID', 'sst', 'sst_anomaly',
                                        'hotspot', 'dhw', 'baa'])
    writer.writeheader()
    writer.writerows(rows)

    client = storage.Client(project=GEE_PROJECT)
    bucket = client.bucket(GCS_BUCKET)
    blob = bucket.blob(blob_path)
    blob.upload_from_string(buf.getvalue(), content_type='text/csv')
    return blob_path



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

    # Bounding box for spatial filters and exports; mask for pixel selection
    bbox = ee.Geometry.Rectangle(EXPORT_BOUNDS)
    export_region = bbox

    # Check data availability (OISST has ~1 day latency)
    if not data_available(target_date, bbox):
        prev = target_date - timedelta(days=1)
        print(f'  No data for {target_date}, trying {prev}')
        if data_available(prev, bbox):
            target_date = prev
        else:
            msg = f'No OISST data available for {target_date} or {prev}'
            print(f'  {msg}')
            return msg

    # Load pre-computed climatology + mask
    mmm, dc_image, mask = load_climatology()

    # Compute products (masked to GBR ocean pixels)
    sst = get_sst(target_date, bbox, mask)
    anomaly = get_anomaly(sst, target_date, dc_image)
    hotspot = get_hotspot(sst, mmm)
    dhw = get_dhw(target_date, mmm, bbox, mask)
    baa = get_baa(hotspot, dhw)

    # Export single 5-band COG (sst, sst_anomaly, hotspot, dhw, baa)
    task_id = export_daily_cog(sst, anomaly, hotspot, dhw, baa,
                               target_date, export_region)
    print(f'  Started GEE export task: {task_id}')

    # Compute and save GBR-wide summary (synchronous)
    row = compute_summary(sst, anomaly, hotspot, dhw, target_date, bbox)
    print(f'  GBR summary: SST={row["sst_mean"]}°C  '
          f'Anom={row["sst_anomaly_mean"]}°C  '
          f'HS={row["hotspot_mean"]}°C  '
          f'DHW={row["dhw_mean"]}°C-wk')

    try:
        save_to_bigquery(row)
        print(f'  Saved to BigQuery: {BQ_TABLE}')
    except Exception as e:
        print(f'  BigQuery error: {e}')
        print(f'  SUMMARY_JSON: {json.dumps(row)}')

    # ── Reef-level extraction ────────────────────────────────────────────────
    try:
        reef_fc = ee.FeatureCollection(REEF_ASSET)
        reef_count = reef_fc.size().getInfo()
        print(f'  Extracting means for {reef_count} reefs ...')

        reef_rows = extract_reef_means(
            sst, anomaly, hotspot, dhw, target_date, reef_fc)
        print(f'  Extracted {len(reef_rows)} reef rows')

        # Save to BigQuery
        try:
            save_reef_to_bigquery(reef_rows, target_date)
            print(f'  Reef data saved to BigQuery: {BQ_REEF_TABLE}')
        except Exception as e:
            print(f'  Reef BigQuery error: {e}')

        # Save daily CSV to GCS
        csv_path = save_reef_csv_to_gcs(reef_rows, target_date)
        print(f'  Reef CSV saved to gs://{GCS_BUCKET}/{csv_path}')

    except Exception as e:
        print(f'  Reef extraction error: {e}')
        reef_rows = []

    return json.dumps({
        'date': target_date.isoformat(),
        'task': task_id,
        'summary': row,
        'reef_count': len(reef_rows)
    })