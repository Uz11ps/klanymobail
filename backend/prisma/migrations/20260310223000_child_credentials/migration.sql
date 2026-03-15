-- Add child credential fields and keep them unique when provided.
ALTER TABLE "children"
ADD COLUMN "phone" TEXT,
ADD COLUMN "email" TEXT,
ADD COLUMN "passwordHash" TEXT;

CREATE UNIQUE INDEX "children_phone_unique" ON "children"("phone");
CREATE UNIQUE INDEX "children_email_unique" ON "children"("email");

ALTER TABLE "child_access_requests"
ADD COLUMN "phone" TEXT,
ADD COLUMN "email" TEXT,
ADD COLUMN "passwordHash" TEXT;
