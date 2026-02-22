import { Body, Controller, Get, Param, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

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
}

