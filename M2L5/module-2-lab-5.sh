#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "   🌐 Starting Module 2 — Lab 5 (Terraform + Custom VPC)"
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
# TASK 1 — Set Environment
# ------------------------------------------------------
echo "→ Setting project"
gcloud config set project "$PROJECT_ID" --quiet

echo "→ Setting region"
gcloud config set compute/region "$REGION" --quiet

echo "→ Setting zone"
gcloud config set compute/zone "$ZONE" --quiet

echo "→ Enabling Cloud Resource Manager API"
gcloud services enable cloudresourcemanager.googleapis.com --quiet

echo ""

# ------------------------------------------------------
# TASK 2 — Create GCS Bucket for Terraform State
# ------------------------------------------------------
STATE_BUCKET="${PROJECT_ID}-terraform-state"

echo "→ Creating Terraform state bucket: gs://$STATE_BUCKET"
gcloud storage buckets create "gs://$STATE_BUCKET" \
  --location=us \
  --uniform-bucket-level-access || true

echo "→ Enabling bucket versioning"
gsutil versioning set on "gs://$STATE_BUCKET"

echo ""

# ------------------------------------------------------
# TASK 3 — Create Terraform Configuration Files
# ------------------------------------------------------
WORKDIR="terraform-vpc"
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

resource "google_compute_network" "vpc_network" {
  name                    = "custom-vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet_us" {
  name          = "subnet-us"
  ip_cidr_range = "10.10.1.0/24"
  region        = "${REGION}"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}
EOF

# variables.tf
cat > variables.tf <<EOF
variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project"
  default     = "${PROJECT_ID}"
}

variable "region" {
  type        = string
  description = "The region to deploy resources in"
  default     = "${REGION}"
}
EOF

# outputs.tf
cat > outputs.tf <<EOF
output "network_name" {
  value       = google_compute_network.vpc_network.name
  description = "The name of the VPC network"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet_us.name
  description = "The name of the subnetwork"
}
EOF

echo ""

# ------------------------------------------------------
# TASK 3 — Terraform Init, Plan, Apply
# ------------------------------------------------------
echo "→ Initializing Terraform"
terraform init -input=false

echo "→ Planning Terraform changes"
terraform plan -input=false

echo "→ Applying Terraform configuration"
terraform apply --auto-approve

echo ""
echo "→ VPC Network, Subnet, and Firewall Rules created!"
echo "→ Verify in the Console under VPC Network / Subnets / Firewall Rules"
echo ""

# ------------------------------------------------------
# TASK 5 — Cleanup
# ------------------------------------------------------
echo "→ Destroying Terraform resources"
terraform destroy --auto-approve

echo ""
echo "=============================================================="
echo " 🎉 Module 2 — Lab 5 Completed Successfully!"
echo "=============================================================="
