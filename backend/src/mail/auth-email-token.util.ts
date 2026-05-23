import { createHash, randomBytes } from "crypto";

export function generateAuthEmailPlainToken(): string {
  return randomBytes(32).toString("hex");
}

export function hashAuthEmailToken(plain: string): string {
  return createHash("sha256").update(plain.trim()).digest("hex");
}

export function isDeliverableUserEmail(email: string): boolean {
  const e = email.trim().toLowerCase();
  if (!e.includes("@")) return false;
  if (e.endsWith("@phone.klany.local")) return false;
  if (e.endsWith("@member.klany.local")) return false;
  return true;
}

export function appPublicBaseUrl(): string {
  return (process.env.APP_PUBLIC_BASE_URL ?? "http://127.0.0.1:8782").replace(/\/+$/, "");
}
