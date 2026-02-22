-- CreateEnum
CREATE TYPE "ProfileRole" AS ENUM ('admin', 'parent', 'child');

-- CreateEnum
CREATE TYPE "ChildAccessRequestStatus" AS ENUM ('pending', 'approved', 'rejected');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('active', 'canceled', 'expired');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('created', 'pending', 'paid', 'canceled', 'failed');

-- CreateTable
CREATE TABLE "families" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ownerUserId" UUID,
    "familyCode" TEXT NOT NULL,
    "clanName" TEXT,

    CONSTRAINT "families_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "profiles" (
    "userId" UUID NOT NULL,
    "familyId" UUID,
    "role" "ProfileRole" NOT NULL DEFAULT 'parent',
    "displayName" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "children" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deactivatedAt" TIMESTAMPTZ(6),

    CONSTRAINT "children_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_access_requests" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT,
    "deviceId" TEXT NOT NULL,
    "deviceKey" TEXT NOT NULL,
    "status" "ChildAccessRequestStatus" NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decidedAt" TIMESTAMPTZ(6),
    "decidedBy" UUID,
    "childId" UUID,

    CONSTRAINT "child_access_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_device_bindings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "deviceId" TEXT NOT NULL,
    "deviceKey" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMPTZ(6),
    "revokedBy" UUID,

    CONSTRAINT "child_device_bindings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quests" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "createdBy" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "reward" INTEGER NOT NULL DEFAULT 0,
    "questType" TEXT NOT NULL DEFAULT 'one_time',
    "status" TEXT NOT NULL DEFAULT 'active',
    "startedAt" TIMESTAMPTZ(6),
    "closedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quest_assignees" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "questId" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'assigned',
    "submittedAt" TIMESTAMPTZ(6),

    CONSTRAINT "quest_assignees_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quest_comments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "questId" UUID NOT NULL,
    "authorUserId" UUID,
    "message" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quest_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quest_evidences" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "questId" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "objectKey" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quest_evidences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "balance" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "wallets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallet_transactions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "walletId" UUID NOT NULL,
    "amount" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "meta" JSONB,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallet_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shop_products" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "price" INTEGER NOT NULL,
    "imageKey" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shop_products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shop_purchases" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "productId" UUID NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "frozenAmount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "decidedAt" TIMESTAMPTZ(6),
    "decidedBy" UUID,

    CONSTRAINT "shop_purchases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscription_plans" (
    "code" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "priceRub" INTEGER NOT NULL,
    "limits" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "subscription_plans_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "family_subscriptions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "planCode" TEXT NOT NULL,
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'active',
    "startedAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMPTZ(6),
    "source" TEXT,

    CONSTRAINT "family_subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "promo_codes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" TEXT NOT NULL,
    "planCode" TEXT NOT NULL,
    "durationDays" INTEGER NOT NULL DEFAULT 30,
    "maxUses" INTEGER NOT NULL DEFAULT 1,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "promo_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "promo_redemptions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "promoId" UUID NOT NULL,
    "familyId" UUID NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "promo_redemptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_orders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "planCode" TEXT,
    "amountRub" INTEGER NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'created',
    "providerPaymentId" TEXT,
    "payload" JSONB,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "paidAt" TIMESTAMPTZ(6),

    CONSTRAINT "payment_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_webhook_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "provider" TEXT NOT NULL,
    "eventType" TEXT NOT NULL,
    "eventId" TEXT,
    "payload" JSONB NOT NULL,
    "processed" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notification_devices" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID,
    "familyId" UUID,
    "platform" TEXT NOT NULL,
    "pushToken" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID,
    "toUserId" UUID,
    "nType" TEXT NOT NULL,
    "payload" JSONB,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "readAt" TIMESTAMPTZ(6),

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID,
    "actorUserId" UUID,
    "action" TEXT NOT NULL,
    "payload" JSONB,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "telegram_links" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "telegramChatId" TEXT NOT NULL,
    "telegramUsername" TEXT,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "telegram_links_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "families_familyCode_key" ON "families"("familyCode");

-- CreateIndex
CREATE INDEX "profiles_familyId_idx" ON "profiles"("familyId");

-- CreateIndex
CREATE INDEX "children_familyId_idx" ON "children"("familyId");

-- CreateIndex
CREATE INDEX "child_access_requests_familyId_status_idx" ON "child_access_requests"("familyId", "status");

-- CreateIndex
CREATE INDEX "child_device_bindings_familyId_childId_idx" ON "child_device_bindings"("familyId", "childId");

-- CreateIndex
CREATE INDEX "child_device_bindings_deviceId_idx" ON "child_device_bindings"("deviceId");

-- CreateIndex
CREATE INDEX "quests_familyId_idx" ON "quests"("familyId");

-- CreateIndex
CREATE INDEX "quest_assignees_childId_idx" ON "quest_assignees"("childId");

-- CreateIndex
CREATE UNIQUE INDEX "quest_assignees_questId_childId_key" ON "quest_assignees"("questId", "childId");

-- CreateIndex
CREATE INDEX "quest_comments_questId_idx" ON "quest_comments"("questId");

-- CreateIndex
CREATE INDEX "quest_evidences_questId_idx" ON "quest_evidences"("questId");

-- CreateIndex
CREATE INDEX "quest_evidences_childId_idx" ON "quest_evidences"("childId");

-- CreateIndex
CREATE INDEX "wallets_familyId_idx" ON "wallets"("familyId");

-- CreateIndex
CREATE UNIQUE INDEX "wallets_childId_key" ON "wallets"("childId");

-- CreateIndex
CREATE INDEX "wallet_transactions_walletId_idx" ON "wallet_transactions"("walletId");

-- CreateIndex
CREATE INDEX "shop_products_familyId_isActive_idx" ON "shop_products"("familyId", "isActive");

-- CreateIndex
CREATE INDEX "shop_purchases_familyId_status_idx" ON "shop_purchases"("familyId", "status");

-- CreateIndex
CREATE INDEX "family_subscriptions_familyId_status_idx" ON "family_subscriptions"("familyId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "promo_codes_code_key" ON "promo_codes"("code");

-- CreateIndex
CREATE INDEX "promo_redemptions_familyId_idx" ON "promo_redemptions"("familyId");

-- CreateIndex
CREATE INDEX "payment_orders_familyId_status_idx" ON "payment_orders"("familyId", "status");

-- CreateIndex
CREATE INDEX "payment_webhook_events_provider_eventType_idx" ON "payment_webhook_events"("provider", "eventType");

-- CreateIndex
CREATE INDEX "notification_devices_familyId_idx" ON "notification_devices"("familyId");

-- CreateIndex
CREATE INDEX "notification_devices_userId_idx" ON "notification_devices"("userId");

-- CreateIndex
CREATE INDEX "notifications_toUserId_isRead_idx" ON "notifications"("toUserId", "isRead");

-- CreateIndex
CREATE INDEX "audit_logs_familyId_idx" ON "audit_logs"("familyId");

-- CreateIndex
CREATE UNIQUE INDEX "telegram_links_telegramChatId_key" ON "telegram_links"("telegramChatId");

-- CreateIndex
CREATE INDEX "telegram_links_familyId_idx" ON "telegram_links"("familyId");

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "children" ADD CONSTRAINT "children_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_access_requests" ADD CONSTRAINT "child_access_requests_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_device_bindings" ADD CONSTRAINT "child_device_bindings_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_device_bindings" ADD CONSTRAINT "child_device_bindings_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quests" ADD CONSTRAINT "quests_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quest_assignees" ADD CONSTRAINT "quest_assignees_questId_fkey" FOREIGN KEY ("questId") REFERENCES "quests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quest_assignees" ADD CONSTRAINT "quest_assignees_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quest_comments" ADD CONSTRAINT "quest_comments_questId_fkey" FOREIGN KEY ("questId") REFERENCES "quests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quest_evidences" ADD CONSTRAINT "quest_evidences_questId_fkey" FOREIGN KEY ("questId") REFERENCES "quests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_transactions" ADD CONSTRAINT "wallet_transactions_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "wallets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shop_products" ADD CONSTRAINT "shop_products_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shop_purchases" ADD CONSTRAINT "shop_purchases_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shop_purchases" ADD CONSTRAINT "shop_purchases_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shop_purchases" ADD CONSTRAINT "shop_purchases_productId_fkey" FOREIGN KEY ("productId") REFERENCES "shop_products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_subscriptions" ADD CONSTRAINT "family_subscriptions_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "family_subscriptions" ADD CONSTRAINT "family_subscriptions_planCode_fkey" FOREIGN KEY ("planCode") REFERENCES "subscription_plans"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promo_codes" ADD CONSTRAINT "promo_codes_planCode_fkey" FOREIGN KEY ("planCode") REFERENCES "subscription_plans"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promo_redemptions" ADD CONSTRAINT "promo_redemptions_promoId_fkey" FOREIGN KEY ("promoId") REFERENCES "promo_codes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "promo_redemptions" ADD CONSTRAINT "promo_redemptions_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payment_orders" ADD CONSTRAINT "payment_orders_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "telegram_links" ADD CONSTRAINT "telegram_links_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
