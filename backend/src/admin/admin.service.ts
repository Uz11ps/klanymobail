import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";

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
      select: { id: true, familyId: true, title: true, price: true, isActive: true, createdAt: true },
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

  async decidePurchase(user: AdminUser, purchaseId: string, approve: boolean) {
    const purchase = await this.prisma.shopPurchase.findUnique({ where: { id: purchaseId } });
    if (!purchase) throw new NotFoundException("Покупка не найдена");
    return this.shop.decide({ userId: user.userId, role: "admin", familyId: purchase.familyId }, purchaseId, approve);
  }
}

