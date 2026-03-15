import { Body, Controller, Get, Param, Post, Query, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { ChildService } from "./child.service";

@Controller()
export class ChildController {
  constructor(private readonly child: ChildService) {}

  @Post("child/access-request")
  async submitAccessRequest(
    @Body() body: {
      phone: string;
      email: string;
      firstName: string;
      password: string;
      familyCode?: string;
      parentContact?: string;
      deviceId: string;
      deviceKey: string;
    },
  ) {
    return this.child.submitAccessRequest(body);
  }

  @Get("child/access-request/:id/poll")
  async poll(
    @Param("id") id: string,
    @Query("deviceId") deviceId: string,
    @Query("deviceKey") deviceKey: string,
  ) {
    return this.child.pollAccessRequest(id, { deviceId, deviceKey });
  }

  @Post("child/restore-session")
  async restore(
    @Body() body: { sessionToken?: string | null; deviceId: string; deviceKey: string },
  ) {
    return this.child.restoreSession(body);
  }

  @Post("child/sign-in")
  async signIn(
    @Body() body: { login: string; password: string; deviceId: string; deviceKey: string },
  ) {
    return this.child.signInWithPassword(body);
  }

  @Post("child/sign-in-code")
  async signInCode(
    @Body() body: { authCode: string; deviceId: string; deviceKey: string },
  ) {
    return this.child.signInWithAuthCode(body);
  }

  @Get("child/me/auth-code")
  @UseGuards(AuthGuard("jwt"), RolesGuard)
  @Roles("child")
  async myAuthCode(@Req() req: any) {
    return this.child.getMyAuthCode(req.user);
  }
}

