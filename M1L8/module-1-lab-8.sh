#!/bin/bash
set -euo pipefail

GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
BOLD="\e[1m"
RESET="\e[0m"

echo -e "${BOLD}Starting Module 1 — Lab 8 (Terraform + Firestore)${RESET}"

# ---------------------------------------
# AUTO-DETECT PROJECT + REGION
# ---------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud config get-value compute/region 2>/dev/null || true)

if [[ -z "$REGION" ]]; then
  REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
    --format="value(commonInstanceMetadata.items[google-compute-default-region])")
fi

[[ -z "$REGION" ]] && REGION="us-central1"

echo -e "${CYAN}→ Project detected: $PROJECT_ID${RESET}"
echo -e "${CYAN}→ Region detected : $REGION${RESET}"

# ---------------------------------------
# TASK 1 — SETUP PROJECT, ENABLE APIS, CREATE BUCKET
# ---------------------------------------
echo -e "${GREEN}→ Setting active project${RESET}"
gcloud config set project "$PROJECT_ID" --quiet

echo -e "${GREEN}→ Enabling Firestore API${RESET}"
gcloud services enable firestore.googleapis.com --quiet

echo -e "${GREEN}→ Enabling Cloud Build API${RESET}"
gcloud services enable cloudbuild.googleapis.com --quiet

BUCKET_NAME="${PROJECT_ID}-tf-state"

echo -e "${GREEN}→ Creating Terraform state bucket: gs://${BUCKET_NAME}${RESET}"
gcloud storage buckets create "gs://${BUCKET_NAME}" --location=us || true

# ---------------------------------------
# TASK 2 — CREATE TERRAFORM CONFIG FILES
# ---------------------------------------
echo -e "${GREEN}→ Creating Terraform configuration files${RESET}"
mkdir -p tf-lab
cd tf-lab

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
  project = "${PROJECT_ID}"
  region  = "${REGION}"
}

resource "google_firestore_database" "default" {
  name        = "default"
  project     = "${PROJECT_ID}"
  location_id = "nam5"
  type        = "FIRESTORE_NATIVE"
}

output "firestore_database_name" {
  value       = google_firestore_database.default.name
  description = "The name of the Cloud Firestore database."
}
EOF

# variables.tf
cat > variables.tf <<EOF
variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project."
  default     = "${PROJECT_ID}"
}

variable "bucket_name" {
  type        = string
  description = "Bucket name for terraform state"
  default     = "${BUCKET_NAME}"
}
EOF

# outputs.tf
cat > outputs.tf <<EOF
output "project_id" {
  value       = var.project_id
  description = "The ID of the Google Cloud project."
}

output "bucket_name" {
  value       = var.bucket_name
  description = "The name of the bucket to store terraform state."
}
EOF

# ---------------------------------------
# TASK 3 — TERRAFORM INIT, PLAN, APPLY
# ---------------------------------------
echo -e "${GREEN}→ Initializing Terraform${RESET}"
terraform init

echo -e "${GREEN}→ Running terraform plan${RESET}"
terraform plan -out=tfplan

echo -e "${GREEN}→ Applying Terraform configuration (non-interactive)${RESET}"
terraform apply -auto-approve tfplan

echo -e "${YELLOW}${BOLD}→ Firestore database should now be created in project: ${PROJECT_ID}${RESET}"
echo -e "${YELLOW}Check Cloud Firestore in the Console to verify.${RESET}"

# ---------------------------------------
# TASK 4 — CLEAN UP (DESTROY)
# ---------------------------------------
echo -e "${GREEN}→ Destroying Terraform-managed resources (cleanup)${RESET}"
terraform destroy -auto-approve

echo -e "${BOLD}${GREEN}🎉 Module 1 — Lab 8 Completed Successfully! (Resources cleaned up)${RESET}"
