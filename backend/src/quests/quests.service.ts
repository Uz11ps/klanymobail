import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";

import { NotificationsService } from "../notifications/notifications.service";
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
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  private static readonly META_PREFIX = "__QUEST_META__:";

  private async ensureWallet(childId: string, familyId: string) {
    const existing = await this.prisma.wallet.findUnique({ where: { childId } });
    if (existing) return existing;
    return this.prisma.wallet.create({ data: { childId, familyId, balance: 0 } });
  }

  private parseMeta(description: string | null | undefined) {
    const raw = (description ?? "").trim();
    const idx = raw.lastIndexOf(QuestsService.META_PREFIX);
    if (idx < 0) {
      return {
        plainDescription: raw || null,
        distributionType: "assigned",
        autoApprove: false,
        timeLimitMinutes: null as number | null,
        scheduleType: "none",
        scheduleDays: [] as string[],
        activateAtIso: null as string | null,
      };
    }
    const plain = raw.slice(0, idx).trim() || null;
    const payload = raw.slice(idx + QuestsService.META_PREFIX.length).trim();
    try {
      const meta = JSON.parse(payload) as {
        distributionType?: string;
        autoApprove?: boolean;
        timeLimitMinutes?: number | null;
        scheduleType?: string;
        scheduleDays?: string[];
      };
      return {
        plainDescription: plain,
        distributionType: meta.distributionType === "exchange" ? "exchange" : "assigned",
        autoApprove: meta.autoApprove === true,
        timeLimitMinutes:
          meta.timeLimitMinutes != null
            ? Math.max(1, Math.trunc(Number(meta.timeLimitMinutes)))
            : null,
        scheduleType:
          meta.scheduleType === "daily" ||
          meta.scheduleType === "weekly" ||
          meta.scheduleType === "custom_days"
            ? meta.scheduleType
            : "none",
        scheduleDays: Array.isArray(meta.scheduleDays)
          ? meta.scheduleDays.map((d) => String(d)).filter(Boolean)
          : [],
        activateAtIso:
          typeof (meta as { activateAtIso?: unknown }).activateAtIso === "string"
            ? ((meta as { activateAtIso?: string }).activateAtIso ?? null)
            : null,
      };
    } catch {
      return {
        plainDescription: raw,
        distributionType: "assigned",
        autoApprove: false,
        timeLimitMinutes: null as number | null,
        scheduleType: "none",
        scheduleDays: [] as string[],
        activateAtIso: null as string | null,
      };
    }
  }

  private buildDescription(
    description: string | null | undefined,
    meta: {
      distributionType: "assigned" | "exchange";
      autoApprove: boolean;
      timeLimitMinutes: number | null;
      scheduleType: "none" | "daily" | "weekly" | "custom_days";
      scheduleDays: string[];
      activateAtIso?: string | null;
    },
  ) {
    const plain = (description ?? "").trim();
    const payload = JSON.stringify(meta);
    const prefix = plain ? `${plain}\n` : "";
    return `${prefix}${QuestsService.META_PREFIX}${payload}`;
  }

  private computeNextRecurringDate(
    baseDate: Date,
    scheduleType: "none" | "daily" | "weekly" | "custom_days",
    scheduleDays: string[],
  ): Date {
    const next = new Date(baseDate);
    if (scheduleType === "daily") {
      next.setDate(next.getDate() + 1);
      return next;
    }
    if (scheduleType === "weekly") {
      next.setDate(next.getDate() + 7);
      return next;
    }
    if (scheduleType === "custom_days" && scheduleDays.length > 0) {
      const map: Record<string, number> = {
        sun: 0,
        mon: 1,
        tue: 2,
        wed: 3,
        thu: 4,
        fri: 5,
        sat: 6,
      };
      const allowed = new Set<number>(
        scheduleDays.map((d) => map[d.toLowerCase()] ?? -1).filter((n) => n >= 0),
      );
      for (let i = 1; i <= 7; i += 1) {
        const candidate = new Date(baseDate);
        candidate.setDate(baseDate.getDate() + i);
        if (allowed.has(candidate.getDay())) {
          return candidate;
        }
      }
    }
    next.setDate(next.getDate() + 1);
    return next;
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
    childIds?: string[];
    distributionType?: "assigned" | "exchange";
    autoApprove?: boolean;
    timeLimitMinutes?: number | null;
    scheduleType?: "none" | "daily" | "weekly" | "custom_days";
    scheduleDays?: string[] | null;
  }) {
    const familyId = ensureFamilyId(user);
    const title = (input.title ?? "").trim();
    if (!title) throw new BadRequestException("title обязателен");
    const rewardAmount = Math.max(0, Math.trunc(Number(input.rewardAmount ?? 0)));
    const questType = (input.questType ?? "one_time").trim() || "one_time";
    const dueAt = input.dueAt ? new Date(input.dueAt) : null;

    const distributionType = input.distributionType === "exchange" ? "exchange" : "assigned";
    const autoApprove = input.autoApprove === true;
    const timeLimitMinutes =
      input.timeLimitMinutes != null
        ? Math.max(1, Math.trunc(Number(input.timeLimitMinutes)))
        : null;
    const scheduleType =
      input.scheduleType === "daily" ||
      input.scheduleType === "weekly" ||
      input.scheduleType === "custom_days"
        ? input.scheduleType
        : "none";
    const scheduleDays = (input.scheduleDays ?? []).map((x) => x.trim()).filter(Boolean);
    const childIds = (input.childIds ?? []).map((x) => x.trim()).filter(Boolean);
    if (distributionType === "assigned" && childIds.length === 0) {
      throw new BadRequestException("childIds обязателен для адресного квеста");
    }

    const activeSub = await this.prisma.familySubscription.findFirst({
      where: { familyId, status: "active" },
      orderBy: { startedAt: "desc" },
    });
    const isBasic = (activeSub?.planCode ?? "basic").toLowerCase() === "basic";
    if (isBasic) {
      if (childIds.length > 1) {
        throw new BadRequestException("На базовом тарифе квест назначается только одному ребенку");
      }
      const allowedTypes = new Set(["one_time", "recurring", "unique"]);
      if (!allowedTypes.has(questType)) {
        throw new BadRequestException("На базовом тарифе доступны только простые квесты");
      }
    }

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
          description: this.buildDescription((input.description ?? "").trim() || null, {
            distributionType,
            autoApprove,
            timeLimitMinutes,
            scheduleType,
            scheduleDays,
          }),
          reward: rewardAmount,
          questType,
          status: "active",
          dueAt,
        },
      });

      if (distributionType === "assigned") {
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
      }

      return q;
    });

    return { ok: true, questId: quest.id };
  }

  async updateQuest(
    user: ParentUser,
    questIdRaw: string,
    input: {
      title?: string;
      description?: string | null;
      rewardAmount?: number;
      status?: string;
      questType?: string;
      dueAt?: string | null;
      childIds?: string[];
      distributionType?: "assigned" | "exchange";
      autoApprove?: boolean;
      timeLimitMinutes?: number | null;
      scheduleType?: "none" | "daily" | "weekly" | "custom_days";
      scheduleDays?: string[] | null;
    },
  ) {
    const familyId = ensureFamilyId(user);
    const questId = (questIdRaw ?? "").trim();
    if (!questId) throw new BadRequestException("questId обязателен");
    const quest = await this.prisma.quest.findUnique({ where: { id: questId } });
    if (!quest || quest.familyId !== familyId) throw new NotFoundException("Квест не найден");
    const meta = this.parseMeta(quest.description);

    const next: Record<string, unknown> = {};
    const currentReward = quest.reward;
    if (typeof input.title === "string") {
      const title = input.title.trim();
      if (!title) throw new BadRequestException("title обязателен");
      next.title = title;
    }
    if (input.description !== undefined) {
      const plain = (input.description ?? "").trim() || null;
      next.description = this.buildDescription(plain, {
        distributionType: meta.distributionType === "exchange" ? "exchange" : "assigned",
        autoApprove: meta.autoApprove,
        timeLimitMinutes: meta.timeLimitMinutes,
        scheduleType: meta.scheduleType as "none" | "daily" | "weekly" | "custom_days",
        scheduleDays: meta.scheduleDays,
        activateAtIso: meta.activateAtIso,
      });
    }
    if (input.rewardAmount !== undefined) {
      const reward = Math.max(0, Math.trunc(Number(input.rewardAmount)));
      next.reward = reward;
    }
    if (typeof input.status === "string") {
      const status = input.status.trim();
      if (status) next.status = status;
      if (status === "closed") next.closedAt = new Date();
    }
    if (typeof input.questType === "string") {
      const questType = input.questType.trim();
      if (questType) next.questType = questType;
    }
    if (input.dueAt !== undefined) {
      next.dueAt = input.dueAt ? new Date(input.dueAt) : null;
    }

    const distributionType =
      input.distributionType !== undefined
        ? (input.distributionType === "exchange" ? "exchange" : "assigned")
        : (meta.distributionType === "exchange" ? "exchange" : "assigned");
    const autoApprove = input.autoApprove !== undefined ? input.autoApprove === true : meta.autoApprove;
    const timeLimitMinutes =
      input.timeLimitMinutes !== undefined
        ? (input.timeLimitMinutes != null
            ? Math.max(1, Math.trunc(Number(input.timeLimitMinutes)))
            : null)
        : meta.timeLimitMinutes;
    const scheduleType =
      input.scheduleType !== undefined
        ? (input.scheduleType === "daily" ||
          input.scheduleType === "weekly" ||
          input.scheduleType === "custom_days"
            ? input.scheduleType
            : "none")
        : (meta.scheduleType as "none" | "daily" | "weekly" | "custom_days");
    const scheduleDays =
      input.scheduleDays !== undefined
        ? (input.scheduleDays ?? []).map((x) => x.trim()).filter(Boolean)
        : meta.scheduleDays;

    const nextDescriptionPlain =
      input.description !== undefined ? ((input.description ?? "").trim() || null) : meta.plainDescription;
    next.description = this.buildDescription(nextDescriptionPlain, {
      distributionType,
      autoApprove,
      timeLimitMinutes,
      scheduleType,
      scheduleDays,
      activateAtIso: meta.activateAtIso,
    });

    const childIds = (input.childIds ?? []).map((x) => x.trim()).filter(Boolean);
    if (distributionType === "assigned") {
      const shouldValidateChildIds = input.childIds !== undefined || input.distributionType !== undefined;
      if (shouldValidateChildIds && childIds.length === 0) {
        throw new BadRequestException("childIds обязателен для адресного квеста");
      }
      if (childIds.length > 0) {
        const children = await this.prisma.child.findMany({ where: { id: { in: childIds } } });
        for (const c of children) {
          if (c.familyId !== familyId) throw new ForbiddenException("Чужой ребёнок");
        }
      }
    }

    const rewardForAssignees = (next.reward as number | undefined) ?? currentReward;
    const shouldReassign =
      input.childIds !== undefined || input.distributionType !== undefined;

    if (Object.keys(next).length === 0 && !shouldReassign) return { ok: true };
    await this.prisma.$transaction(async (tx) => {
      if (shouldReassign) {
        await tx.questAssignee.deleteMany({ where: { questId } });
        if (distributionType === "assigned") {
          for (const childId of childIds) {
            await tx.questAssignee.create({
              data: {
                questId,
                childId,
                status: "assigned",
                rewardAmount: rewardForAssignees,
              },
            });
          }
        }
      } else if (input.rewardAmount !== undefined) {
        await tx.questAssignee.updateMany({
          where: { questId },
          data: { rewardAmount: rewardForAssignees },
        });
      }

      await tx.quest.update({
        where: { id: questId },
        data: next,
      });
    });
    return { ok: true };
  }

  async deleteQuest(user: ParentUser, questIdRaw: string) {
    const familyId = ensureFamilyId(user);
    const questId = (questIdRaw ?? "").trim();
    if (!questId) throw new BadRequestException("questId обязателен");
    const quest = await this.prisma.quest.findUnique({ where: { id: questId } });
    if (!quest || quest.familyId !== familyId) throw new NotFoundException("Квест не найден");

    await this.prisma.$transaction(async (tx) => {
      await tx.questEvidence.deleteMany({ where: { questId } });
      await tx.questComment.deleteMany({ where: { questId } });
      await tx.questAssignee.deleteMany({ where: { questId } });
      await tx.quest.delete({ where: { id: questId } });
    });
    return { ok: true };
  }

  async listParentQuests(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.quest.findMany({
      where: { familyId, status: "active" },
      include: {
        assignees: {
          select: { childId: true },
        },
      },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return {
      items: rows.map((q) => {
        const meta = this.parseMeta(q.description);
        return {
          ...q,
          description: meta.plainDescription,
          distributionType: meta.distributionType,
          autoApprove: meta.autoApprove,
          timeLimitMinutes: meta.timeLimitMinutes,
          scheduleType: meta.scheduleType,
          scheduleDays: meta.scheduleDays,
          childIds: q.assignees.map((a) => a.childId),
        };
      }),
    };
  }

  async listChildAssignments(user: ChildUser) {
    const assignees = await this.prisma.questAssignee.findMany({
      where: {
        childId: user.childId,
        quest: { status: "active" },
        status: { not: "approved" },
      },
      include: { quest: true },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    const marketQuests = await this.prisma.quest.findMany({
      where: {
        familyId: user.familyId,
        status: "active",
        assignees: { none: {} },
      },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return {
      items: [
        ...assignees.map((a) => {
          const meta = this.parseMeta(a.quest.description);
          const activateAt = meta.activateAtIso ? new Date(meta.activateAtIso) : null;
          if (activateAt && activateAt.getTime() > Date.now()) {
            return null;
          }
          const nowMs = Date.now();
          const deadlineMs =
            meta.timeLimitMinutes != null
              ? new Date(a.createdAt).getTime() + meta.timeLimitMinutes * 60_000
              : null;
          const isOverdue =
            deadlineMs != null &&
            nowMs > deadlineMs &&
            (a.status === "assigned" || a.status === "in_progress");
          return {
            questId: a.questId,
            assignmentId: a.id,
            title: a.quest.title,
            status: isOverdue ? "overdue" : a.status,
            rewardAmount: a.rewardAmount,
            comment: a.comment,
            dueAt: a.quest.dueAt,
            createdAt: a.createdAt,
            // У ребёнка строки из QuestAssignee — это уже «мои задачи»; иначе взятый с биржи
            // квест остаётся с distributionType exchange и зависает во вкладке «Биржа».
            distributionType:
              meta.distributionType === "exchange" ? "assigned" : meta.distributionType,
            autoApprove: meta.autoApprove,
            timeLimitMinutes: meta.timeLimitMinutes,
            scheduleType: meta.scheduleType,
            scheduleDays: meta.scheduleDays,
          };
        }).filter(Boolean),
        ...marketQuests.map((q) => {
          const meta = this.parseMeta(q.description);
          if (meta.distributionType !== "exchange") {
            return null;
          }
          const activateAt = meta.activateAtIso ? new Date(meta.activateAtIso) : null;
          if (activateAt && activateAt.getTime() > Date.now()) {
            return null;
          }
          return {
            questId: q.id,
            assignmentId: "",
            title: q.title,
            status: "market",
            rewardAmount: q.reward,
            comment: meta.plainDescription,
            dueAt: q.dueAt,
            createdAt: q.createdAt,
            distributionType: meta.distributionType,
            autoApprove: meta.autoApprove,
            timeLimitMinutes: meta.timeLimitMinutes,
            scheduleType: meta.scheduleType,
            scheduleDays: meta.scheduleDays,
          };
        }).filter(Boolean),
      ],
    };
  }

  async takeFromMarket(user: ChildUser, questIdRaw: string) {
    const questId = (questIdRaw ?? "").trim();
    if (!questId) throw new BadRequestException("questId обязателен");
    const quest = await this.prisma.quest.findUnique({ where: { id: questId } });
    if (!quest) throw new NotFoundException("Квест не найден");
    if (quest.familyId !== user.familyId) throw new ForbiddenException("Чужая семья");
    const meta = this.parseMeta(quest.description);
    if (meta.distributionType !== "exchange") {
      throw new BadRequestException("Этот квест не из биржи");
    }
    const existing = await this.prisma.questAssignee.findUnique({
      where: { questId_childId: { questId, childId: user.childId } },
    });
    if (existing) return { ok: true };
    await this.prisma.questAssignee.create({
      data: {
        questId,
        childId: user.childId,
        status: "in_progress",
        rewardAmount: quest.reward,
      },
    });
    return { ok: true };
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
    const meta = this.parseMeta(assignment.quest.description);

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
        data: { status: meta.autoApprove ? "approved" : "submitted", submittedAt: new Date() },
      });
      if (meta.autoApprove) {
        const wallet = await this.ensureWallet(user.childId, user.familyId);
        await tx.wallet.update({
          where: { id: wallet.id },
          data: { balance: wallet.balance + assignment.rewardAmount },
        });
        await tx.walletTransaction.create({
          data: {
            walletId: wallet.id,
            amount: assignment.rewardAmount,
            txType: "quest_reward",
            note: "Автоподтверждение квеста",
            reason: "quest_reward",
            meta: { questId },
          },
        });
        if (
          assignment.quest.questType === "one_time" ||
          assignment.quest.questType === "unique"
        ) {
          await tx.quest.update({
            where: { id: assignment.questId },
            data: { status: "closed", closedAt: new Date() },
          });
        }
        if (assignment.quest.questType === "recurring") {
          const nextAt = this.computeNextRecurringDate(
            new Date(),
            meta.scheduleType as "none" | "daily" | "weekly" | "custom_days",
            meta.scheduleDays,
          );
          const nextDescription = this.buildDescription(meta.plainDescription, {
            distributionType: meta.distributionType === "exchange" ? "exchange" : "assigned",
            autoApprove: meta.autoApprove,
            timeLimitMinutes: meta.timeLimitMinutes,
            scheduleType: meta.scheduleType as "none" | "daily" | "weekly" | "custom_days",
            scheduleDays: meta.scheduleDays,
            activateAtIso: nextAt.toISOString(),
          });
          const recreated = await tx.quest.create({
            data: {
              familyId: assignment.quest.familyId,
              createdBy: assignment.quest.createdBy,
              title: assignment.quest.title,
              description: nextDescription,
              reward: assignment.quest.reward,
              questType: assignment.quest.questType,
              status: "active",
              dueAt: assignment.quest.dueAt,
            },
          });
          if (meta.distributionType === "assigned") {
            await tx.questAssignee.create({
              data: {
                questId: recreated.id,
                childId: user.childId,
                status: "assigned",
                rewardAmount: assignment.rewardAmount,
              },
            });
          }
          await tx.quest.update({
            where: { id: assignment.questId },
            data: { status: "closed", closedAt: new Date() },
          });
        }
      }
    });

    if (!meta.autoApprove) {
      const child = await this.prisma.child.findUnique({ where: { id: user.childId } });
      const childName = child ? [child.firstName, child.lastName].filter(Boolean).join(" ").trim() : "Ребёнок";
      const parentProfiles = await this.prisma.profile.findMany({
        where: { familyId: user.familyId, role: { in: ["parent", "admin"] } },
        select: { userId: true },
        take: 100,
      });
      const recipients = [...new Set(parentProfiles.map((p) => p.userId).filter(Boolean))];
      if (recipients.length > 0) {
        await this.prisma.notification.createMany({
          data: recipients.map((userId) => ({
            familyId: user.familyId,
            toUserId: userId,
            nType: "quest_submitted",
            payload: { questId, childId: user.childId, questTitle: assignment.quest.title, childName },
          })),
        });
      }
      await this.notifications.notifyFamilyPush(
        user.familyId,
        "Квест выполнен",
        `${childName} выполнил(а) «${assignment.quest.title}»`,
        "quest_submitted",
      );
    }

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
    const meta = this.parseMeta(assignment.quest.description);

    await this.prisma.$transaction(async (tx) => {
      await tx.questAssignee.update({
        where: { id: assignment.id },
        data: { status: approve ? "approved" : "in_progress" },
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
        if (
          assignment.quest.questType === "one_time" ||
          assignment.quest.questType === "unique"
        ) {
          await tx.quest.update({
            where: { id: assignment.questId },
            data: { status: "closed", closedAt: new Date() },
          });
        }
        if (assignment.quest.questType === "recurring") {
          const nextAt = this.computeNextRecurringDate(
            new Date(),
            meta.scheduleType as "none" | "daily" | "weekly" | "custom_days",
            meta.scheduleDays,
          );
          const nextDescription = this.buildDescription(meta.plainDescription, {
            distributionType: meta.distributionType === "exchange" ? "exchange" : "assigned",
            autoApprove: meta.autoApprove,
            timeLimitMinutes: meta.timeLimitMinutes,
            scheduleType: meta.scheduleType as "none" | "daily" | "weekly" | "custom_days",
            scheduleDays: meta.scheduleDays,
            activateAtIso: nextAt.toISOString(),
          });
          const recreated = await tx.quest.create({
            data: {
              familyId: assignment.quest.familyId,
              createdBy: user.userId,
              title: assignment.quest.title,
              description: nextDescription,
              reward: assignment.quest.reward,
              questType: assignment.quest.questType,
              status: "active",
              dueAt: assignment.quest.dueAt,
            },
          });
          if (meta.distributionType === "assigned") {
            await tx.questAssignee.create({
              data: {
                questId: recreated.id,
                childId,
                status: "assigned",
                rewardAmount: assignment.rewardAmount,
              },
            });
          }
          await tx.quest.update({
            where: { id: assignment.questId },
            data: { status: "closed", closedAt: new Date() },
          });
        }
      }
    });

    const questTitle = assignment.quest.title;
    if (approve) {
      await this.notifications.notifyFamilyPush(
        familyId,
        "Квест подтверждён",
        `«${questTitle}» — вам начислена награда!`,
        "quest_approved",
      );
    } else {
      await this.notifications.notifyFamilyPush(
        familyId,
        "Квест отклонён",
        `«${questTitle}» — нужно выполнить ещё раз`,
        "quest_rejected",
      );
    }

    return { ok: true };
  }
}

