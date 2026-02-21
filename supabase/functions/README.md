# Edge Functions

## Переменные окружения

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `YOOKASSA_SHOP_ID`
- `YOOKASSA_SECRET_KEY`
- `YOOKASSA_RETURN_URL`
- `TELEGRAM_BOT_TOKEN`
- `APP_BASE_URL`

## Функции

- `yookassa-create-payment` — создаёт платёж в YooKassa по `payment_orders.id`
- `yookassa-webhook` — обрабатывает webhook оплаты и активирует подписку
- `telegram-bot-webhook` — обработчик команд Telegram (`/start`, `/promo`)
- `notifications-cron` — планировщик уведомлений по подписке/событиям

## Настройка Telegram webhook

После деплоя:
`https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook?url=<APP_BASE_URL>/functions/v1/telegram-bot-webhook`

Команды бота:
- `/start`
- `/link FAMILY-ID`
- `/promo CODE`

