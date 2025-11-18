#!/bin/bash
set -euo pipefail

GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
BOLD="\e[1m"
RESET="\e[0m"

echo -e "${BOLD}Starting Module 1 — Lab 7 (Docker Networking + Artifact Registry)${RESET}"

# ---------------------------------------
# AUTO-DETECT PROJECT + REGION
# ---------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

[[ -z "$REGION" ]] && REGION="us-east1"

echo -e "${CYAN}→ Project: $PROJECT_ID${RESET}"
echo -e "${CYAN}→ Region : $REGION${RESET}"

# ---------------------------------------
# TASK 1 — ENVIRONMENT SETUP
# ---------------------------------------
echo -e "${GREEN}→ Setting project and region${RESET}"
gcloud config set project "$PROJECT_ID" --quiet
gcloud config set compute/region "$REGION" --quiet

echo -e "${GREEN}→ Enabling Artifact Registry API${RESET}"
gcloud services enable artifactregistry.googleapis.com --quiet

echo -e "${GREEN}→ Creating Docker repository (lab-registry)${RESET}"
gcloud artifacts repositories create lab-registry \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository" || true

echo -e "${YELLOW}→ Waiting 10 seconds for repository propagation...${RESET}"
sleep 10

echo -e "${GREEN}→ Configuring Docker authentication${RESET}"
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet

# Pull & push alpine/curl
echo -e "${GREEN}→ Pulling and pushing alpine/curl${RESET}"
docker pull alpine/curl
docker tag alpine/curl "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/alpine-curl:latest"
docker push "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/alpine-curl:latest"

# Pull & push nginx
echo -e "${GREEN}→ Pulling and pushing nginx${RESET}"
docker pull nginx:latest
docker tag nginx:latest "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/nginx:latest"
docker push "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/nginx:latest"

# ---------------------------------------
# TASK 2 — DEFAULT BRIDGE NETWORK
# ---------------------------------------
echo -e "${GREEN}→ Starting containers on default bridge network${RESET}"

docker run -d --name container1 "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/alpine-curl:latest" sleep infinity
docker run -d --name container2 "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/alpine-curl:latest" sleep infinity

docker network inspect bridge

docker exec -it container1 ping -c 2 container2 || true

docker stop container2 && docker rm container2

docker run -d --name container2 -p 8080:80 "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/nginx:latest"

docker exec -it container1 curl container2:8080 || true

# ---------------------------------------
# TASK 3 — CUSTOM NETWORK
# ---------------------------------------
echo -e "${GREEN}→ Creating custom network my-net${RESET}"
docker network create my-net

docker run -d --name container3 --network my-net "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/alpine-curl:latest" sleep infinity
docker run -d --name container4 --network my-net "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/alpine-curl:latest" sleep infinity

docker network inspect my-net

docker exec -it container3 ping -c 2 container4 || true

docker stop container4 && docker rm container4

docker run -d --name container4 --network my-net -p 8081:80 "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/nginx:latest"

docker exec -it container3 curl container4:80 || true

docker stop container4 && docker rm container4

# ---------------------------------------
# TASK 4 — PORT PUBLISHING
# ---------------------------------------
echo -e "${GREEN}→ Demonstrating port publishing${RESET}"
docker run -d --name container4 -p 8080:80 "$REGION-docker.pkg.dev/$PROJECT_ID/lab-registry/nginx:latest"

curl localhost:8080
docker port container4 80

# ---------------------------------------
# TASK 5 — CLEANUP
# ---------------------------------------
docker stop container1 container2 container3 container4 || true
docker rm   container1 container2 container3 container4 || true
docker network rm my-net || true

echo -e "${BOLD}${GREEN}🎉 Module 1 — Lab 7 Completed Successfully!${RESET}"
