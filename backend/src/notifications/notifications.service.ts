import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";

import { PrismaService } from "../prisma/prisma.service";

async function sendTelegram(chatId: string, text: string) {
  const token = process.env.TELEGRAM_BOT_TOKEN ?? "";
  if (!token) return;
  await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, text }),
  });
}

type AnyUser = {
  role: "admin" | "parent" | "child";
  userId?: string;
  familyId?: string | null;
  childId?: string | null;
};

function ensureFamilyId(user: AnyUser): string {
  const familyId = user.familyId ?? null;
  if (!familyId) throw new ForbiddenException("Нет семьи");
  return familyId;
}

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async registerDevice(user: AnyUser, input: { platform: string; pushToken: string }) {
    const platform = (input.platform ?? "").trim();
    const pushToken = (input.pushToken ?? "").trim();
    if (!platform || !pushToken) throw new BadRequestException("platform/pushToken обязательны");

    await this.prisma.notificationDevice.upsert({
      where: { pushToken },
      create: {
        pushToken,
        platform,
        isActive: true,
        familyId: user.familyId ?? null,
        userId: user.userId ?? null,
      },
      update: {
        platform,
        isActive: true,
        familyId: user.familyId ?? null,
        userId: user.userId ?? null,
      },
    });

    return { ok: true };
  }

  async list(user: AnyUser) {
    const familyId = ensureFamilyId(user);

    const rows = await this.prisma.notification.findMany({
      where: {
        familyId,
        ...(user.userId ? { toUserId: user.userId } : {}),
      },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return { items: rows };
  }

  async markRead(user: AnyUser, id: string) {
    const familyId = ensureFamilyId(user);
    const row = await this.prisma.notification.findUnique({ where: { id } });
    if (!row || row.familyId !== familyId) throw new NotFoundException("Не найдено");

    await this.prisma.notification.update({
      where: { id: row.id },
      data: { isRead: true, readAt: new Date() },
    });
    return { ok: true };
  }

  async runCron(providedSecret: string) {
    const expected = process.env.CRON_SECRET ?? "";
    if (!expected || providedSecret !== expected) throw new ForbiddenException("Forbidden");

    const now = new Date();
    const inThreeDays = new Date(now);
    inThreeDays.setDate(inThreeDays.getDate() + 3);

    const expiring = await this.prisma.familySubscription.findMany({
      where: {
        status: "active",
        expiresAt: { not: null, lte: inThreeDays, gte: now },
      },
      select: { familyId: true, planCode: true, expiresAt: true },
      take: 500,
    });

    for (const row of expiring) {
      const family = await this.prisma.family.findUnique({ where: { id: row.familyId } });
      const toUserId = family?.ownerUserId ?? null;

      await this.prisma.notification.create({
        data: {
          familyId: row.familyId,
          toUserId,
          nType: "subscription_expiring",
          payload: { plan: row.planCode, expiresAt: row.expiresAt },
        },
      });

      const links = await this.prisma.telegramLink.findMany({
        where: { familyId: row.familyId },
        select: { telegramChatId: true },
      });
      for (const tg of links) {
        await sendTelegram(
          tg.telegramChatId,
          `Подписка ${row.planCode} скоро закончится (${row.expiresAt?.toISOString() ?? ""})`,
        );
      }
    }

    return { ok: true, processed: expiring.length };
  }
}

