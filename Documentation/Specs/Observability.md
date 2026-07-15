# Observability

> **Status**: Draft
> **SPRD tasks**: SPRD-311
> **Session**: SESH-31

## Overview

Crash reporting, error logging, and product analytics for the MVP (decided 2026-07-12, `mvp-launch.md` §6.3): a **hybrid stack** — Firebase Crashlytics for crashes and non-fatal error reports (the one job Supabase cannot do), and a Supabase `analytics_events` table for product events so activation/retention/feature-adoption data lives in the app's own Postgres next to product data. Both sit behind injected protocols so the vendors are swappable, localhost/previews are no-ops, and nothing reports from development machines. Beta feedback without this telemetry is anecdotes; SESH-31 ships the infrastructure *and* the v1 event taxonomy so TestFlight starts with real signal.

---

## Requirements

### Protocols and injection [SPRD-311]

- `ErrorReporting` protocol (`report(_ error: Error, context: [String: String])` plus a lightweight breadcrumb `log(_ message: String)`), and `AnalyticsTracking` protocol (`track(_ event: AnalyticsEvent)`). Both constructed in `AppDependencies` factories and injected — protocols at boundaries, vendor swappable. [SPRD-311]
- Localhost and previews receive `Test*`-prefixed plain no-op implementations; unit tests use `Mock*` call-recording implementations — per the Test*/Mock* naming convention. Reporting is active only when `DataEnvironment.current == .production` (never from localhost; development TBD at implementation). [SPRD-311]
- OSLog remains the console/logging layer; reporting is additive, not a replacement. [SPRD-311]

### Crashlytics (crashes + non-fatal errors) [SPRD-311]

- Firebase SPM dependency, **Crashlytics product only** (no Firebase Analytics). `FirebaseApp.configure()` is isolated inside the live reporter's bootstrap — the one documented singleton exception, third-party requirement. [SPRD-311]
- `GoogleService-Info.plist` configured for the production app only; dSYM upload build phase added for symbolication (release-engineering step, documented in the task). [SPRD-311]
- Every user-facing error alert surfaced by SPRD-302/303/305 also reports as a non-fatal: task/note/settings/collections save failures, runtime-init failure, sync failures, enqueue failures, and outbox quarantine transitions (with entity type — never content). [SPRD-311]

### Supabase product events [SPRD-311]

- New `analytics_events` table: `id uuid pk`, `user_id uuid`, `name text`, `properties jsonb`, `created_at timestamptz`; RLS: insert-only for the authenticated user's own rows, no client select. Folded into the squashed `baseline_schema.sql` and applied to `spread-prod` (additive; pre-release squash policy). [SPRD-311]
- Events buffer locally in a lightweight persisted queue and flush in batches (bulk insert) when connectivity allows — **deliberately separate from the `SyncMutation` outbox** (see Decision). Flush failures retry later; analytics loss is acceptable, product-sync interference is not. [SPRD-311]

### v1 event taxonomy [SPRD-311]

- A type-safe `AnalyticsEvent` enum — no stringly-typed call sites; event names are stable snake_case strings derived from cases. v1 set: `session_start`, `spread_created` (property: period), `task_created`, `note_created`, `task_completed`, `task_migrated` (property: source→destination granularity), `time_sort_selected`. [SPRD-311]
- **No PII**: titles, bodies, names, and dates never leave the device; properties are enum-derived strings and counts only. [SPRD-311]
- Activation metrics (first spread/task created) are **derived server-side** from each user's earliest event — no client-side "first time" state. [SPRD-311]

---

## Design Decisions

### Decision: Hybrid Crashlytics + Supabase events (not all-Firebase, not Google-free)

- **Context**: The MVP needs crash signal during beta and product analytics the developer owns. Supabase has no crash reporting; MetricKit's delayed delivery and manual symbolication are weakest exactly when beta needs crash signal most; all-Firebase puts product events in Google's console.
- **Decision**: Crashlytics for crashes/non-fatals; Supabase `analytics_events` for product events. One new SDK, product data stays in the app's Postgres.
- **Rationale**: Each tool does the one job the other can't. Decided 2026-07-12 over all-Firebase and Supabase+MetricKit.
- **SPRD reference**: SPRD-311

### Decision: Analytics queue is separate from the sync outbox

- **Context**: The `SyncMutation` outbox is the product-data durability mechanism, now with quarantine semantics (SPRD-305). Analytics events also need offline buffering.
- **Decision**: A dedicated lightweight buffer (own SwiftData model, batch-flushed), not `SyncMutation` rows.
- **Rationale**: Analytics must never compete with, stall, or complicate product sync; loss tolerance differs (dropping an analytics batch is acceptable, dropping a task edit is not); and the outbox's per-entity merge machinery is meaningless for append-only events.
- **SPRD reference**: SPRD-311

### Decision: Client sends events; server derives insights

- **Context**: Activation funnels ("first task created") could be computed on-device or in SQL.
- **Decision**: The client emits plain occurrence events only; firsts/funnels/retention are SQL over `analytics_events`.
- **Rationale**: Keeps client logic dumb and stateless, avoids client/server double-truth, and lets analysis evolve without app releases.
- **SPRD reference**: SPRD-311

---

## Open Questions

- Does the `development` DataEnvironment report to Crashlytics (separate Firebase app) or stay silent? Default: silent — revisit if beta debugging needs it.
- Event-volume guardrails (max buffered events, flush cadence) — pick pragmatic constants during implementation.
- Whether `session_start` should carry app-version/OS properties or rely on Crashlytics for environment breakdowns — decide during implementation.
