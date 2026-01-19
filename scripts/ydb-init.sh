#!/bin/bash
#
# YDB schema initialization script (safe & idempotent)
# Requires YDB_ENDPOINT and YDB_DATABASE to be set explicitly
#

set -euo pipefail

echo "=== Initializing YDB schema ==="
echo ""

# ---- Required environment variables ----
REQUIRED_VARS=(
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

echo "✓ Required variables are set"
echo ""
echo "YDB Endpoint: $YDB_ENDPOINT"
echo "YDB Database: $YDB_DATABASE"
echo ""

# ---- Create table (idempotent) ----
echo "Creating table 'messages' if it does not exist..."

ydb \
  -e "$YDB_ENDPOINT" \
  -d "$YDB_DATABASE" \
  yql -s "
CREATE TABLE IF NOT EXISTS messages (
    id Utf8,
    author Utf8,
    message Utf8,
    timestamp Utf8,
    PRIMARY KEY (id)
);
"

echo ""
echo "YDB schema is ready"
echo "Table 'messages' exists"
