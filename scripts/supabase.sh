#!/usr/bin/env bash
# scripts/supabase.sh
#
# Supabase migration helper for the Spread app.
# Manages schema changes across dev and prod environments.
#
# Prerequisites:
#   - Supabase CLI installed: brew install supabase/tap/supabase
#   - Logged in: supabase login
#   - Set in your shell profile (~/.zshrc):
#
#       # DB passwords (Settings > Database > Database password)
#       export SUPABASE_DB_PASSWORD_DEV="..."
#       export SUPABASE_DB_PASSWORD_PROD="..."
#
#       # Pooler hostnames are hardcoded in the script (not sensitive).
#
# Usage:
#   ./scripts/supabase.sh new <name>       Create a new migration file
#   ./scripts/supabase.sh push dev         Apply pending migrations to dev
#   ./scripts/supabase.sh push prod        Apply pending migrations to prod
#   ./scripts/supabase.sh push all         Apply pending migrations to both
#   ./scripts/supabase.sh reload-cache dev Notify PostgREST to reload the dev schema cache
#   ./scripts/supabase.sh reload-cache prod Notify PostgREST to reload the prod schema cache
#   ./scripts/supabase.sh status           Show migration status for dev and prod
#   ./scripts/supabase.sh init-prod        One-time: apply full dev schema to prod

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────

DEV_REF="apblzzondjcughtgqowd"
PROD_REF="nzsswqmxodkvgsnabnaj"

DEV_DB_PASSWORD="${SUPABASE_DB_PASSWORD_DEV:-}"
PROD_DB_PASSWORD="${SUPABASE_DB_PASSWORD_PROD:-}"

# Session-mode pooler hostnames (IPv4 compatible, port 5432).
DEV_POOLER_HOST="aws-1-us-east-1.pooler.supabase.com"
PROD_POOLER_HOST="aws-1-us-east-2.pooler.supabase.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Helpers ──────────────────────────────────────────────────────────────────

log()  { echo "→ $*"; }
ok()   { echo "✓ $*"; }
err()  { echo "Error: $*" >&2; exit 1; }

# Percent-encode a string for safe inclusion in a URL userinfo field.
url_encode() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# Verify the CLI is installed and the user is logged in.
require_login() {
    if ! command -v supabase &>/dev/null; then
        err "Supabase CLI not found. Install with: brew install supabase/tap/supabase"
    fi
    if ! supabase projects list &>/dev/null; then
        err "Not logged in. Run: supabase login"
    fi
}

# Require DB password env vars. These are needed for commands that connect
# directly to the database (push, dump). Commands that use the Management API
# only (migration list) do not need them.
require_dev_password() {
    [[ -n "$DEV_DB_PASSWORD" ]] || err \
        "SUPABASE_DB_PASSWORD_DEV is not set.\n" \
        "Add to your shell profile: export SUPABASE_DB_PASSWORD_DEV=\"...\"\n" \
        "Find it at: https://supabase.com/dashboard/project/$DEV_REF/settings/database"
}

require_prod_password() {
    [[ -n "$PROD_DB_PASSWORD" ]] || err \
        "SUPABASE_DB_PASSWORD_PROD is not set.\n" \
        "Add to your shell profile: export SUPABASE_DB_PASSWORD_PROD=\"...\"\n" \
        "Find it at: https://supabase.com/dashboard/project/$PROD_REF/settings/database"
}

require_psql() {
    command -v psql &>/dev/null || err \
        "psql not found. Install with: brew install libpq && brew link --force libpq"
}


# Apply all pending local migrations to a Supabase project.
push_to() {
    local ref="$1" label="$2" host="$3" password="$4"
    local encoded_pw
    encoded_pw="$(url_encode "$password")"
    local db_url="postgresql://postgres.${ref}:${encoded_pw}@${host}:5432/postgres"
    log "Pushing migrations to $label ($ref)..."
    (cd "$PROJECT_ROOT" && supabase db push --db-url "$db_url")
    ok "$label is up to date."
}

reload_cache_for() {
    local ref="$1" label="$2" host="$3" password="$4"
    local encoded_pw
    encoded_pw="$(url_encode "$password")"
    local db_url="postgresql://postgres.${ref}:${encoded_pw}@${host}:5432/postgres"
    log "Reloading PostgREST schema cache for $label ($ref)..."
    psql "$db_url" -v ON_ERROR_STOP=1 -c "NOTIFY pgrst, 'reload schema';"
    ok "$label schema cache reloaded."
}

# ─── Commands ─────────────────────────────────────────────────────────────────

# Create a new timestamped migration file in supabase/migrations/.
cmd_new() {
    local name="${1:-}"
    [[ -n "$name" ]] || err "Usage: $(basename "$0") new <migration_name>"
    (cd "$PROJECT_ROOT" && supabase migration new "$name")
    ok "Created migration in supabase/migrations/"
}

# Apply pending migrations to dev, prod, or both.
cmd_push() {
    local target="${1:-all}"
    require_login
    case "$target" in
        dev)
            require_dev_password
            push_to "$DEV_REF" "dev" "$DEV_POOLER_HOST" "$DEV_DB_PASSWORD"
            ;;
        prod)
            require_prod_password
            push_to "$PROD_REF" "prod" "$PROD_POOLER_HOST" "$PROD_DB_PASSWORD"
            ;;
        all)
            require_dev_password
            require_prod_password
            push_to "$DEV_REF"  "dev"  "$DEV_POOLER_HOST"  "$DEV_DB_PASSWORD"
            push_to "$PROD_REF" "prod" "$PROD_POOLER_HOST" "$PROD_DB_PASSWORD"
            ;;
        *)
            err "Unknown target '$target'. Use: dev, prod, or all"
            ;;
    esac
}

cmd_reload_cache() {
    local target="${1:-}"
    require_login
    require_psql
    case "$target" in
        dev)
            require_dev_password
            reload_cache_for "$DEV_REF" "dev" "$DEV_POOLER_HOST" "$DEV_DB_PASSWORD"
            ;;
        prod)
            require_prod_password
            reload_cache_for "$PROD_REF" "prod" "$PROD_POOLER_HOST" "$PROD_DB_PASSWORD"
            ;;
        *)
            err "Unknown target '$target'. Use: dev or prod"
            ;;
    esac
}

# Show which migrations have been applied on dev and prod.
cmd_status() {
    require_login
    require_dev_password
    require_prod_password
    local dev_pw prod_pw
    dev_pw="$(url_encode "$DEV_DB_PASSWORD")"
    prod_pw="$(url_encode "$PROD_DB_PASSWORD")"
    echo ""
    echo "─── dev ($DEV_REF) ───────────────────────────────"
    (cd "$PROJECT_ROOT" && supabase migration list \
        --db-url "postgresql://postgres.${DEV_REF}:${dev_pw}@${DEV_POOLER_HOST}:5432/postgres")
    echo ""
    echo "─── prod ($PROD_REF) ──────────────────────────────"
    (cd "$PROJECT_ROOT" && supabase migration list \
        --db-url "postgresql://postgres.${PROD_REF}:${prod_pw}@${PROD_POOLER_HOST}:5432/postgres")
    echo ""
}

# One-time initial setup: dump the full dev schema and apply it to prod.
#
# This is needed when prod has no tables yet. It:
#   1. Dumps the dev schema (structure only, no data) to a temp SQL file.
#   2. Applies the dump to prod via psql.
#   3. Marks all local migration files as applied in prod's migration history
#      so that future `push prod` calls don't re-apply already-applied SQL.
#
# Run this once, then use `push prod` for all future schema changes.
cmd_init_prod() {
    require_login
    require_dev_password
    require_prod_password
    require_psql

    local dump_file
    dump_file="$(mktemp /tmp/spread_dev_schema_XXXXXX.sql)"
    # Capture the path now so the trap can reference it after the function returns.
    trap "rm -f '$dump_file'" EXIT

    local dev_pw prod_pw
    dev_pw="$(url_encode "$DEV_DB_PASSWORD")"
    prod_pw="$(url_encode "$PROD_DB_PASSWORD")"

    # Step 1: Dump dev schema (structure only, no data).
    # Uses pg_dump directly to avoid the `supabase db dump` Docker requirement.
    log "Dumping schema from dev..."
    local dev_db_url="postgresql://postgres.${DEV_REF}:${dev_pw}@${DEV_POOLER_HOST}:5432/postgres"
    pg_dump "$dev_db_url" --schema-only --no-owner \
        --schema=public -f "$dump_file"
    # Remove SCHEMA-level CREATE statements — public schema is managed by Supabase.
    sed -i '' '/^CREATE SCHEMA/d; /^COMMENT ON SCHEMA/d' "$dump_file"
    ok "Schema dump written to $dump_file"

    # Step 2: Apply schema to prod.
    # Uses the session-mode pooler (IPv4 compatible) instead of the direct
    # connection (IPv6 only by default).
    local prod_db_url="postgresql://postgres.${PROD_REF}:${prod_pw}@${PROD_POOLER_HOST}:5432/postgres"

    # Reset the public schema to a clean state. This drops all tables, functions,
    # triggers, and other objects so the dump can be applied without conflicts.
    # Safe because prod has no user data at this point.
    log "Resetting public schema on prod..."
    psql "$prod_db_url" \
        -c "SELECT cron.unschedule('cleanup-tombstones');" 2>/dev/null || true
    psql "$prod_db_url" \
        -c "DROP SCHEMA public CASCADE;" \
        -c "CREATE SCHEMA public;" \
        -c "GRANT ALL ON SCHEMA public TO postgres;" \
        -c "GRANT ALL ON SCHEMA public TO public;"

    log "Applying schema to prod..."
    psql "$prod_db_url" -f "$dump_file" -v ON_ERROR_STOP=1
    ok "Schema applied to prod"

    # Step 3: Mark all local migration files as applied in prod's history.
    # This prevents `push prod` from trying to re-run SQL that is already live.
    log "Marking local migrations as applied in prod..."
    for migration_file in "$PROJECT_ROOT"/supabase/migrations/*.sql; do
        local version
        version="$(basename "$migration_file" | cut -d'_' -f1)"
        log "  Marking $version as applied..."
        (cd "$PROJECT_ROOT" && supabase migration repair \
            --db-url "postgresql://postgres.${PROD_REF}:${prod_pw}@${PROD_POOLER_HOST}:5432/postgres" \
            --status applied \
            "$version") || {
            echo "  Warning: Could not mark $version — skipping." >&2
        }
    done

    ok "prod is fully initialized and migration history is in sync."
    echo ""
    echo "Run './scripts/supabase.sh status' to verify."
}

# ─── Entry point ──────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  new <name>    Create a new timestamped migration file
  push dev      Apply pending migrations to dev
  push prod     Apply pending migrations to prod
  push all      Apply pending migrations to dev then prod  (default)
  reload-cache dev|prod
                 Notify PostgREST to reload the schema cache
  status        Show migration status for dev and prod
  init-prod     One-time: apply full dev schema to prod

Environment variables (required for push, init-prod):
  SUPABASE_DB_PASSWORD_DEV    DB password for dev
  SUPABASE_DB_PASSWORD_PROD   DB password for prod

EOF
    exit 1
}

case "${1:-}" in
    new)       cmd_new "${2:-}" ;;
    push)      cmd_push "${2:-all}" ;;
    reload-cache) cmd_reload_cache "${2:-}" ;;
    status)    cmd_status ;;
    init-prod) cmd_init_prod ;;
    *)         usage ;;
esac
