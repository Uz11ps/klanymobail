import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from "@nestjs/common";
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
    childIds?: string[];
    distributionType?: "assigned" | "exchange";
    autoApprove?: boolean;
    timeLimitMinutes?: number | null;
    scheduleType?: "none" | "daily" | "weekly" | "custom_days";
    scheduleDays?: string[] | null;
  }) {
    return this.quests.createQuest(req.user, body);
  }

  @Patch("quests/:id")
  @Roles("parent", "admin")
  async update(
    @Req() req: any,
    @Param("id") id: string,
    @Body() body: {
      title?: string;
      description?: string | null;
      rewardAmount?: number;
      status?: string;
      questType?: string;
      dueAt?: string | null;
      childIds?: string[];
      distributionType?: "assigned" | "exchange" | "reverse";
      autoApprove?: boolean;
      timeLimitMinutes?: number | null;
      scheduleType?: "none" | "daily" | "weekly" | "custom_days";
      scheduleDays?: string[] | null;
    },
  ) {
    return this.quests.updateQuest(req.user, id, body);
  }

  @Delete("quests/:id")
  @Roles("parent", "admin")
  async delete(@Req() req: any, @Param("id") id: string) {
    return this.quests.deleteQuest(req.user, id);
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

  @Post("quests/child/take")
  @Roles("child")
  async takeFromMarket(@Req() req: any, @Body() body: { questId: string }) {
    return this.quests.takeFromMarket(req.user, body.questId);
  }

  @Post("quests/child/submit")
  @Roles("child")
  async submit(@Req() req: any, @Body() body: { questId: string; evidenceKey?: string | null }) {
    return this.quests.submit(req.user, body.questId, body.evidenceKey ?? null);
  }

  @Get("quests/child/reverse")
  @Roles("child")
  async childReverseGet(@Req() req: any) {
    return this.quests.getReverseQuestForChild(req.user);
  }

  @Post("quests/child/reverse")
  @Roles("child")
  async childReverseCreate(
    @Req() req: any,
    @Body() body: { title: string; rewardAmount: number; description?: string },
  ) {
    return this.quests.createReverseQuest(req.user, body);
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

