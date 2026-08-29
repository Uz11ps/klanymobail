# Clan Capital — checkout site

Статический фронт для продажи Premium-подписок через ЮKassa.
Пользователь оплачивает на сайте → получает промо-код → вводит код
в мобильном приложении.

## Структура

```
clan_capital_site/
├── index.html        — лендинг + 3 тарифа + email-модалка
├── success.html      — страница после редиректа от ЮKassa, показ кода
└── assets/
    ├── styles.css    — единый стиль (Nunito, бренд-цвета приложения)
    └── pay.js        — обращение к API, redirect на ЮKassa
```

Никаких зависимостей. Можно деплоить на любой статический хостинг
(Vercel / Netlify / nginx / S3).

## Локальная разработка

```bash
cd apps/clan_capital_site
python3 -m http.server 8000
# открыть http://localhost:8000
```

По умолчанию JS обращается к `https://klanymobail.ru/api`. Чтобы
переопределить базовый URL, добавьте перед `<script src="assets/pay.js">`:

```html
<script>window.API_BASE = 'https://staging.klanymobail.ru/api';</script>
```

## Контракт с бэкендом

Сайт ожидает три эндпоинта на основном API:

### `POST /api/payments/create`

Создаёт платёж в ЮKassa и возвращает ссылку на оплату.

Request:
```json
{
  "planCode": "premium_1m" | "premium_6m" | "premium_12m",
  "amount": 499,
  "returnUrl": "https://site.example/success.html"
}
```

Response:
```json
{
  "paymentId": "2c8a8b7b-000f-5000-9000-aaa",
  "confirmationUrl": "https://yoomoney.ru/checkout/payments/v2/contract?..."
}
```

Бэкенд:
1. Вызывает ЮKassa `POST /v3/payments` (idempotency key = uuid)
2. Сохраняет в БД `payments(id, planCode, amount, status='pending')`
3. Возвращает `confirmation.confirmation_url` и `id`

### `GET /api/payments/:id`

Возвращает текущий статус платежа и (при `succeeded`) промо-код.

Response:
```json
{
  "status": "pending" | "succeeded" | "canceled" | "failed",
  "promoCode": "PREM-XXXX-XXXX"
}
```

### `POST /api/payments/webhook`

Принимает webhook от ЮKassa (`payment.succeeded` / `payment.canceled`).
По `payment.succeeded`:
1. Помечает `payments.status = 'succeeded'`
2. Генерирует промо-код (16 символов, формат `PREM-XXXX-XXXX`), связывает с `planCode` и `durationDays`
3. Сохраняет в `promo_codes(code, planCode, durationDays, status='unused', expiresAt = now + 30d, createdFromPayment)`

### `POST /api/promo/redeem` (используется приложением)

Активирует подписку для семьи по коду.

Request:
```json
{ "code": "PREM-XXXX-XXXX" }
```

Headers: `Authorization: Bearer <parent_token>`

Response: `{ "ok": true, "expiresAt": "2026-..." }`

Логика:
1. Найти `promo_codes` по коду, status='unused' и not expired
2. Найти `family` по `parentId` из токена
3. Создать/продлить `family_subscriptions(planCode='premium', expiresAt += durationDays)`
4. Пометить `promo_codes.status='used', usedBy, usedAt=now`

## Связь с мобильным приложением

После показа кода на `success.html` есть кнопка «Открыть приложение» с
deep-link `clancapital://activate?code=PREM-XXXX-XXXX`. Чтобы её
обработать в приложении, нужно зарегистрировать схему:

- iOS: `ios/Runner/Info.plist` → `CFBundleURLTypes` со схемой `clancapital`
- Android: `android/app/src/main/AndroidManifest.xml` → `<intent-filter>` с
  `<data android:scheme="clancapital" android:host="activate" />`

В коде Flutter использовать пакет `app_links` или `uni_links` для подписки
на входящие ссылки и автоподстановки кода в поле активации.

## Тарифы

Текущие цены в `index.html` (поменять — `data-amount` на кнопках):

| План          | Сумма (₽) | Длительность |
|---------------|-----------|--------------|
| premium_1m    | 499       | 30 дней      |
| premium_6m    | 2 490     | 180 дней     |
| premium_12m   | 4 490     | 365 дней     |

Соответствие planCode → durationDays задаётся на бэке.
