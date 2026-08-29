#!/usr/bin/env sh
# Generate a fresh .env with random secrets for a clean server deploy.
# Usage:
#   sh scripts/server/generate_fresh_env.sh [/opt/klanymobail/.env]
#   sh scripts/server/generate_fresh_env.sh /opt/klany/shared/.env

set -eu

OUT="${1:-.env}"
PUBLIC_HOST="${PUBLIC_HOST:-31.31.201.32}"
HTTP_PORT="${HTTP_PORT:-80}"
USE_HTTPS="${USE_HTTPS:-0}"

rand() {
  dd if=/dev/urandom bs=48 count=1 2>/dev/null | base64 | tr -d '\n' | tr '+/' '-_'
}

ADMIN_PASS="$(dd if=/dev/urandom bs=12 count=1 2>/dev/null | base64 | tr -d '/+=' | head -c 16)"

JWT_SECRET="$(rand)"
CRON_SECRET="$(rand)"
POSTGRES_PASSWORD="$(rand)"
MINIO_ROOT_PASSWORD="$(rand)"
MINIO_ROOT_USER="klanyminio"

mkdir -p "$(dirname "$OUT")"

if [ "$USE_HTTPS" = "1" ]; then
  PUBLIC_SCHEME=https
  PUBLIC_PORT_SUFFIX=""
else
  PUBLIC_SCHEME=http
  if [ "$HTTP_PORT" = "80" ]; then
    PUBLIC_PORT_SUFFIX=""
  else
    PUBLIC_PORT_SUFFIX=":${HTTP_PORT}"
  fi
fi
PUBLIC_BASE="${PUBLIC_SCHEME}://${PUBLIC_HOST}${PUBLIC_PORT_SUFFIX}"

cat > "$OUT" <<EOF
# Fresh .env — ${PUBLIC_BASE} (generated $(date -u +%Y-%m-%dT%H:%M:%SZ))
# Wipe old data: docker compose --env-file ${OUT} down -v && docker compose --env-file ${OUT} up -d --build

APP_PUBLIC_BASE_URL=${PUBLIC_BASE}
MINIO_PUBLIC_BASE_URL=${PUBLIC_BASE}

HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=8443
API_PORT=3000

POSTGRES_DB=klany
POSTGRES_USER=klany
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_PORT=5434

JWT_SECRET=${JWT_SECRET}
CRON_SECRET=${CRON_SECRET}

ADMIN_SEED_EMAIL=admin@klany.local
ADMIN_SEED_PASSWORD=${ADMIN_PASS}

MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
MINIO_ACCESS_KEY=${MINIO_ROOT_USER}
MINIO_SECRET_KEY=${MINIO_ROOT_PASSWORD}
MINIO_HOST_PORT=9000
MINIO_CONSOLE_HOST_PORT=9001
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_ENDPOINT=minio
MINIO_USE_SSL=false
MINIO_BUCKET_QUEST_EVIDENCE=quest-evidence
MINIO_BUCKET_SHOP_PRODUCTS=shop-products
MINIO_BUCKET_MEMBER_AVATARS=member-avatars
MINIO_API_CORS_ALLOW_ORIGIN=*

NGINX_CERTS_DIR=/opt/klany/shared/certs

CORS_ORIGIN_ALLOWLIST=
CORS_CREDENTIALS=false

NODE_BUILD_MEMORY_MB=1536

RESEND_API_KEY=
RESEND_FROM_EMAIL=noreply@klany.local

YOOKASSA_SHOP_ID=
YOOKASSA_SECRET_KEY=
YOOKASSA_RETURN_URL=${PUBLIC_BASE}

TELEGRAM_BOT_TOKEN=

FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=
EOF

chmod 600 "$OUT" 2>/dev/null || true

echo "[generate_fresh_env] wrote $OUT"
echo "[generate_fresh_env] public URL: ${PUBLIC_BASE}"
echo "[generate_fresh_env] admin login: admin@klany.local / ${ADMIN_PASS}"
echo "[generate_fresh_env] run: sh scripts/server/generate_self_signed_certs.sh"
echo "[generate_fresh_env] next:"
echo "  docker compose --env-file ${OUT} down -v"
echo "  docker compose --env-file ${OUT} up -d --build"
