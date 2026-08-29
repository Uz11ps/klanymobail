import type { PrismaService } from "../prisma/prisma.service";

export const DEFAULT_GLOBAL_TAX_RATE = 0.2;
export const MAX_GLOBAL_TAX_RATE = 0.5;

export function clampGlobalTaxRate(raw: number): number {
  const n = Number(raw);
  if (!Number.isFinite(n)) return DEFAULT_GLOBAL_TAX_RATE;
  return Math.min(MAX_GLOBAL_TAX_RATE, Math.max(0, n));
}

/** gross=100, tax=0.5 → net=50 монет ребёнку. */
export function applyGlobalTaxToQuestReward(grossReward: number, taxRate: number): number {
  const gross = Math.max(0, Math.trunc(Number(grossReward) || 0));
  const rate = clampGlobalTaxRate(taxRate);
  return Math.max(0, Math.trunc(gross * (1 - rate)));
}

export async function getFamilyGlobalTaxRate(
  prisma: PrismaService,
  familyId: string,
): Promise<number> {
  const row = await prisma.auditLog.findFirst({
    where: { familyId, action: "family_global_tax_set" },
    orderBy: { createdAt: "desc" },
  });
  const payload = (row?.payload ?? null) as { taxRate?: number } | null;
  return clampGlobalTaxRate(Number(payload?.taxRate ?? DEFAULT_GLOBAL_TAX_RATE));
}
