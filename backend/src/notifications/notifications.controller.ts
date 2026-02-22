import { Body, Controller, Get, Param, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { NotificationsService } from "./notifications.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post("notifications/devices/register")
  @Roles("parent", "admin", "child")
  async registerDevice(
    @Req() req: any,
    @Body() body: { platform: string; pushToken: string },
  ) {
    return this.notifications.registerDevice(req.user, body);
  }

  @Get("notifications")
  @Roles("parent", "admin", "child")
  async list(@Req() req: any) {
    return this.notifications.list(req.user);
  }

  @Post("notifications/:id/read")
  @Roles("parent", "admin", "child")
  async markRead(@Req() req: any, @Param("id") id: string) {
    return this.notifications.markRead(req.user, id);
  }

  // Called by server scheduler/cron. Protected by shared secret header.
  @Post("internal/notifications-cron")
  async cron(@Req() req: any) {
    const secret = req.headers["x-cron-secret"]?.toString() ?? "";
    return this.notifications.runCron(secret);
  }
}

