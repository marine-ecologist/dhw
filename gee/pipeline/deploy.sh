#!/bin/bash
# deploy.sh — Deploy the daily DHW pipeline to Google Cloud
#
# Edit the variables below, then run:
#   chmod +x deploy.sh && ./deploy.sh
set -euo pipefail

# ═══════════════════════════════════════════════
# Set these via environment variables, e.g.:
#   export GEE_PROJECT="oisst-dhw"
#   export GCS_BUCKET="coral-dhw-gbr"
#   ./deploy.sh
# ═══════════════════════════════════════════════
PROJECT_ID="${GEE_PROJECT:?Set GEE_PROJECT first, e.g. export GEE_PROJECT=oisst-dhw}"
# GCP project IDs must be lowercase
PROJECT_ID=$(echo "$PROJECT_ID" | tr '[:upper:]' '[:lower:]')
REGION="australia-southeast1"
BUCKET="${GCS_BUCKET:-coral-dhw-gbr}"
SA_NAME="dhw-pipeline"
# ═══════════════════════════════════════════════

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== 1. Set project and enable APIs ==="
echo "  Using project: ${PROJECT_ID}"
gcloud config set project $PROJECT_ID

gcloud services enable \
  earthengine.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudscheduler.googleapis.com \
  pubsub.googleapis.com \
  cloudbuild.googleapis.com \
  bigquery.googleapis.com \
  storage.googleapis.com \
  run.googleapis.com

echo "=== 2. Service account ==="
gcloud iam service-accounts create $SA_NAME \
  --display-name="DHW Pipeline" 2>/dev/null || echo "SA exists."

for ROLE in roles/earthengine.admin roles/storage.objectAdmin \
            roles/bigquery.dataEditor roles/bigquery.jobUser; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" --role="${ROLE}" \
    --quiet
done

echo "=== 3. GCS bucket ==="
gsutil mb -p $PROJECT_ID -l $REGION "gs://${BUCKET}/" 2>/dev/null \
  || echo "Bucket exists."

echo "=== 4. BigQuery table ==="
bq mk --dataset --location=$REGION \
  ${PROJECT_ID}:coral_dhw 2>/dev/null || echo "Dataset exists."

bq mk --table ${PROJECT_ID}:coral_dhw.daily_summary \
  date:DATE,\
sst_mean:FLOAT,sst_std:FLOAT,sst_ci95_lower:FLOAT,sst_ci95_upper:FLOAT,sst_n_pixels:INTEGER,\
anomaly_mean:FLOAT,anomaly_std:FLOAT,anomaly_ci95_lower:FLOAT,anomaly_ci95_upper:FLOAT,anomaly_n_pixels:INTEGER,\
dhw_mean:FLOAT,dhw_std:FLOAT,dhw_ci95_lower:FLOAT,dhw_ci95_upper:FLOAT,dhw_n_pixels:INTEGER \
  2>/dev/null || echo "Table exists."

echo "=== 5. Pub/Sub topic ==="
gcloud pubsub topics create dhw-daily-trigger 2>/dev/null \
  || echo "Topic exists."

echo "=== 6. Deploy Cloud Function ==="
# Find the pipeline/ directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "${SCRIPT_DIR}/pipeline" ]; then
  FUNC_SOURCE="${SCRIPT_DIR}/pipeline"
elif [ -f "${SCRIPT_DIR}/main.py" ]; then
  FUNC_SOURCE="${SCRIPT_DIR}"
else
  echo "ERROR: Cannot find pipeline/main.py. Run from the project root."
  exit 1
fi
echo "  Deploying from: ${FUNC_SOURCE}"

gcloud functions deploy daily-dhw-pipeline \
  --gen2 \
  --region=$REGION \
  --runtime=python311 \
  --source=$FUNC_SOURCE \
  --entry-point=process_daily \
  --trigger-topic=dhw-daily-trigger \
  --memory=512MB \
  --timeout=300s \
  --set-env-vars="GCS_BUCKET=${BUCKET},GEE_PROJECT=${PROJECT_ID},BQ_TABLE=${PROJECT_ID}.coral_dhw.daily_summary" \
  --service-account=$SA_EMAIL

echo "=== 7. Cloud Scheduler (daily 12:00 UTC) ==="
gcloud scheduler jobs create pubsub daily-dhw-trigger \
  --location=$REGION \
  --schedule="0 12 * * *" \
  --topic=dhw-daily-trigger \
  --message-body='{}' \
  --time-zone="UTC" 2>/dev/null || echo "Scheduler exists."

echo ""
echo "═══════════════════════════════════════════════"
echo "✓ Deployment complete!"
echo ""
echo "Test:   gcloud scheduler jobs run daily-dhw-trigger --location=$REGION"
echo "Logs:   gcloud functions logs read daily-dhw-pipeline --region=$REGION"
echo "GCS:    gsutil ls gs://${BUCKET}/"
echo "BQ:     bq query 'SELECT * FROM coral_dhw.daily_summary ORDER BY date DESC LIMIT 5'"
echo "═══════════════════════════════════════════════"