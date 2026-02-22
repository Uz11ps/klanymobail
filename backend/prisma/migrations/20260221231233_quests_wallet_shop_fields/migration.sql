-- AlterTable
ALTER TABLE "quest_assignees" ADD COLUMN     "comment" TEXT,
ADD COLUMN     "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "rewardAmount" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "quests" ADD COLUMN     "dueAt" TIMESTAMPTZ(6);

-- AlterTable
ALTER TABLE "shop_purchases" ADD COLUMN     "quantity" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "totalPrice" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "wallet_transactions" ADD COLUMN     "note" TEXT,
ADD COLUMN     "txType" TEXT NOT NULL DEFAULT 'adjustment';
