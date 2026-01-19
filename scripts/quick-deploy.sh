#!/bin/bash
#
# Safe Quick Deploy script for Guestbook application
# Requires all environment variables to be set manually
#

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Guestbook Safe Deploy ==="
echo ""

# ---- Required environment variables ----
REQUIRED_VARS=(
  YC_FOLDER_ID
  SERVICE_ACCOUNT_ID
  REGISTRY_ID
  YDB_ENDPOINT
  YDB_DATABASE
  BUCKET_NAME
  CONTAINER_NAME
  FUNCTION_NAME
  API_GATEWAY_NAME
)

echo "Checking required environment variables..."

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "Environment variable $VAR is not set"
    echo "Please export all required variables before running the script."
    exit 1
  fi
done

echo "All required environment variables are set"
echo ""

# ---- Prerequisites ----
command -v yc >/dev/null 2>&1 || { echo "yc CLI is required"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker is required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }

echo "Prerequisites check passed"
echo ""

# ---- Configure Docker for YCR ----
echo "Configuring Docker for Yandex Container Registry..."
yc container registry configure-docker
echo ""

# ---- Initialize YDB schema (idempotent) ----
echo "Initializing YDB schema (if needed)..."
export YDB_ENDPOINT
export YDB_DATABASE
bash "$SCRIPT_DIR/ydb-init.sh" || echo "Schema already exists"
echo ""

# ---- Deploy Serverless Container ----
echo "Deploying Serverless Container..."
export SERVICE_ACCOUNT_ID
export REGISTRY_ID
export CONTAINER_NAME
bash "$SCRIPT_DIR/update-container.sh"

CONTAINER_ID=$(yc serverless container get "$CONTAINER_NAME" \
  --folder-id "$YC_FOLDER_ID" \
  --format json | jq -r .id)

echo "Container deployed: $CONTAINER_ID"
echo ""

# ---- Deploy Cloud Function ----
echo "Deploying Cloud Function..."
export FUNCTION_NAME
bash "$SCRIPT_DIR/update-_
