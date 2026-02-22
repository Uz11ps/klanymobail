import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";

import { AdminService } from "./admin.service";

type AdminUser = {
  userId: string;
  role: "admin";
};

type CreatePromoBody = {
  code: string;
  planCode: string;
  durationDays: number;
  maxUses: number;
};

type DecidePurchaseBody = {
  approve: boolean;
};

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get("admin/families")
  @Roles("admin")
  families() {
    return this.admin.families();
  }

  @Get("admin/profiles")
  @Roles("admin")
  profiles() {
    return this.admin.profiles();
  }

  @Get("admin/children")
  @Roles("admin")
  children() {
    return this.admin.children();
  }

  @Get("admin/quests")
  @Roles("admin")
  quests() {
    return this.admin.quests();
  }

  @Get("admin/products")
  @Roles("admin")
  products() {
    return this.admin.products();
  }

  @Get("admin/purchases")
  @Roles("admin")
  purchases() {
    return this.admin.purchases();
  }

  @Get("admin/subscriptions")
  @Roles("admin")
  subscriptions() {
    return this.admin.subscriptions();
  }

  @Get("admin/promocodes")
  @Roles("admin")
  promocodes() {
    return this.admin.promocodes();
  }

  @Get("admin/payments")
  @Roles("admin")
  payments() {
    return this.admin.payments();
  }

  @Get("admin/notifications")
  @Roles("admin")
  notifications() {
    return this.admin.notifications();
  }

  @Get("admin/audit")
  @Roles("admin")
  audit() {
    return this.admin.audit();
  }

  @Get("admin/access-requests")
  @Roles("admin")
  accessRequests(@Query("status") status?: string) {
    return this.admin.accessRequests(status);
  }

  @Post("admin/promocodes")
  @Roles("admin")
  @HttpCode(HttpStatus.OK)
  createPromo(@Body() body: CreatePromoBody, @Req() req: any) {
    return this.admin.createPromo(req.user as AdminUser, body);
  }

  @Post("admin/access-requests/:id/approve")
  @Roles("admin")
  @HttpCode(HttpStatus.OK)
  approveRequest(@Param("id") id: string, @Req() req: any) {
    return this.admin.approveAccessRequest(req.user as AdminUser, id);
  }

  @Post("admin/access-requests/:id/reject")
  @Roles("admin")
  @HttpCode(HttpStatus.OK)
  rejectRequest(@Param("id") id: string, @Req() req: any) {
    return this.admin.rejectAccessRequest(req.user as AdminUser, id);
  }

  @Post("admin/children/:id/deactivate")
  @Roles("admin")
  @HttpCode(HttpStatus.OK)
  deactivateChild(@Param("id") id: string, @Req() req: any) {
    return this.admin.deactivateChild(req.user as AdminUser, id);
  }

  @Post("admin/purchases/:id/decide")
  @Roles("admin")
  @HttpCode(HttpStatus.OK)
  decidePurchase(@Param("id") id: string, @Body() body: DecidePurchaseBody, @Req() req: any) {
    return this.admin.decidePurchase(req.user as AdminUser, id, body?.approve === true);
  }
}

