#!/usr/bin/env bash
# Full reset: stop ALL klany containers, wipe volumes, start fresh stack.
#
# Usage (on server, from repo root):
#   cd /opt/klanymobail/klanymobail
#   sh scripts/server/nuke_and_up.sh
#   sh scripts/server/nuke_and_up.sh /path/to/.env
#
# WARNING: deletes postgres/redis/minio data for project klanymobail.

set -euo pipefail

COMPOSE_DIR="${NUKE_COMPOSE_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
ENV_FILE="${1:-$COMPOSE_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "nuke_and_up: .env not found: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
  echo "nuke_and_up: docker-compose.yml not found in $COMPOSE_DIR" >&2
  exit 1
fi

echo "=== [1/5] Stop any running klany / klanymobail compose stacks ==="
for dir in \
  "$COMPOSE_DIR" \
  /opt/klanymobail/klanymobail \
  /opt/klanymobail \
  /opt/klany/current \
  /opt/klany/releases/*/; do
  [[ -f "$dir/docker-compose.yml" ]] || continue
  for ef in "$ENV_FILE" "$dir/.env" /opt/klany/shared/.env /opt/klany/shared/.env.server; do
    [[ -f "$ef" ]] || continue
    echo "  compose down -v in $dir (env=$ef)"
    (cd "$dir" && docker compose --env-file "$ef" down -v --remove-orphans 2>/dev/null) || true
    break
  done
done

echo "=== [2/5] Force-remove leftover klany containers ==="
docker ps -aq --filter 'name=klany' | xargs -r docker rm -f
docker ps -aq --filter 'name=klanymobail' | xargs -r docker rm -f

echo "=== [3/5] Remove named volumes (fresh DB / MinIO) ==="
docker volume rm -f klanymobail_postgres_data klanymobail_redis_data klanymobail_minio_data 2>/dev/null || true
docker volume rm -f klany_postgres_data klany_postgres_data klany_redis_data klany_minio_data 2>/dev/null || true

echo "=== [4/5] Ensure nginx TLS stubs exist ==="
CERT_DIR="$(grep -E '^NGINX_CERTS_DIR=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r' || true)"
CERT_DIR="${CERT_DIR:-/opt/klany/shared/certs}"
if [[ ! -f "$CERT_DIR/server.crt" ]]; then
  CN="${PUBLIC_HOST:-31.31.201.32}"
  mkdir -p "$CERT_DIR"
  if command -v openssl >/dev/null 2>&1; then
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout "$CERT_DIR/server.key" \
      -out "$CERT_DIR/server.crt" \
      -subj "/CN=${CN}/O=Klany/C=RU"
    chmod 600 "$CERT_DIR/server.key"
    echo "  created self-signed certs in $CERT_DIR"
  else
    echo "  WARN: openssl missing; nginx may fail if certs absent" >&2
  fi
fi

echo "=== [5/5] Build and start stack ==="
cd "$COMPOSE_DIR"
docker compose --env-file "$ENV_FILE" build api nginx
docker compose --env-file "$ENV_FILE" up -d --remove-orphans

echo ""
docker compose --env-file "$ENV_FILE" ps
echo ""
HTTP_PORT="$(grep -E '^HTTP_PORT=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r' || echo 8782)"
PUBLIC="$(grep -E '^APP_PUBLIC_BASE_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r' || echo "http://127.0.0.1:${HTTP_PORT}")"
echo "Health: curl -sS ${PUBLIC}/api/health"
curl -sS "http://127.0.0.1:${HTTP_PORT}/api/health" || echo "(health check failed — wait 30s and retry)"
echo ""
echo "Done."
