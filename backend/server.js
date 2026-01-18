const http = require('http');
const { Driver, getLogger, getCredentialsFromEnv } = require('ydb-sdk');
const os = require('os');

const BACKEND_VERSION = 'v1.0.0';
const INSTANCE_ID = os.hostname();
const PORT = process.env.PORT || 8080;

const YDB_ENDPOINT = process.env.YDB_ENDPOINT || 'grpcs://ydb.serverless.yandexcloud.net:2135';
const YDB_DATABASE = process.env.YDB_DATABASE || '/ru-central1/b1g***********';

let driver;
let isReady = false;

async function initYDB() {
    try {
        const authService = getCredentialsFromEnv();
        driver = new Driver({ endpoint: YDB_ENDPOINT, database: YDB_DATABASE, authService });
        const timeout = 10000;
        if (!await driver.ready(timeout)) {
            console.error(`Driver is not ready after ${timeout}ms`);
        } else {
            console.log('YDB driver initialized successfully');
            isReady = true;
        }
    } catch (error) {
        console.error('Failed to initialize YDB:', error);
    }
}

async function getMessages() {
    if (!isReady) {
        return [];
    }
    
    try {
        const query = `
            SELECT id, author, message, timestamp
            FROM messages
            ORDER BY timestamp DESC
            LIMIT 100;
        `;
        
        const result = await driver.tableClient.withSession(async (session) => {
            const { resultSets } = await session.executeQuery(query);
            return resultSets[0].rows;
        });
        
        return result.map(row => {
            let timestamp = row.timestamp;
            try {
                // Ensure timestamp is in ISO format
                timestamp = new Date(row.timestamp).toISOString();
            } catch (e) {
                console.error('Invalid timestamp format:', row.timestamp);
                timestamp = new Date().toISOString();
            }
            
            return {
                id: row.id,
                author: row.author,
                message: row.message,
                timestamp: timestamp
            };
        });
    } catch (error) {
        console.error('Failed to get messages:', error);
        return [];
    }
}

async function addMessage(author, message) {
    if (!isReady) {
        throw new Error('Database not ready');
    }
    
    try {
        const id = Date.now().toString() + Math.random().toString(36).substring(2, 9);
        const timestamp = new Date().toISOString();
        
        const query = `
            DECLARE $id AS Utf8;
            DECLARE $author AS Utf8;
            DECLARE $message AS Utf8;
            DECLARE $timestamp AS Utf8;
            
            INSERT INTO messages (id, author, message, timestamp)
            VALUES ($id, $author, $message, $timestamp);
        `;
        
        await driver.tableClient.withSession(async (session) => {
            const preparedQuery = await session.prepareQuery(query);
            await session.executeQuery(preparedQuery, {
                '$id': { type: { optionalType: { item: { typeId: 'UTF8' } } }, value: { textValue: id } },
                '$author': { type: { optionalType: { item: { typeId: 'UTF8' } } }, value: { textValue: author } },
                '$message': { type: { optionalType: { item: { typeId: 'UTF8' } } }, value: { textValue: message } },
                '$timestamp': { type: { optionalType: { item: { typeId: 'UTF8' } } }, value: { textValue: timestamp } }
            });
        });
        
        return { id, author, message, timestamp };
    } catch (error) {
        console.error('Failed to add message:', error);
        throw error;
    }
}

const server = http.createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    console.log(`${req.method} ${req.url}`);
    
    if (req.url === '/api/info' && req.method === 'GET') {
        res.writeHead(200);
        res.end(JSON.stringify({
            version: BACKEND_VERSION,
            instanceId: INSTANCE_ID,
            ready: isReady
        }));
        return;
    }
    
    if (req.url === '/api/messages' && req.method === 'GET') {
        try {
            const messages = await getMessages();
            res.writeHead(200);
            res.end(JSON.stringify({ messages }));
        } catch (error) {
            res.writeHead(500);
            res.end(JSON.stringify({ error: 'Internal Server Error' }));
        }
        return;
    }
    
    if (req.url === '/api/messages' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });
        
        req.on('end', async () => {
            try {
                const { author, message } = JSON.parse(body);
                
                if (!author || !message) {
                    res.writeHead(400);
                    res.end(JSON.stringify({ error: 'Author and message are required' }));
                    return;
                }
                
                const newMessage = await addMessage(author, message);
                res.writeHead(201);
                res.end(JSON.stringify(newMessage));
            } catch (error) {
                res.writeHead(500);
                res.end(JSON.stringify({ error: 'Internal Server Error' }));
            }
        });
        return;
    }
    
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Not Found' }));
});

initYDB().then(() => {
    server.listen(PORT, () => {
        console.log(`Server running on port ${PORT}`);
        console.log(`Backend version: ${BACKEND_VERSION}`);
        console.log(`Instance ID: ${INSTANCE_ID}`);
    });
});
