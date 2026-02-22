import { Injectable, UnauthorizedException } from "@nestjs/common";
import { PassportStrategy } from "@nestjs/passport";
import { ExtractJwt, Strategy } from "passport-jwt";

import { PrismaService } from "../prisma/prisma.service";

type JwtPayload = {
  sub: string;
  role: "admin" | "parent" | "child";
  familyId?: string | null;
  childId?: string | null;
  sessionToken?: string | null;
};

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_SECRET ?? "dev_secret_change_me",
    });
  }

  async validate(payload: JwtPayload) {
    if (!payload?.role) throw new UnauthorizedException("Invalid token");

    if (payload.role === "child") {
      // For child tokens we validate server-side session, so revoke is possible.
      const token = payload.sessionToken ?? "";
      if (!token) throw new UnauthorizedException("Invalid child token");

      const session = await this.prisma.childSession.findUnique({
        where: { token },
        include: { binding: true },
      });
      if (!session || session.isActive !== true) throw new UnauthorizedException("Session revoked");
      if (session.binding.isActive !== true) throw new UnauthorizedException("Device revoked");

      return {
        role: "child",
        familyId: session.familyId,
        childId: session.childId,
        sessionToken: session.token,
      };
    }

    // parent/admin tokens: validate user exists + profile still present
    const userId = payload.sub;
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException("User not found");

    const profile = await this.prisma.profile.findFirst({ where: { userId } });
    if (!profile) throw new UnauthorizedException("Profile not found");

    return {
      userId,
      email: user.email,
      role: profile.role,
      familyId: profile.familyId,
    };
  }
}

