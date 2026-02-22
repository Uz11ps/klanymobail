import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req } from "@nestjs/common";

import { AuthService } from "./auth.service";
import { AuthGuardJwt } from "./guards/auth-guard-jwt";

type SignUpBody = {
  email: string;
  password: string;
  displayName?: string;
};

type SignInBody = {
  email: string;
  password: string;
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

  @Get("me")
  @AuthGuardJwt()
  async me(@Req() req: any) {
    return { user: req.user };
  }
}

