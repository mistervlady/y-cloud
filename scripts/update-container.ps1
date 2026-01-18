# Update Serverless Container script (PowerShell)

$ErrorActionPreference = "Stop"

# Get the script directory and project root
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

$CONTAINER_NAME = if ($env:CONTAINER_NAME) { $env:CONTAINER_NAME } else { "guestbook-backend" }
$REGISTRY_ID = $env:REGISTRY_ID
$IMAGE_NAME = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "guestbook-backend" }
$SERVICE_ACCOUNT_ID = $env:SERVICE_ACCOUNT_ID

if (-not $REGISTRY_ID -or -not $SERVICE_ACCOUNT_ID) {
    Write-Error "Error: REGISTRY_ID and SERVICE_ACCOUNT_ID environment variables must be set"
    Write-Host "Example:"
    Write-Host '  $env:REGISTRY_ID="crp***********"'
    Write-Host '  $env:SERVICE_ACCOUNT_ID="aje***********"'
    exit 1
}

Write-Host "Building Docker image..."
Set-Location "$PROJECT_ROOT\backend"
docker build -t "cr.yandex/$REGISTRY_ID/${IMAGE_NAME}:latest" .

Write-Host "Pushing image to Yandex Container Registry..."
docker push "cr.yandex/$REGISTRY_ID/${IMAGE_NAME}:latest"

Write-Host "Updating Serverless Container..."
yc serverless container revision deploy `
    --container-name $CONTAINER_NAME `
    --image "cr.yandex/$REGISTRY_ID/${IMAGE_NAME}:latest" `
    --cores 1 `
    --memory 512MB `
    --execution-timeout 30s `
    --service-account-id $SERVICE_ACCOUNT_ID `
    --environment "YDB_ENDPOINT=$env:YDB_ENDPOINT,YDB_DATABASE=$env:YDB_DATABASE"

Write-Host "Container updated successfully!"
