# GBR Coral Bleaching Heat Stress — Automated Pipeline

Daily SST, SST Anomaly, and DHW for the Great Barrier Reef,
computed from NOAA OISST on Google Earth Engine, exported
automatically to Google Cloud Storage as COGs.

## Architecture

```
Cloud Scheduler (12:00 UTC daily)
       │
       ▼
Cloud Function (pipeline/main.py)
       │
       ├──► GCS bucket (Cloud Optimized GeoTIFFs)
       │      gs://bucket/sst/2024/20240315.tif
       │      gs://bucket/sst_anomaly/2024/20240315.tif
       │      gs://bucket/dhw/2024/20240315.tif
       │
       └──► BigQuery (daily_summary table)
              date | sst_mean | sst_ci95_lower | sst_ci95_upper
                   | anomaly_mean | ... | dhw_mean | ...
```

## File structure

```
precompute_climatology.py   ← Run ONCE to create EE assets (MM, MMM, DC)
pipeline/
  main.py                   ← Cloud Function (daily processing)
  requirements.txt          ← Python deps for Cloud Function
backfill.py                 ← Process historical date ranges locally
deploy.sh                   ← One-command GCP deployment
SETUP_GUIDE.md              ← Detailed step-by-step instructions
01–05_*.js                  ← Interactive GEE Code Editor scripts
```

## Quick start

### 1. Pre-compute climatology (once)

```bash
pip install earthengine-api
earthengine authenticate
export GEE_PROJECT="your-project-id"

python precompute_climatology.py
# Wait ~10 min for EE export tasks to finish
```

### 2. Deploy the daily pipeline

```bash
# Edit PROJECT_ID and BUCKET in deploy.sh, then:
chmod +x deploy.sh
./deploy.sh
```

### 3. Test

```bash
# Trigger manually
gcloud scheduler jobs run daily-dhw-trigger --location=australia-southeast1

# Check results
gsutil ls gs://coral-dhw-gbr/dhw/
bq query --nouse_legacy_sql 'SELECT * FROM coral_dhw.daily_summary ORDER BY date DESC LIMIT 5'
```

### 4. Backfill historical data

```bash
python backfill.py --start 2024-01-01 --end 2024-12-31
python backfill.py --annual-max 2024
```

## Cost: ~$0/month

All usage falls within GCP free tiers. The GBR ROI is ~3,000 pixels
at 0.25° — each daily COG is ~12 KB, totalling ~13 MB/year.
