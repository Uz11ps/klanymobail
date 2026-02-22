import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module";
import { ChildController } from "./child.controller";
import { ChildService } from "./child.service";

@Module({
  imports: [AuthModule],
  controllers: [ChildController],
  providers: [ChildService],
  exports: [ChildService],
})
export class ChildModule {}

