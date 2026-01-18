# YDB initialization script (PowerShell)
# This script creates the messages table in YDB

$ErrorActionPreference = "Stop"

if (-not $env:YDB_ENDPOINT -or -not $env:YDB_DATABASE) {
    Write-Error "Error: YDB_ENDPOINT and YDB_DATABASE environment variables must be set"
    Write-Host "Example:"
    Write-Host '  $env:YDB_ENDPOINT="grpcs://ydb.serverless.yandexcloud.net:2135"'
    Write-Host '  $env:YDB_DATABASE="/ru-central1/b1g***********/etn***********"'
    exit 1
}

Write-Host "Initializing YDB schema..."
Write-Host "Endpoint: $env:YDB_ENDPOINT"
Write-Host "Database: $env:YDB_DATABASE"

# Create messages table
$query = @"
CREATE TABLE messages (
    id Utf8,
    author Utf8,
    message Utf8,
    timestamp Utf8,
    PRIMARY KEY (id)
);
"@

ydb -e $env:YDB_ENDPOINT -d $env:YDB_DATABASE yql -s $query

Write-Host "Schema initialized successfully!"
Write-Host "Table 'messages' created with columns: id, author, message, timestamp"
