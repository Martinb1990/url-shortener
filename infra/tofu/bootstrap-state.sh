#!/usr/bin/env bash
# One-time: create the versioned GCS bucket that holds OpenTofu state,
# and write backend.hcl pointing at it. Idempotent.
#   ./bootstrap-state.sh <project-id>
set -euo pipefail

PROJECT="${1:?usage: $0 <project-id>}"
BUCKET="${PROJECT}-tfstate"
# us-central1 sits in Cloud Storage's Always Free tier (5 GB); state is a few KB.
LOCATION="us-central1"

cd "$(dirname "$0")"

if gcloud storage buckets describe "gs://$BUCKET" --project "$PROJECT" >/dev/null 2>&1; then
  echo "Bucket gs://$BUCKET already exists"
else
  gcloud storage buckets create "gs://$BUCKET" \
    --project "$PROJECT" \
    --location "$LOCATION" \
    --default-storage-class STANDARD \
    --uniform-bucket-level-access \
    --public-access-prevention
fi
# Versioning lets you roll back a corrupted or bad state file.
gcloud storage buckets update "gs://$BUCKET" --versioning >/dev/null

echo "bucket = \"$BUCKET\"" > backend.hcl
echo "Wrote backend.hcl. Next: tofu init -backend-config=backend.hcl"
