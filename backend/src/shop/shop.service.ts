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
export class ShopService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  private async ensureWallet(childId: string, familyId: string) {
    const existing = await this.prisma.wallet.findUnique({ where: { childId } });
    if (existing) return existing;
    return this.prisma.wallet.create({ data: { childId, familyId, balance: 0 } });
  }

  async listProducts(user: ParentUser | ChildUser) {
    const familyId = ensureFamilyId(user);
    // Same catalog for parents and children; purchase is still blocked for
    // inactive items in requestPurchase().
    const rows = await this.prisma.shopProduct.findMany({
      where: { familyId },
      orderBy: { createdAt: "desc" },
    });
    return { items: rows };
  }

  async createProduct(user: ParentUser, input: { title: string; description?: string; price: number; imageKey?: string | null }) {
    const familyId = ensureFamilyId(user);
    const title = (input.title ?? "").trim();
    if (!title) throw new BadRequestException("title обязателен");
    const price = Math.trunc(Number(input.price ?? 0));
    if (!Number.isFinite(price) || price <= 0) throw new BadRequestException("price должен быть > 0");

    const row = await this.prisma.shopProduct.create({
      data: {
        familyId,
        title,
        description: (input.description ?? "").trim() || null,
        price,
        imageKey: input.imageKey ?? null,
        isActive: true,
      },
    });
    return { id: row.id };
  }

  async toggleProduct(user: ParentUser, productId: string, isActive: boolean) {
    const familyId = ensureFamilyId(user);
    const row = await this.prisma.shopProduct.findUnique({ where: { id: productId } });
    if (!row || row.familyId !== familyId) throw new NotFoundException("Товар не найден");

    await this.prisma.shopProduct.update({
      where: { id: row.id },
      data: { isActive: !!isActive },
    });
    return { ok: true };
  }

  async updateProduct(
    user: ParentUser,
    productId: string,
    input: { title?: string; description?: string | null; price?: number; isActive?: boolean },
  ) {
    const familyId = ensureFamilyId(user);
    const row = await this.prisma.shopProduct.findUnique({ where: { id: productId } });
    if (!row || row.familyId !== familyId) throw new NotFoundException("Товар не найден");

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
    if (input.isActive !== undefined) {
      next.isActive = input.isActive === true;
    }
    if (Object.keys(next).length === 0) return { ok: true };

    await this.prisma.shopProduct.update({
      where: { id: row.id },
      data: next,
    });
    return { ok: true };
  }

  async deleteProduct(user: ParentUser, productId: string) {
    const familyId = ensureFamilyId(user);
    const row = await this.prisma.shopProduct.findUnique({ where: { id: productId } });
    if (!row || row.familyId !== familyId) throw new NotFoundException("Товар не найден");
    const purchasesCount = await this.prisma.shopPurchase.count({ where: { productId: row.id } });
    if (purchasesCount > 0) {
      await this.prisma.shopProduct.update({
        where: { id: row.id },
        data: { isActive: false },
      });
      return { ok: true, soft: true };
    }
    await this.prisma.shopProduct.delete({ where: { id: row.id } });
    return { ok: true };
  }

  async requestPurchase(user: ChildUser, productIdRaw: string, quantityRaw: number) {
    const familyId = ensureFamilyId(user);
    const productId = (productIdRaw ?? "").trim();
    if (!productId) throw new BadRequestException("productId обязателен");
    const quantity = Math.max(1, Math.trunc(Number(quantityRaw ?? 1)));

    const product = await this.prisma.shopProduct.findUnique({ where: { id: productId } });
    if (!product || product.familyId !== familyId || product.isActive !== true) {
      throw new NotFoundException("Товар не найден");
    }

    const wallet = await this.ensureWallet(user.childId, familyId);
    const total = product.price * quantity;
    if (wallet.balance < total) throw new BadRequestException("Недостаточно средств");

    const childProfile = await this.prisma.child.findUnique({
      where: { id: user.childId },
      select: { firstName: true, lastName: true },
    });
    const childDisplayName =
      [childProfile?.firstName?.trim(), childProfile?.lastName?.trim()]
        .filter((s) => s && String(s).length > 0)
        .join(" ")
        .trim() || "";

    const purchase = await this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({ where: { id: wallet.id }, data: { balance: wallet.balance - total } });
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: -total,
          txType: "freeze",
          note: `Заморозка на покупку: ${product.title}`,
          reason: "shop_freeze",
          meta: { productId: product.id, quantity },
        },
      });

      return tx.shopPurchase.create({
        data: {
          familyId,
          childId: user.childId,
          productId: product.id,
          quantity,
          totalPrice: total,
          frozenAmount: total,
          status: "requested",
        },
      });
    });

    const parentProfiles = await this.prisma.profile.findMany({
      where: {
        familyId,
        role: { in: ["parent", "admin"] },
      },
      select: { userId: true },
      take: 100,
    });
    const recipients = [...new Set(parentProfiles.map((p) => p.userId).filter(Boolean))];
    if (recipients.length > 0) {
      await this.prisma.notification.createMany({
        data: recipients.map((userId) => ({
          familyId,
          toUserId: userId,
          nType: "shop_purchase_requested",
          payload: {
            purchaseId: purchase.id,
            productTitle: product.title,
            totalPrice: purchase.totalPrice,
            childId: user.childId,
            ...(childDisplayName ? { displayName: childDisplayName } : {}),
          },
        })),
      });
    }
    await this.notifications.notifyFamilyPush(
      familyId,
      "Новая заявка на покупку",
      `${product.title} • ${purchase.totalPrice} монет`,
      "shop_purchase_requested",
    );

    return { purchaseId: purchase.id };
  }

  async listPending(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.shopPurchase.findMany({
      where: { familyId, status: "requested" },
      orderBy: { createdAt: "desc" },
      include: { product: true, child: true },
      take: 200,
    });

    return {
      items: rows.map((r) => ({
        id: r.id,
        status: r.status,
        totalPrice: r.totalPrice,
        productTitle: r.product.title,
        childId: r.childId,
        childName: [r.child.firstName, r.child.lastName].filter(Boolean).join(" ").trim(),
        avatarObjectKey: r.child.avatarObjectKey ?? null,
      })),
    };
  }

  async decide(user: ParentUser, purchaseIdRaw: string, approve: boolean) {
    const familyId = ensureFamilyId(user);
    const purchaseId = (purchaseIdRaw ?? "").trim();
    if (!purchaseId) throw new BadRequestException("purchaseId обязателен");

    const purchase = await this.prisma.shopPurchase.findUnique({
      where: { id: purchaseId },
      include: { product: true },
    });
    if (!purchase || purchase.familyId !== familyId) throw new NotFoundException("Покупка не найдена");
    if (purchase.status !== "requested") throw new BadRequestException("Покупка уже обработана");

    if (approve) {
      const parentProfiles = await this.prisma.profile.findMany({
        where: {
          familyId,
          role: { in: ["parent", "admin"] },
        },
        select: { userId: true },
        take: 100,
      });
      const recipients = [...new Set(parentProfiles.map((p) => p.userId).filter(Boolean))];
      await this.prisma.shopPurchase.update({
        where: { id: purchase.id },
        data: { status: "approved", decidedAt: new Date(), decidedBy: user.userId },
      });
      if (recipients.length > 0) {
        await this.prisma.notification.createMany({
          data: recipients.map((userId) => ({
            familyId,
            toUserId: userId,
            nType: "shop_purchase_approved",
            payload: {
              purchaseId: purchase.id,
              productTitle: purchase.product.title,
              totalPrice: purchase.totalPrice,
            },
          })),
        });
      }
      await this.notifications.notifyFamilyPush(
        familyId,
        "Покупка подтверждена",
        `${purchase.product.title} подтверждена`,
        "shop_purchase_approved",
      );
      return { ok: true };
    }

    // Reject -> refund frozen funds.
    const wallet = await this.ensureWallet(purchase.childId, familyId);
    await this.prisma.$transaction(async (tx) => {
      await tx.wallet.update({ where: { id: wallet.id }, data: { balance: wallet.balance + purchase.frozenAmount } });
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: purchase.frozenAmount,
          txType: "refund",
          note: `Возврат по покупке: ${purchase.product.title}`,
          reason: "shop_refund",
          meta: { purchaseId: purchase.id },
        },
      });
      await tx.shopPurchase.update({
        where: { id: purchase.id },
        data: { status: "rejected", decidedAt: new Date(), decidedBy: user.userId },
      });
    });

    const parentProfiles = await this.prisma.profile.findMany({
      where: {
        familyId,
        role: { in: ["parent", "admin"] },
      },
      select: { userId: true },
      take: 100,
    });
    const recipients = [...new Set(parentProfiles.map((p) => p.userId).filter(Boolean))];
    if (recipients.length > 0) {
      await this.prisma.notification.createMany({
        data: recipients.map((userId) => ({
          familyId,
          toUserId: userId,
          nType: "shop_purchase_rejected",
          payload: {
            purchaseId: purchase.id,
            productTitle: purchase.product.title,
            totalPrice: purchase.totalPrice,
          },
        })),
      });
    }
    await this.notifications.notifyFamilyPush(
      familyId,
      "Покупка отклонена",
      `${purchase.product.title} отклонена`,
      "shop_purchase_rejected",
    );

    return { ok: true };
  }
}

