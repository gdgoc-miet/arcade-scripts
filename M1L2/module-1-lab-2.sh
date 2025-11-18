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

echo "${BG_PURPLE}${BOLD}Starting Module 2 — Traefik Static Site Deployment${RESET}"

# ---------------------------------------
# AUTO-DETECT PROJECT + REGION
# ---------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Fallback if region metadata is missing
if [[ -z "$REGION" ]]; then
    REGION="us-east1"
fi

echo "${CYAN}${BOLD}→ Project detected: $PROJECT_ID${RESET}"
echo "${CYAN}${BOLD}→ Region detected : $REGION${RESET}"

# ---------------------------------------
# TASK 1 — ENVIRONMENT SETUP
# ---------------------------------------
echo "${GREEN}→ Enabling required APIs${RESET}"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com --quiet

echo "${GREEN}→ Setting project & region${RESET}"
gcloud config set project "$PROJECT_ID" --quiet
gcloud config set run/region "$REGION" --quiet

# ---------------------------------------
# TASK 2 — Artifact Registry Repo
# ---------------------------------------
echo "${GREEN}→ Creating Artifact Registry repo: traefik-repo${RESET}"
gcloud artifacts repositories create traefik-repo \
    --repository-format=docker \
    --location="$REGION" \
    --description="Traefik static site repo" || true

# ---------------------------------------
# TASK 3 — STATIC SITE + TRAEFIK FILES
# ---------------------------------------
echo "${GREEN}→ Creating directories${RESET}"
mkdir -p traefik-site/public
cd traefik-site

echo "${GREEN}→ Creating public/index.html${RESET}"
cat > public/index.html <<EOF
<html>
<head>
  <title>My Static Website</title>
</head>
<body>
  <p>Hello from my static website on Cloud Run!</p>
</body>
</html>
EOF

echo "${GREEN}→ Creating traefik.yml${RESET}"
cat > traefik.yml <<EOF
entryPoints:
  web:
    address: ":8080"

providers:
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

log:
  level: INFO
EOF

echo "${GREEN}→ Creating dynamic.yml${RESET}"
cat > dynamic.yml <<EOF
http:
  routers:
    static-files:
      rule: "PathPrefix(\`/\`)"
      entryPoints:
        - web
      service: static-service

  services:
    static-service:
      loadBalancer:
        servers:
          - url: "http://localhost:8000"
EOF

# ---------------------------------------
# TASK 4 — DOCKERFILE
# ---------------------------------------
echo "${GREEN}→ Creating Dockerfile${RESET}"
cat > Dockerfile <<EOF
FROM alpine:3.20

# Install traefik and caddy
RUN apk add --no-cache traefik caddy

# Copy configs and static files
COPY traefik.yml /etc/traefik/traefik.yml
COPY dynamic.yml /etc/traefik/dynamic.yml
COPY public/ /public/

# Cloud Run uses port 8080
EXPOSE 8080

# Run static server (8000) + traefik (8080)
ENTRYPOINT [ "caddy" ]
CMD [ "file-server", "--listen", ":8000", "--root", "/public", "&", "traefik" ]
EOF

# ---------------------------------------
# TASK 5 — BUILD & PUSH IMAGE
# ---------------------------------------
IMAGE_URI="$REGION-docker.pkg.dev/$PROJECT_ID/traefik-repo/traefik-static-site:latest"

echo "${GREEN}→ Configuring Docker auth${RESET}"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

echo "${GREEN}→ Building Docker image${RESET}"
docker build -t "$IMAGE_URI" .

echo "${GREEN}→ Pushing Docker image${RESET}"
docker push "$IMAGE_URI"

# ---------------------------------------
# TASK 6 — DEPLOY TO CLOUD RUN
# ---------------------------------------
echo "${GREEN}→ Deploying to Cloud Run${RESET}"
gcloud run deploy traefik-static-site \
    --image "$IMAGE_URI" \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --port 8000 \
    --quiet

# ---------------------------------------
# FETCH SERVICE URL
# ---------------------------------------
SERVICE_URL=$(gcloud run services describe traefik-static-site \
    --platform managed \
    --region "$REGION" \
    --format="value(status.url)")

echo "${YELLOW}${BOLD}→ Your Website URL: $SERVICE_URL${RESET}"

# ---------------------------------------
# BIG FINAL BANNER + CLICKABLE LINK
# ---------------------------------------
echo ""
echo "${BG_GREEN}${BOLD}=================================================================${RESET}"
echo "${BG_GREEN}${BOLD} 🚀 YOUR TRAEFIK STATIC WEBSITE IS READY! OPEN IT BELOW 🚀 ${RESET}"
echo "${BG_GREEN}${BOLD}=================================================================${RESET}"
echo ""

echo "${YELLOW}${BOLD}URL: $SERVICE_URL${RESET}"
echo ""

printf '\e]8;;'"$SERVICE_URL"'\e\\'"👉 CLICK HERE TO OPEN YOUR WEBSITE 👈"'\e]8;;\e\\\n'
echo ""

echo "${CYAN}If clicking doesn't work, manually open the URL in a new browser tab.${RESET}"
echo ""

echo "${BG_GREEN}${BOLD}🎉 Congratulations! Module 2 Lab Completed Successfully! 🎉${RESET}"
