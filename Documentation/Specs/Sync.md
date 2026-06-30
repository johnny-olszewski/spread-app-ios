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

### Batch Mutation Push [SPRD-276]

**Status**: Draft

#### Overview

`SyncEngine.push()` currently sends one RPC call per pending `SyncMutation`, sequentially, awaiting each round-trip before starting the next. For N pending mutations of the same entity type, that's N network round-trips where one would do. This batches all pending mutations of a given entity type into a single RPC call per sync pass (≤8 calls total — one per `SyncEntityType` case — down from N).

Mutation coalescing (per-entity, see "Outbox Mutation Coalescing" above) is unaffected and unrelated — it already collapses repeated edits to *the same entity* into one outbox row before this layer ever runs. This feature batches across *different* entities of the same type into one network call.

Deletes require no special handling: they are already expressed as a soft-delete (`deleted_at`) field inside the same merge RPC payload, so batching the merge call batches deletes for free.

#### Requirements

1. For each `SyncEntityType` with one or more pending mutations, `SyncEngine.push()` issues exactly one RPC call carrying all of that type's pending mutations, instead of one RPC call per mutation. [SPRD-276]
2. Each of the 8 existing `merge_*` Postgres functions (`merge_settings`, `merge_spread`, `merge_entry`, `merge_collection`, `merge_list`, `merge_tag`, `merge_assignment`, `merge_entry_tag`) gains a sibling `merge_X_batch(p_rows jsonb) RETURNS jsonb` function accepting a JSON array of the same per-row fields the scalar function already takes. [SPRD-276]
3. Within a batch call, one row's failure does not abort the rest of the batch — each row is processed in its own isolated exception block, and the function returns a per-row result array (`{"id":..., "success":true, "row":{...}}` or `{"id":..., "success":false, "error":"..."}`) so the client can selectively clear succeeded mutations and retry only failed ones. [SPRD-276]
4. Each row in a batch is still authorized independently via `auth.uid()` — there is no single batch-level trust boundary. [SPRD-276]
5. A whole-call failure (e.g. transport error, the RPC call itself throws) is treated the same as today's per-mutation failure: every mutation in that batch has its `retryCount` incremented and remains in the outbox for the existing exponential-backoff retry to pick up later. No local entity data is reverted or lost in either failure mode — local SwiftData writes are already final and independent of network success. [SPRD-276]
6. Mutations that fail local serialization (`buildMergeParams` returns nil for malformed `recordData`) are filtered out and deleted from the outbox before the batch is built, exactly as today's per-mutation logic does — this is unrelated to the new batching and behavior here is unchanged. [SPRD-276]
7. `Task.checkCancellation()` is preserved between entity-type batches (not per-row within a batch, since rows now travel together in one call). [SPRD-276]
8. The existing scalar `merge_X` functions are removed from `baseline_schema.sql` if no other caller exists after this change; if a caller is found, they are kept and noted. [SPRD-276]

#### Design Decisions

##### Decision: Batch via new `merge_X_batch` Postgres functions, not PostgREST's native bulk `upsert()`

- **Context**: PostgREST supports native bulk upsert via posting an array to a REST endpoint. This was evaluated as a simpler alternative to writing 8 new SQL functions.
- **Decision**: Add `merge_X_batch(p_rows jsonb)` functions that loop over the array server-side, reusing each existing `merge_X` function's per-row INSERT/UPDATE/field-level-LWW logic — not PostgREST's bulk `upsert()`.
- **Rationale**: PostgREST's native bulk upsert requires uniform row shape and has no support for per-field last-write-wins semantics or mixed insert/update/delete handling in one call — both of which the existing `merge_X` functions already implement per-row. The batch functions are a thin looping wrapper around proven per-row logic, not a reimplementation.
- **SPRD reference**: [SPRD-276]

##### Decision: Per-row exception isolation inside one transaction, not one transaction per row

- **Context**: A batch could process each row in its own transaction (matching the granularity of today's one-call-per-mutation behavior exactly) or all rows in one transaction with per-row exception handling.
- **Decision**: One RPC call (so one transaction) per entity type per sync pass, with each row wrapped in its own `BEGIN ... EXCEPTION WHEN OTHERS THEN ...` block inside that transaction so a single malformed row doesn't abort the others.
- **Rationale**: This is what makes the batching actually reduce round-trips — one transaction per row would still mean N database operations even if sent as one network call (no win). The per-row exception block preserves today's "one bad row doesn't block its siblings" behavior without losing the round-trip savings.
- **SPRD reference**: [SPRD-276]

##### Decision: Whole-batch network failure still blocks via existing backoff, not finer-grained retry

- **Context**: If the entire RPC call throws (e.g. the device loses signal mid-request), that failure could be handled by retrying only the batch, or by some finer per-row fallback.
- **Decision**: A whole-call failure increments `retryCount` and leaves all mutations in that batch in the outbox, exactly mirroring today's per-mutation failure behavior — the existing exponential backoff (2s → 4s → ... → 5min cap, reset on next success) is unchanged and applies at the same granularity as before.
- **Rationale**: This refactor's scope is reducing round-trip count when the network is healthy, not changing failure/retry semantics. A single bad *row* inside a successful batch call is now isolated (new behavior, requirement 3 above); a failure of the *entire call* is not finer-grained than before, since there's no way to know which rows would have succeeded without the call completing.
- **SPRD reference**: [SPRD-276]

##### Decision: One combined SPRD task for server + client changes

- **Context**: The server-side `merge_X_batch` functions and the client-side `SyncEngine.push()`/`SyncSerializer` changes touch different systems (live Supabase Postgres functions vs. local Swift code) and could in principle be split into two tasks landed independently.
- **Decision**: Track both under a single SPRD-276 task.
- **Rationale**: The client batching change is not independently useful or shippable without the server batch RPCs existing first — there's no meaningful intermediate state where landing one without the other provides value. Splitting would add task-tracking overhead with no real decoupling benefit.
- **SPRD reference**: [SPRD-276]

#### Open Questions

- Whether any screen currently shows the user a visible "not synced yet" indicator is worth checking separately — not part of this refactor's scope, since this refactor changes round-trip count, not what's shown to the user about sync state.
