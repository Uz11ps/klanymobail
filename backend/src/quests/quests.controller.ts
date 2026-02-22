import { Body, Controller, Get, Post, Req, UseGuards } from "@nestjs/common";
import { AuthGuard } from "@nestjs/passport";

import { Roles } from "../auth/roles/roles.decorator";
import { RolesGuard } from "../auth/roles/roles.guard";
import { QuestsService } from "./quests.service";

@Controller()
@UseGuards(AuthGuard("jwt"), RolesGuard)
export class QuestsController {
  constructor(private readonly quests: QuestsService) {}

  @Get("family/children")
  @Roles("parent", "admin")
  async familyChildren(@Req() req: any) {
    return this.quests.listFamilyChildren(req.user);
  }

  @Post("quests")
  @Roles("parent", "admin")
  async create(@Req() req: any, @Body() body: {
    title: string;
    description?: string;
    rewardAmount: number;
    questType: string;
    dueAt?: string | null;
    childIds: string[];
  }) {
    return this.quests.createQuest(req.user, body);
  }

  @Get("quests/parent")
  @Roles("parent", "admin")
  async parentList(@Req() req: any) {
    return this.quests.listParentQuests(req.user);
  }

  @Get("quests/child")
  @Roles("child")
  async childAssignments(@Req() req: any) {
    return this.quests.listChildAssignments(req.user);
  }

  @Post("quests/child/submit")
  @Roles("child")
  async submit(@Req() req: any, @Body() body: { questId: string; evidenceKey?: string | null }) {
    return this.quests.submit(req.user, body.questId, body.evidenceKey ?? null);
  }

  @Get("quests/review")
  @Roles("parent", "admin")
  async reviewList(@Req() req: any) {
    return this.quests.listSubmittedForReview(req.user);
  }

  @Post("quests/review")
  @Roles("parent", "admin")
  async review(@Req() req: any, @Body() body: { questId: string; childId: string; approve: boolean; comment?: string | null }) {
    return this.quests.review(req.user, body);
  }
}

