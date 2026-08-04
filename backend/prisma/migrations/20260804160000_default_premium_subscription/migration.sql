INSERT INTO "subscription_plans" ("code", "title", "priceRub", "isActive")
VALUES
  ('basic', 'Базовый', 0, true),
  ('premium', 'Премиум', 0, true)
ON CONFLICT ("code") DO NOTHING;

INSERT INTO "family_subscriptions" ("familyId", "planCode", "status", "startedAt", "expiresAt", "source")
SELECT f."id", 'premium', 'active', NOW(), NULL, 'backfill'
FROM "families" f
WHERE NOT EXISTS (
  SELECT 1
  FROM "family_subscriptions" fs
  WHERE fs."familyId" = f."id"
    AND fs."status" = 'active'
    AND LOWER(fs."planCode") LIKE '%premium%'
);
