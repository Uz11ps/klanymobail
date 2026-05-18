import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import * as bcrypt from "bcrypt";

import { PrismaService } from "../prisma/prisma.service";

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function normalizePhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (!digits) return "";
  if (digits.length === 11 && digits.startsWith("8")) return `7${digits.substring(1)}`;
  return digits;
}

function phoneToPseudoEmail(phone: string): string {
  const normalized = normalizePhone(phone);
  return normalized ? `${normalized}@phone.klany.local` : "";
}

function generateFamilyCode(): string {
  // Human-friendly 8 chars (no 0/O, 1/I).
  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  let out = "";
  for (let i = 0; i < 8; i += 1) {
    out += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return out;
}

type JwtPayload = {
  sub: string;
  role: "admin" | "parent" | "child";
  familyId?: string | null;
  childId?: string | null;
  sessionToken?: string | null;
};

function normalizeInviteToken(token: string): string {
  return token.trim().toUpperCase();
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async signUpParent(input: { email?: string; phone?: string; password: string; displayName?: string; recoveryEmail?: string }) {
    const providedPhone = normalizePhone(input.phone ?? "");
    const providedEmail = normalizeEmail(input.email ?? input.recoveryEmail ?? "");
    const email = providedEmail || (providedPhone ? phoneToPseudoEmail(providedPhone) : "");
    if (!email.includes("@")) {
      throw new BadRequestException("Нужен email в формате user@example.com или номер телефона (10+ цифр)");
    }
    if ((input.password ?? "").length < 6) throw new BadRequestException("Пароль: минимум 6 символов");

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new BadRequestException("Пользователь уже существует");

    const passwordHash = await bcrypt.hash(input.password, 10);

    // Create family + profile in one transaction.
    const result = await this.prisma.$transaction(async (tx) => {
      let familyCode = generateFamilyCode();
      // Ensure uniqueness (rare collision).
      for (let i = 0; i < 5; i += 1) {
        const exists = await tx.family.findUnique({ where: { familyCode } });
        if (!exists) break;
        familyCode = generateFamilyCode();
      }

      const user = await tx.user.create({
        data: {
          email,
          phone: providedPhone || null,
          passwordHash,
        },
      });

      const family = await tx.family.create({
        data: {
          ownerUserId: user.id,
          familyCode,
        },
      });

      const profile = await tx.profile.create({
        data: {
          userId: user.id,
          familyId: family.id,
          role: "parent",
          displayName: (input.displayName ?? "").trim() || null,
        },
      });

      return { user, family, profile };
    });

    const accessToken = this.jwt.sign({
      sub: result.user.id,
      role: result.profile.role,
      familyId: result.profile.familyId,
    } satisfies JwtPayload);

    return {
      accessToken,
      user: { id: result.user.id, email: result.user.email, phone: providedPhone || null },
      profile: {
        userId: result.profile.userId,
        role: result.profile.role,
        familyId: result.profile.familyId,
      },
      family: { id: result.family.id, familyCode: result.family.familyCode },
    };
  }

  async signInWithPassword(input: { email?: string; login?: string; phone?: string; password: string }) {
    const login = (input.login ?? input.email ?? input.phone ?? "").trim();
    const email = login.includes("@")
      ? normalizeEmail(login)
      : phoneToPseudoEmail(login);
    if (!email) throw new UnauthorizedException("Неверный email/телефон или пароль");
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException("Неверный email/телефон или пароль");

    const ok = await bcrypt.compare(input.password ?? "", user.passwordHash);
    if (!ok) throw new UnauthorizedException("Неверный email/телефон или пароль");

    const profile = await this.prisma.profile.findFirst({
      where: { userId: user.id },
      orderBy: { createdAt: "asc" },
    });
    if (!profile) throw new ForbiddenException("Профиль не найден");

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const accessToken = this.jwt.sign({
      sub: user.id,
      role: profile.role,
      familyId: profile.familyId,
    } satisfies JwtPayload);

    return {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        phone: user.email.endsWith("@phone.klany.local")
          ? user.email.replace("@phone.klany.local", "")
          : null,
      },
      profile: { userId: profile.userId, role: profile.role, familyId: profile.familyId },
    };
  }

  async signInWithFamilyCode(input: { code: string }) {
    const code = (input.code ?? "").trim();
    if (!/^\d{6}$/.test(code)) throw new UnauthorizedException("Неверный код");

    const memberCode = await this.prisma.familyMemberCode.findUnique({
      where: { code },
      include: { family: true },
    });
    if (!memberCode) throw new UnauthorizedException("Неверный код");

    if (memberCode.childId) {
      throw new ForbiddenException("Для ребёнка используйте вход ребёнка по коду");
    }
    if (!memberCode.userId) throw new ForbiddenException("Код пользователя не привязан");

    const user = await this.prisma.user.findUnique({ where: { id: memberCode.userId } });
    if (!user) throw new UnauthorizedException("Пользователь не найден");
    const profile = await this.prisma.profile.findFirst({ where: { userId: user.id } });
    if (!profile) throw new ForbiddenException("Профиль не найден");

    const accessToken = this.jwt.sign({
      sub: user.id,
      role: profile.role,
      familyId: profile.familyId,
    } satisfies JwtPayload);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    return {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
      },
      profile: { userId: profile.userId, role: profile.role, familyId: profile.familyId },
      family: {
        id: memberCode.familyId,
        familyCode: memberCode.family.familyCode,
        clanName: memberCode.family.clanName,
      },
    };
  }

  async requestRecovery(input: { phone?: string }) {
    const phone = normalizePhone(input.phone ?? "");
    if (!phone) throw new BadRequestException("Телефон обязателен");

    const email = phoneToPseudoEmail(phone);
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      // Do not leak whether account exists.
      return { ok: true };
    }

    const profile = await this.prisma.profile.findFirst({ where: { userId: user.id } });
    if (!profile?.familyId) return { ok: true };

    const family = await this.prisma.family.findUnique({ where: { id: profile.familyId } });
    if (!family) return { ok: true };

    await this.prisma.notification.create({
      data: {
        familyId: family.id,
        toUserId: family.ownerUserId ?? null,
        nType: "account_recovery_requested",
        payload: { phone },
      },
    });

    const links = await this.prisma.telegramLink.findMany({
      where: { familyId: family.id },
      select: { telegramChatId: true },
      take: 20,
    });
    for (const tg of links) {
      const token = (process.env.TELEGRAM_BOT_TOKEN ?? "").trim();
      if (!token) break;
      await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: tg.telegramChatId,
          text: `Запрошено восстановление доступа для телефона ${phone}.`,
        }),
      });
    }

    return { ok: true };
  }

  async acceptParentInvite(userId: string, input: { inviteToken: string }) {
    const inviteToken = normalizeInviteToken(input.inviteToken ?? "");
    if (!inviteToken) throw new BadRequestException("inviteToken обязателен");

    const profile = await this.prisma.profile.findFirst({ where: { userId } });
    if (!profile) throw new ForbiddenException("Профиль не найден");
    if (profile.role === "child") {
      throw new ForbiddenException("Ребёнок не может принять инвайт родителя");
    }

    const family = await this.prisma.family.findUnique({
      where: { familyCode: inviteToken },
      select: { id: true, familyCode: true, clanName: true },
    });
    if (!family) throw new BadRequestException("Инвайт недействителен");

    const updated = await this.prisma.profile.update({
      where: { userId },
      data: {
        familyId: family.id,
        role: profile.role === "admin" ? "admin" : "parent",
      },
    });

    return {
      ok: true,
      profile: {
        userId: updated.userId,
        role: updated.role,
        familyId: updated.familyId,
      },
      family: {
        id: family.id,
        familyCode: family.familyCode,
        clanName: family.clanName,
      },
    };
  }

  signChildJwt(params: { familyId: string; childId: string; sessionToken: string }) {
    return this.jwt.sign({
      sub: `child:${params.childId}`,
      role: "child",
      familyId: params.familyId,
      childId: params.childId,
      sessionToken: params.sessionToken,
    } satisfies JwtPayload);
  }
}

