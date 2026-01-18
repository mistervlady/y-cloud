#!/bin/bash

# YDB initialization script
# This script creates the messages table in YDB

set -e

if [ -z "$YDB_ENDPOINT" ] || [ -z "$YDB_DATABASE" ]; then
    echo "Error: YDB_ENDPOINT and YDB_DATABASE environment variables must be set"
    echo "Example:"
    echo "  export YDB_ENDPOINT=grpcs://ydb.serverless.yandexcloud.net:2135"
    echo "  export YDB_DATABASE=/ru-central1/b1g***********/etn***********"
    exit 1
fi

echo "Initializing YDB schema..."
echo "Endpoint: $YDB_ENDPOINT"
echo "Database: $YDB_DATABASE"

# Create messages table
ydb -e "$YDB_ENDPOINT" -d "$YDB_DATABASE" yql -s "
CREATE TABLE messages (
    id Utf8,
    author Utf8,
    message Utf8,
    timestamp Utf8,
    PRIMARY KEY (id)
);"

echo "Schema initialized successfully!"
echo "Table 'messages' created with columns: id, author, message, timestamp"
