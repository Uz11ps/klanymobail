# Klany (Flutter + Supabase)

## Структура

- `apps/klany_mobile` — мобильное приложение (iOS/Android)
- `apps/klany_admin` — веб-админка (Flutter Web)
- `supabase/` — схема БД + заметки по backend

## Текущий auth-flow детей

- Ребёнок не вводит пароль/email
- Вводит: `Фамилия + Имя + Family ID`
- Родитель подтверждает заявку в разделе `Запросы на вход`
- После подтверждения устройство ребёнка привязывается к профилю

## Настройка Supabase

1) Создайте проект в Supabase.
2) Выполните `supabase/schema.sql` в SQL Editor.
3) Заполните `.env`:
   - `apps/klany_mobile/.env`
   - `apps/klany_admin/.env`

Шаблон ключей: `.env.example`.

## Запуск

Мобилка:
```bash
cd apps/klany_mobile
flutter run
```

Админка (web):
```bash
cd apps/klany_admin
flutter run -d chrome
```

## Flutter Web + свой API (типовые ошибки)

1. **CORS** — приложение на `http://localhost:*`, API на другом домене: подними backend из этого репозитория; по умолчанию Nest отражает `Origin` запроса. Для жёсткого прод-режима задай `CORS_ORIGIN_ALLOWLIST=https://твой-домен.ru`.
2. **Presigned URL с хостом `minio:9000`** — на сервере обязательно задай `MINIO_PUBLIC_BASE_URL` на публичный URL того же nginx, где проксируются bucket-пути (`infra/nginx/default.conf`: `/shop-products`, …). Иначе подпись считается для внутреннего имени Docker и браузер не откроет файл. После правок CORS пересобери образ nginx (`docker compose build nginx && docker compose up -d nginx`) и при необходимости перезапусти MinIO с `MINIO_API_CORS_ALLOW_ORIGIN=*` (в `docker-compose.yml` уже по умолчанию).
3. **401** — протух или не передан JWT; войди заново.
4. **403 на части методов** — проверь роли и бизнес-правила в конкретном endpoint.

## Edge Functions (Supabase)

Деплой:
```bash
supabase functions deploy yookassa-create-payment
supabase functions deploy yookassa-webhook
supabase functions deploy telegram-bot-webhook
supabase functions deploy notifications-cron
```

