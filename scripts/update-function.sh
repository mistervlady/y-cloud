#!/bin/bash

# Update Cloud Function script

set -e

FUNCTION_NAME=${FUNCTION_NAME:-"ping-function"}
SERVICE_ACCOUNT_ID=${SERVICE_ACCOUNT_ID}

if [ -z "$SERVICE_ACCOUNT_ID" ]; then
    echo "Error: SERVICE_ACCOUNT_ID environment variable must be set"
    echo "Example:"
    echo "  export SERVICE_ACCOUNT_ID=aje***********"
    exit 1
fi

echo "Creating function archive..."
cd ../function
zip -r function.zip index.js package.json

echo "Updating Cloud Function..."
yc serverless function version create \
    --function-name ${FUNCTION_NAME} \
    --runtime nodejs18 \
    --entrypoint index.handler \
    --memory 128m \
    --execution-timeout 3s \
    --source-path function.zip \
    --service-account-id ${SERVICE_ACCOUNT_ID}

echo "Cleaning up..."
rm function.zip

echo "Function updated successfully!"
