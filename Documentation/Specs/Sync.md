# Sync

> Source: Documentation/spec.md

### Supabase Sync + Auth (v1)
- Supabase environments: separate dev and prod projects. Release builds are locked to prod. QA builds are locked to dev. Debug builds default to dev and may be launched in `localhost` for a single run via debug launch configuration or launch arguments. [SPRD-80, SPRD-105, SPRD-107]
- Runtime data-environment switching is not part of v1. There is no in-app environment switcher, no persisted environment selection, and no soft-restart flow for environment changes. [SPRD-105]
- `localhost` is Debug-only, non-persistent, and intended exclusively for engineering workflows such as UI development, debug overrides, and mock data loading. [SPRD-107]
- Auth in product environments is email/password only for v1. Sign in with Apple and Google are out of scope. [SPRD-104, SPRD-108]
- Product usage requires authentication. If no valid product-environment session exists on launch, the app presents an auth gate before journal content is accessible. [SPRD-106]
- In Debug `localhost`, auth is bypassed automatically with a mock user and the app opens directly into journal content. [SPRD-107]
- Sign-up and forgot-password flows remain in-app in product environments. [SPRD-106]
- Sign-out wipes the local store and returns the user to the auth gate. [SPRD-106]
- Sync: field-level last-write-wins (server-arrival time), per-field timestamps set by DB triggers, monotonic revision per table for incremental sync, soft-delete with 90-day cleanup, delete wins conflicts, and device_id recorded on writes. [SPRD-81, SPRD-83, SPRD-85, SPRD-89]
- Data integrity: unique constraints for spreads/assignments, foreign keys enforced, and RLS policies restrict rows to `auth.uid()`. [SPRD-81, SPRD-82]
- Sync status semantics:
  - Debug `localhost`: `localOnly`.
  - Authenticated dev/prod: normal sync states (idle/syncing/synced/offline/error). [SPRD-85, SPRD-107]
- Data environment resolution:
  - Debug supports `-DataEnvironment localhost` for that launch only.
  - Debug without an override defaults to `development`.
  - QA defaults to `development`.
  - Release defaults to `production`. [SPRD-105, SPRD-107]
- `localhost` selection is never persisted across launches.
- Launch-time wipe protection remains only for `localhost` isolation: if the resolved environment changes to or from `localhost`, the local store is wiped before app startup so mock/debug data cannot contaminate dev-backed local state. [SPRD-105, SPRD-107]
- Architecture expectations:
  - Core services expose protocols and accept injected policies (Sync/Auth/Network) to keep debug logic out of production files.
  - Debug overrides live under `Spread/Debug` and are compiled only in Debug/QA builds.
  - Minimize `#if DEBUG` inside core services; prefer debug-only extensions/policy files.

### Sync Conflict Scenarios
- **Duplicate spread creation**: Two devices create a spread with the same period + normalized date. The server's unique constraint (`user_id, period, date`) causes the second push to fail. The merge RPC detects the existing row and applies field-level LWW to update any differing fields; the client receives the canonical row and updates its local copy. No duplicate is created. [SPRD-81, SPRD-83]
- **Concurrent task migration**: Two devices migrate the same task to different spreads. Both pushes succeed because they create different assignment rows. The task ends up with assignments on both destination spreads. The source assignment is marked migrated by whichever push arrives first; the second push's LWW timestamp for the source assignment status is compared and the later write wins. [SPRD-83]
- **Concurrent field edits**: Two devices edit different fields of the same entity (e.g., one changes title, another changes status). Each field has its own `*_updated_at` timestamp; both edits are preserved because LWW is per-field, not per-row. [SPRD-83]
- **Delete wins**: If one device deletes an entity while another edits it, the delete (`deleted_at` timestamp) wins regardless of field-level timestamps. The entity is soft-deleted on all devices after the next pull. [SPRD-83]
- **Merge RPC response**: All merge RPCs return the canonical row after applying LWW, so the client can update its local copy to match the server's resolved state. [SPRD-83]

### Outbox Mutation Coalescing
- The outbox holds at most one unsent `SyncMutation` row per `(entityType, entityId)`. Enqueuing a mutation for an entity that already has an unsent row updates that row in place rather than appending a new one. [SPRD-253]
- This is safe because each mutation's `recordData` is a full entity snapshot, not a field-delta — the latest pending mutation already supersedes any earlier unsent one for that entity. [SPRD-253]
- Operation precedence on coalescing: an unsent `create` is never downgraded to `update` by a later mutation — it stays `create` with the latest data. A `delete` always wins outright and replaces any prior unsent mutation for that entity, regardless of arrival order. [SPRD-253]
- Coalescing only applies to currently-unsent rows. Once `SyncEngine.push()` successfully pushes and deletes a row, the next mutation for that entity starts a fresh row. [SPRD-253]
- Remote sync continues to be triggered independently of the outbox write (auto-sync on launch/foreground/reconnect, or manual `syncNow()`) — coalescing only reduces how many rows accumulate per entity while offline, it does not change when or how often a push attempt happens. [SPRD-253]
