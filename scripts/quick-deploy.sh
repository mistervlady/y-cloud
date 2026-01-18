#!/bin/bash

# Quick deploy script for Guestbook application
# This script automates the full deployment process

set -e

echo "=== Yandex Cloud Guestbook Quick Deploy ==="
echo ""

# Check prerequisites
command -v yc >/dev/null 2>&1 || { echo "Error: yc CLI is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Error: docker is required but not installed. Aborting." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed. Aborting." >&2; exit 1; }

echo "✓ Prerequisites check passed"
echo ""

# Get folder ID
FOLDER_ID=$(yc config get folder-id)
echo "Using folder: $FOLDER_ID"
echo ""

# Create service account
echo "Step 1: Creating service account..."
yc iam service-account create --name guestbook-sa --folder-id $FOLDER_ID 2>/dev/null || echo "  Service account already exists"
SA_ID=$(yc iam service-account get guestbook-sa --folder-id $FOLDER_ID --format json | jq -r .id)
echo "  Service Account ID: $SA_ID"

# Assign roles
echo "  Assigning roles..."
yc resource-manager folder add-access-binding $FOLDER_ID --role serverless.containers.invoker --subject serviceAccount:$SA_ID 2>/dev/null || true
yc resource-manager folder add-access-binding $FOLDER_ID --role serverless.functions.invoker --subject serviceAccount:$SA_ID 2>/dev/null || true
yc resource-manager folder add-access-binding $FOLDER_ID --role ydb.editor --subject serviceAccount:$SA_ID 2>/dev/null || true
yc resource-manager folder add-access-binding $FOLDER_ID --role storage.viewer --subject serviceAccount:$SA_ID 2>/dev/null || true
yc resource-manager folder add-access-binding $FOLDER_ID --role container-registry.images.pusher --subject serviceAccount:$SA_ID 2>/dev/null || true
echo ""

# Create YDB
echo "Step 2: Creating YDB database..."
yc ydb database create guestbook-db --serverless --folder-id $FOLDER_ID 2>/dev/null || echo "  Database already exists"
sleep 5
YDB_INFO=$(yc ydb database get guestbook-db --folder-id $FOLDER_ID --format json)
YDB_ENDPOINT=$(echo $YDB_INFO | jq -r .endpoint)
YDB_DATABASE=$(echo $YDB_INFO | jq -r .path)
echo "  YDB Endpoint: $YDB_ENDPOINT"
echo "  YDB Database: $YDB_DATABASE"
echo ""

# Initialize YDB schema
echo "Step 3: Initializing YDB schema..."
export YDB_ENDPOINT
export YDB_DATABASE
cd scripts
./ydb-init.sh || echo "  Schema already initialized"
cd ..
echo ""

# Create Container Registry
echo "Step 4: Creating Container Registry..."
yc container registry create --name guestbook-registry --folder-id $FOLDER_ID 2>/dev/null || echo "  Registry already exists"
REGISTRY_ID=$(yc container registry get guestbook-registry --folder-id $FOLDER_ID --format json | jq -r .id)
echo "  Registry ID: $REGISTRY_ID"
yc container registry configure-docker
echo ""

# Create Object Storage bucket
echo "Step 5: Creating Object Storage bucket..."
BUCKET_NAME="guestbook-frontend-$(date +%s)"
yc storage bucket create --name $BUCKET_NAME --folder-id $FOLDER_ID
echo "  Bucket: $BUCKET_NAME"
echo ""

# Upload frontend files
echo "Step 6: Uploading frontend files..."
cd frontend
yc storage s3api put-object --bucket $BUCKET_NAME --key index.html --body index.html
yc storage s3api put-object --bucket $BUCKET_NAME --key style.css --body style.css --content-type text/css
yc storage s3api put-object --bucket $BUCKET_NAME --key app.js --body app.js --content-type application/javascript
cd ..
echo "  ✓ Frontend files uploaded"
echo ""

# Create and deploy Serverless Container
echo "Step 7: Creating Serverless Container..."
yc serverless container create --name guestbook-backend --folder-id $FOLDER_ID 2>/dev/null || echo "  Container already exists"
export REGISTRY_ID
export SERVICE_ACCOUNT_ID=$SA_ID
export CONTAINER_NAME="guestbook-backend"
cd scripts
./update-container.sh
cd ..
CONTAINER_ID=$(yc serverless container get guestbook-backend --folder-id $FOLDER_ID --format json | jq -r .id)
echo "  Container ID: $CONTAINER_ID"
echo ""

# Create and deploy Cloud Function
echo "Step 8: Creating Cloud Function..."
yc serverless function create --name ping-function --folder-id $FOLDER_ID 2>/dev/null || echo "  Function already exists"
cd scripts
./update-function.sh
cd ..
FUNCTION_ID=$(yc serverless function get ping-function --folder-id $FOLDER_ID --format json | jq -r .id)
echo "  Function ID: $FUNCTION_ID"
echo ""

# Create API Gateway
echo "Step 9: Creating API Gateway..."
cp api-gateway.yaml api-gateway-deploy.yaml
sed -i "s/\${BUCKET_NAME}/$BUCKET_NAME/g" api-gateway-deploy.yaml
sed -i "s/\${CONTAINER_ID}/$CONTAINER_ID/g" api-gateway-deploy.yaml
sed -i "s/\${FUNCTION_ID}/$FUNCTION_ID/g" api-gateway-deploy.yaml
sed -i "s/\${SERVICE_ACCOUNT_ID}/$SA_ID/g" api-gateway-deploy.yaml

yc serverless api-gateway create --name guestbook-gateway --spec api-gateway-deploy.yaml --folder-id $FOLDER_ID 2>/dev/null || \
yc serverless api-gateway update guestbook-gateway --spec api-gateway-deploy.yaml --folder-id $FOLDER_ID

GATEWAY_URL=$(yc serverless api-gateway get guestbook-gateway --folder-id $FOLDER_ID --format json | jq -r .domain)
echo "  ✓ API Gateway created"
echo ""

# Save configuration
cat > .env.local <<EOF
# Auto-generated configuration from quick-deploy
YC_FOLDER_ID=$FOLDER_ID
SERVICE_ACCOUNT_ID=$SA_ID
REGISTRY_ID=$REGISTRY_ID
YDB_ENDPOINT=$YDB_ENDPOINT
YDB_DATABASE=$YDB_DATABASE
BUCKET_NAME=$BUCKET_NAME
CONTAINER_ID=$CONTAINER_ID
CONTAINER_NAME=guestbook-backend
FUNCTION_ID=$FUNCTION_ID
FUNCTION_NAME=ping-function
GATEWAY_URL=https://$GATEWAY_URL
EOF

echo "=== Deployment Complete! ==="
echo ""
echo "Application URL: https://$GATEWAY_URL"
echo "Ping Function: https://$GATEWAY_URL/api/ping-fn"
echo ""
echo "Configuration saved to .env.local"
echo ""
echo "Open https://$GATEWAY_URL in your browser to use the guestbook!"
