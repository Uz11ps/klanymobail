import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { randomUUID } from "crypto";

import { PrismaService } from "../prisma/prisma.service";

type ParentUser = {
  userId: string;
  role: "parent" | "admin";
  familyId?: string | null;
};

function ensureFamilyId(user: ParentUser): string {
  const familyId = user.familyId ?? null;
  if (!familyId) throw new ForbiddenException("Нет семьи");
  return familyId;
}

@Injectable()
export class ParentService {
  constructor(private readonly prisma: PrismaService) {}

  async getFamilyContext(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const family = await this.prisma.family.findUnique({ where: { id: familyId } });
    if (!family) throw new NotFoundException("Семья не найдена");
    return { familyId: family.id, familyCode: family.familyCode, clanName: family.clanName };
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
        displayName: [c.firstName, c.lastName].filter(Boolean).join(" ").trim(),
        isActive: c.isActive,
      })),
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
      const child = await tx.child.create({
        data: {
          familyId,
          firstName: req.firstName,
          lastName: req.lastName,
          isActive: true,
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
}

