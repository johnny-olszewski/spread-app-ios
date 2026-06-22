# JournalManager

> Source: Documentation/spec.md

### Journal Logic Architecture
- `JournalManager` should remain the sole UI-facing journal facade. Views and view models should not call low-level business-rule engines directly; `JournalManager` delegates internally and remains responsible for repository effects, state refresh, logging, and `dataVersion` invalidation. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- `JournalManager` should not remain a rule engine. Beyond collaborator selection based on runtime mode and workflow orchestration, business-rule branching should live in extracted services/coordinators. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Extracted journal logic seams should be protocol-backed from day one so implementations are swappable and unit-test seams are explicit. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Rule engines should be pure or mostly pure where possible, returning derived models, plans, or mutation decisions without performing repository writes directly. Repository effects belong in workflow coordinators and the `JournalManager` facade. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Task and note logic should prefer separate services/coordinators when their domain behavior differs materially; shared helpers are acceptable only where the business rule is truly identical. Do not force aggressive generic `Entry` abstractions that blur task/note semantics. [SPRD-155, SPRD-156, SPRD-157]
- Each refactor slice must land with exhaustive unit coverage for its extracted seam before the task is considered complete; no deferred testing sweep. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Each slice task must also remove or shrink the superseded private `JournalManager` helpers in the same change so duplicate rule paths do not remain in the codebase. [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Preferred extracted seams for journal logic are: [SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
  - `JournalDataModelBuilder` protocol with a single `ConventionalJournalDataModelBuilder` implementation.
  - `InboxResolver` protocol for Inbox membership and count resolution.
  - `OverdueEvaluator` protocol for overdue state and source resolution.
  - `MigrationPlanner` protocol for migration eligibility, current displayed/destination spread resolution, hierarchy traversal, and destination planning.
  - `AssignmentReconciliationCoordinator` protocol(s) for task/note preferred-assignment reconciliation and mutation workflows.
  - `SpreadDeletionCoordinator` protocol for deletion planning, reassignment, and persistence orchestration.
- `JournalManager` wires the single conventional implementation at init; no runtime mode switching is required. [SPRD-226]

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
  - structural changes such as reload, first-weekday change, large sync refresh, or other broad invalidation: full rebuild [SPRD-160, SPRD-161]
- During rollout, correctness wins over maximal optimization. If mutation scope is ambiguous, `JournalManager` should use the structural fallback rather than risk stale UI state. [SPRD-160, SPRD-161, SPRD-162]
- The refactor should remove redundant full-repository re-fetches on simple single-entity edits where the updated entity is already known, unless a specific repository boundary requires a verified reload. [SPRD-159]
- Testing requirements for this architecture are strict:
  - all existing unit tests must remain green
  - new unit tests must cover mutation result scope, targeted patch behavior, and full-rebuild fallback behavior
  - targeted patch tests must prove no user-visible regression in conventional, multiday, Inbox, migration, and overdue scenarios
  - tests should verify that simple mutations do not trigger unnecessary full rebuild paths once the targeted path is implemented [SPRD-159, SPRD-160, SPRD-161, SPRD-162]

### Decision: Drop protocol-per-logic-seam; protocols are a repository-only boundary [SPRD-244–SPRD-248]

- **Context**: A performance audit (SESH-24) found that despite the SPRD-159–162 targeted-mutation work, almost every CRUD path still ends in a full single-entity-table reload (`tasks = await taskRepository.getTasks()`), and `SwiftDataTaskRepository`/`SwiftDataNoteRepository` each open two throwaway `ModelContext`s per save purely to recover pre-mutation state for sync-outbox diffing. Separately, the "protocol-backed from day one" rule above (line 8) was applied to every extracted logic seam — `JournalDataModelBuilder`, `InboxResolver`, `MigrationPlanner`, `OverdueEvaluator`, the assignment reconcilers, and the mutation/migration coordinators — none of which have more than one production implementation or need a test double; tests exercise them by constructing the concrete type with controlled inputs. The `any X` existentials and parallel "Standard*" factory wiring (duplicated in `init` and `rebuildTemporalCollaborators()`) cost indirection with no substitution benefit.
- **Decision**: Protocols are reserved for genuine test-substitution boundaries — repositories (`TaskRepository`, `NoteRepository`, `SpreadRepository`, `EventRepository`, `ListRepository`, `TagRepository`, `CollectionRepository`, `SettingsRepository`) — where production (SwiftData) and test (in-memory/mock) implementations both already exist and need to differ. All journal business logic (data-model building, inbox resolution, migration planning, overdue evaluation, assignment reconciliation, mutation/migration coordination) is rebuilt as concrete structs taking their dependencies (calendar, repositories) by direct initialization — no `any`, no protocol declaration, no "Standard" naming prefix.
- **Rationale**: A protocol without a second production implementation or a need for a behavior-diverging test double is pure indirection. Concrete structs remain fully unit-testable (construct with a fixed calendar/date, assert on output) without the existential dispatch cost or the duplicated wiring in `JournalManager`'s init and `rebuildTemporalCollaborators()`.
- **SPRD reference**: SPRD-244 (repositories), SPRD-245 (logic layer), SPRD-246 (index + facade), SPRD-247 (parity tests), SPRD-248 (cutover)

### Decision: Replace full-array reload and full-rebuild with an incremental, dictionary-keyed canonical store [SPRD-244–SPRD-248]

- **Context**: `JournalManager.tasks`/`.notes` are flat arrays mutated by linear scan (`first(where:)`, `removeAll(where:)`) and reassigned wholesale after nearly every mutation coordinator call, which both does an unnecessary full-table SwiftData fetch and invalidates every `@Observable` consumer of the array regardless of what actually changed. Separately, `.structural` rebuild scope (`buildDataModel()`) recomputes the entire `JournalDataModel` by filtering all tasks/notes/events against every spread — O(spreads × entries) — on every spread create-with-migration, spread delete, multiday date edit, and calendar/day-boundary crossing.
- **Decision**: The canonical in-memory store becomes `[UUID: Entity]` dictionaries (O(1) lookup/update/delete) instead of arrays. The derived `JournalDataModel` becomes a maintained reverse index (`SpreadDataModelKey ⇄ entity IDs`) updated incrementally as a direct consequence of each mutation, rather than a cache periodically recomputed from zero. There is no longer a `.structural` vs. `.spreadKeys` distinction in the rebuilt architecture — every mutation updates only the index entries its own changed assignments touch; a full index build happens exactly once, on cold load.
- **Rationale**: Eliminates both the algorithmic cost (O(spreads × entries) full rebuilds) and the observation cost (whole-array reassignment on every edit) in one structural change, rather than patching the two symptoms separately.
- **SPRD reference**: SPRD-246

### Decision: Sync-outbox diffing moves from repository-side disk re-fetch to caller-supplied change descriptors [SPRD-244]

- **Context**: `SwiftDataTaskRepository.save()`/`SwiftDataNoteRepository.save()` need to know an entity's previous `assignments`/`tags` to compute outbox create/update/delete rows, but by the time `save()` is called the caller has already mutated the `@Model` object in place, so the repository re-fetches the pre-mutation state from disk through a second, throwaway `ModelContext` — twice per save (assignments, then tags) — plus a separate `fetchCount` query to decide create-vs-update.
- **Decision**: Callers capture the pre-mutation `assignments`/`tags` themselves (they hold the value one statement before mutating it) and pass an explicit change descriptor into `save()`. Create-vs-update is answered from `JournalManager`'s own in-memory identity set, not a `fetchCount` query. Multi-entity operations (reconciliation passes, batch migration) get a batched save API that performs one `modelContext.save()` commit for all N changes instead of N separate commits.
- **Rationale**: Removes all disk re-fetches from the save path — diffing becomes an in-memory comparison the caller already has the data for. This is the single highest-impact fix found in the SESH-24 audit: creating one spread against a backlog of N pending tasks today performs up to 3N redundant SwiftData operations during reconciliation alone.
- **SPRD reference**: SPRD-244

### Decision: Build additively, validate with unit tests, cut over as a final separate step [SPRD-244–SPRD-248]

- **Context**: This is a from-scratch rebuild of `JournalManager` and its supporting repositories/logic layer, not an incremental patch. Building it directly against production wiring would make the in-progress branch unshippable and hard to review incrementally.
- **Decision**: SPRD-244–247 add only new files (new repository implementations, new concrete logic types, new index/facade types, new tests) with zero edits to existing production files — `DependencyContainer` and all views keep using the legacy `JournalManager` and `SwiftData*Repository` implementations until SPRD-248. Each new layer ships with exhaustive unit test coverage as its own validation (no debug-build trial UI). SPRD-247 adds a parity test suite asserting the new facade produces identical observable behavior to the legacy `JournalManager` across the existing CRUD/migration/inbox/overdue scenarios before SPRD-248 wires it in and deletes the legacy implementation in the same task.
- **Rationale**: Keeps the working tree shippable throughout the rebuild, gives the reviewer a clean, isolated diff per layer, and makes the cutover itself a small, low-risk, fully-reviewed swap once parity is proven — rather than a single enormous, unreviewable change.
- **SPRD reference**: SPRD-244, SPRD-245, SPRD-246, SPRD-247, SPRD-248
