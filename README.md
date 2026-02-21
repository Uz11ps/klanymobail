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

## Edge Functions (Supabase)

Деплой:
```bash
supabase functions deploy yookassa-create-payment
supabase functions deploy yookassa-webhook
supabase functions deploy telegram-bot-webhook
supabase functions deploy notifications-cron
```

