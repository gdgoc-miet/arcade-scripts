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

echo "${BG_PURPLE}${BOLD}Starting Module 1 — Lab 5 (NPM Packages in Artifact Registry)${RESET}"

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
# TASK 1 — ENABLE API + CREATE NPM REPO
# ---------------------------------------
echo "${GREEN}→ Enabling Artifact Registry API${RESET}"
gcloud services enable artifactregistry.googleapis.com --quiet

echo "${GREEN}→ Setting project & region${RESET}"
gcloud config set project "$PROJECT_ID" --quiet
gcloud config set compute/region "$REGION" --quiet

echo "${GREEN}→ Creating NPM Artifact Registry repo (my-npm-repo)${RESET}"
gcloud artifacts repositories create my-npm-repo \
    --repository-format=npm \
    --location="$REGION" \
    --description="NPM repository" || true

echo "${YELLOW}→ Waiting 10 seconds for repository to initialize...${RESET}"
sleep 10

# ---------------------------------------
# TASK 2 — CREATE NPM PACKAGE
# ---------------------------------------
echo "${GREEN}→ Creating npm package directory${RESET}"
mkdir -p my-npm-package
cd my-npm-package

echo "${GREEN}→ Initializing npm package${RESET}"
npm init --scope=@"$PROJECT_ID" -y

echo "${GREEN}→ Creating index.js${RESET}"
echo 'console.log(`Hello from my-npm-package!`);' > index.js

# ---------------------------------------
# TASK 3 — CONFIGURE NPM AUTH
# ---------------------------------------
echo "${GREEN}→ Generating .npmrc settings from Artifact Registry${RESET}"
gcloud artifacts print-settings npm \
    --project="$PROJECT_ID" \
    --repository=my-npm-repo \
    --location="$REGION" \
    --scope=@"$PROJECT_ID" > .npmrc

echo "${GREEN}→ Configuring Docker auth for npm.pkg.dev${RESET}"
gcloud auth configure-docker "$REGION-npm.pkg.dev" --quiet

echo "${GREEN}→ Updating package.json to include artifactregistry-login script${RESET}"
cat > package.json <<EOF
{
  "name": "@$PROJECT_ID/my-npm-package",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "artifactregistry-login": "npx google-artifactregistry-auth --repo-config=./.npmrc --credential-config=./.npmrc",
    "test": "echo \\"Error: no test specified\\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "type": "commonjs"
}
EOF

echo "${GREEN}→ Refreshing authentication token${RESET}"
npm run artifactregistry-login

echo "${GREEN}→ Viewing updated .npmrc${RESET}"
cat .npmrc

# ---------------------------------------
# PUBLISH PACKAGE
# ---------------------------------------
echo "${GREEN}→ Publishing package to Artifact Registry${RESET}"
npm publish --registry=https://"$REGION"-npm.pkg.dev/"$PROJECT_ID"/my-npm-repo/

# ---------------------------------------
# VERIFY PACKAGE
# ---------------------------------------
echo "${GREEN}→ Listing NPM packages in Artifact Registry${RESET}"
gcloud artifacts packages list \
    --repository=my-npm-repo \
    --location="$REGION"

echo "${BG_GREEN}${BOLD}🎉 Congratulations! Module 1 Lab 5 Completed Successfully! 🎉${RESET}"
