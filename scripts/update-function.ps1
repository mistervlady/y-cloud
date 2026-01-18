# Update Cloud Function script (PowerShell)

$ErrorActionPreference = "Stop"

# Get the script directory and project root
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

$FUNCTION_NAME = if ($env:FUNCTION_NAME) { $env:FUNCTION_NAME } else { "ping-function" }
$SERVICE_ACCOUNT_ID = $env:SERVICE_ACCOUNT_ID

if (-not $SERVICE_ACCOUNT_ID) {
    Write-Error "Error: SERVICE_ACCOUNT_ID environment variable must be set"
    Write-Host "Example:"
    Write-Host '  $env:SERVICE_ACCOUNT_ID="aje***********"'
    exit 1
}

Write-Host "Creating function archive..."
Set-Location "$PROJECT_ROOT\function"
Compress-Archive -Path index.py,requirements.txt -DestinationPath function.zip -Force

Write-Host "Updating Cloud Function..."
yc serverless function version create `
    --function-name $FUNCTION_NAME `
    --runtime python311 `
    --entrypoint index.handler `
    --memory 128m `
    --execution-timeout 3s `
    --source-path function.zip `
    --service-account-id $SERVICE_ACCOUNT_ID

Write-Host "Cleaning up..."
Remove-Item function.zip

Write-Host "Function updated successfully!"
