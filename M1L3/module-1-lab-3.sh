#!/bin/bash
set -euo pipefail

# ---------------------------------------
# Colors
# ---------------------------------------
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`
BOLD=`tput bold`
RESET=`tput sgr0`

BG_PURPLE=`tput setab 5`
BG_GREEN=`tput setab 2`

echo "${BG_PURPLE}${BOLD}Starting Module 1 — Lab 3 (Artifact Registry Basics)${RESET}"

# ---------------------------------------
# AUTO-DETECT PROJECT + REGION
# ---------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Fallback if Cloud Shell metadata missing
if [[ -z "$REGION" ]]; then
    REGION="us-east1"
fi

echo "${CYAN}${BOLD}→ Project detected: $PROJECT_ID${RESET}"
echo "${CYAN}${BOLD}→ Region detected : $REGION${RESET}"

# ---------------------------------------
# TASK 1 — Enable Artifact Registry API
# ---------------------------------------
echo "${GREEN}→ Enabling Artifact Registry API${RESET}"
gcloud services enable artifactregistry.googleapis.com --quiet

# ---------------------------------------
# TASK 2 — Configure Project + Create Repo
# ---------------------------------------
echo "${GREEN}→ Setting project ID${RESET}"
gcloud config set project "$PROJECT_ID" --quiet

echo "${GREEN}→ Setting compute region${RESET}"
gcloud config set compute/region "$REGION" --quiet

echo "${GREEN}→ Creating Artifact Registry Repo (my-docker-repo)${RESET}"
gcloud artifacts repositories create my-docker-repo \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository" || true

echo "${YELLOW}→ Waiting 20 seconds for Artifact Registry to be ready...${RESET}"
sleep 20

# ---------------------------------------
# TASK 3 — Configure Docker Authentication
# ---------------------------------------
echo "${GREEN}→ Configuring Docker authentication${RESET}"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

# ---------------------------------------
# TASK 4 — Build & Tag Docker Image
# ---------------------------------------
echo "${GREEN}→ Creating sample-app folder & Dockerfile${RESET}"
mkdir -p sample-app
cd sample-app

echo "${GREEN}→ Writing Dockerfile${RESET}"
echo "FROM nginx:latest" > Dockerfile

echo "${GREEN}→ Building Docker image (nginx-image)${RESET}"
docker build -t nginx-image .

IMAGE_URI="$REGION-docker.pkg.dev/$PROJECT_ID/my-docker-repo/nginx-image:latest"

echo "${GREEN}→ Tagging Docker image${RESET}"
docker tag nginx-image "$IMAGE_URI"

# ---------------------------------------
# TASK 5 — Push Docker Image
# ---------------------------------------
echo "${GREEN}→ Pushing image to Artifact Registry${RESET}"
docker push "$IMAGE_URI"

echo "${BG_GREEN}${BOLD}🎉 Congratulations! Module 1 Lab 3 Completed Successfully! 🎉${RESET}"
