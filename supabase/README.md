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

## Ребёнок: телефон + пароль

Supabase не поддерживает вход по "phone+password" как отдельный провайдер.
В MVP мы делаем детский логин через детерминированный псевдо-email:

`<digits-only-phone>@kids.klany.local`

Клиент принимает телефон+пароль, конвертирует телефон в псевдо-email и использует стандартный `signInWithPassword`.

