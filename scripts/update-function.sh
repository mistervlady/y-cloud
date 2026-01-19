#!/bin/bash
#
# Update Cloud Function script (safe version)
# All required variables must be provided via environment
#

set -euo pipefail

# Resolve paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Updating Cloud Function ==="
echo ""

# ---- Required environment variables ----
REQUIRED_VARS=(
  FUNCTION_NAME
  SERVICE_ACCOUNT_ID
)

echo "Checking required environment variables..."

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "Environment variable $VAR is not set"
    exit 1
  fi
done

echo "✓ All required variables are set"
echo ""

# ---- Build function archive ----
echo "Creating function archive..."
cd "$PROJECT_ROOT/function"

rm -f function.zip
zip -r function.zip index.py requirements.txt >/dev/null

echo "✓ Archive created"
echo ""

# ---- Deploy function version ----
echo "Deploying new function version..."

yc serverless function version create \
  --function-name "$FUNCTION_NAME" \
  --runtime python311 \
  --entrypoint index.handler \
  --memory 128m \
  --execution-timeout 3s \
  --source-path function.zip \
  --service-account-id "$SERVICE_ACCOUNT_ID"

echo ""

# ---- Cleanup ----
rm -f function.zip

echo "Function updated successfully"
