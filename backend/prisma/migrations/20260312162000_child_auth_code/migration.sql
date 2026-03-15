ALTER TABLE "children"
ADD COLUMN "authCode" TEXT;

CREATE UNIQUE INDEX "children_authCode_key" ON "children"("authCode");
