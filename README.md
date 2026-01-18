# Гостевая книга на Yandex Cloud

Serverless приложение "Гостевая книга" на базе Yandex Cloud.

## Архитектура

- **Frontend**: Статические файлы (HTML, CSS, JS) в Object Storage
- **Backend**: Serverless Container с Node.js для API
- **Database**: YDB Serverless для хранения сообщений
- **Function**: Cloud Function для endpoint /api/ping-fn
- **API Gateway**: Единая точка входа (HTTPS) для всех запросов

## Структура проекта

```
.
├── frontend/           # Статические файлы фронтенда
│   ├── index.html     # Главная страница (показывает FRONT_VERSION)
│   ├── style.css      # Стили
│   └── app.js         # JavaScript приложение
├── backend/           # Backend на Node.js
│   ├── Dockerfile     # Докер-образ для Serverless Container
│   ├── package.json   # Зависимости
│   └── server.js      # API сервер (показывает BACKEND_VERSION + instanceId)
├── function/          # Cloud Function
│   ├── index.js       # Handler функции
│   └── package.json   # Зависимости
├── scripts/           # Скрипты для развертывания
│   ├── ydb-init.sh    # Инициализация схемы YDB (bash)
│   ├── ydb-init.ps1   # Инициализация схемы YDB (PowerShell)
│   ├── update-container.sh    # Обновление контейнера (bash)
│   ├── update-container.ps1   # Обновление контейнера (PowerShell)
│   ├── update-function.sh     # Обновление функции (bash)
│   └── update-function.ps1    # Обновление функции (PowerShell)
└── api-gateway.yaml   # Спецификация API Gateway
```

## API Endpoints

- `GET /` - Главная страница (из Object Storage)
- `GET /api/info` - Информация о backend (версия, instanceId)
- `GET /api/messages` - Получить список сообщений
- `POST /api/messages` - Добавить новое сообщение
- `GET /api/ping-fn` - Cloud Function endpoint

## Предварительные требования

1. Установленный [Yandex Cloud CLI](https://cloud.yandex.ru/docs/cli/quickstart)
2. Настроенный профиль CLI: `yc init`
3. Docker для сборки образов контейнеров
4. Созданные ресурсы:
   - YDB Serverless база данных
   - Object Storage bucket
   - Container Registry
   - Service Account с необходимыми ролями

## Настройка

### 1. Создание Service Account

```bash
# Создать сервисный аккаунт
yc iam service-account create --name guestbook-sa

# Получить ID сервисного аккаунта
SA_ID=$(yc iam service-account get guestbook-sa --format json | jq -r .id)

# Назначить роли
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role serverless.containers.invoker \
  --subject serviceAccount:$SA_ID

yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role serverless.functions.invoker \
  --subject serviceAccount:$SA_ID

yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role ydb.editor \
  --subject serviceAccount:$SA_ID

yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role storage.viewer \
  --subject serviceAccount:$SA_ID
```

### 2. Создание YDB базы данных

```bash
# Создать Serverless YDB
yc ydb database create --name guestbook-db --serverless

# Получить параметры подключения
yc ydb database get guestbook-db
```

### 3. Инициализация схемы YDB

```bash
# Установить переменные окружения
export YDB_ENDPOINT="grpcs://ydb.serverless.yandexcloud.net:2135"
export YDB_DATABASE="/ru-central1/b1g***********/etn***********"

# Запустить скрипт инициализации
cd scripts
chmod +x ydb-init.sh
./ydb-init.sh
```

Или в PowerShell:

```powershell
$env:YDB_ENDPOINT="grpcs://ydb.serverless.yandexcloud.net:2135"
$env:YDB_DATABASE="/ru-central1/b1g***********/etn***********"

cd scripts
.\ydb-init.ps1
```

### 4. Создание Object Storage bucket

```bash
# Создать bucket
yc storage bucket create --name guestbook-frontend

# Загрузить статические файлы
cd ../frontend
yc storage s3api put-object --bucket guestbook-frontend --key index.html --body index.html
yc storage s3api put-object --bucket guestbook-frontend --key style.css --body style.css
yc storage s3api put-object --bucket guestbook-frontend --key app.js --body app.js
```

### 5. Создание Container Registry

```bash
# Создать registry
yc container registry create --name guestbook-registry

# Получить ID registry
REGISTRY_ID=$(yc container registry get guestbook-registry --format json | jq -r .id)

# Настроить Docker для работы с registry
yc container registry configure-docker
```

### 6. Создание и развертывание Serverless Container

```bash
# Создать контейнер
yc serverless container create --name guestbook-backend

# Установить переменные окружения
export REGISTRY_ID="crp***********"
export SERVICE_ACCOUNT_ID="aje***********"
export YDB_ENDPOINT="grpcs://ydb.serverless.yandexcloud.net:2135"
export YDB_DATABASE="/ru-central1/b1g***********/etn***********"

# Запустить скрипт обновления
cd scripts
chmod +x update-container.sh
./update-container.sh
```

Или в PowerShell:

```powershell
$env:REGISTRY_ID="crp***********"
$env:SERVICE_ACCOUNT_ID="aje***********"
$env:YDB_ENDPOINT="grpcs://ydb.serverless.yandexcloud.net:2135"
$env:YDB_DATABASE="/ru-central1/b1g***********/etn***********"

cd scripts
.\update-container.ps1
```

### 7. Создание и развертывание Cloud Function

```bash
# Создать функцию
yc serverless function create --name ping-function

# Установить переменные окружения
export SERVICE_ACCOUNT_ID="aje***********"

# Запустить скрипт обновления
chmod +x update-function.sh
./update-function.sh
```

Или в PowerShell:

```powershell
$env:SERVICE_ACCOUNT_ID="aje***********"

.\update-function.ps1
```

### 8. Создание API Gateway

```bash
# Получить IDs ресурсов
CONTAINER_ID=$(yc serverless container get guestbook-backend --format json | jq -r .id)
FUNCTION_ID=$(yc serverless function get ping-function --format json | jq -r .id)

# Заменить плейсхолдеры в api-gateway.yaml
sed -i "s/\${BUCKET_NAME}/guestbook-frontend/g" ../api-gateway.yaml
sed -i "s/\${CONTAINER_ID}/$CONTAINER_ID/g" ../api-gateway.yaml
sed -i "s/\${FUNCTION_ID}/$FUNCTION_ID/g" ../api-gateway.yaml
sed -i "s/\${SERVICE_ACCOUNT_ID}/$SERVICE_ACCOUNT_ID/g" ../api-gateway.yaml

# Создать API Gateway
yc serverless api-gateway create \
  --name guestbook-gateway \
  --spec ../api-gateway.yaml

# Получить URL
yc serverless api-gateway get guestbook-gateway
```

## Обновление приложения

### Обновление контейнера

```bash
cd scripts
./update-container.sh
```

### Обновление функции

```bash
cd scripts
./update-function.sh
```

## Функциональность

### Frontend
- Отображает FRONT_VERSION (v1.0.0)
- Показывает BACKEND_VERSION и instanceId от backend
- Форма для отправки сообщений (имя + текст)
- Список всех сообщений с автообновлением каждые 10 секунд
- Адаптивный дизайн

### Backend
- Endpoint `/api/info` - возвращает версию и instanceId
- Endpoint `/api/messages` GET - список сообщений из YDB
- Endpoint `/api/messages` POST - добавление сообщения в YDB
- Каждый запрос может попадать на разные инстансы контейнера

### Cloud Function
- Endpoint `/api/ping-fn` - возвращает pong с версией и метаданными

## Проверка работы

1. Откройте URL API Gateway в браузере
2. Проверьте отображение версий фронтенда и бэкенда
3. Добавьте несколько сообщений через форму
4. Проверьте endpoint `/api/ping-fn`
5. Обновите страницу несколько раз и наблюдайте изменение instanceId

## Лицензия

MIT