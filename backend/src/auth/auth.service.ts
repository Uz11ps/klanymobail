import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import * as bcrypt from "bcrypt";

import { PrismaService } from "../prisma/prisma.service";

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
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

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async signUpParent(input: { email: string; password: string; displayName?: string }) {
    const email = normalizeEmail(input.email);
    if (!email.includes("@")) throw new BadRequestException("Некорректный email");
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
      user: { id: result.user.id, email: result.user.email },
      profile: {
        userId: result.profile.userId,
        role: result.profile.role,
        familyId: result.profile.familyId,
      },
      family: { id: result.family.id, familyCode: result.family.familyCode },
    };
  }

  async signInWithPassword(input: { email: string; password: string }) {
    const email = normalizeEmail(input.email);
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException("Неверный логин или пароль");

    const ok = await bcrypt.compare(input.password ?? "", user.passwordHash);
    if (!ok) throw new UnauthorizedException("Неверный логин или пароль");

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
      user: { id: user.id, email: user.email },
      profile: { userId: profile.userId, role: profile.role, familyId: profile.familyId },
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

