import { Body, Controller, Get, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { SubscriptionsService } from "./subscriptions.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class SubscriptionsController {
  constructor(private readonly subs: SubscriptionsService) {}

  @Get("subscriptions")
  @Roles("parent", "admin")
  async list(@Req() req: any) {
    return this.subs.listFamilySubscriptions(req.user);
  }

  @Post("subscriptions/promo/activate")
  @Roles("parent", "admin")
  async activatePromo(@Req() req: any, @Body() body: { code: string }) {
    return this.subs.activatePromo(req.user, body.code);
  }
}

