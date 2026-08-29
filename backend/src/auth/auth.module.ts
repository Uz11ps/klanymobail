import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { PassportModule } from "@nestjs/passport";

import { MailModule } from "../mail/mail.module";

import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { JwtStrategy } from "./jwt.strategy";
import { RolesGuard } from "./roles/roles.guard";

@Module({
  imports: [
    MailModule,
    PassportModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET ?? "dev_secret_change_me",
      signOptions: { expiresIn: "30d" },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, RolesGuard],
  exports: [AuthService, RolesGuard],
})
export class AuthModule {}

