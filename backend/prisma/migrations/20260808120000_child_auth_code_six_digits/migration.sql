-- Все существующие 6-значные коды → 8 цифр с ведущими нулями (946231 → 00946231).
-- Новые коды генерируются сразу в 8-значном формате (child-auth-code.util.ts).

UPDATE "children"
SET "authCode" = LPAD("authCode", 8, '0')
WHERE "authCode" IS NOT NULL
  AND length("authCode") = 6
  AND "authCode" ~ '^[0-9]+$';

UPDATE "family_member_codes"
SET "code" = LPAD("code", 8, '0')
WHERE length("code") = 6
  AND "code" ~ '^[0-9]+$';
