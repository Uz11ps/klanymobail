import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import * as bcrypt from "bcrypt";

import { assertKlanyPasswordPlain } from "../auth/password-policy";
import { ParentService } from "../parent/parent.service";
import { PrismaService } from "../prisma/prisma.service";
import { ShopService } from "../shop/shop.service";

type AdminUser = {
  userId: string;
  role: "admin";
};

function toInt(v: unknown, fallback: number): number {
  const n = Math.trunc(Number(v));
  if (!Number.isFinite(n)) return fallback;
  return n;
}

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly parent: ParentService,
    private readonly shop: ShopService,
  ) {}

  async families() {
    const rows = await this.prisma.family.findMany({
      orderBy: { createdAt: "desc" },
      take: 200,
      select: { id: true, ownerUserId: true, familyCode: true, clanName: true, createdAt: true },
    });
    return { items: rows };
  }

  async profiles() {
    const rows = await this.prisma.profile.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: { userId: true, familyId: true, role: true, displayName: true, createdAt: true },
    });
    return { items: rows };
  }

  async children() {
    const rows = await this.prisma.child.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: { id: true, familyId: true, firstName: true, lastName: true, isActive: true, createdAt: true },
    });
    return {
      items: rows.map((c) => ({
        ...c,
        displayName: [c.firstName, c.lastName].filter(Boolean).join(" ").trim(),
      })),
    };
  }

  async quests() {
    const rows = await this.prisma.quest.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: { id: true, familyId: true, title: true, status: true, questType: true, reward: true, createdAt: true },
    });
    return { items: rows };
  }

  async products() {
    const rows = await this.prisma.shopProduct.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: { id: true, familyId: true, title: true, description: true, price: true, isActive: true, createdAt: true },
    });
    return { items: rows };
  }

  async purchases() {
    const rows = await this.prisma.shopPurchase.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: { id: true, familyId: true, childId: true, totalPrice: true, status: true, createdAt: true },
    });
    return { items: rows };
  }

  async subscriptions() {
    const rows = await this.prisma.familySubscription.findMany({
      orderBy: { startedAt: "desc" },
      take: 500,
      select: { id: true, familyId: true, planCode: true, status: true, expiresAt: true, source: true, startedAt: true },
    });
    return { items: rows };
  }

  async promocodes() {
    const rows = await this.prisma.promoCode.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: {
        id: true,
        code: true,
        planCode: true,
        durationDays: true,
        maxUses: true,
        usedCount: true,
        isActive: true,
        createdAt: true,
      },
    });
    return { items: rows };
  }

  async payments() {
    const rows = await this.prisma.paymentOrder.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: {
        id: true,
        familyId: true,
        planCode: true,
        amountRub: true,
        status: true,
        providerPaymentId: true,
        createdAt: true,
        paidAt: true,
      },
    });
    return { items: rows };
  }

  async notifications() {
    const rows = await this.prisma.notification.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: { id: true, familyId: true, toUserId: true, nType: true, isRead: true, createdAt: true, readAt: true },
    });
    return { items: rows };
  }

  async audit() {
    const rows = await this.prisma.auditLog.findMany({
      orderBy: { createdAt: "desc" },
      take: 500,
      select: { id: true, familyId: true, actorUserId: true, action: true, createdAt: true },
    });
    return { items: rows };
  }

  async accessRequests(status?: string) {
    const st = (status ?? "").trim();
    const where: any = {};
    if (st) where.status = st;
    const rows = await this.prisma.childAccessRequest.findMany({
      where,
      orderBy: { createdAt: "asc" },
      take: 500,
      select: { id: true, familyId: true, firstName: true, lastName: true, deviceId: true, status: true, createdAt: true },
    });
    return { items: rows };
  }

  async adminAccounts() {
    const rows = await this.prisma.profile.findMany({
      where: { role: "admin" },
      orderBy: { createdAt: "desc" },
      take: 500,
      include: {
        user: {
          select: { id: true, email: true, createdAt: true, lastLoginAt: true },
        },
      },
    });
    return {
      items: rows.map((row) => ({
        userId: row.userId,
        email: row.user.email,
        displayName: row.displayName,
        createdAt: row.createdAt,
        userCreatedAt: row.user.createdAt,
        lastLoginAt: row.user.lastLoginAt,
      })),
    };
  }

  async createPromo(_user: AdminUser, input: { code: string; planCode: string; durationDays: number; maxUses: number }) {
    const code = (input.code ?? "").trim().toUpperCase();
    const planCode = (input.planCode ?? "").trim();
    if (!code) throw new BadRequestException("code обязателен");
    if (!planCode) throw new BadRequestException("planCode обязателен");

    const durationDays = Math.max(1, toInt(input.durationDays, 30));
    const maxUses = Math.max(1, toInt(input.maxUses, 1));

    const plan = await this.prisma.subscriptionPlan.findUnique({ where: { code: planCode } });
    if (!plan) throw new NotFoundException("Тариф не найден");

    await this.prisma.promoCode.create({
      data: {
        code,
        planCode,
        durationDays,
        maxUses,
        isActive: true,
      },
    });
    return { ok: true };
  }

  async approveAccessRequest(user: AdminUser, requestId: string) {
    const req = await this.prisma.childAccessRequest.findUnique({ where: { id: requestId } });
    if (!req) throw new NotFoundException("Запрос не найден");
    return this.parent.approveAccessRequest({ userId: user.userId, role: "admin", familyId: req.familyId }, requestId);
  }

  async rejectAccessRequest(user: AdminUser, requestId: string) {
    const req = await this.prisma.childAccessRequest.findUnique({ where: { id: requestId } });
    if (!req) throw new NotFoundException("Запрос не найден");
    return this.parent.rejectAccessRequest({ userId: user.userId, role: "admin", familyId: req.familyId }, requestId, null);
  }

  async deactivateChild(user: AdminUser, childId: string) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException("Ребёнок не найден");
    return this.parent.deactivateChild({ userId: user.userId, role: "admin", familyId: child.familyId }, childId);
  }

  async deleteChild(user: AdminUser, childId: string) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException("Ребёнок не найден");
    return this.parent.deleteChild({ userId: user.userId, role: "admin", familyId: child.familyId }, childId);
  }

  async updateChild(
    user: AdminUser,
    childId: string,
    input: { firstName?: string; lastName?: string | null; isActive?: boolean },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException("Ребёнок не найден");
    return this.parent.updateChild(
      { userId: user.userId, role: "admin", familyId: child.familyId },
      childId,
      input,
    );
  }

  async updateProduct(
    _user: AdminUser,
    productId: string,
    input: { title?: string; description?: string | null; price?: number; isActive?: boolean },
  ) {
    const row = await this.prisma.shopProduct.findUnique({ where: { id: productId } });
    if (!row) throw new NotFoundException("Товар не найден");
    const next: Record<string, unknown> = {};
    if (typeof input.title === "string") {
      const title = input.title.trim();
      if (!title) throw new BadRequestException("title обязателен");
      next.title = title;
    }
    if (input.description !== undefined) {
      const description = (input.description ?? "").trim();
      next.description = description || null;
    }
    if (input.price !== undefined) {
      const price = Math.trunc(Number(input.price));
      if (!Number.isFinite(price) || price <= 0) throw new BadRequestException("price должен быть > 0");
      next.price = price;
    }
    if (typeof input.isActive === "boolean") next.isActive = input.isActive;
    if (Object.keys(next).length === 0) return { ok: true };
    await this.prisma.shopProduct.update({ where: { id: row.id }, data: next });
    return { ok: true };
  }

  async deleteProduct(_user: AdminUser, productId: string) {
    const row = await this.prisma.shopProduct.findUnique({ where: { id: productId } });
    if (!row) throw new NotFoundException("Товар не найден");
    const purchasesCount = await this.prisma.shopPurchase.count({ where: { productId: row.id } });
    if (purchasesCount > 0) {
      await this.prisma.shopProduct.update({ where: { id: row.id }, data: { isActive: false } });
      return { ok: true, soft: true };
    }
    await this.prisma.shopProduct.delete({ where: { id: row.id } });
    return { ok: true };
  }

  async updateQuest(
    _user: AdminUser,
    questId: string,
    input: { title?: string; rewardAmount?: number; status?: string },
  ) {
    const row = await this.prisma.quest.findUnique({ where: { id: questId } });
    if (!row) throw new NotFoundException("Квест не найден");
    const next: Record<string, unknown> = {};
    if (typeof input.title === "string") {
      const title = input.title.trim();
      if (!title) throw new BadRequestException("title обязателен");
      next.title = title;
    }
    if (input.rewardAmount !== undefined) {
      const reward = Math.max(0, Math.trunc(Number(input.rewardAmount)));
      next.reward = reward;
      await this.prisma.questAssignee.updateMany({
        where: { questId: row.id },
        data: { rewardAmount: reward },
      });
    }
    if (typeof input.status === "string") {
      const status = input.status.trim();
      if (status) next.status = status;
      if (status === "closed") next.closedAt = new Date();
    }
    if (Object.keys(next).length === 0) return { ok: true };
    await this.prisma.quest.update({ where: { id: row.id }, data: next });
    return { ok: true };
  }

  async deleteQuest(_user: AdminUser, questId: string) {
    const row = await this.prisma.quest.findUnique({ where: { id: questId } });
    if (!row) throw new NotFoundException("Квест не найден");
    await this.prisma.$transaction(async (tx) => {
      await tx.questEvidence.deleteMany({ where: { questId: row.id } });
      await tx.questComment.deleteMany({ where: { questId: row.id } });
      await tx.questAssignee.deleteMany({ where: { questId: row.id } });
      await tx.quest.delete({ where: { id: row.id } });
    });
    return { ok: true };
  }

  async decidePurchase(user: AdminUser, purchaseId: string, approve: boolean) {
    const purchase = await this.prisma.shopPurchase.findUnique({ where: { id: purchaseId } });
    if (!purchase) throw new NotFoundException("Покупка не найдена");
    return this.shop.decide({ userId: user.userId, role: "admin", familyId: purchase.familyId }, purchaseId, approve);
  }

  async createAdminAccount(_user: AdminUser, input: { email: string; password: string; displayName?: string }) {
    const email = normalizeEmail(input.email ?? "");
    const validatedPassword = assertKlanyPasswordPlain(input.password ?? "");
    const displayName = (input.displayName ?? "").trim() || null;
    if (!email.includes("@")) throw new BadRequestException("Некорректный email");

    const passwordHash = await bcrypt.hash(validatedPassword, 10);
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (!existing) {
      const created = await this.prisma.$transaction(async (tx) => {
        const user = await tx.user.create({
          data: { email, passwordHash },
          select: { id: true },
        });
        await tx.profile.create({
          data: { userId: user.id, role: "admin", displayName, familyId: null },
        });
        return user;
      });
      return { ok: true, userId: created.id };
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: existing.id },
        data: { passwordHash },
      });
      await tx.profile.upsert({
        where: { userId: existing.id },
        create: { userId: existing.id, role: "admin", displayName, familyId: null },
        update: { role: "admin", displayName: displayName ?? undefined, familyId: null },
      });
      return existing.id;
    });
    return { ok: true, userId: updated };
  }

  async deleteAdminAccount(user: AdminUser, targetUserId: string) {
    const id = (targetUserId ?? "").trim();
    if (!id) throw new BadRequestException("userId обязателен");
    if (id === user.userId) throw new BadRequestException("Нельзя удалить самого себя");

    const adminCount = await this.prisma.profile.count({ where: { role: "admin" } });
    if (adminCount <= 1) {
      throw new BadRequestException("Нельзя удалить последнего администратора");
    }

    const profile = await this.prisma.profile.findUnique({ where: { userId: id } });
    if (!profile || profile.role !== "admin") {
      throw new NotFoundException("Администратор не найден");
    }
    if (profile.familyId) {
      throw new BadRequestException("Нельзя удалить админа, привязанного к семье");
    }

    const ownsFamilies = await this.prisma.family.count({ where: { ownerUserId: id } });
    if (ownsFamilies > 0) {
      throw new BadRequestException("Нельзя удалить админа-владельца семьи");
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.profile.delete({ where: { userId: id } });
      await tx.user.delete({ where: { id } });
    });
    return { ok: true };
  }
}

