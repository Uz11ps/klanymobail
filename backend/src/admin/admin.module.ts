import { Module } from "@nestjs/common";

import { ParentModule } from "../parent/parent.module";
import { PrismaModule } from "../prisma/prisma.module";
import { ShopModule } from "../shop/shop.module";

import { AdminController } from "./admin.controller";
import { AdminService } from "./admin.service";

@Module({
  imports: [PrismaModule, ParentModule, ShopModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}

