#!/usr/bin/env bash
# Idempotent stack start: drops legacy fixed-name containers, then compose up.
#
# Usage:
#   ./scripts/server/stack-up.sh [compose_dir] [env_file] [extra docker compose up args...]
#
# Examples:
#   cd /opt/klanymobail && ./scripts/server/stack-up.sh
#   cd /opt/klanymobail && ./scripts/server/stack-up.sh . /path/to/.env

set -euo pipefail

COMPOSE_DIR="${1:-.}"
shift || true

ENV_FILE="${1:-}"
if [[ -n "$ENV_FILE" ]]; then
  shift || true
else
  if [[ -f "$COMPOSE_DIR/.env" ]]; then
    ENV_FILE="$COMPOSE_DIR/.env"
  elif [[ -f "/opt/klany/shared/.env" ]]; then
    ENV_FILE="/opt/klany/shared/.env"
  elif [[ -f "$COMPOSE_DIR/.env.server" ]]; then
    ENV_FILE="$COMPOSE_DIR/.env.server"
  elif [[ -f "/opt/klany/shared/.env.server" ]]; then
    ENV_FILE="/opt/klany/shared/.env.server"
  else
    echo "stack-up: создай файл $COMPOSE_DIR/.env (см. .env.example в репозитории) или передай путь вторым аргументом" >&2
    exit 1
  fi
fi

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
cd "$COMPOSE_DIR"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "stack-up: compose file not found: $COMPOSE_DIR/$COMPOSE_FILE" >&2
  exit 1
fi

# Older compose used global container_name=klany-* — only one instance allowed on the host.
legacy=(klany-postgres klany-redis klany-minio klany-api klany-nginx)
for c in "${legacy[@]}"; do
  if docker container inspect "$c" >/dev/null 2>&1; then
    echo "[stack-up] removing legacy container: $c"
    docker rm -f "$c" >/dev/null
  fi
done

echo "[stack-up] compose up ($COMPOSE_DIR, env=$ENV_FILE)"
exec docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --build --remove-orphans "$@"
