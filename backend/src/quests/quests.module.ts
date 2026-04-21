import { Module } from "@nestjs/common";

import { NotificationsModule } from "../notifications/notifications.module";
import { QuestsController } from "./quests.controller";
import { QuestsService } from "./quests.service";

@Module({
  imports: [NotificationsModule],
  controllers: [QuestsController],
  providers: [QuestsService],
})
export class QuestsModule {}

