import { Body, Controller, Get, HttpCode, HttpStatus, Post, Query, Req, Res } from "@nestjs/common";
import type { Response } from "express";

import {
  verifyEmailErrorPageHtml,
  verifyEmailSuccessPageHtml,
} from "../mail/auth-mail.templates";

import { AuthService } from "./auth.service";
import { AuthGuardJwt } from "./guards/auth-guard-jwt";

type SignUpBody = {
  email?: string;
  phone?: string;
  password: string;
  displayName?: string;
  recoveryEmail?: string;
};

type SignInBody = {
  email?: string;
  phone?: string;
  login?: string;
  password: string;
};

type SignInCodeBody = {
  code: string;
};

type AcceptInviteBody = {
  inviteToken: string;
};

type RecoverBody = {
  phone?: string;
};

type ForgotPasswordBody = {
  email: string;
};

type ResetPasswordBody = {
  email?: string;
  code?: string;
  /** Устаревшие письма со ссылкой — по возможности вводите код в приложении. */
  token?: string;
  password: string;
};

type VerifyEmailBody = {
  token: string;
};

type ResendVerificationBody = {
  email: string;
};

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @HttpCode(HttpStatus.OK)
  @Get("auth/parent-email-registered")
  async parentEmailRegistered(@Query("email") email?: string) {
    return this.auth.isParentEmailRegistered(email ?? "");
  }

  @Post("auth/sign-up")
  async signUp(@Body() body: SignUpBody) {
    return this.auth.signUpParent(body);
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/sign-in")
  async signIn(@Body() body: SignInBody) {
    return this.auth.signInWithPassword(body);
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/sign-in-code")
  async signInCode(@Body() body: SignInCodeBody) {
    return this.auth.signInWithFamilyCode(body);
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/recover")
  async recover(@Body() body: RecoverBody) {
    return this.auth.requestRecovery(body);
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/forgot-password")
  async forgotPassword(@Body() body: ForgotPasswordBody) {
    return this.auth.requestPasswordReset(body);
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/reset-password")
  async resetPassword(@Body() body: ResetPasswordBody) {
    return this.auth.resetPassword(body);
  }

  /** Ссылка из письма Resend — без экрана в приложении, только HTML в браузере. */
  @Get("auth/verify-email")
  async verifyEmailLink(@Query("token") token: string | undefined, @Res() res: Response) {
    try {
      await this.auth.verifyEmail({ token: token ?? "" });
      res.status(200).type("text/html; charset=utf-8").send(verifyEmailSuccessPageHtml());
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Ссылка недействительна";
      res.status(400).type("text/html; charset=utf-8").send(verifyEmailErrorPageHtml(msg));
    }
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/verify-email")
  async verifyEmail(@Body() body: VerifyEmailBody) {
    return this.auth.verifyEmail(body);
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/resend-verification")
  async resendVerification(@Body() body: ResendVerificationBody) {
    return this.auth.resendVerificationEmail(body);
  }

  @Get("me")
  @AuthGuardJwt()
  async me(@Req() req: any) {
    return { user: req.user };
  }

  @HttpCode(HttpStatus.OK)
  @Post("auth/accept-invite")
  @AuthGuardJwt()
  async acceptInvite(@Req() req: any, @Body() body: AcceptInviteBody) {
    return this.auth.acceptParentInvite(req.user.userId, body);
  }
}

