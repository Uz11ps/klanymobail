#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-/opt/klany}"
ENV_FILE="$APP_DIR/shared/.env.server"
CRON_TMP="$(mktemp)"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

get_env() {
  local key="$1"
  sed -n "s/^${key}=//p" "$ENV_FILE" | head -n 1
}

CRON_SECRET="$(get_env CRON_SECRET)"
if [[ -z "$CRON_SECRET" ]]; then
  echo "CRON_SECRET is empty in $ENV_FILE" >&2
  exit 1
fi

mkdir -p "$APP_DIR/shared/ops" "$APP_DIR/shared/backups/postgres" "$APP_DIR/shared/backups/minio"

cat > "$APP_DIR/shared/ops/backup.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/klany"
ENV_FILE="$APP_DIR/shared/.env.server"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
PG_DIR="$APP_DIR/shared/backups/postgres"
MINIO_DIR="$APP_DIR/shared/backups/minio"

get_env() {
  local key="$1"
  sed -n "s/^${key}=//p" "$ENV_FILE" | head -n 1
}

POSTGRES_USER="$(get_env POSTGRES_USER)"
POSTGRES_DB="$(get_env POSTGRES_DB)"
MINIO_ACCESS_KEY="$(get_env MINIO_ACCESS_KEY)"
MINIO_SECRET_KEY="$(get_env MINIO_SECRET_KEY)"
MINIO_HOST_PORT="$(get_env MINIO_HOST_PORT)"
MINIO_PORT_LEGACY="$(get_env MINIO_PORT)"
MINIO_BUCKET_QUEST_EVIDENCE="$(get_env MINIO_BUCKET_QUEST_EVIDENCE)"
MINIO_BUCKET_SHOP_PRODUCTS="$(get_env MINIO_BUCKET_SHOP_PRODUCTS)"

POSTGRES_USER="${POSTGRES_USER:-klany}"
POSTGRES_DB="${POSTGRES_DB:-klany}"
MINIO_MC_HOST="${MINIO_HOST_PORT:-${MINIO_PORT_LEGACY:-9000}}"
MINIO_BUCKET_QUEST_EVIDENCE="${MINIO_BUCKET_QUEST_EVIDENCE:-quest-evidence}"
MINIO_BUCKET_SHOP_PRODUCTS="${MINIO_BUCKET_SHOP_PRODUCTS:-shop-products}"

if [[ -z "$MINIO_ACCESS_KEY" || -z "$MINIO_SECRET_KEY" ]]; then
  echo "MINIO_ACCESS_KEY/MINIO_SECRET_KEY are required in $ENV_FILE" >&2
  exit 1
fi

mkdir -p "$PG_DIR" "$MINIO_DIR/$STAMP"

COMPOSE_DIR="$APP_DIR/current"
if [[ ! -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
  COMPOSE_DIR="/opt/klanymobail"
fi
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_DIR/docker-compose.yml" exec -T postgres \
  sh -lc "pg_dump -U \"$POSTGRES_USER\" \"$POSTGRES_DB\"" | gzip > "$PG_DIR/${STAMP}.sql.gz"

docker run --rm --network host \
  -e MC_HOST_src="http://$MINIO_ACCESS_KEY:$MINIO_SECRET_KEY@127.0.0.1:${MINIO_MC_HOST}" \
  -v "$MINIO_DIR/$STAMP:/backup" \
  minio/mc:latest \
  mirror --overwrite "src/$MINIO_BUCKET_QUEST_EVIDENCE" "/backup/$MINIO_BUCKET_QUEST_EVIDENCE"

docker run --rm --network host \
  -e MC_HOST_src="http://$MINIO_ACCESS_KEY:$MINIO_SECRET_KEY@127.0.0.1:${MINIO_MC_HOST}" \
  -v "$MINIO_DIR/$STAMP:/backup" \
  minio/mc:latest \
  mirror --overwrite "src/$MINIO_BUCKET_SHOP_PRODUCTS" "/backup/$MINIO_BUCKET_SHOP_PRODUCTS"

find "$PG_DIR" -type f -name "*.sql.gz" -mtime +7 -delete
find "$MINIO_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} +
EOF

chmod +x "$APP_DIR/shared/ops/backup.sh"

cat > "$APP_DIR/shared/ops/healthcheck.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! curl -fsS -m 10 "http://127.0.0.1:8782/api/health" >/dev/null; then
  cd /opt/klany/current
  docker compose --env-file /opt/klany/shared/.env.server up -d
fi
EOF

chmod +x "$APP_DIR/shared/ops/healthcheck.sh"

{
  crontab -l 2>/dev/null | sed '/# klany-notifications-cron/d;/# klany-backup/d;/# klany-healthcheck/d' || true
  echo "*/15 * * * * curl -fsS -m 10 -X POST -H 'x-cron-secret: ${CRON_SECRET}' -o /dev/null http://127.0.0.1:8782/api/internal/notifications-cron # klany-notifications-cron"
  echo "17 2 * * * /opt/klany/shared/ops/backup.sh >/var/log/klany-backup.log 2>&1 # klany-backup"
  echo "*/5 * * * * /opt/klany/shared/ops/healthcheck.sh >/var/log/klany-healthcheck.log 2>&1 # klany-healthcheck"
} > "$CRON_TMP"

crontab "$CRON_TMP"
rm -f "$CRON_TMP"

echo "OK: ops installed"
