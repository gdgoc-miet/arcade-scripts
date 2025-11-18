#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "   🔥 Starting Module 2 — Lab 4 (Terraform + Firewall Rule)"
echo "=============================================================="
echo ""

# ------------------------------------------------------
# AUTO-DETECT PROJECT / REGION / ZONE
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
# TASK 1 — Configure Project
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
# TASK 2 — Create GCS Backend Bucket
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
# TASK 3 — Create Terraform Files
# ------------------------------------------------------
WORKDIR="terraform-firewall"
rm -rf $WORKDIR
mkdir $WORKDIR && cd $WORKDIR

echo "→ Creating Terraform configuration"

# firewall.tf
cat > firewall.tf <<EOF
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-from-anywhere"
  network = "default"
  project = "${PROJECT_ID}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-allowed"]
}
EOF

# variables.tf
cat > variables.tf <<EOF
variable "project_id" {
  type    = string
  default = "${PROJECT_ID}"
}

variable "bucket_name" {
  type    = string
  default = "${STATE_BUCKET}"
}

variable "region" {
  type    = string
  default = "${REGION}"
}
EOF

# outputs.tf
cat > outputs.tf <<EOF
output "firewall_name" {
  value = google_compute_firewall.allow_ssh.name
}
EOF

# backend + provider
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
EOF

echo ""

# ------------------------------------------------------
# TASK 4 — Terraform Init & Apply
# ------------------------------------------------------
echo "→ Initializing Terraform"
terraform init -input=false

echo "→ Planning Terraform changes"
terraform plan -input=false

echo "→ Applying Terraform changes"
terraform apply -auto-approve

echo ""
echo "→ Firewall rule created. Verifying..."
gcloud compute firewall-rules list --filter="name=allow-ssh-from-anywhere"

echo ""

# ------------------------------------------------------
# TASK 5 — Clean Up
# ------------------------------------------------------
echo "→ Destroying Terraform-managed resources"
terraform destroy -auto-approve

echo ""
echo "=============================================================="
echo " 🎉 Module 2 — Lab 4 Completed Successfully!"
echo "=============================================================="
