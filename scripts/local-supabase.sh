#!/usr/bin/env bash
# scripts/local-supabase.sh
#
# Local Supabase helper for sync-enabled durability testing.
# Keeps hosted dev/prod untouched while providing an isolated local backend
# for destructive rebuild, repair, and assignment durability tests.
#
# Usage:
#   ./scripts/local-supabase.sh start
#   ./scripts/local-supabase.sh stop
#   ./scripts/local-supabase.sh status
#   ./scripts/local-supabase.sh env
#   ./scripts/local-supabase.sh launch-args
#   ./scripts/local-supabase.sh bootstrap-schema-from-dev
#   ./scripts/local-supabase.sh reset
#   ./scripts/local-supabase.sh provision-users
#
# One-time bootstrap requirements:
#   - Docker Desktop running
#   - Supabase CLI installed
#   - psql/pg_dump installed
#   - export SUPABASE_DB_PASSWORD_DEV="..."

set -euo pipefail

DEV_REF="apblzzondjcughtgqowd"
DEV_POOLER_HOST="aws-1-us-east-1.pooler.supabase.com"

DEFAULT_TEST_PASSWORD="${SPREAD_LOCAL_TEST_PASSWORD:-spread-local-pass}"
DEFAULT_TEST_USERS=(
  "local-sync-1@spread.test"
  "local-sync-2@spread.test"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUPABASE_DIR="$PROJECT_ROOT/supabase"
LOCAL_SCHEMA_DIR="$SUPABASE_DIR/local"
LOCAL_SCHEMA_FILE="$LOCAL_SCHEMA_DIR/public_schema_from_dev.sql"
LOCAL_ENV_FILE="$LOCAL_SCHEMA_DIR/test.env"
LOCAL_SECRET_FILE="$SUPABASE_DIR/.env.local"

log()  { echo "→ $*"; }
ok()   { echo "✓ $*"; }
err()  { echo "Error: $*" >&2; exit 1; }

load_local_secret_file() {
  if [[ -f "$LOCAL_SECRET_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$LOCAL_SECRET_FILE"
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || err "Missing required command: $1"
}

require_supabase() {
  require_command supabase
}

require_psql_tools() {
  require_command psql
  require_command pg_dump
}

require_docker() {
  require_command docker
  docker info >/dev/null 2>&1 || err \
    "Docker Desktop is not running or not accessible. Start Docker Desktop, then retry."
}

require_dev_password() {
  load_local_secret_file
  local dev_db_password="${SUPABASE_DB_PASSWORD_DEV:-}"
  [[ -n "$dev_db_password" ]] || err \
    $'SUPABASE_DB_PASSWORD_DEV is not set.\n' \
    "Set it in your shell or in $LOCAL_SECRET_FILE before running bootstrap-schema-from-dev."
}

dev_db_password() {
  load_local_secret_file
  printf '%s' "${SUPABASE_DB_PASSWORD_DEV:-}"
}

url_encode() {
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

ensure_local_dirs() {
  mkdir -p "$LOCAL_SCHEMA_DIR"
}

sanitize_bootstrap_schema_dump() {
  local source_file="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  python3 - "$source_file" "$tmp_file" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])

skip_default_acl = False
out_lines = []

for line in source.read_text().splitlines():
    if line.startswith("-- Name: DEFAULT PRIVILEGES"):
        skip_default_acl = True
        continue
    if skip_default_acl:
        if line.startswith("-- PostgreSQL database dump complete"):
            skip_default_acl = False
            out_lines.append(line)
        continue
    if line.startswith("\\restrict ") or line.startswith("\\unrestrict "):
        continue
    out_lines.append(line)

target.write_text("\n".join(out_lines) + "\n")
PY

  mv "$tmp_file" "$source_file"
}

load_local_status_env() {
  local env_output
  env_output="$(cd "$PROJECT_ROOT" && supabase status -o env)"
  eval "$(printf '%s\n' "$env_output" | sed 's/^/export /')"
}

require_local_schema_file() {
  [[ -f "$LOCAL_SCHEMA_FILE" ]] || err \
    $'Missing '"$LOCAL_SCHEMA_FILE"$'.\n' \
    "Run ./scripts/local-supabase.sh bootstrap-schema-from-dev after setting SUPABASE_DB_PASSWORD_DEV."
}

cmd_start() {
  require_supabase
  require_docker
  ensure_local_dirs
  (cd "$PROJECT_ROOT" && supabase start)
  ok "Local Supabase started."
}

cmd_stop() {
  require_supabase
  (cd "$PROJECT_ROOT" && supabase stop)
  ok "Local Supabase stopped."
}

cmd_status() {
  require_supabase
  (cd "$PROJECT_ROOT" && supabase status)
}

cmd_env() {
  require_supabase
  (cd "$PROJECT_ROOT" && supabase status -o env)
}

cmd_launch_args() {
  require_supabase
  load_local_status_env
  printf '%s\n' \
    "-DataEnvironment" "development" \
    "-SupabaseURL" "${API_URL}" \
    "-SupabaseKey" "${ANON_KEY}"
}

write_local_env_file() {
  load_local_status_env
  cat > "$LOCAL_ENV_FILE" <<EOF
DATA_ENVIRONMENT=development
SUPABASE_URL=${API_URL}
SUPABASE_PUBLISHABLE_KEY=${ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
SPREAD_LOCAL_TEST_PASSWORD=${DEFAULT_TEST_PASSWORD}
SPREAD_LOCAL_TEST_EMAIL_1=${DEFAULT_TEST_USERS[0]}
SPREAD_LOCAL_TEST_EMAIL_2=${DEFAULT_TEST_USERS[1]}
EOF
  ok "Wrote local test environment file: $LOCAL_ENV_FILE"
}

cmd_bootstrap_schema_from_dev() {
  require_supabase
  require_psql_tools
  require_dev_password
  ensure_local_dirs

  local encoded_pw dev_db_url
  encoded_pw="$(url_encode "$(dev_db_password)")"
  dev_db_url="postgresql://postgres.${DEV_REF}:${encoded_pw}@${DEV_POOLER_HOST}:5432/postgres"

  log "Dumping public schema from remote dev..."
  pg_dump "$dev_db_url" \
    --schema-only \
    --no-owner \
    --schema=public \
    -f "$LOCAL_SCHEMA_FILE"

  # `public` itself is managed separately during local reset.
  sed -i '' '/^CREATE SCHEMA public/d; /^COMMENT ON SCHEMA public/d' "$LOCAL_SCHEMA_FILE"
  sanitize_bootstrap_schema_dump "$LOCAL_SCHEMA_FILE"
  ok "Wrote local schema bootstrap: $LOCAL_SCHEMA_FILE"
}

reset_local_database() {
  require_supabase
  require_docker
  require_local_schema_file
  require_psql_tools

  log "Resetting local database containers..."
  (cd "$PROJECT_ROOT" && supabase db reset --local --no-seed)

  load_local_status_env

  log "Replacing local public schema with bootstrap snapshot..."
  psql "$DB_URL" \
    -c "DROP SCHEMA public CASCADE;" \
    -c "CREATE SCHEMA public;" \
    -c "GRANT ALL ON SCHEMA public TO postgres;" \
    -c "GRANT ALL ON SCHEMA public TO public;"

  psql "$DB_URL" -f "$LOCAL_SCHEMA_FILE" -v ON_ERROR_STOP=1
  ok "Local public schema restored from bootstrap snapshot."
}

create_or_ignore_user() {
  local email="$1"
  local payload response_code response_body
  payload=$(cat <<EOF
{"email":"$email","password":"$DEFAULT_TEST_PASSWORD","email_confirm":true}
EOF
)

  response_body="$(mktemp)"
  response_code="$(
    curl -sS \
      -o "$response_body" \
      -w "%{http_code}" \
      -X POST "${API_URL}/auth/v1/admin/users" \
      -H "apikey: ${SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -d "$payload"
  )"

  case "$response_code" in
    200|201)
      ok "Provisioned local test user $email"
      ;;
    422)
      ok "Local test user already exists: $email"
      ;;
    *)
      cat "$response_body" >&2
      rm -f "$response_body"
      err "Failed to provision local test user $email (HTTP $response_code)"
      ;;
  esac

  rm -f "$response_body"
}

cmd_provision_users() {
  require_supabase
  require_command curl
  load_local_status_env

  for email in "${DEFAULT_TEST_USERS[@]}"; do
    create_or_ignore_user "$email"
  done

  write_local_env_file
}

cmd_reset() {
  reset_local_database
  cmd_provision_users
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start                     Start local Supabase services
  stop                      Stop local Supabase services
  status                    Show local Supabase status
  env                       Print local Supabase env vars
  launch-args               Print app launch arguments for local Supabase
  bootstrap-schema-from-dev Dump the remote dev public schema to ${LOCAL_SCHEMA_FILE}
  provision-users           Create deterministic local auth users for testing
  reset                     Reset local DB, restore schema bootstrap, and provision users

Important files:
  Local schema bootstrap:   ${LOCAL_SCHEMA_FILE}
  Local env file:           ${LOCAL_ENV_FILE}

Prerequisites:
  - Supabase CLI
  - Docker Desktop running
  - psql and pg_dump installed
  - SUPABASE_DB_PASSWORD_DEV set before bootstrap-schema-from-dev
EOF
  exit 1
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  env) cmd_env ;;
  launch-args) cmd_launch_args ;;
  bootstrap-schema-from-dev) cmd_bootstrap_schema_from_dev ;;
  provision-users) cmd_provision_users ;;
  reset) cmd_reset ;;
  *) usage ;;
esac
