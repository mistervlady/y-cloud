import os
import json
import time
import random
import socket
import uuid
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import ydb

BACKEND_VERSION = 'v1.0.0'
INSTANCE_ID = str(uuid.uuid4())
PORT = int(os.environ.get('PORT', 8080))

YDB_ENDPOINT = os.environ.get('YDB_ENDPOINT', 'grpcs://ydb.serverless.yandexcloud.net:2135')
YDB_DATABASE = os.environ.get('YDB_DATABASE', '/ru-central1/b1g***********')

app = Flask(__name__)
CORS(app)

driver = None
is_ready = False


def init_ydb():
    """Initialize YDB driver"""
    global driver, is_ready
    try:
        driver_config = ydb.DriverConfig(
            YDB_ENDPOINT,
            YDB_DATABASE,
            credentials=ydb.iam.MetadataUrlCredentials(),
        )
        driver = ydb.Driver(driver_config)
        driver.wait(timeout=10, fail_fast=True)
        is_ready = True
        print('YDB driver initialized successfully')
    except Exception as error:
        print(f'Failed to initialize YDB: {error}')
        is_ready = False


def get_messages():
    """Get messages from YDB"""
    if not is_ready:
        return []

    try:
        query = """
            SELECT id, author, message, timestamp
            FROM messages
            ORDER BY timestamp DESC
            LIMIT 100;
        """

        session = driver.table_client.session().create()
        result_sets = session.transaction().execute(
            query,
            commit_tx=True,
        )

        messages = []
        for row in result_sets[0].rows:
            try:
                timestamp = datetime.fromisoformat(row.timestamp).isoformat()
            except Exception:
                print(f'Invalid timestamp format: {row.timestamp}')
                timestamp = datetime.now().isoformat()

            messages.append({
                'id': row.id,
                'author': row.author,
                'message': row.message,
                'timestamp': timestamp
            })

        return messages

    except Exception as error:
        print(f'Failed to get messages: {error}')
        return []


def add_message(author, message):
    """Add a message to YDB"""
    if not is_ready:
        raise Exception('Database not ready')

    try:
        msg_id = str(int(time.time() * 1000)) + ''.join(
            random.choices('abcdefghijklmnopqrstuvwxyz0123456789', k=7)
        )
        timestamp = datetime.now().isoformat()

        query = """
            DECLARE $id AS Utf8;
            DECLARE $author AS Utf8;
            DECLARE $message AS Utf8;
            DECLARE $timestamp AS Utf8;

            INSERT INTO messages (id, author, message, timestamp)
            VALUES ($id, $author, $message, $timestamp);
        """

        session = driver.table_client.session().create()
        prepared_query = session.prepare(query)
        session.transaction().execute(
            prepared_query,
            {
                '$id': msg_id,
                '$author': author,
                '$message': message,
                '$timestamp': timestamp,
            },
            commit_tx=True,
        )

        return {
            'id': msg_id,
            'author': author,
            'message': message,
            'timestamp': timestamp
        }

    except Exception as error:
        print(f'Failed to add message: {error}')
        raise error


@app.route('/api/info', methods=['GET'])
def api_info():
    """Return backend information"""
    return jsonify({
        'version': BACKEND_VERSION,
        'instanceId': INSTANCE_ID,
        'ready': is_ready
    })


@app.route('/api/messages', methods=['GET'])
def get_messages_route():
    """Get all messages"""
    try:
        messages = get_messages()
        return jsonify({'messages': messages})
    except Exception:
        return jsonify({'error': 'Internal Server Error'}), 500


@app.route('/api/messages', methods=['POST'])
def post_message_route():
    """Post a new message"""
    try:
        data = request.get_json()

        if not data or 'author' not in data or 'message' not in data:
            return jsonify({'error': 'Author and message are required'}), 400

        author = data['author']
        message = data['message']

        if not author or not message:
            return jsonify({'error': 'Author and message are required'}), 400

        new_message = add_message(author, message)
        return jsonify(new_message), 201

    except Exception:
        return jsonify({'error': 'Internal Server Error'}), 500


if __name__ == '__main__':
    init_ydb()
    print(f'Server running on port {PORT}')
    print(f'Backend version: {BACKEND_VERSION}')
    print(f'Instance ID: {INSTANCE_ID}')
    app.run(host='0.0.0.0', port=PORT)
