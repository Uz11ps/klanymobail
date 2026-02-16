# Klany (Flutter + Supabase)

## Структура

- `apps/klany_mobile` — мобильное приложение (iOS/Android)
- `apps/klany_admin` — веб-админка (Flutter Web)
- `supabase/` — схема БД + заметки по backend

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

