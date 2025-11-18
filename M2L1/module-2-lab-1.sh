#!/bin/bash
set -euo pipefail

# ==============================================================
#   🚀 Module 2 — Lab 1 (Terraform + GCE Instance) — Auto-Retry
# ==============================================================

echo ""
echo "=============================================================="
echo "   🚀 Starting Module 2 — Lab 1 (Terraform + GCE Instance)"
echo "=============================================================="
echo ""

# Detect project, region & zone
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
         --format="value(commonInstanceMetadata.items[google-compute-default-region])")
ZONE=$(gcloud compute project-info describe --project "$PROJECT_ID" \
        --format="value(commonInstanceMetadata.items[google-compute-default-zone])")

REGION=${REGION:-"us-central1"}
ZONE=${ZONE:-"${REGION}-b"}

echo "→ Project detected : $PROJECT_ID"
echo "→ Region detected  : $REGION"
echo "→ Zone detected    : $ZONE"
echo ""

# --------------------------------------------------------------
# AUTO-RETRY FUNCTION FOR ENABLING APIS
# --------------------------------------------------------------
enable_api() {
    API="$1"
    echo "→ Enabling $API"

    for ATTEMPT in {1..3}; do
        if gcloud services enable "$API" --quiet; then
            echo "✔ $API enabled successfully"
            return 0
        else
            echo "⚠ Failed to enable $API (attempt $ATTEMPT/3). Retrying in 10 seconds..."
            sleep 10
        fi
    done

    echo "❌ WARNING: Failed to enable $API after multiple attempts."
    echo "   Continuing script — API might already be enabled."
}

# --------------------------------------------------------------
# ENABLE REQUIRED APIS WITH RETRIES
# --------------------------------------------------------------
enable_api "artifactregistry.googleapis.com"
enable_api "compute.googleapis.com"

# --------------------------------------------------------------
# TERRAFORM SETUP STARTS BELOW
# --------------------------------------------------------------
echo ""
echo "→ Creating Terraform state bucket: gs://${PROJECT_ID}-tf-state"
gcloud storage buckets create "gs://${PROJECT_ID}-tf-state" --location=us --quiet || true

echo "→ Enabling bucket versioning"
gsutil versioning set on "gs://${PROJECT_ID}-tf-state" >/dev/null || true

echo "→ Creating Terraform files"
mkdir -p terraform-gce && cd terraform-gce

cat > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "${PROJECT_ID}-tf-state"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "$PROJECT_ID"
  region  = "$REGION"
}

resource "google_compute_instance" "default" {
  name         = "terraform-instance"
  machine_type = "e2-micro"
  zone         = "$ZONE"

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

echo "→ Initializing Terraform"
terraform init -input=false

echo "→ Running terraform plan"
terraform plan -out=tfplan -input=false

echo "→ Applying Terraform configuration"
terraform apply -input=false -auto-approve tfplan

echo ""
echo "✔ Instance created. Showing VM list:"
gcloud compute instances list

echo ""
echo "→ Destroying Terraform-managed resources (cleanup)"
terraform destroy -auto-approve -input=false

echo ""
echo "🎉 Module 2 — Lab 1 Completed Successfully!"
