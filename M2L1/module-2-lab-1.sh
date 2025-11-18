#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "   🚀 Starting Module 2 — Lab 1 (Terraform + GCE Instance)"
echo "=============================================================="
echo ""

# ------------------------------------------------------
# FETCH PROJECT ID + REGION + ZONE
# ------------------------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

ZONE=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

# fallback values
[[ -z "$REGION" ]] && REGION="us-central1"
[[ -z "$ZONE" ]] && ZONE="us-central1-a"

echo "→ Project detected : $PROJECT_ID"
echo "→ Region detected  : $REGION"
echo "→ Zone detected    : $ZONE"
echo ""

# ------------------------------------------------------
# Task 1 — Enable APIs + Verify Tools
# ------------------------------------------------------
echo "→ Enabling Artifact Registry API"
gcloud services enable artifactregistry.googleapis.com --quiet

echo "→ Enabling Compute Engine API"
gcloud services enable compute.googleapis.com --quiet

echo "→ Verifying Terraform availability"
terraform version || { echo "Terraform not installed!"; exit 1; }

echo "→ Verifying gcloud installation"
gcloud version >/dev/null

echo ""

# ------------------------------------------------------
# Task 2 — Create Terraform State Bucket
# ------------------------------------------------------
BUCKET_NAME="${PROJECT_ID}-tf-state"

echo "→ Creating Terraform state bucket: gs://$BUCKET_NAME"
gsutil mb -l "$REGION" "gs://$BUCKET_NAME" || true

echo "→ Enabling versioning"
gsutil versioning set on "gs://$BUCKET_NAME"

echo ""

# ------------------------------------------------------
# Task 3 — Create Terraform Files
# ------------------------------------------------------
echo "→ Creating Terraform configuration files"
rm -rf m2l1-terraform
mkdir m2l1-terraform
cd m2l1-terraform

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
    bucket = "${BUCKET_NAME}"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_instance" "default" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = "default"
    access_config {}
  }
}
EOF

# variables.tf
cat > variables.tf <<EOF
variable "project_id" {
  type        = string
  description = "Google Cloud Project ID"
  default     = "${PROJECT_ID}"
}

variable "region" {
  type        = string
  description = "Deployment region"
  default     = "${REGION}"
}

variable "zone" {
  type        = string
  description = "Deployment zone"
  default     = "${ZONE}"
}
EOF

echo ""

# ------------------------------------------------------
# Task 4 — Terraform Init/Plan/Apply
# ------------------------------------------------------
echo "→ Initializing Terraform"
terraform init -input=false

echo "→ Running terraform plan"
terraform plan -input=false -out=tfplan

echo "→ Applying Terraform (non-interactive)"
terraform apply -auto-approve tfplan

echo ""
echo "→ Instance deployed! Verifying..."
gcloud compute instances list --filter="name=terraform-instance"

# ------------------------------------------------------
# Task 6 — Destroy Infra
# ------------------------------------------------------
echo ""
echo "→ Destroying Terraform-managed resources (cleanup)"
terraform destroy -auto-approve

echo ""
echo "=============================================================="
echo "  🎉 Module 2 — Lab 1 Completed Successfully!"
echo "=============================================================="
