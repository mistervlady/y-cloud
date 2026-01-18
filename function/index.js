const os = require('os');

module.exports.handler = async function (event, context) {
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            message: 'pong',
            timestamp: new Date().toISOString(),
            functionVersion: 'v1.0.0',
            instanceId: os.hostname(),
            requestId: context.requestId
        })
    };
    
    return response;
};
