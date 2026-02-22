import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";

import { ChildService } from "./child.service";

@Controller()
export class ChildController {
  constructor(private readonly child: ChildService) {}

  @Post("child/access-request")
  async submitAccessRequest(
    @Body() body: { familyCode: string; firstName: string; lastName?: string; deviceId: string; deviceKey: string },
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
}

