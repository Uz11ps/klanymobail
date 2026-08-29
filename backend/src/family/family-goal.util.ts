import type { PrismaService } from "../prisma/prisma.service";

export type FamilyGoalPayload = {
  goalAmount?: number;
  goalName?: string;
};

export type FamilyGoal = {
  goalAmount: number;
  goalName: string | null;
};

const DEFAULT_GOAL_AMOUNT = 10000;

export async function getFamilyGoal(
  prisma: PrismaService,
  familyId: string,
): Promise<FamilyGoal> {
  const row = await prisma.auditLog.findFirst({
    where: { familyId, action: "family_goal_set" },
    orderBy: { createdAt: "desc" },
  });
  const payload = (row?.payload ?? null) as FamilyGoalPayload | null;
  const parsed = Math.trunc(Number(payload?.goalAmount ?? 0));
  const goalAmount = parsed > 0 ? parsed : DEFAULT_GOAL_AMOUNT;
  const rawName = (payload?.goalName ?? "").trim();
  return { goalAmount, goalName: rawName || null };
}

export async function getFamilySavingsTotal(
  prisma: PrismaService,
  familyId: string,
): Promise<number> {
  const agg = await prisma.wallet.aggregate({
    where: { familyId },
    _sum: { balance: true },
  });
  return Math.trunc(Number(agg._sum.balance ?? 0));
}
