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
#   ./scripts/local-supabase.sh reset
#   ./scripts/local-supabase.sh provision-users
#
# One-time requirements:
#   - Docker Desktop running
#   - Supabase CLI installed
#
# `reset` replays supabase/migrations/*.sql (a single baseline schema
# migration kept in sync with spread-prod) against the local database via
# `supabase db reset` — no dump/bootstrap step is required.

set -euo pipefail

DEFAULT_TEST_PASSWORD="${SPREAD_LOCAL_TEST_PASSWORD:-spread-local-pass}"
DEFAULT_TEST_USERS=(
  "local-sync-1@spread.test"
  "local-sync-2@spread.test"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUPABASE_DIR="$PROJECT_ROOT/supabase"
LOCAL_SCHEMA_DIR="$SUPABASE_DIR/local"
LOCAL_ENV_FILE="$LOCAL_SCHEMA_DIR/test.env"

log()  { echo "→ $*"; }
ok()   { echo "✓ $*"; }
err()  { echo "Error: $*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || err "Missing required command: $1"
}

require_supabase() {
  require_command supabase
}

require_docker() {
  require_command docker
  docker info >/dev/null 2>&1 || err \
    "Docker Desktop is not running or not accessible. Start Docker Desktop, then retry."
}

ensure_local_dirs() {
  mkdir -p "$LOCAL_SCHEMA_DIR"
}

load_local_status_env() {
  local env_output
  env_output="$(cd "$PROJECT_ROOT" && supabase status -o env)"
  eval "$(printf '%s\n' "$env_output" | sed 's/^/export /')"
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

reset_local_database() {
  require_supabase
  require_docker
  ensure_local_dirs

  log "Resetting local database from supabase/migrations..."
  (cd "$PROJECT_ROOT" && supabase db reset)
  ok "Local database reset from supabase/migrations."
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
  start            Start local Supabase services
  stop              Stop local Supabase services
  status            Show local Supabase status
  env               Print local Supabase env vars
  launch-args       Print app launch arguments for local Supabase
  provision-users   Create deterministic local auth users for testing
  reset             Reset local DB from supabase/migrations and provision users

Important files:
  Local env file:   ${LOCAL_ENV_FILE}

Prerequisites:
  - Supabase CLI
  - Docker Desktop running
EOF
  exit 1
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  env) cmd_env ;;
  launch-args) cmd_launch_args ;;
  provision-users) cmd_provision_users ;;
  reset) cmd_reset ;;
  *) usage ;;
esac
