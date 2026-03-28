# Spread

A SwiftUI bullet journal app for iPhone and iPad with SwiftData local persistence and Supabase sync.

## Requirements

- macOS with Xcode `26.1.1`
- iOS / iPadOS `26.1` simulator runtime
- Homebrew
- Docker Desktop
- Python 3
- `jq`
- Supabase CLI
- PostgreSQL client tools (`psql`, `pg_dump`)

Recommended install commands:

```bash
brew install jq
brew install supabase/tap/supabase
brew install libpq
echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
```

If you use the GitHub workflows or local Supabase durability flow, Docker Desktop must be running before you start.

## Clone And Bootstrap

```bash
git clone <repo-url>
cd spread-app-ios
```

Local app development against the hosted dev backend works immediately after clone if the checked-in xcconfig values are valid for your team.

To enable the full development workflow, also create the local Supabase secret file:

```bash
cp supabase/.env.local.example supabase/.env.local
```

Then edit `supabase/.env.local` and set:

- `SUPABASE_DB_PASSWORD_DEV`
  - the remote database password for `spread-dev`
- `SPREAD_LOCAL_TEST_PASSWORD`
  - optional override for deterministic local test users

## Development Environments

Spread currently uses four practical environments:

| Environment | Backend | Purpose |
|---|---|---|
| Debug default | remote `spread-dev` | day-to-day development with real sync |
| Release | remote `spread-prod` | production behavior |
| Debug `localhost` | none | local-only UI and mock-data scenarios, no auth/sync |
| Local Supabase | local Docker stack | destructive durability, rebuild, and repair testing |

Important rules:

- `localhost` is engineering-only and bypasses product auth.
- Mock data loading is only available in `localhost`.
- Local Supabase testing keeps `DataEnvironment` on `development` and overrides only the Supabase URL/key.
- `spread-prod` should only be used for production validation and real-life use.

## Build And Run

Build:

```bash
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Run from Xcode:

1. Open [Spread.xcodeproj](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/Spread.xcodeproj)
2. Select the `Spread` scheme
3. Choose a simulator or device
4. Run

Default build behavior:

- `Debug` uses `spread-dev`
- `QA` uses `spread-dev`
- `Release` uses `spread-prod`

## Launch Arguments

### Debug Localhost

Use this for mock-data and UI-only scenarios:

```text
-DataEnvironment localhost
```

### Local Supabase Sync Testing

Use this for sync-enabled durability testing:

```text
-DataEnvironment development
-SupabaseURL <local api url>
-SupabaseKey <local anon key>
```

Get the exact values from:

```bash
./scripts/local-supabase.sh launch-args
```

## Local Supabase Workflow

This is required for durability, rebuild, and repair work.

One-time schema bootstrap from `spread-dev`:

```bash
./scripts/local-supabase.sh bootstrap-schema-from-dev
```

Daily workflow:

```bash
./scripts/local-supabase.sh start
./scripts/local-supabase.sh reset
./scripts/local-supabase.sh launch-args
```

Useful commands:

```bash
./scripts/local-supabase.sh status
./scripts/local-supabase.sh env
./scripts/local-supabase.sh provision-users
./scripts/local-supabase.sh stop
```

Generated local files:

- [supabase/local/public_schema_from_dev.sql](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/supabase/local/public_schema_from_dev.sql)
  - committed schema snapshot used for local restore
- [supabase/local/test.env](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/supabase/local/test.env)
  - generated local credentials and deterministic test-user values

Deterministic local users:

- `local-sync-1@spread.test`
- `local-sync-2@spread.test`

Default password:

- `spread-local-pass`

## Testing

Run the full suite:

```bash
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Run a specific test plan:

```bash
xcodebuild -scheme Spread -testPlan CoreBusinessLogic -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -scheme Spread -testPlan AllUITests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Run a specific test:

```bash
xcodebuild -scheme Spread -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SpreadTests/OverdueTaskTests test
```

What each layer is for:

- unit and app tests
  - normal local logic and sync behavior
- UI scenario tests
  - user-visible flows and scenario fixtures
- local Supabase durability flow
  - server-backed rebuild, repair, and destructive sync validation

Before destructive sync work, start and reset local Supabase first:

```bash
./scripts/local-supabase.sh start
./scripts/local-supabase.sh reset
```

## Supabase Workflows

Install and authenticate the CLI:

```bash
supabase login
supabase link --project-ref apblzzondjcughtgqowd
```

Common commands:

```bash
supabase migration new <name>
supabase db push
supabase db pull
supabase db diff
```

Remote projects in use:

- `spread-dev`
- `spread-prod`

Do not run destructive durability tests against the remote projects. Use local Supabase for those flows.

## CI And Secrets

The repo now includes a local Supabase smoke workflow:

- [.github/workflows/local-supabase-smoke.yml](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/.github/workflows/local-supabase-smoke.yml)

Required GitHub Actions secret:

- `SUPABASE_DB_PASSWORD_DEV`

Optional GitHub Actions secret:

- `SPREAD_LOCAL_TEST_PASSWORD`

Other CI workflows use:

- [.github/workflows/run-unit-tests.yml](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/.github/workflows/run-unit-tests.yml)
- [.github/workflows/pr_validation.yml](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/.github/workflows/pr_validation.yml)
- [.github/workflows/post-merge-validation.yml](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/.github/workflows/post-merge-validation.yml)

## Key Docs

- [Documentation/spec.md](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/Documentation/spec.md)
- [Documentation/plan.md](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/Documentation/plan.md)
- [docs/supabase-setup.md](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/docs/supabase-setup.md)
- [docs/local-supabase-testing.md](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/docs/local-supabase-testing.md)
- [docs/sync-qa-checklist.md](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/docs/sync-qa-checklist.md)
- [CLAUDE.md](/Users/johnnyo/Documents/2.Development/github.com_johnny-olszewski/spread-app-ios/CLAUDE.md)

## License

Copyright 2026. All rights reserved.
