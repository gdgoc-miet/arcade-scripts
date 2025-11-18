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
# TASK 1 — Set Environment
# ---------------------------------------
echo "${GREEN}→ Setting project ID${RESET}"
gcloud config set project qwiklabs-gcp-01-97b95e9cdf45

echo "${GREEN}→ Setting region${RESET}"
gcloud config set run/region us-east1

echo "${GREEN}→ Enabling Cloud Run + Artifact Registry APIs${RESET}"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com

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
    --location=us-east1 \
    --description="Docker repository for static website" || true

echo "${GREEN}→ Building Docker image${RESET}"
docker build -t nginx-static-site .

echo "${GREEN}→ Tagging Docker image${RESET}"
docker tag nginx-static-site \
us-east1-docker.pkg.dev/qwiklabs-gcp-01-97b95e9cdf45/nginx-static-site/nginx-static-site

echo "${GREEN}→ Configuring Docker auth${RESET}"
gcloud auth configure-docker us-east1-docker.pkg.dev

echo "${GREEN}→ Pushing Docker image${RESET}"
docker push \
us-east1-docker.pkg.dev/qwiklabs-gcp-01-97b95e9cdf45/nginx-static-site/nginx-static-site

# ---------------------------------------
# TASK 6 — Deploy to Cloud Run
# ---------------------------------------
echo "${GREEN}→ Deploying to Cloud Run${RESET}"
gcloud run deploy nginx-static-site \
    --image us-east1-docker.pkg.dev/qwiklabs-gcp-01-97b95e9cdf45/nginx-static-site/nginx-static-site \
    --platform managed \
    --region us-east1 \
    --allow-unauthenticated

# ---------------------------------------
# Get URL
# ---------------------------------------
SERVICE_URL=$(gcloud run services describe nginx-static-site \
    --platform managed \
    --region us-east1 \
    --format='value(status.url)')

echo "${YELLOW}${BOLD}→ Your website URL: $SERVICE_URL${RESET}"

# ---------------------------------------
# Auto-open if supported
# ---------------------------------------
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$SERVICE_URL" >/dev/null 2>&1 &
fi

# ---------------------------------------
# END
# ---------------------------------------
echo "${BG_GREEN}${BOLD}🎉 Congratulations! Lab Completed Successfully.${RESET}"
