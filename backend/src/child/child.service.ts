import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";

import { AuthService } from "../auth/auth.service";
import { PrismaService } from "../prisma/prisma.service";

@Injectable()
export class ChildService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
  ) {}

  async submitAccessRequest(input: {
    familyCode: string;
    firstName: string;
    lastName?: string;
    deviceId: string;
    deviceKey: string;
  }) {
    const familyCode = (input.familyCode ?? "").trim().toUpperCase();
    const firstName = (input.firstName ?? "").trim();
    const lastName = (input.lastName ?? "").trim();
    const deviceId = (input.deviceId ?? "").trim();
    const deviceKey = (input.deviceKey ?? "").trim();

    if (!familyCode) throw new BadRequestException("familyCode обязателен");
    if (!firstName) throw new BadRequestException("firstName обязателен");
    if (!deviceId || !deviceKey) throw new BadRequestException("deviceId/deviceKey обязательны");

    const family = await this.prisma.family.findUnique({ where: { familyCode } });
    if (!family) throw new NotFoundException("Family ID не найден");

    const row = await this.prisma.childAccessRequest.create({
      data: {
        familyId: family.id,
        firstName,
        lastName: lastName || null,
        deviceId,
        deviceKey,
        status: "pending",
      },
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

    return { accessToken, childId: session.childId, familyId: session.familyId, childDisplayName };
  }
}

