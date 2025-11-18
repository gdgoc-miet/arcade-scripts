#!/usr/bin/env bash
set -euo pipefail

echo "=============================="
echo " Running Lab Script (Tasks 1–7)"
echo "=============================="

# ------------ TASK 1 ------------
echo "→ Setting project ID"
gcloud config set project "PROJECT_ID"

echo "→ Setting region"
gcloud config set run/region "REGION"

echo "→ Enabling APIs"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com


# ------------ TASK 2 ------------
echo "→ Creating index.html"
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


# ------------ TASK 3 ------------
echo "→ Creating nginx.conf"
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


# ------------ TASK 4 ------------
echo "→ Creating Dockerfile"
cat > Dockerfile <<EOF
FROM nginx:latest

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
EOF


# ------------ TASK 5 ------------
echo "→ Creating Artifact Registry repo"
gcloud artifacts repositories create nginx-static-site \
    --repository-format=docker \
    --location="REGION" \
    --description="Docker repository for static website" || true

echo "→ Building Docker image"
docker build -t nginx-static-site .

echo "→ Tagging image"
docker tag nginx-static-site "REGION"-docker.pkg.dev/"PROJECT_ID"/nginx-static-site/nginx-static-site

echo "→ Pushing image"
docker push "REGION"-docker.pkg.dev/"PROJECT_ID"/nginx-static-site/nginx-static-site


# ------------ TASK 6 ------------
echo "→ Deploying Cloud Run service"
gcloud run deploy nginx-static-site \
    --image "REGION"-docker.pkg.dev/"PROJECT_ID"/nginx-static-site/nginx-static-site \
    --platform managed \
    --region "REGION" \
    --allow-unauthenticated

echo "→ Fetching service URL"
gcloud run services describe nginx-static-site \
    --platform managed \
    --region "REGION" \
    --format='value(status.url)'


echo "=============================="
echo " Script Completed (All Tasks)"
echo "=============================="
