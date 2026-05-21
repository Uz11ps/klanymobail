import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import * as bcrypt from "bcrypt";
import { randomUUID } from "crypto";

import { AuthService } from "../auth/auth.service";
import { assertKlanyPasswordPlain } from "../auth/password-policy";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../prisma/prisma.service";

type ChildUser = {
  role: "child";
  familyId: string;
  childId: string;
};

function generateChildAuthCode(): string {
  return Math.floor(Math.random() * 1000000).toString().padStart(6, "0");
}

@Injectable()
export class ChildService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly notifications: NotificationsService,
  ) {}

  async submitAccessRequest(input: {
    phone: string;
    email: string;
    firstName: string;
    password: string;
    familyCode?: string;
    parentContact?: string;
    deviceId: string;
    deviceKey: string;
  }) {
    const normalizePhone = (phone: string): string => {
      const digits = phone.replace(/\D/g, "");
      if (!digits) return "";
      if (digits.length === 11 && digits.startsWith("8")) return `7${digits.substring(1)}`;
      return digits;
    };
    const phoneToPseudoEmail = (phone: string): string => {
      const normalized = normalizePhone(phone);
      return normalized ? `${normalized}@phone.klany.local` : "";
    };
    const normalizeEmail = (email: string): string => email.trim().toLowerCase();

    const phoneRaw = (input.phone ?? "").trim();
    const emailRaw = (input.email ?? "").trim();
    const parentContactRaw = (input.parentContact ?? "").trim();
    const firstName = (input.firstName ?? "").trim();
    const familyCode = (input.familyCode ?? "").trim().toUpperCase();
    const deviceId = (input.deviceId ?? "").trim();
    const deviceKey = (input.deviceKey ?? "").trim();
    const normalizedPhone = normalizePhone(phoneRaw);
    const normalizedEmail = normalizeEmail(emailRaw);

    if (!firstName) throw new BadRequestException("firstName обязателен");
    if (!normalizedPhone) throw new BadRequestException("phone обязателен");
    if (!normalizedEmail || !normalizedEmail.includes("@")) {
      throw new BadRequestException("email обязателен");
    }
    const validatedPassword = assertKlanyPasswordPlain(input.password ?? "");
    if (!deviceId || !deviceKey) throw new BadRequestException("deviceId/deviceKey обязательны");
    if (!familyCode && !parentContactRaw) {
      throw new BadRequestException("Укажите Family ID или контакт родителя");
    }
    let family = null;
    if (familyCode) {
      family = await this.prisma.family.findUnique({ where: { familyCode } });
    }
    if (!family && parentContactRaw) {
      const parentPhone = normalizePhone(parentContactRaw);
      if (parentPhone) {
        const userByPhone = await this.prisma.user.findUnique({ where: { phone: parentPhone } });
        if (userByPhone) {
          const profile = await this.prisma.profile.findFirst({
            where: { userId: userByPhone.id, role: { in: ["parent", "admin"] } },
          });
          if (profile?.familyId) {
            family = await this.prisma.family.findUnique({ where: { id: profile.familyId } });
          }
        }
      }
      if (!family) {
        const candidates = new Set<string>();
        const pseudoEmail = phoneToPseudoEmail(parentContactRaw);
        if (pseudoEmail) candidates.add(pseudoEmail);
        if (parentContactRaw.includes("@")) candidates.add(normalizeEmail(parentContactRaw));
        if (parentPhone) candidates.add(`${parentPhone}@phone.klany.local`);

        for (const candidate of candidates) {
          const user = await this.prisma.user.findUnique({ where: { email: candidate } });
          if (!user) continue;
          const profile = await this.prisma.profile.findFirst({
            where: { userId: user.id, role: { in: ["parent", "admin"] } },
          });
          if (!profile?.familyId) continue;
          family = await this.prisma.family.findUnique({ where: { id: profile.familyId } });
          if (family) break;
        }
      }
    }

    if (!family) throw new NotFoundException("Семья не найдена");
    const passwordHash = await bcrypt.hash(validatedPassword, 10);

    const row = await this.prisma.childAccessRequest.create({
      data: {
        familyId: family.id,
        firstName,
        lastName: null,
        phone: normalizedPhone,
        email: normalizedEmail,
        passwordHash,
        deviceId,
        deviceKey,
        status: "pending",
      },
    });

    await this.notifications.sendChildAccessRequested({
      familyId: family.id,
      childName: firstName,
    });

    return { requestId: row.id, status: row.status };
  }

  async pollAccessRequest(requestId: string, input: { deviceId: string; deviceKey: string }) {
    const deviceId = (input.deviceId ?? "").trim();
    const deviceKey = (input.deviceKey ?? "").trim();
    if (!deviceId || !deviceKey) throw new BadRequestException("deviceId/deviceKey обязательны");

    const req = await this.prisma.childAccessRequest.findUnique({ where: { id: requestId } });
    if (!req) throw new NotFoundException("Запрос не найден");
    if (req.deviceId !== deviceId || req.deviceKey !== deviceKey) {
      throw new ForbiddenException("Неверная привязка устройства");
    }

    if (req.status !== "approved") {
      return { status: req.status };
    }

    // Find most recent active session for this device binding/child.
    const session = await this.prisma.childSession.findFirst({
      where: {
        childId: req.childId ?? undefined,
        familyId: req.familyId,
        isActive: true,
        binding: { deviceId, deviceKey, isActive: true },
      },
      orderBy: { createdAt: "desc" },
    });

    if (!session || !req.childId) {
      return { status: "approved", ready: false };
    }

    const accessToken = this.auth.signChildJwt({
      familyId: req.familyId,
      childId: req.childId,
      sessionToken: session.token,
    });

    const child = await this.prisma.child.findUnique({ where: { id: req.childId } });
    const childDisplayName = child ? [child.firstName, child.lastName].filter(Boolean).join(" ").trim() : "";

    return {
      status: "approved",
      ready: true,
      accessToken,
      childId: req.childId,
      familyId: req.familyId,
      childDisplayName,
      avatarObjectKey: child?.avatarObjectKey ?? null,
    };
  }

  async restoreSession(input: { sessionToken?: string | null; deviceId: string; deviceKey: string }) {
    const token = (input.sessionToken ?? "").trim();
    const deviceId = (input.deviceId ?? "").trim();
    const deviceKey = (input.deviceKey ?? "").trim();
    if (!deviceId || !deviceKey) throw new BadRequestException("deviceId/deviceKey обязательны");

    const session = token
        ? await this.prisma.childSession.findUnique({
            where: { token },
            include: { binding: true },
          })
        : await this.prisma.childSession.findFirst({
            where: {
              isActive: true,
              binding: { isActive: true, deviceId, deviceKey },
            },
            include: { binding: true },
            orderBy: { createdAt: "desc" },
          });
    if (!session || session.isActive !== true) throw new ForbiddenException("Сессия недействительна");
    if (session.binding.isActive !== true) throw new ForbiddenException("Доступ устройства отозван");
    if (session.binding.deviceId !== deviceId || session.binding.deviceKey !== deviceKey) {
      throw new ForbiddenException("Устройство не совпадает");
    }

    const accessToken = this.auth.signChildJwt({
      familyId: session.familyId,
      childId: session.childId,
      sessionToken: session.token,
    });

    const child = await this.prisma.child.findUnique({ where: { id: session.childId } });
    const childDisplayName = child ? [child.firstName, child.lastName].filter(Boolean).join(" ").trim() : "";

    return {
      accessToken,
      childId: session.childId,
      familyId: session.familyId,
      childDisplayName,
      avatarObjectKey: child?.avatarObjectKey ?? null,
    };
  }

  async signInWithPassword(input: {
    login: string;
    password: string;
    deviceId: string;
    deviceKey: string;
  }) {
    const normalizePhone = (phone: string): string => {
      const digits = phone.replace(/\D/g, "");
      if (!digits) return "";
      if (digits.length === 11 && digits.startsWith("8")) return `7${digits.substring(1)}`;
      return digits;
    };
    const login = (input.login ?? "").trim().toLowerCase();
    const password = (input.password ?? "").trim();
    const deviceId = (input.deviceId ?? "").trim();
    const deviceKey = (input.deviceKey ?? "").trim();
    if (!login || !password) throw new BadRequestException("login/password обязательны");
    if (!deviceId || !deviceKey) throw new BadRequestException("deviceId/deviceKey обязательны");

    const normalizedPhone = normalizePhone(login);
    const child = await this.prisma.child.findFirst({
      where: login.includes("@")
        ? { email: login }
        : { phone: normalizedPhone },
    });
    if (!child || !child.passwordHash) {
      throw new ForbiddenException("Неверный логин или пароль");
    }
    if (!child.isActive) throw new ForbiddenException("Аккаунт ребёнка деактивирован");

    const ok = await bcrypt.compare(password, child.passwordHash);
    if (!ok) throw new ForbiddenException("Неверный логин или пароль");

    const result = await this.prisma.$transaction(async (tx) => {
      let binding = await tx.childDeviceBinding.findFirst({
        where: {
          familyId: child.familyId,
          childId: child.id,
          deviceId,
          deviceKey,
          isActive: true,
        },
      });

      if (!binding) {
        binding = await tx.childDeviceBinding.create({
          data: {
            familyId: child.familyId,
            childId: child.id,
            deviceId,
            deviceKey,
            isActive: true,
          },
        });
      }

      const session = await tx.childSession.create({
        data: {
          familyId: child.familyId,
          childId: child.id,
          bindingId: binding.id,
          token: randomUUID(),
          isActive: true,
        },
      });
      return { session };
    });

    const accessToken = this.auth.signChildJwt({
      familyId: child.familyId,
      childId: child.id,
      sessionToken: result.session.token,
    });

    return {
      accessToken,
      familyId: child.familyId,
      childId: child.id,
      childDisplayName: [child.firstName, child.lastName].filter(Boolean).join(" ").trim(),
      avatarObjectKey: child.avatarObjectKey ?? null,
    };
  }

  async signInWithAuthCode(input: { authCode: string; deviceId: string; deviceKey: string }) {
    const authCode = (input.authCode ?? "").trim();
    const deviceId = (input.deviceId ?? "").trim();
    const deviceKey = (input.deviceKey ?? "").trim();
    if (!/^\d{6}$/.test(authCode)) throw new BadRequestException("authCode должен состоять из 6 цифр");
    if (!deviceId || !deviceKey) throw new BadRequestException("deviceId/deviceKey обязательны");

    const child = await this.prisma.child.findFirst({ where: { authCode } });
    if (!child) throw new ForbiddenException("Неверный код");
    if (!child.isActive) throw new ForbiddenException("Аккаунт ребёнка деактивирован");

    const result = await this.prisma.$transaction(async (tx) => {
      let binding = await tx.childDeviceBinding.findFirst({
        where: {
          familyId: child.familyId,
          childId: child.id,
          deviceId,
          deviceKey,
          isActive: true,
        },
      });

      if (!binding) {
        binding = await tx.childDeviceBinding.create({
          data: {
            familyId: child.familyId,
            childId: child.id,
            deviceId,
            deviceKey,
            isActive: true,
          },
        });
      }

      const session = await tx.childSession.create({
        data: {
          familyId: child.familyId,
          childId: child.id,
          bindingId: binding.id,
          token: randomUUID(),
          isActive: true,
        },
      });
      return { session };
    });

    const accessToken = this.auth.signChildJwt({
      familyId: child.familyId,
      childId: child.id,
      sessionToken: result.session.token,
    });

    return {
      accessToken,
      familyId: child.familyId,
      childId: child.id,
      childDisplayName: [child.firstName, child.lastName].filter(Boolean).join(" ").trim(),
      avatarObjectKey: child.avatarObjectKey ?? null,
    };
  }

  async getMyAuthCode(user: ChildUser) {
    if (user.role !== "child") throw new ForbiddenException("Недостаточно прав");
    const child = await this.prisma.child.findUnique({ where: { id: user.childId } });
    if (!child || child.familyId !== user.familyId) throw new NotFoundException("Ребёнок не найден");
    if (child.authCode) return { authCode: child.authCode };

    for (let i = 0; i < 20; i += 1) {
      const authCode = generateChildAuthCode();
      try {
        const updated = await this.prisma.child.update({
          where: { id: child.id },
          data: { authCode },
        });
        return { authCode: updated.authCode };
      } catch (e: any) {
        if (e?.code === "P2002") continue;
        throw e;
      }
    }
    throw new BadRequestException("Не удалось сгенерировать код входа");
  }

  async setMyAvatar(user: ChildUser, objectKeyRaw: string) {
    if (user.role !== "child") throw new ForbiddenException("Недостаточно прав");
    const key = (objectKeyRaw ?? "").trim();
    if (!key) throw new BadRequestException("objectKey обязателен");
    const prefix = `avatars/families/${user.familyId}/children/${user.childId}/`;
    if (!key.startsWith(prefix)) {
      throw new BadRequestException("Некорректный objectKey");
    }
    await this.prisma.child.update({
      where: { id: user.childId },
      data: { avatarObjectKey: key },
    });
    return { ok: true, avatarObjectKey: key };
  }
}

