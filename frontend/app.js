const FRONT_VERSION = 'v1.0.0';

document.getElementById('front-version').textContent = FRONT_VERSION;

async function loadBackendInfo() {
    try {
        const response = await fetch('/api/info');
        const data = await response.json();
        document.getElementById('backend-info').innerHTML = 
            `Backend: <strong>${data.version}</strong> | Instance: <strong>${data.instanceId}</strong>`;
    } catch (error) {
        console.error('Failed to load backend info:', error);
        document.getElementById('backend-info').innerHTML = 
            'Backend: <strong>Error</strong>';
    }
}

async function loadMessages() {
    try {
        const response = await fetch('/api/messages');
        const data = await response.json();
        const container = document.getElementById('messages-container');
        
        if (data.messages && data.messages.length > 0) {
            container.innerHTML = data.messages.map(msg => `
                <div class="message-item">
                    <div class="message-header">
                        <span class="message-author">${escapeHtml(msg.author)}</span>
                        <span class="message-date">${new Date(msg.timestamp).toLocaleString('ru-RU')}</span>
                    </div>
                    <div class="message-text">${escapeHtml(msg.message)}</div>
                </div>
            `).join('');
        } else {
            container.innerHTML = '<p class="loading">Пока нет сообщений. Будьте первым!</p>';
        }
    } catch (error) {
        console.error('Failed to load messages:', error);
        document.getElementById('messages-container').innerHTML = 
            '<div class="error">Ошибка загрузки сообщений</div>';
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

document.getElementById('message-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const author = document.getElementById('author').value;
    const message = document.getElementById('message').value;
    
    try {
        const response = await fetch('/api/messages', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ author, message }),
        });
        
        if (response.ok) {
            document.getElementById('author').value = '';
            document.getElementById('message').value = '';
            await loadMessages();
        } else {
            alert('Ошибка при отправке сообщения');
        }
    } catch (error) {
        console.error('Failed to post message:', error);
        alert('Ошибка при отправке сообщения');
    }
});

loadBackendInfo();
loadMessages();

setInterval(loadMessages, 10000);
