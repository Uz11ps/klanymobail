-- CreateEnum
CREATE TYPE "AuthEmailTokenPurpose" AS ENUM ('password_reset', 'email_verification');

-- AlterTable
ALTER TABLE "users" ADD COLUMN "emailVerifiedAt" TIMESTAMPTZ(6);

-- CreateTable
CREATE TABLE "auth_email_tokens" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "userId" UUID NOT NULL,
    "purpose" "AuthEmailTokenPurpose" NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ(6) NOT NULL,
    "usedAt" TIMESTAMPTZ(6),
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_email_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "auth_email_tokens_tokenHash_key" ON "auth_email_tokens"("tokenHash");

-- CreateIndex
CREATE INDEX "auth_email_tokens_userId_purpose_idx" ON "auth_email_tokens"("userId", "purpose");

-- AddForeignKey
ALTER TABLE "auth_email_tokens" ADD CONSTRAINT "auth_email_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Уже зарегистрированные пользователи считаются подтверждёнными.
UPDATE "users"
SET "emailVerifiedAt" = NOW()
WHERE "emailVerifiedAt" IS NULL
  AND "email" NOT LIKE '%@phone.klany.local'
  AND "email" NOT LIKE '%@member.klany.local';
