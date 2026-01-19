# Архитектура приложения

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Пользователь (Browser)                      │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │ HTTPS
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    API Gateway (HTTPS Default Domain)                │
│  - Единая точка входа                                               │
│  - Роутинг запросов                                                  │
└──────┬────────────────────┬─────────────────────┬────────────────────┘
       │                    │                     │
       │ /                  │ /api/*              │ /api/ping-fn
       │ /style.css         │                     │
       │ /app.js            │                     │
       ▼                    ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│ Object Storage   │  │ Serverless       │  │ Cloud Function       │
│                  │  │ Container        │  │                      │
│ - index.html     │  │                  │  │ - /api/ping-fn       │
│   (FRONT_VERSION)│  │ python + YDB SD  │  │   (ping handler)     │
│ - style.css      │  │                  │  │ - Возвращает pong    │
│ - app.js         │  │ Endpoints:       │  │   с metadata         │
│                  │  │ - /api/info      │  │                      │
│                  │  │   (BACKEND_      │  │ Runtime: python      │
│                  │  │    VERSION +     │  │                      │
│                  │  │    instanceId)   │  │                      │
│                  │  │ - /api/messages  │  │                      │
│                  │  │   GET/POST       │  │                      │
│                  │  │                  │  │                      │
│                  │  │ Масштабируется   │  │                      │
│                  │  │ автоматически    │  │                      │
│                  │  │ (разные          │  │                      │
│                  │  │  инстансы)       │  │                      │
└──────────────────┘  └────────┬─────────┘  └──────────────────────┘
                               │
                               │ YDB SDK
                               ▼
                     ┌──────────────────────┐
                     │ YDB Serverless       │
                     │                      │
                     │ Table: messages      │
                     │ - id (PK)            │
                     │ - author             │
                     │ - message            │
                     │ - timestamp          │
                     └──────────────────────┘
```

## Поток данных

### Загрузка страницы (GET /)
1. Браузер → API Gateway → Object Storage → index.html
2. Браузер загружает style.css и app.js
3. app.js отображает FRONT_VERSION (v1.0.0)
4. app.js делает GET /api/info → API Gateway → Container → ответ с BACKEND_VERSION + instanceId
5. app.js делает GET /api/messages → API Gateway → Container → YDB → список сообщений

### Отправка сообщения (POST /api/messages)
1. Форма → POST /api/messages (JSON: {author, message})
2. API Gateway → Serverless Container (может быть любой инстанс)
3. Container → YDB.insert(id, author, message, timestamp)
4. Ответ с созданным сообщением
5. Frontend обновляет список сообщений

### Ping функции (GET /api/ping-fn)
1. Браузер → GET /api/ping-fn
2. API Gateway → Cloud Function
3. Function возвращает pong с metadata
4. Можно использовать для проверки работоспособности/обновления

## Особенности

- **Статический контент**: Отдается из Object Storage через API Gateway
- **API**: Обрабатывается Serverless Container с автоматическим масштабированием
- **База данных**: YDB Serverless для хранения сообщений
- **Функция**: Отдельный endpoint для дополнительной функциональности
- **Единый домен**: Все запросы идут через API Gateway HTTPS endpoint
- **Разные инстансы**: Каждый запрос может обрабатываться разным инстансом контейнера
