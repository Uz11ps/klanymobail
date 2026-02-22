#!/bin/sh
set -e

if [ -n "${DATABASE_URL:-}" ]; then
  # Ensure DB schema is applied in prod-like runs.
  npx prisma migrate deploy
fi

if [ -n "${ADMIN_SEED_EMAIL:-}" ] && [ -n "${ADMIN_SEED_PASSWORD:-}" ]; then
  # Idempotent: creates/updates admin user for first login.
  node dist/scripts/seed-admin.js
fi

node dist/main.js

