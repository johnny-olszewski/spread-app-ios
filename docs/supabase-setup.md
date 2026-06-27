# Supabase Setup Guide

This document covers the Supabase configuration for the Spread app, including environment setup, CLI usage, migrations workflow, and the local Supabase durability-testing stack.

## Environments

The app uses one remote Supabase project:

| Environment | Project Name | Project URL | Purpose |
|-------------|--------------|-------------|---------|
| Production | spread-prod | `https://nzsswqmxodkvgsnabnaj.supabase.co` | App Store releases |

The testing workflow also uses two local-only environments:

| Environment | Backend | Purpose |
|-------------|---------|---------|
| Debug `localhost` | None (local-only app state) | Mock-data/UI logic scenarios with no auth or sync |
| Local Supabase | Local Docker stack | Destructive sync durability, rebuild, and repair testing |

A separate `spread-dev` Supabase project previously existed but is not in use
and is not referenced by any build configuration.

## Build Configuration

The project has two build configurations - Debug and Release - with two
corresponding schemes, `Spread Localhost` and `Spread Prod`. There is
currently no separate configuration for TestFlight distribution; that is a
future configuration that is not needed yet.

Supabase configuration is managed via xcconfig files:

- `Configuration/Debug.xcconfig` - Defaults to `localhost` (local-only, no backend). Also
  carries the fixed local Docker Supabase URL/key used by `-DataEnvironment development`.
- `Configuration/Release.xcconfig` - Uses the `spread-prod` environment

These values are injected into `Info.plist` at build time and read by `SupabaseConfiguration.swift` at runtime.

### Debug Localhost Mode

Debug builds default to `localhost` (local-only, no backend). Runtime
environment switching is not part of v1, but `-DataEnvironment development`
can be passed at launch (paired with `-SupabaseURL`/`-SupabaseKey` overrides,
or the local Docker Supabase defaults baked into `Debug.xcconfig`) to test
against a local Supabase stack. See
[docs/local-supabase-testing.md](./local-supabase-testing.md) for that workflow.

`localhost` is an engineering-only mode:
- it bypasses product auth with a mock user
- it keeps all persistence local for that run
- it is the only mode where mock data loading is available
- it is not persisted across launches
- the app wipes the local store when switching to or from `localhost` so mock data cannot contaminate backed local state

## Auth Providers

### Currently Enabled
- **Email/Password** - Basic authentication

V1 does not use Sign in with Apple or Google Sign-in.

## Supabase CLI Setup

### Installation

```bash
# macOS (Homebrew)
brew install supabase/tap/supabase

# Or via npm
npm install -g supabase
```

### Login

```bash
supabase login
```

### Link to Projects

```bash
# Link to prod (use with caution)
supabase link --project-ref nzsswqmxodkvgsnabnaj
```

## Migrations Workflow

`supabase/migrations/` currently holds a single baseline migration
(`<timestamp>_baseline_schema.sql`) that reflects `spread-prod`'s schema as of
the date it was generated. Pre-release, there is no need to preserve a
historical sequence of incremental migrations; this will be revisited once the
app ships and remote schema changes must be rolled out incrementally.

### Regenerating the Baseline

When `spread-prod`'s schema changes intentionally, regenerate the baseline
migration from prod via `pg_dump`:

```bash
pg_dump "<spread-prod connection string>" --schema-only --no-owner --schema=public \
  -f supabase/migrations/<timestamp>_baseline_schema.sql
```

Then:

1. Strip the `CREATE SCHEMA public` / `COMMENT ON SCHEMA public` lines, any
   `-- Name: DEFAULT PRIVILEGES` blocks, and any `\restrict` / `\unrestrict`
   lines from the dump.
2. Remove the previous baseline migration file.
3. Run `./scripts/local-supabase.sh reset` to verify the local database
   reproduces the new schema.

See [docs/local-supabase-testing.md](./local-supabase-testing.md#updating-the-local-schema)
for the equivalent local-testing instructions.

### Applying Schema Changes to Prod

Once a schema change has been made directly against `spread-prod` (e.g. via
the Supabase Dashboard, `supabase db push`, or the Supabase MCP), regenerate
the baseline migration as described above so local development stays in sync.

```bash
# Compare local migrations with remote schema
supabase db diff --linked
```

## MCP Integration

The Supabase MCP (Model Context Protocol) server can be used with Claude for:
- Schema inspection and verification
- Running ad-hoc queries during development
- Validating migration results

### MCP Server Configuration

Add to your Claude MCP configuration:

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-supabase", "--project-ref", "nzsswqmxodkvgsnabnaj"]
    }
  }
}
```

## Local Development

### Running Supabase Locally

Spread uses local Supabase for sync-enabled durability testing while staying on the hosted free tier.

Use the repo helper script instead of raw CLI commands:

```bash
# Start the local stack
./scripts/local-supabase.sh start

# Reset local schema (replays supabase/migrations/) and provision deterministic local test users
./scripts/local-supabase.sh reset

# Print local app launch arguments
./scripts/local-supabase.sh launch-args

# Stop the local stack
./scripts/local-supabase.sh stop
```

See [docs/local-supabase-testing.md](./local-supabase-testing.md) for the full workflow.
Use `supabase/.env.local.example` as the starting point for local secrets.

### Launch Modes

For local testing against the app's in-memory/local-only stack, launch Debug with:

```text
-DataEnvironment localhost
```

For local Supabase sync testing, keep the app in a sync-enabled mode and override the backend:

```text
-DataEnvironment development
-SupabaseURL <local api url>
-SupabaseKey <local anon key>
```

## Database Schema

The schema below reflects `spread-prod`'s current schema, as captured in the
single baseline migration `supabase/migrations/<timestamp>_baseline_schema.sql`
(see [Migrations Workflow](#migrations-workflow)).

### Tables Overview

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `spreads` | Journaling pages tied to time periods | `period`, `date`, `start_date`, `end_date`, `is_favorite`, `custom_name`, `uses_dynamic_name` |
| `tasks` | Assignable entries with status | `title`, `body`, `date`, `period`, `status`, `priority`, `due_date`, `list_id` |
| `notes` | Assignable entries with content | `title`, `content`, `date`, `period`, `status`, `list_id` |
| `task_assignments` | Per-spread status for tasks | `task_id`, `spread_id`, `period`, `date`, `status` |
| `note_assignments` | Per-spread status for notes | `note_id`, `spread_id`, `period`, `date`, `status` |
| `collections` | Plain text pages | `title` |
| `settings` | User preferences (one row per user) | `bujo_mode`, `first_weekday` |
| `lists` | Named groupings of tasks/notes | `name` |
| `tags` | User-defined tags | `name` |
| `task_tags` | Join table: tags applied to tasks | `task_id`, `tag_id` |
| `note_tags` | Join table: tags applied to notes | `note_id`, `tag_id` |

### Common Columns

Entity tables (`spreads`, `tasks`, `notes`, `task_assignments`,
`note_assignments`, `collections`, `settings`, `lists`, `tags`) include:

| Column | Type | Purpose |
|--------|------|---------|
| `id` | `uuid` | Primary key (auto-generated) |
| `user_id` | `uuid` | Owner of the record |
| `device_id` | `uuid` | Device that created/modified the record |
| `created_at` | `timestamptz` | When record was created |
| `deleted_at` | `timestamptz` | Soft delete timestamp (null = active) |
| `revision` | `bigint` | Monotonic version for incremental sync |

`lists` and `tags` omit `updated_at` (no field-level LWW beyond `name`).
All other entity tables above also include `updated_at` (`timestamptz`).

The join tables `task_tags` (PK `(task_id, tag_id)`) and `note_tags` (PK
`(note_id, tag_id)`) omit `id` and `device_id`, and have only `user_id`,
`created_at`, `deleted_at`, `revision`.

### Field-Level LWW Timestamps

Each table has per-field `*_updated_at` columns for field-level last-write-wins conflict resolution:

- **spreads**: `period_updated_at`, `date_updated_at`, `start_date_updated_at`, `end_date_updated_at`, `is_favorite_updated_at`, `custom_name_updated_at`, `uses_dynamic_name_updated_at`
- **tasks**: `title_updated_at`, `date_updated_at`, `period_updated_at`, `status_updated_at`, `body_updated_at`, `priority_updated_at`, `due_date_updated_at`, `list_updated_at`
- **notes**: `title_updated_at`, `content_updated_at`, `date_updated_at`, `period_updated_at`, `status_updated_at`, `list_updated_at`
- **collections**: `title_updated_at`
- **settings**: `bujo_mode_updated_at`, `first_weekday_updated_at`
- **task_assignments**: `status_updated_at`
- **note_assignments**: `status_updated_at`
- **lists**: `name_updated_at`
- **tags**: `name_updated_at`

`task_tags` and `note_tags` have no field-level LWW columns (they are
presence-only join rows; conflict resolution is delete-wins via
`deleted_at`/`revision`).

### CHECK Constraints

| Table | Field | Constraint |
|-------|-------|------------|
| spreads, notes, note_assignments, task_assignments | `period` | `year`, `month`, `day`, `multiday` |
| tasks | `period` | `NULL` or one of `year`, `month`, `day`, `multiday` |
| tasks, task_assignments | `status` | `open`, `complete`, `migrated`, `cancelled` |
| notes, note_assignments | `status` | `active`, `migrated` |
| tasks | `priority` | `none`, `low`, `medium`, `high` |
| settings | `bujo_mode` | `conventional`, `traditional` |
| settings | `first_weekday` | `1` to `7` |
| spreads | multiday dates | `start_date`/`end_date` both set when `period = 'multiday'`, both `NULL` otherwise |
| lists | `name` | non-empty after trimming whitespace |
| tags | `name` | non-empty after trimming whitespace |

### Unique Constraints

| Table | Constraint | Condition |
|-------|------------|-----------|
| spreads | `(user_id, period, date)` | `period != 'multiday'` and not deleted |
| spreads | `(user_id, start_date, end_date)` | `period = 'multiday'` and not deleted |
| settings | `user_id` | One settings row per user |
| task_assignments | `(user_id, task_id, period, date)` | `spread_id IS NULL` and not deleted |
| task_assignments | `(user_id, task_id, spread_id)` | `spread_id IS NOT NULL` and not deleted |
| note_assignments | `(user_id, note_id, period, date)` | `spread_id IS NULL` and not deleted |
| note_assignments | `(user_id, note_id, spread_id)` | `spread_id IS NOT NULL` and not deleted |
| task_tags | `(task_id, tag_id)` | Primary key |
| note_tags | `(note_id, tag_id)` | Primary key |

### Foreign Keys

| Table | Column | References | On Delete |
|-------|--------|------------|-----------|
| task_assignments | `task_id` | `tasks.id` | CASCADE |
| task_assignments | `spread_id` | `spreads.id` | SET NULL |
| note_assignments | `note_id` | `notes.id` | CASCADE |
| note_assignments | `spread_id` | `spreads.id` | SET NULL |
| tasks | `list_id` | `lists.id` | SET NULL |
| notes | `list_id` | `lists.id` | SET NULL |
| lists | `user_id` | `auth.users.id` | CASCADE |
| tags | `user_id` | `auth.users.id` | CASCADE |
| task_tags | `task_id` | `tasks.id` | CASCADE |
| task_tags | `tag_id` | `tags.id` | CASCADE |
| task_tags | `user_id` | `auth.users.id` | CASCADE |
| note_tags | `note_id` | `notes.id` | CASCADE |
| note_tags | `tag_id` | `tags.id` | CASCADE |
| note_tags | `user_id` | `auth.users.id` | CASCADE |

### Indexes

All entity tables have indexes for efficient sync queries:
- `(user_id, revision)` - Incremental sync by revision (`(revision)` only for `lists`/`tags`/`task_tags`/`note_tags`)
- `(user_id, deleted_at)` - Filter active vs deleted records (entity tables only)

Additional indexes:
- `task_assignments(task_id)`, `task_assignments(spread_id)` - FK lookups
- `note_assignments(note_id)`, `note_assignments(spread_id)` - FK lookups
- `task_tags(task_id)`, `task_tags(tag_id)` - FK lookups
- `note_tags(note_id)`, `note_tags(tag_id)` - FK lookups
- `lists(user_id)`, `tags(user_id)` - FK lookups

### RLS Policies

All 11 tables have RLS enabled.

| Tables | Policy Count | Shape |
|--------|---------------|-------|
| `collections`, `notes`, `note_assignments`, `settings`, `spreads`, `tasks`, `task_assignments` | 4 each | Separate `SELECT`/`INSERT`/`UPDATE`/`DELETE` policies, each `auth.uid() = user_id` |
| `lists`, `tags`, `task_tags`, `note_tags` | 1 each | Single `FOR ALL` policy, `auth.uid() = user_id` |

**Service role** bypasses RLS by default for admin/cleanup operations.

### Triggers and Revision Sequence

**Global revision sequence** (`next_revision()`) provides monotonic versioning for incremental sync.

Each table has a `BEFORE INSERT OR UPDATE` trigger function (e.g.
`tasks_trigger_fn`, `spreads_trigger_fn`, `notes_trigger_fn`,
`settings_trigger_fn`, `collections_trigger_fn`, `task_assignments_trigger_fn`,
`note_assignments_trigger_fn`) that:
- Assigns next `revision` from `next_revision()`
- Sets `updated_at` to current timestamp (where the table has `updated_at`)
- On INSERT: initializes all `*_updated_at` fields
- On UPDATE: only updates `*_updated_at` for fields that actually changed

`lists`, `tags`, `task_tags`, and `note_tags` have their own revision-assigning
triggers but do not maintain `updated_at`.

### Merge RPCs

Merge functions implement field-level last-write-wins (LWW) conflict resolution:

| Function | Table |
|----------|-------|
| `merge_spread()` | spreads |
| `merge_task()` | tasks |
| `merge_note()` | notes |
| `merge_collection()` | collections |
| `merge_settings()` | settings |
| `merge_task_assignment()` | task_assignments |
| `merge_note_assignment()` | note_assignments |
| `merge_list()` | lists |
| `merge_tag()` | tags |
| `merge_task_tag()` | task_tags |
| `merge_note_tag()` | note_tags |

**Merge behavior:**
1. If record doesn't exist → INSERT
2. If incoming `deleted_at` is newer → apply delete (delete-wins)
3. Otherwise → field-level LWW merge (newer timestamp wins per field), or
   presence-only delete-wins merge for join tables (`task_tags`/`note_tags`)
4. Returns canonical row as JSON

All merge RPCs use `SECURITY DEFINER` and validate `user_id = auth.uid()`.

## Tombstone Cleanup Job

Soft-deleted rows (`deleted_at IS NOT NULL`) older than 90 days are permanently removed by a scheduled PostgreSQL function.

### Prerequisites

- **`pg_cron` extension** must be enabled. The migration handles this automatically (`CREATE EXTENSION IF NOT EXISTS pg_cron`), or enable it manually via Dashboard > Database > Extensions.

### How It Works

- **Function**: `cleanup_tombstones()` — `SECURITY DEFINER` function that bypasses RLS and hard-deletes expired tombstones from all 11 tables.
- **Schedule**: Runs daily at 03:00 UTC via `pg_cron`.
- **Deletion order**: Join tables and child assignments first (`task_tags`, `note_tags`, `task_assignments`, `note_assignments`), then parent entries (`tasks`, `notes`), then other entities (`spreads`, `collections`, `settings`, `lists`, `tags`).

### Manual Verification

```sql
-- Check cron job is registered
SELECT * FROM cron.job WHERE jobname = 'cleanup-tombstones';

-- Check recent job runs
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'cleanup-tombstones')
ORDER BY start_time DESC
LIMIT 5;

-- Create a test tombstone older than 90 days (use a test user)
UPDATE tasks
SET deleted_at = now() - interval '91 days'
WHERE id = '<test-task-id>';

-- Run cleanup manually
SELECT cleanup_tombstones();

-- Verify the row was removed
SELECT * FROM tasks WHERE id = '<test-task-id>';
```

### Disabling the Job

```sql
-- Unschedule the cron job
SELECT cron.unschedule('cleanup-tombstones');
```

## Troubleshooting

### Configuration Not Loading

1. Ensure xcconfig files are linked to the Xcode project:
   - Project > Info > Configurations
   - Set Debug configuration to use `Debug.xcconfig`
   - Set Release configuration to use `Release.xcconfig`

2. Clean build folder: Product > Clean Build Folder (Cmd+Shift+K)

### Auth Issues

1. Verify email/password auth is enabled in Supabase Dashboard:
   - Authentication > Providers

### Migration Failures

1. Check migration file syntax
2. Ensure migrations are applied in order
3. Review Supabase Dashboard > Database > Migrations for status

## Related Tasks

- SPRD-80: Initial Supabase setup (this document)
- SPRD-81: Database schema + migrations
- SPRD-82: RLS policies
- SPRD-83: DB triggers + merge RPCs
- SPRD-84: Supabase client + auth integration
- SPRD-89: Tombstone cleanup job (90-day cron)
- SPRD-239: Squash migrations to a single baseline matching `spread-prod` and remove dev-bootstrap machinery
