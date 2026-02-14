"""
upload_polygon.py — Upload a GeoJSON/Shapefile as an Earth Engine table asset.

For small files (<100 features): builds ee.FeatureCollection client-side.
For large files (≥100 features): stages via GCS, then ingests into EE.

Usage:
    python upload_polygon.py <file> [asset_name]

Examples:
    python upload_polygon.py gbr.geojson gbr_polygon         # 1 feature, fast
    python upload_polygon.py gbr_reefs.geojson gbr_reefs     # 4,658 features, via GCS

Overwrites existing assets automatically.

Prerequisites:
    pip install earthengine-api google-cloud-storage
"""

import ee
import json
import sys
import os
import time
import subprocess

GEE_PROJECT = os.environ.get('GEE_PROJECT', 'YOUR-GEE-PROJECT')
GCS_BUCKET = os.environ.get('GCS_BUCKET', 'YOUR-GCS-BUCKET')
ASSET_FOLDER = f'projects/{GEE_PROJECT}/assets/coral_dhw'

SMALL_THRESHOLD = 100  # features — above this, use GCS staging


def init():
    ee.Initialize(project=GEE_PROJECT)


def delete_asset_if_exists(asset_id):
    try:
        ee.data.deleteAsset(asset_id)
        print(f'  Deleted existing asset: {asset_id}')
    except ee.EEException:
        pass


def ensure_folder():
    try:
        ee.data.createFolder(ASSET_FOLDER)
    except ee.EEException:
        pass


def wait_for_task(task):
    """Poll task until completed or failed."""
    print('Waiting for upload ...')
    while True:
        status = task.status()
        state = status['state']
        print(f'  {state}')
        if state == 'COMPLETED':
            return True
        elif state == 'FAILED':
            print(f'  Error: {status.get("error_message", "")}')
            return False
        time.sleep(5)


def wait_for_operation(op_name):
    """Poll an EE operation by name until done."""
    print('Waiting for ingestion ...')
    while True:
        op = ee.data.getOperation(op_name)
        state = op['metadata']['state']
        print(f'  {state}')
        if state == 'SUCCEEDED':
            return True
        elif state in ('FAILED', 'CANCELLED'):
            print(f'  Error: {op.get("error", {}).get("message", "")}')
            return False
        time.sleep(5)


# ═════════════════════════════════════════════════════════════════════════════
# Method 1: Small files — client-side ee.FeatureCollection
# ═════════════════════════════════════════════════════════════════════════════

def upload_small(features, asset_id, asset_name):
    """Upload via ee.batch.Export.table.toAsset (< ~100 features)."""
    ee_features = []
    for feat in features:
        geom_type = feat['geometry']['type']
        coords = feat['geometry']['coordinates']

        if geom_type == 'Polygon':
            ee_geom = ee.Geometry.Polygon(coords)
        elif geom_type == 'MultiPolygon':
            ee_geom = ee.Geometry.MultiPolygon(coords)
        elif geom_type == 'Point':
            ee_geom = ee.Geometry.Point(coords)
        else:
            print(f'  Skipping unsupported geometry: {geom_type}')
            continue

        props = feat.get('properties', {}) or {}
        ee_features.append(ee.Feature(ee_geom, props))

    fc = ee.FeatureCollection(ee_features)
    print(f'  Built FeatureCollection with {len(ee_features)} features')

    task = ee.batch.Export.table.toAsset(
        collection=fc,
        description=f'{asset_name}_upload',
        assetId=asset_id
    )
    task.start()
    return wait_for_task(task)


# ═════════════════════════════════════════════════════════════════════════════
# Method 2: Large files — upload to GCS, then ingest into EE
# ═════════════════════════════════════════════════════════════════════════════

def upload_large_via_gcs(geojson_path, asset_id, asset_name):
    """Upload large GeoJSON by staging through GCS."""
    from google.cloud import storage

    gcs_path = f'tmp/{asset_name}.geojson'
    print(f'  Uploading to gs://{GCS_BUCKET}/{gcs_path} ...')

    client = storage.Client(project=GEE_PROJECT)
    bucket = client.bucket(GCS_BUCKET)
    blob = bucket.blob(gcs_path)
    blob.upload_from_filename(geojson_path)
    print(f'  Uploaded ({blob.size / 1024 / 1024:.1f} MB)')

    # Ingest from GCS into EE
    print(f'  Ingesting into EE: {asset_id}')
    request = {
        'id': asset_id,
        'sources': [{'uris': [f'gs://{GCS_BUCKET}/{gcs_path}']}]
    }

    try:
        task_id = ee.data.newTaskId()[0]
        ee.data.startTableIngestion(task_id, request, allow_overwrite=True)

        # Poll the operation
        op_name = f'projects/{GEE_PROJECT}/operations/{task_id}'
        success = wait_for_operation(op_name)
    except Exception as e:
        print(f'  Python ingestion failed ({e}), trying CLI ...')
        success = upload_large_via_cli(geojson_path, asset_id)

    # Clean up GCS staging file
    try:
        blob.delete()
        print(f'  Cleaned up gs://{GCS_BUCKET}/{gcs_path}')
    except Exception:
        pass

    return success


def upload_large_via_cli(geojson_path, asset_id):
    """Fallback: use earthengine CLI to upload."""
    print(f'  Using earthengine CLI ...')
    cmd = [
        'earthengine', 'upload', 'table',
        f'--asset_id={asset_id}',
        '--force',
        geojson_path
    ]
    print(f'  Running: {" ".join(cmd)}')
    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f'  CLI error: {result.stderr}')
        return False

    print(f'  CLI output: {result.stdout.strip()}')

    # CLI starts an async task — wait for it
    print('  Waiting for CLI upload task ...')
    for _ in range(360):  # max 30 minutes
        tasks = ee.data.getTaskList()
        upload_tasks = [t for t in tasks
                        if 'upload' in t.get('description', '').lower()
                        and t['state'] in ('READY', 'RUNNING')]
        if not upload_tasks:
            # Check if completed
            recent = [t for t in tasks
                      if t['state'] == 'COMPLETED'
                      and 'upload' in t.get('description', '').lower()]
            if recent:
                return True
            break
        time.sleep(5)

    return True


# ═════════════════════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: python upload_polygon.py <geojson_file> [asset_name]')
        sys.exit(1)

    geojson_path = sys.argv[1]
    asset_name = sys.argv[2] if len(sys.argv) > 2 else 'gbr_polygon'
    asset_id = f'{ASSET_FOLDER}/{asset_name}'

    # Read file to count features
    with open(geojson_path) as f:
        gj = json.load(f)

    features = gj.get('features', [])
    n_features = len(features)

    # Report properties from first feature
    if features:
        props = list((features[0].get('properties', {}) or {}).keys())
        geom_type = features[0]['geometry']['type']
        print(f'File:       {geojson_path}')
        print(f'Features:   {n_features}')
        print(f'Geometry:   {geom_type}')
        print(f'Properties: {props}')
        print(f'Asset:      {asset_id}')
        print()

    # Init EE
    init()
    ensure_folder()
    delete_asset_if_exists(asset_id)

    # Choose method based on size
    if n_features < SMALL_THRESHOLD:
        print(f'Using client-side upload ({n_features} features) ...')
        success = upload_small(features, asset_id, asset_name)
    else:
        print(f'Using GCS-staged upload ({n_features} features) ...')
        success = upload_large_via_gcs(geojson_path, asset_id, asset_name)

    if success:
        print(f'\n✓ Asset created: {asset_id}')

        # Verify
        try:
            fc = ee.FeatureCollection(asset_id)
            count = fc.size().getInfo()
            first_props = fc.first().propertyNames().getInfo()
            print(f'  Verified: {count} features')
            print(f'  Properties: {first_props}')
        except Exception as e:
            print(f'  Verification skipped: {e}')
    else:
        print(f'\n✗ Upload failed. Try uploading via the Code Editor:')
        print(f'  https://code.earthengine.google.com/')
        print(f'  Assets → NEW → Table Upload → select your .shp files')
        print(f'  Set asset path to: {asset_id}')
