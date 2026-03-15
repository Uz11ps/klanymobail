import { Body, Controller, Get, Param, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { NotificationsService } from "./notifications.service";

@Controller()
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post("notifications/devices/register")
  @UseGuards(AuthGuard("jwt"), RolesGuard)
  @Roles("parent", "admin", "child")
  async registerDevice(
    @Req() req: any,
    @Body() body: { platform: string; pushToken: string },
  ) {
    return this.notifications.registerDevice(req.user, body);
  }

  @Get("notifications")
  @UseGuards(AuthGuard("jwt"), RolesGuard)
  @Roles("parent", "admin", "child")
  async list(@Req() req: any) {
    return this.notifications.list(req.user);
  }

  @Post("notifications/:id/read")
  @UseGuards(AuthGuard("jwt"), RolesGuard)
  @Roles("parent", "admin", "child")
  async markRead(@Req() req: any, @Param("id") id: string) {
    return this.notifications.markRead(req.user, id);
  }

  @Post("notifications/clear")
  @UseGuards(AuthGuard("jwt"), RolesGuard)
  @Roles("parent", "admin", "child")
  async clear(@Req() req: any) {
    return this.notifications.clear(req.user);
  }

  // Called by server scheduler/cron. Protected by shared secret header.
  @Post("internal/notifications-cron")
  async cron(@Req() req: any) {
    const secret = req.headers["x-cron-secret"]?.toString() ?? "";
    return this.notifications.runCron(secret);
  }

  @Post("internal/child-access-requested")
  async childAccessRequested(
    @Req() req: any,
    @Body() body: { familyId: string; childName: string },
  ) {
    const secret = req.headers["x-cron-secret"]?.toString() ?? "";
    const expected = process.env.CRON_SECRET ?? "";
    if (!expected || secret !== expected) return { ok: false };
    return this.notifications.sendChildAccessRequested(body);
  }

  // Health of integrations (Telegram + FCM). Protected by shared secret header.
  @Post("internal/integrations-health")
  async integrationsHealth(@Req() req: any) {
    const secret = req.headers["x-cron-secret"]?.toString() ?? "";
    const expected = process.env.CRON_SECRET ?? "";
    if (!expected || secret !== expected) return { ok: false };

    const telegramConfigured = (process.env.TELEGRAM_BOT_TOKEN ?? "").trim().length > 0;
    const fcm = await this.notifications.fcmHealth();
    return {
      ok: true,
      telegram: { configured: telegramConfigured },
      fcm,
    };
  }

  @Post("internal/notification-devices")
  async internalDevices(@Req() req: any, @Body() body: { familyId?: string; familyCode?: string }) {
    const secret = req.headers["x-cron-secret"]?.toString() ?? "";
    const expected = process.env.CRON_SECRET ?? "";
    if (!expected || secret !== expected) return { ok: false };
    const familyId = await this.notifications.resolveFamilyId(body);
    return this.notifications.listDevicesForFamily(familyId);
  }

  @Post("internal/push-test")
  async internalPushTest(
    @Req() req: any,
    @Body() body: { familyId?: string; familyCode?: string; title?: string; message?: string },
  ) {
    const secret = req.headers["x-cron-secret"]?.toString() ?? "";
    const expected = process.env.CRON_SECRET ?? "";
    if (!expected || secret !== expected) return { ok: false };
    const title = (body.title ?? "").trim() || "Тестовое уведомление";
    const msg = (body.message ?? "").trim() || "Если вы это видите — push работает.";
    const familyId = await this.notifications.resolveFamilyId(body);
    return this.notifications.pushTestToFamily(familyId, title, msg);
  }

  @Post("internal/telegram-test")
  async internalTelegramTest(
    @Req() req: any,
    @Body() body: { familyId?: string; familyCode?: string; message?: string },
  ) {
    const secret = req.headers["x-cron-secret"]?.toString() ?? "";
    const expected = process.env.CRON_SECRET ?? "";
    if (!expected || secret !== expected) return { ok: false };
    const msg = (body.message ?? "").trim() || "Тест: Telegram уведомления работают.";
    const familyId = await this.notifications.resolveFamilyId(body);
    return this.notifications.telegramTestToFamily(familyId, msg);
  }
}

