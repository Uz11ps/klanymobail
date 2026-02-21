# Supabase

## Быстрый старт

1) Создайте проект в Supabase.
2) Откройте SQL Editor и выполните `schema.sql`.
3) Скопируйте `.env.example` → заполните:
   - `apps/klany_mobile/.env`
   - `apps/klany_admin/.env`

## Роли

- `profiles.role`: `parent` | `admin`
- Ребёнок хранится в `children` и тоже является `auth.users`

## Ребёнок: беспарольный доступ

Ребёнок не использует email/пароль.

1) Ребёнок отправляет заявку: `Фамилия + Имя + Family ID`
2) Родитель подтверждает/отклоняет заявку
3) После подтверждения устройство привязывается к ребёнку (`child_device_bindings`)

Для анонимного child-flow используются RPC:
- `child_submit_access_request`
- `child_poll_access_request`
- `child_restore_session`

## Подписки, промокоды, платежи

Таблицы:
- `subscription_plans`
- `family_subscriptions`
- `promo_codes`
- `promo_redemptions`
- `payment_orders`
- `payment_webhook_events`

Основные RPC:
- `parent_activate_promo`
- `parent_create_payment_order`
- `family_active_plan_code`

## Квесты, кошелёк, магазин

Дополнительно:
- `quest_assignees` — множественные исполнители квеста
- `quest_comments` — комментарии по квесту
- `audit_logs` — журнал действий

RPC:
- `parent_create_quest`
- `child_submit_quest`
- `parent_review_quest_submission`
- `parent_adjust_wallet`
- `child_request_purchase`
- `parent_decide_purchase`

## Уведомления

- In-app: таблица `notifications`, статусы `new/read`
- Push устройства: `notification_devices`
- Планировщик: функция `notifications-cron` (деплоится как Edge Function)

Рекомендуемые Storage buckets:
- `quest-evidence`
- `shop-products`

