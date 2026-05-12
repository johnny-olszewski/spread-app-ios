# JournalManager

> Source: Documentation/spec.md

### BuJo Mode
- Conventional: show only current assignments in spread content while preserving assignment history for migration logic and feedback. [SPRD-29, SPRD-186]
- Traditional: show entries only on their preferred assignment, no migration history visible, and expose the full year/month/day hierarchy through the same shared spread navigation and surface components used by conventional mode. [SPRD-17, SPRD-35, SPRD-151]

### Journal Logic Architecture
- `JournalManager` should remain the sole UI-facing journal facade. Views and view models should not call low-level business-rule engines directly; `JournalManager` delegates internally and remains responsible for repository effects, state refresh, logging, and `dataVersion` invalidation. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- `JournalManager` should not remain a rule engine. Beyond collaborator selection based on runtime mode and workflow orchestration, business-rule branching should live in extracted services/coordinators. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Extracted journal logic seams should be protocol-backed from day one so implementations are swappable and unit-test seams are explicit. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Rule engines should be pure or mostly pure where possible, returning derived models, plans, or mutation decisions without performing repository writes directly. Repository effects belong in workflow coordinators and the `JournalManager` facade. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Task and note logic should prefer separate services/coordinators when their domain behavior differs materially; shared helpers are acceptable only where the business rule is truly identical. Do not force aggressive generic `Entry` abstractions that blur task/note semantics. [SPRD-155, SPRD-156, SPRD-157]
- Each refactor slice must land with exhaustive unit coverage for its extracted seam before the task is considered complete; no deferred testing sweep. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Each slice task must also remove or shrink the superseded private `JournalManager` helpers in the same change so duplicate rule paths do not remain in the codebase. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Preferred extracted seams for journal logic are: [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
  - `JournalDataModelBuilder` protocol with separate `ConventionalJournalDataModelBuilder` and `TraditionalJournalDataModelBuilder` implementations.
  - `InboxResolver` protocol for Inbox membership and count resolution.
  - `OverdueEvaluator` protocol for overdue state and source resolution.
  - `MigrationPlanner` protocol for migration eligibility, current displayed/destination spread resolution, hierarchy traversal, and destination planning.
  - `AssignmentReconciliationCoordinator` protocol(s) for task/note preferred-assignment reconciliation and mutation workflows.
  - `SpreadDeletionCoordinator` protocol for deletion planning, reassignment, and persistence orchestration.
- `JournalManager` may select mode-specific implementations internally based on `bujoMode` when that keeps runtime wiring simpler, but the implementations themselves should remain behind injected protocol boundaries. [SPRD-154, SPRD-158]

### Targeted Journal Mutation Architecture
- The app should preserve the current user-visible behavior while reducing full `JournalDataModel` reconstruction after ordinary mutations. This is an internal performance and maintainability refactor, not a product behavior change. [SPRD-159, SPRD-160, SPRD-161, SPRD-162]
- `JournalManager` remains the single observed journal state owner. Views continue to call `JournalManager`, not repositories or low-level logic services directly. [SPRD-159, SPRD-160, SPRD-161, SPRD-162]
- Journal mutations should follow a typed command/result pipeline:
  - UI triggers a typed journal mutation through `JournalManager`.
  - `JournalManager` routes that mutation to the correct injected logic service/coordinator.
  - The service/coordinator returns updated domain entities plus a domain-scoped mutation result describing the affected scope.
  - `JournalManager` persists as needed, merges updated entities into in-memory state, and patches only the affected derived presentation slices when safe. [SPRD-159, SPRD-160, SPRD-161, SPRD-162]
- Logic services should not mutate `JournalManager` state directly. They should return updated entities and mutation scope so business logic stays unit-testable and independent of observation mechanics. [SPRD-159, SPRD-160, SPRD-161]
- Mutation scope must be described in domain terms, not UI terms. Examples:
  - acceptable: renamed task, task status changed, task moved from source spread to destination spread, affected spread keys, inbox changed, overdue changed, structural rebuild required
  - not acceptable: reload row, refresh header badge, reload section 0 [SPRD-159, SPRD-160, SPRD-161]
- `JournalDataModel` patching must be keyed by stable spread/surface identity. Conventional created spreads, traditional virtual spreads, multiday surfaces, Inbox-derived state, and overdue-derived state must all have canonical keys or patch points that `JournalManager` can target deterministically. [SPRD-159, SPRD-160]
- Journal data-model builders must support more than full rebuild:
  - full data-model build remains required
  - targeted spread/surface rebuild APIs should be added so `JournalManager` can rebuild one spread or a bounded set of spreads without replacing the whole journal snapshot
  - broad or uncertain invalidation must still fall back to a full rebuild for correctness [SPRD-160]
- Expected mutation handling tiers:
  - simple content edits: patch only affected spread surfaces and any directly impacted summary slices
  - spread membership changes such as migration or date/period reassignment: rebuild source, destination, and any affected parent/multiday/Inbox/overdue slices
  - structural changes such as reload, mode change, first-weekday change, large sync refresh, or other broad invalidation: full rebuild [SPRD-160, SPRD-161]
- During rollout, correctness wins over maximal optimization. If mutation scope is ambiguous, `JournalManager` should use the structural fallback rather than risk stale UI state. [SPRD-160, SPRD-161, SPRD-162]
- The refactor should remove redundant full-repository re-fetches on simple single-entity edits where the updated entity is already known, unless a specific repository boundary requires a verified reload. [SPRD-159]
- Testing requirements for this architecture are strict:
  - all existing unit tests must remain green
  - new unit tests must cover mutation result scope, targeted patch behavior, and full-rebuild fallback behavior
  - targeted patch tests must prove no user-visible regression in conventional, traditional, multiday, Inbox, migration, and overdue scenarios
  - tests should verify that simple mutations do not trigger unnecessary full rebuild paths once the targeted path is implemented [SPRD-159, SPRD-160, SPRD-161, SPRD-162]
