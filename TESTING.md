# Тестирование приложения

После развертывания приложения выполните следующие тесты для проверки работоспособности.

## Предварительная проверка

Получите URL вашего API Gateway:

```bash
yc serverless api-gateway get guestbook-gateway --format json | jq -r .domain
```

Или используйте URL из файла `.env.local` после выполнения `quick-deploy.sh`.

## Тест 1: Главная страница

### Проверка
```bash
curl -I https://<gateway-domain>/
```

### Ожидаемый результат
- HTTP Status: 200
- Content-Type: text/html

### В браузере
Откройте `https://<gateway-domain>/` и проверьте:
- ✓ Страница загружается
- ✓ Видна версия фронтенда (v1.0.0)
- ✓ Видна версия бэкенда и instanceId
- ✓ Форма для ввода сообщения отображается
- ✓ Стили применены корректно

## Тест 2: API - Backend Info

### Проверка
```bash
curl https://<gateway-domain>/api/info
```

### Ожидаемый результат
```json
{
  "version": "v1.0.0",
  "instanceId": "...",
  "ready": true
}
```

### Проверка разных инстансов
Выполните запрос несколько раз:
```bash
for i in {1..5}; do
  curl -s https://<gateway-domain>/api/info | jq .instanceId
done
```

Вы можете увидеть разные `instanceId`, что подтверждает масштабирование.

## Тест 3: API - Получение сообщений

### Проверка (пустая база)
```bash
curl https://<gateway-domain>/api/messages
```

### Ожидаемый результат
```json
{
  "messages": []
}
```

## Тест 4: API - Отправка сообщения

### Проверка
```bash
curl -X POST https://<gateway-domain>/api/messages \
  -H "Content-Type: application/json" \
  -d '{"author":"Тестер","message":"Привет из curl!"}'
```

### Ожидаемый результат
```json
{
  "id": "...",
  "author": "Тестер",
  "message": "Привет из curl!",
  "timestamp": "2026-01-18T..."
}
```

### Проверка сохранения
```bash
curl https://<gateway-domain>/api/messages
```

Должно вернуть массив с одним сообщением.

## Тест 5: Cloud Function - Ping

### Проверка
```bash
curl https://<gateway-domain>/api/ping-fn
```

### Ожидаемый результат
```json
{
  "message": "pong",
  "timestamp": "2026-01-18T...",
  "functionVersion": "v1.0.0",
  "instanceId": "...",
  "requestId": "..."
}
```

## Тест 6: Полный сценарий в браузере

1. Откройте приложение в браузере
2. Заполните форму:
   - Имя: "Иван"
   - Сообщение: "Тестовое сообщение"
3. Нажмите "Отправить"
4. Проверьте, что:
   - ✓ Форма очистилась
   - ✓ Новое сообщение появилось в списке
   - ✓ Отображается имя автора
   - ✓ Отображается время создания
5. Добавьте еще 2-3 сообщения
6. Проверьте, что все сообщения отображаются в обратном хронологическом порядке

## Тест 7: Автообновление

1. Откройте приложение в двух вкладках браузера
2. В первой вкладке добавьте сообщение
3. Подождите до 10 секунд
4. Проверьте, что:
   - ✓ Новое сообщение появилось во второй вкладке автоматически

## Тест 8: Статические ресурсы

### Проверка CSS
```bash
curl -I https://<gateway-domain>/style.css
```
Ожидается: HTTP 200, Content-Type: text/css

### Проверка JS
```bash
curl -I https://<gateway-domain>/app.js
```
Ожидается: HTTP 200, Content-Type: application/javascript

## Тест 9: Нагрузка (опционально)

### Отправка множества сообщений
```bash
for i in {1..10}; do
  curl -X POST https://<gateway-domain>/api/messages \
    -H "Content-Type: application/json" \
    -d "{\"author\":\"User$i\",\"message\":\"Message $i\"}"
  echo " - Message $i sent"
done
```

### Проверка
```bash
curl https://<gateway-domain>/api/messages | jq '.messages | length'
```

Должно вернуть количество сообщений (как минимум 10).

## Тест 10: Проверка разных инстансов контейнера

```bash
# Запустить параллельные запросы
for i in {1..20}; do
  curl -s https://<gateway-domain>/api/info &
done | jq -r .instanceId | sort | uniq -c
```

Вы должны увидеть запросы, распределенные по разным инстансам.

## Мониторинг через Yandex Cloud Console

1. Откройте [Yandex Cloud Console](https://console.cloud.yandex.ru/)
2. Перейдите в раздел "Serverless Container"
3. Выберите "guestbook-backend"
4. Проверьте:
   - Метрики запросов
   - Логи выполнения
   - Количество активных инстансов
5. Перейдите в "Cloud Functions"
6. Выберите "ping-function"
7. Проверьте логи и метрики

## Тест обработки ошибок

### Отправка невалидных данных
```bash
curl -X POST https://<gateway-domain>/api/messages \
  -H "Content-Type: application/json" \
  -d '{"author":"Test"}'
```

Ожидается: HTTP 400 с сообщением об ошибке

```bash
curl -X POST https://<gateway-domain>/api/messages \
  -H "Content-Type: application/json" \
  -d 'invalid json'
```

Ожидается: HTTP 500 с сообщением об ошибке

## Чеклист успешного развертывания

- [ ] Главная страница загружается (HTTP 200)
- [ ] Отображается FRONT_VERSION (v1.0.0)
- [ ] Отображается BACKEND_VERSION (v1.0.0) и instanceId
- [ ] GET /api/info возвращает корректные данные
- [ ] GET /api/messages возвращает массив сообщений
- [ ] POST /api/messages успешно добавляет сообщение
- [ ] GET /api/ping-fn возвращает pong
- [ ] Форма в UI работает корректно
- [ ] Сообщения отображаются в списке
- [ ] Автообновление работает (каждые 10 секунд)
- [ ] Запросы распределяются по разным инстансам
- [ ] Статические файлы (CSS, JS) загружаются корректно

## Очистка тестовых данных

Если нужно очистить тестовые сообщения из базы данных:

```bash
export YDB_ENDPOINT="<your-endpoint>"
export YDB_DATABASE="<your-database>"

ydb -e "$YDB_ENDPOINT" -d "$YDB_DATABASE" yql -s "DELETE FROM messages;"
```

Или через YDB Console в веб-интерфейсе Yandex Cloud.
