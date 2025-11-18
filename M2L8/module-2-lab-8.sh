#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "   🚀 Starting Module 2 — Lab 8 (Caddy Static Site on Cloud Run)"
echo "=============================================================="
echo ""

# ------------------------------------------------------
# AUTO-DETECT PROJECT ID
# ------------------------------------------------------
PROJECT_ID=$(gcloud config get-value project)
echo "→ Project detected: $PROJECT_ID"

# AUTO-DETECT REGION (fallback to us-central1)
REGION=$(gcloud config get-value run/region 2>/dev/null || echo "")
if [[ -z "$REGION" ]]; then
  REGION="us-central1"
fi
echo "→ Region detected : $REGION"

# ------------------------------------------------------
# TASK 1 — Enable APIs
# ------------------------------------------------------
echo "→ Enabling Cloud Run + Artifact Registry + Cloud Build APIs..."
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com

# ------------------------------------------------------
# TASK 2 — Create Artifact Registry repo
# ------------------------------------------------------
echo "→ Creating Artifact Registry repo: caddy-repo"
gcloud artifacts repositories create caddy-repo \
  --repository-format=docker \
  --location="$REGION" \
  --description="Docker repository for Caddy images" || echo "Repo already exists, continuing..."

# ------------------------------------------------------
# TASK 3 — Create static website + Caddyfile
# ------------------------------------------------------
echo "→ Creating index.html"
cat > index.html <<EOF
<html>
<head>
  <title>My Static Website</title>
</head>
<body>
  <div>Hello from Caddy on Cloud Run!</div>
  <p>This website is served by Caddy running in a Docker container on Google Cloud Run.</p>
</body>
</html>
EOF

echo "→ Creating Caddyfile"
cat > Caddyfile <<EOF
:8080
root * /usr/share/caddy
file_server
EOF

# ------------------------------------------------------
# TASK 4 — Dockerfile
# ------------------------------------------------------
echo "→ Creating Dockerfile"
cat > Dockerfile <<EOF
FROM caddy:2-alpine

WORKDIR /usr/share/caddy

COPY index.html .
COPY Caddyfile /etc/caddy/Caddyfile
EOF

# ------------------------------------------------------
# TASK 5 — Build + Push Docker Image
# ------------------------------------------------------
IMAGE_PATH="$REGION-docker.pkg.dev/$PROJECT_ID/caddy-repo/caddy-static:latest"

echo "→ Building Docker image"
docker build -t "$IMAGE_PATH" .

echo "→ Configuring Docker auth"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

echo "→ Pushing Docker image to Artifact Registry"
docker push "$IMAGE_PATH"

# ------------------------------------------------------
# TASK 6 — Deploy to Cloud Run
# ------------------------------------------------------
echo "→ Deploying to Cloud Run"
gcloud run deploy caddy-static \
  --image "$IMAGE_PATH" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --quiet

# ------------------------------------------------------
# FETCH URL
# ------------------------------------------------------
SERVICE_URL=$(gcloud run services describe caddy-static \
  --platform managed \
  --region "$REGION" \
  --format='value(status.url)')

echo ""
echo "=============================================================="
echo "   🌐 YOUR STATIC WEBSITE IS LIVE!"
echo "=============================================================="
echo ""
echo "URL: $SERVICE_URL"
printf '\e]8;;'"$SERVICE_URL"'\e\\'"👉 CLICK HERE TO OPEN WEBSITE 👈"'\e]8;;\e\\\n'
echo ""

echo "=============================================================="
echo " 🎉 Module 2 — Lab 8 Completed Successfully!"
echo "=============================================================="
