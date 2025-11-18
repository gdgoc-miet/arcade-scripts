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

BG_MAGENTA=`tput setab 5`
BG_GREEN=`tput setab 2`

echo "${BG_MAGENTA}${BOLD}Starting Module 1 — Lab 1 Execution${RESET}"

# ---------------------------------------
# FETCH PROJECT ID & REGION DYNAMICALLY
# ---------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Fallback if region metadata is missing
if [[ -z "$REGION" ]]; then
    REGION="us-east1"
fi

echo "${CYAN}${BOLD}→ PROJECT ID detected: $PROJECT_ID${RESET}"
echo "${CYAN}${BOLD}→ REGION detected: $REGION${RESET}"

# ---------------------------------------
# TASK 1 — Set Environment
# ---------------------------------------
echo "${GREEN}→ Setting project ID${RESET}"
gcloud config set project "$PROJECT_ID" --quiet

echo "${GREEN}→ Setting region${RESET}"
gcloud config set run/region "$REGION" --quiet

echo "${GREEN}→ Enabling Cloud Run + Artifact Registry APIs${RESET}"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com --quiet

# ---------------------------------------
# TASK 2 — Create Static Website
# ---------------------------------------
echo "${GREEN}→ Creating index.html${RESET}"
cat > index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>My Static Website</title>
</head>
<body>
    <div>Welcome to My Static Website!</div>
    <p>This website is served from Google Cloud Run using Nginx and Artifact Registry.</p>
</body>
</html>
EOF

# ---------------------------------------
# TASK 3 — Create nginx.conf
# ---------------------------------------
echo "${GREEN}→ Creating nginx.conf${RESET}"
cat > nginx.conf <<EOF
events {}
http {
    server {
        listen 8080;
        root /usr/share/nginx/html;
        index index.html index.htm;

        location / {
            try_files \$uri \$uri/ =404;
        }
    }
}
EOF

# ---------------------------------------
# TASK 4 — Create Dockerfile
# ---------------------------------------
echo "${GREEN}→ Creating Dockerfile${RESET}"
cat > Dockerfile <<EOF
FROM nginx:latest

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
EOF

# ---------------------------------------
# TASK 5 — Build & Push Image
# ---------------------------------------
echo "${GREEN}→ Creating Artifact Registry repo${RESET}"
gcloud artifacts repositories create nginx-static-site \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository for static website" || true

echo "${GREEN}→ Building Docker image${RESET}"
docker build -t nginx-static-site .

IMAGE_PATH="$REGION-docker.pkg.dev/$PROJECT_ID/nginx-static-site/nginx-static-site"

echo "${GREEN}→ Tagging Docker image${RESET}"
docker tag nginx-static-site "$IMAGE_PATH"

echo "${GREEN}→ Configuring Docker auth${RESET}"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

echo "${GREEN}→ Pushing Docker image${RESET}"
docker push "$IMAGE_PATH"

# ---------------------------------------
# TASK 6 — Deploy to Cloud Run
# ---------------------------------------
echo "${GREEN}→ Deploying to Cloud Run${RESET}"
gcloud run deploy nginx-static-site \
    --image "$IMAGE_PATH" \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --quiet

# ---------------------------------------
# Get URL
# ---------------------------------------
SERVICE_URL=$(gcloud run services describe nginx-static-site \
    --platform managed \
    --region "$REGION" \
    --format='value(status.url)')

echo "${YELLOW}${BOLD}→ Your website URL: $SERVICE_URL${RESET}"

# ---------------------------------------
# Display BIG FINAL MESSAGE + CLICKABLE URL
# ---------------------------------------
echo ""
echo "${BG_GREEN}${BOLD}=============================================================${RESET}"
echo "${BG_GREEN}${BOLD}   🚀 YOUR WEBSITE IS READY! OPEN IT IN A NEW TAB BELOW 🚀   ${RESET}"
echo "${BG_GREEN}${BOLD}=============================================================${RESET}"
echo ""

# Show plain URL (copy/paste option)
echo "${YELLOW}${BOLD}URL: $SERVICE_URL${RESET}"
echo ""

# Clickable link (Cloud Shell supported)
printf '\e]8;;'"$SERVICE_URL"'\e\\'"👉 CLICK HERE TO OPEN YOUR STATIC WEBSITE AND COMPLETE YOUR LAB IMPORTANT STEP👈"'\e]8;;\e\\\n'
echo ""

# For environments where hyperlink doesn't work
echo "${CYAN}If clicking doesn't work, manually open the URL in a new browser tab.${RESET}"
echo ""

echo "${BG_GREEN}${BOLD}🎉 Congratulations! Lab Completed Successfully. 🎉${RESET}"

