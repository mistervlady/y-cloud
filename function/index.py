import json
import socket
from datetime import datetime


def handler(event, context):
    """Cloud Function handler"""
    response = {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
        },
        'body': json.dumps({
            'message': 'pong',
            'timestamp': datetime.now().isoformat(),
            'functionVersion': 'v1.0.0',
            'instanceId': socket.gethostname(),
            'requestId': context.request_id
        })
    }
    
    return response
