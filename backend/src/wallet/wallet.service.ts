import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";

import { PrismaService } from "../prisma/prisma.service";
import { getFamilyGoal, getFamilySavingsTotal } from "../family/family-goal.util";

type ParentUser = {
  userId: string;
  role: "parent" | "admin";
  familyId?: string | null;
};

type ChildUser = {
  role: "child";
  familyId: string;
  childId: string;
  sessionToken: string;
};

function ensureFamilyId(user: { familyId?: string | null }): string {
  const familyId = user.familyId ?? null;
  if (!familyId) throw new ForbiddenException("Нет семьи");
  return familyId;
}

@Injectable()
export class WalletService {
  constructor(private readonly prisma: PrismaService) {}

  /** Mirrors parent goal resolution so child dashboard progress matches семейная цель. */
  private async getFamilyGoalForWallet(familyId: string) {
    return getFamilyGoal(this.prisma, familyId);
  }

  private async ensureWallet(childId: string, familyId: string) {
    const existing = await this.prisma.wallet.findUnique({ where: { childId } });
    if (existing) return existing;
    return this.prisma.wallet.create({ data: { childId, familyId, balance: 0 } });
  }

  async getChildWallet(user: ChildUser) {
    const wallet = await this.ensureWallet(user.childId, user.familyId);
    const [goal, familySavingsTotal] = await Promise.all([
      this.getFamilyGoalForWallet(user.familyId),
      getFamilySavingsTotal(this.prisma, user.familyId),
    ]);
    const completedQuestsCount = await this.prisma.questAssignee.count({
      where: { childId: user.childId, status: "approved" },
    });
    const shopPendingAgg = await this.prisma.shopPurchase.aggregate({
      where: { childId: user.childId, status: "requested" },
      _sum: { frozenAmount: true },
    });
    const shopFrozenAmount = Math.trunc(Number(shopPendingAgg._sum.frozenAmount ?? 0));
    return {
      walletId: wallet.id,
      balance: wallet.balance,
      goalAmount: goal.goalAmount,
      goalName: goal.goalName,
      familySavingsTotal,
      completedQuestsCount,
      shopFrozenAmount,
    };
  }

  async getChildTransactions(user: ChildUser) {
    const wallet = await this.ensureWallet(user.childId, user.familyId);
    const rows = await this.prisma.walletTransaction.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return { walletId: wallet.id, items: rows };
  }

  async getFamilyWallets(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const children = await this.prisma.child.findMany({
      where: { familyId, isActive: true },
      orderBy: { createdAt: "asc" },
    });

    const result = [];
    for (const child of children) {
      const wallet = await this.ensureWallet(child.id, familyId);
      const displayName = [child.firstName, child.lastName].filter(Boolean).join(" ").trim();
      result.push({
        childId: child.id,
        displayName,
        balance: wallet.balance,
        avatarObjectKey: child.avatarObjectKey ?? null,
      });
    }
    return { items: result };
  }

  async adjust(user: ParentUser, input: { childId: string; amount: number; note?: string }) {
    const familyId = ensureFamilyId(user);
    const childId = (input.childId ?? "").trim();
    if (!childId) throw new BadRequestException("childId обязателен");

    const amount = Number(input.amount ?? 0);
    if (!Number.isFinite(amount) || amount === 0) throw new BadRequestException("amount должен быть != 0");

    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child || child.familyId !== familyId) throw new NotFoundException("Ребёнок не найден");

    const note = (input.note ?? "").trim() || "Корректировка";

    const wallet = await this.ensureWallet(childId, familyId);
    const nextBalance = wallet.balance + Math.trunc(amount);
    if (nextBalance < 0) throw new BadRequestException("Недостаточно средств");

    await this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: nextBalance },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: Math.trunc(amount),
          txType: "adjustment",
          note,
          reason: "parent_adjust",
          meta: { actorUserId: user.userId },
        },
      });
    });

    return { ok: true, balance: nextBalance };
  }
}

