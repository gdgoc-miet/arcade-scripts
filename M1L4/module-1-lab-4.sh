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

echo "${BG_PURPLE}${BOLD}Starting Module 1 — Lab 4 (Go Modules in Artifact Registry)${RESET}"

# ---------------------------------------
# AUTO-DETECT PROJECT + REGION
# ---------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

if [[ -z "$REGION" ]]; then
    REGION="us-east1"
fi

echo "${CYAN}${BOLD}→ Project detected: $PROJECT_ID${RESET}"
echo "${CYAN}${BOLD}→ Region detected : $REGION${RESET}"

# ---------------------------------------
# TASK 1 — ENABLE API + CREATE REPO
# ---------------------------------------
echo "${GREEN}→ Enabling Artifact Registry API${RESET}"
gcloud services enable artifactregistry.googleapis.com --quiet

echo "${GREEN}→ Setting project & region${RESET}"
gcloud config set project "$PROJECT_ID" --quiet
gcloud config set compute/region "$REGION" --quiet

echo "${GREEN}→ Creating Go Artifact Registry repo (my-go-repo)${RESET}"
gcloud artifacts repositories create my-go-repo \
    --repository-format=go \
    --location="$REGION" \
    --description="Go repository" || true

echo "${YELLOW}→ Waiting 10 seconds for repository to initialize...${RESET}"
sleep 10

echo "${GREEN}→ Verifying repository${RESET}"
gcloud artifacts repositories describe my-go-repo --location="$REGION"

# ---------------------------------------
# TASK 2 — Configure Go Authentication
# ---------------------------------------
echo "${GREEN}→ Configuring Go environment${RESET}"
go env -w GOPRIVATE=cloud.google.com/"$PROJECT_ID"

echo "${GREEN}→ Setting GONOPROXY & authenticating Go${RESET}"
export GONOPROXY=github.com/GoogleCloudPlatform/artifact-registry-go-tools
GOPROXY=proxy.golang.org go run github.com/GoogleCloudPlatform/artifact-registry-go-tools/cmd/auth@latest add-locations --locations="$REGION"

# ---------------------------------------
# TASK 3 — Create Go Module
# ---------------------------------------
echo "${GREEN}→ Creating Go module folder${RESET}"
mkdir -p hello
cd hello

echo "${GREEN}→ Initializing Go module${RESET}"
go mod init labdemo.app/hello

echo "${GREEN}→ Writing hello.go${RESET}"
cat > hello.go <<EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go module from Artifact Registry!")
}
EOF

echo "${GREEN}→ Building module (optional)${RESET}"
go build || true

# ---------------------------------------
# TASK 4 — Git Setup
# ---------------------------------------
echo "${GREEN}→ Configuring Git${RESET}"
git config --global user.email "student@example.com"
git config --global user.name "cls"
git config --global init.defaultBranch main

git init
git add .
git commit -m "Initial commit"
git tag v1.0.0

# ---------------------------------------
# TASK 5 — Upload Go Module
# ---------------------------------------
echo "${GREEN}→ Uploading module to Artifact Registry${RESET}"

gcloud artifacts go upload \
  --repository=my-go-repo \
  --location="$REGION" \
  --module-path=labdemo.app/hello \
  --version=v1.0.0 \
  --source=. \
  --quiet

echo "${GREEN}→ Listing packages in Artifact Registry${RESET}"
gcloud artifacts packages list \
  --repository=my-go-repo \
  --location="$REGION"

echo "${BG_GREEN}${BOLD}🎉 Congratulations! Module 1 Lab 4 Completed Successfully! 🎉${RESET}"
