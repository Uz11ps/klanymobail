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
export class ShopService {
  constructor(private readonly prisma: PrismaService) {}

  private async ensureWallet(childId: string, familyId: string) {
    const existing = await this.prisma.wallet.findUnique({ where: { childId } });
    if (existing) return existing;
    return this.prisma.wallet.create({ data: { childId, familyId, balance: 0 } });
  }

  async listProducts(user: ParentUser | ChildUser) {
    const familyId = ensureFamilyId(user);
    const where: any = { familyId };
    if (user.role === "child") where.isActive = true;
    const rows = await this.prisma.shopProduct.findMany({ where, orderBy: { createdAt: "desc" } });
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
        childName: [r.child.firstName, r.child.lastName].filter(Boolean).join(" ").trim(),
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
      await this.prisma.shopPurchase.update({
        where: { id: purchase.id },
        data: { status: "approved", decidedAt: new Date(), decidedBy: user.userId },
      });
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

    return { ok: true };
  }
}

