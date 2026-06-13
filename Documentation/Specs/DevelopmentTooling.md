# Development Tooling

> Source: Documentation/spec.md

### Development Tooling
- Debug UI is available only in Debug and QA TestFlight builds; Release builds have no debug destinations or data-loading actions. [SPRD-45]
- Replace the debug overlay with a dedicated Debug destination:
  - iPadOS (regular width): sidebar item titled "Debug" with SF Symbol `ant`. [SPRD-45]
  - iOS (compact width): tab bar item titled "Debug" with SF Symbol `ant`. [SPRD-45]
- Debug menu provides grouped sections with labels and descriptions:
  - Environment and dependency summary. [SPRD-2, SPRD-3, SPRD-45]
  - Sync/network/auth override controls for engineering verification. [SPRD-85A, SPRD-85C]
- Mock data sets are generated in code (no external fixtures) and cover varied spread scenarios and edge cases (empty, standard year/month/day, multiday ranges, boundary dates, large volume/perf). [SPRD-46]
- Mock data set loading uses JournalManager APIs to mirror app behavior; loading or clearing data refreshes UI and resets selection to today's spread when available. [SPRD-67]
- Mock data set loading is available only in Debug `localhost`. It is not available in Debug dev, QA, or Release. [SPRD-107]
- Debug menu provides appearance overrides for paper tone, dot grid (size/spacing/opacity), heading font, and accent color (DEBUG builds only). [SPRD-63]
- Debug tooling files live under `Spread/Debug` to keep debug-only views/data isolated. [SPRD-45]
- There is no in-app environment switcher in v1. Environment selection for `localhost` is done before launch in Debug only. [SPRD-105, SPRD-107]
- Debug functionality should be visible only inside the Debug destination (no always-on overlay/badge).
- Debug behavior should be isolated from production code via protocols + dependency injection:
  - Core services (Sync/Auth/Network) expose protocols and default policies in non-debug files.
  - Debug overrides live under `Spread/Debug` as separate policy implementations compiled only in Debug/QA builds.
  - Avoid sprinkling `#if DEBUG` inside core services; prefer debug-only extensions/policy files.
- Debug menu provides Sync & Network overrides (DEBUG builds only) to mock runtime states:
  - Block all network connections (force NWPathMonitor offline and fail requests).
  - Disable sync while keeping network available.
  - Force sign-in auth errors: invalid credentials, email not confirmed, user not found, rate limited, network timeout.
  - Force sync UI states: "syncing" pinned for 5s with engine paused; whole-sync failure error injection.
  - Seed outbox with real `SyncMutation` rows to simulate backlog.
  - Scenario presets that apply multiple overrides at once plus manual toggles/sliders.
  - Live sync readout (network status, last sync time, outbox count, current sync error).
  - Override persistence across relaunch is not required.

### Testing
- Automated testing is split between deterministic unit tests for isolated logic and localhost-backed UI scenario tests for user-visible flows. [SPRD-113, SPRD-114]
- Logic-heavy user scenarios must be exercised through Debug `localhost` launches with seeded mock data and deterministic temporal context. The shared harness must support both startup-fixed temporal context and runtime-controlled AppClock changes so scenarios can verify behavior before and after day/time/context transitions without relaunching. [SPRD-114, SPRD-181]
- UI scenario tests are additive to existing unit coverage; they do not replace unit tests for JournalManager, assignment logic, migration revalidation, or overdue computation. [SPRD-114]
- Scenario UI tests focus on conventional-mode logic-heavy flows first: assignment fallback, Inbox resolution, migration prompting/review, overdue badge visibility, and edit-time reassignment. [SPRD-114]
- UI scenario fixtures may seed the starting state, but the user action under test must still be performed through the UI. [SPRD-114]
- A shared localhost scenario harness is required for UI tests. It must centralize:
  - app launch with `localhost`, scenario dataset selection, and startup-fixed temporal context
  - runtime AppClock controls for advancing time and changing time zone/locale/calendar context during a running scenario
  - spread navigation
  - migration banner/review interactions
  - overdue badge interactions
  - common assertions for relocated tasks, source sections, and migrated-history visibility
- The UI scenario suite should stay organized by logic area instead of by fixture: assignment, reassignment, migration, and overdue each get their own test class backed by the shared harness.
- Scenario-only mock data sets may live in the same in-code catalog as debug mock data, but test-only cases must be hidden from normal debug-menu browsing. [SPRD-114]
- Scenario-test-critical UI must expose explicit accessibility identifiers instead of relying only on visible copy. This includes:
  - migration banner, review sheet, section headers, rows, selection controls, and confirm action
  - overdue badge counts, visibility, and selected-spread coexistence
  - any supporting source/destination labels needed to assert assignment and migration outcomes
- UI scenario assertions should prefer user-visible outcomes. Localhost-only debug inspection may be used only when the UI cannot distinguish a required state clearly enough. [SPRD-114]
- Focused unit tests still backstop exclusion-only and revalidation-heavy rules where UI coverage would otherwise become brittle, but user-visible scenario coverage remains the primary integration signal for assignment, migration, reassignment, and overdue.
- AppClock coverage is required at multiple levels:
  - unit tests for temporal-context refresh classification, day-boundary detection, and notification/lifecycle bridging
  - unit tests for pure rule helpers receiving explicit temporal input
  - JournalManager/view-model tests proving temporal refresh updates shared semantics without mutating user selection unexpectedly
  - localhost UI scenarios where the app remains open while time crosses midnight or temporal context changes
  - regression tests proving open forms keep their draft/default state stable while surrounding display semantics update [SPRD-179, SPRD-180, SPRD-181]
- Scenario coverage matrix required for v1: [SPRD-114, SPRD-115, SPRD-116, SPRD-117, SPRD-118]

| Scenario area | Required localhost UI coverage | Key assertion |
| --- | --- | --- |
| Creation-time assignment | Creating a task on a created matching spread assigns it directly there. | The new task appears on the selected spread without using Inbox or migration UI. |
| Inbox fallback | Creating a task when no matching spread exists routes it to Inbox. | The task is absent from spread content, present in Inbox, and can be identified by desired assignment. |
| Inbox auto-resolution | A task seeded in Inbox becomes migration-eligible when a valid year/month/day spread is later created. | The destination spread exposes migration UI for that task and the task can be moved out of Inbox from the review sheet. |
| Desired-assignment-bounded migration | A month-desired task on `2026` prompts on `January 2026` but not `January 10, 2026`. | Only the valid month destination shows migration UI. |
| Most-granular-valid destination | A day-desired task on `2026` prompts on `January 2026` only until `January 10, 2026` exists, then only the day spread prompts. | The coarser prompt disappears once the finer valid destination exists. |
| Migration review flow | Conventional migration banner opens a sheet with eligible tasks preselected and sectioned by source. | Source and destination labels are visible, default selection is correct, and confirm migrates the selected tasks. |
| Migration post-submit behavior | After migration, the review sheet updates in place and only dismisses when no eligible tasks remain. | Remaining rows stay visible; fully resolved sheets dismiss automatically. |
| Edit-time reassignment | Editing a task's preferred date/period relocates it according to conventional reassignment rules. | The task appears on the new destination, disappears from the active list on the old spread, and appears in migrated history there. |
| Overdue day threshold | Day-assigned open tasks become overdue after the assigned day passes. | The assigned spread's navigator item shows the overdue count badge. |
| Overdue month/year thresholds | Month- and year-assigned tasks become overdue only after the full assigned period passes. | Navigator badge counts change only at the defined absolute-date boundaries. |
| Inbox overdue fallback | Inbox tasks become overdue from their desired assignment when no open spread assignment exists. | No spread badge is shown until the task has an open spread assignment; Inbox overdue items remain discoverable through the search tab's Inbox section. |
| Overdue badge flow | Overdue signaling is passive in the spread title navigator rather than a toolbar-sheet flow. | Count and visibility remain correct from any spread context without introducing a special review interaction. |
| Note exclusions | Notes never appear in migration or overdue navigator surfaces. | Migration review exclusion is covered in UI; overdue exclusion is backstopped by focused unit tests because notes should not contribute to spread badge counts. |
| Traditional-mode parity check | Traditional mode still has no migration UI. | Traditional mode continues to omit migration controls; overdue navigator badge behavior applies only where the spread title navigator is shown. |
| Spread task row visual treatment | Main spread task lists keep a solid list backing while task rows remain transparent. | The spread dot-grid background remains visible behind the task-list surface instead of each task row rendering as an opaque card. |
| Task inline title editing | Tapping the title of a task row in a main spread list activates an inline text field for editing the title in place. | The row expands to show an editable text field in place of the title. A "×" cancel button appears. Tapping outside, pressing Return, or losing focus commits the change. Tapping "×" discards it. |
| Task full-sheet access | The full task edit sheet (title, date, period, status) is accessible via the swipe-action Edit button. | The edit sheet opens and pre-populates with the current task values. |
| Inline task creation | An "+ Add Task" button appears at the bottom of every spread's task list. Tapping it opens an inline input row with immediate keyboard focus. | The input row appears, a glass-effect toolbar above the keyboard shows Save and Cancel. Return saves the title and opens a new blank row. Save closes the input. Cancel or empty-field focus loss discards. The task is assigned to the spread's period and date. |
| Multiday empty-day visibility | A multiday spread shows a section for every day in its covered range even when no tasks exist for that day. | Empty dates still render a day header and explicit empty-state message. |
| Multiday adaptive layout | A multiday spread uses two columns on regular-width layouts and one column on compact layouts. | The same ordered set of day sections is visible in reading order on both size classes. |

- Durability and rebuild matrix required for v1: [SPRD-119, SPRD-120, SPRD-121, SPRD-122, SPRD-123]

| Scenario area | Required sync-enabled coverage | Key assertion |
| --- | --- | --- |
| Direct assignment durability | Create a task/note on an existing spread, sync, wipe local state, rebuild from server. | The entry returns on the same spread with the same assignment status/history. |
| Inbox fallback durability | Create a task/note with no matching spread so it lands in Inbox, sync, wipe local state, rebuild from server. | The entry returns in Inbox with the same desired assignment and no phantom spread assignment. |
| Migration durability | Migrate a task/note, sync, wipe local state, rebuild from server. | The destination remains active, the old spread no longer shows the entry in spread content, and assignment history survives rebuild. |
| Reassignment durability | Edit preferred date/period to trigger reassignment, sync, wipe local state, rebuild from server. | The entry appears on the same destination, disappears from the old spread content, and assignment history survives rebuild. |
| Spread deletion durability | Delete a spread that causes reassignment to parent or Inbox, sync, wipe local state, rebuild from server. | Reassigned destinations and preserved histories match the pre-wipe state exactly. |
| Cross-device parity | Apply assignment-changing actions on one signed-in client, then rebuild a second clean client from server data. | The second client reproduces the same visible placement and preserved assignment history without resurrecting source-spread content. |
| Assignment tombstone durability | Delete an entry or remove/supersede an assignment path, sync, wipe local state, rebuild from server. | Removed assignments do not reappear and surviving history remains intact. |
| Safe backfill recovery | Start from an entry with local assignment history and zero server assignment rows, run repair, then rebuild from server. | Full assignment history is backfilled once and survives subsequent rebuilds. |
| Note parity | Repeat durability/rebuild scenarios for notes where assignment behavior exists. | `note_assignments` round-trip with the same guarantees as `task_assignments`. |

- Sync-enabled durability coverage is distinct from pure `localhost` UI scenarios:
  - `localhost` remains the required environment for deterministic logic/UI-only scenario tests.
  - Assignment durability, repair, and rebuild scenarios must run in a sync-enabled integration or UI test layer because pure `localhost` cannot validate server persistence.
  - The preferred free-tier environment split is:
    - `localhost` for UI logic scenarios
    - local Supabase for destructive durability/rebuild/repair testing
    - remote `spread-dev` for shared hosted QA
    - remote `spread-prod` for production use
- Lower-level tests required alongside the user-facing rebuild scenarios: [SPRD-120, SPRD-121, SPRD-122]
  - durable assignment ID generation and persistence
  - assignment mutation enqueueing on every assignment-changing save path
  - assignment update vs create vs tombstone behavior
  - push ordering between parent entries and child assignments
  - exact pull/apply reconstruction of placement and history from server rows
- Device matrix:
  - iPhone is the default scenario-test device. [SPRD-114]
  - Add a targeted iPad subset only for scenarios where layout or navigation behavior differs materially from iPhone. [SPRD-114]
  - iPad UI test infrastructure (separate test plan configuration or device-specific test classes) does not yet exist. iPad-specific tests for features like the Today button [SPRD-130] are deferred until this infrastructure is established.

### Secrets and Configuration
- Supabase publishable (anon) keys and project URLs are stored in build-time xcconfig files. These are client-side keys protected by RLS policies; they are not service role keys.
- Configuration files:
  - `Configuration/Debug.xcconfig` — dev Supabase URL + key, `development` environment, `dev.johnnyo.Spread.debug` bundle ID.
  - `Configuration/QA.xcconfig` — dev Supabase URL + key (same as Debug), `development` environment, `dev.johnnyo.Spread.qa` bundle ID.
  - `Configuration/Release.xcconfig` — prod Supabase URL + key, `production` environment, `dev.johnnyo.Spread` bundle ID.
- `Info.plist` reads values via build variables: `$(SUPABASE_URL)`, `$(SUPABASE_PUBLISHABLE_KEY)`, `$(DATA_ENVIRONMENT)`.
- `SupabaseConfiguration.swift` resolves configuration with this priority:
  1. Debug-only launch selection of `-DataEnvironment localhost` for that run.
  2. Build configuration defaults (`development` for Debug/QA, `production` for Release).
  3. `DataEnvironment`-based hardcoded dev/prod fallbacks (in code).
  4. `Info.plist` build-time values (from xcconfig).
- `DataEnvironment.swift` contains hardcoded URLs and keys for dev/prod as fallback defaults.
- `.gitignore` blocks `.env` files but does not block `.xcconfig` files; publishable keys are committed to git (acceptable for client-side anon keys).
- Service role keys and other server-side secrets are never stored in the client codebase. They exist only in the Supabase dashboard and server-side infrastructure.

### Test/Debug Infrastructure Simplification

- `supabase/migrations/` is squashed to a single baseline migration reflecting the current `spread-prod` schema (`pg_dump --schema-only`), rather than a reconstructed migration history. Migration history discipline (incremental, reviewable migrations) is deferred until after v1 release, when schema changes against a live user base require it. [SPRD-239]
- Local Docker Supabase bootstraps from `supabase/migrations/` via plain `supabase db reset` — no dependency on dumping from a remote project at setup time. [SPRD-239]
- `spread-dev` is decommissioned as a backend, and the "QA" build configuration is removed entirely. Only Debug and Release configurations remain: Debug defaults to `localhost` (local-only, no backend), and Release defaults to `spread-prod`. [SPRD-240]
- A TestFlight build configuration is deferred until TestFlight distribution actually begins post-release. Because TestFlight installs are archived/standalone and cannot receive launch-arg overrides, such a configuration would necessarily be fixed to `spread-prod` with `allowsDebugUI = true` — effectively Release plus a visible debug menu. External TestFlight/App Store users should see the prod app with no testing functionality. [SPRD-240]
- The Debug-build destination's debug menu is split by concern:
  - A read-only data viewer (`DebugRepositoryListView` + environment/build-info readout) remains, for inspecting local state in Debug builds.
  - The runtime scenario-toggle/fault-injection panel (forced auth errors, sync status overrides, outbox seeding, scenario presets, network blocking) is removed entirely — it is not exercised by any automated test and is not part of the desired debug-build capability set. [SPRD-241]
- Where a protocol exists solely to support one production conformance and one now-removed debug conformance (e.g., `SyncPolicy` / `DefaultSyncPolicy` after `DebugSyncPolicy` is removed), the protocol pattern is preserved (for future test substitution) but the protocol and its sole conformance are co-located in a single file rather than split. [SPRD-241]
- `DebugAppearanceSettings` (and its `.shared` singleton, which violated the no-singleton architecture rule) is removed entirely, along with its debug-menu appearance override section. The app uses its production-defined appearance only. [SPRD-242]
- `MockDataSet` cases that are not referenced by any `SpreadUITests` scenario or required debug-menu picker entry are removed (currently: `highVolume`, `inboxNextYear`). [SPRD-243]

### Open Questions

- After `spread-dev` is decommissioned (SPRD-240), `DataEnvironment.development` and its associated `SupabaseConfiguration.KnownEnvironment.devURL`/`devKey` become dead (no build defaults to `.development`, and the dev project no longer exists). Re-audit `DataEnvironment`, `SupabaseConfiguration`'s explicit URL/key override path, and `lastUsed`/`requiresWipeOnLaunch` once SPRD-240 lands to confirm what (if anything) should be removed — deferred until that change's diff is visible. Owner: revisit in the session after SPRD-240.
