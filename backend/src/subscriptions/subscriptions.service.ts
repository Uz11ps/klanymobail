import { BadRequestException, ForbiddenException, Injectable } from "@nestjs/common";

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
export class SubscriptionsService {
  constructor(private readonly prisma: PrismaService) {}

  async listFamilySubscriptions(user: ParentUser) {
    const familyId = ensureFamilyId(user);
    const rows = await this.prisma.familySubscription.findMany({
      where: { familyId },
      orderBy: { startedAt: "desc" },
    });
    return { items: rows };
  }

  async activatePromo(user: ParentUser, codeRaw: string) {
    const familyId = ensureFamilyId(user);
    const code = (codeRaw ?? "").trim().toUpperCase();
    if (!code) throw new BadRequestException("code обязателен");

    const result = await this.prisma.$transaction(async (tx) => {
      const promo = await tx.promoCode.findUnique({ where: { code } });
      if (!promo || promo.isActive !== true) throw new BadRequestException("Промокод недоступен");
      if (promo.usedCount >= promo.maxUses) throw new BadRequestException("Промокод исчерпан");

      const now = new Date();
      const expires = new Date(now);
      expires.setDate(expires.getDate() + Math.max(Number(promo.durationDays || 30), 1));

      await tx.familySubscription.create({
        data: {
          familyId,
          planCode: promo.planCode,
          status: "active",
          startedAt: now,
          expiresAt: expires,
          source: "promo",
        },
      });

      await tx.promoCode.update({
        where: { id: promo.id },
        data: { usedCount: promo.usedCount + 1 },
      });

      await tx.promoRedemption.create({
        data: { promoId: promo.id, familyId },
      });

      return { ok: true, planCode: promo.planCode };
    });

    return result;
  }
}

