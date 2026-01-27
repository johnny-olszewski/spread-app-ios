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

See SPRD-81 for the full schema definition including:
- Tables: `spreads`, `tasks`, `notes`, `task_assignments`, `note_assignments`, `collections`, `settings`
- Field-level timestamps for LWW conflict resolution
- RLS policies for user data isolation

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
