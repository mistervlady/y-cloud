# Быстрое развертывание гостевой книги

Этот гайд поможет быстро развернуть приложение в Yandex Cloud.

## Шаг 1: Подготовка

1. Установите [Yandex Cloud CLI](https://cloud.yandex.ru/docs/cli/quickstart)
2. Инициализируйте CLI:
   ```bash
   yc init
   ```
3. Установите Docker
4. Установите jq (для обработки JSON в скриптах)

## Шаг 2: Создание инфраструктуры

### Создание сервисного аккаунта

```bash
# Создать service account
yc iam service-account create --name guestbook-sa

# Сохранить ID
export SA_ID=$(yc iam service-account get guestbook-sa --format json | jq -r .id)
export FOLDER_ID=$(yc config get folder-id)

# Назначить роли
yc resource-manager folder add-access-binding $FOLDER_ID \
  --role serverless.containers.invoker --subject serviceAccount:$SA_ID

yc resource-manager folder add-access-binding $FOLDER_ID \
  --role serverless.functions.invoker --subject serviceAccount:$SA_ID

yc resource-manager folder add-access-binding $FOLDER_ID \
  --role ydb.editor --subject serviceAccount:$SA_ID

yc resource-manager folder add-access-binding $FOLDER_ID \
  --role storage.viewer --subject serviceAccount:$SA_ID

yc resource-manager folder add-access-binding $FOLDER_ID \
  --role container-registry.images.pusher --subject serviceAccount:$SA_ID
```

### Создание YDB

```bash
# Создать базу данных
yc ydb database create guestbook-db \
  --serverless \
  --folder-id $FOLDER_ID

# Получить параметры подключения
yc ydb database get guestbook-db --format json
```

Сохраните значения `endpoint` и `document_api_endpoint` - это будут `YDB_ENDPOINT` и `YDB_DATABASE`.

### Создание Container Registry

```bash
# Создать registry
yc container registry create --name guestbook-registry

# Сохранить ID
export REGISTRY_ID=$(yc container registry get guestbook-registry --format json | jq -r .id)

# Настроить Docker
yc container registry configure-docker
```

### Создание Object Storage bucket

```bash
# Создать bucket (имя должно быть уникальным)
yc storage bucket create --name guestbook-frontend-$(date +%s)

# Сохранить имя bucket
export BUCKET_NAME=guestbook-frontend-$(date +%s)
```

## Шаг 3: Развертывание приложения

### Инициализация базы данных

```bash
# Установить переменные
export YDB_ENDPOINT="<значение endpoint из YDB>"
export YDB_DATABASE="<значение database из YDB>"

# Запустить скрипт
cd scripts
./ydb-init.sh
```

### Загрузка фронтенда в Object Storage

```bash
cd ../frontend

# Загрузить файлы
yc storage s3api put-object --bucket $BUCKET_NAME --key index.html --body index.html
yc storage s3api put-object --bucket $BUCKET_NAME --key style.css --body style.css --content-type text/css
yc storage s3api put-object --bucket $BUCKET_NAME --key app.js --body app.js --content-type application/javascript
```

### Развертывание Serverless Container

```bash
# Создать контейнер
yc serverless container create --name guestbook-backend

# Установить переменные
export SERVICE_ACCOUNT_ID=$SA_ID
export CONTAINER_NAME=guestbook-backend

# Собрать и развернуть
cd ../scripts
./update-container.sh

# Сохранить ID контейнера
export CONTAINER_ID=$(yc serverless container get guestbook-backend --format json | jq -r .id)
```

### Развертывание Cloud Function

```bash
# Создать функцию
yc serverless function create --name ping-function

# Развернуть
./update-function.sh

# Сохранить ID функции
export FUNCTION_ID=$(yc serverless function get ping-function --format json | jq -r .id)
```

### Создание API Gateway

```bash
# Подготовить спецификацию
cd ..
cp api-gateway.yaml api-gateway-deploy.yaml

# Заменить переменные
sed -i "s/\${BUCKET_NAME}/$BUCKET_NAME/g" api-gateway-deploy.yaml
sed -i "s/\${CONTAINER_ID}/$CONTAINER_ID/g" api-gateway-deploy.yaml
sed -i "s/\${FUNCTION_ID}/$FUNCTION_ID/g" api-gateway-deploy.yaml
sed -i "s/\${SERVICE_ACCOUNT_ID}/$SA_ID/g" api-gateway-deploy.yaml

# Создать API Gateway
yc serverless api-gateway create \
  --name guestbook-gateway \
  --spec api-gateway-deploy.yaml

# Получить URL
yc serverless api-gateway get guestbook-gateway
```

## Шаг 4: Проверка

Откройте в браузере URL из вывода последней команды (поле `domain`). Вы должны увидеть:

1. Главную страницу с формой
2. Версию фронтенда (v1.0.0)
3. Версию бэкенда и instanceId
4. Возможность добавлять и просматривать сообщения

Проверьте также endpoint функции:
```
https://<domain>/api/ping-fn
```

## Обновление версий

### Обновить frontend

1. Измените `FRONT_VERSION` в `frontend/app.js`
2. Загрузите файлы заново:
   ```bash
   cd frontend
   yc storage s3api put-object --bucket $BUCKET_NAME --key app.js --body app.js --content-type application/javascript
   ```

### Обновить backend

1. Измените `BACKEND_VERSION` в `backend/server.js`
2. Запустите скрипт:
   ```bash
   cd scripts
   ./update-container.sh
   ```

### Обновить функцию

1. Измените код в `function/index.js`
2. Запустите скрипт:
   ```bash
   cd scripts
   ./update-function.sh
   ```

## Удаление ресурсов

```bash
# Удалить API Gateway
yc serverless api-gateway delete guestbook-gateway

# Удалить контейнер
yc serverless container delete guestbook-backend

# Удалить функцию
yc serverless function delete ping-function

# Очистить и удалить bucket
yc storage bucket delete --name $BUCKET_NAME

# Удалить YDB
yc ydb database delete guestbook-db

# Удалить registry
yc container registry delete guestbook-registry

# Удалить service account
yc iam service-account delete guestbook-sa
```
