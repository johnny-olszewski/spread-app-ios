# Local Supabase Sync Testing

This guide defines the free-tier local sync-testing workflow for Spread.

## Environment Roles

- `localhost`
  - UI logic only
  - no auth, no sync
  - use for mock-data and deterministic UI scenario tests
- local Supabase
  - destructive sync durability, rebuild, and repair testing
  - isolated from hosted environments
  - schema comes from `supabase/migrations/` (a single baseline migration kept in sync with `spread-prod`)
- remote `spread-prod`
  - production use only

## Prerequisites

- Supabase CLI installed
- Docker Desktop running

Optional `supabase/.env.local` (used for deterministic local test users):

```bash
SPREAD_LOCAL_TEST_PASSWORD="spread-local-pass"
```

Use the checked-in template as a starting point:

```bash
cp supabase/.env.local.example supabase/.env.local
```

## Daily Workflow

Start the local stack:

```bash
./scripts/local-supabase.sh start
```

Reset the local database from `supabase/migrations/` and provision deterministic local test users:

```bash
./scripts/local-supabase.sh reset
```

Inspect local credentials:

```bash
./scripts/local-supabase.sh env
```

Print app launch arguments for local sync testing:

```bash
./scripts/local-supabase.sh launch-args
```

Generated local test environment file:

- `supabase/local/test.env`

It contains:

- local Supabase URL
- local publishable key
- local service-role key
- deterministic test-user emails
- deterministic test-user password

## App Launch Strategy

The app should continue to use:

- Debug default -> `localhost` (local-only, no backend)
- Release default -> remote production
- `-DataEnvironment localhost` -> local-only engineering mode

For local Supabase sync testing, keep `DataEnvironment` on a sync-enabled mode and override the backend:

```text
-DataEnvironment development
-SupabaseURL <local api url>
-SupabaseKey <local anon key>
```

This preserves product auth/sync behavior while redirecting the backend to the local Supabase stack.

## Deterministic Local Users

Provisioned by:

```bash
./scripts/local-supabase.sh provision-users
```

Default accounts:

- `local-sync-1@spread.test`
- `local-sync-2@spread.test`

Default password:

- `spread-local-pass`

Override the password before provisioning if needed:

```bash
export SPREAD_LOCAL_TEST_PASSWORD="..."
```

## CI Expectations

CI should:

1. start Docker
2. start local Supabase (`supabase db reset` replays `supabase/migrations/`)
3. run `./scripts/local-supabase.sh reset`
4. inject the generated local URL/key into the test process

CI must not point automated destructive durability tests at remote `spread-prod`.

## Updating the Local Schema

The local schema is defined entirely by `supabase/migrations/`. When `spread-prod`'s schema changes intentionally, regenerate the baseline migration:

```bash
pg_dump "<spread-prod connection string>" --schema-only --no-owner --schema=public -f supabase/migrations/<timestamp>_baseline_schema.sql
```

Then strip the `CREATE SCHEMA public`/`COMMENT ON SCHEMA public`/`DEFAULT PRIVILEGES`/`\restrict`/`\unrestrict` lines, remove the previous baseline migration file, and run `./scripts/local-supabase.sh reset` to verify.

## Running Sync-Enabled Durability Tests

After `./scripts/local-supabase.sh start` and `./scripts/local-supabase.sh reset`, run:

```bash
xcodebuild -scheme Spread \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SpreadTests/SyncDurabilityIntegrationTests \
  test
```

These tests read `supabase/local/test.env` directly, sign into the deterministic local users, and exercise:

- direct assignment rebuild after local wipe
- Inbox fallback rebuild
- migration rebuild and source-history preservation
- reassignment rebuild on a fresh second client
- spread deletion reassignment durability for tasks and notes
- assignment tombstone durability
- safe backfill recovery for missing server assignment rows
