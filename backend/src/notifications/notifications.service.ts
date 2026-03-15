import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { createSign } from "node:crypto";

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

function encodeBase64Url(value: string): string {
  return Buffer.from(value, "utf8")
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

async function getGoogleAccessToken(): Promise<string | null> {
  const clientEmail = (process.env.FIREBASE_CLIENT_EMAIL ?? "").trim();
  const privateKeyRaw = (process.env.FIREBASE_PRIVATE_KEY ?? "").trim();
  if (!clientEmail || !privateKeyRaw) return null;

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const unsigned = `${encodeBase64Url(JSON.stringify(header))}.${encodeBase64Url(JSON.stringify(payload))}`;
  const sign = createSign("RSA-SHA256");
  sign.update(unsigned);
  sign.end();
  const privateKey = privateKeyRaw.replace(/\\n/g, "\n");
  const signature = sign
    .sign(privateKey)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
  const assertion = `${unsigned}.${signature}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!tokenRes.ok) return null;
  const tokenJson = (await tokenRes.json()) as { access_token?: string };
  return tokenJson.access_token ?? null;
}

async function sendFcmPush(tokens: string[], title: string, body: string, dataType: string): Promise<number> {
  const projectId = (process.env.FIREBASE_PROJECT_ID ?? "").trim();
  if (!projectId || tokens.length === 0) return 0;
  const accessToken = await getGoogleAccessToken();
  if (!accessToken) return 0;

  let sent = 0;
  for (const token of tokens) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: {
            type: dataType,
          },
        },
      }),
    });
    if (res.ok) sent += 1;
  }
  return sent;
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

  async fcmHealth(): Promise<{ ok: boolean; reason?: string }> {
    const projectId = (process.env.FIREBASE_PROJECT_ID ?? "").trim();
    const clientEmail = (process.env.FIREBASE_CLIENT_EMAIL ?? "").trim();
    const privateKeyRaw = (process.env.FIREBASE_PRIVATE_KEY ?? "").trim();
    if (!projectId || !clientEmail || !privateKeyRaw) return { ok: false, reason: "missing_env" };

    const accessToken = await getGoogleAccessToken();
    if (!accessToken) return { ok: false, reason: "oauth_failed" };
    return { ok: true };
  }

  async listDevicesForFamily(familyId: string) {
    const rows = await this.prisma.notificationDevice.findMany({
      where: { familyId },
      select: { id: true, platform: true, pushToken: true, isActive: true, createdAt: true, userId: true },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return { items: rows };
  }

  async resolveFamilyId(input: { familyId?: string; familyCode?: string }): Promise<string> {
    const familyId = (input.familyId ?? "").trim();
    if (familyId) return familyId;
    const familyCode = (input.familyCode ?? "").trim().toUpperCase();
    if (!familyCode) throw new BadRequestException("familyId или familyCode обязателен");
    const family = await this.prisma.family.findUnique({ where: { familyCode }, select: { id: true } });
    if (!family) throw new BadRequestException("Семья не найдена");
    return family.id;
  }

  async pushTestToFamily(familyId: string, title: string, body: string) {
    await this.pushToFamily(familyId, title, body, "test");
    return { ok: true };
  }

  async notifyFamilyPush(
    familyId: string,
    title: string,
    body: string,
    type: string = "generic",
  ) {
    await this.pushToFamily(familyId, title, body, type);
    return { ok: true };
  }

  async telegramTestToFamily(familyId: string, text: string) {
    const links = await this.prisma.telegramLink.findMany({
      where: { familyId },
      select: { telegramChatId: true },
      take: 50,
    });
    for (const tg of links) {
      await sendTelegram(tg.telegramChatId, text);
    }
    return { ok: true, chats: links.length };
  }

  private async pushToFamily(
    familyId: string,
    title: string,
    body: string,
    dataType: string = "generic",
  ): Promise<void> {
    const devices = await this.prisma.notificationDevice.findMany({
      where: { familyId, isActive: true },
      select: { pushToken: true },
      take: 300,
    });
    const tokens = devices.map((d) => d.pushToken).filter((x) => x.trim().length > 0);
    if (tokens.length === 0) return;
    await sendFcmPush(tokens, title, body, dataType);
  }

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

  async clear(user: AnyUser) {
    const familyId = ensureFamilyId(user);
    const where: Record<string, unknown> = { familyId };
    if (user.userId) {
      where.toUserId = user.userId;
    } else {
      where.toUserId = null;
    }
    const result = await this.prisma.notification.deleteMany({ where });
    return { ok: true, deleted: result.count };
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

      await this.pushToFamily(
        row.familyId,
        "Подписка скоро закончится",
        `Тариф ${row.planCode}. Продлите подписку заранее.`,
        "subscription_expiring",
      );
    }

    return { ok: true, processed: expiring.length };
  }

  async sendChildAccessRequested(input: { familyId: string; childName: string }) {
    const family = await this.prisma.family.findUnique({ where: { id: input.familyId } });
    if (!family) return { ok: true };

    const parentProfiles = await this.prisma.profile.findMany({
      where: {
        familyId: input.familyId,
        role: { in: ["parent", "admin"] },
      },
      select: { userId: true },
      take: 100,
    });
    const recipients = [...new Set(parentProfiles.map((p) => p.userId).filter(Boolean))];

    if (recipients.length > 0) {
      await this.prisma.notification.createMany({
        data: recipients.map((userId) => ({
          familyId: input.familyId,
          toUserId: userId,
          nType: "child_access_requested",
          payload: { childName: input.childName },
        })),
      });
    } else {
      const toUserId = family.ownerUserId ?? null;
      await this.prisma.notification.create({
        data: {
          familyId: input.familyId,
          toUserId,
          nType: "child_access_requested",
          payload: { childName: input.childName },
        },
      });
    }

    const links = await this.prisma.telegramLink.findMany({
      where: { familyId: input.familyId },
      select: { telegramChatId: true },
    });
    for (const tg of links) {
      await sendTelegram(
        tg.telegramChatId,
        `Ребёнок ${input.childName} запрашивает доступ. Откройте приложение и подтвердите.`,
      );
    }

    await this.pushToFamily(
      input.familyId,
      "Новый запрос ребёнка",
      `${input.childName} запрашивает доступ`,
      "child_access_requested",
    );

    return { ok: true };
  }
}

