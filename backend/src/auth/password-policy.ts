import { BadRequestException } from "@nestjs/common";

/** Единые правила для паролей (регистрация главы, заявки ребёнка, создание админа). */
export const KLANY_PASSWORD_MIN = 8;
export const KLANY_PASSWORD_MAX = 128;

// Латиница + кириллица (вкл. ё/Ё) + цифры + «безопасная» пунктуация без пробелов и символов, неудобных для JSON/HTML.
const KLANY_PASSWORD_RE = /^[a-zA-Zа-яА-ЯёЁ0-9!@#$%^&*()_+\-=[\]{}|;:,./?]+$/u;

/** Проверяет пароль и возвращает его как есть (без trim), для последующего `bcrypt.hash`. */
export function assertKlanyPasswordPlain(pwRaw: unknown): string {
  const pw = typeof pwRaw === "string" ? pwRaw : "";
  if (pw.length < KLANY_PASSWORD_MIN) {
    throw new BadRequestException(`Пароль: минимум ${KLANY_PASSWORD_MIN} символов`);
  }
  if (pw.length > KLANY_PASSWORD_MAX) {
    throw new BadRequestException(`Пароль не длиннее ${KLANY_PASSWORD_MAX} символов`);
  }
  if (/\s/.test(pw)) {
    throw new BadRequestException("Пароль не должен содержать пробелов");
  }
  if (!KLANY_PASSWORD_RE.test(pw)) {
    throw new BadRequestException(
      "Пароль: только буквы (латиница или кириллица), цифры и символы !@#$%^&*()_+-=[]{}|;:,./?",
    );
  }
  return pw;
}
