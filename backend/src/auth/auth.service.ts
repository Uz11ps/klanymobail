import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { AuthEmailTokenPurpose, Prisma } from "@prisma/client";
import * as bcrypt from "bcrypt";

import {
  emailVerificationHtml,
  passwordResetEmailHtml,
} from "../mail/auth-mail.templates";
import {
  generateAuthEmailPlainToken,
  hashAuthEmailToken,
  isDeliverableUserEmail,
} from "../mail/auth-email-token.util";
import { ResendMailService } from "../mail/resend-mail.service";
import { PrismaService } from "../prisma/prisma.service";

import { assertKlanyPasswordPlain } from "./password-policy";

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

/** Prisma P2002 → понятный 400 вместо 500 «сервер недоступен». */
function mapPrismaUniqueToBadRequest(err: unknown): never {
  if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
    const target = err.meta?.target;
    const fields = Array.isArray(target) ? target.map(String) : [];
    if (fields.includes("phone")) {
      throw new BadRequestException("Этот номер телефона уже зарегистрирован");
    }
    if (fields.includes("email")) {
      throw new BadRequestException("Этот email уже зарегистрирован");
    }
    throw new BadRequestException("Пользователь с такими данными уже зарегистрирован");
  }
  throw err;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly mail: ResendMailService,
  ) {}

  private userEmailVerified(user: { email: string; emailVerifiedAt: Date | null }): boolean {
    if (!isDeliverableUserEmail(user.email)) return true;
    return Boolean(user.emailVerifiedAt);
  }

  private async createEmailToken(userId: string, purpose: AuthEmailTokenPurpose, ttlMs: number) {
    const plain = generateAuthEmailPlainToken();
    const tokenHash = hashAuthEmailToken(plain);
    const expiresAt = new Date(Date.now() + ttlMs);

    await this.prisma.authEmailToken.updateMany({
      where: { userId, purpose, usedAt: null },
      data: { usedAt: new Date() },
    });

    await this.prisma.authEmailToken.create({
      data: { userId, purpose, tokenHash, expiresAt },
    });

    return plain;
  }

  private async sendVerificationEmailForUser(userId: string, email: string) {
    if (!isDeliverableUserEmail(email)) return { sent: false };
    const plain = await this.createEmailToken(
      userId,
      AuthEmailTokenPurpose.email_verification,
      48 * 60 * 60 * 1000,
    );
    const tpl = emailVerificationHtml(plain);
    const result = await this.mail.send({ to: email, subject: tpl.subject, html: tpl.html });
    return { sent: result.ok };
  }

  /** Проверка: зарегистрирован ли пользователь с данным email (только для главы: шаг «Продолжить»). */
  async isParentEmailRegistered(emailRaw: string) {
    const email = normalizeEmail(emailRaw ?? "");
    if (!email.includes("@")) {
      throw new BadRequestException("Нужен корректный email");
    }
    const existing = await this.prisma.user.findUnique({
      where: { email },
      select: { id: true },
    });
    return { registered: Boolean(existing) };
  }

  async signUpParent(input: { email?: string; phone?: string; password: string; displayName?: string; recoveryEmail?: string }) {
    const providedPhone = normalizePhone(input.phone ?? "");
    const providedEmail = normalizeEmail(input.email ?? input.recoveryEmail ?? "");
    const email = providedEmail || (providedPhone ? phoneToPseudoEmail(providedPhone) : "");
    if (!email.includes("@")) {
      throw new BadRequestException("Нужен email в формате user@example.com или номер телефона (10+ цифр)");
    }
    const validatedPassword = assertKlanyPasswordPlain(input.password);

    const existingEmail = await this.prisma.user.findUnique({ where: { email } });
    if (existingEmail) {
      throw new BadRequestException("Этот email уже зарегистрирован");
    }
    if (providedPhone) {
      const existingPhone = await this.prisma.user.findUnique({
        where: { phone: providedPhone },
      });
      if (existingPhone) {
        throw new BadRequestException("Этот номер телефона уже зарегистрирован");
      }
    }

    const passwordHash = await bcrypt.hash(validatedPassword, 10);

    // Create family + profile in one transaction.
    let result: Awaited<ReturnType<typeof this.createParentFamilyInTx>>;
    try {
      result = await this.prisma.$transaction(async (tx) =>
        this.createParentFamilyInTx(tx, {
          email,
          providedPhone,
          passwordHash,
          displayName: (input.displayName ?? "").trim() || null,
        }),
      );
    } catch (err) {
      throw mapPrismaUniqueToBadRequest(err);
    }

    const accessToken = this.jwt.sign({
      sub: result.user.id,
      role: result.profile.role,
      familyId: result.profile.familyId,
    } satisfies JwtPayload);

    const verification = await this.sendVerificationEmailForUser(result.user.id, result.user.email);

    return {
      accessToken,
      user: {
        id: result.user.id,
        email: result.user.email,
        phone: providedPhone || null,
        emailVerified: this.userEmailVerified(result.user),
      },
      profile: {
        userId: result.profile.userId,
        role: result.profile.role,
        familyId: result.profile.familyId,
      },
      family: { id: result.family.id, familyCode: result.family.familyCode },
      emailVerificationSent: verification.sent,
    };
  }

  private async createParentFamilyInTx(
    tx: Prisma.TransactionClient,
    input: {
      email: string;
      providedPhone: string;
      passwordHash: string;
      displayName: string | null;
    },
  ) {
      let familyCode = generateFamilyCode();
      // Ensure uniqueness (rare collision).
      for (let i = 0; i < 5; i += 1) {
        const exists = await tx.family.findUnique({ where: { familyCode } });
        if (!exists) break;
        familyCode = generateFamilyCode();
      }

      const user = await tx.user.create({
        data: {
          email: input.email,
          phone: input.providedPhone || null,
          passwordHash: input.passwordHash,
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
          displayName: input.displayName,
        },
      });

      return { user, family, profile };
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
        emailVerified: this.userEmailVerified(user),
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

  /** Письмо со ссылкой на сброс пароля (Resend). */
  async requestPasswordReset(input: { email?: string }) {
    const email = normalizeEmail(input.email ?? "");
    if (!isDeliverableUserEmail(email)) {
      throw new BadRequestException("Укажите email, на который регистрировались");
    }

    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return { ok: true };

    const plain = await this.createEmailToken(
      user.id,
      AuthEmailTokenPurpose.password_reset,
      60 * 60 * 1000,
    );
    const tpl = passwordResetEmailHtml(plain);
    await this.mail.send({ to: email, subject: tpl.subject, html: tpl.html });

    return { ok: true };
  }

  async resetPassword(input: { token?: string; password?: string }) {
    const plain = (input.token ?? "").trim();
    if (!plain) throw new BadRequestException("token обязателен");
    const validatedPassword = assertKlanyPasswordPlain(input.password ?? "");

    const row = await this.prisma.authEmailToken.findUnique({
      where: { tokenHash: hashAuthEmailToken(plain) },
      include: { user: true },
    });
    if (
      !row ||
      row.purpose !== AuthEmailTokenPurpose.password_reset ||
      row.usedAt ||
      row.expiresAt < new Date()
    ) {
      throw new BadRequestException("Ссылка недействительна или устарела");
    }

    const passwordHash = await bcrypt.hash(validatedPassword, 10);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: row.userId },
        data: { passwordHash },
      }),
      this.prisma.authEmailToken.update({
        where: { id: row.id },
        data: { usedAt: new Date() },
      }),
    ]);

    return { ok: true };
  }

  async verifyEmail(input: { token?: string }) {
    const plain = (input.token ?? "").trim();
    if (!plain) throw new BadRequestException("token обязателен");

    const row = await this.prisma.authEmailToken.findUnique({
      where: { tokenHash: hashAuthEmailToken(plain) },
    });
    if (
      !row ||
      row.purpose !== AuthEmailTokenPurpose.email_verification ||
      row.usedAt ||
      row.expiresAt < new Date()
    ) {
      throw new BadRequestException("Ссылка подтверждения недействительна или устарела");
    }

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: row.userId },
        data: { emailVerifiedAt: new Date() },
      }),
      this.prisma.authEmailToken.update({
        where: { id: row.id },
        data: { usedAt: new Date() },
      }),
    ]);

    return { ok: true, emailVerified: true };
  }

  async resendVerificationEmail(input: { email?: string }) {
    const email = normalizeEmail(input.email ?? "");
    if (!isDeliverableUserEmail(email)) {
      throw new BadRequestException("Укажите корректный email");
    }

    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return { ok: true };
    if (this.userEmailVerified(user)) return { ok: true, emailVerified: true };

    const sent = await this.sendVerificationEmailForUser(user.id, email);
    return { ok: true, emailVerificationSent: sent.sent };
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

