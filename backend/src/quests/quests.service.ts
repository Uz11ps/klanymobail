import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";

import { PrismaService } from "../prisma/prisma.service";

type ParentUser = {
  userId: string;
  role: "parent" | "admin";
  familyId?: string | null;
};

type ChildUser = {
  role: "child";
  familyId: string;
  childId: string;
};

function ensureFamilyId(user: { familyId?: string | null }): string {
  const familyId = user.familyId ?? null;
  if (!familyId) throw new ForbiddenException("Нет семьи");
  return familyId;
}

@Injectable()
export class QuestsService {
  constructor(private readonly prisma: PrismaService) {}

  private async ensureWallet(childId: string, familyId: string) {
    const existing = await this.prisma.wallet.findUnique({ where: { childId } });
    if (existing) return existing;
    return this.prisma.wallet.create({ data: { childId, familyId, balance: 0 } });
  }

  async listFamilyChildren(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.child.findMany({
      where: { familyId, isActive: true },
      orderBy: { createdAt: "asc" },
    });
    return {
      items: rows.map((c) => ({
        id: c.id,
        displayName: [c.firstName, c.lastName].filter(Boolean).join(" ").trim(),
      })),
    };
  }

  async createQuest(user: ParentUser, input: {
    title: string;
    description?: string;
    rewardAmount: number;
    questType: string;
    dueAt?: string | null;
    childIds: string[];
  }) {
    const familyId = ensureFamilyId(user);
    const title = (input.title ?? "").trim();
    if (!title) throw new BadRequestException("title обязателен");
    const rewardAmount = Math.max(0, Math.trunc(Number(input.rewardAmount ?? 0)));
    const questType = (input.questType ?? "one_time").trim() || "one_time";
    const dueAt = input.dueAt ? new Date(input.dueAt) : null;

    const childIds = (input.childIds ?? []).map((x) => x.trim()).filter(Boolean);
    if (childIds.length === 0) throw new BadRequestException("childIds обязателен");

    // Ensure children belong to family.
    const children = await this.prisma.child.findMany({ where: { id: { in: childIds } } });
    for (const c of children) {
      if (c.familyId !== familyId) throw new ForbiddenException("Чужой ребёнок");
    }

    const quest = await this.prisma.$transaction(async (tx) => {
      const q = await tx.quest.create({
        data: {
          familyId,
          createdBy: user.userId,
          title,
          description: (input.description ?? "").trim() || null,
          reward: rewardAmount,
          questType,
          status: "active",
          dueAt,
        },
      });

      for (const childId of childIds) {
        await tx.questAssignee.create({
          data: {
            questId: q.id,
            childId,
            status: "assigned",
            rewardAmount,
          },
        });
      }

      return q;
    });

    return { ok: true, questId: quest.id };
  }

  async listParentQuests(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.quest.findMany({
      where: { familyId },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return { items: rows };
  }

  async listChildAssignments(user: ChildUser) {
    const rows = await this.prisma.questAssignee.findMany({
      where: { childId: user.childId },
      include: { quest: true },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return {
      items: rows.map((a) => ({
        questId: a.questId,
        assignmentId: a.id,
        title: a.quest.title,
        status: a.status,
        rewardAmount: a.rewardAmount,
        comment: a.comment,
        dueAt: a.quest.dueAt,
      })),
    };
  }

  async submit(user: ChildUser, questIdRaw: string, evidenceKey: string | null) {
    const questId = (questIdRaw ?? "").trim();
    if (!questId) throw new BadRequestException("questId обязателен");

    const assignment = await this.prisma.questAssignee.findUnique({
      where: { questId_childId: { questId, childId: user.childId } },
      include: { quest: true },
    });
    if (!assignment) throw new NotFoundException("Назначение не найдено");
    if (assignment.quest.familyId !== user.familyId) throw new ForbiddenException("Чужая семья");

    await this.prisma.$transaction(async (tx) => {
      if (evidenceKey) {
        await tx.questEvidence.create({
          data: {
            questId,
            childId: user.childId,
            objectKey: evidenceKey,
          },
        });
      }
      await tx.questAssignee.update({
        where: { id: assignment.id },
        data: { status: "submitted", submittedAt: new Date() },
      });
    });

    return { ok: true };
  }

  async listSubmittedForReview(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.questAssignee.findMany({
      where: { status: "submitted", quest: { familyId } },
      include: {
        quest: true,
        child: true,
      },
      orderBy: { submittedAt: "desc" },
      take: 200,
    });

    const result = [];
    for (const row of rows) {
      const evidence = await this.prisma.questEvidence.findFirst({
        where: { questId: row.questId, childId: row.childId },
        orderBy: { createdAt: "desc" },
      });
      result.push({
        questId: row.questId,
        childId: row.childId,
        childName: [row.child.firstName, row.child.lastName].filter(Boolean).join(" ").trim(),
        title: row.quest.title,
        submittedAt: row.submittedAt,
        evidenceKey: evidence?.objectKey ?? null,
      });
    }
    return { items: result };
  }

  async review(user: ParentUser, input: { questId: string; childId: string; approve: boolean; comment?: string | null }) {
    const familyId = ensureFamilyId(user);
    const questId = (input.questId ?? "").trim();
    const childId = (input.childId ?? "").trim();
    if (!questId || !childId) throw new BadRequestException("questId/childId обязательны");

    const assignment = await this.prisma.questAssignee.findUnique({
      where: { questId_childId: { questId, childId } },
      include: { quest: true },
    });
    if (!assignment) throw new NotFoundException("Назначение не найдено");
    if (assignment.quest.familyId !== familyId) throw new ForbiddenException("Чужая семья");
    if (assignment.status !== "submitted") throw new BadRequestException("Не на проверке");

    const approve = input.approve === true;
    const comment = (input.comment ?? "").trim() || null;

    await this.prisma.$transaction(async (tx) => {
      await tx.questAssignee.update({
        where: { id: assignment.id },
        data: { status: approve ? "approved" : "rejected" },
      });

      if (comment) {
        await tx.questComment.create({
          data: {
            questId,
            authorUserId: user.userId,
            message: comment,
          },
        });
      }

      if (approve) {
        const wallet = await this.ensureWallet(childId, familyId);
        await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance: wallet.balance + assignment.rewardAmount },
        });
        await tx.walletTransaction.create({
          data: {
            walletId: wallet.id,
            amount: assignment.rewardAmount,
            txType: "quest_reward",
            note: `Награда за квест`,
            reason: "quest_reward",
            meta: { questId },
          },
        });
      }
    });

    return { ok: true };
  }
}

