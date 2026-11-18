#!/bin/bash
# Railway start script for the Hyperswitch router.
# 1. maps Railway's Postgres and Redis variables onto Hyperswitch's ROUTER__* settings,
# 2. runs the release's database migrations (diesel, idempotent),
# 3. starts the router as the unprivileged `app` user.
set -euo pipefail

need() {
  local missing=0
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then echo "hyperswitch-start: missing required variable $name" >&2; missing=1; fi
  done
  [ "$missing" -eq 0 ] || exit 1
}

need PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE REDISHOST REDISPORT \
  ROUTER__SECRETS__ADMIN_API_KEY ROUTER__SECRETS__JWT_SECRET ROUTER__SECRETS__MASTER_ENC_KEY \
  ROUTER__API_KEYS__HASH_KEY ROUTER__USER_AUTH_METHODS__ENCRYPTION_KEY \
  ROUTER__PAYMENT_METHOD_AUTH__PM_AUTH_KEY ROUTER__INTERNAL_MERCHANT_ID_PROFILE_ID_AUTH__PRIMARY_INTERNAL_API_KEY

for name in ROUTER__SECRETS__MASTER_ENC_KEY ROUTER__API_KEYS__HASH_KEY ROUTER__USER_AUTH_METHODS__ENCRYPTION_KEY; do
  if [[ ! "${!name}" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "hyperswitch-start: $name must be 64 hex characters" >&2; exit 1
  fi
done

# --- Database: one Postgres for every store Hyperswitch knows about
for db in MASTER_DATABASE REPLICA_DATABASE ACCOUNTS_DATABASE GLOBAL_DATABASE ANALYTICS__SQLX; do
  export "ROUTER__${db}__HOST=${PGHOST}"
  export "ROUTER__${db}__PORT=${PGPORT}"
  export "ROUTER__${db}__USERNAME=${PGUSER}"
  export "ROUTER__${db}__PASSWORD=${PGPASSWORD}"
  export "ROUTER__${db}__DBNAME=${PGDATABASE}"
done
export ROUTER__ANALYTICS__SOURCE="${ROUTER__ANALYTICS__SOURCE:-sqlx}"

# --- Redis (Railway's Redis requires AUTH)
export ROUTER__REDIS__HOST="${REDISHOST}"
export ROUTER__REDIS__PORT="${REDISPORT}"
if [ -n "${REDISPASSWORD:-}" ]; then
  export ROUTER__REDIS__USERNAME="${REDISUSER:-default}"
  export ROUTER__REDIS__PRIMARY_PASSWORD="${REDISPASSWORD}"
fi

# --- HTTP server
export ROUTER__SERVER__HOST="${ROUTER__SERVER__HOST:-0.0.0.0}"
export ROUTER__SERVER__PORT="${PORT:-8080}"
export ROUTER__SERVER__WORKERS="${ROUTER__SERVER__WORKERS:-2}"

# --- Public URLs of the three services (set by the template from Railway's domains)
if [ -n "${HYPERSWITCH_PUBLIC_URL:-}" ]; then
  export ROUTER__MULTITENANCY__TENANTS__PUBLIC__BASE_URL="${HYPERSWITCH_PUBLIC_URL%/}"
  export ROUTER__INTERNAL_SERVICES__PAYMENTS_BASE_URL="${HYPERSWITCH_PUBLIC_URL%/}"
fi
if [ -n "${CONTROL_CENTER_URL:-}" ]; then
  export ROUTER__USER__BASE_URL="${CONTROL_CENTER_URL%/}"
  export ROUTER__MULTITENANCY__TENANTS__PUBLIC__USER__CONTROL_CENTER_URL="${CONTROL_CENTER_URL%/}"
fi
if [ -n "${SDK_URL:-}" ]; then
  loader="${SDK_URL%/}/web/${HYPERSWITCH_WEB_VERSION:-0.135.0}/v1/HyperLoader.js"
  export ROUTER__GENERIC_LINK__PAYMENT_METHOD_COLLECT__SDK_URL="${loader}"
  export ROUTER__GENERIC_LINK__PAYOUT_LINK__SDK_URL="${loader}"
fi

# --- Defaults for a single-router deployment (each can be overridden with a variable)
export ROUTER__LOG__CONSOLE__LEVEL="${ROUTER__LOG__CONSOLE__LEVEL:-INFO}"
export ROUTER__LOG__CONSOLE__LOG_FORMAT="${ROUTER__LOG__CONSOLE__LOG_FORMAT:-default}"
export ROUTER__LOG__TELEMETRY__METRICS_ENABLED="${ROUTER__LOG__TELEMETRY__METRICS_ENABLED:-false}"
export ROUTER__LOG__TELEMETRY__TRACES_ENABLED="${ROUTER__LOG__TELEMETRY__TRACES_ENABLED:-false}"
# There is no Superposition service in this template: the router falls back to the
# release's bundled seed file, which holds the upstream defaults.
export ROUTER__SUPERPOSITION__ENDPOINT="${ROUTER__SUPERPOSITION__ENDPOINT:-http://127.0.0.1:1}"
export ROUTER__SUPERPOSITION__BACKUP_FILE_PATH="${ROUTER__SUPERPOSITION__BACKUP_FILE_PATH:-/local/config/superposition_seed.toml}"

# --- Files (dispute evidence, themes) live on the Railway volume at /local/bin/files
mkdir -p /local/bin/files
chown app:app /local/bin/files 2>/dev/null || true

# --- Database migrations (upstream's own diesel migrations, recorded in __diesel_schema_migrations)
# libpq reads PGUSER / PGPASSWORD from the environment, so no password goes into the URL.
export DATABASE_URL="postgresql://${PGHOST}:${PGPORT}/${PGDATABASE}"
attempt=0
until diesel migration run \
    --migration-dir /local/migrations \
    --config-file /local/config/diesel.toml; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "hyperswitch-start: migrations failed after ${attempt} attempts" >&2
    exit 1
  fi
  echo "hyperswitch-start: database not ready or migration failed, retrying in 5 s (${attempt}/30)" >&2
  sleep 5
done
echo "hyperswitch-start: database migrations are up to date (Hyperswitch ${HYPERSWITCH_VERSION})"

cd /local/bin
exec setpriv --reuid=app --regid=app --init-groups /local/bin/router -f /local/config/router.toml
