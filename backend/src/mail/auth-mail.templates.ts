import { appPublicBaseUrl } from "./auth-email-token.util";

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function layout(title: string, bodyHtml: string): string {
  return `<!DOCTYPE html>
<html lang="ru">
<head><meta charset="utf-8"><title>${title}</title></head>
<body style="font-family:Arial,sans-serif;line-height:1.5;color:#1e2d52;background:#f4f8fc;padding:24px">
  <div style="max-width:520px;margin:0 auto;background:#fff;border-radius:16px;padding:28px">
    <h1 style="margin:0 0 16px;font-size:20px">${title}</h1>
    ${bodyHtml}
    <p style="margin-top:24px;font-size:12px;color:#5b6b85">Clan Capital</p>
  </div>
</body>
</html>`;
}

export function passwordResetEmailHtml(code: string): { subject: string; html: string } {
  const safe = escapeHtml(code);
  return {
    subject: "Код для сброса пароля — Clan Capital",
    html: layout(
      "Восстановление пароля",
      `<p>Вы запросили сброс пароля. Введите код в приложении Clan Capital:</p>
       <p style="font-size:32px;font-weight:800;letter-spacing:8px;text-align:center;margin:24px 0;color:#1e2d52">${safe}</p>
       <p style="font-size:13px;color:#5b6b85">Код действует 15 минут. Никому его не сообщайте.</p>
       <p style="font-size:13px;color:#5b6b85">Если вы не запрашивали сброс — просто проигнорируйте письмо.</p>`,
    ),
  };
}

export function emailVerificationHtml(plainToken: string): { subject: string; html: string } {
  const link = `${appPublicBaseUrl()}/api/auth/verify-email?token=${encodeURIComponent(plainToken)}`;
  return {
    subject: "Подтвердите email — Clan Capital",
    html: layout(
      "Подтверждение почты",
      `<p>Спасибо за регистрацию. Подтвердите email, чтобы завершить настройку аккаунта.</p>
       <p><a href="${link}" style="display:inline-block;padding:12px 20px;background:#2b88ff;color:#fff;text-decoration:none;border-radius:999px;font-weight:700">Подтвердить email</a></p>
       <p style="font-size:13px;color:#5b6b85">Ссылка действует 48 часов.</p>
       <p style="font-size:13px;color:#5b6b85">Или откройте вручную:<br><span style="word-break:break-all">${link}</span></p>`,
    ),
  };
}

export function verifyEmailSuccessPageHtml(): string {
  return layout(
    "Email подтверждён",
    `<p style="font-size:16px">Готово. Можно закрыть эту страницу и войти в приложение Clan Capital.</p>`,
  );
}

export function verifyEmailErrorPageHtml(message = "Ссылка недействительна или устарела."): string {
  return layout(
    "Не удалось подтвердить",
    `<p style="font-size:16px">${message}</p>
     <p style="font-size:13px;color:#5b6b85">Запросите новое письмо при входе или зарегистрируйтесь снова.</p>`,
  );
}
