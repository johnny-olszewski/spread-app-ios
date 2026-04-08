# Bulleted Implementation Plan (v1.0)

## Scope Update
- Events are deferred to v2; v1 ships without event creation or display. [SPRD-69]
- Existing event scaffolding must be stubbed/hidden for v1 and kept ready for v2 integration. [SPRD-69]
- Supabase offline-first sync replaces CloudKit for v1; CloudKit configuration tasks remain for history but are superseded by the Supabase migration. [SPRD-80]
- Product usage in dev/prod now requires authentication; guest/local-only product usage is removed from v1. [SPRD-104, SPRD-106]
- Backup entitlement is removed from v1; authenticated users can sync without a purchase gate. [SPRD-104]
- Sign in with Apple and Google are removed from v1 scope; auth is email/password only, with sign-up and forgot-password flows retained. [SPRD-104, SPRD-108]
- Runtime environment switching is removed from v1. Debug keeps a non-persistent `localhost` mode for engineering only; QA remains dev-backed and Release remains prod-backed. [SPRD-105, SPRD-107]

## Story Overview (v1)
- Foundation and scaffolding (completed)
- Core time and data models
- Supabase offline-first sync + auth migration (priority)
- Simplification pass: auth, environments, debug tooling, and test cleanup
- Journal core: creation, assignment, inbox, migration
- Conventional MVP UI: create spreads and tasks
- Debug and dev tools
- Task lifecycle UI: edit and migration surfaces
- Scope trim for v1 (event deferment)
- Notes support
- Multiday aggregation and UI
- Settings and preferences
- Traditional mode navigation
- Collections and repository tests
- Sync and persistence
- Scope guard tests

## Story: Foundation and scaffolding (completed)

### User Story
- As a user, I want the app to launch reliably with a basic home screen so I can confirm it runs on my device.

### Definition of Done
- App boots with a placeholder root view on iPadOS/iOS 26.
- AppEnvironment and DependencyContainer are configured with debug overlay support.
- SwiftData schema and task/spread repositories (plus mocks) are in place.
- Baseline environment/container/repository tests pass.

## Story: Core time and data models

### User Story
- As a user, I want the app to understand days, months, years, and multiday ranges so my journal entries are organized correctly.

### Definition of Done
- Date utilities and period normalization support first-weekday settings.
- Spread/Entry/Assignment models exist with multiday support.
- Date and multiday preset tests pass.

### [SPRD-49] Feature: Unit tests for date + multiday presets - [x] Complete
- **Context**: Date logic is error-prone.
- **Description**: Add unit tests for normalization, presets, and first weekday override.
- **Acceptance Criteria**:
  - Tests cover locale week start, overrides, and boundaries. (Spec: Edge Cases)
- **Tests**:
  - Unit tests across month/year boundaries.
- **Dependencies**: SPRD-7, SPRD-8

## Story: Journal core: creation, assignment, inbox, migration

### User Story
- As a user, I want to create spreads, assign entries, and migrate tasks so my journal stays current as plans change.

### Definition of Done
- JournalManager loads data and enforces spread creation rules.
- Assignment engine and Inbox auto-resolve logic are implemented.
- Migration logic and cancelled-task behavior are implemented.
- Unit tests for creation, assignment, and migration pass.

## Story: Conventional MVP UI: create spreads and tasks

### User Story
- As a user, I want to create spreads and tasks from a clear navigation shell so I can start journaling quickly.

### Definition of Done
- Adaptive root navigation renders spreads and content for iPad and iPhone.
- User can create spreads and tasks; tasks render in spread lists.
- Entry list grouping and Inbox sheet behavior work end-to-end.
- Entry rows and symbols are used consistently in lists.
- Spread content surfaces use dot grid background and minimal paper styling.

### [SPRD-23] Feature: Task creation sheet - [x] Complete
- **Context**: Task creation must enforce date/period rules.
- **Description**: Build task creation UI with validation (no past dates).
- **Implementation Details**:
  - `TaskCreationSheet` presented as sheet (medium detent)
  - Entry point: replace the create spread "+" with a menu that offers "Create Spread" or "Create Task"
  - Defaults:
    - If a spread is selected, default to that spread's period/date
    - If no spread is selected, default to the same "initial selection" logic as the spreads view
  - Card 1: Core task creation UI
    - Title (required, auto-focus)
    - Period picker (year/month/day only)
    - Date selection varies by period:
      - Year: list of years
      - Month: two-step picker (year, then month)
      - Day: standard date picker
    - Date range uses same min/max as spread creation
    - Validation behavior:
      - Create button is hidden until title is edited once
      - After first edit, Create is visible even if invalid; tapping shows inline errors
      - Inline errors clear on next change
      - Title required (whitespace-only invalid, no trimming)
      - Date must be >= today using period-normalized comparison
    - On save: create Task via JournalManager; assignment logic follows existing best-match rules
- **Acceptance Criteria**:
  - "+" create action offers "Create Spread" and "Create Task". (Spec: Entries)
  - Task sheet defaults to selected spread; otherwise uses initial spread selection logic. (Spec: Navigation and UI)
  - Period picker allows year/month/day only, with period-appropriate date controls. (Spec: Entries)
  - Date range limits match spread creation. (Spec: Spreads)
  - Create button is hidden until title is edited once; after first edit it stays visible. (Spec: Entries)
  - Inline validation:
    - Title required; whitespace-only invalid (no trimming). (Spec: Entries)
    - Date is blocked when period-normalized date is before today. (Spec: Entries)
    - Validation errors clear on next change. (Spec: Entries)
  - Saving creates a task with normalized date for the selected period and runs normal assignment logic. (Spec: Entries)
- **Tests**:
  - Unit tests:
    - Default selections with/without a selected spread.
    - Period-normalized date validation (year/month/day).
    - Title validation (empty vs whitespace-only).
  - UI tests:
    - Create Task flow opens from "+" menu.
    - Create button visibility follows first-edit rule and inline errors appear on invalid submit.
    - Past-dated selections are blocked for each period.
    - Task created with selected period/date and assigns to matching spread when available.
- **Dependencies**: SPRD-22, SPRD-13

## Story: Debug and dev tools

### User Story
- As a user, I want debug tools and quick actions so I can inspect data and iterate faster.

### Definition of Done
- Debug menu and quick actions are available in Debug builds only.
- Test data builders and debug logging hooks are implemented.
- Debug menu includes appearance overrides for paper tone, dot grid, heading font, and accent color.
- Debug menu is a top-level navigation destination: tab bar item on iPhone and sidebar item on iPad (SF Symbol `ant`), with the overlay removed.

### [SPRD-63] Feature: Debug appearance overrides - [x] Complete
- **Context**: Visual tuning needs fast iteration without rebuilding UI constants.
- **Description**: Add Debug-only controls to adjust paper tone, dot grid, typography, and accent color.
- **Implementation Details**:
  - Add an "Appearance" section to `DebugMenuView` (DEBUG only).
  - Controls:
    - Paper tone presets (warm off-white default, clean white, cool gray).
    - Dot grid toggle plus sliders for dot size, spacing, and opacity.
    - Heading font picker (default sans and a few alternatives for comparison).
    - Accent color picker with a muted blue default and a reset button.
  - Store overrides in `@AppStorage` or a `DebugAppearanceSettings` observable to update SwiftUI live.
  - Provide "Reset to defaults" action to revert to spec defaults.
- **Acceptance Criteria**:
  - Changing Debug appearance values updates spread content surfaces immediately. (Spec: Visual Design)
  - Overrides are DEBUG-only and do not ship in Release builds. (Spec: Development Tooling)
- **Tests**:
  - Unit test ensures appearance controls are excluded in Release builds.
  - UI tests: changing appearance controls updates spread surface (dot grid toggle, accent color, paper tone).
- **Dependencies**: SPRD-45, SPRD-62

### [SPRD-101] Refactor: Retrofit architecture decisions to existing code - [x] Complete
- **Context**: New architecture decisions were added to CLAUDE.md (view coordinators, `#if DEBUG` separation, struct-by-default). Existing code predates these conventions and should be updated for consistency.
- **Description**: Update existing views and services to follow the new architecture patterns in a single cleanup pass.
- **Implementation Details**:
  - **View coordinators**:
    - Extract `SpreadsCoordinator` from `ConventionalSpreadsView` — move 4 sheet presentation bools into a single `SheetDestination` enum, add action methods, replace child callback closures with coordinator method calls.
    - Evaluate `TabNavigationView` (2 sheet bools for inbox/auth) — consider sharing presentation coordination with `SpreadsCoordinator` or extracting a lightweight coordinator if warranted.
  - **`#if DEBUG` extraction**:
    - `ContentView.swift` has 3 `#if DEBUG` blocks (launch config, sync policy factory, auth service factory). Extract these into `Debug/` files or `+Debug.swift` extensions.
    - Audit remaining source files for any other `#if DEBUG` blocks in production code.
  - **Struct-by-default audit**:
    - Review existing classes in `Services/` — confirm each class requires identity semantics (`@Observable`, `@Model`, or shared mutable state). Convert any that don't to structs.
- **Acceptance Criteria**:
  - `ConventionalSpreadsView` uses a `SpreadsCoordinator` with a single `SheetDestination` enum for sheet presentation.
  - No production source files (outside `Debug/`) contain `#if DEBUG` blocks.
  - All service/coordinator types that don't require identity semantics are structs.
- **Tests**:
  - Unit: `SpreadsCoordinator` action methods set the correct `activeSheet` destination.
  - Existing tests continue to pass (no behavioral changes).
- **Dependencies**: None (can be done at any time)

## Story: Supabase offline-first sync + auth migration (priority)

### User Story
- As an authenticated user, I want my data to work offline first and sync across devices and platforms without unnecessary account-state complexity.

### Definition of Done
- Supabase dev/prod environments are configured with migrations, RLS, and merge RPCs.
- App uses SwiftData locally with an outbox-based sync engine (push + incremental pull).
- Auth is email/password only in product environments, with sign-up and forgot-password flows available in-app.
- Product usage is auth-gated in dev/prod; signed-in users retain offline access with cached local data until the app can definitively determine the session is invalid online.
- Debug supports a non-persistent `localhost` mode for engineering; QA stays on dev and Release stays on prod.
- Runtime environment switching, backup entitlement gating, sign-in merge/discard flows, and social auth are removed from the v1 target.
- Sync status and error feedback are visible for the simplified state model; CloudKit is no longer required.

### Planning Note
- Completed tasks below capture the current implementation history, including flows that are now out of scope. The simplification story below supersedes those behaviors where they conflict with the updated v1 target. [SPRD-104, SPRD-105, SPRD-106, SPRD-107, SPRD-108, SPRD-109]

## Story: Simplification pass: auth, environments, debug tooling, and tests

### User Story
- As the team, we want a simpler authenticated product model and a narrower debug/runtime matrix so the codebase is cleaner, the infrastructure is easier to trust, and obsolete tests do not keep dead complexity alive.

### Definition of Done
- Product usage in dev/prod requires authentication, using email/password only.
- Backup entitlement, social auth, guest/local-only product usage, sign-in merge/discard, and runtime environment switching are removed from the v1 target and implementation.
- Debug retains a non-persistent `localhost` mode with mock auth and mock data loading for engineering only.
- QA remains dev-backed; Release remains prod-backed.
- Local store isolation prevents mock `localhost` data from contaminating dev-backed local state.
- Debug, unit, and QA documentation are updated to the simplified matrix.
- Obsolete tests and code paths are removed rather than preserved behind dead abstractions.

### [SPRD-104] Refactor: Simplify auth and sync eligibility model - [x] Complete
- **Context**: Backup entitlement, guest usage, and sign-in merge/discard create a large amount of product and infrastructure complexity for a small v1 benefit.
- **Description**: Collapse the product model to authenticated usage in dev/prod with sync gated only by session validity.
- **Implementation Details**:
  - Remove backup-entitlement concepts from auth state, sync eligibility, sync status copy, and onboarding/documentation.
  - Remove sign-in merge/discard prompts and related local-data migration state.
  - Define the product runtime as:
    - No valid session on launch in dev/prod -> auth gate.
    - Valid cached session in dev/prod -> app loads local data and syncs when possible.
    - Offline with cached session -> app remains usable until session invalidation is confirmed online.
    - Sign-out -> wipe local store and return to auth gate.
  - Keep `localOnly` sync status only for Debug `localhost`.
- **Acceptance Criteria**:
  - There is no backup-entitlement state, code path, or UI in the v1 implementation.
  - There is no sign-in merge/discard prompt in the app.
  - Dev/prod sync eligibility is based on authenticated session only.
  - Sign-out wipes local data and exits to the auth gate.
- **Tests**:
  - Remove tests that exist only for backup entitlement or sign-in merge/discard flows.
  - Add/update unit tests for auth-gated launch, cached-session offline access, and sign-out wipe behavior.
- **Dependencies**: None

### [SPRD-105] Refactor: Simplify DataEnvironment model and launch behavior - [x] Complete
- **Context**: Runtime environment switching, persisted environment selection, and restart flows add significant runtime and test complexity.
- **Description**: Reduce `DataEnvironment` to a launch-time concern with Debug `localhost` support only.
- **Implementation Details**:
  - Remove persisted data-environment selection and any in-app switch flow/coordinator usage.
  - Remove runtime soft-restart behavior that exists only for environment switching.
  - Define launch-time environment rules:
    - Debug default -> `development`
    - Debug override -> `localhost` when explicitly launched that way
    - QA -> `development`
    - Release -> `production`
  - Keep launch-time wipe protection only for transitions to/from `localhost`.
- **Acceptance Criteria**:
  - No in-app environment switcher exists.
  - `localhost` is selected per Debug launch only and never persists across launches.
  - Transitioning to or from `localhost` wipes the local store before app startup.
  - QA cannot enter `localhost`; Release cannot enter `localhost`.
- **Tests**:
  - Remove tests that exist only for persisted environment selection or runtime switching.
  - Add/update tests for launch-time resolution and `localhost` isolation wipe rules.
- **Dependencies**: SPRD-104

### [SPRD-106] Feature: Auth-gated launch, large auth sheet, and onboarding after auth - [x] Complete
- **Context**: The updated product model needs a clear, explicit entry flow instead of allowing the app to run meaningfully while signed out.
- **Description**: Introduce a blocking auth gate in product environments and move onboarding to the first authenticated launch.
- **Implementation Details**:
  - Present auth as a large sheet on launch whenever dev/prod starts without a valid session.
  - Reuse the same auth sheet from the toolbar when logged out.
  - Keep email/password sign-in, sign-up, forgot-password, and inline validation/error handling.
  - Remove social-auth buttons and flows.
  - Show onboarding after the first successful authenticated launch, once per install.
- **Acceptance Criteria**:
  - Dev/prod users cannot access journal content while signed out.
  - Auth sheet uses a large presentation style and supports sign-in, sign-up, and forgot password.
  - First authenticated launch shows onboarding; later launches skip it.
  - Offline launch with a cached valid session still opens the app.
- **Tests**:
  - Unit/UI tests for auth gate presentation, large-sheet flow, onboarding-after-auth, and offline cached-session behavior.
  - Remove tests specific to Apple/Google auth entry points.
- **Dependencies**: SPRD-104, SPRD-105

### [SPRD-107] Feature: Debug-only localhost mode and mock data isolation - [x] Complete
- **Context**: Engineering still needs a fast local workflow for debug scenarios, previews, and seeded data, but that mode should not leak into product behavior.
- **Description**: Keep `localhost` only as a Debug engineering mode with mock auth and mock data loading.
- **Implementation Details**:
  - In Debug `localhost`, bypass the auth gate automatically with mock auth.
  - Restrict mock data loading to Debug `localhost`.
  - Remove mock-data access from dev-backed Debug, QA, and Release runs.
  - Ensure debug descriptions, labels, and QA docs clearly distinguish `localhost` from product environments.
- **Acceptance Criteria**:
  - Launching Debug in `localhost` opens directly into the app with mock auth.
  - Mock data loading is available only in Debug `localhost`.
  - Dev-backed Debug and QA builds cannot accidentally load mock data into a real backend account.
- **Tests**:
  - Unit tests for localhost auth bypass and mock-data availability rules.
  - Remove tests that assume localhost persistence or runtime switching.
- **Dependencies**: SPRD-105, SPRD-106

### [SPRD-108] Refactor: Remove obsolete social-auth and runtime-switch surfaces - [x] Complete
- **Context**: The current implementation and completed tasks include features that are now explicitly out of scope and should not remain as dead or misleading code.
- **Description**: Remove code, docs, and UI surfaces for Apple/Google auth, backup-entitlement flows, and runtime environment switching.
- **Implementation Details**:
  - Remove Apple/Google auth service methods, UI buttons, and related docs/tests.
  - Remove debug environment switcher UI, switch coordinator usage, restart callbacks, and related warnings/confirmations.
  - Remove obsolete sync status variants and user-facing copy tied only to the old model.
  - Keep only the debug tooling that still serves the simplified matrix.
- **Acceptance Criteria**:
  - There are no reachable Apple/Google auth flows in the app.
  - There is no reachable runtime environment-switch UI or restart flow.
  - Obsolete status/UI states from the old model are removed, not hidden.
- **Tests**:
  - Delete obsolete test files/cases that only exercise removed surfaces.
  - Update remaining tests to assert the new smaller state surface.
- **Dependencies**: SPRD-104, SPRD-105, SPRD-106, SPRD-107

### [SPRD-109] Quality: Rebuild the test and QA matrix for the simplified model - [x] Complete
- **Context**: The current tests and QA docs encode a wider runtime/auth matrix than the new product requires.
- **Description**: Rebuild the automated and manual verification matrix around the simplified environments and auth behavior.
- **Implementation Details**:
  - Audit `SpreadTests`, UI tests, and manual QA docs for obsolete coverage.
  - Remove test cases for:
    - backup entitlement
    - sign-in merge/discard
    - Apple/Google auth
    - persisted environment selection
    - runtime environment switching
    - localhost persistence
  - Add focused coverage for:
    - auth-gated launch
    - cached-session offline usage
    - sign-out wipe
    - Debug `localhost` isolation
    - mock-data availability rules
  - Update `docs/sync-qa-checklist.md`, `docs/offline-first-qa-checklist.md`, and related setup docs to reflect the smaller matrix.
- **Acceptance Criteria**:
  - No test or QA doc asserts behavior that is no longer in scope.
  - The remaining matrix is explicit and small enough to reason about quickly.
  - Manual QA docs separate product-environment behavior from Debug `localhost` behavior.
- **Tests**:
  - Run the updated unit/UI suites relevant to auth, sync, and environment bootstrapping.
  - Update QA checklists to match the simplified behavior exactly.
- **Dependencies**: SPRD-104, SPRD-105, SPRD-106, SPRD-107, SPRD-108

### [SPRD-110] Refactor: Formalize migration eligibility by desired assignment - [x]
- **Context**: The current migration prompt behavior is parent-based but not yet fully specified around desired assignment limits, Inbox-source migration, or “most granular valid destination” resolution.
- **Description**: Tighten JournalManager migration eligibility rules so prompts only appear for the correct spread and task combinations.
- **Implementation Details**:
  - Define migration eligibility from the task's current open assignment plus desired assignment period/date.
  - Only allow migration into the most granular valid existing destination that does not exceed the task's desired assignment.
  - Support `Inbox` as a migration source for newly available year/month/day spreads.
  - Ensure completed, migrated-history-only, and cancelled tasks are excluded.
  - Ensure multiday spreads never participate as migration destinations.
- **Acceptance Criteria**:
  - A month-desired task assigned to `2026` is prompted on `January 2026`, but never on `January 10, 2026`.
  - A day-desired task assigned to `2026` is prompted on `January 2026` only until `January 10, 2026` exists; then only the day spread prompts it.
  - Inbox tasks follow the same “most granular valid existing destination” rule.
- **Tests**:
  - Unit tests for desired-assignment bounding, Inbox-source eligibility, and “most granular valid destination” resolution.
  - Remove any tests that assume any parent task can prompt on any deeper spread.
- **Dependencies**: SPRD-15, SPRD-24, SPRD-52

### [SPRD-111] Feature: Conventional migration review banner and sheet refinement - [x]
- **Context**: The migration prompt needs clearer, scenario-driven behavior that stays spread-scoped and explicit.
- **Description**: Refine the conventional-mode migration banner and review sheet around the new eligibility rules.
- **Implementation Details**:
  - Keep the migration banner only on conventional year/month/day spreads.
  - Banner appears whenever eligible tasks exist and reappears on revisit while eligibility remains.
  - Tapping the banner opens a review sheet with all eligible tasks preselected.
  - Section rows by source (`Inbox`, year, month, or parent day when applicable) and show both source and destination.
  - Batch-confirm selected migrations, revalidate on submit, skip stale rows with non-blocking feedback, and keep the sheet open only while eligible tasks remain.
- **Acceptance Criteria**:
  - Migration prompt is conventional-only and never appears on multiday or traditional spreads.
  - Review sheet sections tasks by source and shows both source and destination.
  - Batch migration behaves resiliently when some rows become stale before submit.
- **Tests**:
  - Unit/UI tests for banner visibility, section ordering by source, preselection, revalidation, and post-submit sheet dismissal rules.
- **Dependencies**: SPRD-110

### [SPRD-112] Feature: Global overdue review based on current assignment granularity - [x]
- **Context**: Overdue needs a global review surface that is independent from spread-scoped migration prompts and consistent with assignment granularity.
- **Description**: Add a global overdue toolbar button and review sheet for open tasks across the journal.
- **Implementation Details**:
  - Compute overdue from the current open assignment (`day` after day passes, `month` after month passes, `year` after year passes).
  - Fall back to desired assignment rules for tasks still in Inbox.
  - Show a yellow toolbar button with icon and count on all spreads in both modes whenever overdue tasks exist globally.
  - Open a global overdue review sheet grouped by source assignment, ordered chronologically by source date.
  - Keep the overdue sheet read/review-only in v1; rows open task editing but no bulk overdue actions exist yet.
- **Acceptance Criteria**:
  - Overdue count is global and appears from any spread when overdue tasks exist anywhere in the journal.
  - Inbox tasks can become overdue using desired-assignment fallback.
  - A task may appear in both overdue review and a spread migration review when both conditions are true.
- **Tests**:
  - Unit tests for overdue-by-assignment-period, Inbox fallback, and global count behavior across conventional/traditional modes.
  - UI tests for yellow toolbar button visibility and overdue review sheet grouping.
- **Dependencies**: SPRD-110

### [SPRD-113] Quality: Scenario table coverage and docs for migration + overdue - [x]
- **Context**: These rules are easy to regress unless the spec, QA docs, and tests all use the same concrete examples.
- **Description**: Align code, tests, and QA material with explicit scenario tables for migration prompting and overdue behavior.
- **Implementation Details**:
  - Add unit-test matrices using absolute dates for day/month/year overdue thresholds.
  - Add scenario coverage for year→month, month→day, Inbox→spread, and disappearing coarser prompts when a finer valid spread appears.
  - Update manual QA docs to include migration-prompt and overdue-review scenarios with absolute dates.
- **Acceptance Criteria**:
  - Spec examples, QA steps, and automated tests use the same concrete scenarios.
  - The migration and overdue rules are understandable without interpreting code.
- **Tests**:
  - Run the focused journal-manager, spread UI, and overdue-review suites added for SPRD-110 through SPRD-112.
- **Dependencies**: SPRD-110, SPRD-111, SPRD-112

### [SPRD-114] Quality: Localhost scenario UI test harness and fixtures - [x]
- **Context**: The core migration, reassignment, Inbox, and overdue rules are now specified, but the current UI suite is still mostly navigation smoke tests and generic datasets.
- **Description**: Build the localhost-backed scenario testing foundation needed for deterministic user-flow coverage.
- **Implementation Details**:
  - Add a shared UI-test harness for localhost launch, fixed-today injection, spread navigation, migration review actions, overdue review actions, and common assertions.
  - Expand the mock data catalog with deterministic scenario-specific fixtures for assignment, Inbox, migration, reassignment, overdue, and note-exclusion cases.
  - Keep test-only datasets hidden from normal debug-menu browsing while still selectable by launch argument.
  - Add dedicated accessibility identifiers for all scenario-test-critical migration and overdue UI elements.
- **Acceptance Criteria**:
  - UI scenario tests no longer duplicate launch and navigation setup ad hoc.
  - Scenario fixtures can reproduce migration and overdue states deterministically from launch arguments alone.
  - Migration and overdue UI surfaces expose stable identifiers suitable for non-brittle UI assertions.
- **Tests**:
  - Add/adjust UI-test smoke coverage proving the harness can launch localhost scenario datasets and find the keyed surfaces.
- **Dependencies**: SPRD-107, SPRD-110, SPRD-111, SPRD-112

### [SPRD-115] Quality: Assignment, Inbox, and reassignment scenario UI tests - [x]
- **Context**: Assignment fallback and edit-time reassignment are logic-heavy user flows that are currently covered more strongly at the unit level than at the integrated UI level.
- **Description**: Add localhost scenario UI tests for creation-time assignment, Inbox routing, Inbox-to-spread resolution, and edit-time reassignment.
- **Implementation Details**:
  - Cover direct assignment to an existing spread during creation.
  - Cover Inbox fallback when no matching spread exists.
  - Cover Inbox-origin tasks becoming movable when a valid year/month/day spread becomes available.
  - Cover edit-time preferred date/period changes, including relocated active placement and migrated-history visibility on the source spread.
- **Acceptance Criteria**:
  - User-visible assignment and reassignment outcomes are validated through the UI, not inferred only from unit tests.
  - Source-spread migrated history is asserted for reassignment flows in conventional mode.
  - Scenario tests remain deterministic through localhost fixtures and fixed `today` values.
- **Tests**:
  - Add UI scenario suites for assignment fallback, Inbox routing, Inbox resolution, and edit-time reassignment.
- **Dependencies**: SPRD-114

### [SPRD-116] Quality: Conventional migration review scenario UI tests - [x]
- **Context**: Migration prompting is one of the most nuanced user-facing behaviors in conventional mode and now depends on desired assignment and destination-resolution rules.
- **Description**: Add localhost scenario UI tests that exercise the full migration review flow end-to-end.
- **Implementation Details**:
  - Cover month-bounded migration, day-destination superseding month prompts, and Inbox-source migration.
  - Assert banner visibility and absence on invalid destinations.
  - Assert full review-sheet behavior: sectioning by source, source/destination labels, preselected rows, confirm action, and post-submit sheet behavior.
  - Keep stale-row revalidation primarily unit-tested; UI tests focus on the normal end-to-end flow.
- **Acceptance Criteria**:
  - The UI suite proves the “most granular valid existing destination” rule from user-visible behavior.
  - Review-sheet interaction is covered end-to-end for conventional migration.
  - Notes are explicitly absent from migration review scenarios.
- **Tests**:
  - Add migration-focused UI scenario suites for year→month, month→day, Inbox→spread, and disappearing coarser prompts.
- **Dependencies**: SPRD-114, SPRD-115

### [SPRD-117] Quality: Global overdue review scenario UI tests - [x]
- **Context**: Overdue now has a global, mode-agnostic review surface whose thresholds depend on assignment granularity and Inbox fallback.
- **Description**: Add localhost scenario UI tests for global overdue toolbar and review behavior.
- **Implementation Details**:
  - Cover day, month, and year overdue thresholds using fixed absolute dates.
  - Cover Inbox overdue fallback using desired assignment.
  - Assert yellow toolbar button visibility and count from any spread.
  - Assert review-sheet availability and grouping by current source assignment from both conventional and traditional contexts.
  - Include a traditional-mode scenario to confirm overdue remains available there while migration stays absent.
- **Acceptance Criteria**:
  - Overdue UI scenarios prove the assignment-granularity thresholds through visible outcomes.
  - The overdue review sheet remains task-only, with note exclusion backstopped by focused unit coverage where UI hooks are too brittle.
  - Traditional mode shows overdue review but never migration UI.
- **Tests**:
  - Add overdue-focused UI scenario suites for button count, grouping, Inbox fallback, and traditional-mode availability, with focused unit coverage for note exclusion.
- **Dependencies**: SPRD-114

### [SPRD-118] Quality: Scenario-matrix QA/docs alignment - [x]
- **Context**: Once scenario UI coverage exists, the spec, plan, and QA material must reference the same required matrix so the suite does not drift.
- **Description**: Align the required scenario matrix across docs and QA artifacts and prune any obsolete or overlapping guidance.
- **Implementation Details**:
  - Update QA docs to match the localhost scenario matrix exactly.
  - Document the shared harness conventions and scenario fixture naming.
  - Remove or rewrite older UI test guidance that assumes generic mock datasets are sufficient for logic-heavy flows.
- **Acceptance Criteria**:
  - Spec, plan, QA docs, and scenario fixtures describe the same set of required scenarios.
  - Adding a new scenario follows a documented harness + fixture pattern instead of ad hoc test structure.
- **Tests**:
  - Run the full scenario UI suite plus the focused migration/overdue unit suites after the matrix lands.
- **Dependencies**: SPRD-115, SPRD-116, SPRD-117

### [SPRD-102] Refactor (Highest Priority): Runtime naming normalization, phases 1-4 - [x]
- **Context**: Naming in app bootstrap/runtime code is overloaded (`session`, `environment`, `container`) and conflicts with auth session terminology.
- **Description**: Apply the naming normalization pass for phases 1-4 to make runtime assembly concepts explicit and reserve `session` for auth only.
- **Implementation Details**:
  - Phase 1: Core type renames in `Spread/Environment/`
    - `AppSession` -> `AppRuntime`
    - `SessionConfiguration` -> `AppRuntimeConfiguration`
    - `SessionFactory` -> `AppRuntimeFactory`
    - `AppSessionFactory` -> `AppRuntimeBootstrapFactory` (or equivalent shim name)
  - Phase 2: Call-site renames for clarity
    - `ContentView` local state and identifiers updated from `session` naming to `runtime` naming
    - Factory call sites updated to runtime names
    - Inline comments/docs updated to runtime terminology
  - Phase 3: Debug configuration wiring rename
    - `SessionConfiguration+Debug.swift` -> `AppRuntimeConfiguration+Debug.swift`
    - Extension and constructors renamed to match runtime configuration terminology
  - Phase 4: Reduce environment naming ambiguity
    - `EnvironmentSwitchCoordinator` -> `DataEnvironmentSwitchCoordinator`
    - Related symbols/labels/docs updated to explicitly reference DataEnvironment switching
- **Acceptance Criteria**:
  - No bootstrap/runtime symbol uses `Session*` naming except auth session concepts.
  - `ContentView` and runtime factories use consistent `runtime` terminology.
  - Debug runtime configuration path compiles and behaves identically to current behavior.
  - Data environment switching symbols are explicitly named around `DataEnvironment`.
- **Tests**:
  - Existing tests continue to pass with renamed symbols.
  - Add/adjust tests only where symbol names changed and test fixtures require updates.
- **Dependencies**: None

### [SPRD-103] Refactor (Highest Priority): Runtime naming normalization, phase 5+ - [x]
- **Context**: After phases 1-4, DI and surrounding terminology still contain ambiguous `container`/`dependency` naming that can be improved in a second pass.
- **Description**: Complete phase 5+ naming cleanup for DI/runtime vocabulary and downstream consistency updates.
- **Implementation Details**:
  - Phase 5: Optional DI naming pass
    - `DependencyContainer` -> `AppDependencies` (or `AppDependencyGraph`, choose one and apply consistently)
    - Call sites and parameter labels renamed from `container` to `dependencies` where this refers to the DI aggregate
    - Keep `ModelContainer` naming unchanged where it refers specifically to SwiftData
  - Phase 6: Test/docs/log alignment
    - Rename impacted test files/symbols under `SpreadTests/Environment`, `SpreadTests/Views`, and `SpreadTests/Services`
    - Update logger categories and comments referencing old runtime/session naming
    - Run symbol sweep for stale identifiers and remove leftovers
  - Phase 7: Validation checklist execution
    - Confirm app launch path, preview path, and environment-switch flow remain behaviorally unchanged
    - Confirm auth terminology still uses `session` exclusively for auth provider/user session concepts
- **Acceptance Criteria**:
  - DI aggregate naming is consistent and no longer overloaded with runtime/auth terms.
  - `ModelContainer` remains clearly distinct from DI aggregate naming.
  - No stale references to old runtime/session/container naming remain in production code or tests.
- **Tests**:
  - Full test suite passes after rename ripple updates.
  - Add targeted regression tests only if required by renamed API surfaces.
- **Dependencies**: SPRD-102

### [SPRD-98] Feature: Immediate push on commit (not per keystroke) - [x] Complete
- **Context**: Sync should be automatic without excessive per-keystroke calls.
- **Description**: Attempt a sync push when a user explicitly saves a change (Save/Done).
- **Implementation Details**:
  - Ensure repository writes enqueue outbox mutations.
  - Trigger `syncNow()` after explicit Save/Done actions for tasks/notes/spreads/settings.
  - Avoid triggering sync on intermediate field edits.
  - **Carry-over from feature/SPRD-85 (cherry-pick guidance):**
    - `49a8c05` (`Spread/Services/Sync/SyncEngine.swift`): keep optional client + local-only behavior, but adapt to DataEnvironment.
  - **Architecture note (commit hook surface)**:
    - Treat “Save/Done” as the synchronization boundary; do not hook per-keystroke.
    - Pseudocode:
      ```swift
      func saveTask() async {
        try await repository.save(task)
        await syncService.syncNow()
      }
      ```
- **Acceptance Criteria**:
  - Save/Done actions trigger immediate sync attempts when signed in and online.
  - Manual sync remains available.
- **Tests**:
  - Manual: edit a task and tap Save; verify a sync attempt occurs.
- **Dependencies**: SPRD-85

### [SPRD-87] Feature: SwiftData model sync metadata - [x] Complete
- **Context**: Local models must carry sync metadata for field-level LWW.
- **Description**: Extend SwiftData models with sync fields and update schema.
- **Implementation Details**:
  - Add per-field `*_updated_at`, `deleted_at`, `revision`, and `device_id` fields.
  - Add settings model fields needed for sync.
  - Update schema version + migration plan.
  - Ensure repositories populate metadata on local edits.
- **Acceptance Criteria**:
  - Local models serialize to/from Supabase records without loss.
  - Schema migration is tested.
- **Tests**:
  - Unit tests for model encoding/decoding and migration.
- **Dependencies**: SPRD-85

### [SPRD-88] Feature: Settings sync (Supabase) ✅
- **Context**: Settings should be consistent across devices.
- **Description**: Sync settings via Supabase and merge locally.
- **Implementation Details**:
  - Store a single `settings` row per user in Supabase.
  - Sync settings through outbox + pull; resolve with field-level LWW.
  - Fall back to local values when offline or signed out.
- **Acceptance Criteria**:
  - Settings sync across devices after sign-in.
- **Tests**:
  - Unit tests for settings merge and conflict resolution.
- **Dependencies**: SPRD-85, SPRD-87

### [SPRD-89] Feature: Tombstone cleanup job - [x] Complete
- **Context**: Soft deletes need periodic cleanup.
- **Description**: Add a scheduled cleanup job to remove rows deleted > 90 days.
- **Implementation Details**:
  - Implement scheduled cleanup (Supabase scheduled SQL or Edge Function).
  - Ensure cleanup uses service role and respects RLS.
- **Acceptance Criteria**:
  - Soft-deleted rows older than 90 days are removed.
- **Tests**:
  - Manual: create old tombstones and verify cleanup job behavior.
- **Dependencies**: SPRD-82

### [SPRD-90] Feature: Sync QA + test plan - [x] Complete
- **Context**: Offline-first sync needs dedicated test coverage.
- **Description**: Add integration tests and a QA checklist for sync scenarios.
- **Implementation Details**:
  - Add tests for offline edits, conflict resolution, and delete-wins.
  - Add QA checklist for environment switching and sign-in merge. Note: the switch flow uses an outbox count check (not a sync attempt); the QA checklist should reflect this simplified flow.
  - Document manual sync verification steps.
- **Acceptance Criteria**:
  - QA checklist exists and covers core sync scenarios.
- **Tests**:
  - Integration test coverage for push/pull and merge conflicts.
- **Dependencies**: SPRD-85

### [SPRD-91] Feature: Apple + Google auth providers - [x] Complete
- **Context**: Social sign-in improves user onboarding and provides secure authentication.
- **Description**: Configure Sign in with Apple and Google OAuth providers in Supabase, and add UI buttons.
- **Implementation Details**:
  - **Sign in with Apple**:
    - Configure Apple Developer account with Services ID for Supabase
    - Add Team ID, Key ID, and private key to Supabase Auth settings
    - Enable Apple provider in both dev and prod Supabase projects
  - **Google Sign-in**:
    - Create Google Cloud project with OAuth 2.0 credentials
    - Configure OAuth consent screen and authorized redirect URIs
    - Add Client ID and Client Secret to Supabase Auth settings
    - Enable Google provider in both dev and prod Supabase projects
  - **UI Updates**:
    - Add "Sign in with Apple" button to login sheet
    - Add "Sign in with Google" button to login sheet
    - Handle OAuth callbacks and session creation
  - Update `docs/supabase-setup.md` with provider configuration steps
- **Acceptance Criteria**:
  - Sign in with Apple works in both dev and prod environments.
  - Google Sign-in works in both dev and prod environments.
  - Login sheet shows Apple and Google sign-in buttons.
  - Documentation includes setup steps for both providers.
- **Tests**:
  - Manual: sign-in flow works with Apple credentials.
  - Manual: sign-in flow works with Google credentials.
- **Dependencies**: SPRD-84

### [SPRD-92] Feature: Sign up + forgot password flows - [x] Complete
- **Context**: Users need to create accounts and recover forgotten passwords.
- **Description**: Add sign up and forgot password UI flows to the login sheet.
- **Implementation Details**:
  - Add "Create Account" link/button to login sheet
  - Sign up sheet with email/password fields and confirmation
  - Add "Forgot Password?" link to login sheet
  - Forgot password flow: email input, send reset link via Supabase
  - Success/error states for both flows
  - Handle email verification flow if required
- **Acceptance Criteria**:
  - Users can create new accounts via sign up flow.
  - Users can request password reset via forgot password flow.
  - Appropriate success/error feedback shown.
- **Tests**:
  - Manual: sign up flow creates account and allows login.
  - Manual: forgot password sends reset email.
- **Dependencies**: SPRD-84

### [SPRD-93] Feature: Login form validation - [x] Complete
- **Context**: Login forms need client-side validation for better UX.
- **Description**: Add validation rules to login and sign up forms.
- **Implementation Details**:
  - Email validation: valid email format check
  - Password validation: minimum length (e.g., 8 characters)
  - Inline validation feedback (show errors as user types or on blur)
  - Disable submit button until validation passes
  - Clear, user-friendly error messages
- **Acceptance Criteria**:
  - Invalid email format shows error message.
  - Password below minimum length shows error message.
  - Submit button disabled until form is valid.
- **Tests**:
  - Unit tests for validation logic.
  - Manual: validation feedback appears correctly.
- **Dependencies**: SPRD-84

### [SPRD-47] Feature: Test data builders - [x] Complete
- **Context**: Tests need consistent fixtures for entries and spreads.
- **Description**: Create test data builders for entries/spreads/multiday ranges.
- **Implementation Details**:
  - `TestData` struct with static methods:
    - `testYear`, `testMonth`, `testDay` - fixed test dates
    - `spreads(calendar:today:)` - hierarchical spread set
    - `tasks(calendar:today:)` - comprehensive task scenarios
    - `events(calendar:today:)` - v2-only, gated behind events-enabled
    - `notes(calendar:today:)` - notes with various states
    - Specialized setups: `migrationChainSetup()`, `batchMigrationSetup()`, `spreadDeletionSetup()`
- **Acceptance Criteria**:
  - Builders cover edge cases (month/year boundaries, multiday overlaps). (Spec: Edge Cases)
- **Tests**:
  - Unit tests for builder outputs.
- **Dependencies**: SPRD-46

### [SPRD-48] Feature: Lifecycle logging hooks - [x] Complete
- **Context**: Assignment/migration debugging needs visibility.
- **Description**: Add OSLog-based logging for assignment, migration, inbox resolution, and spread deletion events — available in all builds, using appropriate log levels.
- **Implementation Details**:
  - Use OSLog/Logger (consistent with existing project pattern) in all builds
  - Log events: assignment created, migration performed, inbox resolved, spread deleted
  - Include relevant context (entry ID, spread info, status changes)
  - Use `.debug` for verbose detail, `.info` for lifecycle events
- **Acceptance Criteria**:
  - Lifecycle events are logged via OSLog with appropriate log levels.
  - Logging is available in all builds (not gated to Debug).
- **Tests**:
  - Unit tests verifying log points exist for key lifecycle events.
- **Dependencies**: SPRD-47

### [SPRD-65] Feature: Leap day boundary test data - [x] Complete
- **Context**: Leap day (Feb 29) is a special case for date boundary testing.
- **Description**: Add leap day scenarios to the boundary mock data set and test data builders.
- **Implementation Details**:
  - Extend `MockDataSet.boundary` to include Feb 29 dates for the next leap year (2028)
  - Add spreads and entries for Feb 28 → Feb 29 → Mar 1 transitions
  - Include test cases for:
    - Day spread on Feb 29
    - Month spread for February in a leap year
    - Multiday range spanning Feb 28-Mar 1 in a leap year
    - Tasks/notes assigned to Feb 29 (events in v2)
- **Acceptance Criteria**:
  - Boundary data set includes leap day scenarios when applicable. (Spec: Edge Cases)
- **Tests**:
  - Unit tests verifying leap day spreads are correctly generated.
  - Unit tests for date normalization on Feb 29.
- **Dependencies**: SPRD-46
## Story: Task lifecycle UI: edit and migration surfaces

### User Story
- As a user, I want to edit task details and migrate tasks from the UI so I can keep my work accurate.

### Definition of Done
- Task edit view supports status updates and migration.
- Migrated tasks section and inline migration affordances are wired to JournalManager.

### [SPRD-24] Feature: Entry detail/edit view (Task) - [x] Complete
- **Context**: Task editing must support status and migration.
- **Description**: Implement detail view for editing task title, date/period, status, and migration.
- **Implementation Details**:
  - `TaskEditView`:
    - Edit title, preferred date/period
    - Status picker (open/complete/migrated/cancelled)
    - Assignment history (conventional mode)
    - Migrate action: button to migrate to current spread
    - Delete action with confirmation alert
  - Migration respects type rules (Task-only in this view)
- **Acceptance Criteria**:
  - Task status includes cancelled. (Spec: Task Status)
  - Migration action respects type rules. (Spec: Entries)
- **Tests**:
  - Unit tests for save behavior by type.
  - UI tests: edit task title/status, migrate action, and delete confirmation flow.
- **Dependencies**: SPRD-22, SPRD-15, SPRD-16

### [SPRD-29] Feature: Migrated tasks section - [x] Complete
- **Context**: Conventional mode shows migrated history.
- **Description**: Add a collapsible migrated tasks section.
- **Implementation Details**:
  - `MigratedTasksSection`:
    - Collapsible section at bottom of spread
    - Shows tasks that were migrated FROM this spread
    - Each row shows destination spread info
    - Expandable with animation
- **Acceptance Criteria**:
  - Migrated tasks are visible with destination info. (Spec: Modes)
- **Tests**:
  - Unit tests for destination formatting.
  - UI tests: migrated tasks section appears, collapses/expands, and shows destination labels.
- **Dependencies**: SPRD-28, SPRD-15

### [SPRD-30] Feature: Migration banner + selection - [x] Complete
- **Context**: Users can migrate eligible tasks in bulk.
- **Description**: Implement migration banner and selection sheet for eligible tasks.
- **Implementation Details**:
  - `MigrationBannerView`:
    - Shows when eligible tasks exist (tasks only, not notes)
    - Count of migratable tasks
    - "Review" button: opens selection sheet
    - "Migrate All" button: batch migrate
    - Dismiss button
  - Selection sheet: checkbox list of eligible tasks
  - Uses `JournalManager.eligibleTasksForMigration(to:)`
- **Acceptance Criteria**:
  - Banner only appears when eligible tasks exist. (Spec: Navigation and UI)
  - Batch migration is manual. (Spec: Entries)
  - Notes excluded from batch suggestions. (Spec: Entries)
- **Tests**:
  - Unit tests for eligibility detection and selection behavior.
  - UI tests: banner appears only with eligible tasks, review sheet selection, and migrate-all action.
- **Dependencies**: SPRD-29

### [SPRD-140] Refactor: Replace migration banner/sheet with inline source and destination migration UI - [ ]
- **Context**: The current migration flow appears to be leaving source assignments active after migration, and the banner/sheet review flow should be replaced with inline migration controls on the spreads themselves.
- **Description**: Fix migration assignment-state correctness and replace the old conventional migration banner/sheet flow with source-row and destination-section inline affordances.
- **Implementation Details**:
  - Fix `JournalManager` migration so migrating a task:
    - preserves the source assignment as history with migrated status
    - creates or updates the destination assignment as the active open assignment
    - removes the task from the source spread's active task list
    - leaves the task visible in the source spread's disabled `Migrated tasks` subsection
  - Source-side UI:
    - add a trailing right-arrow on active task rows only when the task has a smaller valid existing destination spread
    - tapping the arrow presents a confirmation alert that explicitly names the destination spread
    - confirming migrates that one task to its smallest valid existing destination spread
  - Destination-side UI:
    - add a bottom `Migrate tasks` section on conventional destination spreads only when at least one task from the immediate parent hierarchy can migrate into that spread
    - make the section collapsible
    - add a trailing `Migrate All` button in the section header scoped to that destination spread
    - list one row per migratable task; tapping a row migrates it into that destination with no additional confirmation
  - Remove the old migration banner, migration review sheet, and any coordinator/view code only used by that flow.
  - Reuse existing entry-row and section-header components wherever practical instead of introducing migration-only chrome when shared list affordances already exist.
- **Acceptance Criteria**:
  - Migrating a task updates assignment state correctly: destination becomes active, source becomes migrated history, and the source active list no longer shows the task. (Spec: Migration)
  - Source-row migration arrows appear only for tasks that have a smaller valid existing destination spread. (Spec: Migration)
  - Source-row confirmation alerts explicitly name the destination spread the task will move to. (Spec: Migration)
  - Destination spreads show a collapsible `Migrate tasks` section only when tasks from the immediate parent hierarchy can migrate into that spread. (Spec: Migration)
  - Tapping a destination task row migrates that one task into the current spread with no confirmation alert. (Spec: Migration)
  - Header `Migrate All` migrates all tasks listed in that destination spread's section. (Spec: Migration)
  - The old migration banner and migration review sheet no longer exist in conventional mode. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests:
    - migration changes the source assignment status to migrated and the destination assignment to active
    - migrated tasks no longer appear in the source spread's active list
    - migrated tasks do appear in the source spread's migrated subsection
    - source-row arrow visibility follows smallest-valid-destination rules
  - UI tests:
    - source-row arrow presents a confirmation alert naming the destination spread and migrates on confirm
    - destination `Migrate tasks` section appears only on valid destination spreads and lists only eligible tasks
    - tapping a destination task row migrates it and removes it from the source spread's active list
    - destination header `Migrate All` migrates every listed task for that destination
    - no migration banner or migration review sheet entry points remain
- **Dependencies**: SPRD-29, SPRD-30, SPRD-110, SPRD-111, SPRD-114, SPRD-116

### [SPRD-141] Refactor: Consolidate task create/edit form logic and reassignment behavior - [ ]
- **Context**: Task creation and task editing currently duplicate period/date form behavior. This drift has already produced a reassignment bug in the seeded navigator data: a task created from the `2026` year spread and later edited to `April 6, 2026` day can incorrectly resolve to the existing `January 1, 2026` day spread instead of remaining on the year spread until an April spread exists. The desired behavior is that the task stays on `2026`, appears in the April section with a `6` context label, then becomes migration-eligible for `April 2026` once that recommended month spread is created.
- **Description**: Extract a shared task editor form/state flow for create and edit, centralize task reassignment decisions so create/edit save paths cannot diverge, and update the task edit sheet so migration is driven by preferred date/period edits instead of a manual `migrated` status.
- **Implementation Details**:
  - Introduce a shared task editor form or view-model used by both `TaskCreationSheet` and `TaskDetailSheet`.
  - Consolidate ownership of:
    - title editing
    - period selection
    - date selection
    - period/date normalization and period-change date adjustment
    - validation and inline error presentation rules
  - Keep mode-specific shell behavior thin:
    - create mode handles creation-specific toolbar copy and callbacks
    - edit mode handles status, assignment history, and delete/cancel/restore affordances
  - Centralize task preferred-date/period reassignment behavior in one `JournalManager` helper or dedicated service, and have both create/edit paths use it consistently.
  - Remove manual `migrated` selection from the task edit sheet; `migrated` remains assignment/history-only.
  - Add a reusable icon-only task status control that matches the entry list status affordance and toggles draft state `open <-> complete`.
  - Move `Cancel Task` / `Restore Task` to bottom-sheet actions and keep `Delete Task` as a separate destructive action.
  - Replace the edit-sheet period picker with a menu-style picker.
  - Replace the edit-sheet date control with a menu-style summary row plus the existing inline period-appropriate picker.
  - When draft status is `complete` or `cancelled`, keep period/date controls visible but disabled and keep assignment history visible.
  - Re-enable those controls immediately if draft status returns to `open` before save.
  - Centralize task status icon/symbol metadata so `EntryListView` and the task edit sheet share one source of truth.
- **Acceptance Criteria**:
  - Task creation and task editing use one shared period/date normalization path. (Spec: Entries; Reassignment)
  - The task edit sheet does not allow the user to manually set `migrated`. (Spec: Task Status)
  - The task edit sheet status control is a reusable icon-only component that toggles `open <-> complete` in draft state only; changes persist only on save. (Spec: Entries)
  - `Cancel Task` / `Restore Task` appear as bottom actions; `Delete Task` remains separate. (Spec: Entries)
  - When the draft task status is `complete` or `cancelled`, period/date controls remain visible but are disabled, and assignment history remains visible. (Spec: Entries)
  - Returning the draft status to `open` re-enables period/date controls immediately before save. (Spec: Entries)
  - Entry-list status icons and task-edit-sheet status icons come from one shared source of truth. (Spec: Task Status)
  - Editing a task from `2026` to preferred assignment `April 6, 2026` day with no April month/day spread leaves it open on the `2026` year spread. (Spec: Reassignment)
  - In that state, the task appears in the April section of the year spread with a `6` contextual label. (Spec: Entry Lists)
  - Creating the recommended `April 2026` month spread makes that task appear in the destination spread's `Migrate tasks` section and surfaces the source-row migration arrow on the year spread. (Spec: Migration)
  - Reassignment no longer jumps edited tasks to unrelated existing spreads outside the desired date hierarchy. (Spec: Reassignment)
- **Tests**:
  - Unit tests:
    - shared editor state normalizes and adjusts date consistently for create and edit modes
    - task edit draft status toggles `open <-> complete` without persisting until save
    - `migrated` is not exposed as a user-editable edit-sheet option
    - complete/cancelled draft state disables period/date editing and reopening re-enables it
    - task status icon metadata is shared between entry-list and edit-sheet consumers
    - edit-time reassignment for `2026` → `April 6, 2026` day falls back to the year spread when no April month/day spread exists
    - creating `April 2026` after that edit surfaces the expected migration candidate
  - UI tests:
    - edit seeded year task to `April 6, 2026` day and verify it remains on the year spread under April with `6` context
    - create the recommended April spread and verify `Migrate tasks` appears on the April spread and the year-spread row gains a migration arrow
    - task edit icon toggle changes local draft status but persists only after tapping `Save`
    - complete/cancelled task edit state shows period/date controls disabled and restore/reopen returns them to enabled state in-draft
    - task edit sheet has no manual `migrated` status option
- **Dependencies**: SPRD-23, SPRD-24, SPRD-137, SPRD-138, SPRD-140

### [SPRD-142] Feature: Refine inline task-row editing actions and migration menu - [ ]
- **Context**: The current row interaction model still reflects the older "tap title / swipe for sheet" behavior. The updated spec moves open tasks toward row-wide inline editing with stable layout, lightweight row actions, and immediate migration shortcuts while preserving full-sheet editing for completed and cancelled tasks.
- **Description**: Update `EntryRowView` and the spread entry list interaction model so open-task rows enter inline title editing on row tap, expose only the new inline action row, and use descriptive immediate migration menu options.
- **Implementation Details**:
  - Refine `EntryRowView` interaction rules:
    - tapping anywhere on an open task row enters inline title editing and focuses the text field
    - tapping anywhere on a completed or cancelled task row opens the full task edit sheet
    - the title row must remain visually stable when inline editing begins; the only new visible layout is the secondary action row underneath
    - tapping outside the active inline-edit row dismisses inline editing, releases focus, and hides the secondary action row
    - `EntryListView` owns the currently active inline-edit task row so only one row can be active at a time
  - While an open task row is inline-editing:
    - show a secondary action row underneath with exactly two actions, ordered `edit sheet` then `migrate`
    - the pencil-writing action commits any inline title draft before opening the edit sheet
    - the migrate action is a `Menu` that applies immediately and only lists valid destinations
    - valid inline migrate labels are descriptive and can include `Today`, `Tomorrow`, a month-level next-month option like `May 2026`, and a same-day next-month option like `May 5, 2026`
  - Replace the leading static task status icon with the reusable task status toggle button in both passive and inline-active row states; the toggle remains pressable whenever the task status allows completion toggling.
- **Acceptance Criteria**:
  - Tapping any part of an open task row starts inline editing and focuses the title field; tapping completed or cancelled rows still opens the full task edit sheet. (Spec: Entries)
  - In the passive state the row shows the saved task title, not a placeholder prompt; when inline editing begins the title row remains visually stable and only the secondary action row appears underneath. (Spec: Entries)
  - Tapping outside the active inline-edit row dismisses focus, hides the secondary action row, and commits pending inline title changes via the existing blur semantics. (Spec: Entries)
  - While inline editing, the row shows only the two secondary actions `edit sheet` and `migrate`, and the leading status control uses the same reusable task status toggle component as the edit sheet in both passive and active states. (Spec: Entries)
  - Inline migrate menus show only valid destination options with descriptive labels and apply immediately on selection. (Spec: Migration)
  - Choosing the pencil-writing inline action commits any pending inline title change before opening the full edit sheet. (Spec: Entries)
- **Tests**:
  - Unit tests:
    - row interaction policy routes open tasks to inline editing and completed/cancelled tasks to full-sheet editing
    - inline migrate menu candidate generation returns only valid options with the expected descriptive labels for `Today`, `Tomorrow`, next-month month-level, and next-month same-day choices
    - choosing the inline pencil action commits a pending title draft before invoking the full edit-sheet callback
    - task row status toggle presentation uses a stable size/configuration in both passive and inline-active states
  - UI tests:
    - tapping an open task row enters inline title editing without opening the full sheet
    - tapping a completed or cancelled task row opens the full edit sheet
    - entering inline edit mode keeps the saved title visible except for the expected cursor/selection treatment and shows only the `edit sheet` and `migrate` secondary actions
    - tapping outside the active inline-edit row dismisses the keyboard and hides the inline action row
    - inline migrate menu shows the correct valid options and selecting one immediately updates assignment/reassignment state
    - tapping the inline pencil action commits the inline title draft and then opens the full edit sheet with the updated title
- **Dependencies**: SPRD-132, SPRD-140, SPRD-141

## Story: Scope trim for v1 (event deferment)

### User Story
- As a user, I want a focused v1 experience without event features so I can ship quickly and avoid half-built integrations.

### Definition of Done
- Event references are removed from v1 UI and copy. [SPRD-69]
- Events never appear in Release builds (data is stubbed/hidden). [SPRD-70]
- Event scaffolding remains in the codebase for v2 integration. [SPRD-70]

### [SPRD-69] Feature: Hide event surfaces in v1 UI - [x] Complete
- **Context**: Event scaffolding exists, but v1 should not expose events.
- **Description**: Remove event-specific UI and copy from v1 surfaces.
- **Implementation Details**:
  - Update spread header count summary to omit events.
  - Update empty state copy to reference tasks/notes only.
  - Gate entry list rendering to tasks/notes when events are disabled.
  - Remove event wording from placeholders and navigation labels.
- **Acceptance Criteria**:
  - Release UI does not mention events. (Spec: Non-Goals)
  - Entry lists show only tasks and notes in v1. (Spec: Entries)
- **Tests**:
  - UI tests for empty state copy and count summary.
- **Dependencies**: SPRD-28, SPRD-62

### [SPRD-70] Feature: Stub event data paths for v1 - [x] Complete
- **Context**: Production data should not surface events before integrations are ready.
- **Description**: Ensure event data is empty or ignored in v1 while keeping v2 scaffolding intact.
- **Implementation Details**:
  - Ensure production uses empty event repositories and v1 ignores event lists when building views.
  - Gate debug/mock event seeds behind an "events enabled" switch (or remove from v1 datasets).
  - Add a single gating mechanism to re-enable event plumbing in v2 (feature flag or build-time toggle).
- **Acceptance Criteria**:
  - Events never appear in Release builds. (Spec: Non-Goals)
  - Event scaffolding remains compile-ready for v2. (Spec: Events v2)
- **Tests**:
  - Unit test verifying event lists are empty when events are disabled.
- **Dependencies**: SPRD-9, SPRD-11

## Story: Events integration (v2 - deferred)

### User Story
- As a user, I want calendar-backed events integrated into my journal so I can see scheduled items alongside tasks.

### Definition of Done
- Event sources (EventKit and/or Google) are connected and synchronized.
- Event cache persists locally for offline display and is refreshed on app lifecycle events.
- Events render on applicable spreads without migrate actions.

### [SPRD-57] Feature: Event source + cache repository
- **Context**: Events are sourced from external calendars and cached locally.
- **Description**: Implement EventRepository backed by SwiftData to store cached external events and source metadata.
- **Implementation Details**:
  - `EventRepository` protocol:
    ```swift
    protocol EventRepository {
        func getEvents() -> [DataModel.Event]
        func getEvents(from startDate: Date, to endDate: Date) -> [DataModel.Event]
        func save(_ event: DataModel.Event) throws
        func delete(_ event: DataModel.Event) throws
    }
    ```
  - `SwiftDataEventRepository`: ModelContext-based implementation
  - Extend `DataModel.Event` with external identifiers (source/provider/calendar IDs) as needed for sync
  - Date range query uses FetchDescriptor with predicate for efficient filtering
  - Mock/test implementations for previews and tests
- **Acceptance Criteria**:
  - CRUD for events works via repository. (Spec: Persistence)
  - Cached events persist with source identifiers. (Spec: Events v2)
- **Tests**:
  - Repository CRUD integration tests
  - Date range query tests
- **Dependencies**: SPRD-9, SPRD-3

### [SPRD-59] Feature: Event sync + visibility logic
- **Context**: Events appear on spreads based on date overlap, not assignments.
- **Description**: Add event sync hooks and visibility queries to JournalManager.
- **Implementation Details**:
  - Sync entry point (manual + lifecycle triggers): pull from EventKit/Google into cache.
  - `JournalManager.eventsForSpread(period:date:) -> [DataModel.Event]`:
    - Query cached events from repository
    - Filter using `event.appearsOn(period:date:calendar:)`
  - `SpreadDataModel` includes `events: [DataModel.Event]?`
  - Event visibility computed on data model build (not stored)
- **Acceptance Criteria**:
  - Events appear on all applicable spreads. (Spec: Events v2)
  - Multiday events span multiple day spreads. (Spec: Events v2)
- **Tests**:
  - Unit tests for event visibility across year/month/day/multiday
  - Unit tests for multiday event spanning multiple spreads
- **Dependencies**: SPRD-57, SPRD-11

### [SPRD-60] Feature: Event source setup + settings
- **Context**: Users need to connect calendars and control what is shown.
- **Description**: Build event source setup flows and settings for calendar selection.
- **Implementation Details**:
  - EventKit permission request + calendar selection UI.
  - Google OAuth flow (if in scope) + calendar selection UI.
  - Per-calendar visibility toggles and refresh controls.
  - Surface authorization errors and limited-access states.
- **Acceptance Criteria**:
  - Users can connect calendar sources and control visibility. (Spec: Events v2)
- **Tests**:
  - Unit tests for calendar selection persistence
  - UI tests: source connection, permission denied states, and visibility toggles.
- **Dependencies**: SPRD-57, SPRD-11

### [SPRD-33] Feature: Event visibility in spread UI (v2)
- **Context**: Events must appear on all applicable spreads based on date overlap.
- **Description**: Render events in spread views for year/month/day/multiday.
- **Implementation Details**:
  - Events rendered with empty circle symbol
  - Events grouped with other entries or in separate section
  - Event row shows: symbol, title, timing indicator (all-day, time range, date range)
  - No swipe actions for migrate (events don't migrate)
  - Swipe actions: edit, delete only
  - Tapping opens `EventDetailView` (read-only unless write-back is in scope)
  - Multiday events: show on each day spread they span
- **Acceptance Criteria**:
  - Events visible on all applicable spread views. (Spec: Events v2)
  - Events not migratable from UI. (Spec: Events v2)
- **Tests**:
  - Unit tests for event inclusion across spread types
  - UI tests: events render in spread list and do not expose migrate actions.
- **Dependencies**: SPRD-59, SPRD-22

## Story: Notes support

### User Story
- As a user, I want to capture notes with extended content and migrate them explicitly so I can preserve important information.

### Definition of Done
- Note repository and note creation/edit UI are implemented.
- Notes migrate only explicitly and are excluded from batch migration.

### [SPRD-58] Feature: Note repository - [x] Complete
- **Context**: Notes need separate CRUD operations.
- **Description**: Implement NoteRepository protocol and SwiftData implementation.
- **Implementation Details**:
  - `NoteRepository` protocol:
    ```swift
    protocol NoteRepository {
        func getNotes() -> [DataModel.Note]
        func save(_ note: DataModel.Note) throws
        func delete(_ note: DataModel.Note) throws
    }
    ```
  - `SwiftDataNoteRepository`: ModelContext-based implementation
  - Mock/test implementations for previews and tests
- **Acceptance Criteria**:
  - CRUD for notes works via repository. (Spec: Persistence)
- **Tests**:
  - Repository CRUD integration tests
- **Dependencies**: SPRD-9, SPRD-3

### [SPRD-61] Feature: Note creation and edit views - [x] Complete
- **Context**: Notes have content field and different migration semantics.
- **Description**: Build note creation/edit UI with extended content support.
- **Implementation Details**:
  - `NoteCreationSheet`:
    - Title (required)
    - Content (multiline TextEditor, optional)
    - Preferred date/period
  - `NoteEditView`:
    - Edit title, content, date, period
    - Show assignment history (conventional mode only)
    - Migrate action (explicit only - button, not swipe suggestion)
    - Status: active/migrated (no complete/cancelled)
  - Migration: available via explicit button, NOT in batch migration banner
- **Acceptance Criteria**:
  - Notes can have extended content. (Spec: Entries)
  - Notes migrate only explicitly. (Spec: Entries)
- **Tests**:
  - Unit tests for note validation
  - Unit tests confirming notes excluded from batch migration
  - UI tests: note creation/edit with content, explicit migrate button only.
- **Dependencies**: SPRD-58, SPRD-22, SPRD-15

### [SPRD-34] Feature: Note migration UX - [x] Complete
- **Context**: Notes can migrate only explicitly.
- **Description**: Ensure note rows expose migrate action only when explicitly invoked.
- **Implementation Details**:
  - Note rows have migrate swipe action BUT:
    - NOT included in migration banner batch
    - NOT suggested in "Review" sheet
  - Migration only via:
    - Explicit swipe action on note row
    - "Migrate" button in NoteEditView
  - JournalManager excludes notes from `eligibleTasksForMigration()`
- **Acceptance Criteria**:
  - Notes are not suggested in migration banners. (Spec: Entries)
- **Tests**:
  - Unit tests for note eligibility rules.
  - UI tests: notes do not appear in migration banner but expose explicit migrate action.
- **Dependencies**: SPRD-61, SPRD-30

## Story: Multiday aggregation and UI

### User Story
- As a user, I want a multiday view that aggregates entries across a range so I can plan across several days.

### Definition of Done
- Multiday aggregation logic includes tasks and notes in range (events added in v2).
- Multiday spread UI shows range and grouped entries.

### [SPRD-18] Feature: Multiday aggregation - [x] Complete
- **Context**: Multiday spreads aggregate entries in range.
- **Description**: Aggregate entries by date range for multiday spreads (no direct assignment).
- **Implementation Details**:
  - `JournalManager.entriesForMultidaySpread(_:) -> [any Entry]`:
    - Query tasks/notes whose preferred date falls within multiday's startDate...endDate
    - No assignment status for multiday - show aggregated view
  - Multiday spread view uses aggregated data, not assignments
- **Acceptance Criteria**:
  - Multiday spreads show aggregated entries within range. (Spec: Spreads)
- **Tests**:
  - Unit tests for range aggregation across month/year boundaries.
- **Dependencies**: SPRD-14, SPRD-8

### [SPRD-32] Feature: Multiday spread UI - [x] Complete
- **Context**: Multiday spreads need a dedicated view.
- **Description**: Render multiday spread with range header and aggregated entries.
- **Implementation Details**:
  - `MultidaySpreadView`:
    - Header shows date range (e.g., "Jan 6 - Jan 12, 2026")
    - Entries grouped by day within range
    - Uses aggregation (not direct assignments)
    - No migration banner (multiday doesn't own entries)
- **Acceptance Criteria**:
  - Multiday UI shows range and aggregated entries. (Spec: Spreads)
- **Tests**:
  - Unit tests for range label formatting.
  - UI tests: multiday view shows range header, grouped entries, and no migration banner.
- **Dependencies**: SPRD-18, SPRD-28

## Story: Settings and preferences

### User Story
- As a user, I want to set my BuJo mode and first day of week so the app matches my workflow and calendar.

### Definition of Done
- Settings view exposes mode and first-day-of-week preferences.
- Preferences persist and affect multiday presets and mode state.

### [SPRD-20] Feature: Settings view (Mode + First Day of Week) - [x] Complete
- **Context**: Users need to configure BuJo mode and locale preferences.
- **Description**: Build Settings screen with mode selection and week start preference.
- **Implementation Details**:
  - Settings accessible via gear icon in navigation header
  - `SettingsView` sections:
    1. **Task Management Style** (mode selection)
       - Conventional: "Track tasks across spreads with migration history"
       - Traditional: "View tasks on their preferred date only"
       - Radio-button style selection using `ModeSelectionRow`
    2. **Calendar Preferences**
       - First day of week: "System Default", "Sunday", "Monday"
       - "System Default" uses `Locale.current.calendar.firstWeekday`
    3. **About** section (version, credits)
  - Persist settings via `@AppStorage` or UserDefaults
  - JournalManager observes mode changes and recomputes assignments
  - firstWeekday affects multiday preset calculations
- **Acceptance Criteria**:
  - Mode toggle reflects and updates current mode. (Spec: Modes)
  - First day of week preference persists and affects multiday presets. (Spec: Settings)
- **Tests**:
  - Unit tests for mode toggle state binding
  - Unit tests for firstWeekday affecting multiday date calculations
  - UI tests: changing mode and first-weekday persists and affects multiday preset ranges.
- **Dependencies**: SPRD-19, SPRD-7

## Story: Traditional mode navigation

### User Story
- As a user, I want a calendar-style year, month, and day flow so I can browse entries like a traditional journal.

### Definition of Done
- Traditional mapping uses virtual spreads without mutating created spreads.
- Year/month/day navigation works with proper entry filtering.
- Traditional mode tests pass.

### [SPRD-17] Feature: Traditional mode mapping - [x] Complete
- **Context**: Traditional mode uses virtual spreads without mutating created spreads.
- **Description**: Map preferred assignments to virtual spreads; migration updates preferred date/period.
- **Implementation Details**:
  - `TraditionalSpreadService`:
    - All year/month/day spreads are "available" regardless of created spreads
    - Entries appear only on their preferred period/date
    - No migration history shown (single assignment view)
  - Traditional navigation:
    - Virtual spread data model generated on-the-fly from entries
    - Does NOT create Spread records
  - Traditional migration:
    - Updates entry's preferred date/period
    - If conventional spread exists for destination, create assignment
    - If no conventional spread, assign to nearest parent or Inbox
    - Never mutate created spreads data
- **Acceptance Criteria**:
  - Traditional mode ignores created-spread records for navigation. (Spec: Modes)
  - Traditional migration falls back to nearest created parent or Inbox. (Spec: Modes)
- **Tests**:
  - Unit tests for virtual spread mapping and fallback logic.
- **Dependencies**: SPRD-20, SPRD-16

### [SPRD-35] Feature: Traditional year view - [x] Complete
- **Context**: Traditional mode starts at year view.
- **Description**: Build a year view listing months with entry counts.
- **Implementation Details**:
  - `TraditionalYearView`:
    - Grid of 12 months
    - Each month shows entry count for that month
    - Tapping month navigates to month view
    - Uses virtual spread data (not created spreads)
- **Acceptance Criteria**:
  - Year view is accessible in traditional mode. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for year aggregation logic.
  - UI tests: traditional year grid displays months and navigates to month view.
- **Dependencies**: SPRD-17

### [SPRD-36] Feature: Traditional month view - [x] Complete
- **Context**: Month view needs calendar-style layout.
- **Description**: Build a calendar grid month view for traditional mode.
- **Implementation Details**:
  - `TraditionalMonthView`:
    - Calendar grid layout (7 columns, 5-6 rows)
    - Day cells show entry count dots
    - Tapping day navigates to day view
    - Respects firstWeekday setting for column order
- **Acceptance Criteria**:
  - Month view supports drill-in to day. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for day selection mapping.
  - UI tests: traditional month grid taps a day and navigates to day view.
- **Dependencies**: SPRD-35

### [SPRD-37] Feature: Traditional day view - [x] Complete
- **Context**: Day view shows preferred assignments (events added in v2).
- **Description**: Render entries for a single day in traditional mode.
- **Implementation Details**:
  - `TraditionalDayView`:
    - Shows entries with preferred date matching this day
    - No migration history visible
    - Uses same `EntryRowView` components
- **Acceptance Criteria**:
  - Day view shows preferred assignments for the selected date. (Spec: Modes)
- **Tests**:
  - Unit tests for day view entry filtering.
  - UI tests: traditional day view shows entries for the selected date.
- **Dependencies**: SPRD-36

### [SPRD-38] Feature: Traditional navigation flow - [x] Complete
- **Context**: Drill-in should mirror iOS Calendar.
- **Description**: Wire year -> month -> day navigation with back stack.
- **Implementation Details**:
  - NavigationStack with path management
  - Year view at root
  - Push month view on month tap
  - Push day view on day tap
  - Back navigation via standard iOS patterns
  - Optional: pinch-to-zoom between levels
- **Acceptance Criteria**:
  - Navigation mirrors iOS Calendar drill-in. (Spec: Navigation and UI)
- **Tests**:
  - Integration test for navigation state transitions.
  - UI tests: traditional navigation drill-in and back stack behavior.
- **Dependencies**: SPRD-37

### [SPRD-53] Feature: Unit tests for traditional mode mapping - [x] Complete
- **Context**: Virtual spreads must be correct and stable.
- **Description**: Add tests for traditional mapping and parent fallback.
- **Acceptance Criteria**:
  - Tests confirm no mutation of created spread data. (Spec: Modes)
- **Tests**:
  - Unit tests for fallback to parent or Inbox.
- **Dependencies**: SPRD-38

## Story: Collections and repository tests

### User Story
- As a user, I want to create and edit collections as standalone pages so I can keep long-form notes.

### Definition of Done
- Collections model, list, and editor are implemented.
- Repository integration tests and collection tests pass.

### [SPRD-39] Feature: Collection model + repository - [x] Complete
- **Context**: Collections are plain text pages.
- **Description**: Implement Collection model and repository storage.
- **Implementation Details**:
  - `DataModel.Collection` @Model:
    ```swift
    @Model
    final class Collection: Hashable {
        @Attribute(.unique) var id: UUID
        var title: String
        var content: String
        var createdDate: Date
        var modifiedDate: Date
    }
    ```
  - `CollectionRepository` protocol with CRUD
  - SwiftData implementation
  - Content is plain text with no character limit (unbounded).
  - Collections list is sorted by modifiedDate descending (newest first).
  - Collections sync via Supabase using the same outbox + pull mechanism as other entities.
- **Acceptance Criteria**:
  - Collections persist title + plain text content. (Spec: Collections)
  - Collections list is sorted by modified date, newest first. (Spec: Collections)
- **Tests**:
  - Unit tests for collection CRUD.
- **Dependencies**: SPRD-19
- **Note**: Dependency changed from SPRD-38 (traditional navigation) to SPRD-19 (root navigation shell). Collections are independent of traditional mode and only require the root navigation entry point to be in place.

### [SPRD-40] Feature: Collections list UI - [x] Complete
- **Context**: Users need access to collections list.
- **Description**: Build collections list with create/delete actions.
- **Implementation Details**:
  - `CollectionsListView`:
    - Accessible from root navigation (button in header)
    - List of collections with title preview
    - "+" button to create new collection
    - Swipe to delete with confirmation
    - Tapping opens collection editor
- **Acceptance Criteria**:
  - Collections list is accessible from root navigation. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for list empty state and CRUD triggers.
  - UI tests: collections list create/open/delete flows.
- **Dependencies**: SPRD-39

### [SPRD-41] Feature: Collection detail editor - [x] Complete
- **Context**: Collections are plain text only.
- **Description**: Provide a plain text editor for a collection.
- **Implementation Details**:
  - `CollectionEditorView`:
    - Editable title field
    - TextEditor for content (plain text)
    - Auto-save on changes (debounced)
    - Updates modifiedDate on save
- **Acceptance Criteria**:
  - Edits persist to storage. (Spec: Collections)
- **Tests**:
  - Integration test for persistence of edits.
  - UI tests: collection editor autosaves and persists after navigation.
- **Dependencies**: SPRD-40

### [SPRD-54] Feature: Integration tests for repositories - [x] Complete
- **Context**: Persistence should be validated end-to-end.
- **Description**: Add integration tests for SwiftData repositories using test containers.
- **Acceptance Criteria**:
  - CRUD works for spreads/entries/collections. (Spec: Persistence)
- **Tests**:
  - Integration tests across all repositories.
- **Dependencies**: SPRD-41, SPRD-57, SPRD-58

### [SPRD-55] Feature: Integration tests for collections - [x] Complete
- **Context**: Collections are new model + UI flow.
- **Description**: Add integration tests for collection CRUD and persistence.
- **Acceptance Criteria**:
  - Collection edits persist across reloads. (Spec: Collections)
- **Tests**:
  - Integration test with in-memory container.
- **Dependencies**: SPRD-54

## Story: Sync and persistence

### User Story
- As a user, I want my data to sync across devices and work offline so I can journal anywhere.

### Definition of Done
- Supabase offline-first sync is implemented and validated.
- CloudKit is removed from v1 configuration and documentation.
- Offline-first QA checklist exists.

### [SPRD-42] Feature: Remove CloudKit configuration remnants - [x] Complete
- **Context**: CloudKit is removed from v1; SwiftData must remain local-only.
- **Description**: Remove CloudKit TODOs and configuration references from the codebase.
- **Implementation Details**:
  - Remove CloudKit TODOs/comments in `ModelContainerFactory`.
  - Verify SwiftData uses local storage only (no CloudKit configuration).
  - Ensure build settings do not include CloudKit containers.
- **Acceptance Criteria**:
  - No CloudKit configuration is present in v1 code or build settings. (Spec: Persistence)
- **Tests**:
  - Manual: confirm no CloudKit entitlements or container references in the project.
- **Dependencies**: SPRD-41
- **Note**: Likely already satisfied — the codebase has no CloudKit entitlements, no CloudKit container references, and no iCloud capability configuration. Verify manually and mark complete if confirmed.

### [SPRD-43] Feature: Remove CloudKit entitlements + document Supabase-only config - [x] Complete
- **Context**: CloudKit is out of scope for v1.
- **Description**: Ensure CloudKit entitlements are removed and documentation reflects Supabase-only sync.
- **Note**: Likely already satisfied — see SPRD-42 note. The project uses Supabase exclusively for sync.
- **Implementation Details**:
  - Remove iCloud/CloudKit capabilities if present.
  - Update docs to remove CloudKit references and clarify Supabase-only sync.
- **Acceptance Criteria**:
  - No CloudKit entitlements are present; docs reflect Supabase-only sync. (Spec: Persistence)
- **Tests**:
  - Manual: verify entitlements and docs.
- **Dependencies**: SPRD-42

### [SPRD-44] Feature: Offline-first manual QA checklist - [x] Complete
- **Context**: Offline-first sync must be validated.
- **Description**: Add a manual QA checklist for offline usage and sync behavior.
- **Implementation Details**:
  - Create QA document covering:
    - Offline create/edit/delete operations
    - Sync when coming back online
    - Conflict resolution behavior
    - Multi-device sync scenarios
- **Acceptance Criteria**:
  - QA doc covers offline create/edit/delete and sync reconciliation. (Spec: Persistence)
- **Tests**:
  - Manual test plan included.
- **Dependencies**: SPRD-43

## Story: Scope guard tests

### User Story
- As a user, I want guardrails that prevent out-of-scope features so v1 stays focused.

### Definition of Done
- Scope guard tests enforce non-goals (no week period, no automated migration, no past entry creation, no events in v1 UI).

### [SPRD-56] Feature: Scope guard tests - [x] Complete
- **Context**: Non-goals must not regress into v1.
- **Description**: Add tests that enforce no week assignment, no automated migration, no past entry creation, and no event surfaces in v1.
- **Acceptance Criteria**:
  - Tests fail if week periods, automated migration, or event surfaces appear in v1. (Spec: Non-Goals)
- **Tests**:
  - Unit tests for no-past-date creation and no week period exposure.
  - UI tests verifying event copy/actions are absent in v1.
- **Dependencies**: SPRD-55

## Dependency Graph (Simplified)

```
SPRD-1 -> SPRD-2 -> SPRD-3 -> SPRD-4 -> SPRD-5 -> SPRD-6 -> SPRD-7 -> SPRD-8
SPRD-8 -> SPRD-49
SPRD-8 -> SPRD-9 -> SPRD-10 -> SPRD-11 -> SPRD-12 -> SPRD-50
SPRD-11 -> SPRD-13 -> SPRD-14 -> SPRD-51 -> SPRD-15 -> SPRD-16 -> SPRD-52
SPRD-16 -> SPRD-19 -> SPRD-21 -> SPRD-22 -> SPRD-23
SPRD-23 -> SPRD-71
SPRD-22 -> SPRD-64
SPRD-19 -> SPRD-25 -> SPRD-26 -> SPRD-27 -> SPRD-62 -> SPRD-28 -> SPRD-31
SPRD-22 -> SPRD-24 -> SPRD-29 -> SPRD-30
SPRD-28 -> SPRD-69
SPRD-9 -> SPRD-70
SPRD-11 -> SPRD-70
V2: SPRD-9 -> SPRD-57 -> SPRD-59 -> SPRD-60 -> SPRD-33
SPRD-9 -> SPRD-58 -> SPRD-61 -> SPRD-34
SPRD-14 -> SPRD-18 -> SPRD-32
SPRD-19 -> SPRD-20 -> SPRD-17 -> SPRD-35 -> SPRD-36 -> SPRD-37 -> SPRD-38 -> SPRD-53
SPRD-19 -> SPRD-39 -> SPRD-40 -> SPRD-41 -> SPRD-54 -> SPRD-55 -> SPRD-56
SPRD-41 -> SPRD-42 -> SPRD-43 -> SPRD-44 -> SPRD-45 -> SPRD-63 -> SPRD-46 -> SPRD-47 -> SPRD-48
SPRD-46 -> SPRD-65
SPRD-62 -> SPRD-63
Supabase: SPRD-80 -> SPRD-81 -> SPRD-82 -> SPRD-83 -> SPRD-84
Supabase: SPRD-80 -> SPRD-94 -> SPRD-95 -> SPRD-85 -> SPRD-99 -> SPRD-96 -> SPRD-100 -> SPRD-86
Supabase: SPRD-85 -> SPRD-98, SPRD-87, SPRD-88, SPRD-89, SPRD-90
Supabase: SPRD-84 -> SPRD-91, SPRD-92, SPRD-93
Supabase: SPRD-84 -> SPRD-85A -> SPRD-84B
Supabase: SPRD-85A -> SPRD-85C
```

## Completed Tasks

### [SPRD-1] Feature: New Xcode project bootstrap (iPadOS/iOS 26) - [x] Complete
- **Context**: Work starts from a brand-new SwiftUI project with only boilerplate code.
- **Description**: Create a new iPadOS/iOS 26 SwiftUI app, set up folder structure, minimal root view, and baseline build/test configuration.
- **Implementation Details**:
  - Create new Xcode project targeting iPadOS 26 (primary) and iOS 26 with SwiftUI lifecycle
  - Folder structure:
    ```
    Bulleted/
    ├── App/                    # App entry point, scenes
    ├── DataModel/              # SwiftData models, protocols
    ├── Repositories/           # Repository protocols + implementations
    ├── Services/               # Business logic services
    ├── JournalManager/         # Core coordinator
    ├── Environment/            # AppEnvironment, DependencyContainer
    ├── Views/                  # SwiftUI views organized by feature
    │   ├── Navigation/
    │   ├── Spreads/
    │   ├── Entries/
    │   ├── Settings/
    │   └── Components/
    └── Additions/              # Extensions, utilities
    BulletedTests/              # Swift Testing tests
    ```
  - Minimal `BulletedApp.swift` with placeholder `ContentView`
  - Configure build settings for Debug/Release
- **Acceptance Criteria**:
  - App targets iPadOS 26 (primary) and iOS 26, builds, and launches with a placeholder root view. (Spec: Platform)
  - Project structure supports domain/data/UI separation. (Spec: Project Summary)
- **Tests**:
  - Swift Testing smoke test that instantiates the root view.
- **Dependencies**: None

### [SPRD-2] Feature: AppEnvironment + configuration - [x] Complete
- **Context**: Multiple environments are needed for mocking, preview, testing, and production.
- **Description**: Implement `AppEnvironment` with production/development/preview/testing and configuration helpers.
- **Implementation Details**:
  - `AppEnvironment` enum with cases: `.production`, `.development`, `.preview`, `.testing`
  - Static `current` property that checks (in order):
    1. Launch arguments (`-AppEnvironment <value>`)
    2. Environment variables (`APP_ENVIRONMENT`)
    3. Build configuration (`#if DEBUG`)
  - Computed properties:
    - `isStoredInMemoryOnly: Bool` - true for preview/testing
    - `usesMockData: Bool` - true for preview
    - `containerName: String` - unique per environment
  - Debug overlay (DEBUG builds only):
    - `DebugEnvironmentOverlay` view modifier showing current environment
    - Tap to expand/collapse detailed environment info
    - Applied to root ContentView in DEBUG builds
- **Acceptance Criteria**:
  - Environment can be selected via launch args/env vars. (Spec: Project Summary)
  - Preview/testing configurations use in-memory or mock storage. (Spec: Persistence)
  - Debug overlay shows current environment in DEBUG builds only. (Spec: Development tooling)
- **Tests**:
  - Unit tests for environment resolution from args/env.
- **Dependencies**: SPRD-1

### [SPRD-3] Feature: DependencyContainer + repository protocols - [x] Complete
- **Context**: Mocking and testing require injectable repositories and services.
- **Description**: Define repository protocols and `DependencyContainer` to wire SwiftData and mocks.
- **Implementation Details**:
  - `DependencyContainer` struct with:
    - `environment: AppEnvironment`
    - `modelContainer: ModelContainer`
    - `modelContext: ModelContext`
    - Repository properties (TaskRepository, SpreadRepository, EventRepository, NoteRepository, CollectionRepository)
  - Factory methods:
    - `static func make(for environment: AppEnvironment) throws -> DependencyContainer`
    - `static func make(taskRepo:, spreadRepo:, ...) throws -> DependencyContainer`
    - `func makeJournalManager(calendar:, today:, bujoMode:) -> JournalManager`
  - Service locator pattern for environment-specific implementations
- **Acceptance Criteria**:
  - Repositories are injectable and swappable for tests. (Spec: Project Summary)
  - App can be constructed with mock repositories in preview/testing. (Spec: Goals)
  - Debug overlay (from SPRD-2) shows DependencyContainer status in DEBUG builds. (Spec: Development tooling)
- **Tests**:
  - Unit tests that DependencyContainer can create mock/test configurations.
- **Dependencies**: SPRD-2

### [SPRD-4] Feature: SwiftData schema + migration plan scaffold - [x] Complete
- **Context**: Data models must be versioned from day one.
- **Description**: Add versioned SwiftData schema and empty migration plan.
- **Implementation Details**:
  - `DataModelSchemaV1: VersionedSchema` with version `1.0.0`
  - Models: `DataModel.Spread`, `DataModel.Task`, `DataModel.Note`, `DataModel.Collection` (Event reserved for v2)
  - `DataModelMigrationPlan: SchemaMigrationPlan` with empty stages (ready for future migrations)
  - Schema used by `ModelContainerFactory`
- **Acceptance Criteria**:
  - Schema versioning exists and compiles with all models. (Spec: Persistence)
- **Tests**:
  - Unit test that ModelContainer can be created with schema + migration plan.
- **Dependencies**: SPRD-3

### [SPRD-5] Feature: SwiftData repositories (Task/Spread) - [x] Complete
- **Context**: Core persistence is required for spreads and tasks.
- **Description**: Implement SwiftData repositories for spreads and tasks.
- **Implementation Details**:
  - `TaskRepository` protocol:
    ```swift
    protocol TaskRepository {
        func getTasks() -> [DataModel.Task]
        func save(_ task: DataModel.Task) throws
        func delete(_ task: DataModel.Task) throws
    }
    ```
  - `SpreadRepository` protocol:
    ```swift
    protocol SpreadRepository {
        func getSpreads() -> [DataModel.Spread]
        func save(_ spread: DataModel.Spread) throws
        func delete(_ spread: DataModel.Spread) throws
    }
    ```
  - SwiftData implementations: `SwiftDataTaskRepository`, `SwiftDataSpreadRepository`
  - Both are `@MainActor` with `ModelContext` dependency
  - Sort tasks by date ascending; spreads by period (desc) then date
- **Acceptance Criteria**:
  - CRUD for spreads/tasks works via repositories. (Spec: Persistence)
- **Tests**:
  - Repository CRUD integration tests in a test container.
- **Dependencies**: SPRD-4

### [SPRD-6] Feature: Mock/test repositories + in-memory containers - [x] Complete
- **Context**: Fast, deterministic tests and previews rely on mocks.
- **Description**: Add mock repositories and test container factory for Swift Testing.
- **Implementation Details**:
  - `mock_TaskRepository`, `mock_SpreadRepository` - in-memory with TestData seeding
  - `test_TaskRepository`, `test_SpreadRepository` - for unit tests with configurable data
  - `EmptyTaskRepository`, `EmptySpreadRepository` - for isolated testing
  - `ModelContainerFactory.makeTestContainer()` - in-memory container for tests
  - `TestModelContainer` helper with `makeInMemory()`, `makeTemporary()`, `cleanup()`
- **Acceptance Criteria**:
  - Mocks support seeding spreads/entries for UI and tests. (Spec: Goals)
- **Tests**:
  - Unit tests for mock repo behavior (save/delete/idempotency).
- **Dependencies**: SPRD-5

### [SPRD-7] Feature: Date utilities + period normalization - [x] Complete
- **Context**: Spread/date normalization must be consistent across modes and locales.
- **Description**: Add date helpers for year/month/day normalization and locale-based first weekday logic.
- **Implementation Details**:
  - `Date+Additions.swift` extensions:
    - `firstDayOfYear(calendar:) -> Date?`
    - `firstDayOfMonth(calendar:) -> Date?`
    - `startOfDay(calendar:) -> Date`
    - `getDate(calendar:, year:, month:, day:) -> Date`
  - First weekday logic:
    - Read from Settings (System Default, Sunday, Monday)
    - System Default uses `Locale.current.calendar.firstWeekday`
    - Used by multiday preset calculations
  - All date operations use explicit `Calendar` parameter (no implicit `.current`)
- **Acceptance Criteria**:
  - Normalization matches calendar periods and firstWeekday setting. (Spec: Spreads; Edge Cases)
- **Tests**:
  - Unit tests for normalization across locales and boundary dates.
  - Tests for different firstWeekday values.
- **Dependencies**: SPRD-6

### [SPRD-8] Feature: Spread model with multiday range - [x] Complete
- **Context**: Multiday spreads require start/end ranges and preset options. Week period removed.
- **Description**: Implement Spread model for year/month/day/multiday with range fields.
- **Implementation Details**:
  - `DataModel.Spread.Period` enum: `.year`, `.month`, `.day`, `.multiday` (NO `.week`)
  - Period extension methods:
    - `normalizeDate(_:calendar:) -> Date` - normalize to period start
    - `calendarComponent: Calendar.Component` - mapping to Calendar API
    - `canHaveTasksAssigned: Bool` - true for year/month/day, false for multiday
    - `childPeriod: Period?` - hierarchy (year → month → day)
    - `parentPeriod: Period?` - reverse hierarchy
  - `DataModel.Spread` @Model:
    ```swift
    @Model
    final class Spread: Hashable {
        @Attribute(.unique) var id: UUID
        var period: Period
        var date: Date           // Normalized date for period
        var startDate: Date?     // Only for multiday
        var endDate: Date?       // Only for multiday
    }
    ```
  - Multiday presets: "This Week", "Next Week" compute start/end based on firstWeekday setting
- **Acceptance Criteria**:
  - Multiday stores start/end; presets compute based on firstWeekday setting. (Spec: Spreads)
  - Week period does not exist in enum. (Spec: Non-Goals)
- **Tests**:
  - Unit tests for period normalization across all periods
  - Unit tests for multiday preset date calculation with different firstWeekday values
  - Unit tests confirming week period does not exist
- **Dependencies**: SPRD-7

### [SPRD-9] Feature: Entry protocol + Task/Note models (Event stub for v2) - [x] Complete
- **Context**: Entries are the parent concept; Task/Note are v1 types, Event is reserved for v2 integration.
- **Description**: Implement Entry protocol and v1 @Model classes, plus Event stub model for future integration.
- **Implementation Details**:
  - `Entry` protocol:
    ```swift
    protocol Entry: Identifiable, Hashable {
        var id: UUID { get }
        var title: String { get set }
        var createdDate: Date { get }
        var entryType: EntryType { get }
    }
    ```
  - `EntryType` enum: `.task`, `.note` (v1); `.event` reserved for v2
    - `imageName: String` - "circle.fill", "circle", "minus"
    - `displayName: String` - "Task", "Event", "Note"
  - `AssignableEntry` protocol (Task, Note):
    ```swift
    protocol AssignableEntry: Entry {
        associatedtype AssignmentType
        var date: Date { get set }
        var period: DataModel.Spread.Period { get set }
        var assignments: [AssignmentType] { get set }
    }
    ```
  - `DateRangeEntry` protocol (Event, v2):
    ```swift
    protocol DateRangeEntry: Entry {
        var startDate: Date { get }
        var endDate: Date { get }
        func appearsOn(period: Spread.Period, date: Date, calendar: Calendar) -> Bool
    }
    ```
  - `DataModel.Task` @Model: id, title, createdDate, date, period, status, assignments: [TaskAssignment]
  - `DataModel.Event` @Model (v2 stub):
    - `EventTiming` enum: `.singleDay`, `.allDay`, `.timed`, `.multiDay`
    - Properties: startDate, endDate, startTime?, endTime?, timing
    - `appearsOn(period:date:calendar:)` - checks date range overlap with spread
  - `DataModel.Note` @Model: id, title, content, createdDate, date, period, status, assignments: [NoteAssignment]
- **Acceptance Criteria**:
  - Task and Note types persist and map to correct symbols. (Spec: Core Concepts)
  - Event stub compiles but is not surfaced in v1 UI/flows. (Spec: Non-Goals)
  - Notes can have extended content. (Spec: Entries)
- **Tests**:
  - Unit tests for Entry protocol conformance for Task/Note
  - Unit tests for symbol mapping per type
- **Dependencies**: SPRD-8

### [SPRD-10] Feature: TaskAssignment + NoteAssignment models - [x] Complete
- **Context**: Assignment tracking differs between Task and Note.
- **Description**: Implement assignment structs for tracking per-spread status.
- **Implementation Details**:
  - Base `EntryAssignment` struct:
    ```swift
    struct EntryAssignment: Codable, Hashable {
        var period: Spread.Period
        var date: Date

        func matches(period: Spread.Period, date: Date, calendar: Calendar) -> Bool {
            guard self.period == period else { return false }
            let normalizedSelf = period.normalizeDate(self.date, calendar: calendar)
            let normalizedOther = period.normalizeDate(date, calendar: calendar)
            return normalizedSelf == normalizedOther
        }
    }
    ```
  - `TaskAssignment`: extends EntryAssignment + `status: Task.Status`
    - `Task.Status`: `.open`, `.complete`, `.migrated`, `.cancelled`
  - `NoteAssignment`: extends EntryAssignment + `status: Note.Status`
    - `Note.Status`: `.active`, `.migrated`
  - Event assignment/visibility rules are reserved for v2 integration
- **Acceptance Criteria**:
  - TaskAssignment supports per-spread status (open/complete/migrated). (Spec: Migration)
  - NoteAssignment supports per-spread status (active/migrated). (Spec: Entries)
- **Tests**:
  - Unit tests for assignment matching by period/date
  - Unit tests for assignment status updates
- **Dependencies**: SPRD-9

### [SPRD-11] Feature: JournalManager base - [x] Complete
- **Context**: Central coordinator is needed for spreads/entries lifecycle.
- **Description**: Implement JournalManager with data loading, caching, and versioning.
- **Implementation Details**:
  - `@Observable class JournalManager`:
    ```swift
    @Observable
    class JournalManager {
        let calendar: Calendar
        let today: Date
        let taskRepository: TaskRepository
        let spreadRepository: SpreadRepository
        let eventRepository: EventRepository
        let noteRepository: NoteRepository

        private(set) var dataVersion: Int = 0  // Triggers UI refresh
        var bujoMode: DataModel.BujoMode
        var creationPolicy: SpreadCreationPolicy

        var dataModel: JournalDataModel  // Nested dictionary [Period: [Date: SpreadDataModel]]
    }
    ```
  - Data loading on init: fetch spreads/tasks/notes (events only when enabled in v2)
  - Build `dataModel` dictionary organizing spreads by period/date
  - Increment `dataVersion` on any mutation for SwiftUI reactivity
- **Acceptance Criteria**:
  - JournalManager loads spreads and entries via repositories. (Spec: Project Summary)
- **Tests**:
  - Unit test initializes JournalManager with mock repositories.
- **Dependencies**: SPRD-10

### [SPRD-12] Feature: Spread creation policy - [x] Complete
- **Context**: Creation rules must match present/future constraints.
- **Description**: Enforce creation rules (no past; multiday start allowed within current week).
- **Implementation Details**:
  - `SpreadCreationPolicy` protocol:
    ```swift
    protocol SpreadCreationPolicy {
        func canCreateSpread(period: Period, date: Date, spreadExists: Bool, calendar: Calendar) -> Bool
    }
    ```
  - `StandardCreationPolicy`:
    - Year/Month/Day: only present or future (normalized date >= today's normalized date)
    - Multiday: start can be in past if within current week; end must be present or future
    - No duplicate spreads (same period + normalized date)
  - Policy injectable via JournalManager
- **Acceptance Criteria**:
  - Past spreads are blocked, except multiday start within current week. (Spec: Spreads)
- **Tests**:
  - Unit tests for creation validation across dates and multiday rules.
- **Dependencies**: SPRD-11

### [SPRD-50] Feature: Unit tests for spread creation rules - [x] Complete
- **Context**: Creation rules must be enforced consistently.
- **Description**: Add unit tests for present/future rules and multiday start handling.
- **Acceptance Criteria**:
  - Tests confirm past spreads are blocked except multiday within current week. (Spec: Spreads)
- **Tests**:
  - Unit tests for validation edge cases.
- **Dependencies**: SPRD-12
- **Note**: Tests implemented as part of SPRD-12 in `SpreadCreationPolicyTests.swift`

### [SPRD-13] Feature: Conventional assignment engine - [x] Complete
- **Context**: Entries must be assigned to created spreads or Inbox.
- **Description**: Assign tasks/notes to year/month/day (events deferred to v2).
- **Implementation Details**:
  - `ConventionalSpreadService`:
    - `getAvailableAssignment(for entry:, dataModel:) -> AssignmentResult?`
    - Search periods from finest to coarsest (day → month → year)
    - Skip periods that can't have tasks assigned (multiday)
    - Match entry's preferred period/date to existing spread
    - Return first available spread or nil (→ Inbox)
  - Multiday: aggregates entries whose dates fall within range (no direct assignment)
- **Acceptance Criteria**:
  - Tasks/notes assign to year/month/day only; multiday aggregates. (Spec: Entries)
- **Tests**:
  - Unit tests for assignment to nearest created parent spread.
- **Dependencies**: SPRD-11

### [SPRD-14] Feature: Inbox data model + auto-resolve - [x] Complete
- **Context**: Unassigned entries must be visible and auto-resolve.
- **Description**: Implement global Inbox for unassigned entries with auto-resolve on spread creation.
- **Implementation Details**:
  - Inbox is computed, not persisted:
    - Query tasks/notes where `assignments.isEmpty` or no matching spread exists
    - Events are not part of v1 (ignored in Inbox)
    - Exclude cancelled tasks
  - `JournalManager.inboxEntries: [any Entry]` - computed property
  - `JournalManager.inboxCount: Int` - for badge display
  - Auto-resolve logic in `addSpread()`:
    - After creating spread, query inbox entries matching spread's period/date
    - Create initial assignment for each matching entry
    - Trigger `dataVersion` increment
- **Acceptance Criteria**:
  - Inbox lists unassigned entries (tasks/notes only). (Spec: Modes)
  - Inbox auto-resolves when a spread is created. (Spec: Modes)
  - Cancelled tasks excluded. (Spec: Task Status)
- **Tests**:
  - Unit tests for Inbox population query
  - Unit tests for auto-resolve when spread created
  - Unit tests confirming cancelled tasks excluded
- **Dependencies**: SPRD-13

### [SPRD-51] Feature: Unit tests for assignment + Inbox - [x] Complete
- **Context**: Assignment and Inbox are core behaviors.
- **Description**: Add tests for assignment engine and Inbox auto-resolve.
- **Acceptance Criteria**:
  - Tests cover nearest parent assignment and Inbox auto-resolve. (Spec: Modes)
- **Tests**:
  - Unit tests for assignment selection across year/month/day.
- **Dependencies**: SPRD-14
- **Note**: Tests implemented as part of SPRD-13 in `ConventionalSpreadServiceTests.swift` and SPRD-14 in `InboxTests.swift`

### [SPRD-15] Feature: Migration logic (manual only) - [x] Complete
- **Context**: Migration must be user-triggered and type-specific.
- **Description**: Implement manual migration for tasks; allow explicit notes (events deferred to v2).
- **Implementation Details**:
  - `JournalManager.migrateTask(_:from:to:)`:
    - Find source assignment, set status to `.migrated`
    - Create destination assignment with status `.open`
    - Update task's top-level status
    - Persist via repository
  - `JournalManager.migrateNote(_:from:to:)`:
    - Same pattern with Note.Status (`.active` → `.migrated`)
    - Only callable from explicit UI action
  - `JournalManager.migrateTasksBatch(_:to:)`:
    - Batch migration for multiple tasks
    - Notes are NOT included in batch
  - **Spread deletion cascade**:
    - Query all entries (tasks/notes) with assignments to deleted spread
    - For each: reassign to parent spread OR Inbox if no parent
    - Preserve full assignment history (don't delete assignments)
    - Completed tasks: reassign like open tasks (never delete entries)
- **Acceptance Criteria**:
  - Migration only occurs when user triggers it. (Spec: Entries; Non-Goals)
  - Notes migrate only explicitly. (Spec: Entries)
  - Spread deletion never deletes entries. (Spec: Spreads)
- **Tests**:
  - Unit tests for migration chain and assignment updates.
  - Unit tests for spread deletion cascade behavior.
- **Dependencies**: SPRD-14

### [SPRD-16] Feature: Cancelled task behavior - [x] Complete
- **Context**: Cancelled tasks must be hidden and excluded.
- **Description**: Ensure cancelled tasks are excluded from Inbox, migration, and default lists.
- **Implementation Details**:
  - All task queries filter out `status == .cancelled` by default
  - Inbox query excludes cancelled
  - `eligibleTasksForMigration()` excludes cancelled
  - Spread entry lists exclude cancelled
  - Cancelled tasks remain in database for potential restore
- **Acceptance Criteria**:
  - Cancelled tasks are hidden and not migratable. (Spec: Task Status)
- **Tests**:
  - Unit tests confirming cancelled tasks are excluded from queries.
- **Dependencies**: SPRD-15

### [SPRD-52] Feature: Unit tests for migration rules - [x] Complete
- **Context**: Migration behavior differs by entry type and status.
- **Description**: Add tests for manual migration, note explicit migration, and cancelled exclusion.
- **Acceptance Criteria**:
  - Tests enforce manual-only migration and exclusion rules. (Spec: Entries; Task Status)
- **Tests**:
  - Unit tests for duplicate assignment prevention.
- **Dependencies**: SPRD-16
- **Note**: Tests implemented as part of SPRD-15 in `MigrationTests.swift` and SPRD-16 in `CancelledTaskTests.swift`

### [SPRD-19] Feature: Root navigation shell (adaptive layout) - [x] Complete
- **Context**: Collections must be outside spread navigation; Inbox in header. App must adapt to iPad and iPhone.
- **Description**: Build adaptive root navigation with entry points for Spreads, Collections, Settings, and Inbox.
- **Implementation Details**:
  - Adaptive navigation container using size classes:
    - **Regular width (iPad)**: `NavigationSplitView` with sidebar
      - Sidebar contains: Spreads, Collections, Settings (and Debug in DEBUG builds)
      - Detail view shows spread content with in-view spread tab bar
      - Inbox accessible from toolbar
    - **Compact width (iPhone)**: Tab-based navigation
      - Spreads destination renders the in-view hierarchical tab bar
      - Collections, Settings as separate tabs or sheets
      - Inbox badge/button in navigation bar
  - Navigation header with:
    - Inbox badge/button (count, opens sheet)
    - Settings gear icon (opens sheet on iPhone, sidebar item on iPad)
    - Collections button (opens sheet on iPhone, sidebar item on iPad)
  - Main content area switches based on BuJo mode:
    - Conventional: in-view hierarchical tab bar + content
    - Traditional: calendar navigation
  - iPad multitasking support:
    - Works correctly in Split View (1/3, 1/2, 2/3)
    - Works correctly in Slide Over
    - Graceful adaptation when size class changes during multitasking
  - Sheet presentations for Inbox (both platforms), Settings/Collections (iPhone)
- **Acceptance Criteria**:
  - Sidebar navigation on iPad (regular width). (Spec: Multiplatform Strategy)
  - Tab-based navigation on iPhone (compact width). (Spec: Multiplatform Strategy)
  - Spread navigation happens inside the spread view via the hierarchical tab bar on both platforms. (Spec: Navigation and UI)
  - Collections are accessible outside spread navigation. (Spec: Navigation and UI)
  - Inbox badge in header/toolbar. (Spec: Inbox)
  - App works correctly in iPad Split View and Slide Over. (Spec: Multiplatform Strategy)
- **Tests**:
  - UI-free integration test ensuring root view composes navigation containers.
  - Unit tests for size class adaptation logic.
- **Dependencies**: SPRD-16

### [SPRD-21] Feature: Entry symbol component - [x] Complete
- **Context**: Task/note symbols must be consistent across UI; event symbol reserved for v2.
- **Description**: Create a reusable symbol/status component for entries.
- **Implementation Details**:
  - `StatusIcon` view:
    - Task: solid circle (●) - "circle.fill"
    - Event: empty circle (○) - "circle" (v2 only)
    - Note: dash (—) - "minus"
  - Task status overlays:
    - Open: base circle
    - Complete: xmark overlay
    - Migrated: arrow.right overlay
    - Cancelled: slash overlay (hidden in v1)
  - Configurable size and color
- **Acceptance Criteria**:
  - Symbols render as solid/dash with task status indicators; event symbol remains v2-only. (Spec: Core Concepts)
- **Tests**:
  - Snapshot-free unit tests verifying symbol selection logic.
- **Dependencies**: SPRD-19, SPRD-9

### [SPRD-22] Feature: Entry row component + swipe actions - [x] Complete
- **Context**: Lists need consistent entry rendering and actions; event actions are v2-only.
- **Description**: Build a row component with type symbol, title, status, and swipe actions.
- **Implementation Details**:
  - `EntryRowView`:
    - StatusIcon (leading)
    - Title
    - Migration badge (if migrated, shows destination)
    - Trailing swipe actions
  - Swipe actions by type:
    - Task: Complete (trailing), Migrate (leading)
    - Note: Migrate (leading) - explicit only
    - Event: Edit, Delete only (no migrate) (v2 only)
  - Action callbacks via closures or environment
- **Acceptance Criteria**:
  - Task rows allow complete/migrate actions; notes only explicit migrate; event actions are v2-only. (Spec: Entries)
- **Tests**:
  - Unit tests for action availability per entry type/status.
- **Dependencies**: SPRD-21, SPRD-15
- **Note**: Visual refinements (greyed out styling, strikethrough for cancelled, past event overlays, migrated note overlays) deferred to SPRD-64.

### [SPRD-64] Feature: Entry row visual refinements (overlays and styling) - [x] Complete
- **Context**: Entry rows need visual treatment to indicate completed, migrated, and cancelled states; event styling reserved for v2.
- **Description**: Extend StatusIcon and EntryRowView to show status overlays and row styling for all entry states.
- **Implementation Details**:
  - `StatusIconConfiguration` updates:
    - Add `noteStatus: DataModel.Note.Status?` parameter
    - Add `isEventPast: Bool` parameter
    - Migrated notes show arrow (→) overlay on dash symbol
    - Past events show X overlay on empty circle symbol (v2 only)
  - `EntryRowConfiguration` updates:
    - Add `isEventPast: Bool` parameter (caller computes based on spread context)
    - Add `isGreyedOut: Bool` computed property (true for: complete tasks, migrated tasks/notes, past events when enabled)
    - Add `hasStrikethrough: Bool` computed property (true for cancelled tasks)
  - `EntryRowView` updates:
    - Apply greyed out foreground color when `isGreyedOut`
    - Apply strikethrough on entire row (symbol + title + trailing) when `hasStrikethrough`
  - Past event rules (computed by caller before passing to EntryRowView, v2 only):
    - Timed events: past when current time exceeds end time
    - All-day/single-day events: past starting the next day
    - Multi-day events: past status varies by spread; on a past day's spread, shows as past for that day only
- **Acceptance Criteria**:
  - Complete tasks show X overlay and greyed out row. (Spec: Task)
  - Migrated tasks show arrow overlay and greyed out row. (Spec: Task)
  - Cancelled tasks show strikethrough on entire row. (Spec: Task)
  - Migrated notes show arrow overlay and greyed out row. (Spec: Note)
  - Past events show X overlay and greyed out row (v2 only). (Spec: Event)
  - Current/active entries show normal styling. (Spec: Task, Note)
- **Tests**:
  - Unit tests for StatusIconConfiguration overlay selection for notes (events in v2).
  - Unit tests for EntryRowConfiguration `isGreyedOut` and `hasStrikethrough` properties.
  - Unit tests for past event rules (timed, all-day, multi-day) in v2.
- **Dependencies**: SPRD-22

### [SPRD-71] Feature: Task creation sheet - existing spread picker - [x] Complete
- **Context**: Users need a fast way to assign tasks to already created spreads.
- **Description**: Add a selection screen to choose from existing spreads or pick a custom date.
- **Implementation Details**:
  - In-sheet option to select from already created spreads + "Choose another date"
  - Opens a selection screen listing all spreads in chronological order (same ordering as spread tab bar)
  - Period filter buttons (year/month/day/multiday) are multi-select toggles; all on by default
  - Selecting a spread auto-fills period/date in the sheet (still editable afterward)
  - Multiday selection:
    - Show multiday spreads in the list
    - Tapping expands inline to list contained dates
    - Caption on multiday items: tasks cannot be assigned to multiday spreads; day selections appear on multiday
    - Choosing a date uses that day and sets period to day
  - "Choose another date" allows dates without existing spreads (task will go to Inbox if no match)
- **Acceptance Criteria**:
  - Spread picker lists all spreads chronologically with period filters applied. (Spec: Navigation and UI)
  - Period filters are multi-select toggles and default to showing all periods. (Spec: Navigation and UI)
  - Selecting a spread updates the task period/date and returns to the sheet; fields remain editable. (Spec: Entries)
  - Multiday items expand inline to show contained dates with caption explaining assignment behavior. (Spec: Entries)
  - "Choose another date" returns to custom date entry; tasks for dates without spreads go to Inbox. (Spec: Entries)
- **Tests**:
  - Unit tests:
    - Filter toggle logic and chronological ordering.
    - Multiday expansion date list generation.
  - UI tests:
    - Filter toggles show/hide periods as expected.
    - Selecting a spread populates period/date in the task sheet.
    - Multiday expansion allows date selection and sets period to day.
    - "Choose another date" path allows custom dates and saves successfully.
- **Dependencies**: SPRD-23, SPRD-13

### [SPRD-25] Feature: Conventional spread hierarchy component - [x] Complete
- **Context**: Conventional mode uses hierarchical spread navigation, adapting to platform.
- **Description**: Implement spread hierarchy component listing created spreads and create action.
- **Implementation Details**:
  - `SpreadHierarchyTabBar` (in-view component used on both iPad and iPhone):
    - Lists created spreads organized by hierarchy (year → month → day + multiday)
    - Chronological ordering within each level
    - Selected spread highlighted; inactive spreads secondary style
    - Progressive disclosure:
      - Selecting a year shows its months; tapping the expanded year again shows all years
      - Selecting a month shows its days + multiday; tapping the expanded month again shows all months
    - Initial selection is the smallest period containing today:
      - Prefer day over multiday
      - If multiple multiday spreads include today: earliest start date, then earliest end date, then earliest creation date
    - Sticky leading tabs for selected year and month; children scroll horizontally
    - Auto-scroll keeps the selected spread visible
    - "No spreads" label when a selected year/month has no children
    - Trailing "+" button always visible and opens `SpreadCreationSheet`
    - No creatable ghost suggestions in MVP
  - Spread selection updates the content view
  - Design constants in `SpreadHierarchyDesign`
- **Acceptance Criteria**:
  - Spread hierarchy lists created spreads only. (Spec: Navigation and UI)
  - Component is used inside the spread view on both iPad and iPhone. (Spec: Multiplatform Strategy)
  - Sticky year/month, scrollable children, and trailing "+" button behave as specified. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for spread list ordering and selection.
- **Dependencies**: SPRD-19, SPRD-8

### [SPRD-66] Feature: Spread hierarchy year/month picker on re-tap - [x] Complete
- **Context**: Re-tapping the selected year/month should present available options instead of toggling the list.
- **Description**: Replace the "show all" toggle with a native picker/menu listing created years/months.
- **Implementation Details**:
  - Update `SpreadHierarchyTabBar` re-tap behavior:
    - Selected year tab opens a picker/menu listing available years derived from created spreads.
    - Selected month tab opens a picker/menu listing available months for the selected year.
    - Selecting an option updates the selection and expands children (months or days/multiday), matching normal tap behavior.
  - Remove the "tap expanded year/month to show all items" toggle logic.
  - Keep "No spreads" placeholder as a label only (no interaction).
  - Use native SwiftUI components (e.g., `Menu` or `Picker`) that work on iPad and iPhone.
- **Acceptance Criteria**:
  - Re-tapping selected year/month opens a picker of created spreads only. (Spec: Navigation and UI)
  - Choosing a year shows that year spread and its months; choosing a month shows that month spread and its day/multiday children. (Spec: Navigation and UI)
  - "Show all" toggle behavior is removed. (Spec: Navigation and UI)
  - Behavior matches on iPad and iPhone. (Spec: Multiplatform Strategy)
- **Tests**:
  - Unit tests for picker option lists (created spreads only) and selection propagation.
- **Dependencies**: SPRD-25

### [SPRD-26] Feature: Spread creation sheet UI - [x] Complete
- **Context**: Users must create spreads explicitly.
- **Description**: Build create-spread UI for year/month/day/multiday with presets and override.
- **Implementation Details**:
  - `SpreadCreationSheet`:
    - Period selection (year, month, day, multiday)
    - Date picker (respects creation policy)
    - For multiday: preset buttons ("This Week", "Next Week") + custom range
    - Validation messages for invalid selections
    - Duplicate detection
  - Uses `SpreadCreationPolicy` for validation
- **Acceptance Criteria**:
  - Creation UI enforces present/future rules and multiday presets. (Spec: Spreads)
- **Tests**:
  - Unit tests for UI validation rules.
- **Dependencies**: SPRD-25, SPRD-12

### [SPRD-27] Feature: Spread content header - [x] Complete
- **Context**: Spread views need consistent metadata display.
- **Description**: Add header showing spread title and counts.
- **Implementation Details**:
  - `SpreadHeaderView`:
    - Period-appropriate title (e.g., "2026", "January 2026", "January 5, 2026")
    - Entry counts by type (tasks, notes) in v1
    - Multiday: show date range in header
- **Acceptance Criteria**:
  - Header reflects spread period/date and entry counts. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for header formatting by period.
  - UI tests: header title and counts update when switching spreads (year/month/day/multiday).
- **Dependencies**: SPRD-26

### [SPRD-62] Feature: Spread surface styling + dot grid background - [x] Complete
- **Context**: The app should feel like a minimal, readable journal with dot grid paper.
- **Description**: Apply paper tone and dot grid background to spread content surfaces only.
- **Implementation Details**:
  - Apply `DotGridView` as the background of spread content containers (year/month/day/multiday).
  - Keep navigation chrome, settings, and sheets on a flat paper tone without dots.
  - Default dot grid config: 1.5pt dots, 20pt spacing, muted blue dots at ~20-25% opacity.
  - Inset the first dot by one spacing unit from edges (no clipped dots).
  - Light mode paper tone: warm off-white (approx #F7F3EA).
  - Dark mode paper tone: warm dark variant (approx #1C1A18); navigation chrome uses system secondary background.
  - Dot color: muted blue, same in both light and dark modes.
  - Accent color uses muted blue for interactive controls and highlights.
  - Typography defaults: sans heading (e.g., Avenir Next) with system sans body text.
- **Acceptance Criteria**:
  - Dot grid appears only on spread content surfaces. (Spec: Visual Design)
  - Typography and accent color match the minimal paper aesthetic. (Spec: Visual Design)
  - Dark mode uses appropriate dark paper tone and system backgrounds for navigation. (Spec: Visual Design)
- **Tests**:
  - Manual visual verification across iPad/iPhone size classes.
  - Manual visual verification in light and dark modes.
- **Dependencies**: SPRD-27

### [SPRD-28] Feature: Conventional entry list + grouping - [x] Complete
- **Context**: Year/month/day grouping is required.
- **Description**: Implement grouping rules for entries in spread views.
- **Implementation Details**:
  - `TaskListView` with grouping:
    - Year spread: group by month
    - Month spread: group by day
    - Day spread: flat list
    - Multiday spread: group by day within range
  - Includes tasks and notes (events added in v2)
  - Uses `EntryRowView` for consistent rendering
- **Acceptance Criteria**:
  - Grouping matches period rules for tasks and notes. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for grouping logic.
  - UI tests: verify grouping sections for year/month/day/multiday spreads.
- **Dependencies**: SPRD-27, SPRD-22

### [SPRD-31] Feature: Inbox view + button styling - [x] Complete
- **Context**: Users access Inbox via a toolbar button; v1 uses yellow tint instead of badge count.
- **Description**: Build Inbox UI with toolbar button (yellow tint when non-empty) and sheet presentation. iPad button in spreads toolbar; iPhone in tab bar.
- **Implementation Details**:
  - `InboxButton`:
    - Toolbar button with `tray` icon
    - Yellow tint (`Color.yellow`) when `inboxCount > 0`; default tint when empty
    - No badge count overlay (liquid glass compatibility)
    - Taps present InboxSheetView
  - **Platform placement**:
    - iPad: Add inbox button to `ConventionalSpreadsView` toolbar (not sidebar)
    - iPhone: Keep existing tab navigation inbox button as-is
  - `InboxSheetView`:
    - List of unassigned tasks/notes (no events in v1)
    - Grouped by entry type (tasks first, then notes)
    - Each row: entry symbol, title, preferred date
    - Swipe action: assign to spread (opens spread picker)
  - Assign action: user picks spread, creates initial assignment
- **Acceptance Criteria**:
  - Inbox button shows in toolbar and uses yellow tint when non-empty (no badge count). (Spec: Navigation and UI)
  - Inbox hides cancelled tasks. (Spec: Modes)
  - Tapping opens sheet with unassigned entries. (Spec: Navigation and UI)
  - On iPad, inbox button appears in spread content toolbar, not sidebar. (Spec: Navigation and UI)
  - iPhone behavior remains unchanged. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for inbox indicator visibility based on count
  - Unit tests for entry grouping in sheet
  - UI tests: inbox button opens sheet, lists tasks before notes, excludes cancelled tasks.
  - Manual QA: verify yellow tint when non-empty; confirm iPad placement in spreads toolbar.
- **Dependencies**: SPRD-14, SPRD-22, SPRD-19
- **Note**: Incorporates SPRD-68 (button placement + tint)

### [SPRD-45] Feature: Debug menu (Debug builds only) - [x] Complete
- **Context**: Debug tooling is required for faster iteration.
- **Description**: Add debug menu to inspect environment, spreads, entries, inbox, and collections.
- **Implementation Details**:
  - `DebugMenuView` gated by `#if DEBUG`, organized under `Spread/Debug`.
  - Replace the `DebugEnvironmentOverlay` with a navigation destination:
    - iPhone: add a `Debug` tab bar item (SF Symbol `ant`).
    - iPad: add a `Debug` sidebar item (SF Symbol `ant`).
  - Grouped sections with labels and descriptions.
  - Shows:
    - Current `AppEnvironment` and configuration properties (from SPRD-2).
    - Dependency container summary.
    - Mock Data Sets loader (see SPRD-46) with overwrite + reload behavior.
  - Expands on the simple overlay from SPRD-2 with full data inspection.
- **Acceptance Criteria**:
  - Debug menu available only in Debug builds. (Spec: Development tooling)
  - Debug menu shows current AppEnvironment and configuration. (Spec: Development tooling)
  - Debug menu appears as a `Debug` tab/sidebar item and does not overlay the main UI. (Spec: Development tooling)
- **Tests**:
  - Unit test ensures debug menu is excluded in Release builds.
- **Dependencies**: SPRD-11

### [SPRD-46] Feature: Debug quick actions - [x] Complete
- **Context**: Developers need to create test data quickly.
- **Description**: Provide mock data sets that overwrite existing data for repeatable testing.
- **Implementation Details**:
  - Mock data sets are generated in code (no external fixtures).
  - Loading a data set clears existing data, loads the set, and triggers a reload.
  - Data sets cover spread scenarios and edge cases, including:
    - Empty state (clears all data)
    - Baseline year/month/day spreads for today
    - Multiday ranges (custom ranges and preset-based ranges)
    - Boundary dates (month/year transitions; leap day when applicable)
    - High-volume spread set for performance testing
- **Acceptance Criteria**:
  - Debug data sets cover multiday spreads and boundary cases. (Spec: Testing)
  - Loading a data set overwrites existing data. (Spec: Development tooling)
- **Tests**:
  - Unit tests for action data creation.
- **Dependencies**: SPRD-45

### [SPRD-67] Feature: Debug data loading via JournalManager - [x] Complete
- **Context**: Debug data loading bypasses JournalManager, causing stale UI state and crashes when mixing debug data with app UI flows.
- **Description**: Route debug data loading and clearing through JournalManager APIs to mirror app behavior and refresh UI immediately.
- **Implementation Details**:
  - Add JournalManager APIs to clear all data and load mock data sets using the same entry/spread creation flows as the app UI.
  - Create JournalManager methods for adding tasks/notes so debug data uses shared logic and assignments (events v2).
  - After load/clear, reload the JournalManager data model and reset selection to today's best matching spread (or nil if none).
  - Update Debug UI to call JournalManager instead of direct repository mutations.
- **Acceptance Criteria**:
  - Loading a mock data set updates the UI immediately without relaunch. (Spec: Development Tooling)
  - Adding mock data, then creating spreads or entries via the app UI does not crash. (Spec: Development Tooling)
  - Debug data loading uses JournalManager APIs, not direct repository writes. (Spec: Development Tooling)
- **Tests**:
  - Manual QA: load each mock data set, verify spreads render immediately, then add a spread and task to confirm no crash.
- **Dependencies**: SPRD-46, SPRD-11

### [SPRD-80] Feature: Supabase environments + MCP workflow - [x] Complete
- **Context**: CloudKit is replaced with Supabase; we need dev/prod environments and a repeatable workflow.
- **Description**: Create Supabase dev/prod projects, configure auth providers, and document local config + MCP usage.
- **Implementation Details**:
  - Create Supabase projects for dev and prod; record project URLs and publishable keys.
  - Configure Auth providers: email/password enabled. Sign in with Apple and Google deferred to SPRD-91.
  - Add local config via build settings in project.pbxproj for Supabase environment URLs/keys.
  - Document Supabase CLI setup and migrations workflow in `docs/supabase-setup.md`.
  - Use the Supabase MCP server with Claude for schema inspection and migration execution.
- **Acceptance Criteria**:
  - Dev/prod projects exist and are reachable. ✓
  - Email/password auth enabled in both environments. ✓ (Apple/Google deferred to SPRD-91)
  - Local config supports switching environments in Debug builds. ✓
- **Tests**:
  - Manual: sign-in works against both dev and prod projects.
- **Dependencies**: None
- **Note**: Sign in with Apple and Google auth providers deferred to SPRD-91.

### [SPRD-81] Feature: Supabase schema + migrations (core entities) - [x] Complete
- **Context**: Local SwiftData models must map 1:1 to Supabase.
- **Description**: Define tables, constraints, and indexes for v1 entities.
- **Implementation Details**:
  - Tables: `spreads`, `tasks`, `notes`, `task_assignments`, `note_assignments`, `collections`, `settings`.
  - Common columns: `id` (uuid PK), `user_id` (uuid), `device_id` (uuid), `created_at` (timestamptz), `updated_at` (timestamptz), `deleted_at` (timestamptz), `revision` (bigint).
  - Period fields stored as text with CHECK (`year|month|day|multiday`).
  - Date-only fields stored as `date` (spread date, assignment date, preferred date).
  - Add per-field `*_updated_at` columns needed for field-level LWW.
  - Add unique constraints (e.g., `spreads` on `user_id, period, date`; assignments on `user_id, entry_id, period, date`).
  - Add FK constraints between entries and assignments; add indexes for `(user_id, revision)` and `(user_id, deleted_at)`.
  - Apply migrations using Supabase CLI (via MCP for verification).
- **Acceptance Criteria**:
  - Migrations apply cleanly to dev and prod.
  - Core entities have required constraints and indexes.
- **Tests**:
  - Verify schema via Supabase MCP query checks.
- **Dependencies**: SPRD-80

### [SPRD-82] Feature: RLS policies + auth isolation - [x] Complete
- **Context**: Data must be private per user.
- **Description**: Enable RLS and add policies for all tables.
- **Implementation Details**:
  - Enable RLS on all tables.
  - Policies: allow select/insert/update/delete where `user_id = auth.uid()`.
  - Ensure service role can run cleanup jobs.
  - Verify anon key cannot access other users' data.
- **Acceptance Criteria**:
  - Cross-user access is blocked by default.
  - Authenticated users can CRUD only their own rows.
- **Tests**:
  - Manual policy checks using Supabase SQL editor or MCP queries.
- **Dependencies**: SPRD-81

### [SPRD-83] Feature: DB triggers + revision + merge RPCs - [x] Complete
- **Context**: Field-level LWW and incremental sync require server-side metadata.
- **Description**: Implement triggers and RPC functions for merge and revision.
- **Implementation Details**:
  - Add triggers to set `updated_at` and per-field `*_updated_at` using `changed_fields`.
  - Maintain a monotonic `revision` per table (global sequence).
  - Implement merge RPCs per table that apply field-level LWW and enforce delete-wins.
  - Ensure merges are atomic and return the canonical row.
- **Acceptance Criteria**:
  - Field-level updates preserve newer values.
  - `deleted_at` wins over stale updates.
  - Incremental sync can use `revision`.
- **Tests**:
  - RPC tests in dev using Supabase MCP calls.
- **Dependencies**: SPRD-81, SPRD-82

### [SPRD-84] Feature: Supabase client + auth integration - [x] Complete
- **Context**: The app needs authenticated sync with optional local-only usage.
- **Description**: Add Supabase Swift client and implement email/password auth with login UI.
- **Implementation Details**:
  - Integrate Supabase Swift client via SPM.
  - Add auth button in toolbar (trailing Inbox button):
    - Logged out: `person.crop.circle` icon, opens login sheet
    - Logged in: `person.crop.circle.fill` icon, opens profile sheet
  - Login sheet (logged out):
    - Email and password fields
    - Sign In button (disabled until fields populated)
    - Error message display for failed login attempts
    - Sheet dismisses on successful login
  - Profile sheet (logged in):
    - Shows user email
    - Sign Out button in toolbar
    - Sign out confirmation alert (warns local data will be wiped)
  - Support local-only usage prior to sign-in.
  - Generate and store `device_id` in Keychain.
  - On sign-in: merge local data with server (field-level LWW via merge RPCs).
  - On sign-out: wipe local store and outbox; reset sync state.
- **Acceptance Criteria**:
  - Users can sign in with email/password.
  - Users can sign out with confirmation.
  - Local-only mode works offline without sign-in.
  - Auth button reflects current auth state.
- **Tests**:
  - Manual auth flows on dev project.
- **Dependencies**: SPRD-80, SPRD-83
- **Note**: Sign up, forgot password (SPRD-92), form validation (SPRD-93), and Apple/Google sign-in (SPRD-91) are separate tasks.

### [SPRD-85A] Feature: Debug sync + network mocking controls - [x] Partial
- **Context**: SPRD-85 requires testing offline, auth failures, and sync UI states without relying on real network behavior.
- **Description**: Add Debug-only runtime overrides for network, auth, and sync engine behavior plus scenario presets.
- **Implementation Details**:
  - Add `DebugSyncOverrides` (DEBUG-only) to hold overrides:
    - `blockAllNetwork: Bool` (forces NWPathMonitor offline and fails all requests).
    - `disableSync: Bool` (prevents auto/manual sync triggers).
    - `forcedAuthError: AuthErrorType?` (invalid credentials, email not confirmed, user not found, rate limited, network timeout).
    - `forcedSyncFailure: Bool` (whole-sync failure injection).
    - `forceSyncingDuration: TimeInterval` (default 5s) with engine paused while UI shows syncing.
    - `outboxSeedCount: Int` (creates real `SyncMutation` rows).
  - Add "Sync & Network" section in Debug destination:
    - Manual toggles/sliders for each override.
    - Scenario presets (one-tap combinations) + "Reset overrides".
    - Live sync readout: network status, last sync time, outbox count, current sync error.
  - Network blocking:
    - Route app network requests through a debug-interceptable client (e.g., custom `URLSession` + `URLProtocol`) so block-all works for Supabase and any other requests.
    - When `blockAllNetwork` is on, force connectivity status to offline and return a deterministic offline error for requests.
  - Auth mocking:
    - Auth service consults `forcedAuthError` before making network calls and returns a matching error.
  - Sync engine:
    - All sync triggers (auto + manual) consult overrides.
    - `disableSync` bypasses scheduling and manual sync.
    - `forceSyncingDuration` pins UI state to syncing for 5s while engine is paused, then resumes.
    - `forcedSyncFailure` returns a single whole-sync error (no partial-table failures for now).
  - Outbox seeding:
    - "Seed outbox" action creates real `SyncMutation` rows using existing schema, then refreshes status.
  - Overrides do not need to persist across relaunch.
  - **Architecture note (debug-only policies/extensions)**:
    - Implement debug policies in `Spread/Debug` to avoid `#if DEBUG` in core services.
    - Pseudocode:
      ```swift
      #if DEBUG
      struct DebugSyncPolicy: SyncPolicy {
        @MainActor let overrides = DebugSyncOverrides.shared
        func shouldAllowSync() -> Bool { !overrides.disableSync }
        func forceSyncFailure() -> Bool { overrides.forcedSyncFailure }
        func forceSyncingDuration() -> TimeInterval? { overrides.forceSyncingDuration }
      }
      #endif
      ```
- **Acceptance Criteria**:
  - Debug builds can block all network traffic and observe offline UI consistently.
  - Auth error selection produces the chosen login failure without real network.
  - Sync can be disabled, forced to show syncing for 5s, or forced to fail as a whole.
  - Outbox seeding creates real rows and reflects in sync status UI.
  - Scenario presets apply multiple overrides at once and can be reset.
- **Tests**:
  - Manual QA in Debug:
    - Toggle block-all network and verify sync + login behave as offline.
    - Choose each auth error and verify login sheet displays the error.
    - Force syncing for 5s and confirm engine pauses and resumes.
    - Force whole-sync failure and verify error status.
    - Seed outbox and verify count/status changes.
- **Dependencies**: SPRD-45, SPRD-84, SPRD-85
- **Partial completion note**: Network blocking, auth error forcing, and live sync readout are implemented. Force sync states UI, disable sync toggle, outbox seeding, and scenario presets are deferred to SPRD-85C.

### [SPRD-85C] Feature: Debug sync forcing, outbox seeding, and scenario presets - [x] Complete
- **Context**: SPRD-85A delivered the core debug mocking controls (network blocking, auth error forcing, live sync readout) but deferred several acceptance criteria. The backend wiring exists (`DebugSyncPolicy.forcedSyncingDuration`, `DebugSyncPolicy.isForceSyncFailure`) but UI controls and additional features are missing.
- **Description**: Complete the remaining SPRD-85A acceptance criteria by adding DebugMenuView controls for sync state forcing, a disable-sync toggle, outbox seeding, and scenario presets.
- **Implementation Details**:
  - Add DebugMenuView toggles/controls for:
    - Disable sync toggle (prevents auto/manual sync triggers via `DebugSyncPolicy`).
    - Force "syncing" state for 5s (binds to `DebugSyncPolicy.forcedSyncingDuration`; engine pauses while UI shows syncing, then resumes).
    - Force whole-sync failure toggle (binds to `DebugSyncPolicy.isForceSyncFailure`).
  - Add "Seed Outbox" action that creates real `SyncMutation` rows using existing schema, then refreshes sync status UI.
  - Add scenario presets section with one-tap combinations of overrides (e.g., "Offline + Auth Failure", "Sync Backlog") plus a "Reset All Overrides" button.
  - Access `DebugSyncPolicy` from `syncEngine.policy` (already internal access) via downcast, consistent with existing `DebugNetworkMonitor` and `DebugAuthService` patterns.
- **Acceptance Criteria**:
  - Sync can be disabled via toggle; auto and manual sync triggers are blocked while active.
  - Force syncing for 5s pins UI state to syncing while engine is paused, then resumes.
  - Force whole-sync failure produces error status on next sync attempt.
  - "Seed outbox" creates real `SyncMutation` rows and count is reflected in sync status UI.
  - Scenario presets apply multiple overrides at once and can be reset with one tap.
- **Tests**:
  - Manual QA in Debug:
    - Toggle disable sync and verify auto/manual sync is blocked.
    - Force syncing for 5s and confirm engine pauses and resumes.
    - Force whole-sync failure and verify error status.
    - Seed outbox and verify count/status changes.
    - Apply a scenario preset and verify all overrides are set; reset and verify all cleared.
- **Dependencies**: SPRD-85A

### [SPRD-94] Feature: Build configurations (Debug/QA/Release) - [x] Complete
- **Context**: Environment switching must be enabled in Debug + QA TestFlight builds but disabled in Release.
- **Description**: Add a QA/TestFlight build configuration that behaves like Debug, with separate bundle id from Release.
- **Implementation Details**:
  - Add build configs: Debug, QA (TestFlight), Release.
  - QA uses DEBUG compile flag to include Debug menu; Release excludes all debug UI.
  - QA and Release have distinct bundle identifiers.
  - Add QA xcconfig with default Supabase dev values (same as Debug) and clear naming in build settings.
  - **Architecture note (build gating)**:
    - Centralize build gating in a small helper (e.g., `BuildInfo`) used by UI and resolvers.
    - Pseudocode:
      ```swift
      enum BuildInfo {
        static var allowsDebugUI: Bool { /* DEBUG or QA */ }
        static var defaultDataEnvironment: DataEnvironment { /* Debug->localhost, QA->dev, Release->prod */ }
        static var isRelease: Bool { /* Release only */ }
      }
      ```
- **Acceptance Criteria**:
  - Debug + QA builds show Debug menu and environment switcher.
  - Release build hides all debug UI.
  - Release build can target dev/localhost via launch args/env vars (with explicit URL/key overrides).
  - QA build installs alongside Release due to distinct bundle id.
- **Tests**:
  - Manual: verify Debug/QA show Debug menu; Release does not.
- **Dependencies**: SPRD-80

### [SPRD-95] Feature: Split BuildEnvironment vs DataEnvironment - [x] Complete
- **Context**: Current AppEnvironment mixes build intent with data target and debug behavior.
- **Description**: Introduce a DataEnvironment (localhost/dev/prod) separate from build configuration.
- **Implementation Details**:
  - Add `DataEnvironment` enum with behaviors: auth required, sync enabled, local-only availability.
  - Build configuration determines whether debug UI is available (via `BuildInfo`), not the data target.
  - Resolution order (all builds): `-DataEnvironment` -> `DATA_ENVIRONMENT` -> persisted selection (Debug/QA only) -> build default.
  - Release honors launch args/env vars for the current run but does not persist overrides.
  - Persist selected DataEnvironment and track last-used value in UserDefaults for Debug/QA only.
  - Add Supabase URL/key overrides via launch args and env vars in all builds:
    - Args: `-SupabaseURL`, `-SupabaseKey`
    - Env vars: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`
  - Require explicit URL/key overrides when targeting non-prod in Release; otherwise fall back to build defaults.
  - Rename launch arguments and env vars from AppEnvironment to DataEnvironment.
  - Update Debug menu to show only DataEnvironment options (localhost/dev/prod) and to respect build gating.
  - Keep AppEnvironment focused on preview/testing behaviors (in-memory, mock data); data targeting lives in DataEnvironment.
  - **Architecture note (separate debug implementations)**:
    - Keep DataEnvironment resolution in non-debug files; debug-only overrides live in `Spread/Debug`.
    - Pseudocode:
      ```swift
      protocol DataEnvironmentResolver {
        func resolve() -> DataEnvironment
      }

      struct DefaultDataEnvironmentResolver: DataEnvironmentResolver {
        func resolve() -> DataEnvironment {
          if let arg = launchArg("-DataEnvironment") { return arg }
          if let env = envVar("DATA_ENVIRONMENT") { return env }
          if BuildInfo.allowsDebugUI, let persisted = persistedSelection { return persisted }
          return BuildInfo.defaultDataEnvironment
        }
      }
      ```
  - **Carry-over from feature/SPRD-85 (do not cherry-pick whole commits, port selectively):**
    - `b86ae37` (`Spread/Environment/AppEnvironment.swift`): reuse resolution-order pattern + behavior flags, but move into new `DataEnvironment`.
    - `dcc3deb` (`Spread/Environment/SupabaseConfiguration.swift`): reuse `isAvailable` + `configure(for:)` pattern; update to DataEnvironment/build gating.
    - `d79b227` (`Spread/Environment/DependencyContainer.swift`): keep optional `supabaseClient` and only create it when sync is enabled; pass DataEnvironment into SyncEngine factory.
    - `35658f9` (`Spread/Services/AuthManager.swift`): keep localhost mock-auth path and optional Supabase client, but adapt to DataEnvironment.
    - `7c06c01` (`Spread/Debug/DebugSyncOverrides.swift`), `14dcb15` (`Spread/Services/Sync/NetworkMonitor.swift`), `785500a` (`Spread/Services/AuthManager.swift`), `ce46dca` (`Spread/Debug/DebugSyncNetworkSection.swift`): reapply debug overrides + Sync & Network section as Debug/QA-only tooling.
    - **Avoid** `226370a` (`Spread/DataModel/ModelContainerFactory.swift`): it adds per-environment container names, which conflicts with the single-store requirement.
- **Acceptance Criteria**:
  - DataEnvironment drives auth/sync/mock-data availability.
  - Resolver precedence works in all builds (args/env override persisted selection).
  - Debug/QA persist selection; Release never persists overrides.
  - Release uses build defaults when no overrides are provided.
  - Supabase URL/key can be overridden via args/env vars in any build.
- **Tests**:
  - Unit tests for DataEnvironment resolution precedence (Debug/QA vs Release behavior).
- **Dependencies**: SPRD-94

### [SPRD-85] Feature: Offline-first sync engine (outbox + pull + eligibility gating) - [x] Complete
- **Context**: Sync must work without reliable connectivity. Backup is a premium feature; not every signed-in account can sync.
- **Description**: Implement outbox-based push + incremental pull with status UI, and gate sync availability on both auth state and backup entitlement.
- **Implementation Details**:
  - Add `SyncMutation` SwiftData model for outbox entries (full record + `changed_fields`).
  - Enqueue outbox mutations on repository writes (tasks/notes/spreads/assignments/collections/settings).
  - Push: batch RPC merge calls (parent-first ordering).
  - Pull: incremental per-table sync using `revision`, with pagination and `last_sync` cursor stored locally.
  - Gate sync with `NWPathMonitor`; auto sync on launch/foreground + manual refresh.
  - Add exponential backoff on failure; store a capped local SyncLog.
  - Introduce a sync entitlement flag (e.g., `AuthState.canSync` or `SyncEligibility`) populated from a profile flag.
  - Update `SyncEngine` to block auto/manual sync when `canSync == false` and set a distinct status for signed-in-but-not-entitled users.
  - Update `SyncStatus`/`SyncStatusView` to use SF Symbol `exclamationmark.arrow.triangle.2.circlepath` (grey) for the "backup unavailable" state.
  - Keep outbox mutations enqueued locally while not entitled; block sync attempts only.
  - Make toolbar sync status icon-only and surface any status copy in a minimal banner/status line near the top of the main spreads content.
  - Trigger a sync attempt when entitlement becomes active (e.g., after purchase or refresh).
  - **Architecture note (protocol + policy injection)**:
    - Define a `SyncPolicy` protocol in non-debug files and inject it into `SyncEngine`.
    - Use `DefaultSyncPolicy` in Release builds; debug policies live in `Spread/Debug`.
    - Pseudocode:
      ```swift
      protocol SyncPolicy {
        func shouldAllowSync() -> Bool
        func forceSyncFailure() -> Bool
        func forceSyncingDuration() -> TimeInterval?
      }

      struct DefaultSyncPolicy: SyncPolicy {
        func shouldAllowSync() -> Bool { true }
        func forceSyncFailure() -> Bool { false }
        func forceSyncingDuration() -> TimeInterval? { nil }
      }

      final class SyncEngine {
        init(policy: SyncPolicy = DefaultSyncPolicy(), ...) { ... }
        func syncNow() async {
          guard policy.shouldAllowSync() else { return }
          ...
        }
      }
      ```
- **Acceptance Criteria**:
  - Mock data loading options in Debug menu only available when localhost Data Environment is selected.
  - Offline edits sync when connectivity returns.
  - Sync is idempotent and resilient to retries.
  - Repository writes enqueue outbox mutations and use serializers.
  - Device ID is included in outbox record data.
  - Logged out: sync is unavailable; local-only behavior persists.
  - Logged in without backup entitlement: no sync attempts; status icon shows `exclamationmark.arrow.triangle.2.circlepath`.
  - Logged in with backup entitlement: normal sync behavior.
  - Toolbar sync status is icon-only; status copy appears in a minimal banner/status line near the top of the main spreads content.
- **Tests**:
  - Unit tests for outbox enqueue and sync ordering.
  - Integration tests for push/pull with dev Supabase project.
  - Unit tests for enqueue + serializer output coverage (task/spread/note/assignment/collection).
  - Unit tests: sync gating for logged-out, logged-in without entitlement, and entitled states.
  - Unit tests: status icon/state mapping for "backup unavailable."
- **Dependencies**: SPRD-83, SPRD-84, SPRD-95

### [SPRD-99] Feature: Auth lifecycle wiring (merge + wipe + device ID) - [x] Complete
- **Context**: Most auth lifecycle wiring was completed in SPRD-85 (commits 13-14): sign-in merge/discard prompt, sign-out wipe, DeviceIdManager injection, auto-sync start/stop, and post-sync reload. Remaining work is entitlement-aware merge gating, collection wipe, and unit tests.
- **Description**: Gate the sign-in merge flow on backup entitlement, ensure sign-out wipes all local data including collections, and add unit tests for lifecycle callbacks.
- **Implementation Details**:
  - Extracted `AuthLifecycleCoordinator` from `ContentView` for testability.
  - Created `MigrationStoreProtocol` and conformed `LocalDataMigrationStore` for dependency injection.
  - Gate `handleSignedIn` on `authManager.hasBackupEntitlement`: when not entitled, skip the migration prompt and auto-sync; set `.backupUnavailable` status and leave local data untouched.
  - Added collection deletion to `JournalManager.clearAllDataFromRepositories()` so sign-out wipes collections alongside tasks, spreads, events, and notes.
  - Added 9 unit tests for the coordinator covering all sign-in/out lifecycle paths.
- **Acceptance Criteria**:
  - Sign-in with entitlement and local data triggers merge/discard prompt, then syncs.
  - Sign-in with entitlement and no local data syncs immediately.
  - Sign-in without entitlement skips merge prompt, leaves local data untouched, and shows `backupUnavailable` status.
  - Sign-out wipes all local data (including collections) and resets sync state.
  - Device ID is generated once and is available to sync/outbox.
- **Tests**:
  - Unit test: sign-in with entitlement and local data → merge prompt shown.
  - Unit test: sign-in without entitlement → no merge prompt, `backupUnavailable` status.
  - Unit test: sign-out → `clearLocalData` + `resetSyncState` called.
  - Manual: sign in/out flows on dev environment.
- **Dependencies**: SPRD-85, SPRD-95

### [SPRD-84B] Feature: Auth policy isolation + DataEnvironment behavior - [x] Complete
- **Context**: Debug behavior must remain in separate files and avoid `#if DEBUG` in core auth services while DataEnvironment behavior stays consistent across builds. Currently `AuthManager` always creates a `SupabaseClient` even in localhost mode, and there is no mechanism to force auth errors at runtime.
- **Description**: Extend auth architecture to support debug overrides and localhost auth behavior via injected policies.
- **Implementation Details**:
  - Define `AuthPolicy` protocol in non-debug file (`Spread/Services/AuthPolicy.swift`):
    - `func forcedAuthError() -> ForcedAuthError?` — returns an error to throw before hitting Supabase.
    - `var isLocalhost: Bool` — when true, `signIn()` auto-succeeds with a mock user instead of hitting Supabase.
  - Define `DefaultAuthPolicy` in the same file: `forcedAuthError` returns `nil`, `isLocalhost` returns `false`.
  - Define `ForcedAuthError` enum in the same file with cases matching spec line 295: `invalidCredentials`, `emailNotConfirmed`, `userNotFound`, `rateLimited`, `networkTimeout`.
  - Inject `AuthPolicy` into `AuthManager` (default: `DefaultAuthPolicy`).
  - In `signIn()`: check `policy.forcedAuthError()` first; if set, map to user-facing message and throw. Then check `policy.isLocalhost`; if true, create a mock `User` and set state to `.signedIn` with backup entitlement, skipping Supabase entirely.
  - In `checkSession()`: if `policy.isLocalhost`, skip session restore (no Supabase client to query).
  - Implement `DebugAuthPolicy` in `Spread/Debug/DebugAuthPolicy.swift` (`#if DEBUG`):
    - Reads `DebugSyncOverrides.shared.forcedAuthError` (a new `ForcedAuthError?` property, single picker — one error active at a time).
    - `isLocalhost` returns `DataEnvironment.current.isLocalOnly`.
  - Add "Forced Auth Error" picker to the Debug menu's Sync & Network section (picker with None + 5 error cases).
  - Wire `DebugAuthPolicy` in `ContentView` when `BuildInfo.allowsDebugUI` is true; otherwise use `DefaultAuthPolicy`.
  - The `#if DEBUG configureForTesting` helper on AuthManager stays — it's for unit test state setup, not runtime auth logic.
  - Pseudocode:
    ```swift
    enum ForcedAuthError: String, CaseIterable {
      case invalidCredentials, emailNotConfirmed, userNotFound, rateLimited, networkTimeout
    }

    protocol AuthPolicy: Sendable {
      func forcedAuthError() -> ForcedAuthError?
      var isLocalhost: Bool { get }
    }

    struct DefaultAuthPolicy: AuthPolicy {
      func forcedAuthError() -> ForcedAuthError? { nil }
      var isLocalhost: Bool { false }
    }

    final class AuthManager {
      init(policy: AuthPolicy = DefaultAuthPolicy(), ...) { ... }
      func signIn(email: String, password: String) async throws {
        if let forced = policy.forcedAuthError() {
          errorMessage = forced.userMessage
          throw forced
        }
        if policy.isLocalhost {
          state = .signedIn(mockUser)
          hasBackupEntitlement = true
          await onSignIn?(mockUser)
          return
        }
        // ... real Supabase sign-in
      }
    }
    ```
- **Acceptance Criteria**:
  - Debug overrides can force auth errors (single picker: invalid credentials, email not confirmed, user not found, rate limited, network timeout) without network calls.
  - Localhost DataEnvironment auto-succeeds sign-in with a mock user and backup entitlement; login sheet is still shown.
  - Debug auth overrides are available only in Debug/QA builds; Release has no debug-only auth types linked.
  - No `#if DEBUG` is required inside core auth logic (the existing test helper in the test support section is acceptable).
- **Tests**:
  - Unit tests for default policy (no forced errors, not localhost).
  - Unit test: localhost policy auto-succeeds sign-in with mock user.
  - Unit test: forced error policy surfaces correct error message.
  - Manual QA in Debug/QA: force each auth error via Debug menu picker and confirm login sheet displays it.
- **Dependencies**: SPRD-84, SPRD-85A, SPRD-95

### [SPRD-86] Feature: Debug environment switcher - [x] Complete
- **Context**: Debug/QA builds must switch between data environments safely; Release must expose no debug UI.
- **Description**: Add data-environment switcher to Debug destination with guardrails (Debug + QA builds only).
- **Implementation Details**:
  - Environment switcher UI added to DebugMenuView with localhost/dev/prod options.
  - Production requires typed "PRODUCTION" confirmation for safety.
  - Switching flow implemented via EnvironmentSwitchCoordinator (SPRD-96).
  - Debug/TestFlight gating handled by #if DEBUG (Release hides switcher entirely).
  - Shows current environment with checkmark indicator and progress during switch.
- **Acceptance Criteria**:
  - Debug/QA builds can switch environments at runtime.
  - Release builds show no switcher UI.
  - Prod access requires explicit confirmation.
- **Tests**:
  - Manual: switch environments and verify local wipe + re-auth.
- **Dependencies**: SPRD-94, SPRD-95, SPRD-96


### [SPRD-96] Feature: Environment switching flow + store wipe - [x] Complete
- **Context**: Switching data environments must be safe and predictable.
- **Description**: Implement a guarded switch flow with sync attempt, sign out, and local wipe.
- **Implementation Details**:
  - Check outbox for unsynced changes; if non-empty, warn the user and require explicit confirmation.
  - On confirm (or if outbox is empty), sign out and clear auth session.
  - Wipe local SwiftData store and outbox on every switch (including sync cursors).
  - Provide infrastructure for launch-time mismatch detection (`DataEnvironment.lastUsed`, `markAsLastUsed`, `requiresWipeOnLaunch`); wiring into app startup is handled in SPRD-100.
  - Release does not persist selection for reuse; it only tracks last-used for wipe safety.
  - Require restart after switching (no hot reload for now).
  - **Carry-over from feature/SPRD-85 (cherry-pick guidance):**
    - `253fa5f` (`Spread/Debug/DebugMenuView.swift`): environment switcher UI section + `onEnvironmentSwitch` callback wiring.
  - **Architecture note (store wipe boundary)**:
    - Encapsulate wipe logic in a single service so both "switch" and "launch mismatch" paths call the same code.
    - Pseudocode:
      ```swift
      protocol StoreWiper { func wipeAll() throws }
      struct SwiftDataStoreWiper: StoreWiper { ... }
      ```
  - Note: The sync dance (wait for sync, attempt push, final push on confirm) has been simplified to an immediate outbox count check. Full implementation in SPRD-100.
- **Acceptance Criteria**:
  - Switching environments always results in a clean local store (SwiftData + outbox + sync cursors).
  - Non-empty outbox shows a warning and requires explicit confirmation to proceed.
  - Infrastructure for launch-time mismatch detection is provided (wiring deferred to SPRD-100).
- **Tests**:
  - Manual: switch between localhost/dev/prod with and without outbox; verify warning behavior, wipe + sign-out, and restart required.
  - Unit: DataEnvironment.lastUsed, markAsLastUsed, requiresWipeOnLaunch work correctly.
- **Dependencies**: SPRD-85, SPRD-95, SPRD-99

### [SPRD-100] Feature: Apply environment switch (restart required) - [x]
- **Context**: Data environment changes must propagate to newly created services; existing clients should not keep stale configuration. SPRD-96 already handles sign-out + store wipe + sync reset; this task wires the restart flow so the app actually rebuilds its service graph and handles launch-time mismatches.
- **Description**: Simplify the environment switch coordinator to use an outbox count check (no sync dance), implement in-app soft restart via `ContentView`, wire the restart callback through the navigation hierarchy, and handle launch-time mismatch wipes.
- **Implementation Details**:
  - **Coordinator simplification**:
    - Replace the 5-phase sync dance (waiting → syncing → pendingConfirmation → finalPush → restartRequired) with 3 phases: `idle`, `pendingConfirmation` (shown only when outbox is non-empty), `restartRequired`.
    - Check outbox count directly instead of attempting sync. If outbox is empty, skip straight to `restartRequired`.
  - **Soft restart via ContentView**:
    - Make `authManager` optional (`@State private var authManager: AuthManager?`). When nil, ContentView shows the loading state.
    - Add `@State private var appSessionId = UUID()` and use `.task(id: appSessionId)` to trigger `initializeApp()`.
    - Add `restartApp()` method that nils out `journalManager`, `authManager`, `syncEngine`, `coordinator`, and sets a new `appSessionId` to re-trigger `.task(id:)`.
    - `AuthManager` must be recreated (not reused) because it holds an `AuthService` bound to the old environment.
  - **Wire `onRestartRequired`**:
    - Pass `restartApp` callback from `ContentView` → `RootNavigationView` → `SidebarNavigationView`/`TabNavigationView` → `DebugMenuView.onRestartRequired`.
  - **Launch-time mismatch wipe**:
    - In `initializeApp()`, before `DependencyContainer.makeForLive()`, check `DataEnvironment.requiresWipeOnLaunch(current:)`. If true, perform a synchronous wipe (create a temporary container, call `StoreWiper.wipeAll()`, then discard it before creating the real container).
    - After successful container creation, call `DataEnvironment.markAsLastUsed()`.
  - Keep restart logic outside `#if DEBUG` — the soft restart mechanism itself is not debug-only, even though the debug menu is the only trigger today.
- **Acceptance Criteria**:
  - Environment switch coordinator uses at most 3 phases (`idle`, `pendingConfirmation`, `restartRequired`) with no sync attempt — only an outbox count check.
  - After an environment switch, the app rebuilds its service graph and the new Supabase URL/key are used by fresh `SyncEngine` and `AuthService` instances.
  - Debug/QA builds can complete a switch and return to a working app state without manually killing and relaunching the process.
  - `restartApp()` callback is wired from `ContentView` through navigation views to `DebugMenuView`.
  - On app launch, if `DataEnvironment.requiresWipeOnLaunch(current:)` returns true, the local store is wiped before the real container is created.
  - After successful app initialization (both cold launch and soft restart), `DataEnvironment.lastUsed` reflects the current environment.
- **Tests**:
  - Manual: switch environments via debug menu; verify the app returns to loading, re-initializes, and the Supabase host in logs reflects the new environment.
  - Manual: switch environments, force-quit, relaunch; verify wipe occurs before container creation (check logs for wipe + new host).
  - Unit: coordinator transitions — empty outbox skips to `restartRequired`; non-empty outbox goes to `pendingConfirmation`.
  - Unit: verify launch-time wipe logic calls `StoreWiper.wipeAll()` when `requiresWipeOnLaunch` returns true (if extractable into a testable function).
- **Dependencies**: SPRD-96

### [SPRD-119] Infra: Local Supabase sync testing environment - [x] Complete
- **Context**: Pure `localhost` scenarios cannot validate server persistence. The durability bug requires isolated, repeatable, sync-enabled environments, but the chosen direction is to stay on the free tier, keep remote `spread-dev` / `spread-prod`, and add local Supabase for destructive durability testing.
- **Description**: Establish the local-Supabase infrastructure, secrets/config, seed/reset tooling, test-account provisioning, and documentation required to run sync-enabled durability tests locally while preserving remote dev/prod for shared QA and production use.
- **Implementation Details**:
  - Keep `spread-dev` and `spread-prod` as the long-lived remote environments.
  - Add local Supabase as the isolated sync-enabled environment for durability, rebuild, and repair testing.
  - Define how the app and tests point to the local Supabase environment without affecting shared dev/prod credentials.
  - Add automated local reset and seed tooling for deterministic test state.
  - Add deterministic test-account provisioning for the local sync environment.
  - Define secret/config handling for both local developer workflow and CI.
  - Support automated sync-enabled tests against local Supabase, not just manual QA.
  - Update all planning and operational documentation that describes environments, test setup, sync testing, and workflow boundaries between localhost, local Supabase, dev, and prod.
- **Acceptance Criteria**:
  - Engineers can start, reset, seed, and tear down a local Supabase environment for testing. (Spec: Persistence; Testing Strategy)
  - App/test configuration can target local Supabase without changing shared dev/prod credentials. (Spec: Secrets and Configuration)
  - Deterministic test users/accounts are provisioned for local sync testing. (Spec: Persistence)
  - Automated sync-enabled tests can run against local Supabase locally and in CI. (Spec: Testing Strategy)
  - Planning documentation is updated with concrete infrastructure details and workflow instructions. (Spec: Testing Strategy)
- **Tests**:
  - Script/integration verification for local Supabase start/reset/seed flows.
  - Verification that app/test configs resolve the intended local credentials.
  - Smoke validation that local Supabase can be seeded, signed into, and synced against from the app/test harness.
- **Dependencies**: Existing remote `spread-dev` / `spread-prod` retained

### [SPRD-120] Refactor: Durable assignment identity for sync rebuild fidelity - [x] Complete
- **Context**: Assignment history currently exists in local task/note models, but exact server-authoritative rebuilds require stable logical assignment identity across updates, tombstones, devices, and reinstalls.
- **Description**: Introduce durable IDs for `TaskAssignment` and `NoteAssignment` and preserve that identity through local persistence, outbox serialization, pull/apply, and rebuild.
- **Implementation Details**:
  - Extend local assignment models with durable IDs that survive status changes and rebuilds.
  - Ensure assignment status changes for the same `(entry, period, date)` update the same logical assignment record instead of creating duplicates.
  - Update serializers/deserializers so assignment IDs round-trip instead of generating fresh IDs per push.
  - Update spread deletion, migration, reassignment, Inbox resolution, and status-change paths to preserve or create the correct durable assignment IDs.
- **Acceptance Criteria**:
  - Assignment records have durable IDs across devices and reinstalls. (Spec: Persistence)
  - Status changes update the same logical assignment record for the same destination. (Spec: Persistence)
  - Local rebuild from server rows restores assignment IDs and visible history correctly. (Spec: Persistence)
- **Tests**:
  - Unit tests for durable assignment ID creation and preservation through migration/reassignment/status changes.
  - Unit tests for serializer/deserializer round-trips preserving assignment IDs.
  - Unit tests confirming no duplicate logical assignment is created for repeated status updates to the same destination.
- **Dependencies**: SPRD-110, SPRD-111, SPRD-119

### [SPRD-121] Feature: Persist assignment mutations through outbox and sync - [x] Complete
- **Context**: Full placement/history durability requires assignment rows to be pushed and tombstoned explicitly, not merely stored inside local task/note arrays.
- **Description**: Enqueue and sync `task_assignments` and `note_assignments` on every assignment-changing save path, with correct parent-before-child ordering and soft-delete behavior.
- **Implementation Details**:
  - Audit all assignment-changing flows:
    - direct creation onto spreads
    - Inbox fallback creation
    - migration
    - preferred date/period reassignment
    - spread deletion reassignment to parent or Inbox
    - task/note status changes with assignment-history impact
    - entry deletion
  - Ensure each flow emits the required assignment creates, updates, and tombstones in the outbox.
  - Preserve parent-entry-before-child-assignment push ordering.
  - Ensure assignment removals are represented as soft-delete tombstones with revisions, not hard deletes.
  - Verify note assignment sync is corrected symmetrically with task assignment sync.
- **Acceptance Criteria**:
  - Every assignment-changing user action enqueues the corresponding assignment mutations. (Spec: Persistence)
  - `task_assignments` and `note_assignments` are populated server-side after sync for affected entries. (Spec: Persistence)
  - Assignment tombstones propagate correctly and removed assignments do not reappear after rebuild. (Spec: Persistence)
  - Parent entries push before child assignment rows when both are pending. (Spec: Persistence)
- **Tests**:
  - Unit/integration tests for outbox enqueueing on each assignment-changing flow.
  - Sync-engine tests for assignment create/update/delete ordering and acknowledgement behavior.
  - Integration tests confirming server pull/apply reconstructs exact placement and history from synced assignment rows.
- **Dependencies**: SPRD-120, SPRD-85, SPRD-119

### [SPRD-122] Feature: Safe automatic backfill for missing server assignment rows - [x] Complete
- **Context**: Existing signed-in users may already have valid local assignment history with zero corresponding server assignment rows due to the current bug.
- **Description**: Add a once-per-entry, silent repair path that backfills full local assignment history to the server only when the server has zero assignment rows for that entry.
- **Implementation Details**:
  - Run repair only in sync-enabled signed-in environments.
  - Repair applies to both tasks and notes.
  - Safe condition:
    - local entry has assignment history
    - server has zero assignment rows for that entry
  - Upload the full local assignment history for the entry, not just the current open/active assignment.
  - Record that repair has run once for the entry/account to avoid repeated backfills.
  - Keep the repair silent in product UX; log internally for diagnostics.
  - If the server already has any assignment rows for the entry, do not auto-reconcile.
- **Acceptance Criteria**:
  - Previously affected local histories can be backfilled to the server without user-visible repair UI. (Spec: Persistence)
  - Repair runs at most once per entry/account. (Spec: Persistence)
  - Entries with partial or non-empty server assignment state are not auto-overwritten. (Spec: Persistence)
- **Tests**:
  - Integration tests for task and note backfill when server has zero assignment rows.
  - Tests confirming full local history is uploaded during repair.
  - Tests confirming repair does not run when the server already has any assignment row for the entry.
  - Tests confirming repair markers prevent repeated backfill for the same entry/account.
- **Dependencies**: SPRD-120, SPRD-121, SPRD-119

### [SPRD-123] Test/QA: Sync-enabled durability and rebuild coverage - [x] Complete
- **Context**: Pure `localhost` UI scenarios cannot validate server persistence. This bug class needs explicit sync-enabled rebuild coverage from the user’s perspective plus lower-level sync tests.
- **Description**: Add a sync-enabled durability test layer and QA checklist coverage for exact placement/history rebuild after sync, local wipe, reinstall-equivalent rebuild, and cross-client parity.
- **Implementation Details**:
  - Add sync-enabled scenario tests for:
    - direct assignment durability
    - Inbox fallback durability
    - migration durability
    - preferred date/period reassignment durability
    - spread deletion reassignment durability
    - assignment tombstone durability
    - safe backfill recovery
    - note parity for assignment durability
  - Each durability scenario must verify both:
    - current visible placement after rebuild
    - migrated/source-history UI after rebuild where applicable
  - Add at least one cross-client or clean-second-client reconstruction scenario.
  - Keep the existing localhost scenario suite for logic/UI-only behavior; do not replace it.
  - Update QA docs with explicit recovery scenarios: delete app/reinstall, sign-out/sign-in, clean second client, and local-store wipe/rebuild.
- **Acceptance Criteria**:
  - Sync-enabled tests cover exact placement/history rebuild for the defined durability scenarios. (Spec: Persistence; Testing Strategy)
  - Rebuild assertions verify both active destination and source migrated-history visibility where applicable. (Spec: Persistence)
  - QA/docs include explicit recovery verification steps for real-world user scenarios. (Spec: Persistence)
- **Tests**:
  - Sync-enabled integration/UI scenario tests for the durability matrix.
  - Full-suite verification including the new durability coverage.
  - Updated manual QA checklists for rebuild/recovery scenarios.
- **Dependencies**: SPRD-121, SPRD-122, SPRD-119

### [SPRD-124] UI: Spread task-list presentation and multiday layout polish - [x] Completed
- **Context**: Main spread content still uses opaque list-row treatment, task editing depends on swipe affordances, and multiday spreads collapse empty days instead of presenting a deterministic day-by-day structure.
- **Description**: Update the main spread task-list presentation so the spread dot-grid remains visible, add direct tap-to-edit for task rows, and make multiday spreads render all covered days with adaptive layout by size class.
- **Implementation Details**:
  - Update the main spread task-list styling so the list container keeps a solid backing while each task row renders transparently over the spread-content surface.
  - Keep auxiliary review lists such as migration and overdue on their current styling; do not broaden the transparent-row treatment beyond main spread task lists.
  - Make tapping a task row in main spread content open the same full task edit sheet currently reachable through the explicit Edit action.
  - Preserve existing swipe actions on task rows; tap-to-edit is additive.
  - Leave note tap behavior unchanged in this task.
  - For multiday spreads, render a visible section for every covered calendar day regardless of whether that day currently has tasks.
  - Empty multiday day sections must show an explicit empty-state message.
  - Multiday sections show tasks only in v1.
  - Use a single-column layout on compact widths and a two-column reading-order layout on regular widths.
  - Add or update accessibility identifiers needed to verify the new task-row interaction and multiday day-section behavior.
- **Acceptance Criteria**:
  - Main spread task lists visually show the spread dot-grid behind transparent task rows while retaining a readable list container. (Spec: Spread Content Presentation and Interaction)
  - Tapping a task row in main spread content opens the existing full task edit sheet without removing swipe actions. (Spec: Spread Content Presentation and Interaction)
  - Multiday spreads always render every day in range, including explicit empty-day sections, with one-column/two-column adaptation by size class. (Spec: Spread Content Presentation and Interaction)
- **Tests**:
  - UI or snapshot-style verification for transparent task-row treatment on main spread content.
  - UI tests confirming task-row tap opens the existing task edit sheet from spread content.
  - UI tests covering multiday empty-day visibility and compact-vs-regular layout behavior.
  - Manual QA confirming auxiliary review sheets keep their existing styling and note tap behavior remains unchanged.
- **Dependencies**: None

### [SPRD-125] UI: header spread navigator surfaces - [x] Completed
- **Context**: Header-based spread navigation currently has in-progress iPad popover work and no matching iPhone surface. The spec now requires one rooted navigator content model presented as a popover on iPad and as a large sheet on iPhone.
- **Description**: Turn the spread title in the header into a tappable navigator trigger on both platforms. The presented surface must open as a popover on iPad and as a large sheet on iPhone, while sharing the same rooted spread navigator content. The navigator must reveal the current spread's hierarchy context by expanding the relevant sections, use collapsible year/month rows, use a mixed day/multiday grid for conventional month detail, and navigate the main app immediately on selection.
- **Implementation Details**:
  - Make the current spread title in `SpreadHeaderView` tappable on both platforms and add a subtle chevron indicator.
  - Present a bounded-size popover rooted on the header title button on iPad.
  - Present the same rooted navigator content in a large sheet on iPhone.
  - Require a separable navigator support/model layer for:
    - deriving available years/months/day-grid items by mode
    - determining the correct initial expanded year/month state from the current spread
    - representing derived conventional years/months versus explicit created spreads
    - representing traditional-mode root-year bounds from earliest data/created-spread year through current year plus ten
    - enforcing accordion expansion behavior for years and months
  - Root content is always the same full hierarchy view.
  - Root years are ordered newest first.
  - Months appear only inside the expanded year and are ordered January through December using available rows only.
  - Month detail is a single chronological grid.
  - Conventional month grids mix explicit day spreads and explicit multiday spreads.
  - Traditional month grids show every calendar day in the month and no multiday tiles.
  - Multiday tiles are labeled by date range and use a subtle alternate tint or border from day tiles.
  - Current selection uses a light shape background, not a checkmark.
  - Conventional mode:
    - include derived years and months when child spreads make them navigable
    - use subtle styling for derived uncreated year/month rows
    - do not derive day or multiday tiles beyond explicit created spreads
  - Traditional mode:
    - show the full calendar structure
    - root year list spans from earliest year with entry data or created conventional spread through current year plus ten
  - Use split interaction on year/month rows:
    - row-body tap navigates immediately and dismisses when the row is an explicit spread destination
    - trailing disclosure expands or collapses that section
    - derived conventional year/month rows are disclosure-only
  - Accordion behavior applies:
    - only one year expanded at a time
    - only one month expanded within the expanded year
  - Selecting any destination row/tile updates the main app spread selection immediately and dismisses the active popover or sheet.
- **Acceptance Criteria**:
  - On iPad, tapping the current spread title opens a popover rooted on that header button and reveals the active spread inside the single rooted hierarchy view. (Spec: Navigation and UI; Header Spread Navigator)
  - On iPhone, tapping the current spread title opens a large sheet showing the same rooted hierarchy and the same active spread context. (Spec: Navigation and UI; Header Spread Navigator)
  - The navigator uses collapsible year/month rows and month grids, with split row-body/disclosure behavior and immediate navigation plus dismissal on destination selection. (Spec: Navigation and UI; Header Spread Navigator)
  - Conventional and traditional modes derive navigator contents according to their respective availability rules, and the current spread is visibly highlighted without a checkmark. (Spec: Navigation and UI; Header Spread Navigator)
- **Tests**:
  - Unit tests for navigator model/support logic covering:
    - initial expansion state for year/month/day/multiday current spreads
    - conventional derived year/month rules
    - traditional root-year range derivation
    - chronological ordering for year/month/day-grid content
    - accordion expansion behavior
  - UI tests covering:
    - tapping the header title opens the correct presentation surface for the current device class
    - the presented navigator reveals the current spread context with the correct expanded sections
    - disclosure controls expand and collapse years/months without navigating
    - selecting a year/month/day/multiday destination navigates and dismisses
    - current selection highlighting is visible
  - Manual QA for visual polish, bounded iPad popover sizing, iPhone sheet presentation, and mode-specific content differences.
- **Dependencies**: None

### [SPRD-126] UI: horizontal spread-title navigator - [x] Complete
- **Context**: `SPRD-125` established the rooted spread navigator surface, but spread selection is still split between older top-bar controls and per-spread header title ownership. The next step is to make spread selection itself live in a centered horizontal title navigator that will also serve as the foundation for future horizontally scrollable spread presentation.
- **Description**: Replace the current top spread selection bar with a centered horizontal spread-title navigator on both iPhone and iPad. The navigator must display spread titles in the app's actual navigable sequence, keep the current spread centered after scroll settle, allow direct tap selection of visible neighbors, and open the existing rooted spread navigator surface when the selected capsule is tapped.
- **Implementation Details**:
  - Remove the old top spread selection bar and replace it with a horizontal scroll view of spread titles in the top spread-navigation area.
  - Use a separable support/model layer for:
    - deriving the ordered navigable spread sequence for conventional and traditional modes
    - mapping current spread selection into centered-strip state
    - preserving a stable centered selected slot with invisible spacer slots near edges and in sparse datasets
    - determining adaptive visible-neighbor behavior from available width instead of hardcoded counts
    - reconciling drag, tap-selection, and external selection changes into one source of truth
  - Render the selected spread as a prominent rounded capsule with a subtle chevron that is not a separate tap target.
  - Render non-selected visible spreads as plain text titles with hierarchy-aware styling.
  - Allow partially visible edge titles when width does not fit only full titles cleanly.
  - Make the strip fully user-scrollable and snap so one spread title is centered at rest.
  - Update current selection only after snap/settle.
  - Tapping a visible non-selected spread selects it and animates it into the centered selected position.
  - Tapping the selected capsule opens the rooted spread navigator surface from `SPRD-125`:
    - popover on iPad
    - large sheet on iPhone
  - When spread selection changes from any source, including rooted navigator selection or other programmatic navigation, automatically recenter the horizontal strip.
  - Remove the duplicate spread title from the per-spread header once the navigator owns current-spread display.
- **Acceptance Criteria**:
  - The old top spread selection bar is replaced by a horizontal spread-title navigator on both iPhone and iPad. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - The selected spread remains centered after scroll settle, including sparse and edge cases, using invisible spacer behavior rather than collapsing the layout around the selected item. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Dragging the navigator snaps a single spread title into the centered selected position, and selection updates only after settling. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Tapping a visible non-selected spread selects it, animates it into the centered position, and updates the main app spread content. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Tapping the selected capsule opens the existing rooted spread navigator surface on the appropriate platform, and selections made there recenter the strip afterward. (Spec: Navigation and UI; Spread Navigator Surface)
  - The per-spread header no longer renders a duplicate spread title once the horizontal navigator is active. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
- **Tests**:
  - Unit tests for the horizontal navigator support/model layer covering:
    - conventional and traditional ordered spread sequencing
    - centered selected-slot behavior with sparse data and edge selections
    - adaptive visible-neighbor window derivation without hardcoded per-device counts
    - snap target resolution and selection-after-settle behavior
    - recentering after external selection changes
  - UI tests on iPhone and iPad covering:
    - selected spread starts centered on launch
    - dragging snaps to a new centered selection and updates spread content only after settle
    - tapping a visible neighbor selects and recenters it
    - tapping the selected capsule opens the existing navigator surface
    - selecting from the sheet/popover recenters the strip on the new current spread
    - the per-spread header no longer shows a duplicate spread title
  - Manual QA for:
    - partial edge visibility polish
    - capsule/plain-text hierarchy styling
    - animation smoothness and non-jittery content updates during drag
    - behavior across compact and regular widths without hardcoded visible-count assumptions
- **Dependencies**: SPRD-125

### [SPRD-127] UI: browse-only horizontal spread-title navigator refinement
- **Context**: `SPRD-126` established the horizontal spread-title navigator and integrated it with the rooted spread navigator surface, but real-world validation showed that strip scrolling should support browsing without mutating the current spread. The selected state, centered capsule, and eventual horizontally scrollable spread surfaces need a clearer separation between browse position and committed selection.
- **Description**: Refine the horizontal spread-title navigator so horizontal dragging browses titles without changing the selected spread or main spread content. Selection should happen only on direct tap of a visible non-selected spread or from other non-strip navigation actions. The strip should be scoped to the selected year rather than the selected period, showing all spreads available in that year for the current mode. The selected spread should always retain its capsule styling while browsing, and when the selected spread is fully offscreen a directional liquid-glass overlay button should appear to return the strip to the selected spread.
- **Implementation Details**:
  - Keep the existing horizontal spread-title navigator as the primary in-view spread-selection control on both iPhone and iPad.
  - Separate strip browse position from committed spread selection in the navigator model/view state.
  - Preserve native horizontal scrolling and snap/settle behavior for the strip, but do not change selection or main spread content from scrolling alone.
  - Scope the strip to the selected spread's year:
    - within a year, changing between year/month/day/multiday selections does not change which strip items are shown
    - when selection changes to a different year, rebuild the strip to that year's sequence
  - In conventional mode, show all explicit spreads that exist in the selected year, ordered chronologically, including explicit year, month, day, and multiday spreads.
  - In traditional mode, show the full calendar year inline as a single chronological sequence of the year item, months, and all day destinations for that year; do not include multiday items.
  - Keep inline month boundaries readable with subtle spacing/separator treatment in the strip.
  - Keep visible non-selected spreads tappable; tapping one must:
    - commit that spread as the new selection
    - update the main app spread content
    - animate the newly selected spread into the centered selected position
  - Keep the selected spread centered on launch and whenever selection changes from a non-strip source.
  - Keep the selected spread visibly styled with its capsule while browsing away from center; selected styling follows the selected spread rather than a fixed centered overlay.
  - Detect when the selected spread has been browsed fully out of the visible strip.
  - Show a liquid-glass overlay button on the nearer edge when the selected spread is fully offscreen:
    - selected spread off to the left: button appears on the left edge
    - selected spread off to the right: button appears on the right edge
  - Tapping the overlay button must animate the strip back so the selected spread is centered again.
  - Keep the selected centered capsule as the trigger for the rooted navigator surface from `SPRD-125` when the selected spread is actually centered/present.
  - Preserve adaptive visible-neighbor behavior and invisible spacer behavior near edges and in sparse datasets.
- **Acceptance Criteria**:
  - Scrolling the horizontal strip browses titles but does not change the selected spread or main spread content. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Tapping a visible non-selected spread selects it, updates content, and recenters it. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - The selected spread starts centered on launch and recenters after non-strip selection changes. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - The strip contents remain stable for all selections within the same year and rebuild only when selection moves to a different year. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Conventional mode includes all explicit spreads in the selected year; traditional mode includes the full selected calendar year sequence. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - The selected spread retains its capsule styling while browsing, regardless of whether it is currently centered. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - When the selected spread is fully offscreen, a directional liquid-glass return button appears on the nearer edge and recenters the strip when tapped. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - The selected centered capsule still opens the rooted navigator surface on iPad and iPhone. (Spec: Navigation and UI; Spread Navigator Surface)
- **Tests**:
  - Unit tests for navigator support/model behavior covering:
    - year-wide strip sequencing for conventional mode using explicit spreads only
    - year-wide strip sequencing for traditional mode across all months/days in the selected year
    - stable strip contents when selection changes within the same year
    - strip rebuild when selection changes to a different year
    - browse-state separate from committed selection
    - adaptive offscreen-selected detection
    - nearer-edge return-button placement
    - recenter-to-selected behavior from the overlay button
  - UI tests on iPhone and iPad covering:
    - strip scroll browsing does not change main spread content
    - tapping a visible non-selected spread commits selection and recenters it
    - selected spread retains its capsule styling while browsing away
    - return-to-selected button appears only when the selected spread is fully offscreen
    - return-to-selected button recenters the strip on the selected spread
  - Manual QA for:
    - browse-vs-select clarity
    - overlay button visual polish and edge placement
    - snap behavior while browsing without accidental selection changes
- **Dependencies**: SPRD-125, SPRD-126

### [SPRD-128] UI: horizontal spread-content paging - [x] Complete
- **Context**: `SPRD-127` established the selected-year horizontal spread-title navigator and clarified the distinction between browsing the strip and committing a spread selection. The next step is to make the spread content itself horizontally pageable and keep it synchronized with the title strip without eagerly loading an entire year's worth of spread views.
- **Description**: Add a horizontal spread-content pager beneath the title strip on both iPhone and iPad. The pager must use the same selected-year sequence as the title strip, update selection only after page-settle, animate for same-year selection changes, jump for cross-year dataset rebuilds, and lazily keep only a small live window of spread content views in memory at once.
- **Implementation Details**:
  - Add a separate horizontal pager surface for spread content beneath `SpreadTitleNavigatorView`; the title strip remains the primary spread-navigation chrome.
  - Use the same ordered selected-year sequence as `SpreadTitleNavigatorModel` for both conventional and traditional modes:
    - conventional mode includes explicit year, month, day, and multiday spreads for the selected year
    - traditional mode includes the full year sequence of the year item, months, and all day destinations for that year
  - The pager uses full-width pages with paging settle; adjacent pages do not remain peeked into view at rest.
  - Update the selected spread only after the pager settles on a new page.
  - When a visible strip item is tapped, or when rooted navigator selection changes within the same selected-year sequence, animate the pager to that page and keep the title strip synchronized.
  - When selection changes to a spread in a different year, rebuild the pager dataset for the new year and jump directly to the selected page rather than animating across datasets.
  - Keep a small live page window around the selected spread instead of instantiating the full selected-year content set:
    - prefer native lazy containers such as `LazyHStack` where feasible
    - keep the current page plus two neighboring pages on each side live
    - pages outside the live window may be torn down and rebuilt, losing transient local view state
  - Preserve the full existing spread views for each page rather than introducing preview-only page variants.
  - Keep swipe navigation and external programmatic selection as the only page navigation mechanisms in this task; do not add previous/next arrow controls.
- **Acceptance Criteria**:
  - Both conventional and traditional spread content can be navigated horizontally by swiping full-width pages. (Spec: Navigation and UI; Horizontal Spread-Content Paging)
  - Swiping the content pager changes the selected spread only after paging settles on a new page. (Spec: Navigation and UI; Horizontal Spread-Content Paging)
  - The title strip and content pager remain synchronized: pager settle updates the strip selection, and same-year strip/rooted-navigator selection animates the pager to the chosen page. (Spec: Navigation and UI; Horizontal Spread-Content Paging)
  - Selecting a spread in a different year rebuilds the pager dataset and jumps to the new year's selected page rather than animating across year datasets. (Spec: Navigation and UI; Horizontal Spread-Content Paging)
  - The pager does not eagerly instantiate the full selected-year content set; it uses a small live lazy window around the selected page. (Spec: Navigation and UI; Horizontal Spread-Content Paging)
  - The pager renders the existing full spread view for each selected page type rather than preview-only stand-ins. (Spec: Navigation and UI; Horizontal Spread-Content Paging)
- **Tests**:
  - Unit tests for pager support/model behavior covering:
    - selected-year sequence alignment with the title strip in conventional and traditional modes
    - live-window derivation for current page plus two neighbors on each side
    - same-year animated navigation targets versus cross-year dataset rebuild targets
    - selection-after-settle semantics for pager-driven updates
  - UI tests on iPhone and iPad covering:
    - swiping content settles on a new page and then updates the selected strip item
    - tapping a visible strip item animates the pager to the matching page
    - rooted navigator selection within the same year animates to the chosen page
    - rooted navigator selection in a different year jumps to the new year dataset/page
    - full-width pages show no resting neighbor peek
  - Manual QA for:
    - paging smoothness across year/month/day/multiday transitions
    - strip and pager staying visually synchronized
    - memory/performance sanity while traversing a dense year sequence
- **Dependencies**: SPRD-127

### [SPRD-129] UI: spread navigator label refinements - [x] Complete
- **Context**: `SPRD-126` through `SPRD-128` established the horizontal title navigator and synchronized content paging. The next refinement is to improve title-strip readability and hierarchy with richer label treatments while removing redundant spread titling from the spread content surface itself.
- **Description**: Refine the visual treatment of horizontal spread navigator labels by removing the duplicate `Spreads` title from the spread content surface, giving year/month/day/multiday items more expressive hierarchy-aware labels, and keeping accessibility/simple spoken labels stable.
- **Implementation Details**:
  - Remove the duplicate `Spreads` title from the spread content surface while preserving higher-level container navigation titles where they are still needed for broader app navigation context.
  - Update year items to use a stacked typographic treatment:
    - small leading century digits above
    - larger trailing two digits below
    - keep the underlying accessibility/spoken label as the plain year value such as `2026`
  - Keep month items as single-line labels, but give them a more expressive typographic treatment than the current plain text styling.
  - Update day items to a three-line label:
    - smallcaps month abbreviation on the top line
    - day number on the middle line
    - short weekday label on the bottom line
  - Update multiday items to a three-line label:
    - same-month ranges use a smallcaps month abbreviation on the top line, a compact day range on the middle line, and a short weekday span on the bottom line
    - cross-month ranges use a smallcaps month span on the top line, a compact endpoint day range on the middle line, and a short weekday span on the bottom line
  - Ensure the selected capsule sizes to the full rendered label block for all item types, including the richer multi-line day and multiday labels.
  - Preserve current accessibility identifiers and plain spoken values for UI testing and accessibility, rather than exposing the visual fragments of the label styling.
- **Acceptance Criteria**:
  - The spread content surface no longer shows the duplicate `Spreads` title, while necessary higher-level container titles remain intact. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Year items render with the new stacked year treatment and still expose plain year accessibility labels. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Month items remain single-line but are visually distinguished from day and multiday items. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Day items render with the agreed three-line month/day/weekday treatment. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - Multiday items render with the agreed three-line month/day-range/weekday-span treatment for both same-month and cross-month spans. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
  - The selected capsule sizes correctly to the full label block for all item types. (Spec: Navigation and UI; Horizontal Spread-Title Navigator)
- **Tests**:
  - Unit tests for navigator label formatting behavior covering:
    - year label model output
    - month label model output
    - day label model output
    - multiday label model output for same-month and cross-month ranges
  - UI tests on iPhone and iPad covering:
    - selected item capsule sizing with multi-line labels
    - title-strip content still remaining tappable and centered after label refinements
    - navigator surface still opening from the selected spread item after the visual update
  - Manual QA for:
    - readability and hierarchy clarity across mixed year/month/day/multiday sequences
    - visual balance of the selected capsule with the new multi-line label blocks
    - correct removal of the duplicate `Spreads` title from the spread content surface
- **Dependencies**: SPRD-128

### [SPRD-131] Infra: adopt Supabase `emitLocalSessionAsInitialSession` auth behavior - [x] Complete
- **Context**: The Supabase Swift SDK (v2.40.0) emits a deprecation warning at launch: the current default behavior only emits the initial session after attempting a server refresh. The SDK plans to change this in the next major release. The recommended migration is to set `emitLocalSessionAsInitialSession: true` so the locally stored session is emitted immediately, and then check `session.isExpired` on the consuming side. See [supabase-swift#822](https://github.com/supabase/supabase-swift/pull/822).
- **Description**: Configure `SupabaseClientOptions.auth` with `emitLocalSessionAsInitialSession: true` in both production `SupabaseClient` creation sites (`SupabaseAuthService.init` and `AppRuntimeFactory.makeRuntime`). Update `SupabaseAuthService.checkSession()` to handle the immediately-emitted session by checking `session.isExpired` and treating expired sessions as signed-out. Verify the deprecation warning no longer appears at launch.
- **Implementation Details**:
  - In `SupabaseAuthService.init`, pass `SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))` to the `SupabaseClient` initializer.
  - In `AppRuntimeFactory.makeRuntime`, pass the same options to the sync `SupabaseClient`.
  - In `SupabaseAuthService.checkSession()`, after retrieving the session, check `session.isExpired`. If expired, return `nil` (treat as signed-out) instead of returning the stale session.
  - Verify `AuthManager` and `AuthLifecycleCoordinator` downstream behavior is unaffected since they already treat a `nil` check-session result as signed-out.
- **Acceptance Criteria**:
  - Both production `SupabaseClient` instances are configured with `emitLocalSessionAsInitialSession: true`.
  - `SupabaseAuthService.checkSession()` returns `nil` for expired sessions.
  - The Supabase deprecation warning no longer appears in the console at launch.
  - Existing sign-in, sign-out, and session-restore flows continue to work correctly.
- **Tests**:
  - Unit test verifying `checkSession()` returns `nil` when the session is expired (requires mock or protocol-based auth service testing).
  - Manual verification that the deprecation warning is suppressed.
- **Dependencies**: None

### [SPRD-130] UI: spread navigation bar Today button
- **Context**: The horizontal spread-title navigator and content pager now keep spread selection synchronized, but there is still no direct "jump to today" control in the navigation bar. Users need a fast way to navigate back to the spread that best represents the current date without manually browsing the strip or rooted navigator.
- **Description**: Add a standalone plain-text `Today` button to the spread-view navigation bar on both iPhone and iPad. The button should appear on the top trailing side ahead of the overdue and inbox buttons and navigate to the smallest-granularity spread that contains today, then synchronize the selected spread, title strip, and content pager.
- **Implementation Details**:
  - Add a plain text `Today` toolbar button to the spread-view navigation bar on both iPhone and iPad.
  - Place `Today` before the overdue and inbox toolbar items in the trailing toolbar group.
  - Conventional mode target resolution:
    - prefer an explicit day spread for today
    - otherwise prefer the narrowest explicit multiday spread containing today
    - otherwise fall back to an explicit month spread for today's month
    - otherwise fall back to an explicit year spread for today's year
    - if multiple multiday spreads contain today, choose the narrowest containing range and break ties by the existing chronological spread ordering
    - if no explicit conventional spread contains today, do nothing for now
  - Traditional mode target resolution:
    - always navigate to the traditional day destination for today
  - If today is already the current spread, still recenter the title strip and content pager on today.
  - Use the same spread-selection pipeline as other navigation actions so the selected spread, title strip, and content pager stay synchronized.
- **Acceptance Criteria**:
  - A plain text `Today` button appears in the spread-view navigation bar on both iPhone and iPad, before the overdue and inbox controls. (Spec: Inbox; Navigation and UI)
  - In conventional mode, `Today` chooses the smallest explicit spread containing today using day, then multiday, then month, then year fallback. (Spec: Inbox)
  - In traditional mode, `Today` always selects the day destination for today. (Spec: Inbox)
  - Pressing `Today` updates the selected spread and recenters the title strip and content pager. (Spec: Inbox; Horizontal Spread-Title Navigator; Horizontal Spread-Content Paging)
  - If no explicit conventional spread contains today, pressing `Today` currently has no visible effect. (Spec: Inbox)
- **Tests**:
  - Unit tests for conventional target-resolution priority, including multiday tie-breaking.
  - Unit tests for traditional mode target resolution.
  - UI tests on iPhone verifying toolbar placement, today navigation, and synchronized strip/pager recentering.
  - iPad UI tests deferred: no iPad-specific UI test infrastructure exists yet. The toolbar code is size-class-independent, so iPad behavior is covered by the shared code path. Add iPad Today button tests when the project establishes an iPad test plan configuration.
- **Dependencies**: SPRD-128

### [SPRD-132] UI: inline task title editing on spread page - [x] Complete
- **Context**: Currently tapping a task row on the spread page opens the full task edit sheet. For the common case of renaming a task, this is heavier than necessary. This task replaces row tap-to-open-sheet with tap-on-title inline editing, keeping the full sheet accessible via the existing Edit swipe action.
- **Spec**: Spread Content Presentation and Interaction
- **Acceptance Criteria**:
  - Tapping the title text of a task row in the main spread entry list activates an inline `TextField` in place of the title label. The keyboard appears immediately.
  - While the inline editor is active, a "×" button is visible in the row. Tapping "×" discards the edit and restores the original title without saving.
  - Tapping outside the active row (losing focus), pressing Return, or the field otherwise resigning first responder commits the edited title to the task.
  - If the committed title is empty, the change is silently discarded and the original title is restored; no error state is shown.
  - Swipe actions (Complete, Migrate, Edit, Delete) are suppressed on a row while its inline editor is active.
  - Tapping anywhere on the task row that is not the title text does not open the full edit sheet. The full edit sheet is only reachable via the swipe-action Edit button.
  - Inline title editing applies identically in both the standard entry list (day/month/year spreads) and the multiday grid view.
  - Note rows are unaffected; their tap behavior remains unchanged.
  - Inline edits are persisted via the existing `JournalManager` task update path (same as the full edit sheet).
- **Tests**:
  - Unit tests for inline edit commit: verifies title is updated when focus is lost with non-empty text.
  - Unit tests for inline edit discard: verifies original title is restored when "×" is tapped or empty text is committed.
  - UI tests verifying the inline editor activates on title tap, commits on Return, and discards on "×".
- **Dependencies**: SPRD-124

### [SPRD-133] UI: inline task creation on spread page
- **Context**: Adding a task currently requires opening a full creation sheet from the toolbar. This task introduces an inline "+ Add Task" button at the bottom of each spread's task list so users can create tasks without leaving the spread surface. Multiday spreads get a per-day button so tasks land on the correct day. The feature uses a glass-effect keyboard toolbar for Save/Cancel and supports rapid multi-task entry via Return.
- **Spec**: Spread Content Presentation and Interaction
- **Acceptance Criteria**:
  - An "+ Add Task" button is always visible at the bottom of the task list on every spread (day, month, year, multiday). It replaces the "No Entries" empty state — the spread never shows the empty state content view.
  - On multiday spreads, each day section has its own "+ Add Task" button at the bottom of that day's task list.
  - Tapping the button appends an inline text field row with immediate keyboard focus.
  - While the input row is active, a glass-effect toolbar (`.glassEffect`) appears above the keyboard containing Save and Cancel buttons.
  - Tapping Save commits the title (if non-empty) and dismisses the input row.
  - Tapping Cancel discards the input and dismisses the row.
  - Pressing Return on the keyboard commits the title (if non-empty) and immediately opens a new blank input row for the next task.
  - When the input row loses focus (e.g., user taps elsewhere), non-empty input is saved; an empty field is silently discarded and the row dismissed.
  - Tasks created via inline creation are assigned to the spread's own period and date (same defaults as `TaskCreationSheet` when that spread is pre-selected). For multiday day sections, tasks are assigned to that specific day with `.day` period.
  - Inline task creation applies to tasks only; no equivalent for notes in v1.
  - Created tasks are persisted via the existing `JournalManager.addTask` path and trigger a sync.
- **Tests**:
  - Unit tests verifying task assignment uses the spread's period and date for day/month/year spreads.
  - Unit tests verifying multiday day-section tasks are assigned to the day's date with `.day` period.
  - UI tests verifying the button appears, tapping it opens the input row, Return creates a task and opens a new row, Save closes the row, Cancel discards.
- **Dependencies**: SPRD-124, SPRD-132

### [SPRD-134] UI: toolbar and spread view button layout changes
- **Context**: Several button/indicator changes are grouped here: remove the sync status toolbar icon and content-area banner entirely (sync feedback deferred to pull-to-refresh in SPRD-135); move the `Today` button from the navigation bar to a `.glassEffect` overlay in the bottom-leading corner of the spread content view; and split the trailing toolbar buttons into two distinct groups — overdue + inbox in one group, auth (profile) button in a separate group with a gap between them.
- **Spec**: Inbox (Today button), Auth UI (toolbar grouping), Sync & Data (sync status)
- **Acceptance Criteria**:
  - The `Today` button is removed from the navigation bar toolbar.
  - The `Today` button is rendered as a `.glassEffect` button overlaid at the bottom-leading corner of the spread content view, always visible.
  - The `Today` button behavior (navigation, recentering) is unchanged from SPRD-130.
  - The overdue toolbar button and inbox toolbar button are in one `ToolbarItemGroup` in the trailing position.
  - The auth (profile) button is in a separate `ToolbarItemGroup` in the trailing position, appearing after the overdue/inbox group with a natural gap between them.
  - `SyncStatusBanner` is removed from `ConventionalSpreadsView` and `TraditionalSpreadsView`.
  - The `SyncStatusBanner` view file is deleted.
  - The sync status toolbar icon (`SyncStatusView`) is removed from all toolbar placements.
  - `SyncStatusView` is deleted.
- **Tests**:
  - UI tests verifying the `Today` button accessibility identifier is present in the spread overlay and absent from the navigation bar.
  - UI tests verifying `SyncStatusBanner` accessibility identifier is absent from the view hierarchy.
  - UI tests verifying `SyncStatusView` (sync icon) accessibility identifier is absent from the toolbar.
- **Dependencies**: SPRD-85, SPRD-130

### [SPRD-135] UI: pull-to-refresh sync on spread entry list
- **Context**: The sync status toolbar icon has been removed (SPRD-134). This task replaces it with pull-to-refresh as the manual sync trigger on the entry list, adds last-sync-time display in the pull indicator, and introduces a persistent non-tappable error banner below the navigator strip for failed sync states.
- **Spec**: Sync & Data (Pull-to-refresh sync behavior, Sync error banner)
- **Acceptance Criteria**:
  - `.refreshable` is applied to the entry list `List`/`ScrollView` in both conventional and traditional modes.
  - Releasing past the system pull threshold triggers `syncEngine.syncNow()`.
  - The pull indicator header displays the current sync status while pulling:
    - `.idle` → "Not yet synced"
    - `.synced(Date)` → "Last synced [relative time]"
    - `.syncing` → standard system spinner; no additional sync triggered on release
    - `.offline` → "Offline"
    - `.localOnly` → "Local only"
    - `.error` → "Last sync failed"
  - Releasing before the threshold dismisses the indicator without triggering sync.
  - Pulling in `.offline` or `.localOnly` state shows the indicator status but does not call `syncNow()`.
  - When `SyncStatus` is `.error`, a non-tappable single-line banner appears below the spread title navigator strip with the text "Last sync failed · Pull down to retry".
  - The error banner is dismissed automatically when `SyncStatus` transitions out of `.error`.
  - The error banner does not appear for `.offline` or `.localOnly` states.
- **Tests**:
  - Unit tests verifying pull indicator text per `SyncStatus` case.
  - Unit tests verifying `syncNow()` is called (or not) on release per state.
  - UI tests verifying the error banner appears and disappears with `.error` state transitions.
  - UI tests verifying the error banner is absent for `.offline` and `.localOnly` states.
- **Dependencies**: SPRD-134

### [SPRD-136] Bug: SpreadTitleNavigatorView strip height and scroll isolation
- **Context**: `SpreadTitleNavigatorView` accumulated multiple layers of selection, centering, and overlay behavior over time. Two concrete bugs remain: (1) the strip height is hardcoded and can clip multi-line day/multiday capsules against the divider and content below, and (2) strip-driven programmatic scrolling can leak into the content pager because the two surfaces share scroll-target mechanics too closely. The task should fix those bugs and refactor the strip to a simpler model while preserving the current visual system.
- **Spec**: Strip height is content-driven with a minimum floor. Strip and pager scrolling are isolated. Strip browsing is preserved independently from pager browsing, except for intentional strip-originated and non-pager jump actions.
- **Acceptance Criteria**:
  - [x] The strip `frame(height: 68)` is removed. The strip sizes to fit its tallest item plus vertical padding and a minimum visual floor so the capsule has breathing room above the divider.
  - [x] The selected capsule is fully visible and not clipped or overlapped by sibling views in both conventional and traditional modes, on iPhone and iPad.
  - [x] Tapping a visible non-selected strip item still changes the selected spread and navigates the pager.
  - [x] Tapping the selected strip item never opens the navigator surface; it only recenters the strip when needed and is otherwise a no-op.
  - [x] A leading `.glassEffect` `Select Spread` overlay button with a down chevron is always visible and opens the rooted spread navigator surface.
  - [x] A trailing `.glassEffect` `Recenter` overlay button appears whenever the selected spread is not centered, and tapping it re-centers the strip without changing the selected spread or moving the content pager.
  - [x] Scrolling the strip programmatically (`Recenter`, strip-originated selection, `Today`, rooted spread selection) does not trigger `onSettledSelect` or any pager navigation.
  - [x] Swiping the content pager still updates the selected spread, but does not automatically recenter the strip; the strip preserves its current browse offset while updating selected-state styling.
  - [x] Width/layout changes preserve the current browse offset when the strip is browsed away from selection, and keep the strip centered only when it was already centered on selection before the change.
- **Tests**:
  - Support tests covering navigator label/content derivation.
  - Focused iPhone UI tests covering strip tap selection, pager swipe selection, rooted navigator opening, and `Today` synchronization in both conventional and traditional modes.
- **Dependencies**: SPRD-134

### [SPRD-137] UI: Recommended spread creation inset
- **Context**: The horizontal spread title navigator should help users discover missing explicit spreads for the current day context without forcing them into the create-spread flow manually. Recommendations should be testable independently of the view and visually distinct from existing spreads.
- **Acceptance Criteria**:
  - [x] Add a recommendation-provider protocol that derives recommended spreads for the navigator and can be unit tested independently of SwiftUI rendering.
  - [x] Inject a conforming recommendation provider into `SpreadTitleNavigatorView`.
  - [x] In conventional mode only, show recommended spreads in a fixed trailing inset area separate from the scrollable strip content.
  - [x] Base recommendations on `today`, not on the currently selected spread.
  - [x] Recommend each missing explicit `year`, `month`, and `day` spread for today's current period context.
  - [x] Do not let containing multiday spreads satisfy the missing day recommendation.
  - [x] Show recommendations in `year`, `month`, `day` order.
  - [x] Reuse the existing navigator label presentation for recommended items.
  - [x] Render recommendations with the implemented shimmering visual treatment so they remain visually distinct from existing spreads.
  - [x] Hide the trailing recommendation inset entirely when there are no recommendations.
  - [x] Tapping a recommendation opens the existing create-spread flow prefilled for that recommendation.
  - [x] Recommendations remain visible while the create-spread flow is open and disappear only after successful creation.
  - [ ] Remove the inner horizontal padding from recommendation cards.
  - [ ] Constrain recommendation cards to a shared fixed `3:5` aspect ratio and ensure all visible recommendation cards are the same size.
  - [ ] Keep iPad behavior showing all recommendations directly in the trailing inset.
  - [ ] On iPhone, keep a single recommendation as a direct tappable card.
  - [ ] On iPhone, when multiple recommendations exist, replace the direct cards with one shimmering down-chevron card that opens a `Menu`.
  - [ ] Use the same shared card size for the iPhone chevron card and the direct recommendation cards.
  - [ ] Use full spread date/title labels for recommendation menu items on iPhone.
- **Tests**:
  - Support tests for recommendation derivation across missing and existing year/month/day spread combinations.
  - Focused UI tests covering recommendation visibility, ordering, and opening prefilled creation flow from the trailing inset.
  - Focused iPhone UI tests covering the multi-recommendation chevron card, menu contents, and shared recommendation sizing.
- **Dependencies**: SPRD-136

### [SPRD-138] Bug: Year/month task sectioning should reflect the current spread - [x] Complete
- **Context**: Conventional spread task grouping is currently too generic. Year and month spreads should present tasks relative to the current spread rather than sectioning everything by source spread. Tasks assigned directly to the current year or month belong to that spread and should not be shown under a redundant titled section, while more granular tasks should remain visible with enough date context to scan them.
- **Spec**: Spread Content Presentation and Interaction
- **Acceptance Criteria**:
  - On a year spread, tasks assigned directly to that year appear in an untitled top section.
  - On a year spread, tasks assigned to months appear under month-titled sections ordered chronologically.
  - On a year spread, tasks assigned to days also appear within their containing month sections and display the day number next to the task title.
  - On a month spread, tasks assigned directly to that month appear in an untitled top section.
  - On a month spread, tasks assigned to days in that month appear in the same list and display the day number next to the task title.
  - Day and multiday spreads do not adopt this year/month-specific sectioning behavior.
- **Tests**:
  - Unit tests for year spread grouping covering year-, month-, and day-assigned tasks.
  - Unit tests for month spread grouping covering month- and day-assigned tasks.
  - UI tests verifying untitled current-spread tasks, titled month sections on year spreads, and day-number rendering on year/month spreads.
- **Dependencies**: SPRD-28

### [SPRD-139] UI: Paged rooted spread header navigator
- **Context**: The rooted spread navigator opened from the spread header should scale across years and support browsing/selecting month and day destinations more directly than the current flat list presentation. The navigator should become a horizontally paging year browser with expandable month rows and calendar-based day picking.
- **Spec**: Navigation and UI
- **Acceptance Criteria**:
  - The rooted spread navigator is a horizontal paging scroll view of year pages ordered chronologically left to right.
  - Each year page is a separate injected view configured with the spreads for one specific year.
  - The navigator opens on the page for the currently selected spread's year.
  - The navigation title shows the current year and updates after paging settles.
  - Each year page shows months in standard calendar order.
  - Each year page allows only one expanded month at a time.
  - Expanded month state is preserved per year page while the navigator remains open.
  - In conventional mode, only months with an explicit month spread or any day/multiday sub-spread are shown.
  - In traditional mode, all months are shown.
  - Expanding a month reveals a calendar grid for that month.
  - Calendar dates with no available target are disabled.
  - If a selected date has exactly one available target, selecting it immediately selects that spread and dismisses the navigator.
  - If a selected date has multiple available targets, a native confirmation dialog lets the user choose between the day spread and covering multiday spread targets.
  - If an expanded month has an explicit month spread, the row shows a `View Month` button that selects the month spread.
  - Tapping the month row itself only toggles expand/collapse and never directly selects the month spread.
- **Tests**:
  - Support tests for year-page month visibility in conventional and traditional modes.
  - Support tests for calendar target derivation, including single-target and multi-target day selection.
  - UI tests covering horizontal year paging, persisted expanded month state while open, `View Month`, disabled dates, and confirmation-dialog selection for overlapping day/multiday targets.
- **Dependencies**: SPRD-125
