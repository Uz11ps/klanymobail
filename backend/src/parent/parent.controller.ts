import { Reflector } from "@nestjs/core";
import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";
import { AuthGuardJwt } from "../auth/guards/auth-guard-jwt";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { ParentService } from "./parent.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class ParentController {
  constructor(private readonly parent: ParentService) {}

  @Get("family/context")
  @Roles("parent", "admin")
  async familyContext(@Req() req: any) {
    return this.parent.getFamilyContext(req.user);
  }

  @Post("family/goal")
  @Roles("parent", "admin")
  async setFamilyGoal(@Req() req: any, @Body() body: { goalAmount: number; goalName?: string }) {
    return this.parent.setFamilyGoal(req.user, body.goalAmount, body.goalName);
  }

  @Post("family/coin-rate")
  @Roles("parent", "admin")
  async setFamilyCoinRate(@Req() req: any, @Body() body: { rublesPer10Coins: number }) {
    return this.parent.setFamilyCoinRate(req.user, body.rublesPer10Coins);
  }

  @Post("family/global-tax")
  @Roles("parent", "admin")
  async setFamilyGlobalTaxRate(@Req() req: any, @Body() body: { taxRate: number }) {
    return this.parent.setFamilyGlobalTaxRate(req.user, body.taxRate);
  }

  @Get("parent/access-requests")
  @Roles("parent", "admin")
  async accessRequests(@Req() req: any) {
    return this.parent.listAccessRequests(req.user);
  }

  @Post("parent/access-requests/:id/approve")
  @Roles("parent", "admin")
  async approve(@Req() req: any, @Param("id") id: string) {
    return this.parent.approveAccessRequest(req.user, id);
  }

  @Post("parent/access-requests/:id/reject")
  @Roles("parent", "admin")
  async reject(@Req() req: any, @Param("id") id: string, @Body() body: { reason?: string }) {
    return this.parent.rejectAccessRequest(req.user, id, body?.reason ?? null);
  }

  @Patch("parent/me/profile")
  @Roles("parent", "admin")
  async updateMyProfile(@Req() req: any, @Body() body: { displayName?: string }) {
    return this.parent.updateMyProfile(req.user, body);
  }

  @Patch("parent/me/avatar")
  @Roles("parent", "admin")
  async setMyAvatar(@Req() req: any, @Body() body: { objectKey?: string }) {
    return this.parent.setMyAvatar(req.user, body?.objectKey ?? "");
  }

  @Get("parent/members")
  @Roles("parent", "admin")
  async members(@Req() req: any) {
    return this.parent.listParentMembers(req.user);
  }

  @Get("parent/children")
  @Roles("parent", "admin")
  async children(@Req() req: any) {
    return this.parent.listChildren(req.user);
  }

  @Get("parent/member-codes")
  @Roles("parent", "admin")
  async memberCodes(@Req() req: any) {
    return this.parent.listFamilyMemberCodes(req.user);
  }

  @Post("parent/member-codes")
  @Roles("parent", "admin")
  async createMemberCode(
    @Req() req: any,
    @Body() body: { memberType?: string; role?: string; displayName: string },
  ) {
    return this.parent.createFamilyMemberCode(req.user, body);
  }

  @Patch("parent/member-codes/:id/avatar")
  @Roles("parent", "admin")
  async setMemberCodeAvatar(
    @Req() req: any,
    @Param("id") id: string,
    @Body() body: { objectKey: string },
  ) {
    return this.parent.setMemberCodeAvatar(req.user, id, body?.objectKey ?? "");
  }

  @Post("parent/member-codes/:id/regenerate")
  @Roles("parent", "admin")
  async regenerateMemberCode(@Req() req: any, @Param("id") id: string) {
    return this.parent.regenerateFamilyMemberCode(req.user, id);
  }

  @Post("parent/member-codes/:id/deactivate")
  @Roles("parent", "admin")
  async deactivateMemberCode(@Req() req: any, @Param("id") id: string) {
    return this.parent.deactivateFamilyMemberCode(req.user, id);
  }

  @Delete("parent/member-codes/:id")
  @Roles("parent", "admin")
  async deleteMemberCode(@Req() req: any, @Param("id") id: string) {
    return this.parent.deleteFamilyMemberCode(req.user, id);
  }

  @Get("parent/children/:childId/profile")
  @Roles("parent", "admin")
  async childProfile(@Req() req: any, @Param("childId") childId: string) {
    return this.parent.getChildProfile(req.user, childId);
  }

  @Get("parent/analytics")
  @Roles("parent", "admin")
  async analytics(@Req() req: any) {
    const periodDaysRaw = Number(req.query?.periodDays ?? 30);
    return this.parent.getFamilyAnalytics(req.user, periodDaysRaw);
  }

  @Post("parent/grant-admin")
  @Roles("admin")
  async grantAdmin(@Req() req: any, @Body() body: { targetUserId: string }) {
    return this.parent.grantAdmin(req.user, body.targetUserId);
  }

  @Post("parent/children/:childId/revoke-devices")
  @Roles("parent", "admin")
  async revokeDevices(@Req() req: any, @Param("childId") childId: string) {
    return this.parent.revokeChildDevices(req.user, childId);
  }

  @Post("parent/children/:childId/deactivate")
  @Roles("parent", "admin")
  async deactivate(@Req() req: any, @Param("childId") childId: string) {
    return this.parent.deactivateChild(req.user, childId);
  }

  @Delete("parent/children/:childId")
  @Roles("parent", "admin")
  async deleteChild(@Req() req: any, @Param("childId") childId: string) {
    return this.parent.deleteChild(req.user, childId);
  }

  @Patch("parent/children/:childId")
  @Roles("parent", "admin")
  async updateChild(
    @Req() req: any,
    @Param("childId") childId: string,
    @Body() body: { firstName?: string; lastName?: string | null; isActive?: boolean },
  ) {
    return this.parent.updateChild(req.user, childId, body);
  }
}

