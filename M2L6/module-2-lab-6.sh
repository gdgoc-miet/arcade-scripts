#!/bin/bash
set -euo pipefail

echo ""
echo "=============================================================="
echo "   🐳 Starting Module 2 — Lab 6 (Docker Volumes + Bind Mount)"
echo "=============================================================="
echo ""

# ------------------------------------------------------
# AUTO-DETECT PROJECT / REGION / ZONE (if needed)
# ------------------------------------------------------
PROJECT_ID=$(gcloud config get-value project || true)
REGION=$(gcloud config get-value compute/region || echo "us-central1")
ZONE=$(gcloud config get-value compute/zone || echo "${REGION}-a")

echo "→ Current Docker Lab (No GCP resources needed)"
echo "→ Project ID (not required, but detected): $PROJECT_ID"
echo ""

# ------------------------------------------------------
# TASK 1 — Conceptual (No commands)
# ------------------------------------------------------
echo "→ Task 1: Concepts covered (Volumes, Bind Mounts, tmpfs). No commands executed."
echo ""

# ------------------------------------------------------
# TASK 2 — Named Volumes
# ------------------------------------------------------
echo "→ Creating named volume: mydata"
docker volume create mydata

echo "→ Inspecting volume"
docker volume inspect mydata

echo "→ Running container with mydata mounted at /data"
docker run -it --name temp1 -v mydata:/data alpine sh -c "echo 'Hello from inside the container!' > /data/myfile.txt"

echo "→ Stopping container"
docker stop temp1 || true

echo "→ Removing container"
docker rm temp1 || true

echo "→ Running new container with same volume"
docker run -it --name temp2 -v mydata:/data alpine sh -c "echo 'Contents of volume:' && ls -l /data && cat /data/myfile.txt"

echo "→ Cleaning up second container"
docker stop temp2 || true
docker rm temp2 || true

# Optional: remove volume
# docker volume rm mydata

echo ""

# ------------------------------------------------------
# TASK 3 — Bind Mounts
# ------------------------------------------------------
HOST_DIR="$HOME/host_data"

echo "→ Creating host directory: $HOST_DIR"
mkdir -p "$HOST_DIR"

echo "→ Creating host file"
echo "Hello from the host!" > "$HOST_DIR/hostfile.txt"

echo "→ Running alpine with bind mount"
docker run -it --name bindtest -v "$HOST_DIR":/data alpine sh -c "echo 'This line added from container' >> /data/hostfile.txt && cat /data/hostfile.txt"

echo "→ Checking file on host"
cat "$HOST_DIR/hostfile.txt"

echo "→ Cleaning up container"
docker stop bindtest || true
docker rm bindtest || true

# Optional host cleanup:
# rm -rf "$HOST_DIR"

echo ""

# ------------------------------------------------------
# TASK 4 — Docker Compose Volume Example
# ------------------------------------------------------
echo "→ Creating docker-compose.yml"
cat > docker-compose.yml <<EOF
version: "3.3"
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - web_data:/usr/share/nginx/html
volumes:
  web_data:
EOF

echo "→ Creating index.html"
cat > index.html <<EOF
<html>
<head>
  <title>Docker Compose Volume Example</title>
</head>
<body>
  <div><strong>Hello from Docker Compose!</strong></div>
  <p>This content is served from a Docker volume.</p>
</body>
</html>
EOF

echo "→ Starting docker-compose"
docker-compose up -d

echo "→ Checking site at localhost:8080"
curl -s http://localhost:8080 || echo "Open in browser: http://localhost:8080"

echo "→ Stopping docker-compose"
docker-compose down

echo ""

# ------------------------------------------------------
# FINAL MESSAGE
# ------------------------------------------------------
echo "=============================================================="
echo " 🎉 Module 2 — Lab 6 Completed Successfully!"
echo "=============================================================="
