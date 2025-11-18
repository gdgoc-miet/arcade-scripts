#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "    🚀 Starting Module 2 — Lab 3 (Terraform + Service Account)"
echo "=============================================================="
echo ""

# ------------------------------------------------------
# AUTO DETECT PROJECT / REGION / ZONE
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
# TASK 1 — Configure Google Cloud
# ------------------------------------------------------
echo "→ Setting project"
gcloud config set project "$PROJECT_ID" --quiet

echo "→ Setting region"
gcloud config set compute/region "$REGION" --quiet

echo "→ Setting zone"
gcloud config set compute/zone "$ZONE" --quiet

echo "→ Enabling IAM API"
gcloud services enable iam.googleapis.com --quiet

echo ""

# ------------------------------------------------------
# TASK 2 — Create GCS State Bucket
# ------------------------------------------------------
STATE_BUCKET="${PROJECT_ID}-tf-state"

echo "→ Creating Terraform state bucket: gs://$STATE_BUCKET"
gcloud storage buckets create "gs://$STATE_BUCKET" \
  --location="$REGION" \
  --uniform-bucket-level-access || true

echo "→ Enabling bucket versioning"
gsutil versioning set on "gs://$STATE_BUCKET"

echo ""

# ------------------------------------------------------
# TASK 3 — Create Terraform Config Files
# ------------------------------------------------------
WORKDIR="terraform-service-account"
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
  project = var.project_id
  region  = var.region
}

resource "google_service_account" "default" {
  account_id   = "terraform-sa"
  display_name = "Terraform Service Account"
}
EOF

# variables.tf
cat > variables.tf <<EOF
variable "project_id" {
  type        = string
  description = "The GCP project ID"
  default     = "${PROJECT_ID}"
}

variable "region" {
  type        = string
  description = "The GCP region"
  default     = "${REGION}"
}
EOF

echo ""

# ------------------------------------------------------
# TASK 4 — Initialize & Apply Terraform
# ------------------------------------------------------
echo "→ Initializing Terraform"
terraform init -input=false

echo "→ Applying Terraform config"
terraform apply -auto-approve

echo ""

echo "→ Verifying service account"
gcloud iam service-accounts list --project="$PROJECT_ID"

echo ""

# ------------------------------------------------------
# TASK 5 — Clean Up
# ------------------------------------------------------
echo "→ Destroying Terraform-managed resources"
terraform destroy -auto-approve

echo ""
echo "=============================================================="
echo " 🎉 Module 2 — Lab 3 Completed Successfully!"
echo "=============================================================="
