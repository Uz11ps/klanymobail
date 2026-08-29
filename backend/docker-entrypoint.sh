#!/bin/sh
set -e

if [ -n "${DATABASE_URL:-}" ]; then
  # Compose healthcheck can pass a hair earlier than Prisma accepts TCP; retry briefly.
  attempt=0
  until npx prisma migrate deploy; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 45 ]; then
      echo "prisma migrate deploy: postgres unreachable after ${attempt} attempts" >&2
      exit 1
    fi
    echo "waiting for postgres (migrate retry ${attempt})..."
    sleep 2
  done
fi

if [ -n "${ADMIN_SEED_EMAIL:-}" ] && [ -n "${ADMIN_SEED_PASSWORD:-}" ]; then
  # Idempotent: creates/updates admin user for first login.
  node dist/scripts/seed-admin.js
fi

node dist/main.js

