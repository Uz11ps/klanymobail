import { Prisma } from "@prisma/client";

export const DEFAULT_PREMIUM_PLAN_CODE = "premium";

export async function ensureSubscriptionPlans(tx: Prisma.TransactionClient) {
  await tx.subscriptionPlan.upsert({
    where: { code: "basic" },
    create: { code: "basic", title: "Базовый", priceRub: 0, isActive: true },
    update: {},
  });
  await tx.subscriptionPlan.upsert({
    where: { code: DEFAULT_PREMIUM_PLAN_CODE },
    create: {
      code: DEFAULT_PREMIUM_PLAN_CODE,
      title: "Премиум",
      priceRub: 0,
      isActive: true,
    },
    update: {},
  });
}

/** Premium без срока — для новых семей и бэкфилла. */
export async function grantDefaultPremiumSubscription(
  tx: Prisma.TransactionClient,
  familyId: string,
) {
  await ensureSubscriptionPlans(tx);

  const existingPremium = await tx.familySubscription.findFirst({
    where: {
      familyId,
      status: "active",
      planCode: DEFAULT_PREMIUM_PLAN_CODE,
    },
  });
  if (existingPremium) return existingPremium;

  return tx.familySubscription.create({
    data: {
      familyId,
      planCode: DEFAULT_PREMIUM_PLAN_CODE,
      status: "active",
      expiresAt: null,
      source: "registration",
    },
  });
}
