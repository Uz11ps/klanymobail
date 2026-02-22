-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastLoginAt" TIMESTAMPTZ(6),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "familyId" UUID NOT NULL,
    "childId" UUID NOT NULL,
    "bindingId" UUID NOT NULL,
    "token" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMPTZ(6),
    "revokedBy" UUID,

    CONSTRAINT "child_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "child_sessions_token_key" ON "child_sessions"("token");

-- CreateIndex
CREATE INDEX "child_sessions_familyId_childId_isActive_idx" ON "child_sessions"("familyId", "childId", "isActive");

-- AddForeignKey
ALTER TABLE "families" ADD CONSTRAINT "families_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "profiles" ADD CONSTRAINT "profiles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_sessions" ADD CONSTRAINT "child_sessions_familyId_fkey" FOREIGN KEY ("familyId") REFERENCES "families"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_sessions" ADD CONSTRAINT "child_sessions_childId_fkey" FOREIGN KEY ("childId") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "child_sessions" ADD CONSTRAINT "child_sessions_bindingId_fkey" FOREIGN KEY ("bindingId") REFERENCES "child_device_bindings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
