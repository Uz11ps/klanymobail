import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req } from "@nestjs/common";

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
  phone: string;
};

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

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

