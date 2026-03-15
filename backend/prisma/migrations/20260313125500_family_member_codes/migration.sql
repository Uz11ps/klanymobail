CREATE TABLE "family_member_codes" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "familyId" UUID NOT NULL,
  "code" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "displayName" TEXT NOT NULL,
  "userId" UUID,
  "childId" UUID,
  "createdAt" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "family_member_codes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "family_member_codes_code_key" ON "family_member_codes"("code");
CREATE INDEX "family_member_codes_familyId_idx" ON "family_member_codes"("familyId");

ALTER TABLE "family_member_codes"
ADD CONSTRAINT "family_member_codes_familyId_fkey"
FOREIGN KEY ("familyId") REFERENCES "families"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;
