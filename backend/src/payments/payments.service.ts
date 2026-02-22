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

function isUuid(v: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);
}

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService) {}

  async createOrder(user: ParentUser, input: { planCode: string; amountRub: number }) {
    const familyId = ensureFamilyId(user);
    const planCode = (input.planCode ?? "").trim() || "premium";
    const amountRub = Number(input.amountRub ?? 0);
    if (!Number.isFinite(amountRub) || amountRub <= 0) throw new BadRequestException("Некорректная сумма");

    const order = await this.prisma.paymentOrder.create({
      data: {
        familyId,
        planCode,
        amountRub: Math.round(amountRub),
        status: "created",
      },
    });

    return { orderId: order.id };
  }

  async createYookassaPayment(user: ParentUser, orderId: string) {
    const familyId = ensureFamilyId(user);
    const id = (orderId ?? "").trim();
    if (!isUuid(id)) throw new BadRequestException("orderId должен быть UUID");

    const shopId = process.env.YOOKASSA_SHOP_ID ?? "";
    const secret = process.env.YOOKASSA_SECRET_KEY ?? "";
    const returnUrl = process.env.YOOKASSA_RETURN_URL ?? "";
    if (!shopId || !secret || !returnUrl) {
      throw new BadRequestException("YooKassa env vars не настроены");
    }

    const order = await this.prisma.paymentOrder.findUnique({ where: { id } });
    if (!order || order.familyId !== familyId) throw new NotFoundException("Заказ не найден");

    const auth = Buffer.from(`${shopId}:${secret}`).toString("base64");
    const idempotenceKey = randomUUID();
    const amountValue = Number(order.amountRub).toFixed(2);

    const resp = await fetch("https://api.yookassa.ru/v3/payments", {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Idempotence-Key": idempotenceKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: { value: amountValue, currency: "RUB" },
        capture: true,
        confirmation: { type: "redirect", return_url: returnUrl },
        description: `Klany subscription order ${order.id}`,
        metadata: {
          order_id: order.id,
          family_id: order.familyId,
          plan_code: order.planCode,
        },
      }),
    });

    const data = (await resp.json()) as any;
    if (!resp.ok) {
      throw new BadRequestException({ provider: "yookassa", error: data });
    }

    await this.prisma.paymentOrder.update({
      where: { id: order.id },
      data: {
        providerPaymentId: data.id ?? null,
        payload: data ?? undefined,
        status: "pending",
      },
    });

    return { confirmationUrl: data?.confirmation?.confirmation_url ?? null };
  }
}

