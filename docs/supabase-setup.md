# Supabase Setup Guide

This document covers the Supabase configuration for the Spread app, including environment setup, CLI usage, and migrations workflow.

## Environments

The app uses two Supabase projects:

| Environment | Project Name | Project URL | Purpose |
|-------------|--------------|-------------|---------|
| Development | spread-dev | `https://apblzzondjcughtgqowd.supabase.co` | Local development, testing |
| Production | spread-prod | `https://nzsswqmxodkvgsnabnaj.supabase.co` | App Store releases |

## Build Configuration

Supabase configuration is managed via xcconfig files:

- `Configuration/Debug.xcconfig` - Uses dev environment
- `Configuration/Release.xcconfig` - Uses prod environment

These values are injected into `Info.plist` at build time and read by `SupabaseConfiguration.swift` at runtime.

### Debug Environment Switching

In Debug builds, the Supabase environment can be switched at runtime via the Debug menu (see SPRD-86). This allows testing against production data without rebuilding.

**Warning:** Switching to production in Debug builds requires explicit confirmation due to the risk of affecting real user data.

## Auth Providers

### Currently Enabled
- **Email/Password** - Basic authentication

### Deferred to SPRD-91
- **Sign in with Apple** - Requires Apple Developer account configuration
- **Google Sign-in** - Requires Google Cloud OAuth setup

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
# Link to dev project
supabase link --project-ref apblzzondjcughtgqowd

# Or link to prod (use with caution)
supabase link --project-ref nzsswqmxodkvgsnabnaj
```

## Migrations Workflow

### Creating Migrations

```bash
# Create a new migration file
supabase migration new <migration_name>

# Example
supabase migration new create_spreads_table
```

This creates a file in `supabase/migrations/` with a timestamp prefix.

### Writing Migrations

Edit the generated SQL file in `supabase/migrations/`:

```sql
-- Example: supabase/migrations/20260126000000_create_spreads_table.sql

CREATE TABLE spreads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    -- ... more columns
);

-- Enable RLS
ALTER TABLE spreads ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Users can only access their own spreads"
    ON spreads FOR ALL
    USING (auth.uid() = user_id);
```

### Applying Migrations

```bash
# Apply to linked project (dev)
supabase db push

# Or apply to a specific project
supabase db push --project-ref apblzzondjcughtgqowd
```

### Pulling Remote Schema

```bash
# Pull current schema from remote
supabase db pull
```

### Diffing Changes

```bash
# Compare local migrations with remote schema
supabase db diff
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
    "supabase-dev": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-supabase", "--project-ref", "apblzzondjcughtgqowd"]
    }
  }
}
```

## Local Development

### Running Supabase Locally (Optional)

For fully offline development:

```bash
# Start local Supabase
supabase start

# Stop local Supabase
supabase stop
```

This requires Docker and provides a local PostgreSQL, Auth, and Storage instance.

### Environment Variables

For local testing, you can override the Supabase configuration via environment variables or launch arguments:

```bash
# Via environment variable
export SUPABASE_URL="http://localhost:54321"

# Via Xcode launch argument
-SUPABASE_URL http://localhost:54321
```

## Database Schema

Schema created in SPRD-81. Migration: `20260127041350_create_core_entities`

### Tables Overview

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `spreads` | Journaling pages tied to time periods | `period`, `date`, `start_date`, `end_date` |
| `tasks` | Assignable entries with status | `title`, `date`, `period`, `status` |
| `notes` | Assignable entries with content | `title`, `content`, `date`, `period`, `status` |
| `task_assignments` | Per-spread status for tasks | `task_id`, `period`, `date`, `status` |
| `note_assignments` | Per-spread status for notes | `note_id`, `period`, `date`, `status` |
| `collections` | Plain text pages | `title` |
| `settings` | User preferences (one row per user) | `bujo_mode`, `first_weekday` |

### Common Columns (All Tables)

All tables include these columns for sync:

| Column | Type | Purpose |
|--------|------|---------|
| `id` | `uuid` | Primary key (auto-generated) |
| `user_id` | `uuid` | Owner of the record |
| `device_id` | `uuid` | Device that created/modified the record |
| `created_at` | `timestamptz` | When record was created |
| `updated_at` | `timestamptz` | When record was last modified |
| `deleted_at` | `timestamptz` | Soft delete timestamp (null = active) |
| `revision` | `bigint` | Monotonic version for incremental sync |

### Field-Level LWW Timestamps

Each table has per-field `*_updated_at` columns for field-level last-write-wins conflict resolution:

- **spreads**: `period_updated_at`, `date_updated_at`, `start_date_updated_at`, `end_date_updated_at`
- **tasks**: `title_updated_at`, `date_updated_at`, `period_updated_at`, `status_updated_at`
- **notes**: `title_updated_at`, `content_updated_at`, `date_updated_at`, `period_updated_at`, `status_updated_at`
- **collections**: `title_updated_at`
- **settings**: `bujo_mode_updated_at`, `first_weekday_updated_at`
- **task_assignments**: `status_updated_at`
- **note_assignments**: `status_updated_at`

### CHECK Constraints

| Table | Field | Allowed Values |
|-------|-------|----------------|
| spreads, tasks, notes, assignments | `period` | `year`, `month`, `day`, `multiday` |
| tasks, task_assignments | `status` | `open`, `complete`, `migrated`, `cancelled` |
| notes, note_assignments | `status` | `active`, `migrated` |
| settings | `bujo_mode` | `conventional`, `traditional` |
| settings | `first_weekday` | `1` to `7` |
| spreads | multiday dates | `start_date`/`end_date` required when `period = 'multiday'` |

### Unique Constraints

| Table | Constraint | Condition |
|-------|------------|-----------|
| spreads | `(user_id, period, date)` | `period != 'multiday'` and not deleted |
| spreads | `(user_id, start_date, end_date)` | `period = 'multiday'` and not deleted |
| settings | `user_id` | One settings row per user |
| task_assignments | `(user_id, task_id, period, date)` | Not deleted |
| note_assignments | `(user_id, note_id, period, date)` | Not deleted |

### Foreign Keys

| Table | Column | References | On Delete |
|-------|--------|------------|-----------|
| task_assignments | `task_id` | `tasks.id` | CASCADE |
| note_assignments | `note_id` | `notes.id` | CASCADE |

### Indexes

All tables have indexes for efficient sync queries:
- `(user_id, revision)` - Incremental sync by revision
- `(user_id, deleted_at)` - Filter active vs deleted records

Assignment tables have additional indexes:
- `(task_id)` / `(note_id)` - FK lookup

### RLS Policies

RLS enabled in SPRD-82. Migration: `20260127042003_enable_rls_policies`

All 7 tables have RLS enabled with 4 policies each:

| Policy | Command | Condition |
|--------|---------|-----------|
| Select own rows | `SELECT` | `auth.uid() = user_id` |
| Insert own rows | `INSERT` | `auth.uid() = user_id` (WITH CHECK) |
| Update own rows | `UPDATE` | `auth.uid() = user_id` (USING + WITH CHECK) |
| Delete own rows | `DELETE` | `auth.uid() = user_id` |

**Service role** bypasses RLS by default for admin/cleanup operations.

### Triggers and Revision Sequence

Added in SPRD-83. Migration: `20260127042413_add_triggers_and_merge_rpcs`

**Global revision sequence** (`sync_revision_seq`) provides monotonic versioning for incremental sync.

Each table has a `BEFORE INSERT OR UPDATE` trigger that:
- Assigns next `revision` from global sequence
- Sets `updated_at` to current timestamp
- On INSERT: initializes all `*_updated_at` fields
- On UPDATE: only updates `*_updated_at` for fields that actually changed

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

**Merge behavior:**
1. If record doesn't exist → INSERT
2. If incoming `deleted_at` is newer → apply delete (delete-wins)
3. Otherwise → field-level LWW merge (newer timestamp wins per field)
4. Returns canonical row as JSON

All merge RPCs use `SECURITY DEFINER` and validate `user_id = auth.uid()`.

## Troubleshooting

### Configuration Not Loading

1. Ensure xcconfig files are linked to the Xcode project:
   - Project > Info > Configurations
   - Set Debug configuration to use `Debug.xcconfig`
   - Set Release configuration to use `Release.xcconfig`

2. Clean build folder: Product > Clean Build Folder (Cmd+Shift+K)

### Auth Issues

1. Verify auth providers are enabled in Supabase Dashboard:
   - Authentication > Providers

2. Check redirect URLs are configured for OAuth providers

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
- SPRD-86: Debug environment switcher
- SPRD-91: Apple + Google auth providers (deferred)
