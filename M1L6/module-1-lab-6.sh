#!/bin/bash
set -euo pipefail

# ---------------------------------------
# Simple Colors (no tput this time)
# ---------------------------------------
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"
BOLD="\e[1m"

echo -e "${BOLD}Starting Module 1 — Lab 6 (Python Packages in Artifact Registry)${RESET}"

# ---------------------------------------
# AUTO-DETECT PROJECT + REGION
# ---------------------------------------
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud compute project-info describe --project "$PROJECT_ID" \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")

if [[ -z "$REGION" ]]; then
    REGION="us-east1"
fi

echo -e "${CYAN}${BOLD}→ Project detected: $PROJECT_ID${RESET}"
echo -e "${CYAN}${BOLD}→ Region detected : $REGION${RESET}"

# ---------------------------------------
# TASK 1 — ENABLE API + CONFIG PROJECT + REGION
# ---------------------------------------
echo -e "${GREEN}→ Enabling Artifact Registry API${RESET}"
gcloud services enable artifactregistry.googleapis.com --quiet

echo -e "${GREEN}→ Setting project & region${RESET}"
gcloud config set project "$PROJECT_ID" --quiet
gcloud config set compute/region "$REGION" --quiet

# ---------------------------------------
# TASK 2 — CREATE PYTHON ARTIFACT REGISTRY REPO
# ---------------------------------------
echo -e "${GREEN}→ Creating Python Artifact Registry repository (my-python-repo)${RESET}"
gcloud artifacts repositories create my-python-repo \
    --repository-format=python \
    --location="$REGION" \
    --description="Python package repository" || true

echo -e "${YELLOW}→ Waiting 10 seconds for repository to initialize...${RESET}"
sleep 10

# ---------------------------------------
# TASK 3 — CONFIGURE PIP AUTH
# ---------------------------------------
echo -e "${GREEN}→ Installing Artifact Registry pip auth plugin${RESET}"
pip install --user keyrings.google-artifactregistry-auth

echo -e "${GREEN}→ Configuring pip to use Artifact Registry${RESET}"
pip config set global.extra-index-url \
    https://"$REGION"-python.pkg.dev/"$PROJECT_ID"/my-python-repo/simple

# ---------------------------------------
# TASK 4 — CREATE SAMPLE PYTHON PACKAGE
# ---------------------------------------
echo -e "${GREEN}→ Creating Python package structure${RESET}"
mkdir -p my-package/my_package
cd my-package

echo -e "${GREEN}→ Creating setup.py${RESET}"
cat > setup.py <<EOF
from setuptools import setup, find_packages

setup(
    name='my_package',
    version='0.1.0',
    author='cls',
    author_email='student@example.com',
    packages=find_packages(exclude=['tests']),
    description='A sample Python package',
)
EOF

echo -e "${GREEN}→ Creating __init__.py${RESET}"
echo "" > my_package/__init__.py

echo -e "${GREEN}→ Creating my_module.py${RESET}"
cat > my_package/my_module.py <<EOF
def hello_world():
    return 'Hello, world!'
EOF

# ---------------------------------------
# TASK 5 — INSTALL TWINE + BUILD + UPLOAD
# ---------------------------------------
echo -e "${GREEN}→ Installing twine${RESET}"
pip install --user twine

echo -e "${GREEN}→ Building Python package${RESET}"
python3 setup.py sdist bdist_wheel

echo -e "${GREEN}→ Uploading package to Artifact Registry${RESET}"
python3 -m twine upload \
  --repository-url https://"$REGION"-python.pkg.dev/"$PROJECT_ID"/my-python-repo/ \
  dist/*

# ---------------------------------------
# TASK 6 — VERIFY PACKAGE
# ---------------------------------------
echo -e "${GREEN}→ Listing Python packages in Artifact Registry${RESET}"
gcloud artifacts packages list \
    --repository=my-python-repo \
    --location="$REGION"

echo -e "${BOLD}${GREEN}🎉 Module 1 — Lab 6 Completed Successfully! 🎉${RESET}"
