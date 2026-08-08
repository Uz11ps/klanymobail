import { randomInt } from "crypto";

/** Единый формат кодов входа ребёнка / участника семьи. */
export const CHILD_AUTH_CODE_LENGTH = 8;

export function generateChildAuthCode(): string {
  return randomInt(0, 100_000_000).toString().padStart(CHILD_AUTH_CODE_LENGTH, "0");
}

export function normalizeChildAuthCode(raw: string): string {
  return (raw ?? "").trim();
}

/**
 * Для входа: 6 цифр из старой записи → 8 с ведущими нулями (946231 → 00946231).
 * После миграции БД код хранится в 8-значном виде.
 */
export function resolveChildAuthCodeForLookup(raw: string): string {
  const trimmed = normalizeChildAuthCode(raw);
  if (/^\d{6}$/.test(trimmed)) {
    return trimmed.padStart(CHILD_AUTH_CODE_LENGTH, "0");
  }
  return trimmed;
}

/** Принимаем 8 цифр; 6 — только если пользователь вводит старый код до миграции UI. */
export function isValidChildAuthCodeFormat(code: string): boolean {
  const trimmed = normalizeChildAuthCode(code);
  return /^\d{8}$/.test(trimmed) || /^\d{6}$/.test(trimmed);
}

export function childAuthCodeFormatError(): string {
  return `Код должен состоять из ${CHILD_AUTH_CODE_LENGTH} цифр`;
}
