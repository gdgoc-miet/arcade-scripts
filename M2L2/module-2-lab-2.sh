#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "   🚀 Starting Module 2 — Lab 2 (Terraform + GCS Bucket)"
echo "=============================================================="
echo ""

# ------------------------------------------------------
# FETCH PROJECT ID + REGION + ZONE DYNAMICALLY
# ------------------------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")
ZONE=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

[[ -z "$REGION" ]] && REGION="us-central1"
[[ -z "$ZONE" ]] && ZONE="${REGION}-a"

echo "→ Project detected : $PROJECT_ID"
echo "→ Region detected  : $REGION"
echo "→ Zone detected    : $ZONE"
echo ""

# ------------------------------------------------------
# Task 1 — Configure Cloud SDK
# ------------------------------------------------------
echo "→ Setting active project"
gcloud config set project "$PROJECT_ID" --quiet

echo "→ Setting default region"
gcloud config set compute/region "$REGION" --quiet

echo "→ Setting default zone"
gcloud config set compute/zone "$ZONE" --quiet

echo ""

# ------------------------------------------------------
# Task 2 — Create GCS Bucket for Terraform State
# ------------------------------------------------------
STATE_BUCKET="${PROJECT_ID}-tf-state"

echo "→ Creating Terraform state bucket: gs://$STATE_BUCKET"
gcloud storage buckets create "gs://$STATE_BUCKET" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --uniform-bucket-level-access || true

echo "→ Enabling versioning"
gsutil versioning set on "gs://$STATE_BUCKET"

echo ""

# ------------------------------------------------------
# Task 3 — Create Terraform Files
# ------------------------------------------------------
WORKDIR="terraform-gcs"
rm -rf $WORKDIR
mkdir $WORKDIR && cd $WORKDIR

echo "→ Creating Terraform configuration"

# main.tf
cat > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "${STATE_BUCKET}"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "${PROJECT_ID}"
  region  = "${REGION}"
}

resource "google_storage_bucket" "default" {
  name          = "${PROJECT_ID}-my-terraform-bucket"
  location      = "${REGION}"
  force_destroy = true

  storage_class = "STANDARD"

  versioning {
    enabled = true
  }
}
EOF

echo ""

# ------------------------------------------------------
# Task 4 — Initialize, Plan & Apply Terraform
# ------------------------------------------------------
echo "→ Initializing Terraform"
terraform init -input=false

echo "→ Running terraform plan"
terraform plan -input=false -out=tfplan

echo "→ Applying Terraform (non-interactive)"
terraform apply -auto-approve tfplan

echo ""
echo "→ Verifying bucket"
gsutil ls "gs://${PROJECT_ID}-my-terraform-bucket" || echo "Bucket not found!"

# ------------------------------------------------------
# Task 6 — Cleanup
# ------------------------------------------------------
echo ""
echo "→ Destroying Terraform-managed resources (cleanup)"
terraform destroy -auto-approve

echo ""
echo "=============================================================="
echo " 🎉 Module 2 — Lab 2 Completed Successfully!"
echo "=============================================================="
