import { Module } from "@nestjs/common";

import { AppController } from "./app.controller";
import { AuthModule } from "./auth/auth.module";
import { AdminModule } from "./admin/admin.module";
import { ChildModule } from "./child/child.module";
import { NotificationsModule } from "./notifications/notifications.module";
import { PaymentsModule } from "./payments/payments.module";
import { ParentModule } from "./parent/parent.module";
import { PrismaModule } from "./prisma/prisma.module";
import { QuestsModule } from "./quests/quests.module";
import { ShopModule } from "./shop/shop.module";
import { StorageModule } from "./storage/storage.module";
import { SubscriptionsModule } from "./subscriptions/subscriptions.module";
import { WalletModule } from "./wallet/wallet.module";
import { WebhooksModule } from "./webhooks/webhooks.module";

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    AdminModule,
    ParentModule,
    ChildModule,
    PaymentsModule,
    SubscriptionsModule,
    NotificationsModule,
    WebhooksModule,
    WalletModule,
    ShopModule,
    QuestsModule,
    StorageModule,
  ],
  controllers: [AppController],
})
export class AppModule {}

