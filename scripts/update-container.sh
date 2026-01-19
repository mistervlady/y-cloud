#!/bin/bash

# Update Serverless Container script

set -e

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

CONTAINER_NAME=${CONTAINER_NAME:-"guestbook-backend"}
REGISTRY_ID=${REGISTRY_ID}
IMAGE_NAME=${IMAGE_NAME:-"guestbook-backend"}
SERVICE_ACCOUNT_ID=${SERVICE_ACCOUNT_ID}

if [ -z "$REGISTRY_ID" ] || [ -z "$SERVICE_ACCOUNT_ID" ]; then
    echo "Error: REGISTRY_ID and SERVICE_ACCOUNT_ID environment variables must be set"
    echo "Example:"
    echo "  export REGISTRY_ID=crp***********"
    echo "  export SERVICE_ACCOUNT_ID=aje***********"
    exit 1
fi

echo "Building Docker image..."
cd "$PROJECT_ROOT/backend"
docker build -t cr.yandex/${REGISTRY_ID}/${IMAGE_NAME}:latest .

echo "Pushing image to Yandex Container Registry..."
docker push cr.yandex/${REGISTRY_ID}/${IMAGE_NAME}:latest

echo "Updating Serverless Container..."
yc serverless container revision deploy \
  --container-name "$CONTAINER_NAME" \
  --image "cr.yandex/${REGISTRY_ID}/${IMAGE_NAME}:latest" \
  --cores 1 \
  --memory 512MB \
  --execution-timeout 30s \
  --service-account-id "$SERVICE_ACCOUNT_ID" \
  --environment "YDB_ENDPOINT=${YDB_ENDPOINT},YDB_DATABASE=${YDB_DATABASE}"


echo "Container updated successfully!"
