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
- remote `spread-dev`
  - shared hosted QA and schema source of truth for local bootstrap snapshots
- remote `spread-prod`
  - production use only

## Prerequisites

- Supabase CLI installed
- Docker Desktop running
- `psql` and `pg_dump` installed
- remote dev DB password available before schema bootstrap, either:
  - exported in the shell, or
  - stored in `supabase/.env.local`

```bash
export SUPABASE_DB_PASSWORD_DEV="..."
```

Example `supabase/.env.local`:

```bash
SUPABASE_DB_PASSWORD_DEV="..."
SPREAD_LOCAL_TEST_PASSWORD="spread-local-pass"
```

Use the checked-in template as a starting point:

```bash
cp supabase/.env.local.example supabase/.env.local
```

## One-Time Bootstrap

Generate the local public-schema snapshot from remote dev:

```bash
./scripts/local-supabase.sh bootstrap-schema-from-dev
```

This writes:

- `supabase/local/public_schema_from_dev.sql`

Commit that file whenever the hosted schema changes intentionally and local sync tests need to track it.

## Daily Workflow

Start the local stack:

```bash
./scripts/local-supabase.sh start
```

Reset local schema and provision deterministic local test users:

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

- Debug/QA default -> remote development
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
2. start local Supabase
3. restore or bootstrap `supabase/local/public_schema_from_dev.sql`
4. run `./scripts/local-supabase.sh reset`
5. inject the generated local URL/key into the test process

Required CI secrets:

- `SUPABASE_DB_PASSWORD_DEV`
- optional `SPREAD_LOCAL_TEST_PASSWORD`

CI must not point automated destructive durability tests at remote `spread-dev` or `spread-prod`.

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
