#!/bin/bash
#
# Update Serverless Container script (safe version)
# All required variables must be provided via environment
#

set -euo pipefail

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Updating Serverless Container ==="
echo ""

# ---- Required environment variables ----
REQUIRED_VARS=(
  CONTAINER_NAME
  REGISTRY_ID
  IMAGE_NAME
  SERVICE_ACCOUNT_ID
  YDB_ENDPOINT
  YDB_DATABASE
)

echo "Checking required environment variables..."

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "Environment variable $VAR is not set"
    exit 1
  fi
done

echo "All required variables are set"
echo ""

# ---- Build Docker image ----
echo "Building Docker image..."
cd "$PROJECT_ROOT/backend"

# Ensure buildx builder exists
docker buildx create --use --name yc-builder >/dev/null 2>&1 || docker buildx use yc-builder

echo "Building & pushing image to registry..."
docker buildx build \
  --platform linux/amd64 \
  -t "cr.yandex/${REGISTRY_ID}/${IMAGE_NAME}:latest" \
  --push \
  .

echo ""

# ---- Deploy container revision ----
echo "Deploying new container revision..."

yc serverless container revision deploy \
  --container-name "$CONTAINER_NAME" \
  --image "cr.yandex/${REGISTRY_ID}/${IMAGE_NAME}:latest" \
  --cores 1 \
  --memory 512MB \
  --execution-timeout 30s \
  --service-account-id "$SERVICE_ACCOUNT_ID" \
  --environment \
    YDB_ENDPOINT="$YDB_ENDPOINT",\
    YDB_DATABASE="$YDB_DATABASE"

echo ""
echo "Container updated successfully"
