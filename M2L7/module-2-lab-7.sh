#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "      🔐 Starting Module 2 — Lab 7 (Secret Manager)"
echo "=============================================================="
echo ""

# ------------------------------------------------------
# AUTO-DETECT PROJECT ID
# ------------------------------------------------------
PROJECT_ID=$(gcloud config get-value project)
echo "→ Project detected: $PROJECT_ID"

# ------------------------------------------------------
# TASK 1 — Enable Secret Manager API
# ------------------------------------------------------
echo "→ Enabling Secret Manager API..."
gcloud services enable secretmanager.googleapis.com --project="$PROJECT_ID"

# ------------------------------------------------------
# TASK 2 — Create Secret
# ------------------------------------------------------
echo "→ Creating secret: my-secret"
gcloud secrets create my-secret --project="$PROJECT_ID" || echo "Secret already exists, continuing..."

# ------------------------------------------------------
# TASK 3 — Add Secret Version
# ------------------------------------------------------
echo "→ Adding secret version with value: super-secret-password"
echo -n "super-secret-password" | gcloud secrets versions add my-secret --data-file=- --project="$PROJECT_ID"

# ------------------------------------------------------
# TASK 4 — Accessing Secret
# ------------------------------------------------------
echo "→ Accessing secret value:"
SECRET_VALUE=$(gcloud secrets versions access latest --secret=my-secret --project="$PROJECT_ID")
echo "   Secret value retrieved: $SECRET_VALUE"

echo "→ Storing secret value in environment variable: MY_SECRET"
export MY_SECRET="$SECRET_VALUE"

echo "→ Printing MY_SECRET:"
echo "$MY_SECRET"

echo ""
echo "=============================================================="
echo " 🎉 Module 2 — Lab 7 Completed Successfully!"
echo "=============================================================="
