import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import * as bcrypt from "bcrypt";
import { randomUUID } from "crypto";

import { PrismaService } from "../prisma/prisma.service";

type ParentUser = {
  userId: string;
  role: "parent" | "admin";
  familyId?: string | null;
};

type FamilyMemberType = "mom" | "child" | "grandma" | "grandpa";

function ensureFamilyId(user: ParentUser): string {
  const familyId = user.familyId ?? null;
  if (!familyId) throw new ForbiddenException("Нет семьи");
  return familyId;
}

function generateChildAuthCode(): string {
  return Math.floor(Math.random() * 1000000).toString().padStart(6, "0");
}

@Injectable()
export class ParentService {
  constructor(private readonly prisma: PrismaService) {}

  private parseFamilyMemberType(input: { memberType?: string; role?: string }): FamilyMemberType {
    const memberType = (input.memberType ?? input.role ?? "").trim().toLowerCase();
    if (
      memberType !== "mom" &&
      memberType !== "child" &&
      memberType !== "grandma" &&
      memberType !== "grandpa"
    ) {
      throw new BadRequestException("memberType должен быть mom/child/grandma/grandpa");
    }
    return memberType;
  }

  private async generateUniqueFamilyAccessCode(): Promise<string> {
    for (let i = 0; i < 30; i += 1) {
      const code = generateChildAuthCode();
      const [memberCode, child] = await Promise.all([
        this.prisma.familyMemberCode.findUnique({ where: { code } }),
        this.prisma.child.findFirst({ where: { authCode: code } }),
      ]);
      if (!memberCode && !child) return code;
    }
    throw new BadRequestException("Не удалось сгенерировать уникальный код");
  }

  private async getFamilyGoalAmount(familyId: string): Promise<number> {
    const row = await this.prisma.auditLog.findFirst({
      where: { familyId, action: "family_goal_set" },
      orderBy: { createdAt: "desc" },
    });
    const payload = (row?.payload ?? null) as { goalAmount?: number } | null;
    const parsed = Math.trunc(Number(payload?.goalAmount ?? 0));
    return parsed > 0 ? parsed : 10000;
  }

  private async getFamilyRublesPer10Coins(familyId: string): Promise<number> {
    const row = await this.prisma.auditLog.findFirst({
      where: { familyId, action: "family_coin_rate_set" },
      orderBy: { createdAt: "desc" },
    });
    const payload = (row?.payload ?? null) as { rublesPer10Coins?: number } | null;
    const parsed = Math.trunc(Number(payload?.rublesPer10Coins ?? 0));
    return parsed > 0 ? parsed : 100;
  }

  async getFamilyContext(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const family = await this.prisma.family.findUnique({ where: { id: familyId } });
    if (!family) throw new NotFoundException("Семья не найдена");
    const [goalAmount, rublesPer10Coins] = await Promise.all([
      this.getFamilyGoalAmount(family.id),
      this.getFamilyRublesPer10Coins(family.id),
    ]);
    return {
      familyId: family.id,
      familyCode: family.familyCode,
      clanName: family.clanName,
      goalAmount,
      rublesPer10Coins,
    };
  }

  async setFamilyGoal(user: ParentUser, goalAmountRaw: number) {
    const familyId = ensureFamilyId(user);
    const goalAmount = Math.trunc(Number(goalAmountRaw ?? 0));
    if (!Number.isFinite(goalAmount) || goalAmount <= 0) {
      throw new BadRequestException("goalAmount должен быть > 0");
    }
    await this.prisma.auditLog.create({
      data: {
        familyId,
        actorUserId: user.userId,
        action: "family_goal_set",
        payload: { goalAmount },
      },
    });
    return { ok: true, goalAmount };
  }

  async setFamilyCoinRate(user: ParentUser, rublesPer10CoinsRaw: number) {
    const familyId = ensureFamilyId(user);
    const rublesPer10Coins = Math.trunc(Number(rublesPer10CoinsRaw ?? 0));
    if (!Number.isFinite(rublesPer10Coins) || rublesPer10Coins <= 0) {
      throw new BadRequestException("rublesPer10Coins должен быть > 0");
    }
    await this.prisma.auditLog.create({
      data: {
        familyId,
        actorUserId: user.userId,
        action: "family_coin_rate_set",
        payload: { rublesPer10Coins },
      },
    });
    return { ok: true, rublesPer10Coins };
  }

  /** Имя в UI семьи (поле профиля `displayName`). */
  async updateMyProfile(user: ParentUser, body: { displayName?: string }) {
    const displayName = (body.displayName ?? "").trim();
    if (!displayName) throw new BadRequestException("Укажите имя");

    const updated = await this.prisma.profile.updateMany({
      where: {
        userId: user.userId,
        role: { in: ["parent", "admin"] },
      },
      data: { displayName },
    });
    if (updated.count === 0) throw new NotFoundException("Профиль не найден");
    return { ok: true as const, displayName };
  }

  /** Аватар текущего родителя/админа (`profiles.avatarObjectKey`). */
  async setMyAvatar(user: ParentUser, objectKeyRaw: string) {
    const familyId = ensureFamilyId(user);
    const key = (objectKeyRaw ?? "").trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    const prefix = `avatars/families/${familyId}/profiles/${user.userId}/`;
    if (!key.startsWith(prefix)) {
      throw new BadRequestException("Некорректный objectKey");
    }
    const updated = await this.prisma.profile.updateMany({
      where: {
        userId: user.userId,
        familyId,
        role: { in: ["parent", "admin"] },
      },
      data: { avatarObjectKey: key },
    });
    if (updated.count === 0) throw new NotFoundException("Профиль не найден");
    return { ok: true as const, avatarObjectKey: key };
  }

  async listParentMembers(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.profile.findMany({
      where: { familyId, role: { in: ["parent", "admin"] } },
      orderBy: { createdAt: "asc" },
    });
    return {
      items: rows.map((p) => ({
        userId: p.userId,
        displayName: p.displayName ?? "Без имени",
        role: p.role,
        avatarObjectKey: p.avatarObjectKey ?? null,
      })),
    };
  }

  async listChildren(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.child.findMany({
      where: { familyId },
      orderBy: { createdAt: "asc" },
    });
    return {
      items: rows.map((c) => ({
        childId: c.id,
        firstName: c.firstName,
        lastName: c.lastName,
        displayName: [c.firstName, c.lastName].filter(Boolean).join(" ").trim(),
        isActive: c.isActive,
        avatarObjectKey: c.avatarObjectKey ?? null,
      })),
    };
  }

  async listFamilyMemberCodes(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.familyMemberCode.findMany({
      where: { familyId },
      orderBy: { createdAt: "desc" },
    });
    const childIds = rows.map((r) => r.childId).filter(Boolean) as string[];
    const userIds = rows.map((r) => r.userId).filter(Boolean) as string[];
    const [children, profiles] = await Promise.all([
      this.prisma.child.findMany({
        where: { id: { in: childIds } },
        select: { id: true, avatarObjectKey: true },
      }),
      this.prisma.profile.findMany({
        where: { userId: { in: userIds } },
        select: { userId: true, avatarObjectKey: true },
      }),
    ]);
    const childMap = new Map(children.map((c) => [c.id, c.avatarObjectKey ?? null]));
    const profileMap = new Map(profiles.map((p) => [p.userId, p.avatarObjectKey ?? null]));

    return {
      items: rows.map((row) => ({
        id: row.id,
        role: row.role,
        code: row.code,
        displayName: row.displayName,
        isActive: row.isActive,
        createdAt: row.createdAt,
        avatarObjectKey: row.childId
          ? childMap.get(row.childId) ?? null
          : row.userId
            ? profileMap.get(row.userId) ?? null
            : null,
      })),
    };
  }

  async setMemberCodeAvatar(user: ParentUser, codeIdRaw: string, objectKeyRaw: string) {
    const row = await this.getFamilyMemberCodeOrThrow(user, codeIdRaw);
    const key = (objectKeyRaw ?? "").trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    const expectedPrefix = `avatars/families/${row.familyId}/members/${row.id}/`;
    if (!key.startsWith(expectedPrefix)) {
      throw new BadRequestException("Некорректный objectKey");
    }
    if (row.childId) {
      await this.prisma.child.update({
        where: { id: row.childId },
        data: { avatarObjectKey: key },
      });
    } else if (row.userId) {
      await this.prisma.profile.update({
        where: { userId: row.userId },
        data: { avatarObjectKey: key },
      });
    } else {
      throw new BadRequestException("Код участника не привязан к профилю");
    }
    return { ok: true, avatarObjectKey: key };
  }

  private async avatarObjectKeyForMemberCode(mc: {
    childId: string | null;
    userId: string | null;
  }): Promise<string | null> {
    if (mc.childId) {
      const c = await this.prisma.child.findUnique({
        where: { id: mc.childId },
        select: { avatarObjectKey: true },
      });
      return c?.avatarObjectKey ?? null;
    }
    if (mc.userId) {
      const p = await this.prisma.profile.findUnique({
        where: { userId: mc.userId },
        select: { avatarObjectKey: true },
      });
      return p?.avatarObjectKey ?? null;
    }
    return null;
  }

  private async getFamilyMemberCodeOrThrow(user: ParentUser, idRaw: string) {
    const familyId = ensureFamilyId(user);
    const id = (idRaw ?? "").trim();
    if (!id) throw new BadRequestException("id обязателен");
    const row = await this.prisma.familyMemberCode.findUnique({ where: { id } });
    if (!row || row.familyId !== familyId) throw new NotFoundException("Код не найден");
    return row;
  }

  async createFamilyMemberCode(
    user: ParentUser,
    input: { memberType?: string; role?: string; displayName: string },
  ) {
    const familyId = ensureFamilyId(user);
    const memberType = this.parseFamilyMemberType(input);
    const displayName = (input.displayName ?? "").trim();
    if (!displayName) throw new BadRequestException("displayName обязателен");

    const code = await this.generateUniqueFamilyAccessCode();
    const isChild = memberType === "child";

    const result = await this.prisma.$transaction(async (tx) => {
      if (isChild) {
        const child = await tx.child.create({
          data: {
            familyId,
            firstName: displayName,
            lastName: null,
            authCode: code,
            isActive: true,
          },
        });
        await tx.wallet.create({
          data: { familyId, childId: child.id, balance: 0 },
        });
        const memberCode = await tx.familyMemberCode.create({
          data: {
            familyId,
            role: memberType,
            code,
            displayName,
            childId: child.id,
          },
        });
        return { memberCode };
      }

      const pseudoEmail = `${familyId}.${code}@member.klany.local`;
      const passwordHash = await bcrypt.hash(randomUUID(), 10);
      const newUser = await tx.user.create({
        data: {
          email: pseudoEmail,
          passwordHash,
        },
      });
      await tx.profile.create({
        data: {
          userId: newUser.id,
          familyId,
          role: "parent",
          displayName,
        },
      });
      const memberCode = await tx.familyMemberCode.create({
        data: {
          familyId,
          role: memberType,
          code,
          displayName,
          userId: newUser.id,
        },
      });
      return { memberCode };
    });

    const avatarObjectKey = await this.avatarObjectKeyForMemberCode({
      childId: result.memberCode.childId,
      userId: result.memberCode.userId,
    });

    return {
      id: result.memberCode.id,
      role: result.memberCode.role,
      code: result.memberCode.code,
      displayName: result.memberCode.displayName,
      isActive: result.memberCode.isActive,
      createdAt: result.memberCode.createdAt,
      avatarObjectKey,
    };
  }

  async regenerateFamilyMemberCode(user: ParentUser, idRaw: string) {
    const row = await this.getFamilyMemberCodeOrThrow(user, idRaw);
    const nextCode = await this.generateUniqueFamilyAccessCode();
    const updated = await this.prisma.$transaction(async (tx) => {
      const nextRow = await tx.familyMemberCode.update({
        where: { id: row.id },
        data: {
          code: nextCode,
        },
      });
      if (row.childId) {
        await tx.child.update({
          where: { id: row.childId },
          data: { authCode: nextCode },
        });
      }
      return nextRow;
    });
    const avatarObjectKey = await this.avatarObjectKeyForMemberCode({
      childId: updated.childId,
      userId: updated.userId,
    });
    return {
      id: updated.id,
      role: updated.role,
      code: updated.code,
      displayName: updated.displayName,
      isActive: updated.isActive,
      createdAt: updated.createdAt,
      avatarObjectKey,
    };
  }

  async deactivateFamilyMemberCode(user: ParentUser, idRaw: string) {
    const row = await this.getFamilyMemberCodeOrThrow(user, idRaw);
    await this.prisma.$transaction(async (tx) => {
      if (row.childId) {
        await tx.child.update({
          where: { id: row.childId },
          data: { authCode: null },
        });
      }
      await tx.familyMemberCode.delete({ where: { id: row.id } });
    });
    return { ok: true };
  }

  async deleteFamilyMemberCode(user: ParentUser, idRaw: string) {
    const row = await this.getFamilyMemberCodeOrThrow(user, idRaw);
    await this.prisma.$transaction(async (tx) => {
      if (row.childId) {
        await tx.child.update({
          where: { id: row.childId },
          data: { authCode: null },
        });
      }
      await tx.familyMemberCode.delete({ where: { id: row.id } });
    });
    return { ok: true };
  }

  async getChildProfile(user: ParentUser, childIdRaw: string) {
    const familyId = ensureFamilyId(user);
    const childId = (childIdRaw ?? "").trim();
    if (!childId) throw new BadRequestException("childId обязателен");

    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child || child.familyId !== familyId) throw new NotFoundException("Ребёнок не найден");

    const wallet = await this.prisma.wallet.findUnique({ where: { childId } });
    const assignments = await this.prisma.questAssignee.findMany({
      where: { childId },
      select: { status: true, submittedAt: true },
      take: 500,
    });

    const stats = {
      assigned: assignments.filter((x) => x.status === "assigned").length,
      inProgress: assignments.filter((x) => x.status === "in_progress").length,
      onReview: assignments.filter((x) => x.status === "submitted").length,
      approved: assignments.filter((x) => x.status === "approved").length,
    };

    return {
      childId: child.id,
      displayName: [child.firstName, child.lastName].filter(Boolean).join(" ").trim(),
      isActive: child.isActive,
      avatarObjectKey: child.avatarObjectKey ?? null,
      balance: wallet?.balance ?? 0,
      stats,
    };
  }

  async getFamilyAnalytics(user: ParentUser, periodDaysRaw?: number) {
    const familyId = ensureFamilyId(user);
    const periodDays = Math.max(1, Math.min(365, Math.trunc(Number(periodDaysRaw ?? 30))));
    const from = new Date(Date.now() - periodDays * 24 * 60 * 60 * 1000);

    const [childrenCount, questsCompleted, walletTxCount] = await Promise.all([
      this.prisma.child.count({ where: { familyId } }),
      this.prisma.questAssignee.count({
        where: { child: { familyId }, status: "approved", createdAt: { gte: from } },
      }),
      this.prisma.walletTransaction.count({
        where: { wallet: { familyId }, createdAt: { gte: from } },
      }),
    ]);

    return {
      periodDays,
      from: from.toISOString(),
      childrenCount,
      questsCompleted,
      walletTxCount,
    };
  }

  async grantAdmin(user: ParentUser, targetUserId: string) {
    const familyId = ensureFamilyId(user);
    const id = (targetUserId ?? "").trim();
    if (!id) throw new BadRequestException("targetUserId обязателен");

    const profile = await this.prisma.profile.findUnique({ where: { userId: id } });
    if (!profile || profile.familyId !== familyId) throw new NotFoundException("Пользователь не найден");

    await this.prisma.profile.update({
      where: { userId: id },
      data: { role: "admin" },
    });
    return { ok: true };
  }

  async listAccessRequests(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.childAccessRequest.findMany({
      where: { familyId, status: "pending" },
      orderBy: { createdAt: "asc" },
    });
    return { items: rows };
  }

  async approveAccessRequest(user: ParentUser, requestId: string) {
    const familyId = ensureFamilyId(user);
    const req = await this.prisma.childAccessRequest.findUnique({ where: { id: requestId } });
    if (!req || req.familyId !== familyId) throw new NotFoundException("Запрос не найден");
    if (req.status !== "pending") throw new BadRequestException("Запрос уже обработан");

    const result = await this.prisma.$transaction(async (tx) => {
      let authCode = generateChildAuthCode();
      for (let i = 0; i < 10; i += 1) {
        const exists = await tx.child.findFirst({ where: { authCode } });
        if (!exists) break;
        authCode = generateChildAuthCode();
      }
      const child = await tx.child.create({
        data: {
          familyId,
          firstName: req.firstName,
          lastName: req.lastName,
          phone: req.phone,
          email: req.email,
          authCode,
          passwordHash: req.passwordHash,
          isActive: true,
        },
      });
      await tx.familyMemberCode.create({
        data: {
          familyId,
          role: "child",
          code: authCode,
          displayName: [req.firstName, req.lastName].filter(Boolean).join(" ").trim() || req.firstName,
          childId: child.id,
        },
      });

      await tx.wallet.create({
        data: {
          familyId,
          childId: child.id,
          balance: 0,
        },
      });

      const binding = await tx.childDeviceBinding.create({
        data: {
          familyId,
          childId: child.id,
          deviceId: req.deviceId,
          deviceKey: req.deviceKey,
          isActive: true,
        },
      });

      const sessionToken = randomUUID();
      const session = await tx.childSession.create({
        data: {
          familyId,
          childId: child.id,
          bindingId: binding.id,
          token: sessionToken,
          isActive: true,
        },
      });

      const updated = await tx.childAccessRequest.update({
        where: { id: req.id },
        data: {
          status: "approved",
          decidedAt: new Date(),
          decidedBy: user.userId,
          childId: child.id,
        },
      });

      return { child, binding, session, request: updated };
    });

    return {
      ok: true,
      requestId,
      childId: result.child.id,
      sessionToken: result.session.token,
    };
  }

  async rejectAccessRequest(user: ParentUser, requestId: string, _reason: string | null) {
    const familyId = ensureFamilyId(user);
    const req = await this.prisma.childAccessRequest.findUnique({ where: { id: requestId } });
    if (!req || req.familyId !== familyId) throw new NotFoundException("Запрос не найден");
    if (req.status !== "pending") throw new BadRequestException("Запрос уже обработан");

    await this.prisma.childAccessRequest.update({
      where: { id: req.id },
      data: { status: "rejected", decidedAt: new Date(), decidedBy: user.userId },
    });

    return { ok: true };
  }

  async revokeChildDevices(user: ParentUser, childId: string) {
    const familyId = ensureFamilyId(user);

    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child || child.familyId !== familyId) throw new NotFoundException("Ребёнок не найден");

    await this.prisma.$transaction(async (tx) => {
      const bindings = await tx.childDeviceBinding.findMany({
        where: { familyId, childId, isActive: true },
        select: { id: true },
      });
      const bindingIds = bindings.map((b) => b.id);

      if (bindingIds.length > 0) {
        await tx.childSession.updateMany({
          where: { bindingId: { in: bindingIds }, isActive: true },
          data: { isActive: false, revokedAt: new Date(), revokedBy: user.userId },
        });
        await tx.childDeviceBinding.updateMany({
          where: { id: { in: bindingIds } },
          data: { isActive: false, revokedAt: new Date(), revokedBy: user.userId },
        });
      }
    });

    return { ok: true };
  }

  async deactivateChild(user: ParentUser, childId: string) {
    const familyId = ensureFamilyId(user);
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child || child.familyId !== familyId) throw new NotFoundException("Ребёнок не найден");

    await this.prisma.child.update({
      where: { id: childId },
      data: { isActive: false, deactivatedAt: new Date() },
    });
    // Also revoke sessions/bindings.
    await this.revokeChildDevices(user, childId);

    return { ok: true };
  }

  async updateChild(
    user: ParentUser,
    childIdRaw: string,
    input: { firstName?: string; lastName?: string | null; isActive?: boolean },
  ) {
    const familyId = ensureFamilyId(user);
    const childId = (childIdRaw ?? "").trim();
    if (!childId) throw new BadRequestException("childId обязателен");
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child || child.familyId !== familyId) throw new NotFoundException("Ребёнок не найден");

    const next: Record<string, unknown> = {};
    if (typeof input.firstName === "string") {
      const firstName = input.firstName.trim();
      if (!firstName) throw new BadRequestException("firstName обязателен");
      next.firstName = firstName;
    }
    if (input.lastName !== undefined) {
      const lastName = (input.lastName ?? "").trim();
      next.lastName = lastName || null;
    }
    if (typeof input.isActive === "boolean") {
      next.isActive = input.isActive;
      next.deactivatedAt = input.isActive ? null : new Date();
    }
    if (Object.keys(next).length === 0) return { ok: true };

    await this.prisma.child.update({
      where: { id: childId },
      data: next,
    });
    if (input.isActive === false) {
      await this.revokeChildDevices(user, childId);
    }
    return { ok: true };
  }

  async deleteChild(user: ParentUser, childIdRaw: string) {
    const familyId = ensureFamilyId(user);
    const childId = (childIdRaw ?? "").trim();
    if (!childId) throw new BadRequestException("childId обязателен");
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child || child.familyId !== familyId) throw new NotFoundException("Ребёнок не найден");

    await this.prisma.$transaction(async (tx) => {
      await tx.familyMemberCode.deleteMany({ where: { familyId, childId } });
      await tx.childAccessRequest.updateMany({
        where: { familyId, childId },
        data: { childId: null },
      });
      await tx.questEvidence.deleteMany({ where: { childId } });
      await tx.questAssignee.deleteMany({ where: { childId } });
      await tx.shopPurchase.deleteMany({ where: { childId } });
      await tx.childSession.deleteMany({ where: { childId } });
      await tx.childDeviceBinding.deleteMany({ where: { childId } });

      const wallets = await tx.wallet.findMany({
        where: { familyId, childId },
        select: { id: true },
      });
      const walletIds = wallets.map((w) => w.id);
      if (walletIds.length > 0) {
        await tx.walletTransaction.deleteMany({ where: { walletId: { in: walletIds } } });
      }
      await tx.wallet.deleteMany({ where: { familyId, childId } });
      await tx.child.delete({ where: { id: childId } });
    });

    return { ok: true };
  }
}

