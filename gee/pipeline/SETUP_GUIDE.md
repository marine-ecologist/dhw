# Automated Daily DHW Pipeline — Setup Guide

## How it works

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Cloud Scheduler ──► Pub/Sub ──► Cloud Function (Python)   │
│   (daily 12:00 UTC)                    │                    │
│                                        │                    │
│                     ┌──────────────────┼──────────────┐     │
│                     │                  │              │     │
│                     ▼                  ▼              ▼     │
│              GCS Bucket          BigQuery         EE Tasks  │
│              (COG tiles)      (daily stats)    (async export)│
│                                                             │
│   gs://bucket/                                              │
│     sst/2024/20240315.tif          daily_summary table      │
│     sst_anomaly/2024/20240315.tif  date | sst_mean | ci95…  │
│     dhw/2024/20240315.tif                                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key detail:** GEE export tasks are *asynchronous*. The Cloud Function
kicks them off (takes ~2 seconds), then GEE's servers do the actual
processing and write the COGs to your GCS bucket (takes 1–5 minutes).
The summary stats are computed synchronously via `getInfo()` (~10 seconds).

## Prerequisites

- Google Cloud account with billing enabled
- `gcloud` CLI installed: https://cloud.google.com/sdk/docs/install
- Earth Engine access: https://earthengine.google.com/

## Step-by-step setup

### 1. Set your project and enable APIs

```bash
export PROJECT_ID="your-project-id"   # ← change this

gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable \
  earthengine.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudscheduler.googleapis.com \
  pubsub.googleapis.com \
  cloudbuild.googleapis.com \
  bigquery.googleapis.com \
  storage.googleapis.com \
  run.googleapis.com
```

### 2. Create a service account for Earth Engine

```bash
# Create service account
gcloud iam service-accounts create dhw-pipeline \
  --display-name="DHW Pipeline Service Account"

# Grant it the roles it needs
SA_EMAIL="dhw-pipeline@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/earthengine.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/bigquery.dataEditor"

# Register the SA with Earth Engine (one-time)
# Go to: https://code.earthengine.google.com/register
# Register as a Cloud Project, select your project
# Or use the API:
earthengine set_project $PROJECT_ID
```

### 3. Create GCS bucket

```bash
export BUCKET="coral-dhw-gbr"  # ← change this

gsutil mb -p $PROJECT_ID -l australia-southeast1 gs://${BUCKET}/
```

### 4. Create BigQuery dataset and table

```bash
bq mk --dataset --location=australia-southeast1 \
  ${PROJECT_ID}:coral_dhw

bq mk --table ${PROJECT_ID}:coral_dhw.daily_summary \
  date:DATE,\
sst_mean:FLOAT,sst_std:FLOAT,sst_ci95_lower:FLOAT,sst_ci95_upper:FLOAT,sst_n_pixels:INTEGER,\
anomaly_mean:FLOAT,anomaly_std:FLOAT,anomaly_ci95_lower:FLOAT,anomaly_ci95_upper:FLOAT,anomaly_n_pixels:INTEGER,\
dhw_mean:FLOAT,dhw_std:FLOAT,dhw_ci95_lower:FLOAT,dhw_ci95_upper:FLOAT,dhw_n_pixels:INTEGER
```

### 5. One-time: export climatology as EE assets

The MM, MMM, and daily climatology are static (1985–2012). Compute them
once and save as EE assets so the daily function doesn't re-derive them.

```bash
# Run the one-time setup script
python precompute_climatology.py
```

This exports three assets:
- `projects/{PROJECT}/assets/coral_dhw/mm_climatology`
- `projects/{PROJECT}/assets/coral_dhw/mmm_climatology`
- `projects/{PROJECT}/assets/coral_dhw/daily_climatology`

Wait for the export tasks to complete (~5–15 min) before deploying
the daily function.

### 6. Deploy the Cloud Function

```bash
cd pipeline/

gcloud functions deploy daily-dhw-pipeline \
  --gen2 \
  --region=australia-southeast1 \
  --runtime=python311 \
  --source=. \
  --entry-point=process_daily \
  --trigger-topic=dhw-daily-trigger \
  --memory=512MB \
  --timeout=300s \
  --set-env-vars="GCS_BUCKET=${BUCKET},GEE_PROJECT=${PROJECT_ID}" \
  --service-account="dhw-pipeline@${PROJECT_ID}.iam.gserviceaccount.com"
```

### 7. Create Cloud Scheduler

```bash
# Create Pub/Sub topic
gcloud pubsub topics create dhw-daily-trigger

# Schedule: daily at 12:00 UTC (OISST updates by ~09:00 UTC)
gcloud scheduler jobs create pubsub daily-dhw-trigger \
  --location=australia-southeast1 \
  --schedule="0 12 * * *" \
  --topic=dhw-daily-trigger \
  --message-body='{}' \
  --time-zone="UTC"
```

### 8. Test it

```bash
# Manual trigger
gcloud scheduler jobs run daily-dhw-trigger \
  --location=australia-southeast1

# Check logs
gcloud functions logs read daily-dhw-pipeline \
  --region=australia-southeast1 --limit=50

# Check GCS for outputs
gsutil ls gs://${BUCKET}/sst/
gsutil ls gs://${BUCKET}/dhw/

# Check BigQuery
bq query --use_legacy_sql=false \
  "SELECT * FROM coral_dhw.daily_summary ORDER BY date DESC LIMIT 5"
```

### 9. Backfill historical data

```bash
python backfill.py --start 2024-01-01 --end 2024-12-31
```

## Cost estimate

| Service | Usage | Monthly cost |
|---------|-------|-------------|
| Cloud Scheduler | 1 job | Free |
| Pub/Sub | 30 msgs/month | Free |
| Cloud Function | 30 runs × ~30s × 512 MB | Free tier |
| GCS storage | ~13 MB/year | ~$0.003/year |
| BigQuery | 365 rows/year, <1 KB each | Free tier |
| Earth Engine | Computation + export | Free (non-commercial) |
| **Total** | | **~$0/month** |
