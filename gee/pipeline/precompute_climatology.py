"""
precompute_climatology.py
=========================
One-time script: compute MM, MMM, and 366-day Daily Climatology
and export them as Earth Engine assets for the daily pipeline to load.

Run this ONCE before deploying the Cloud Function.

Usage:
    earthengine authenticate
    earthengine set_project your-project-id
    python precompute_climatology.py

Then wait for the 3 export tasks to finish in the GEE Tasks tab
or monitor via:
    earthengine task list
"""

import ee
import os
import time

# ── Config ───────────────────────────────────────────────────────────────────
GEE_PROJECT = os.environ.get('GEE_PROJECT', 'your-gee-project')  # ← change
ASSET_FOLDER = f'projects/{GEE_PROJECT}/assets/coral_dhw'

ROI_COORDS = [141.0958, -24.70584, 153.2032, -8.926405]
CLIM_START = 1985
CLIM_END = 2012
TARGET_YEAR = 1988.2857
SCALE = 27830

# ── Initialize ───────────────────────────────────────────────────────────────
ee.Initialize(project=GEE_PROJECT)
roi = ee.Geometry.Rectangle(ROI_COORDS)

# Create asset folder if it doesn't exist
try:
    ee.data.createFolder(ASSET_FOLDER)
    print(f'Created asset folder: {ASSET_FOLDER}')
except ee.EEException:
    print(f'Asset folder exists: {ASSET_FOLDER}')


# ── Compute MM for one month ────────────────────────────────────────────────
def compute_mm_for_month(month):
    month_ee = ee.Number(month)
    years = ee.List.sequence(CLIM_START, CLIM_END)

    def yearly_mean(year):
        year = ee.Number(year)
        t1 = ee.Date.fromYMD(year, month_ee, 1)
        t2 = t1.advance(1, 'month')
        mean_sst = (ee.ImageCollection('NOAA/CDR/OISST/V2_1')
                     .select('sst').filterDate(t1, t2).filterBounds(roi)
                     .mean().multiply(0.01))
        return (mean_sst
                .addBands(ee.Image.constant(1).rename('constant').toFloat())
                .addBands(ee.Image.constant(year).rename('year').toFloat())
                .rename(['sst', 'constant', 'year'])
                .set('year', year))

    coll = ee.ImageCollection(years.map(yearly_mean))
    reg = (coll.select(['constant', 'year', 'sst'])
           .reduce(ee.Reducer.linearRegression(numX=2, numY=1)))
    coef = (reg.select('coefficients').arrayProject([0])
            .arrayFlatten([['intercept', 'slope']]))
    return (coef.select('intercept')
            .add(coef.select('slope').multiply(TARGET_YEAR))
            .rename('mm_sst').toFloat())


# ── Build all climatology products ───────────────────────────────────────────
print('Computing 12 Monthly Means ...')
mm_bands = [compute_mm_for_month(m) for m in range(1, 13)]

# MM multi-band (12 bands: mm_01 ... mm_12)
mm_renamed = [mm_bands[i].rename(f'mm_{i+1:02d}') for i in range(12)]
mm_image = ee.Image.cat(mm_renamed).clip(roi)

# MMM (single band)
mmm_image = mm_image.reduce(ee.Reducer.max()).rename('mmm_sst')

# Daily Climatology (366 bands via linear interpolation)
print('Interpolating 366-day Daily Climatology ...')
anchor_doys = [15, 46, 74, 105, 135, 166, 196, 227, 258, 288, 319, 349]
anchor_ext = [-16] + anchor_doys + [380]
month_idx = [11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0]

dc_list = []
for doy in range(1, 367):
    lo = 0
    for k in range(len(anchor_ext) - 1):
        if anchor_ext[k] <= doy < anchor_ext[k + 1]:
            lo = k
            break
    frac = (doy - anchor_ext[lo]) / (anchor_ext[lo + 1] - anchor_ext[lo])
    mm_lo = mm_bands[month_idx[lo]]
    mm_hi = mm_bands[month_idx[lo + 1]]
    dc = mm_lo.add(mm_hi.subtract(mm_lo).multiply(frac)).rename(f'dc_{doy:03d}')
    dc_list.append(dc)

dc_image = ee.Image.cat(dc_list).clip(roi)


# ── Export as EE Assets ──────────────────────────────────────────────────────
def export_asset(image, name, description):
    asset_id = f'{ASSET_FOLDER}/{name}'
    print(f'  Exporting: {asset_id}')
    task = ee.batch.Export.image.toAsset(
        image=image.toFloat(),
        description=description,
        assetId=asset_id,
        region=roi,
        scale=SCALE,
        maxPixels=1e10
    )
    task.start()
    return task


tasks = [
    export_asset(mm_image, 'mm_climatology', 'MM_Climatology_12bands'),
    export_asset(mmm_image, 'mmm_climatology', 'MMM_Climatology'),
    export_asset(dc_image, 'daily_climatology', 'Daily_Climatology_366bands'),
]

print(f'\nStarted {len(tasks)} export tasks.')
print(f'Monitor at: https://code.earthengine.google.com/tasks')
print(f'Or run: earthengine task list\n')

# ── Poll until complete ──────────────────────────────────────────────────────
print('Waiting for exports to complete ...')
while True:
    statuses = [t.status()['state'] for t in tasks]
    print(f'  Status: {statuses}')

    if all(s == 'COMPLETED' for s in statuses):
        print('\n✓ All exports completed successfully!')
        print(f'  MM:  {ASSET_FOLDER}/mm_climatology')
        print(f'  MMM: {ASSET_FOLDER}/mmm_climatology')
        print(f'  DC:  {ASSET_FOLDER}/daily_climatology')
        break
    elif any(s == 'FAILED' for s in statuses):
        for t in tasks:
            s = t.status()
            if s['state'] == 'FAILED':
                print(f'  FAILED: {s["description"]} — {s.get("error_message", "")}')
        break

    time.sleep(30)
