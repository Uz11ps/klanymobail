import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module";
import { NotificationsModule } from "../notifications/notifications.module";
import { ChildController } from "./child.controller";
import { ChildService } from "./child.service";

@Module({
  imports: [AuthModule, NotificationsModule],
  controllers: [ChildController],
  providers: [ChildService],
  exports: [ChildService],
})
export class ChildModule {}

