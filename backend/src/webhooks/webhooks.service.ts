import { BadRequestException, Injectable } from "@nestjs/common";

import { PrismaService } from "../prisma/prisma.service";

function isUuid(v: string | undefined): v is string {
  if (!v) return false;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);
}

async function sendTelegram(chatId: string, text: string) {
  const token = process.env.TELEGRAM_BOT_TOKEN ?? "";
  if (!token) return;
  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text }),
  });
}

@Injectable()
export class WebhooksService {
  constructor(private readonly prisma: PrismaService) {}

  async handleYookassa(payload: any) {
    const eventType = payload?.event as string | undefined;
    const payment = payload?.object;
    const paymentId = payment?.id as string | undefined;
    const metadata = payment?.metadata ?? {};
    const orderId = metadata?.order_id as string | undefined;

    await this.prisma.paymentWebhookEvent.create({
      data: {
        provider: "yookassa",
        eventType: eventType ?? "unknown",
        eventId: paymentId ?? null,
        payload,
        processed: false,
      },
    });

    if (eventType !== "payment.succeeded" || !isUuid(orderId)) {
      return { ok: true, skipped: true };
    }

    const order = await this.prisma.paymentOrder.findUnique({ where: { id: orderId } });
    if (!order) throw new BadRequestException("Order not found");

    await this.prisma.$transaction(async (tx) => {
      await tx.paymentOrder.update({
        where: { id: order.id },
        data: {
          status: "paid",
          paidAt: new Date(),
          payload,
        },
      });

      const startedAt = new Date();
      const expiresAt = new Date(startedAt);
      expiresAt.setDate(expiresAt.getDate() + 30);

      await tx.familySubscription.create({
        data: {
          familyId: order.familyId,
          planCode: order.planCode ?? "premium",
          status: "active",
          startedAt,
          expiresAt,
          source: "yookassa",
        },
      });

      await tx.paymentWebhookEvent.updateMany({
        where: { provider: "yookassa", eventId: paymentId ?? "" },
        data: { processed: true },
      });
    });

    return { ok: true };
  }

  async handleTelegram(update: any) {
    const message = update?.message;
    const text: string = (message?.text ?? "").trim();
    const chatId = String(message?.chat?.id ?? "");
    const username = message?.from?.username as string | undefined;
    if (!chatId || !text) return { ok: true };

    if (text === "/start") {
      await sendTelegram(
        chatId,
        "Привет! Команды:\n/link FAMILY-ID — привязать чат к семье\n/promo CODE — активировать промокод",
      );
      return { ok: true };
    }

    if (text.startsWith("/link ")) {
      const familyCode = text.replace("/link", "").trim().toUpperCase();
      const family = await this.prisma.family.findUnique({ where: { familyCode } });
      if (!family) {
        await sendTelegram(chatId, "Family ID не найден");
        return { ok: true };
      }

      await this.prisma.telegramLink.upsert({
        where: { telegramChatId: chatId },
        create: {
          familyId: family.id,
          telegramChatId: chatId,
          telegramUsername: username ?? null,
        },
        update: {
          familyId: family.id,
          telegramUsername: username ?? null,
        },
      });

      await sendTelegram(chatId, "Чат привязан к семье. Теперь можно активировать промокоды.");
      return { ok: true };
    }

    if (text.startsWith("/promo ")) {
      const code = text.replace("/promo", "").trim().toUpperCase();
      const link = await this.prisma.telegramLink.findUnique({ where: { telegramChatId: chatId } });
      if (!link) {
        await sendTelegram(chatId, "Сначала привяжите семью командой /link FAMILY-ID");
        return { ok: true };
      }

      const promo = await this.prisma.promoCode.findUnique({ where: { code } });
      if (!promo || promo.isActive !== true || promo.usedCount >= promo.maxUses) {
        await sendTelegram(chatId, "Промокод недоступен");
        return { ok: true };
      }

      const now = new Date();
      const expiresAt = new Date(now);
      expiresAt.setDate(expiresAt.getDate() + Math.max(Number(promo.durationDays || 30), 1));

      await this.prisma.$transaction(async (tx) => {
        await tx.familySubscription.create({
          data: {
            familyId: link.familyId,
            planCode: promo.planCode,
            status: "active",
            startedAt: now,
            expiresAt,
            source: "telegram_promo",
          },
        });
        await tx.promoCode.update({ where: { id: promo.id }, data: { usedCount: promo.usedCount + 1 } });
        await tx.promoRedemption.create({ data: { promoId: promo.id, familyId: link.familyId } });
      });

      await sendTelegram(chatId, `Промокод применён. Тариф: ${promo.planCode}`);
      return { ok: true };
    }

    await sendTelegram(chatId, "Неизвестная команда. Используйте /start");
    return { ok: true };
  }
}

