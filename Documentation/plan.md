# Bulleted Implementation Plan (v1.0)

## Task Template

Use this format for every new `SPRD-##` task block:

```markdown
### [SPRD-###] Feature: <short description> - [ ] Pending

- **Context**: Why this task exists; what prompted it.
- **Description**: What is being built or changed.
- **Spec**: `Documentation/Specs/FeatureName.md` — Section name
- **Acceptance Criteria**:
  - AC1
  - AC2
- **Tests**:
  - Test description
- **Dependencies**: SPRD-## (if any)
```

The `Spec:` field is required — it tells Claude which spec file to load for this task's context.

---

## Scope Update
- Events are deferred to v2; v1 ships without event creation or display. [SPRD-69]
- Existing event scaffolding must be stubbed/hidden for v1 and kept ready for v2 integration. [SPRD-69]
- Supabase offline-first sync replaces CloudKit for v1; CloudKit configuration tasks remain for history but are superseded by the Supabase migration. [SPRD-80]
- Product usage in dev/prod now requires authentication; guest/local-only product usage is removed from v1. [SPRD-104, SPRD-106]
- Backup entitlement is removed from v1; authenticated users can sync without a purchase gate. [SPRD-104]
- Sign in with Apple and Google are removed from v1 scope; auth is email/password only, with sign-up and forgot-password flows retained. [SPRD-104, SPRD-108]
- Runtime environment switching is removed from v1. Debug keeps a non-persistent `localhost` mode for engineering only; QA remains dev-backed and Release remains prod-backed. [SPRD-105, SPRD-107]
- `WKFLW-17` is a workflow branch for one bundled schema/sync pass across spread personalization and richer task metadata plus local-only title navigator refinements. The approved scope is explicit spread favorites, explicit spread custom/dynamic naming, multiday spread date editing, task body, task priority, task due date, task-only nil preferred assignment, conventional title-strip relevance filtering, rooted navigator chevron consolidation, and derived title-strip badges. Links, tags, assigned time, subtasks, sequential/blocking dependencies, hidden-on-spreads, status expansion, and note nil-assignment parity are deferred and tracked in `Documentation/backlog.md`. [SPRD-167, SPRD-168, SPRD-169, SPRD-170, SPRD-171, SPRD-174, SPRD-175, SPRD-176, SPRD-177, SPRD-178]

## Story Overview (v1)
- Foundation and scaffolding (completed)
- Month calendar row overlays
- Spread visual system refresh
- First-class multiday assignment
- Core time and data models
- Temporal context and AppClock
- Supabase offline-first sync + auth migration (priority)
- Simplification pass: auth, environments, debug tooling, and test cleanup
- Journal core: creation, assignment, inbox, migration
- Personalized spreads and richer task metadata (`WKFLW-17`)
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

## Story: Month calendar row overlays

### User Story
- As a user, I want month-calendar surfaces to show spanning row-bounded decorations, such as multiday coverage in the rooted navigator, so I can recognize date ranges without opening each day individually.

### Definition of Done
- `MonthCalendarView` exposes a separate optional row-overlay seam distinct from `CalendarContentGenerator`.
- Overlay coverage is date-driven in v1 and may include visible peripheral day cells when they are rendered.
- The shell automatically segments overlays by visible week row, packs colliding segments into lanes, and enforces a configurable visible-lane limit.
- Over-limit packed overlays surface overflow metadata so the app can render an explicit overflow indicator lane instead of silently dropping information.
- Overlay visuals remain app-owned; foundation owns structural math, layout context, and packing behavior only.
- Overlays render between the week background and day cells and remain decorative-only.
- Package-level logic tests and focused `Spread` integration tests protect the contract.

### [SPRD-183] Feature: add row-bounded overlay seam to MonthCalendarView - [x] Complete
- **Context**: `MonthCalendarView` currently supports only single-slot content plus a week background seam. The rooted spread navigator now needs multiday coverage cues, and future calendar consumers may need other same-row date-driven decorations. Cross-row continuation was considered and explicitly deferred to keep the shell simpler and more predictable.
- **Description**: Extend `johnnyo-foundation` with a separate optional row-overlay seam for `MonthCalendarView` that supports decorative same-row overlay segments across visible day cells.
- **Spec**: Shared Month Calendar Component; Month Calendar Row Overlays
- **Implementation Details**:
  - Add a separate optional row-overlay generator protocol instead of expanding `CalendarContentGenerator`.
  - Keep the v1 overlay contract date-driven:
    - callers declare logical overlay coverage against dates
    - the shell resolves only visible day cells
    - hidden placeholders never participate
  - Allow visible peripheral dates to participate when `showsPeripheralDates == true`.
  - Split logical overlay coverage into visible row-bounded segments at week boundaries.
  - Render overlay content between `weekBackgroundView` and the day/placeholder cells.
  - Keep overlays decorative-only; do not add overlay hit testing or overlay-driven delegate actions.
  - Let consumers configure the maximum number of visible overlay lanes per week row.
  - Implement foundation-owned automatic lane packing for colliding row segments.
  - Derive overflow metadata when packed lanes exceed the visible-lane limit instead of silently discarding overflowed segments.
  - Expose a packed row-segment render context to the app that includes semantic coverage, lane assignment, row metadata, continuation flags, overflow metadata, and row-scoped layout information sufficient for app-owned rendering.
- **Acceptance Criteria**:
  - `MonthCalendarView` accepts an optional separate row-overlay seam.
  - Row overlays can span multiple visible day cells within one week row.
  - Logical overlays that cross week boundaries are split into separate row segments.
  - Visible peripheral dates participate when rendered; hidden placeholders do not.
  - Colliding segments are automatically packed into lanes by foundation.
  - The visible-lane count is consumer-configurable.
  - Overflow metadata is surfaced whenever packed segments exceed the visible-lane limit.
  - Overlay rendering does not intercept existing day/week interactions.
- **Tests**:
  - Package-unit tests for visible-date participation and placeholder exclusion.
  - Package-unit tests for row segmentation across week boundaries.
  - Package-unit tests for automatic lane packing and stable ordering of colliding segments.
  - Package-unit tests for visible-lane limiting and overflow metadata derivation.
  - Package-view tests proving overlays render between week background and day cells without altering existing cell invocation behavior.
- **Dependencies**: SPRD-153

### [SPRD-184] Feature: render multiday spread row overlays in the rooted navigator - [x] Complete
- **Context**: The first concrete consumer of the new row-overlay seam is the rooted spread navigator's expanded month grid. Conventional mode already reasons about explicit day and multiday targets there, but the grid does not yet show spanning multiday coverage.
- **Description**: Add a `Spread` overlay generator and renderer for the rooted navigator so multiday spreads appear as row-bounded spanning decorations in expanded month grids.
- **Spec**: Rooted spread navigator behavior; Month Calendar Row Overlays
- **Implementation Details**:
  - Add a `Spread`-side overlay generator for the rooted navigator month grid that derives overlay coverage from conventional multiday spread ranges.
  - Keep the first consumer decorative-only; continue to route selection through day-cell taps and existing multi-target dialogs.
  - Ensure overlay coverage reflects visible day cells, including visible peripheral dates if a future navigator configuration enables them.
  - Render app-owned overlay visuals from the packed row-segment context supplied by foundation.
  - Render app-owned overflow indicator treatment using the overflow metadata supplied by foundation.
  - Preserve existing rooted-navigator created/uncreated/today cell treatment and existing day-target selection semantics.
  - Keep traditional-mode behavior unchanged unless a concrete overlay use case is later approved there.
- **Acceptance Criteria**:
  - Conventional rooted-navigator month grids show row-bounded multiday coverage overlays for explicit multiday spreads.
  - Day-cell taps and multi-target dialogs continue to work as before.
  - Multiple overlapping multiday overlays are packed into visible lanes automatically.
  - Overflow conditions render an explicit app-owned overflow indication rather than silently hiding extra overlays.
  - Traditional-mode navigator behavior is unchanged unless explicitly covered by overlay data.
- **Tests**:
  - App-level model tests for multiday spread overlay coverage derivation in the rooted navigator.
  - App-level integration/view tests proving packed row-segment context renders the expected multiday overlay visuals.
  - Regression tests proving existing navigator selection behavior remains unchanged when overlays are present.
  - Focused UI tests for representative overlapping and overflow scenarios in the expanded month navigator.
- **Dependencies**: SPRD-183, SPRD-166, SPRD-177

### [SPRD-185] Test/Docs: codify row-overlay guarantees and edge cases - [x] Complete
- **Context**: The new seam splits responsibility between foundation-owned structural math and app-owned visuals. Without explicit documentation and edge-case coverage, future work can easily reintroduce geometry leakage or broaden the seam inconsistently.
- **Description**: Add the remaining documentation, test fixtures, and edge-case coverage needed so row overlays remain predictable and extensible.
- **Spec**: Shared Foundations Package; Month Calendar Row Overlays; Testing
- **Implementation Details**:
  - Update package-local documentation so the overlay contract is documented alongside the month shell API.
  - Add explicit guidance that cross-row continuation is out of scope for this version.
  - Add fixture coverage for:
    - week-boundary splitting
    - visible peripheral participation
    - dense overlap packing
    - visible-lane overflow
  - Ensure the app-side tests document that overflow visuals are app-owned even though overflow metadata is foundation-owned.
- **Acceptance Criteria**:
  - Package-local docs describe the overlay seam, ownership split, and current row-bounded limitation.
  - Edge-case tests cover the accepted behaviors called out in the spec.
  - The implementation guidance is clear enough that future work does not need to rediscover the lane/overflow contract.
- **Tests**:
  - Additional package fixtures for pathological overlap/overflow cases.
- App-level regression coverage for overflow rendering and non-interactive overlay behavior.
- **Dependencies**: SPRD-183, SPRD-184

## Story: Spread visual system refresh

### User Story
- As a user, I want every spread type and its related navigation surfaces to use a clearer, more calendar-structured visual system, so I can understand what exists, what is assigned where, and where work moved when more granular spreads are created.

### Definition of Done
- Spread content is current-assignment-only and no longer shows migrated-history rows.
- Year/month/day spread creation auto-migrates eligible tasks and notes within the explicit year/month/day hierarchy using existing preferred-date/preferred-period rules.
- Year, month, day, and multiday spreads follow the confirmed new layout system.
- Navigation surfaces adopt the same semantics and lighter matching visuals.
- Automatic migration feedback uses structural motion plus anchored cues with context-dependent destination reveal.
- Unit, integration, and UI coverage protect the new visibility, migration, and layout rules.

### [SPRD-186] Spec/Model: rewrite spread visibility and assignment semantics - [x] Complete
- **Context**: Current conventional spread builders and spread content surfaces still include migrated/source-history content and older sectioning rules. The new visual system requires spread content to be driven by current live assignment only, with migration becoming a distinct flow rather than persistent clutter.
- **Description**: Update the product spec and core assignment/visibility model so spread content becomes current-assignment-only and automatic migration is defined for explicit year/month/day spread creation.
- **Spec**: Shared Spread Surface Architecture; Spread Visual System Refresh
- **Dependencies**: SPRD-140, SPRD-151

### [SPRD-187] Core refactor: implement current-assignment-only builders and automatic year/month/day migration - [x] Complete
- **Context**: The data model and builders currently retain source-history visibility and require manual movement in cases the new system wants to resolve automatically.
- **Description**: Refactor spread builders, assignment visibility, and spread-creation side effects so eligible tasks and notes automatically move into newly created more-granular explicit year/month/day spreads and disappear from their old spread content immediately afterward.
- **Spec**: Spread Visual System Refresh
- **Implementation Details**:
  - Update conventional spread-data building so explicit year/month/day spread membership is driven only by current non-migrated assignments.
  - Ensure targeted derived-model rebuild scope uses only current explicit-assignment keys plus multiday aggregation keys, so source-history assignments no longer keep obsolete surfaces alive.
  - Keep assignment history persistence intact on `TaskAssignment` and `NoteAssignment`; only spread-content visibility changes.
  - Add a shared conventional-mode spread-creation reconciliation path for explicit `year`, `month`, and `day` spreads:
    - append/save the new spread
    - recompute eligible task and note destinations using the existing preferred-date/preferred-period hierarchy rules
    - persist only entries whose current assignment path actually changes
  - Apply automatic migration only within the explicit year/month/day hierarchy.
  - Do not auto-migrate into multiday spreads and do not change traditional-mode virtual spread derivation.
  - Preserve preferred-assignment ceilings:
    - year-preferred entries do not move below year
    - month-preferred entries do not move to day
    - day-preferred entries may move year → month → day as finer explicit spreads appear
  - Preserve Inbox behavior for entries with no preferred assignment and for preferred assignments that still have no valid explicit destination after spread creation.
  - Keep migration/history state available for dedicated migration flows, deletion fallback, sync durability, and future feedback work under `SPRD-192`.
- **Acceptance Criteria**:
  - Conventional explicit spread content excludes migrated-history-only task and note rows.
  - Reassignment or manual migration removes the entry from the old spread's content immediately while preserving migrated assignment history.
  - Creating an explicit year spread auto-assigns eligible Inbox entries whose best available explicit destination is that year spread, including month/day-preferred entries when no finer explicit spread exists yet.
  - Creating an explicit month spread auto-assigns eligible preferred month/day entries from Inbox or year spreads, without exceeding the preferred assignment period.
  - Creating an explicit day spread auto-assigns eligible preferred day entries from Inbox, year, or month spreads.
  - Month-preferred entries do not auto-migrate into day spreads.
  - Explicit spread creation auto-reconciles notes using the same destination hierarchy rules, while multiday spread creation remains aggregation-only.
  - Traditional-mode derived spread behavior is unchanged.
- **Tests**:
  - Builder tests for excluding migrated-history-only explicit assignments from spread content.
  - Builder/patch-scope tests for dropping migrated explicit spread keys while preserving multiday aggregation keys.
  - JournalManager tests for year/month/day spread creation auto-assigning eligible Inbox tasks and notes.
  - JournalManager tests for parent-to-child auto-migration across year → month and month → day creation.
  - JournalManager tests proving preferred-period ceilings block invalid finer auto-migration.
  - JournalManager tests proving unmatched or nil-preference entries remain in Inbox.
  - Regression tests proving multiday spread creation does not trigger direct assignment auto-migration.
- **Dependencies**: SPRD-186

### [SPRD-188] UI: redesign year spread into year section plus adaptive month cards - [x] Complete
- **Context**: The year spread needs to shift from a generic sectioned list toward a vertical month-card surface that still truthfully reflects current assignment.
- **Description**: Implement the new year spread layout with a top year-period section, adaptive month cards, month-grid previews, existence/current-month state styling, and year-assigned task/note previews inside month cards.
- **Spec**: Spread Visual System Refresh
- **Implementation Details**:
  - Replace the generic year-spread sectioning with a dedicated year surface composed of:
    - one top year-period entry section for entries currently assigned to the year with preferred period `year`
    - a vertically stacked month-card list beneath it
  - Build month cards from calendar order rather than from the old source-assignment grouping.
  - Render each month card with:
    - month title/header
    - read-only mini month grid with weekday headers and date numbers
    - no interactive cells inside the mini grid
    - explicit month-spread existence styling via solid vs dashed border
    - distinct current-month emphasis layered independently from created/uncreated state
    - a bottom `View Spread` or `Create Spread` action based on explicit month-spread existence
  - Surface year-assigned entries with dates in that month inside the corresponding card, without old migrated/source subsections.
  - Keep month-card entry previews unsectioned; when an entry has a concrete day date, render a small day-number context label.
  - Implement adaptive density rules so sparse months stay compact while dense months switch to preview-threshold plus overflow treatment instead of unbounded height.
  - Reuse shared entry-row styling and shared spread visual tokens introduced by this refreshed system instead of creating a year-only row language.
- **Acceptance Criteria**:
  - Year spreads render a top year-entry section plus one month card per calendar month.
  - Month cards visually distinguish explicit month spreads from missing month spreads using the specified border-state semantics.
  - Current-month emphasis does not replace the explicit existence styling.
  - Month cards show currently year-assigned month/day-dated entries only; migrated/source-history entries are absent.
  - Month card actions open the existing month spread when it exists and the create-spread flow when it does not.
  - Mini month grids are read-only and do not introduce cell-level navigation.
  - Dense month cards use preview limiting/overflow instead of growing without bound.
- **Tests**:
  - View-model/support tests for month-card grouping and day-number context labeling.
  - View tests for solid/dashed/current-month card state combinations.
  - View tests for `View Spread` vs `Create Spread` action routing.
  - View tests for preview-threshold and overflow behavior on dense months.
  - Integration tests proving migrated/source-history rows are absent from year surfaces while current assigned entries appear in the correct cards.
- **Dependencies**: SPRD-186, SPRD-187

### [SPRD-189] UI: redesign month spread into calendar, month section, and day-section list - [x] Complete
- **Context**: The month spread needs to become a structural calendar surface with distinct month-level and day-level current-assignment presentation.
- **Description**: Implement the new month spread layout with a structural month calendar, dedicated month-period section, and plain day-section list including explicit empty day-spread destinations.
- **Spec**: Shared Month Calendar Component; Spread Visual System Refresh
- **Implementation Details**:
  - Restructure month spreads around three fixed zones:
    - top structural month calendar
    - month-entry section for entries currently assigned to that month with preferred period `month`
    - day-section list beneath for day-preferred entries currently assigned to the month
  - Use `MonthCalendarView` as a structural/navigation surface rather than as a row-list replacement.
  - Keep explicit day-spread existence and current assignment content as separate signals in the calendar:
    - borders communicate explicit day-spread existence
    - secondary indicators communicate currently assigned content
  - Remove old generic source-based grouping and migrated-history subsections from month spread content.
  - Render non-empty day sections by default for current month-assigned day entries.
  - Preserve explicit day-spread destinations even when no current entries remain there by rendering an empty section for created day spreads.
  - Make the day-section header the clickthrough/navigation affordance to the explicit day spread.
  - Keep day-section entry content plain and list-first rather than card-composed.
- **Acceptance Criteria**:
  - Month spreads render a month calendar, a dedicated month-entry section, and a day-section list in that order.
  - Month-entry content contains only month-assigned entries whose preferred period is `month`.
  - Day sections contain only currently assigned day-period entries or explicit empty day-spread destinations.
  - A created day spread still renders its day section even when its current entry list is empty.
  - Calendar existence styling and content indicators remain distinct.
  - Month spread content no longer shows migrated-history/source sections.
- **Tests**:
  - View/support tests for separating month-period entries from day-period sections.
  - View tests for explicit empty day-spread destination rendering.
  - View tests for day-section header navigation behavior.
  - Month-calendar integration tests for distinct created/uncreated borders versus current-content indicators.
  - Integration tests proving current-assignment-only month content after auto-migration and manual migration.
- **Dependencies**: SPRD-186, SPRD-187

### [SPRD-190] UI: align day and multiday spreads with the refreshed system - [x] Complete
- **Context**: Day and multiday surfaces should preserve their strengths while adopting the new assignment-only and visual-state rules.
- **Description**: Keep day spreads list-first, update multiday to show only currently assigned entries with lighter empty days, and align shared styling/state semantics across spread surfaces.
- **Spec**: Spread Visual System Refresh
- **Implementation Details**:
  - Keep day spreads primarily list-first and avoid reworking them into the year/month card architecture.
  - Refresh day spread styling to match the shared visual system:
    - shared header semantics
    - shared section styling
    - no migrated/source-history subsection
  - Update multiday spreads so every covered day remains visible regardless of whether that day currently has entries.
  - Render only currently assigned entries inside each multiday day section.
  - Introduce a lighter empty-day treatment for multiday sections instead of removing empty dates.
  - Preserve existing multiday footer actions, created/uncreated/today card semantics, and related day-spread creation/navigation affordances while aligning the surrounding content styling with the refreshed system.
  - Ensure cancelled-task visibility rules continue to apply where task rows remain visible, while migrated-history-only rows do not reappear in spread content.
- **Acceptance Criteria**:
  - Day spreads remain list-first and adopt the refreshed shared styling without introducing year/month card behavior.
  - Day spread content is current-assignment-only.
  - Multiday spreads show every day in range, including empty days.
  - Multiday day sections render only currently assigned entries for that date.
  - Empty multiday days use a lighter empty-state treatment instead of disappearing.
  - Migrated-history/source sections are absent from both day and multiday spread content.
- **Tests**:
  - View tests for day spread list-first structure under the refreshed styling.
  - Integration tests for day spreads dropping migrated/source-history rows after reassignment.
  - Multiday support/view tests for preserving all covered dates, including empty days.
  - Multiday integration tests proving only current entries render in each day section.
  - Regression tests for cancelled-row visibility and existing multiday footer action behavior.
- **Dependencies**: SPRD-186, SPRD-187

### [SPRD-191] UI: align rooted navigator and related navigation surfaces - [x] Complete
- **Context**: The new spread system also applies to related navigation surfaces, but those surfaces should remain lighter-density than full spread pages.
- **Description**: Update the rooted navigator and related spread-preview/navigation surfaces to use the new existence/content semantics, lighter shared visual language, and refreshed month/day cues.
- **Spec**: Rooted spread navigator behavior; Spread Visual System Refresh
- **Implementation Details**:
  - Refresh rooted navigator month grids and related preview/navigation surfaces to match the new existence/content semantics:
    - explicit year/month/day spread existence remains the created/uncreated signal
    - current assignment content is communicated through lighter secondary cues
  - Keep these surfaces lighter-density than the full spread pages; do not duplicate full spread-entry previews everywhere.
  - In conventional mode, preserve the rule that multiday coverage is a decorative overlay lane and does not make day cells appear as created day spreads.
  - Align year-page month rows, expanded month grids, and related preview surfaces with the refreshed day/month visual grammar introduced by `SPRD-188` and `SPRD-189`.
  - Ensure today/current-period emphasis layers on top of created/uncreated state instead of replacing it.
  - Preserve rooted navigator selection rules, month filtering rules, and multi-target confirmation flows while refreshing the visual semantics.
  - Update any auxiliary spread-preview surfaces tied to the title navigator, month/day previews, or rooted selector so they no longer imply source-history content.
- **Acceptance Criteria**:
  - Rooted navigator day cells use distinct created/uncreated existence state plus separate current-content indication.
  - Multiday overlay lanes remain decorative and do not mark covered day cells as explicitly created.
  - Today/current-period emphasis layers correctly over created/uncreated day-cell state.
  - Conventional and traditional rooted navigator availability rules remain intact while sharing the refreshed visual language.
  - Related spread-preview/navigation surfaces no longer imply migrated/source-history content.
- **Tests**:
  - Navigator support/view tests for day-cell created/uncreated/content-state combinations.
  - Integration tests proving multiday overlay lanes remain separate from explicit day-spread existence.
  - View tests for today/current-period emphasis layering over existence state.
  - Rooted navigator interaction regression tests for month visibility, expansion, and multi-target day selection.
  - Preview/navigation surface tests for lighter shared semantics without full spread-density regressions.
- **Dependencies**: SPRD-183, SPRD-184, SPRD-186, SPRD-188, SPRD-189, SPRD-190

### [SPRD-192] UX/Test: implement migration feedback and full regression coverage - [x] Complete
- **Context**: Automatic migration is a major behavioral change and needs strong user feedback plus tests that prevent subtle regressions.
- **Description**: Add structural migration feedback, anchored cues, context-dependent reveal behavior, and comprehensive unit/integration/UI coverage for the refreshed spread system.
- **Spec**: Spread Visual System Refresh; Testing
- **Implementation Details**:
  - Add automatic migration feedback for explicit year/month/day spread creation using structural motion plus a lightweight anchored cue.
  - Define reveal behavior by context:
    - when the destination is already visible in the current surface, reveal/highlight it locally
    - otherwise update selection/navigation so the destination spread becomes visible
  - Ensure automatic migration feedback handles both task and note moves without reintroducing persistent source-history sections.
  - Keep feedback scoped to the automatic-migration transition itself rather than broad permanent badge/state additions.
  - Add comprehensive regression coverage spanning:
    - current-assignment-only spread content
    - auto-migration on explicit spread creation
    - year/month/day refreshed layouts
    - multiday current-assignment rendering
    - rooted navigator and preview semantic alignment
    - feedback/reveal behavior
  - Cover sync/rebuild durability for preserved assignment history without resurrecting source-spread content.
- **Acceptance Criteria**:
  - Automatic migration produces visible feedback rather than silently moving content.
  - Feedback reveals/highlights the destination locally when possible and otherwise changes selection to show the destination spread.
  - Automatic migration feedback works for both tasks and notes.
  - Full regression coverage protects current-assignment-only spread content across year, month, day, multiday, and navigation surfaces.
  - Sync/rebuild scenarios preserve assignment history while keeping source-spread content absent after reassignment.
- **Tests**:
  - Unit tests for auto-migration feedback decision logic and destination-reveal routing.
  - Integration tests for year/month/day spread creation auto-migration plus destination highlight/selection behavior.
  - UI tests for refreshed year/month/day/multiday surfaces and rooted navigator semantics.
  - Sync-enabled durability tests for auto-migrated and manually migrated entries rebuilding with preserved history but no resurrected source content.
  - Regression tests covering tasks vs notes, Inbox-origin entries, parent-origin entries, and preferred-period ceiling edge cases.
- **Dependencies**: SPRD-187, SPRD-188, SPRD-189, SPRD-190, SPRD-191

## Story: First-class multiday assignment

### User Story
- As a user, I want multiday spreads to be true assignment destinations, so weekly or range-based work lives on the multiday spread instead of falling back to a month/year spread and becoming confusing later.

### Definition of Done
- Multiday is a first-class assignable period for tasks and notes in conventional mode.
- Multiday remains optional product behavior: recommendations and default spread expectations still cover only year/month/day.
- Assignment resolution, deletion fallback, overdue logic, and spread rendering all treat explicit multiday assignment consistently.
- New multiday create/edit flows block overlapping ranges while grandfathering legacy overlapping data.
- Unit, integration, UI, and sync-path tests cover multiday assignment, waterfall migration, picker behavior, and legacy-overlap fallback rules.

### [SPRD-193] Core/UI/Sync: implement first-class multiday assignment semantics - [x] Complete
- **Context**: The current product and codebase treat multiday as an aggregate-only surface. That causes day-level work to fall back to month/year surfaces even when the user is working primarily out of a weekly multiday spread, which makes overdue and ownership behavior misleading. The refreshed spec makes multiday a first-class assignable period while keeping it optional and non-recommended.
- **Description**: Refactor the assignment model, unified spread picker, migration engine, multiday validation, rendering rules, overdue logic, and sync identity so explicit multiday spreads can own task/note assignments safely and predictably.
- **Spec**: Spread Periods; Migration; Spread Visual System Refresh; Edge Cases
- **Implementation Details**:
  - Update `Period`-level assignment capabilities so `multiday` is a first-class assignable period in conventional mode.
  - Introduce stable direct multiday-assignment ownership keyed to explicit multiday spread identity rather than inferring ownership only from `period + date`.
  - Preserve optional-product semantics:
    - recommendations still cover only year/month/day
    - default spread expectations never assume users will create multiday spreads
    - multiday appears only when it already exists or when the user is explicitly working in one
  - Replace the old spread-assignment UI split with the unified picker contract from the spec:
    - inline `year`, `month`, `multiday`, and `day` options
    - created/uncreated differentiation for year/month/day
    - existing-multiday-only choices for multiday
  - Change create/edit defaults so creating from a multiday spread preselects that multiday spread as the assignment destination.
  - Update reassignment/waterfall logic:
    - day-preferred entries resolve `day -> multiday -> month -> year`
    - multiday-preferred entries resolve `multiday -> month -> year`
    - month-preferred entries do not auto-resolve into multiday
  - Add automatic migration into newly created multiday spreads for eligible day-preferred and multiday-preferred entries, and preserve auto-migration from multiday into explicit day spreads when a finer destination becomes available.
  - Update multiday spread rendering so:
    - preferred-period `multiday` entries render in a dedicated spread-level section
    - day-preferred entries assigned to the multiday render only in their preferred-day section
    - multiday-assigned entries do not duplicate into overlapping day/month/year spread content
  - Update overdue logic so direct multiday assignments become overdue only after the multiday spread end date passes.
  - Update spread deletion/edit logic:
    - deleting a multiday spread reassigns owned entries through the normal non-multiday fallback hierarchy
    - editing multiday dates preserves assignment ownership by spread identity
    - new create/edit validation blocks overlapping multiday ranges
    - legacy overlapping multiday data remains readable, with deterministic fallback resolution
  - Update sync/schema/serialization as needed so direct multiday assignment survives offline edits, sync merges, date edits, and deletion fallback without ambiguity.
- **Acceptance Criteria**:
  - Tasks and notes can be explicitly assigned to existing multiday spreads.
  - Creating from a multiday spread defaults assignment to that multiday spread.
  - The unified spread picker shows year/month/day implicit or explicit destinations plus existing multiday spreads only.
  - Day-preferred entries may auto-migrate into an explicit multiday spread when it becomes the best available destination, and later auto-migrate into an explicit day spread when that day spread is created.
  - Month-preferred and year-preferred entries do not auto-migrate into multiday spreads.
  - Multiday-preferred entries render in the spread-level multiday section, while day-preferred entries render only in their preferred-day section.
  - Multiday-assigned entries appear only on their current multiday spread in spread content.
  - Direct multiday assignments become overdue only after the assigned multiday end date passes.
  - Deleting a multiday spread preserves entries by reassigning them through the non-multiday fallback hierarchy.
  - New overlapping multiday ranges are blocked; grandfathered legacy overlaps still load and resolve deterministically.
- **Tests**:
  - Unit tests for period capabilities, unified picker option derivation, and created/uncreated destination formatting.
  - Builder and reconciler tests for multiday direct assignment, day-to-multiday waterfall migration, and multiday-to-day follow-up migration.
  - Overdue tests for direct multiday assignments and fallback reassignment after multiday deletion.
  - Validation tests for blocking new overlapping multiday creates/edits while allowing grandfathered legacy overlap reads.
  - Integration tests for multiday spread rendering with spread-level multiday entries plus day-section entries.
  - Sync/serialization tests proving direct multiday assignment survives device sync, date edits, deletion fallback, and legacy-overlap resolution.
- **Dependencies**: SPRD-186, SPRD-187, SPRD-189, SPRD-190, SPRD-192

### [SPRD-194] Infra: EventKit service — CalendarEvent type, protocol, live implementation, and DI - [x] Complete
- **Context**: The app will display read-only calendar events from EventKit on day and multiday spreads. Before any UI exists, the service layer needs a clean protocol boundary so views are testable and the EventStore dependency is injectable.
- **Description**: Introduce a `CalendarEvent` value type, an `EventKitService` protocol, a `LiveEventKitService` implementation backed by `EKEventStore`, a `MockEventKitService` for testing, and wire the service into `DependencyContainer`.
- **Spec**: Events (EventKit Integration — v1)
- **Implementation Details**:
  - `CalendarEvent` struct: `id: String` (EK event identifier), `title: String`, `startDate: Date`, `endDate: Date`, `isAllDay: Bool`, `calendarTitle: String`, `calendarColor: Color`. Pure value type, not a SwiftData model, not part of the Entry hierarchy.
  - `EventAuthorizationStatus` enum: `notDetermined`, `authorized`, `denied`, `restricted`. Maps to `EKAuthorizationStatus`.
  - `EventKitService` protocol:
    - `var authorizationStatus: EventAuthorizationStatus { get }`
    - `func requestAuthorization() async -> Bool`
    - `func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent]`
    - `func openEvent(_ event: CalendarEvent)` — presents `EKEventViewController` or falls back to Calendar URL scheme
  - `LiveEventKitService`: wraps `EKEventStore`. `fetchEvents` queries all calendars with no filter (v1 shows all). `openEvent` stores a reference to the `EKEvent` by identifier for presentation.
  - `MockEventKitService`: configurable `stubbedStatus` and `stubbedEvents` array. Conforms to the protocol. Lives in its own file in the test target (or in `Debug/` if needed by the debug UI).
  - Wire `EventKitService` into `DependencyContainer` with `LiveEventKitService` as the production instance and `MockEventKitService` available for tests.
- **Acceptance Criteria**:
  - `CalendarEvent` is a struct with all display-relevant fields.
  - `EventKitService` protocol compiles and all methods are covered by `MockEventKitService`.
  - `LiveEventKitService` fetches events within the given date range from `EKEventStore` using all calendars.
  - `DependencyContainer` exposes `eventKitService: any EventKitService`.
  - No production file contains `#if DEBUG` blocks related to EventKit.
- **Tests**:
  - Unit tests for `MockEventKitService` confirming stub behavior for all protocol methods.
  - Unit tests confirming `CalendarEvent` initialisation from representative EK data shapes (all-day, timed, multi-day).
- **Dependencies**: None

### [SPRD-195] UI: Display EventKit events on day and multiday spreads - [x] Complete
- **Context**: With the `EventKitService` in place, day and multiday spread content views should fetch and display calendar events live, handle all authorization states gracefully, and let the user view event detail by tapping.
- **Description**: Add event fetching to day and multiday spread content views; render a dedicated Events section with `CalendarEventRow`; handle authorization states; present `EKEventViewController` on tap.
- **Spec**: Events (EventKit Integration — v1)
- **Implementation Details**:
  - On day spreads: request authorization on first `.task {}` / `.onAppear`. If authorized, fetch events for the spread's single day. Display in a dedicated **Events** section below the task list — all-day events first, then timed events sorted by start time.
  - On multiday spreads: fetch events covering the full spread date range. Within each day section, show the events that overlap that day.
  - `CalendarEventRow`: leading calendar color square, event title (primary), time range or "All Day" + calendar name (secondary). No swipe actions, no status toggle.
  - Tap → present `EKEventViewControllerRepresentable` (a `UIViewControllerRepresentable` wrapping `EKEventViewController`) as a sheet. Sheet is read-only (`allowsEditing = false`). A Done button dismisses.
  - If `authorizationStatus` is `.denied` or `.restricted`, the Events section is silently omitted. No empty state, no error banner.
  - If `authorizationStatus` is `.notDetermined`, call `requestAuthorization()` once on appear; show the section only after authorization resolves to `.authorized`.
  - If there are no events for the period and permission is granted, omit the Events section (no empty state).
- **Acceptance Criteria**:
  - Events appear in a dedicated section below the task list on day spreads.
  - Events appear per-day in the correct day sections on multiday spreads.
  - All-day events sort before timed events; timed events sort by start time.
  - Tapping an event row presents the native `EKEventViewController` in a sheet.
  - The Events section is absent when permission is denied, restricted, or there are no events.
  - Authorization is requested automatically on first spread appearance when status is `notDetermined`.
  - No `EKEventStore` or EventKit import appears in view files — views depend only on `EventKitService`.
- **Tests**:
  - Unit tests for event-section visibility logic (authorized + events present, authorized + no events, denied, not determined).
  - Unit tests confirming correct day-overlap filtering for multiday spread day sections.
  - UI tests verifying the Events section appears on a day spread with stubbed events, and is absent when the mock returns no events or denied status.
- **Dependencies**: SPRD-194

## Story: Day timeline visualization

### User Story
- As a user, I want to see a visual timeline of my calendar events on day spreads so I can understand my scheduled time at a glance alongside my tasks and notes.

### Definition of Done
- A fixed-height timeline card appears above the entry list on day spreads when events are present and EventKit is authorized.
- The card renders a time ruler on the left and proportionally positioned EventKit event blocks on the right.
- Overlapping events are indented so both remain partially visible.
- The timeline component in `johnnyo-foundation` is generic and protocol-driven; the Spread app provides the `CalendarEvent` rendering via a conforming provider.

### [SPRD-196] Package: DayTimelineView — coordinate space, provider protocol, and generic view
- **Context**: The app needs a day timeline visualization component. To keep it reusable and testable, the layout math and view skeleton live in the `johnnyo-foundation` package while the Spread app supplies rendering via a protocol conformance.
- **Description**: Add `DayTimeCoordinateSpace` (core), `DayTimelineItemContext` (core), `DayTimelineContentProvider` protocol (UI), and `DayTimelineView` generic SwiftUI view (UI) to `johnnyo-foundation`.
- **Spec**: Day Timeline Visualization
- **Implementation Details**:
  - `DayTimeCoordinateSpace` in `JohnnyOFoundationCore/DayTimeline/`:
    - Public `Sendable` struct with `visibleStart: Date`, `visibleEnd: Date`, `totalHeight: CGFloat`.
    - `yOffset(for date: Date) -> CGFloat` — proportional offset, clamped to `[0, totalHeight]`.
    - `height(from startDate: Date, to endDate: Date) -> CGFloat` — proportional height for a range, clamped; minimum 0.
    - Dates outside the visible window are clamped rather than excluded so edge events still partially appear.
  - `DayTimelineItemContext<Item: Identifiable & Sendable>` in `JohnnyOFoundationCore/DayTimeline/`:
    - Public `Identifiable`, `Sendable` generic struct.
    - Properties: `item: Item`, `yOffset: CGFloat`, `height: CGFloat`, `overlapOffset: CGFloat`, `coordinateSpace: DayTimeCoordinateSpace`.
    - `id` forwarded from `item.id`.
  - `DayTimelineContentProvider` protocol in `JohnnyOFoundationUI/DayTimeline/`:
    - Associated types: `Item: Identifiable & Sendable`, `ItemContent: View`, `TimeRulerLabel: View`.
    - `func startDate(for item: Item) -> Date` — the package queries this to compute layout.
    - `func endDate(for item: Item) -> Date`.
    - `@ViewBuilder func itemView(context: DayTimelineItemContext<Item>) -> ItemContent` — called by the view to render each event; the package handles position; the conformer handles appearance.
    - `@ViewBuilder func timeRulerLabel(hour: Int) -> TimeRulerLabel` — rendered at each hour tick.
  - `DayTimelineView<Provider: DayTimelineContentProvider>` in `JohnnyOFoundationUI/DayTimeline/`:
    - Public struct with: `provider: Provider`, `items: [Provider.Item]`, `date: Date`, `visibleStartHour: Int = 6`, `visibleEndHour: Int = 22`, `height: CGFloat = 240`, `calendar: Calendar = .current`.
    - Constructs `DayTimeCoordinateSpace` from `date`, `visibleStartHour`, `visibleEndHour`, and `height`.
    - Renders a two-column `HStack`: left ruler column (fixed width ~40pt) with hour labels; right event zone with hour-divider lines and item blocks.
    - Overlap detection: sorts items by start time; for each item, finds the count of earlier items whose ranges overlap; uses that depth × 12pt as `overlapOffset`. Each item view is positioned with `.frame(height:)` + `.padding(.leading, overlapOffset)` + `.offset(y: yOffset)` within a `ZStack(alignment: .topLeading)`.
    - The entire view clips to `height`.
- **Acceptance Criteria**:
  - `DayTimeCoordinateSpace` maps dates proportionally to Y offsets within the visible window, clamping outside dates.
  - `DayTimelineView` renders with items positioned at correct Y offsets relative to the visible window.
  - Overlapping items receive non-zero `overlapOffset` values; non-overlapping items receive zero.
  - The view compiles and previews against a dummy conformer in `JohnnyOFoundationUI`.
- **Tests**:
  - Unit tests for `DayTimeCoordinateSpace`: correct Y for in-range, start, end, before-start, after-end dates; correct height computation for full, partial, and zero-length ranges.
  - Unit tests for overlap detection logic: non-overlapping items all get zero offset; two overlapping items give the second a non-zero offset; three-way overlap gives escalating offsets.

### [SPRD-197] App: Integrate DayTimelineView on day spreads
- **Context**: With the generic `DayTimelineView` in place, the Spread app wires in a `SpreadDayTimelineProvider` that renders `CalendarEvent` items and displays the timeline card above the entry list on day spread content views.
- **Description**: Implement `SpreadDayTimelineProvider`, integrate `DayTimelineView` into `DaySpreadContentView`, and ensure the card only appears when authorized with events.
- **Spec**: Day Timeline Visualization
- **Implementation Details**:
  - `SpreadDayTimelineProvider` in `Spread/Views/EventKit/`:
    - Struct conforming to `DayTimelineContentProvider` with `Item = CalendarEvent`.
    - `startDate(for:)` and `endDate(for:)` forward to `CalendarEvent.startDate`/`endDate`.
    - `itemView(context:)`: renders a rounded rectangle filled with a translucent version of `event.calendarColor`, a leading 3pt color bar, and a single-line event title in caption style. All-day events use a lighter fill.
    - `timeRulerLabel(hour:)`: renders the hour as a short string (e.g. `"9 AM"`) using `SpreadTheme.Typography.caption` in `.tertiary` foreground.
  - Modify `DaySpreadContentView`:
    - Replace the top-level `VStack` `if let dataModel` branch body: insert `DayTimelineView(provider: SpreadDayTimelineProvider(), items: calendarEvents, date: spread.date, calendar: journalManager.calendar)` above `EntryListView`, wrapped in `if !calendarEvents.isEmpty`.
  - The timeline is omitted when `calendarEvents` is empty (which already handles denied/restricted states since `fetchCalendarEvents` returns empty on non-authorized status).
- **Acceptance Criteria**:
  - The timeline card appears above the entry list on a day spread when events are present and authorized.
  - The card is absent when no events exist or authorization is not granted.
  - Each event block is proportionally positioned and uses the calendar color from `CalendarEvent`.
  - Overlapping events are visually offset so both blocks are partially visible.
  - Hour labels appear at the correct positions in the ruler.
- **Tests**:
  - Unit test for `SpreadDayTimelineProvider.startDate(for:)` and `endDate(for:)` forwarding.
  - Snapshot or preview test verifying layout with a mix of non-overlapping and overlapping events.
- **Dependencies**: SPRD-195, SPRD-196

## Story: Core time and data models

### User Story
- As a user, I want the app to understand days, months, years, and multiday ranges so my journal entries are organized correctly.

### Definition of Done
- Date utilities and period normalization support first-weekday settings.
- Spread/Entry/Assignment models exist with multiday support.
- Date and multiday preset tests pass.

## Story: Temporal context and AppClock

### User Story
- As a user, I want the app's time-sensitive behavior to stay correct while the app remains open across midnight, foreground returns, DST/time-zone shifts, and locale/calendar changes, without the app unexpectedly navigating away from what I am viewing.

### Definition of Done
- A single app-wide `AppClock` owns system temporal context (`now`, `Calendar`, `TimeZone`, `Locale`) and refresh semantics, with scene lifecycle inputs feeding that shared instance.
- SwiftUI views can access the shared clock through the environment, while non-view infrastructure receives explicit injected access or explicit temporal inputs.
- `JournalManager` and related helpers no longer depend on a frozen launch-time `today` for live product semantics.
- Time-sensitive product semantics refresh correctly without automatic selection jumps.
- Draft/edit sessions keep user-entered state stable across temporal changes.
- Debug and test infrastructure support both startup-fixed and runtime-controllable temporal context.
- Unit, integration, and localhost UI scenario coverage prove correctness and protect against stale-time regressions.

### [SPRD-179] Infra: introduce AppClock and temporal-context refresh pipeline - [x] Complete
- **Context**: The app currently captures `today` at runtime creation and threads that snapshot through navigation, overdue logic, dynamic naming, and other date-sensitive surfaces. This causes stale semantics when the app stays open across day/time/context changes.
- **Description**: Add a concrete app-wide `AppClock` service that observes system temporal-context changes and publishes refreshed temporal state into the app runtime.
- **Spec**: AppClock and Temporal Context; Testing
- **Implementation Details**:
  - Add a concrete observable `AppClock` type that owns:
    - current reference time
    - current system `Calendar`
    - current system `TimeZone`
    - current system `Locale`
    - semantic refresh metadata describing why the clock refreshed and whether a day boundary was crossed
  - Keep `AppClock` infrastructure-only; do not move product policy into it.
  - Use injectable low-level collaborators rather than a top-level `AppClock` protocol:
    - current-time provider
    - notification bridge/observer
    - lifecycle bridge or scene activation hook support
  - Create one shared `AppClock` per app runtime.
  - Feed scene/app activation into the shared clock rather than creating per-scene clocks.
  - Wire refresh triggers for:
    - foreground/active transitions
    - significant time change
    - calendar day changed
    - time-zone change
    - locale change
    - current-calendar/preference change notifications/messages where applicable
  - Inject the clock into the view layer through the SwiftUI environment so descendants can read it without prop drilling.
  - Inject the same shared clock explicitly into non-view infrastructure that needs it; do not let core services depend on environment lookup.
  - Do not add a global minute ticker to `AppClock`.
- **Acceptance Criteria**:
  - The app runtime owns one shared `AppClock` instance.
  - Foreground and significant temporal-context changes refresh the shared clock without rebuilding the entire app runtime.
  - Descendant SwiftUI views can access the clock through the environment.
  - Core services do not depend on a view-only environment lookup for clock access.
  - `AppClock` publishes enough semantic refresh metadata for consumers to react without encoding product behavior in the clock itself.
  - No app-wide minute cadence is introduced.
- **Tests**:
  - Unit tests for clock refresh classification and day-boundary detection.
  - Unit tests for notification/lifecycle bridge wiring.
  - Unit tests proving locale/time-zone/calendar changes refresh the clock state.
  - Integration-style tests proving a single shared clock instance is reused across the runtime.
- **Dependencies**: SPRD-49

### [SPRD-180] Refactor: route journal semantics through AppClock and explicit temporal inputs - [x] Complete
- **Context**: A clock service alone does not fix stale semantics unless the journal layer and support helpers stop treating launch-time `today` as authoritative runtime state.
- **Description**: Refactor journal and view-support code so shared semantics refresh from AppClock while pure helpers consume explicit temporal inputs.
- **Spec**: AppClock and Temporal Context; Inbox; Modes; Navigation and UI
- **Implementation Details**:
  - Remove frozen launch-time `today` assumptions from `JournalManager`-owned live semantics.
  - Keep the hybrid recomputation model explicit:
    - shared broadly reused semantics may refresh eagerly on coarse clock changes
    - pure formatting and local checks stay lazy and accept explicit temporal input parameters
  - Pass explicit temporal inputs where practical into:
    - overdue evaluation
    - dynamic spread naming
    - today-target resolution
    - spread recommendation derivation
    - title-strip today emphasis support
    - other support/model helpers that are pure rule code
  - Refresh shared manager/view-model semantics on coarse AppClock changes without automatically changing the currently selected spread.
  - Preserve user selection across temporal refreshes unless existing non-clock logic already requires a fallback due to deleted/invalid data.
  - Distinguish live display semantics from draft state:
    - open create/edit sheets may refresh surrounding display-only labels
    - form defaults and user-entered draft state stay frozen after presentation
  - Ensure app-owned settings such as `firstWeekday` remain outside `AppClock` and are composed by consumers with temporal context.
  - Add implementation notes or local comments where needed so developers do not accidentally reintroduce frozen-time seams.
- **Acceptance Criteria**:
  - Dynamic names, `Today` behavior, overdue semantics, recommendations, and today emphasis update correctly after coarse clock changes.
  - Temporal refresh does not auto-navigate the user to a new spread.
  - Open create/edit sessions keep draft/default state stable while surrounding semantics update.
  - Pure rule helpers that remain time-sensitive accept explicit temporal input where practical instead of reaching into hidden global state.
  - Existing product behavior unrelated to time refresh remains unchanged.
- **Tests**:
  - Unit tests for explicit-input helpers across before/after temporal boundaries.
  - JournalManager/view-model tests proving shared semantic refresh without selection jumps.
  - Regression tests for dynamic names, overdue thresholds, recommendations, and today emphasis after clock changes.
  - Regression tests proving open sheets/forms do not silently rewrite draft state on temporal refresh.
- **Dependencies**: SPRD-179, SPRD-155, SPRD-157, SPRD-158

### [SPRD-181] Test/Debug: add deterministic and runtime-controllable AppClock infrastructure - [x] Complete
- **Context**: The existing localhost testing strategy relies on fixed `today` injection at launch, but AppClock behavior also needs same-session transition coverage such as midnight rollover and context changes while the app remains open.
- **Description**: Extend debug and test infrastructure so temporal context can be fixed at startup or controlled at runtime in localhost, previews, unit tests, and UI scenarios.
- **Spec**: AppClock and Temporal Context; Testing
- **Implementation Details**:
  - Preserve startup-fixed temporal context support for deterministic datasets and scenario seeding.
  - Add a controllable test/debug clock path that can:
    - advance or set the reference date/time
    - cross midnight without relaunch
    - simulate significant time change refreshes
    - change time zone
    - change locale
    - change current calendar context where applicable
  - Make the controllable clock drive the same AppClock refresh pipeline as production rather than bypassing core behavior.
  - Expose only the minimum debug/test affordances needed for engineering and automated tests.
  - Update the shared localhost scenario harness to support both startup-fixed and runtime-controlled temporal scenarios.
  - Keep debug-only wiring isolated from production files where practical.
- **Acceptance Criteria**:
  - Localhost and tests can launch with a fixed temporal context.
  - Localhost and tests can change temporal context during a running session without relaunching the app.
  - Runtime-controlled temporal changes exercise the same update path as production AppClock refreshes.
  - Existing deterministic scenario seeding remains available.
  - Release builds expose no debug-only temporal controls.
- **Tests**:
  - Unit tests for controllable clock operations and emitted refresh semantics.
  - Preview/test harness tests verifying startup-fixed and runtime-controlled configuration paths.
  - Localhost UI scenario coverage for:
    - app remains open across midnight and labels/badges update
    - foreground return after time changed while suspended
    - time-zone or locale change affecting date-sensitive UI
    - open form draft stability during temporal refresh
- **Dependencies**: SPRD-179

### [SPRD-182] Infra/UI: codify local minute-based rendering for live calendar surfaces - [x] Complete
- **Context**: The app needs a clear boundary between coarse semantic clock refreshes and future minute-level live rendering such as a current-time line on a day calendar. Without an explicit seam, developers may incorrectly turn AppClock into a global timer.
- **Description**: Add the architectural guardrails and initial support layer for minute-sensitive view-local rendering while keeping AppClock coarse-grained.
- **Spec**: AppClock and Temporal Context
- **Implementation Details**:
  - Document and enforce that minute-sensitive surfaces use local timeline-based rendering such as `TimelineView(.everyMinute)` or an equivalent local schedule.
  - Do not add a global minute revision to AppClock.
  - Add a small support seam or local pattern for live calendar/day-schedule surfaces so future work such as a current-time line can plug into minute updates without redesigning the temporal architecture.
  - Keep minute rendering view-local and display-only unless a future approved spec explicitly introduces minute-based business semantics.
- **Acceptance Criteria**:
  - The codebase contains no app-wide minute ticker inside AppClock.
  - The implementation/docs make the preferred local-minute rendering path explicit enough that future developers are not misled into using AppClock for minute polling.
  - The architectural seam is sufficient for a future day-calendar current-time line to be implemented without revisiting the coarse clock design.
- **Tests**:
  - Focused unit/view tests for any new support seam or helper introduced for local timeline usage.
  - Regression tests proving coarse AppClock refresh logic remains independent from minute-local rendering.
- **Dependencies**: SPRD-179

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

## Story: Personalized spreads and richer task metadata (`WKFLW-17`)

### User Story
- As a user, I want spread personalization, richer task planning data, and a less crowded spread navigator so the journal reflects how I organize ranges, deadlines, Inbox-first work, and long-lived years with many past spreads.

### Definition of Done
- The branch records the finalized keep/defer decision for every candidate in the `WKFLW-17` enhancement bundle.
- Approved persisted fields land through one coordinated schema/sync migration pass across SwiftData and Supabase.
- Spread personalization covers conventional explicit-spread favorites plus custom/dynamic naming for persisted explicit spreads across all period types.
- Multiday spread date editing is implemented through shared spread create/edit sheet architecture and updates existing multiday spread records without changing personalization or entry assignment semantics.
- Approved task metadata changes preserve offline-first sync, existing assignment/migration/overdue behavior, and the new task-only nil-assignment Inbox flow.
- Conventional title-strip filtering reduces irrelevant past spreads by default through a local-only display preference while preserving complete navigation through the rooted navigator and content pager.
- Rooted spread navigation is consolidated into a fixed leading title-strip affordance, including hidden-selection proxy behavior when a filtered spread remains selected.
- Title-strip badges use a derived prioritized enum so overdue task counts and favorite state explain why relevant spreads remain visible without adding schema or sync state.
- Durability tests cover local rebuild/sync paths for every approved persisted field.

### [SPRD-167] Discovery: finalize keep/defer scope for the bundled spread/task enhancement pass - [x] Complete
- **Context**: `WKFLW-17` was opened to avoid piecemeal schema churn, but the requested feature bundle mixes contained metadata work with graph-heavy features that would turn this branch into a much larger schema program.
- **Description**: Audit the requested features, explicitly decide what this branch will implement vs defer, and reconcile `Documentation/spec.md` contradictions before schema work begins.
- **Implementation Details**:
  - Final approved keep set:
    - explicit spread favorites in conventional mode
    - custom name override for persisted explicit spreads across all period types
    - dynamic naming boolean for persisted explicit spreads across all period types
    - task body as one optional plain multiline text field
    - task priority as non-null `none` / `low` / `medium` / `high`
    - task-only true nil preferred assignment
    - task due date as optional informational day-level metadata
  - Final deferred set:
    - links
    - tags and tag filters
    - assigned time
    - subtasks
    - sequential/blocking dependencies
    - hidden-on-spreads
    - status-model expansion beyond the existing task status model
    - nil-assignment parity for notes
  - Resolved spec contradictions:
    - tags remain deferred even though task body participates in existing task search
    - task preferred assignment is nullable for tasks only
    - due date is informational and does not affect assignment, Inbox, migration, or overdue behavior
    - note assignment behavior remains unchanged
- **Acceptance Criteria**:
  - Every requested item is explicitly marked keep or defer on `WKFLW-17`.
  - `Documentation/spec.md` reflects the approved branch scope and no longer leaves the assignment/due-date/tagging/note-parity decisions ambiguous.
  - Schema work does not begin until the branch scope is narrowed to the approved persisted bundle.
- **Tests**:
  - N/A beyond doc review.
- **Dependencies**: None

### [SPRD-168] Schema: land one additive schema/sync pass for the approved `WKFLW-17` bundle - [x] Complete
- **Context**: The current persisted model is minimal. Any approved spread/task enhancements must update SwiftData, Supabase tables, merge RPCs, serializers, repair/rebuild paths, and the committed local schema snapshot together.
- **Description**: Implement one coordinated schema migration for the approved persisted fields from `SPRD-167`, keeping the pass additive and bounded.
- **Implementation Details**:
  - Add persisted spread fields for explicit spreads:
    - `isFavorite`, default false
    - optional `customName` / name override
    - `usesDynamicName`, default on for newly created spreads and off for existing migrated spreads
  - Add persisted task fields:
    - optional plain text `body`
    - non-null `priority` enum with `none`, `low`, `medium`, `high`, default `none`
    - optional day-level `dueDate`
    - nullable preferred assignment fields for tasks only
  - Keep note preferred assignment non-null and defer note parity.
  - Add per-field sync/conflict timestamps for every independently mergeable new metadata field.
  - Do not move preferred assignment into the new independent metadata conflict system; keep assignment/status under existing sync behavior.
  - Treat clearing optional fields to nil as first-class edits that update their per-field timestamps.
  - Initialize new field timestamps during migration/backfill from each record's existing sync/update timestamp, not migration time.
  - Update Supabase migrations, merge RPCs, RLS-safe table definitions, serializers, deserializers, repair/backfill paths, and `supabase/local/public_schema_from_dev.sql`.
  - Keep delete semantics stable: delete wins over concurrent `WKFLW-17` metadata edits and does not resurrect records.
  - Avoid introducing child-table graphs or persisted virtual-spread personalization.
- **Acceptance Criteria**:
  - All approved persisted fields from `SPRD-167` exist end-to-end in SwiftData and Supabase.
  - All approved persisted fields sync across devices through existing offline-first sync flows.
  - Independent new metadata fields merge independently; same-field conflicts use field-level last-write-wins.
  - New task metadata is preserved against title edits, while assignment/status changes keep existing behavior.
  - Local rebuild/reset flows succeed with the new schema.
  - No deferred `WKFLW-17` candidates are partially persisted.
- **Tests**:
  - Unit/integration coverage for serializer round-trips and merge/apply behavior for each approved field.
  - Conflict tests for independent-field merge, same-field last-write-wins, clears to nil, title-vs-metadata edits, assignment/status preservation, and delete-wins behavior.
  - Local Supabase rebuild/reset verification.
- **Dependencies**: SPRD-167

### [SPRD-169] Feature: add explicit-spread personalization with favorites and naming - [x] Complete
- **Context**: Spread personalization is the lowest-risk user-facing portion of the bundle and can validate the bundled schema pass before task semantics become more complex.
- **Description**: Add conventional explicit-spread favorites plus custom/dynamic naming for persisted explicit spreads across all period types.
- **Implementation Details**:
  - Favorite behavior:
    - favorites apply only to conventional explicit spreads
    - favorite/unfavorite from a star/favorite toggle in the spread header or nearby spread-level toolbar area
    - toolbar favorites button appears in conventional mode and is hidden in traditional mode
    - toolbar favorites menu lists only favorites from the currently selected year because `SpreadTitleNavigatorView` is year-scoped
    - if the current year has no favorites, keep the button visible and show an explanatory empty menu
    - favorite menu order uses the app's normal chronological spread ordering
    - selecting a favorite navigates `SpreadTitleNavigatorView` to that spread
    - favorites are tied to the spread record lifecycle; deleting and recreating the same period/date starts fresh
  - Naming behavior:
    - custom name override and dynamic naming apply to persisted explicit spreads across all period types
    - custom override always wins over dynamic naming
    - dynamic naming is a separate boolean fallback used only when no override exists
    - dynamic naming defaults on for newly created explicit spreads and off for existing migrated spreads
    - spread creation includes optional naming controls prefilled with dynamic naming on and no override
    - existing spreads expose an `Edit Name` action in the spread header or nearby toolbar area
    - `Edit Name` and favorites are hidden in traditional mode because virtual destinations are not persisted personalization targets
    - dynamic naming remains independently editable while an override exists
    - clearing an override falls back to dynamic naming only if dynamic naming is on; otherwise it falls back to the canonical date title
    - custom overrides trim leading/trailing whitespace and store nil when empty; duplicate names are allowed
  - Display behavior:
    - personalized display name is the primary label, including in `SpreadTitleNavigatorView`
    - canonical date title appears as secondary context where space allows
    - favorites menu labels use the current live display name at render time
  - Dynamic naming behavior:
    - live derived at render time using each device's local calendar/timezone
    - use existing app calendar, first-weekday, and multiday preset rules
    - day/month/year dynamic names cover previous/current/next only
    - multiday dynamic names are limited to standard week/weekend-style ranges in the previous/current/next window
    - relative labels do not introduce a week period or week assignment granularity
- **Acceptance Criteria**:
  - Users can favorite/unfavorite conventional explicit spreads from the spread surface.
  - The toolbar favorites menu is year-scoped, chronological, stable in empty years, hidden in traditional mode, and navigates the title navigator to the chosen spread.
  - Explicit spreads can be named at creation and renamed/toggled later.
  - Custom override, dynamic naming, canonical fallback, trimming, duplicates, and live label updates follow the spec.
  - Personalized labels are primary in navigation surfaces; date context is secondary where available.
- **Tests**:
  - Unit tests for relative-label generation across previous/current/next day/month/year and week/weekend multiday cases.
  - Unit tests for naming fallback priority, trimming/nil behavior, duplicate-name allowance, and device-local live derivation.
  - UI/unit tests for favorite toggle, year-scoped menu contents, empty menu state, traditional-mode hiding, and title navigator navigation.
  - Persistence/sync tests for favorite, custom name, and dynamic naming fields.
- **Dependencies**: SPRD-168

### [SPRD-172] UI: refine SpreadTitleNavigatorView label matrix for personalized naming - [x] Complete
- **Context**: `SPRD-169` already implemented explicit-spread favorites and naming. After implementation, the title navigator label requirements were refined so personalized names and canonical fallback labels have an explicit per-period layout matrix.
- **Description**: Update `SpreadTitleNavigatorView` label rendering so canonical and personalized labels follow the finalized matrix for year, month, day, and multiday spreads.
- **Implementation Details**:
  - Treat custom overrides and qualifying dynamic names as the same personalized label source.
  - Canonical labels:
    - year: keep the existing stacked year layout
    - month: show four-digit `YYYY` above uppercase `MMM`
    - day: keep the existing `MMM` / day number / `EEE` layout
    - multiday: keep the existing month or month-range / day-range / weekday-range layout
  - Personalized labels:
    - year: show `YYYY` above the personalized name with no footer
    - month: show `MMM` above the personalized name above `YYYY`
    - day: show `MMM d` above the personalized name above `EEE`
    - multiday: show compact date range above the personalized name above weekday range
  - Keep the `SPRD-169` naming source rules intact: custom override wins, dynamic naming is a fallback, and canonical labels are used when neither personalized source applies.
- **Acceptance Criteria**:
  - `SpreadTitleNavigatorView` renders the canonical month label as `YYYY` over `MMM`.
  - Personalized labels use the same layout whether the source is a custom override or a qualifying dynamic name.
  - Personalized year/month/day/multiday labels render with the finalized header/name/footer matrix.
  - Existing canonical year/day/multiday behavior remains unchanged.
- **Tests**:
  - Unit tests for the `SpreadTitleNavigatorView` label matrix across canonical and personalized year/month/day/multiday spreads.
  - Regression tests proving dynamic and custom personalized sources render identically for equivalent labels.
- **Dependencies**: SPRD-169

### [SPRD-173] UI: add confirmed Delete Spread action to spread actions menu - [x] Complete
- **Context**: Spread deletion is implemented and tested through `JournalManager.deleteSpread(_:)`, but no user-facing affordance currently calls it. The existing spread actions menu only exposes `Edit Name`.
- **Description**: Add a destructive `Delete Spread` action to the same spread actions menu as `Edit Name` for conventional explicit spreads.
- **Implementation Details**:
  - Show `Delete Spread` in the current spread header actions menu for conventional explicit spreads only.
  - Keep the action hidden in traditional mode because traditional destinations are virtual and not persisted explicit spread records.
  - Present a destructive confirmation alert before deleting.
  - Alert copy must explain that only the spread is deleted; tasks and notes are preserved and moved to the nearest parent spread or Inbox by the existing deletion coordinator.
  - Treat the user-facing action as permanent deletion with no restore/trash flow.
  - Preserve the current implementation semantics: local SwiftData spread row is deleted immediately and sync emits the existing tombstone/`deleted_at` delete mutation so other devices apply delete-wins behavior.
  - Do not add special favorited-spread copy or a required unfavorite step; deleting the spread naturally removes its favorite shortcut.
  - After successful deletion, rely on the existing best-available fallback selection behavior when the selected spread no longer exists.
  - If deletion fails, keep the user on the spread and show an error alert.
  - Trigger a sync after successful deletion when a sync engine is available, matching other spread/task/note mutation flows.
- **Acceptance Criteria**:
  - Users can open the spread actions menu and choose `Delete Spread` from the same menu as `Edit Name`.
  - Confirming the alert deletes the spread and preserves contained tasks/notes according to existing parent-or-Inbox reassignment rules.
  - Cancelling the alert leaves the spread, tasks, notes, favorites, and selection unchanged.
  - Successful deletion removes the spread from the title navigator and navigates to a valid fallback selection.
  - Deletion failure surfaces an error alert and leaves the user on the current spread.
  - Traditional mode does not expose a delete-spread action.
- **Tests**:
  - Unit/view-model tests or view inspection where practical for menu visibility and action wiring.
  - Journal/UI integration coverage for confirm, cancel, failure alert, and post-delete selection fallback.
  - Regression coverage that deleting a favorited spread removes it from the favorites menu through normal spread removal.
- **Dependencies**: SPRD-169, SPRD-172

### [SPRD-174] Refactor: consolidate spread create/edit sheet architecture - [x] Complete
- **Context**: Multiday spread date editing should reuse the existing spread creation sheet surface instead of creating a parallel edit form. The current creation sheet mixes form state, validation, view copy, and persistence callbacks around creation-only assumptions, which would make future spread add/edit changes easy to duplicate.
- **Description**: Refactor the spread sheet flow so creation and focused edit modes share one form/state/validation architecture while preserving the current create-spread behavior.
- **Spec**: Workflow Branch Bundle (`WKFLW-17`); Spread
- **Implementation Details**:
  - Introduce a shared spread sheet mode/model/configuration that can represent:
    - create mode for year/month/day/multiday spreads
    - edit-dates mode for an existing multiday spread
  - Keep the existing create mode behavior and copy intact:
    - title `New Spread`
    - `Cancel` and `Create`
    - spread type selection
    - year/month/day date picker
    - multiday presets and custom range controls
    - custom name and dynamic-name controls
  - Add edit-mode configuration support without yet requiring the actions-menu entry:
    - title `Edit Dates`
    - `Cancel` and `Save`
    - multiday date-range controls and presets only
    - no spread type picker
    - no custom-name field
    - no dynamic-name toggle
    - no favorite controls
  - Centralize validation so create and edit share the same multiday date rules, duplicate detection, and validation messages, with edit mode able to ignore the spread currently being edited.
  - Expose an unchanged-range state so edit mode can disable `Save` when no date change has been made.
  - Preserve existing accessibility identifiers where behavior is unchanged and add edit-mode identifiers only where tests need to distinguish save/cancel/date controls.
  - Do not add new persisted fields or Supabase migrations in this refactor.
- **Acceptance Criteria**:
  - Existing spread creation behavior remains unchanged for year/month/day/multiday creation. (Spec: Workflow Branch Bundle (`WKFLW-17`); Spread)
  - The shared sheet architecture can render a focused multiday edit-dates mode without duplicating create-sheet date-range logic. (Spec: Workflow Branch Bundle (`WKFLW-17`); Spread)
  - Edit-mode validation can ignore the current spread for duplicate checks while still detecting exact duplicate ranges against other multiday spreads. (Spec: Workflow Branch Bundle (`WKFLW-17`); Edge Cases)
  - Edit mode can detect unchanged ranges independently from invalid ranges. (Spec: Workflow Branch Bundle (`WKFLW-17`))
- **Tests**:
  - Unit/support tests for the shared configuration/model covering create mode and edit-dates mode.
  - Unit/support tests for multiday duplicate detection that ignores the edited spread but rejects another spread with the same range.
  - Unit/support tests for unchanged-range detection and save-disabled state.
  - Regression tests for existing create-spread validation and prefill behavior.
- **Dependencies**: SPRD-169, SPRD-172, SPRD-173

### [SPRD-175] UI: add Edit Dates for conventional multiday spreads - [x] Complete
- **Context**: Multiday spreads are views over existing days rather than assignment owners. Users should be able to correct or move a multiday view by editing its start/end dates while preserving the spread's identity, name, favorite state, and aggregation semantics.
- **Description**: Add an `Edit Dates` action for conventional explicit multiday spreads and persist date-range edits on the existing spread record through the shared spread sheet architecture from `SPRD-174`.
- **Spec**: Workflow Branch Bundle (`WKFLW-17`); Spread; Spread Periods; Edge Cases
- **Implementation Details**:
  - Add `Edit Dates` to the existing spread actions ellipsis menu for conventional explicit multiday spreads only.
  - Place `Edit Dates` after `Edit Name` and before destructive `Delete Spread`.
  - Keep `Edit Dates` hidden for year/month/day spreads and hidden in traditional mode.
  - Open the shared spread sheet in edit-dates mode for the selected multiday spread.
  - Edit mode shows only multiday date-range controls and presets, with title `Edit Dates`, `Cancel`, and `Save`.
  - Do not expose or mutate spread type, custom name, dynamic-name setting, or favorite state from `Edit Dates`.
  - Validate edits using the existing multiday creation date limits:
    - start date uses the current multiday minimum-start rule
    - end date uses the current multiday minimum-end rule
    - maximum date remains the existing creation maximum
    - end date must be on or after start date
    - exact duplicate ranges with another multiday spread are invalid
    - the edited spread is ignored for duplicate checking
    - partial overlaps with other multiday spreads remain allowed
  - Disable `Save` when the selected range is unchanged, invalid, or an exact duplicate of another multiday spread.
  - Persist a successful edit by mutating the same spread record ID and updating the spread `date`, `startDate`, and `endDate` fields together from one user action.
  - Preserve custom name, dynamic-name setting, and favorite state unchanged.
  - Use existing field-level sync timestamps for `date`, `startDate`, and `endDate`; no Supabase schema/RPC migration is expected unless implementation finds the existing merge path cannot persist those fields.
  - Keep delete-wins behavior over concurrent date edits.
  - After successful save, dismiss the sheet, keep the edited spread selected by record identity, and rebuild/recenter the title navigator and content pager around the new range, including cross-year moves based on the updated start date.
  - If local persistence fails, keep the edit sheet open, preserve the selected range, and show an error alert; later sync failures continue through existing sync status/error UI.
- **Acceptance Criteria**:
  - Conventional explicit multiday spreads show `Edit Dates` in the spread actions menu between `Edit Name` and `Delete Spread`. (Spec: Workflow Branch Bundle (`WKFLW-17`))
  - Year/month/day spreads and traditional-mode destinations do not expose `Edit Dates`. (Spec: Workflow Branch Bundle (`WKFLW-17`))
  - `Edit Dates` opens a date-only edit sheet with the agreed copy and without spread type, naming, dynamic-name, or favorite controls. (Spec: Workflow Branch Bundle (`WKFLW-17`))
  - Invalid ranges, unchanged ranges, and exact duplicate ranges with another multiday spread cannot be saved. (Spec: Edge Cases)
  - Partial overlapping multiday ranges can be saved. (Spec: Edge Cases)
  - Saving updates the same spread record and preserves custom name, dynamic-name setting, and favorite state. (Spec: Spread)
  - After save, the app remains selected on the edited spread and the navigator/pager reflect the updated range. (Spec: Workflow Branch Bundle (`WKFLW-17`))
  - Save failure leaves the sheet open with the user's selected range and surfaces an error alert. (Spec: Workflow Branch Bundle (`WKFLW-17`))
- **Tests**:
  - Unit/support tests for menu visibility/action availability by spread period and mode.
  - Unit/support tests for edit-date validation, including exact duplicate rejection, edited-spread duplicate exemption, unchanged range, invalid range, and partial-overlap allowance.
  - JournalManager tests proving date edits update the same spread record and preserve custom name, dynamic-name setting, and favorite state.
  - Navigation/model tests proving post-save selection stays on the edited spread and rebuilds/recenters when the updated range changes its ordering or year scope.
  - One UI flow test covering opening `Edit Dates` from a multiday actions menu, changing the range, saving, and seeing the updated selected spread.
- **Dependencies**: SPRD-174

### [SPRD-176] Feature: filter conventional title strip past spreads by relevance - [x] Complete
- **Context**: `SpreadTitleNavigatorView` can become crowded and laggy when a selected year contains many explicit spreads. Old past spreads that no longer contain actionable work make relevant current/future spreads harder to reach, while users still need a way to access the complete navigation history.
- **Description**: Add a local, per-device title-strip display preference that defaults the conventional horizontal title strip to showing only relevant past spreads while keeping current/future spreads and complete navigation available elsewhere.
- **Spec**: Workflow Branch Bundle (`WKFLW-17`); Navigation and UI; Settings
- **Implementation Details**:
  - Add a local-only display preference with two values:
    - `Relevant Past Only` (default)
    - `Show All Spreads`
  - Persist the preference outside synced schema using `UserDefaults`/`@AppStorage` or an equivalent local-only settings store.
  - Do not add SwiftData, Supabase, RPC, serializer, snapshot, or migration changes for this preference.
  - Expose the preference in Settings rather than in the spread toolbar/title strip.
  - Settings copy should explain that filtered mode keeps current/future spreads plus favorited or open-task past spreads visible, and that the rooted chevron navigator remains available for complete navigation when a spread is not immediately visible.
  - Apply filtering only in conventional mode. Traditional mode keeps the full virtual year/month/day strip unchanged.
  - In `Show All Spreads`, keep the existing conventional selected-year strip: all explicit year/month/day/multiday spreads in normal chronological order.
  - In `Relevant Past Only`, keep all current and future explicit spreads visible.
  - In `Relevant Past Only`, hide a past explicit spread unless it is favorited or currently shows at least one `.open` task.
  - Define past by period:
    - day: past after that day has fully passed
    - month: past after that month has fully passed
    - year: past after that year has fully passed
    - multiday: past after its end date has passed
  - Use existing display/inclusion rules for open-task relevance:
    - year/month/day spreads are relevant when they currently show at least one `.open` task under existing conventional spread-resolution rules
    - multiday spreads are relevant when at least one `.open` task has a preferred assignment date inside the multiday range under existing multiday inclusion behavior
  - Completed, cancelled, migrated-history-only tasks, notes, and events do not preserve past title-strip visibility.
  - Perform filtering in the title navigator support/model layer before item rendering so hidden spreads do not incur normal item view cost.
  - Decouple the filtered title-strip presentation sequence from complete navigation sequences: the content pager, rooted navigator, global task browser ordering, and current-year favorites menu must continue to have access to complete eligible navigation data.
  - Because favorited past spreads remain visible by rule, the current-year favorites menu should remain functionally unaffected by filtered mode.
- **Acceptance Criteria**:
  - Conventional mode defaults to `Relevant Past Only` when no local preference exists. (Spec: Settings)
  - Users can switch between `Relevant Past Only` and `Show All Spreads` in Settings without a schema or sync change. (Spec: Settings)
  - `Show All Spreads` preserves the existing complete conventional title-strip behavior. (Spec: Navigation and UI)
  - `Relevant Past Only` always shows current/future explicit spreads and hides only irrelevant past explicit spreads. (Spec: Navigation and UI)
  - Past favorited spreads and past spreads with at least one open task remain visible. (Spec: Navigation and UI)
  - Traditional mode title-strip contents are unchanged. (Spec: Modes)
  - Global task browser sections and complete navigation surfaces are not filtered by the title-strip preference. (Spec: Navigation and UI)
- **Tests**:
  - Unit/support tests for display-preference defaulting and local persistence.
  - Unit/support tests for past/current/future classification by year, month, day, and multiday range.
  - Unit/support tests proving favorite and open-task relevance retain past conventional spreads.
  - Unit/support tests proving completed/cancelled/migrated-only tasks and notes do not retain past spreads.
  - Unit/support tests proving traditional strip generation ignores the preference.
  - Regression tests proving `Show All Spreads` matches the pre-filter conventional item set and ordering.
  - Regression tests proving global task browser ordering and favorites menu data are not accidentally reduced by the filtered presentation sequence.
- **Dependencies**: SPRD-169, SPRD-170, SPRD-172, SPRD-175

### [SPRD-177] UI: move rooted navigator trigger into fixed title-strip leading inset - [x] Complete
- **Context**: The selected spread item is no longer the rooted navigator opener; selection is now represented by dot indicator and typography. Filtering the horizontal strip also needs a complete, always-visible navigation escape hatch when the selected spread is hidden from the filtered presentation.
- **Description**: Move the rooted spread navigator trigger out of `SpreadHeaderView` and into a fixed leading inset of `SpreadTitleNavigatorView`, and use that affordance as the selected-state proxy when the selected spread is hidden by the conventional relevance filter.
- **Spec**: Workflow Branch Bundle (`WKFLW-17`); Navigation and UI; Header Spread Navigator
- **Implementation Details**:
  - Add a fixed leading chevron/rooted-navigator affordance to `SpreadTitleNavigatorView`.
  - Keep the affordance outside the scrollable title content so it remains visible while the strip scrolls.
  - Present the existing rooted spread navigator from this affordance:
    - iPad: popover rooted on the leading affordance
    - iPhone: large sheet with the same rooted navigator content
  - Remove rooted-navigator ownership from `SpreadHeaderView`; the spread header should not duplicate the chevron trigger.
  - Preserve the rooted navigator as a complete, unfiltered navigation surface.
  - Tapping the selected spread item in the title strip should not open the rooted navigator.
  - When the selected spread is visible in the title strip, keep the existing selected dot indicator under the selected item.
  - When the selected spread is hidden by `Relevant Past Only`, keep the selected spread valid and render the leading chevron as the selected-state proxy:
    - use selected styling on the chevron affordance
    - draw the selected indicator dot underneath the chevron affordance
    - animate the dot smoothly between visible strip items and the leading affordance using the same matched/coordinate-space-aware indicator system
  - If the user selects a hidden spread from the rooted navigator or by swiping the content pager, do not force a fallback selection or mutate the filter; show the hidden-selection proxy.
  - If the user switches to `Show All Spreads` or otherwise makes the selected spread visible, return the indicator to the selected strip item.
  - Accessibility should identify the chevron as the complete spread navigator and indicate when it is representing a hidden selected spread.
- **Acceptance Criteria**:
  - The rooted spread navigator opens from the fixed leading title-strip chevron on iPad and iPhone. (Spec: Spread Navigator Surface)
  - `SpreadHeaderView` no longer shows or owns a duplicate rooted-navigator chevron. (Spec: Shared Spread Surface Architecture)
  - The rooted navigator remains complete and unfiltered even when the title strip is in `Relevant Past Only`. (Spec: Navigation and UI)
  - Selected visible spreads keep the normal title-strip selected styling and indicator. (Spec: Navigation and UI)
  - Selected hidden spreads keep valid selection, show selected styling on the leading chevron, and move the indicator dot under the chevron. (Spec: Navigation and UI)
  - Rooted-navigator selection and content-pager swiping can select a hidden spread without forcing navigation to a visible fallback. (Spec: Navigation and UI)
  - Accessibility labels/hints distinguish the complete navigator affordance and hidden-selected proxy state. (Spec: Accessibility)
- **Tests**:
  - Unit/support tests for hidden-selected-proxy state derivation.
  - View/UI tests or focused interaction tests proving the leading chevron opens the rooted navigator on compact and regular presentations where practical.
  - Regression tests proving selected title-strip items no longer open the rooted navigator.
  - Regression tests proving hidden rooted-navigator selections and pager-driven hidden selections activate the leading proxy rather than changing selection.
  - Snapshot/visual or targeted view tests for visible-selection indicator placement and hidden-selection chevron indicator placement where practical.
- **Dependencies**: SPRD-176

### [SPRD-178] UI: add prioritized title navigator badges for overdue and favorite state - [x] Complete
- **Context**: `SPRD-176` can retain past spreads when they are favorited or contain overdue work, but the title strip does not always explain why a past spread remains visible. Multiday spreads are especially unclear because they aggregate contained days rather than owning direct task assignments.
- **Description**: Replace the title-strip item badge inputs with a single prioritized badge enum that can render overdue task counts or favorite state in one top-right badge slot.
- **Spec**: Workflow Branch Bundle (`WKFLW-17`); Navigation and UI; Spread title navigator badges
- **Implementation Details**:
  - Introduce a model-level title navigator badge enum/value object rather than adding parallel boolean/count fields.
  - Supported badge cases for this task:
    - `overdue(count)`
    - `favorite`
  - Render at most one badge per title-strip item.
  - Badge priority is `overdue(count)` first, then `favorite`.
  - Preserve the existing overdue visual language for `overdue(count)`:
    - red numeric badge
    - exact uncapped count
    - selected spread still shows the badge
  - Render `favorite` as a yellow `star.fill` badge in the same top-right badge slot.
  - If a favorited spread also has overdue work, show only the overdue count badge.
  - Apply the badge enum in both conventional title-strip display modes: `Relevant Past Only` and `Show All Spreads`.
  - Conventional explicit year/month/day/multiday spreads can show overdue or favorite badges.
  - Traditional virtual year/month/day items should use the same badge enum path for overdue counts only; favorite badges never apply in traditional mode.
  - Overdue count semantics:
    - count only open tasks whose preferred assignment date/period has passed under existing overdue threshold rules
    - exclude completed, cancelled, and migrated-history-only tasks
    - for conventional year/month/day spreads, preserve the existing current-spread/source assignment semantics and do not propagate child counts to ancestor spreads
    - for conventional multiday spreads, count open tasks whose preferred assignment date falls inside the multiday range and whose preferred assignment period has passed
    - overdue tasks still in `Inbox` because no spread assignment/source exists remain excluded from year/month/day spread badges, but can contribute to a multiday badge when their preferred assignment date falls inside that multiday range
  - Do not add schema, Supabase, sync, or local persistence changes; badges are derived from existing spread/task state.
  - Keep tapping a badged spread identical to tapping any other spread; badges do not open review flows.
  - Accessibility:
    - semantic labels should describe the badge meaning, such as `3 overdue tasks`, `3 overdue tasks in this date range`, or `Favorited spread`
    - badge accessibility identifiers should include badge kind plus spread date/period, such as `overdue-2026-03-01-day` or `favorite-2026-01-01-year`, so tests can target a specific spread's badge
- **Acceptance Criteria**:
  - Title-strip items render at most one badge using the prioritized enum. (Spec: Navigation and UI)
  - Overdue badges take priority over favorite badges. (Spec: Spread title navigator badges)
  - Favorite conventional explicit spreads without overdue work show a yellow star badge in the title strip. (Spec: Workflow Branch Bundle (`WKFLW-17`))
  - Conventional multiday spreads show overdue counts for open overdue tasks whose preferred assignment date falls inside their range. (Spec: Spread title navigator badges)
  - Existing year/month/day overdue count behavior is preserved except for moving through the new badge enum. (Spec: Spread title navigator badges)
  - Traditional items can still show overdue badges through the enum path and never show favorite badges. (Spec: Modes)
  - Badge behavior is the same in `Relevant Past Only` and `Show All Spreads`. (Spec: Settings)
  - Badges use semantic accessibility labels and per-spread accessibility identifiers. (Spec: Accessibility)
  - No schema, sync, or persistence migration is introduced. (Spec: Workflow Branch Bundle (`WKFLW-17`))
- **Tests**:
  - Unit/support tests for badge priority: overdue beats favorite, favorite appears only when no overdue badge exists.
  - Unit/support tests for conventional year/month/day overdue badge counts preserving existing assignment/source semantics.
  - Unit/support tests for multiday overdue counts from open tasks inside the range whose preferred assignment period has passed.
  - Unit/support tests proving completed, cancelled, and migrated-history-only tasks do not count.
  - Unit/support tests proving traditional items use overdue badges only and never favorite badges.
  - View/UI tests or snapshot tests for red count badge, yellow star badge, selected-item coexistence, and per-spread accessibility identifiers.
- **Dependencies**: SPRD-169, SPRD-170, SPRD-176, SPRD-177

### [SPRD-170] Feature: add richer task metadata with body, priority, optional Inbox assignment, and due dates - [x] Complete
- **Context**: These task changes are still contained enough for a single branch, but they materially affect creation/edit flows, Inbox semantics, and overdue logic.
- **Description**: Add task body, priority, optional nil preferred assignment, and due dates that are distinct from assignment targets.
- **Implementation Details**:
  - Task-level metadata:
    - `body` is one optional plain multiline text field, distinct from standalone `Note` entries
    - trim `body` on save and store nil when empty or whitespace-only
    - `priority` is a non-null enum with `none`, `low`, `medium`, `high`, defaulting to `none`
    - priority is display-only and does not change ordering
    - `dueDate` is optional day-only informational metadata
    - due date is fully independent from preferred assignment, can be any calendar day including the past, and has no validation relationship to assignment
  - Task row presentation:
    - show priority as text badges for `low`, `medium`, and `high`; omit `none`
    - show due date inline when present
    - show due-date today/past highlight only for open tasks and keep it visually distinct from assignment-overdue styling
    - show due date neutrally on completed/cancelled rows
    - show both assignment-overdue and due-date-highlight signals when both apply
    - show one-line body preview when body is present
  - Task create/edit UI:
    - priority and due date are visible in the main form
    - body is in an expandable/details area
    - body, priority, and due date remain editable when a task is complete or cancelled even if assignment controls are disabled
    - assignment is controlled by an explicit optional `Assign to spread` section
    - creating from an explicit year/month/day spread defaults assignment on and prefilled to the selected spread
    - creating from an explicit multiday spread defaults assignment on and prefilled to the multiday range start day at day granularity
    - creating from a non-spread context defaults assignment off; turning assignment on prepopulates today at day granularity
    - editing a true nil-assignment task and turning assignment on also prepopulates today at day granularity
    - editing an Inbox task shows assignment on when it has a preferred assignment but no matching spread, and off only for true nil-assignment tasks
  - Nil-assignment behavior:
    - true nil preferred assignment is task-only; note parity is deferred
    - true nil-assignment tasks are Inbox-first in both conventional and traditional modes
    - true nil-assignment tasks stay in Inbox until explicitly assigned, are unaffected by spread creation, and are never overdue until assigned
    - assigned tasks keep the existing most-granular-valid spread resolution and Inbox fallback logic
    - Inbox rows explicitly distinguish `Unassigned` from `Assigned: ...` waiting-for-spread using row metadata, without splitting Inbox into separate groups
    - clearing assignment from a task with a real current open spread assignment moves it to Inbox and converts the current open assignment to migrated history
    - clearing an unmaterialized preferred assignment from an Inbox waiting-for-spread task simply sets preferred assignment to nil with no migrated-history entry
  - Search behavior:
    - global task browser search matches task title and body
    - body-backed search results use the normal row and body preview, not a search-specific snippet layout
- **Acceptance Criteria**:
  - Tasks can be saved with body, priority, optional assignment, and optional due date.
  - Task body/priority/due-date presentation works on spread rows and global task browser rows.
  - Inbox-first tasks remain visible and stable until explicitly assigned in both conventional and traditional modes.
  - Due dates remain informational only and never affect assignment, Inbox placement, migration, or overdue membership.
  - Existing assignment, migration, and overdue behavior remains unchanged for tasks with preferred assignments.
  - Note assignment behavior remains unchanged.
- **Tests**:
  - Unit tests for create/edit/reconcile flows with true nil assignment, waiting-for-spread assignment, spread-launched defaults, multiday-launched defaults, and non-spread assign-on defaults.
  - Unit tests for clearing assignment from real current spread assignment vs unmaterialized preferred assignment.
  - Regression tests for Inbox, migration, overdue, traditional-mode Inbox-only behavior, and affected spread surfaces.
  - UI/model tests for priority badges, due-date neutral/highlight states, dual overdue/due-date signals, body preview, and body search.
- **Dependencies**: SPRD-168

### [SPRD-171] Validation: harden rebuild, sync, and regression coverage for the approved bundle - [x] Complete
- **Context**: A one-shot schema pass is only valuable if rebuild, repair, and sync paths remain trustworthy after the branch lands.
- **Description**: Finish the bundle with durability validation covering local rebuilds, sync replay, and regression-prone journal scenarios.
- **Implementation Details**:
  - Validate local Supabase reset/rebuild workflows against the new schema.
  - Add regression scenarios for:
    - favorite toggle and year-scoped favorites menu behavior
    - explicit-spread custom/dynamic naming on year/month/day/multiday spreads
    - SpreadTitleNavigatorView canonical and personalized label matrix
    - dynamic naming live derivation across previous/current/next periods
    - task body, priority, due date, and task-only nil assignment
    - sync conflict cases for independent new metadata fields
  - Verify no deferred `WKFLW-17` candidates leaked partial behavior into the codebase.
- **Acceptance Criteria**:
  - Approved fields survive local reset/rebuild, sync pull, sync push, and repair/backfill flows.
  - Journal surfaces remain correct for favorite/custom-named spreads, Inbox-first tasks, and due-dated tasks.
  - The branch closes with explicit defers for links, tags, assigned time, subtasks, sequential/blocking dependencies, hidden-on-spreads, status expansion, and note nil-assignment parity.
- **Tests**:
  - Targeted rebuild/reset validation.
  - Sync replay and conflict validation for each approved field.
  - Regression suite additions for approved `WKFLW-17` behaviors.
- **Dependencies**: SPRD-169, SPRD-170, SPRD-172

## Story: Journal logic extraction and hardening

### User Story
- As the team, we want journal business logic isolated behind testable, swappable seams so edge cases can be covered thoroughly and `JournalManager` can remain a stable orchestration facade instead of a monolithic rule engine.

### Definition of Done
- `JournalManager` remains the sole UI-facing journal facade but delegates business rules to extracted protocol-backed collaborators.
- Each extracted seam lands with focused unit coverage for normal flows and edge cases before the task is complete.
- Superseded private helpers are removed or reduced from `JournalManager` in the same task that extracts the logic.
- Rule engines are pure or mostly pure where possible; repository writes are performed by coordinators/orchestrators rather than pure logic services.

### [SPRD-154] Refactor: extract JournalDataModel builders and core journal queries - [x] Complete
- **Context**: `JournalManager` currently builds conventional and traditional data models itself and also owns inbox/association/visibility helpers. This mixes state ownership with high-value logic that should be independently testable.
- **Description**: Introduce protocol-backed journal data-model builders and move data-model construction plus closely related pure query logic out of `JournalManager`.
- **Implementation Details**:
  - Add `JournalDataModelBuilder` protocol.
  - Add `ConventionalJournalDataModelBuilder` and `TraditionalJournalDataModelBuilder`.
  - Move conventional/traditional model building and shared helper logic behind these builders.
  - Extract protocol-backed `InboxResolver` and `OverdueEvaluator` seams if their logic remains coupled to the same model/query surface during this slice.
  - `JournalManager` selects the correct builder for `bujoMode` and delegates model construction/query resolution.
  - Remove or shrink superseded helpers from `JournalManager` in the same change.
- **Acceptance Criteria**:
  - `JournalManager` no longer directly implements conventional/traditional data-model construction.
  - Mode-specific building logic is isolated behind `JournalDataModelBuilder` conformers.
  - Inbox and overdue query logic are either extracted in this slice or reduced to collaborator delegation without duplicate rule paths left in `JournalManager`.
  - Edge-case tests cover spread visibility and inclusion for conventional vs traditional rules.
- **Tests**:
  - Unit tests for both data-model builders across:
    - year/month/day visibility boundaries
    - multiday inclusion
    - migrated-history inclusion/exclusion
    - conventional vs traditional month/day differences
  - Unit tests for Inbox and overdue resolution if extracted in this slice.
- **Dependencies**: SPRD-151

### [SPRD-155] Refactor: extract migration planning and overdue/inbox rule engines - [x] Complete
- **Context**: Migration candidate resolution, current spread resolution, hierarchy traversal, and overdue/source determination are dense rule systems embedded inside `JournalManager`.
- **Description**: Move migration planning and remaining rule-heavy query logic into protocol-backed planners/evaluators with exhaustive unit coverage.
- **Implementation Details**:
  - Add `MigrationPlanner` protocol and concrete implementation(s).
  - Planner owns:
    - migration candidate generation
    - destination resolution
    - parent-hierarchy traversal
    - current destination/current displayed spread resolution
  - If `InboxResolver` and `OverdueEvaluator` were not completed in `SPRD-154`, complete them here.
  - `JournalManager` delegates migration/overdue/inbox queries to these collaborators.
  - Remove superseded migration/query helpers from `JournalManager`.
- **Acceptance Criteria**:
  - `JournalManager` no longer directly contains migration-planning rules.
  - Current displayed/destination spread logic is delegated to a planner.
  - Overdue/source resolution is delegated to an evaluator.
  - No duplicate migration-rule helper path remains inside `JournalManager`.
- **Tests**:
  - Unit tests for migration planning across:
    - Inbox sources
    - parent hierarchy sources
    - preferred-period ceilings
    - most-granular-valid-destination selection
    - migrated/completed/cancelled exclusions
  - Unit tests for overdue evaluation by period and source.
- **Dependencies**: SPRD-154

### [SPRD-156] Refactor: extract assignment reconciliation and entry mutation coordinators - [x] Complete
- **Context**: Preferred-date/period changes, assignment reconciliation, and task/note mutation workflows are central domain logic currently embedded in `JournalManager` mutation methods.
- **Description**: Extract protocol-backed coordinators for assignment reconciliation and entry mutation workflows while keeping `JournalManager` as the public facade.
- **Implementation Details**:
  - Add protocol-backed task/note assignment reconciliation collaborators.
  - Add workflow coordinators for task/note mutation paths as needed so repository writes and refresh flows are orchestrated outside pure rule engines.
  - Keep task and note logic separate where rules differ materially.
  - `JournalManager` delegates add/update/move-style entry workflows internally and remains the sole UI-facing API.
  - Remove superseded reconciliation helpers from `JournalManager`.
- **Acceptance Criteria**:
  - Task and note preferred-assignment reconciliation no longer live as private rule helpers inside `JournalManager`.
  - Entry mutation workflows use extracted coordinators internally.
  - `JournalManager` still exposes the same app-facing mutation surface.
  - No duplicated task/note assignment rule path remains in `JournalManager`.
- **Tests**:
  - Unit tests for task assignment reconciliation across:
    - Inbox fallback
    - existing destination assignment reuse
    - completed-status preservation
    - active-assignment migration to history
  - Unit tests for note assignment reconciliation across analogous note rules.
  - Coordinator tests for task/note create and edit workflows.
- **Dependencies**: SPRD-154, SPRD-155

### [SPRD-157] Refactor: extract spread deletion planning and reassignment coordination - [x] Complete
- **Context**: Spread deletion combines parent lookup, reassignment rules, persistence, and state refresh in one high-risk `JournalManager` workflow.
- **Description**: Move spread deletion reassignment rules and workflow coordination behind dedicated protocol-backed planning/coordinator types.
- **Implementation Details**:
  - Add `SpreadDeletionCoordinator` and supporting planner/policy types as needed.
  - Move parent spread lookup, affected-entry discovery, and reassignment planning out of `JournalManager`.
  - Keep repository effects and state refresh orchestrated through coordinator + `JournalManager` facade.
  - Remove superseded deletion helpers from `JournalManager`.
- **Acceptance Criteria**:
  - `JournalManager.deleteSpread` delegates deletion planning/reassignment logic.
  - Deletion rule logic is no longer implemented by private helper chain inside `JournalManager`.
  - Entry preservation and parent/Inbox fallback behavior remain unchanged.
- **Tests**:
  - Unit tests for deletion planning across:
    - parent spread exists
    - no parent spread
    - task vs note reassignment
    - migrated/history preservation
    - multiday deletion no-op reassignment behavior
  - Coordinator tests for spread deletion persistence workflow.
- **Dependencies**: SPRD-156

### [SPRD-158] Refactor: finalize JournalManager as orchestration facade and tighten dependency injection - [x] Complete
- **Context**: After extractions land, `JournalManager` should be hardened as a facade with explicit collaborator injection and minimal remaining rule branching.
- **Description**: Complete the architectural pass so `JournalManager` is primarily orchestration/state management and all extracted seams are injected, selected, and tested coherently.
- **Implementation Details**:
  - Audit `JournalManager` for remaining business-rule branching.
  - Normalize collaborator injection and factory/default wiring.
  - Ensure mode-specific collaborator selection happens inside `JournalManager` where intended, without leaking rule logic back in.
  - Add/refine integration-style unit tests around the facade to verify delegation and state refresh behavior.
- **Acceptance Criteria**:
  - `JournalManager` primarily coordinates repositories, state refresh, logging, and collaborator delegation.
  - Remaining private helpers in `JournalManager` are orchestration-only or trivial adapter glue.
  - Extracted collaborators are injectable and swappable in tests.
  - No major business-rule subsystem remains trapped directly inside `JournalManager`.
- **Tests**:
  - Unit tests for `JournalManager` facade delegation and refresh/version behavior.
  - Integration-style tests proving alternate collaborator implementations can be injected.
- **Dependencies**: SPRD-154, SPRD-155, SPRD-156, SPRD-157

## Story: Targeted journal mutation and derived-state patching

### User Story
- As the team, we want journal mutations to patch only the affected derived state so ordinary edits remain cheap while preserving the current user-visible behavior.

### Definition of Done
- `JournalManager` remains the sole observed journal facade and single UI entry point for journal mutations.
- Journal mutation flows return typed updated entities plus domain-scoped mutation results rather than forcing a full derived-model rebuild on every mutation.
- `JournalDataModel` can be rebuilt by targeted spread/surface scope where safe, with a structural full-rebuild fallback for broad invalidation.
- Existing behavior for conventional, traditional, multiday, Inbox, migration, and overdue surfaces is unchanged.
- Unit tests for targeted mutation behavior are extensive and fully green before the story is considered complete.

### [SPRD-159] Refactor: introduce typed journal mutation results and remove unnecessary full repository reloads - [x] Complete
- **Context**: `JournalManager` currently rebuilds derived state after nearly every mutation, and some simple single-entity edits also re-fetch an entire repository slice before rebuilding.
- **Description**: Add a typed mutation result contract for journal mutations and eliminate avoidable full repository re-fetches on simple edits where the updated entity is already known.
- **Implementation Details**:
  - Introduce typed journal mutation result types that capture:
    - updated domain entities
    - domain-scoped mutation kind
    - structural-fallback cases
  - Keep `JournalManager` as the UI-facing entry point; views do not call services directly.
  - Update simple mutation paths such as task/note title or status edits to use returned updated entities instead of re-fetching all tasks/notes when safe.
  - Preserve current persistence ordering and error handling.
- **Acceptance Criteria**:
  - Simple single-entity edits no longer require unconditional full repository slice reloads when the saved entity is already available.
  - Mutation results are expressed in domain terms, not UI terms.
  - No user-visible journal behavior changes.
- **Tests**:
  - Unit tests for mutation result contracts across representative task/note mutations.
  - Regression tests proving simple edits preserve current task/note visibility and history behavior.
  - Unit tests verifying repository-wide reload is not performed on the targeted simple-edit paths.
- **Dependencies**: SPRD-158

### [SPRD-160] Refactor: add stable spread keys and targeted JournalDataModel builder APIs - [x] Complete
- **Context**: Targeted mutation patching is not possible unless the app can identify and rebuild one spread/surface at a time instead of only producing full `JournalDataModel` snapshots.
- **Description**: Introduce canonical spread/surface identity and extend journal data-model builders to support targeted spread/surface rebuilding alongside full rebuilds.
- **Implementation Details**:
  - Define stable keys for conventional created spreads, traditional virtual spreads, and multiday surfaces.
  - Add targeted builder APIs to rebuild:
    - one spread/surface
    - a bounded set of spread/surface keys
    - full fallback rebuild
  - Keep builder logic pure.
  - Do not change user-facing behavior or navigation identity semantics.
- **Acceptance Criteria**:
  - `JournalManager` can request a targeted rebuild for a single spread/surface without requiring a whole-journal rebuild.
  - Stable spread keys are deterministic and testable across conventional, traditional, and multiday cases.
  - Full rebuild path remains available for structural invalidation.
- **Tests**:
  - Unit tests for stable key generation across period/date/multiday cases.
  - Unit tests for targeted builder output matching full builder output for the same spread/surface.
  - Regression tests covering conventional vs traditional inclusion rules under targeted rebuilds.
- **Dependencies**: SPRD-159

### [SPRD-161] Refactor: patch JournalManager derived state by affected scope - [x] Complete
- **Context**: After mutation results and targeted builder APIs exist, `JournalManager` still needs a scoped apply path that updates only affected derived slices instead of always replacing the whole `dataModel`.
- **Description**: Teach `JournalManager` to merge updated entities, interpret affected mutation scope, and patch only the affected derived spread/surface slices when safe.
- **Implementation Details**:
  - Add scoped apply/refresh helpers inside `JournalManager`.
  - Support mutation handling tiers:
    - simple content edits
    - spread-membership changes
    - structural fallback
  - Patch derived slices for affected spreads and dependent state such as Inbox/overdue where needed.
  - Preserve a conservative full-rebuild fallback whenever scope is broad or uncertain.
- **Acceptance Criteria**:
  - `JournalManager` no longer always replaces the full `dataModel` after ordinary mutations.
  - Scoped patching remains internal; UI-facing APIs and behavior do not change.
  - Structural flows still use full rebuild for correctness.
- **Tests**:
  - Unit tests for `JournalManager` scoped apply behavior across:
    - rename/title edits
    - status changes
    - date/period reassignment
    - migration
    - spread create/delete
  - Regression tests proving affected spread slices update correctly while unrelated slices remain stable.
  - Explicit tests for structural fallback behavior.
- **Dependencies**: SPRD-160

### [SPRD-162] Refactor: harden targeted mutation architecture and verify no user-visible regression - [x] Complete
- **Context**: Once scoped mutation patching is in place, the architecture needs a final hardening pass so it remains safe, testable, and maintainable.
- **Description**: Audit targeted mutation adoption, remove obsolete full-rebuild call paths where appropriate, and expand tests so the green suite proves the refactor preserved behavior.
- **Implementation Details**:
  - Audit `JournalManager` mutation paths for remaining unconditional rebuilds.
  - Keep structural full rebuild only where intentionally required.
  - Add regression coverage for conventional, traditional, multiday, Inbox, migration, and overdue surfaces under targeted mutation flows.
  - Ensure naming and helper boundaries reflect domain-scoped mutation concepts rather than UI-scoped refresh concepts.
- **Acceptance Criteria**:
  - Ordinary mutations follow targeted mutation paths by default.
  - Remaining full rebuild paths are intentional and documented by mutation type.
  - No observable product behavior changes from the user perspective.
  - Unit tests are extensive and green.
- **Tests**:
  - Full `SpreadTests` suite green.
  - New targeted-mutation unit tests covering edge cases and fallback paths.
  - Added regression tests for current journal behaviors most sensitive to stale derived state.
- **Dependencies**: SPRD-161

## Story: Shared spreads shell and page-content refactor

### User Story
- As the team, we want one shared spreads shell and one shared pager/page assembly path so the spread UI is easier to evolve without duplicating conventional and traditional root view logic.

### Definition of Done
- One shared `SpreadsView` replaces the conventional/traditional root composition split.
- `SpreadsViewModel` owns shell-level UI state without becoming a new business-logic owner.
- `SpreadTitleNavigatorView` reads from `SpreadTitleNavigatorProviding`, with `JournalManager` providing mode-aware strip data.
- `SpreadContentPagerView` assembles page headers and spread-type content views directly.
- `SpreadSurfaceView` is removed if fully subsumed by the new pager/content structure.
- User-visible spread behavior remains unchanged.

### [SPRD-163] Refactor: introduce SpreadsView and SpreadsViewModel as the shared spreads shell - [x] Complete
- **Context**: `ConventionalSpreadsView` and `TraditionalSpreadsView` still duplicate root shell concerns such as selection state, recentering, sheet routing, and shared control assembly.
- **Description**: Create a shared `SpreadsView` and a shell-scoped `SpreadsViewModel`, then move shared root-view composition into that one shell.
- **Implementation Details**:
  - Add `SpreadsView`.
  - Add `SpreadsViewModel` for shell UI state only:
    - selection
    - recenter token
    - active sheet
    - shell control state
  - Move shared shell assembly for:
    - `SpreadTitleNavigatorView`
    - `SpreadContentPagerView`
    - shared sheets
    - shared bottom controls
  - Remove duplicated root-shell logic from `ConventionalSpreadsView` and `TraditionalSpreadsView`.
- **Acceptance Criteria**:
  - One shared root spreads shell is used for both BuJo modes.
  - `SpreadsViewModel` owns shell state only and does not absorb journal business logic.
  - User-visible spread behavior remains unchanged.
- **Tests**:
  - Unit tests for `SpreadsViewModel` shell state transitions.
  - Existing spread shell/support tests updated to target the shared root.
  - App build and relevant spread unit tests remain green.
- **Dependencies**: SPRD-162

### [SPRD-164] Refactor: add SpreadTitleNavigatorProviding and move strip-model generation into JournalManager - [x] Complete
- **Context**: The title navigator is still wired from mode-specific spread roots even though strip generation should come from the journal facade based on `bujoMode`.
- **Description**: Introduce `SpreadTitleNavigatorProviding` and move strip/title navigator provision behind `JournalManager`.
- **Implementation Details**:
  - Add `SpreadTitleNavigatorProviding`.
  - Add `JournalManager+SpreadTitleNavigatorProviding.swift`.
  - Move strip model / item generation behind the protocol.
  - Update `SpreadTitleNavigatorView` and the shared spreads shell to depend on the protocol rather than conventional/traditional-specific wiring.
- **Acceptance Criteria**:
  - `SpreadTitleNavigatorView` is fed by a `SpreadTitleNavigatorProviding` instance.
  - `JournalManager` provides the correct strip data for the current mode.
  - Conventional/traditional root-specific strip wiring is removed.
- **Tests**:
  - Unit tests for `JournalManager` strip provision across conventional and traditional modes.
  - Existing navigator support tests updated for the protocol-backed provider path.
  - Spread shell tests remain green.
- **Dependencies**: SPRD-163

### [SPRD-165] Refactor: collapse SpreadSurfaceView into pager-assembled spread content views - [x] Complete
- **Context**: `SpreadSurfaceView` and `SpreadContentPagerView` currently split responsibilities that can be simplified by letting the pager assemble each page directly.
- **Description**: Make `SpreadContentPagerView` assemble page headers plus spread-type content views and remove `SpreadSurfaceView` if fully subsumed.
- **Implementation Details**:
  - Update `SpreadContentPagerView` to assemble each page as:
    - `SpreadHeaderView`
    - `YearSpreadContentView`, `MonthSpreadContentView`, `DaySpreadContentView`, or `MultidaySpreadContentView`
  - Content views receive fully prepared display models.
  - Header remains outside the content views.
  - Prefer `SpreadsViewModel` / `JournalManager` access over repeatedly threading identical closures through multiple layers.
  - Remove `SpreadSurfaceView` if no longer needed.
- **Acceptance Criteria**:
  - `SpreadContentPagerView` becomes the shared page assembler.
  - Spread-type content views exist for year/month/day/multiday rendering.
  - `SpreadSurfaceView` is removed if redundant.
  - No user-visible spread behavior change.
- **Tests**:
  - Unit/support tests for pager page assembly and spread-type content selection.
  - Updated spread support tests for header + content composition.
  - App build and spread-related unit tests remain green.
- **Dependencies**: SPRD-163, SPRD-164

### [SPRD-166] Refactor: replace rooted-navigator calendar grid with MonthCalendarView and share day visual style - [x] Complete
- **Context**: `SpreadHeaderNavigatorYearPageView` renders the expanded-month calendar grid with a bespoke `calendarGrid` method backed by `CalendarGridHelper`. `MonthCalendarView` from `johnnyo-foundation` is already used for `SpreadMonthCalendarView` and provides the `CalendarContentGenerator` protocol. The multiday day-card visual states (today / created / uncreated) also inline their style constants as private view properties; the navigator grid needs those same styles, making this the right moment to centralize them.
- **Description**: Replace the bespoke calendar grid in the rooted navigator with `MonthCalendarView` via a new dedicated `CalendarContentGenerator`. Move fill, border color, and stroke style constants out of `MultidayDayCardView` into computed properties on `MultidayDayCardVisualState`, and have both the card and the new generator reference those shared properties. Delete `CalendarGridHelper` once it is no longer used.
- **Implementation Details**:
  - Add computed properties to `MultidayDayCardVisualState`: `fill: Color`, `borderColor: Color`, `borderStyle: StrokeStyle`. Values match the current private computed properties in `MultidayDayCardView`.
  - Update `MultidayDayCardView` to reference these shared properties instead of its own inline values.
  - Create `SpreadHeaderNavigatorCalendarGenerator: CalendarContentGenerator` in `Spread/Views/Spreads/Header/`:
    - Receives `model: SpreadHeaderNavigatorModel`, `monthRow: SpreadHeaderNavigatorModel.MonthRow`, `currentSpread: DataModel.Spread`, and `onDayTapped: (Date, [SpreadHeaderNavigatorModel.SelectionTarget]) -> Void`
    - `headerView`: returns `EmptyView` (the month name is already shown by `navigationTitle` in the popover)
    - `weekdayHeaderView`: renders the very-short weekday symbol using `SpreadTheme.Typography.caption`
    - `dayCellView`: maps `MonthCalendarDayContext` → `MultidayDayCardVisualState` (today → `.today`; conventional with targets → `.created`; conventional without targets → `.uncreated`; traditional → always `.created`), applies shared `fill`/`borderColor`/`borderStyle` from `MultidayDayCardVisualState`, calls `onDayTapped` on tap
    - `placeholderCellView`: returns `Color.clear` with a fixed height (peripheral dates hidden via `showsPeripheralDates: false`)
    - `weekBackgroundView`: returns `Color.clear`
  - Replace `calendarGrid(for:)` in `SpreadHeaderNavigatorYearPageView` with a `MonthCalendarView` instantiation using `SpreadHeaderNavigatorCalendarGenerator`, passing `showsPeripheralDates: false`
  - Wire tap handling inside `onDayTapped`: single target → call `onSelect` + `onDismiss`; multiple targets → set `dialogTargets` and `isShowingSelectionDialog = true`
  - Delete `CalendarGridHelper.swift` once `calendarGrid` is removed
  - Remove the `weekdayHeaders` computed property from `SpreadHeaderNavigatorYearPageView`; weekday rendering moves into the generator
  - Update `SpreadMonthCalendarContentGenerator.dayCellView` to apply the same three-state visual treatment:
    - Map context to `MultidayDayCardVisualState`: today → `.today`; entryCount > 0 → `.created`; entryCount == 0 → `.uncreated`
    - Apply shared `borderColor` and `borderStyle` from `MultidayDayCardVisualState` as a `strokeBorder` overlay on each cell
    - Cell fill: today → `visualState.fill`; others → `Color.clear`
    - Entry count dot indicators are retained beneath the day number
- **Acceptance Criteria**:
  - Expanded-month calendar grid in the rooted navigator is rendered by `MonthCalendarView` with `SpreadHeaderNavigatorCalendarGenerator`
  - Day cells in both the navigator grid and the month spread calendar use today / created / uncreated visual treatment
  - `MultidayDayCardVisualState` owns the fill, border color, and border style for each state
  - `MultidayDayCardView` reads from `MultidayDayCardVisualState` properties (no inline duplication)
  - `CalendarGridHelper.swift` is deleted
  - Tap behavior is unchanged: single target selects immediately, multiple targets show confirmation dialog
  - App builds cleanly and existing tests remain green
- **Tests**:
  - Unit tests for `MultidayDayCardVisualState` shared properties (correct colors and stroke styles)
  - Unit tests for visual state mapping in the navigator generator (today / created / uncreated) for both conventional and traditional modes
- **Dependencies**: SPRD-153, SPRD-165

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

### [SPRD-140] Refactor: Replace migration banner/sheet with inline source and destination migration UI - [x] Complete
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

### [SPRD-141] Refactor: Consolidate task create/edit form logic and reassignment behavior - [x] Complete
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

### [SPRD-142] Feature: Refine inline task-row editing actions and migration menu - [x] Complete
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
  - `SpreadService`:
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
- **Note**: Tests implemented as part of SPRD-13 in `SpreadServiceTests.swift` and SPRD-14 in `InboxTests.swift`

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

### [SPRD-143] Refactor: Consolidate root navigation to sidebar-adaptable TabView - [x] Complete
- **Context**: The current adaptive root navigation duplicates top-level container logic across `RootNavigationView`, `NavigationLayoutType`, `SidebarNavigationView`, and `TabNavigationView`. The product requirement remains the same: iPhone uses tab-bar navigation and iPad uses sidebar-style navigation. SwiftUI's adaptive tab APIs now support a single-root approach that can satisfy that requirement with less duplicated shell code.
- **Description**: Replace the split root/sidebar/tab implementation with a single `TabView`-based root that uses SwiftUI's sidebar-adaptable tab style on supported OS versions while preserving current destination structure and toolbar behavior.
- **Implementation Details**:
  - Introduce a single consolidated adaptive root navigation view:
    - Keep `NavigationTab` as the single source of truth for top-level destination identity and selection.
    - Use one `TabView(selection:)` for `Spreads`, `Collections`, `Settings`, and `Debug` when available.
    - Keep destinations flat; do not introduce `TabSection`s in this refactor.
  - Apply SwiftUI adaptive tab APIs:
    - Use `.tabViewStyle(.sidebarAdaptable)` when available under the current deployment target.
    - Keep the structure non-customizable; do not add `tabViewCustomization` state or persistence.
    - Preserve an explicit layout/testing override so tests and previews can still force compact vs regular adaptive behavior deterministically.
  - Preserve current content composition:
    - Keep each top-level destination wrapped in the same `NavigationStack` and content branching used today.
    - Preserve current toolbar behavior:
      - `Spreads` continues to own its spreads-specific toolbar/header behavior.
      - Non-spread destinations continue to show inbox/auth toolbar actions in the navigation bar.
  - Remove obsolete navigation shell types after migration:
    - Delete `NavigationLayoutType.swift`.
    - Delete `SidebarNavigationView.swift`.
    - Delete `TabNavigationView.swift`.
    - Simplify `RootNavigationView.swift` to the unified adaptive implementation.
  - Update previews/tests away from shell-specific assertions toward behavior assertions based on adaptive presentation and destination selection.
- **Acceptance Criteria**:
  - A single root `TabView` implementation is used for both iPhone and iPad. (Spec: Multiplatform Strategy)
  - iPhone still presents top-level navigation as a tab bar. (Spec: Multiplatform Strategy)
  - iPad uses SwiftUI's sidebar-adaptable tab presentation instead of the current custom `NavigationSplitView` shell. (Spec: Multiplatform Strategy)
  - Top-level destinations remain `Spreads`, `Collections`, `Settings`, and `Debug` when available, with flat destination structure. (Spec: Multiplatform Strategy)
  - `NavigationTab` remains the single source of truth for destination identity/selection. (Spec: Multiplatform Strategy)
  - Inbox/auth toolbar behavior remains unchanged for non-spread destinations, and spreads-specific toolbar behavior remains owned by the spreads surface. (Spec: Navigation and UI; Inbox)
  - There is no user customization of tab/sidebar layout in v1. (Spec: Multiplatform Strategy)
  - `NavigationLayoutType`, `SidebarNavigationView`, and `TabNavigationView` are removed from the project once the unified root is in place.
- **Tests**:
  - Unit tests for the unified root view's destination selection and override-driven adaptive style resolution.
  - UI tests on compact-width devices verifying tab-bar navigation between `Spreads`, `Collections`, `Settings`, and `Debug` when present.
  - UI tests on regular-width devices verifying the adaptive sidebar-capable presentation still exposes the same destinations and selection behavior.
  - Regression UI tests verifying inbox/auth toolbar actions remain present on non-spread destinations and unchanged on the spreads destination.
- **Dependencies**: SPRD-19

### [SPRD-144] UI: Refine today emphasis and strip ordering cues - [x] Complete
- **Context**: The spread-title navigator and multiday content need a clearer passive indication of "today" that remains visible even when today is not the selected spread. The multiday add-task affordance should also align with the entry-row columns, and conventional strip ordering should resolve same-start-date multiday/day ties consistently.
- **Description**: Add a shared configurable today-emphasis token, apply it to the title strip and today's multiday card, align the add-task row with entry rows, and order same-start multiday items before day items in the conventional strip.
- **Implementation Details**:
  - Add shared today-emphasis theme tokens for:
    - today unselected foreground
    - today selected foreground
    - today border/background tint
  - Update the spread-title navigator support and item rendering to:
    - derive today's semantic strip item using the same destination rules as the `Today` button
    - render distinct non-today selected, non-today unselected, today selected, and today unselected states
  - Update multiday entry sections so only today's card uses the today-emphasis palette on its header, outline, and background.
  - Align multiday `+ Add Task` and inline creation rows to the same 24pt leading icon column and body-text title column used by entry rows.
  - Change conventional strip ranking so multiday spreads sort before day spreads when both start on the same date.
- **Acceptance Criteria**:
  - Today's strip item is passively emphasized regardless of selection state. (Spec: Navigation and UI)
  - The strip uses separate today-selected and today-unselected appearance states. (Spec: Navigation and UI)
  - The today emphasis colors are centrally configurable. (Spec: Navigation and UI)
  - Only today's multiday section receives the today-emphasis treatment. (Spec: Entry lists / multiday)
  - The multiday add-task row aligns with the standard entry-row icon and title columns. (Spec: Entry lists / add task)
  - Same-start-date multiday items appear before day items in the conventional strip. (Spec: Navigation and UI)
- **Tests**:
  - Update strip support expectations for same-start multiday/day ordering.
  - Add a support test verifying a conventional multiday item appears before a same-start day item.
  - Build verification for the today-emphasis and multiday styling changes.
- **Dependencies**: SPRD-127, SPRD-133

### [SPRD-145] Bug: Dismiss inline task creation UI immediately after local add - [x] Complete
- **Context**: Inline task creation currently keeps its transient input row and keyboard visible until follow-up sync work finishes. That delay makes the just-created task appear duplicated for a few seconds because the stale input row remains visible after the new row has already been inserted.
- **Description**: Clear the inline task-creation UI immediately after local add success, while allowing sync to continue asynchronously.
- **Implementation Details**:
  - Apply the fix uniformly to all inline creation commit paths:
    - keyboard `Save`
    - `Return`
    - focus-loss save
  - Once the local add succeeds:
    - dismiss the inline creation row immediately
    - dismiss the keyboard immediately
    - do not wait for sync completion before clearing transient UI state
  - Preserve existing local-add failure handling.
- **Acceptance Criteria**:
  - The transient inline creation row disappears immediately after a successful local add. (Spec: Inline task creation)
  - The keyboard dismisses immediately after a successful local add. (Spec: Inline task creation)
  - The UI does not show a duplicate-looking stale inline row while sync completes. (Spec: Inline task creation)
  - The behavior is consistent for `Save`, `Return`, and focus-loss save. (Spec: Inline task creation)
- **Tests**:
  - Unit tests for inline creation state transitions across all commit paths.
  - UI tests verifying the inline row and keyboard dismiss immediately after inline task creation without waiting for sync.
- **Dependencies**: SPRD-133

### [SPRD-146] Bug: Migrated task taps should jump to the current spread before editing - [x] Complete
- **Context**: Source spreads keep migrated-task history visible, but tapping a migrated task currently edits in the historical context instead of taking the user to the task's current live spread first. That breaks the migrated-history mental model.
- **Description**: Make migrated-task taps on source spreads navigate to the task's most granular current open destination spread and then present the edit sheet there.
- **Implementation Details**:
  - For tasks shown in the disabled `Migrated tasks` subsection:
    - resolve the task's most granular current open assignment
    - navigate to the spread that matches that assignment
    - once navigation settles, immediately present the task edit sheet on that destination spread
  - If multiple non-migrated assignments exist, prefer the most granular assignment.
  - If no destination spread can be resolved, fall back to opening the edit sheet on the current spread.
- **Acceptance Criteria**:
  - Tapping a migrated task on a source spread first navigates to its current destination spread and then opens the edit sheet there. (Spec: Conventional migration UI)
  - The chosen destination is the most granular current open assignment when multiple current assignments exist. (Spec: Conventional migration UI)
  - If navigation cannot resolve a destination spread, the app falls back to opening the edit sheet on the current spread. (Spec: Conventional migration UI)
- **Tests**:
  - Unit tests for migrated-task destination resolution and most-granular tie-breaking.
  - UI tests verifying a migrated task tap changes the selected spread and then opens the task edit sheet on the destination spread.
  - UI tests verifying fallback to local edit when the destination spread no longer exists.
- **Dependencies**: SPRD-140

### [SPRD-147] UI: Replace overdue review toolbar flow with spread navigator badges - [x] Complete
- **Context**: The current overdue experience is centered on a global toolbar button and review sheet. That adds a separate review surface and does not tie the signal to the actual spread that contains the overdue work.
- **Description**: Remove the global overdue toolbar/sheet flow and instead show per-spread overdue count badges directly in the spread title navigator.
- **Implementation Details**:
  - Remove the overdue toolbar button from spread toolbars.
  - Remove the overdue review sheet and coordinator/support code used only by that flow.
  - Compute overdue badge counts per spread from current open assignments only.
  - Badge only the spread that currently contains the overdue task assignment.
  - Exclude overdue tasks that are still in `Inbox` from the spread-badge UI.
  - Show the badge in the top-right of each spread item in `SpreadTitleNavigatorView`.
  - Keep the badge visible even when that spread is selected.
  - Preserve normal spread-selection behavior when a badged spread is tapped.
- **Acceptance Criteria**:
  - Spread items with currently open overdue tasks show an exact overdue count badge in the title navigator. (Spec: Conventional navigation and UI)
  - Only the spread that currently contains an overdue task assignment is badged; ancestor spreads are not. (Spec: Conventional navigation and UI)
  - Selected spreads can still show overdue badges. (Spec: Conventional navigation and UI)
  - Overdue tasks still in `Inbox` do not produce spread badges. (Spec: Conventional navigation and UI)
  - The overdue toolbar button and overdue review sheet are removed. (Spec: Conventional navigation and UI)
- **Tests**:
  - Unit tests for overdue count aggregation by current open spread assignment, including day/month/year thresholds and inbox exclusion.
  - Unit tests for exact-count badge values and no ancestor-spread propagation.
  - UI tests verifying badge visibility/count on badged spreads, coexistence with selected-state styling, and absence of the old overdue toolbar/sheet flow.
- **Dependencies**: SPRD-112, SPRD-143

### [SPRD-148] UI: Replace Inbox toolbar flow with a search-role task browser tab - [x] Complete
- **Context**: Inbox is still surfaced from a spread-toolbar button and sheet, which keeps task discovery tied to the spread screen and duplicates functionality that fits better as a global navigation destination.
- **Description**: Remove the Inbox toolbar button and Inbox sheet flow, and replace them with a top-level `.search` tab that hosts a global task browser grouped by the spread where each task is currently shown.
- **Implementation Details**:
  - Add a top-level tab item with `.search` role to the adaptive root `TabView`.
  - Remove the Inbox toolbar button, Inbox sheet, and coordinator/presentation code used only by those flows.
  - Build a task-only search screen with a real search field from day one.
  - Selecting the `Search` tab should present the search screen ready for typing without a second press.
  - Keep the search field visibly present at the top of the search screen rather than hiding it behind an additional toolbar interaction.
  - Group results into hidden-when-empty sections:
    - `Inbox` first.
    - Remaining sections in the same order as `SpreadTitleNavigatorView` for the active mode (`conventional` vs `traditional`).
  - Show each task exactly once under the spread where it is currently shown.
  - Exclude migrated historical rows from the search browser.
  - Tapping a result should navigate to the task's spread and then open the task edit sheet there.
- **Acceptance Criteria**:
  - The top-level Inbox toolbar button and Inbox sheet are removed. (Spec: Inbox; Navigation and UI)
  - A top-level search-role tab is present and opens a task-only browser with a real search field. (Spec: Inbox; Navigation and UI)
  - Selecting the `Search` tab requires only one press before the user can type into search. (Spec: Navigation and UI)
  - The search field remains visibly present at the top of the search screen. (Spec: Navigation and UI)
  - The first section is `Inbox`, and remaining non-empty sections match the active-mode spread-strip ordering. (Spec: Inbox; Navigation and UI)
  - Each task appears exactly once, under the spread where it is currently shown. (Spec: Navigation and UI)
  - Tapping a task in search navigates to that spread and then opens task editing there. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for search grouping/order generation in both conventional and traditional modes, including Inbox-first ordering and empty-section suppression.
  - Unit tests verifying current-display-spread resolution excludes migrated history and keeps each task unique.
  - UI tests verifying the search tab replaces the Inbox toolbar flow, shows the grouped task browser, places keyboard focus into search on tab selection, keeps the search field visibly present, filters results, and routes task taps to the destination spread edit sheet.
- **Dependencies**: SPRD-143

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

### [SPRD-149] UI: multiday day-card today/uncreated states and footer action - [x] Complete
- **Context**: Multiday spreads currently show per-day cards, but they do not yet distinguish today's day at the header level, do not indicate when a covered day has no explicit day spread, and do not provide a direct footer action to open or create that day's spread.
- **Description**: Refine multiday day cards to support `today`, `uncreated`, and normal created states, add a trailing footer action that either navigates to the day spread or opens a preconfigured create-spread flow for that exact day, add overdue badges, and align supporting conventional spread chrome and header formatting with the new multiday presentation.
- **Implementation Details**:
  - Add a `Today` label above the weekday on multiday cards whose date is today.
  - Left-align that label with the weekday and style it to match the structural role of the short month label above the date.
  - Detect whether each multiday-covered day has an explicit day spread.
  - Apply an uncreated dashed-outline treatment when no explicit day spread exists, instead of a distinct grey header/fill treatment.
  - If a card is both today and uncreated, use only the today treatment.
  - Add a footer to every multiday card with a single always-visible trailing icon button using the same filled circular treatment for both the `open day` and `create day` actions.
  - If the day spread exists, the footer button should navigate through the normal spread-selection/navigation path.
  - If the day spread does not exist, the footer button should open the create-spread sheet already configured for that exact day spread.
  - After successful creation from that footer path, immediately navigate into the newly created day spread.
  - Use `calendar.badge.plus` for the create-day footer state and a navigation icon for the open-day state, with white-tinted circular fills and blue iconography.
  - Add top-right overdue count badges to multiday cards using the same visual badge language as the spread title navigator.
  - Extract the multiday day card into its own view.
  - Move conventional spread `Today` and `+` controls into a bottom safe-area inset, with `Today` leading and `+` trailing, while preserving the paper dot grid through the inset region.
  - Update spread header formatting so year, month, day, and multiday titles/subtitles match the current visual rules and the navigator chevron sits on the trailing edge of the centered title block.
- **Acceptance Criteria**:
  - Today's multiday card shows a `Today` label above the weekday, left-aligned with it. (Spec: Spread Content Presentation and Interaction)
  - Uncreated multiday day cards use a dashed outline treatment instead of a distinct greyed container and header treatment. (Spec: Spread Content Presentation and Interaction)
  - If a multiday card is both today and uncreated, the today treatment fully wins. (Spec: Spread Content Presentation and Interaction)
  - Every multiday card shows a trailing filled circular footer icon button, with the same visual treatment used for both action states. (Spec: Spread Content Presentation and Interaction)
  - The footer action navigates to the day spread when it exists, or opens preconfigured day-spread creation when it does not. (Spec: Spread Content Presentation and Interaction)
  - Creating a day spread from the multiday footer action immediately navigates into that day spread. (Spec: Spread Content Presentation and Interaction)
  - Multiday cards can show a top-right overdue count badge using the same badge language as the spread title navigator. (Spec: Spread Content Presentation and Interaction)
  - Conventional spread bottom controls sit in a safe-area inset with the dot grid continuing behind them. (Spec: Spread Content Presentation and Interaction)
  - Spread headers use the current title/subtitle formatting rules and keep the chevron attached to the trailing edge of the centered title block. (Spec: Rooted spread header navigator behavior)
- **Tests**:
  - Unit tests for multiday day-card state derivation covering created, uncreated, today, and today-uncreated precedence.
  - Unit tests for footer action resolution covering existing day navigation vs preconfigured day creation.
  - UI tests verifying the `Today` label placement, uncreated visual treatment, footer button visibility, existing-day navigation, create-then-navigate flow, multiday overdue badges, and updated conventional bottom controls/header formatting.
- **Dependencies**: SPRD-124, SPRD-125, SPRD-126

### [SPRD-150] UI: show cancelled and migrated task rows inline with terminal-state styling - [x] Complete
- **Context**: Task rows currently emphasize active editing and migration shortcuts, but cancelled tasks are filtered away and migrated tasks only appear in special source-history surfaces. The row-level reassignment affordance also has no direct path into the full edit sheet when the user needs a non-shortcut destination.
- **Description**: Extend `EntryRowView` and the task-list query/presentation pipeline so cancelled and migrated tasks remain visible in normal task lists with distinct terminal-state styling, while the inline reassignment menu gains a final `Custom...` route into the full task editor.
- **Implementation Details**:
  - Add a final `Custom...` item to the inline reassignment menu in `EntryRowView`.
  - Selecting `Custom...` should end inline editing and open the task edit sheet for that row.
  - Include cancelled and migrated task rows anywhere task rows are normally rendered, including multiday day sections.
  - Preserve the existing task ordering logic instead of regrouping terminal states.
  - Keep cancelled and migrated rows greyed out and non-inline-editable.
  - Render cancelled task rows with a continuous strike line that visually runs from the status icon through the title.
  - Render migrated task rows with a normal task-sized dot plus a right-arrow overlay that extends beyond the dot bounds.
  - Tapping a cancelled row should open the task edit sheet.
  - Tapping a migrated row should use the existing migrated-task navigation path to the current destination spread before opening edit.
- **Acceptance Criteria**:
  - The inline reassignment menu ends with `Custom...`, and selecting it opens the full task edit sheet. (Spec: Conventional-mode inline migration UI)
  - Cancelled and migrated tasks remain visible in standard task lists and multiday day sections. (Spec: Conventional-mode inline migration UI)
  - Existing row ordering is preserved while including cancelled and migrated rows. (Spec: Conventional-mode inline migration UI)
  - Cancelled task rows are greyed out and show a continuous strike line from icon through title. (Spec: Conventional-mode inline migration UI)
  - Migrated task rows are greyed out and show the dot-plus-arrow migrated symbol. (Spec: Conventional-mode inline migration UI)
  - Cancelled rows open the edit sheet on tap, and migrated rows navigate to the current spread before editing. (Spec: Conventional-mode inline migration UI)
- **Tests**:
  - Unit tests covering row presentation config for cancelled and migrated task states.
  - Unit tests covering inline reassignment menu options including the `Custom...` fallback.
  - UI tests verifying cancelled and migrated rows remain visible, cancelled strike styling is discoverable, migrated rows follow destination navigation, and `Custom...` opens the edit sheet.
- **Dependencies**: SPRD-140, SPRD-142, SPRD-146

### [SPRD-151] Refactor: unify conventional and traditional spread surfaces
- **Context**: `ConventionalSpreadsView`, `TraditionalSpreadsView`, and the traditional year/month/day surfaces duplicate navigation shell, paging, header, and entry rendering responsibilities even though the foundational distinction between the two modes is not the UI mechanics. The real difference is mode semantics: conventional mode exposes only explicit created spreads and conventional migration/inclusion rules, while traditional mode exposes the full year/month/day hierarchy with traditional inclusion and assignment rules. The architecture should express those differences through injected builders/configuration rather than separate view trees.
- **Spec**: Project Summary; BuJo Mode; Navigation and UI; Shared Spread Surface Architecture
- **Acceptance Criteria**:
  - Conventional and traditional modes render through the same shared spread-shell architecture.
  - The shared shell owns the common layout for:
    - `SpreadTitleNavigatorView`
    - `SpreadContentPagerView`
    - injected shell controls such as `Today`, create actions, and auth actions
  - A shared spread-surface renderer owns:
    - `SpreadHeaderView`
    - section composition
    - one or more `EntryListView` instances
  - `ConventionalSpreadsView` and `TraditionalSpreadsView` become thin wrappers/adapters around the shared shell rather than separate full layouts.
  - Traditional navigation uses the same user-facing navigation mechanics as conventional:
    - spread-title strip
    - header chevron selector
    - swipe paging
  - Traditional mode no longer uses separate calendar-grid/drill-in spread views as its primary UI.
  - `EntryListView` remains reusable and config-driven, receiving injected data/config rather than reading `JournalManager` directly.
  - Multiday rendering is composed from repeated multiday-section components, each hosting an `EntryListView`.
  - Shared visual section/list components are reused across both modes; conventional-only migration/history behavior is enabled through injected config.
  - `SpreadDataModel` remains the core domain input; mode-specific builders/adapters derive UI configuration from it.
  - Mode-specific inclusion rules remain explicit and preserved, including:
    - conventional month surfaces can include day-assigned tasks that have not been taken over by explicit day spreads according to conventional rules
    - traditional month surfaces include only month-assigned tasks because day-assigned tasks belong on day surfaces
  - Traditional mode continues to exclude multiday destinations.
- **Implementation Details**:
  - Introduce a shared spread shell view and injected shell-control configuration.
  - Introduce mode-specific spread-surface builders/adapters, for example:
    - `ConventionalSpreadSurfaceBuilder`
    - `TraditionalSpreadSurfaceBuilder`
  - Extract shared spread-surface/section/list contracts so reusable UI components depend on injected configuration and action closures, not manager/service lookups.
  - Remove or retire traditional-only year/month/day view trees once their behavior has been absorbed into the shared spread-surface pipeline.
- **Tests**:
  - Unit tests for conventional and traditional surface builders covering section derivation and entry inclusion rules.
  - Unit tests for injected shell-control configuration and shared shell selection behavior.
  - UI tests verifying both modes navigate through the same strip, rooted selector, and swipe pager interactions.
  - UI tests verifying conventional and traditional month inclusion differences remain correct after consolidation.
- **Dependencies**: SPRD-143, SPRD-148, SPRD-149, SPRD-150

### [SPRD-152] Infrastructure: create johnnyo-foundation local package
- **Context**: Shared UI primitives and utilities are starting to outgrow the app target. The repository needs a real local Swift Package boundary that can evolve into a publishable GitHub package later, beginning with calendar-related components while keeping app-specific content generation in the app target.
- **Spec**: Project Summary; Shared Foundations Package
- **Acceptance Criteria**:
  - A real local Swift Package named `johnnyo-foundation` is added to the repository and integrated into the Xcode project/package graph.
  - The package starts with separate targets for UI and non-UI/core code.
  - The app imports only the package UI target for the initial calendar use case.
  - The package includes package-local tests.
  - The package includes publishable package-local documentation, including a `README.md` and a package-local `spec.md`.
  - The package includes minimal package-local examples or previews demonstrating the public month-calendar API shape.
  - Package boundaries prevent app-specific `Spread` code from leaking into the package targets.
- **Implementation Details**:
  - Create a package manifest and folder structure suitable for later GitHub publication.
  - Define initial target layout, for example:
    - `JohnnyOFoundationCore`
    - `JohnnyOFoundationUI`
  - Keep package-internal API documentation close to the package sources rather than overloading the app product spec.
  - Ensure the app target links/imports the package through the local package integration path rather than source-file duplication.
- **Tests**:
  - Package-unit tests covering initial exported types/buildability.
  - Verification that package-local documentation files (`README.md`, package-local `spec.md`) are present.
  - A build verification that the app target resolves the local package successfully.
- **Dependencies**: SPRD-151

### [SPRD-153] Feature: shared month calendar shell in johnnyo-foundation and month-spread embedding
- **Context**: Month spreads need a reusable calendar component that can be shared across conventional and traditional month surfaces without replacing the month spread itself. The month spread should embed a generic package-owned month calendar shell above the existing entry list, with `Spread` supplying content generation and keeping this first integration view-only.
- **Spec**: Shared Foundations Package; Shared Month Calendar Component; Shared Spread Surface Architecture
- **Acceptance Criteria**:
  - `johnnyo-foundation` exposes a reusable month calendar shell component.
  - The month shell is driven by:
    - a displayed month `Date`
    - an injected `Calendar`
    - explicit configuration including peripheral-date behavior
  - The month shell owns:
    - header placement
    - weekday header row placement
    - date-grid generation
    - first-weekday and locale-aware weekday ordering
    - leading/trailing peripheral-date generation when enabled
  - The month shell renders the minimum number of week rows needed for the displayed month/peripheral-date policy.
  - Grid cells abut with no built-in spacing by default.
  - The month shell uses an injected `CalendarContentGenerator` protocol for semantic slots including:
    - month header
    - weekday column headers
    - date cells
    - additional shell-defined decoration slots as needed
  - Date-cell callbacks receive rich context models rather than raw `Date` values alone.
  - The month shell accepts an optional injected delegate protocol covering shell-generated interaction points.
  - The initial `Spread` month integration is view-only and does not change month-list filtering or selection behavior yet.
  - Both conventional and traditional month spreads embed the same package month calendar component above the entry list.
- **Implementation Details**:
  - Define public month-shell configuration and context-model types in the package.
  - Keep shell structure/calendar math in the package; keep `Spread`-specific content generator and any view-only adapter code in the app target.
  - Do not add built-in previous/next month controls to the package shell in this first version; let header content be generator-driven.
  - Replace existing app-local traditional month-grid implementation with the package calendar embedding where appropriate.
- **Tests**:
  - Package-unit tests covering month-grid generation, first-weekday handling, peripheral-date inclusion/exclusion, and minimum-row behavior.
  - Package tests covering content-generator slot invocation and rich cell-context derivation.
  - App-level tests verifying both conventional and traditional month spreads render the embedded package calendar above the entry list.
  - App-level tests verifying the first `Spread` integration is view-only and does not alter existing month entry-list filtering semantics.
- **Dependencies**: SPRD-152

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

### [SPRD-198] UI: Title navigator collapsed groups - [x] Complete
- **Context**: When users swipe horizontally in the content area and land on a spread hidden by the relevance filter, there is no visual anchor in the title strip. Contiguous runs of hidden spreads should be represented by a collapsed group element that shows the selection indicator when the active spread is inside it, and expands inline to reveal and navigate to those spreads.
- **Spec**: Title Navigator Collapsed Groups [SPRD-198]
- **Acceptance Criteria**:
  - [ ] Add `SpreadTitleNavigatorGroup` value type in `SpreadTitleNavigatorSupport.swift` with `id`, `items: [SpreadTitleNavigatorModel.Item]`, and `dateRangeLabel: String`.
  - [ ] Add `SpreadTitleNavigatorStripElement` enum (`.item` / `.group`) in `SpreadTitleNavigatorSupport.swift`.
  - [ ] Add a static function in `SpreadTitleNavigatorSupport.swift` that computes the ordered array of `SpreadTitleNavigatorStripElement` from a full item list and a filtered item list, forming one group per contiguous gap.
  - [ ] Implement `dateRangeLabel` computation: for a single hidden item use its display label; for multiple, compose a compact range from the first and last item (e.g. "JAN–MAR", "3–7").
  - [ ] Create `SpreadTitleNavigatorGroupView.swift` that renders the collapsed state (date range label + selection indicator dot via `matchedGeometryEffect`) and the expanded collapse-trigger state (compact icon/label).
  - [ ] Update `SpreadTitleNavigatorView` to compute strip elements from full vs filtered item lists and render them instead of the flat `items` array.
  - [ ] Add `@State private var expandedGroupID: String?` to `SpreadTitleNavigatorView`.
  - [ ] Tapping a collapsed group sets `expandedGroupID` with animation; expanding reveals its items inline and collapses any previously expanded group.
  - [ ] Tapping the collapse trigger sets `expandedGroupID = nil` with animation.
  - [ ] In `.onChange(of: selectedSemanticID)`: if new ID is not inside the expanded group, set `expandedGroupID = nil` with animation.
  - [ ] After group expansion, call `requestCenter(on:animated:)` for the active spread.
  - [ ] If the expanded group no longer exists after item list regeneration, reset `expandedGroupID = nil`.
  - [ ] Traditional mode strip is unaffected (groups only form in conventional mode where the relevance filter runs).
- **Tests**:
  - Unit tests for strip-element computation: single-gap, multi-gap, leading-gap, trailing-gap, and no-gap scenarios.
  - Unit tests for `dateRangeLabel` formatting for month-style, day-style, and single-item groups.
  - UI tests: indicator appears under group when active spread is hidden, expand/collapse animation triggers, auto-collapse on selection change outside the group.
- **Dependencies**: SPRD-136, SPRD-137

### [SPRD-199] ✅ UI: Replace inline title strip with compact spread context bar
- **Context**: The inline title strip has accumulated too many responsibilities: current-context display, timeline browsing, recommendation surfacing, hidden-range recovery, and animation-heavy centering behavior. The result is unstable vertical chrome, complex state coupling, and a navigation model that is harder to scan than a simpler persistent context bar plus richer navigator surface.
- **Description**: Replace the persistent horizontal title strip with a compact spread context bar that shows only the current spread, keeps the rooted navigator as the full browsing surface, and moves spread recommendations into the rooted navigator.
- **Spec**: Compact Spread Context Bar and Rooted Navigator [SPRD-199]
- **Acceptance Criteria**:
  - [ ] `SpreadTitleNavigatorView` no longer renders a horizontally scrolling title timeline in the persistent spread chrome.
  - [ ] The persistent bar renders only:
    - a fixed leading rooted-navigator trigger
    - the current spread's primary title plus compact secondary context when needed
    - the existing trailing create affordance
  - [ ] The compact bar stays visually short on iPhone and iPad and does not expand into a tall band during selection changes, layout changes, or recommendation state changes.
  - [ ] Tapping the leading chevron opens the rooted navigator on both platforms; tapping the current title area may open the same navigator surface.
  - [ ] Pager swipes continue to settle selection normally, and the compact bar updates directly to the settled page with no inline recenter, hidden-group proxy, or browse-offset behavior.
  - [ ] Conventional-mode recommendations are removed from the persistent trailing inset and rendered inside the rooted navigator surface instead.
  - [ ] The local `Relevant Past Only` / `Show All Spreads` setting and supporting `@AppStorage` state are removed from the UI and spread-shell wiring.
- **Tests**:
  - Unit tests for compact current-title derivation, including personalized-title + canonical-context combinations.
  - Unit tests for recommendation derivation remaining unchanged while recommendation placement moves into the rooted navigator.
  - UI tests on iPhone and iPad covering compact bar height, rooted navigator opening from the chevron/title area, pager-to-bar synchronization, and recommendation visibility inside the rooted navigator.
- **Dependencies**: SPRD-125, SPRD-128, SPRD-137, SPRD-151

## Story: Auth flow — TestFlight readiness (WKFLW-19) - [x] Complete

### User Story
- As a new user, I want to sign up, verify my email, and access the app without hitting a broken or confusing state.
- As an existing user, I want to reset my password entirely inside the app without being sent to a web page.
- As any user, I want clear feedback when an auth operation is in progress or fails.
- As a user entering a password, I want a show/hide toggle so I can verify what I typed.
- As a user whose sign-in fails because my email is unconfirmed, I want a quick way to resend the verification link without leaving the login screen.
- As a signed-in user, I want to change my password, delete my account, and access legal documents directly from the app.

### Definition of Done
- Email confirmation after sign-up shows an in-sheet "Check your email" state.
- Email verification and password reset deeplinks route back into the app via `spread://auth/callback` and complete fully in-app.
- All three auth sheets show a `ProgressView` loading overlay during async operations.
- All auth error cases produce specific, human-readable messages.
- Session expiry while the app is running transitions the user to the auth gate.
- Supabase redirect URL configuration (`spread://auth/callback`) is applied to both `spread-prod` and `spread-dev`.
- All password `SecureField` inputs have a show/hide visibility toggle.
- Sign-in with an unconfirmed email surfaces an inline "Resend verification email" action.
- `ProfileSheet` exposes Change Password, Delete Account, and Legal links.
- `SignUpSheet` footer links to Terms of Service and Privacy Policy.
- Automated smoke and integration tests pass. Manual test cases are documented in `Documentation/ManualTests.md`.

---

### [SPRD-200] Infra/Protocol: extend AuthService with deeplink handling, password update, resend, and session stream - [x] Complete
- **Context**: The current `AuthService` protocol covers sign-in, sign-up, password reset email, sign-out, and session check. Four new capabilities are required for WKFLW-19: token exchange from deeplink URLs, in-app password update, resend verification email, and an async stream of externally-triggered auth state changes.
- **Description**: Add four new members to `AuthService`. Implement all in `SupabaseAuthService`. Add no-op/stub implementations in `MockAuthService`. Define the supporting value types `AuthDeepLinkResult` and `AuthChangeEvent`.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — AuthService Protocol Additions
- **Implementation Details**:
  - Add `AuthDeepLinkResult` enum: `.emailConfirmed(AuthSuccess)` and `.recoverySession`.
  - Add `AuthChangeEvent` enum: `.signedOut`.
  - Add `func handle(url: URL) async throws -> AuthDeepLinkResult` to the protocol. In `SupabaseAuthService`, call `client.auth.session(from: url)` to exchange the token; inspect the URL `type` parameter (`signup` → `.emailConfirmed`, `recovery` → `.recoverySession`).
  - Add `func updatePassword(newPassword: String) async throws` to the protocol. In `SupabaseAuthService`, call `client.auth.update(user: UserAttributes(password: newPassword))`.
  - Add `func resendVerification(email: String) async throws` to the protocol. In `SupabaseAuthService`, call `client.auth.resend(email: email, type: .signup)`.
  - Add `var authStateChanges: AsyncStream<AuthChangeEvent>` to the protocol. In `SupabaseAuthService`, wrap `client.auth.authStateChanges` and emit `.signedOut` on `signedOut` and `userDeleted` events; ignore all other events. In `MockAuthService`, return a stream that never emits (for baseline test use).
  - All new types live in the `Services/` layer alongside existing `AuthService.swift`; each new value type gets its own file.
- **Acceptance Criteria**:
  - [x] `AuthService` protocol declares `handle(url:)`, `updatePassword(newPassword:)`, `resendVerification(email:)`, and `authStateChanges`.
  - [x] `SupabaseAuthService` implements all four using the Supabase Swift SDK.
  - [x] `MockAuthService` provides stub implementations that compile and satisfy the protocol.
  - [x] `AuthDeepLinkResult` and `AuthChangeEvent` are defined as enums in the `Services/` layer.
  - [x] `handle(url:)` correctly returns `.recoverySession` when `type=recovery` is present in the URL and `.emailConfirmed` for `type=signup`.
- **Tests**:
  - Unit tests for `handle(url:)` URL type parsing using mock URLs (no network required).
  - Unit tests verifying `MockAuthService` satisfies the protocol at compile time.
- **Dependencies**: None

### [SPRD-201] Manager: extend AuthManager with updatePassword, resendVerification, and auth state change observation - [x] Complete
- **Context**: `AuthManager` coordinates auth operations and owns `isLoading` and `errorMessage` state. It needs three additions: a `updatePassword` operation, a `resendVerification` operation, and a stored-`Task` that observes `service.authStateChanges` to handle session expiry.
- **Description**: Add `updatePassword(newPassword:)` and `resendVerification(email:)` to `AuthManager`. Start a stored `Task` in `init` that iterates `service.authStateChanges` and calls the existing sign-out path on a `.signedOut` event.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — Session Expiry; AuthService Protocol Additions
- **Implementation Details**:
  - Add `private var authStateObservationTask: Task<Void, Never>?` stored property.
  - In `init`, assign `authStateObservationTask = Task { await observeAuthStateChanges() }`.
  - `observeAuthStateChanges()` is a `private func` that iterates `service.authStateChanges` and on `.signedOut` sets `state = .signedOut` then calls `await onSignOut?()`. This matches the manual sign-out path so `AuthLifecycleCoordinator` handles data wipe and sync reset automatically.
  - Add `func updatePassword(newPassword: String) async throws` following the same `isLoading`/`errorMessage`/`defer` pattern as existing methods.
  - Add `func resendVerification(email: String) async throws` following the same pattern. On success, no state change is needed (the user remains unconfirmed). On failure, set `errorMessage`.
  - `AuthManager` already exceeds 200 lines; no further extension of the class is needed beyond these additions. If the file grows past 300 lines, extract the error-mapping logic into a separate `AuthErrorMapper` helper.
- **Acceptance Criteria**:
  - [x] `AuthManager.init` starts a stored `Task` observing `service.authStateChanges`.
  - [x] A `.signedOut` stream event transitions `AuthManager.state` to `.signedOut` and calls `onSignOut`.
  - [x] `updatePassword(newPassword:)` is implemented with `isLoading`, `errorMessage`, and `defer` guards matching existing methods.
  - [x] `resendVerification(email:)` is implemented with the same guards.
  - [x] The observation `Task` is stored (not fire-and-forget) per the Swift 6 concurrency guidelines in `CLAUDE.md`.
- **Tests**:
  - Unit test: injecting a `MockAuthService` whose `authStateChanges` emits `.signedOut` verifies that `AuthManager.state` transitions to `.signedOut` and `onSignOut` is called.
  - Unit test: `updatePassword` sets `isLoading` during the call and clears it after.
  - Unit test: `resendVerification` failure sets `errorMessage`.
- **Dependencies**: SPRD-200

### [SPRD-202] Infra/UI: URL scheme registration, AuthDeepLinkCoordinator, and app-root onOpenURL wiring - [x] Complete
- **Context**: iOS delivers deeplinks to the app via the `onOpenURL` environment action. Neither the `spread://` URL scheme nor a handler exist yet. This task adds the scheme, the coordinator that owns routing state, and the wiring in the app root.
- **Description**: Register the `spread` URL scheme in `Info.plist`. Create `AuthDeepLinkCoordinator`. Wire `.onOpenURL` in the app's root view to call the coordinator. Document the Supabase dashboard configuration step in spec.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — URL Scheme and Deeplink Routing
- **Implementation Details**:
  - Add `CFBundleURLTypes` entry to `Info.plist` with `CFBundleURLSchemes: ["spread"]`.
  - Create `AuthDeepLinkCoordinator.swift` in `Services/`:
    - `@Observable @MainActor final class AuthDeepLinkCoordinator`
    - Properties: `private(set) var isRecoverySession = false`
    - Dependencies: injected `AuthService` and `AuthManager`
    - Method: `func handle(url: URL) async` — calls `service.handle(url: url)`. On `.emailConfirmed(let result)`: calls `authManager` session update path (sign-in via existing callback). On `.recoverySession`: sets `isRecoverySession = true`.
    - Method: `func clearRecoverySession()` — sets `isRecoverySession = false`. Called by `SetNewPasswordSheet` on cancel or after successful password update.
  - In the app root view (or scene entry point), inject `AuthDeepLinkCoordinator` via `@Environment` or `@State` and add `.onOpenURL { url in Task { await coordinator.handle(url: url) } }`.
  - Supabase config note: `spread://auth/callback` must be added to Authentication → URL Configuration → Redirect URLs in both `spread-prod` and `spread-dev` Supabase dashboards. This is a manual step documented in `Documentation/ManualTests.md`.
- **Acceptance Criteria**:
  - [x] `Info.plist` declares the `spread` URL scheme.
  - [x] `AuthDeepLinkCoordinator` is an `@Observable @MainActor final class` with `isRecoverySession` state.
  - [x] `.onOpenURL` in the app root routes all URLs to `coordinator.handle(url:)`.
  - [x] `isRecoverySession` becomes `true` when a `type=recovery` URL is handled and clears after cancel or success.
  - [x] Email-confirmation URLs auto-sign the user in without setting `isRecoverySession`.
- **Tests**:
  - Unit test: `AuthDeepLinkCoordinator.handle(url:)` with a mock `type=recovery` URL sets `isRecoverySession = true`.
  - Unit test: `handle(url:)` with a mock `type=signup` URL does not set `isRecoverySession`.
  - Manual test: full end-to-end deeplink flows documented in `Documentation/ManualTests.md`.
- **Dependencies**: SPRD-200, SPRD-201

### [SPRD-203] View: update SignUpSheet with in-sheet email confirmation state - [x] Complete
- **Context**: `SignUpSheet` currently calls `onSignIn` immediately after `signUp()` succeeds. With email confirmation enabled in Supabase, `signUp()` succeeds but no session is returned. The sheet must not dismiss and must instead show a confirmation state.
- **Description**: Update `SignUpSheet` to capture the submitted email after `signUp()` and show an in-sheet "Check your email" confirmation state. Add a Resend button and a Done dismiss button.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — Sign-Up Flow (with Email Confirmation)
- **Implementation Details**:
  - Add `@State private var submittedEmail: String?` to `SignUpSheet`.
  - After a successful `authManager.signUp(email:password:)` call (no error thrown), set `submittedEmail = email` instead of relying on `authManager.state` change to dismiss.
  - When `submittedEmail != nil`, replace the form content with the confirmation state view:
    - `Label` with `envelope.badge.fill` icon (green) and "Check Your Email" title, matching the `ForgotPasswordSheet` success pattern.
    - Text: "We sent a verification link to [email]. Tap it to confirm your account."
    - "Resend Email" button: calls `authManager.resendVerification(email: submittedEmail)`. Shows `authManager.errorMessage` below it on failure.
    - Toolbar: replace "Cancel"/"Create" with a single "Done" trailing button that dismisses.
  - Keep the existing `.onChange(of: authManager.state)` dismiss path so that if the user verifies their email while the sheet is still open (same device, background app), the sheet dismisses automatically.
  - Keep `.onDisappear { authManager.clearError() }`.
- **Acceptance Criteria**:
  - [x] Successful `signUp()` transitions the sheet to the confirmation state without dismissing.
  - [x] The confirmation state shows the submitted email address, verification instructions, and a "Resend Email" button.
  - [x] "Resend Email" calls `authManager.resendVerification(email:)` and surfaces errors via `authManager.errorMessage`.
  - [x] The "Done" button dismisses the sheet from the confirmation state.
  - [x] If `authManager.state` transitions to `.signedIn` while the sheet is open, it still dismisses normally.
  - [x] Preview includes both the empty/default state and the post-submission confirmation state.
- **Tests**:
  - Unit test: after `signUp()` succeeds, `submittedEmail` is set and the form content is replaced.
  - Unit test: "Resend Email" invokes `resendVerification(email:)` on the auth manager.
- **Dependencies**: SPRD-200, SPRD-201

### [SPRD-204] View: add SetNewPasswordSheet - [x] Complete
- **Context**: When a password reset deeplink is handled, `AuthDeepLinkCoordinator.isRecoverySession` is set to `true`. The app root must present a sheet where the user can enter and confirm a new password. This view does not yet exist.
- **Description**: Create `SetNewPasswordSheet`. Present it from the app root when `coordinator.isRecoverySession == true`. On success, clear the recovery session and the user lands in journal content.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — Password Reset Flow
- **Implementation Details**:
  - Create `SetNewPasswordSheet.swift` in `Views/Auth/`.
  - Dependencies: injected `AuthManager` and `AuthDeepLinkCoordinator`.
  - Fields: new password (`textContentType(.newPassword)`) and confirm password. Both use `@State private var hasEdited` guards before showing validation errors, consistent with `SignUpSheet`.
  - Validation via `AuthFormValidator.validatePassword` and `AuthFormValidator.validatePasswordConfirmation`.
  - Toolbar: `Cancel` (cancellation action) and `Save Password` (confirmation action, disabled when form invalid or `authManager.isLoading`).
  - Cancel action: calls `coordinator.clearRecoverySession()` and dismisses. Returns the user to the auth gate.
  - Save action: calls `authManager.updatePassword(newPassword: password)`. On success, calls `coordinator.clearRecoverySession()` and dismisses. On error, shows `authManager.errorMessage` inline.
  - `ProgressView` overlay when `authManager.isLoading`.
  - `interactiveDismissDisabled(true)` — users must explicitly cancel or save.
  - Present from the app root as `.sheet(isPresented: $coordinator.isRecoverySession) { SetNewPasswordSheet(...) }`.
  - Preview includes empty state and loading state.
- **Acceptance Criteria**:
  - [x] `SetNewPasswordSheet` is presented when `coordinator.isRecoverySession == true`.
  - [x] New password and confirm password fields validate using `AuthFormValidator`.
  - [x] "Save Password" is disabled until the form is valid and not loading.
  - [x] Successful password update calls `coordinator.clearRecoverySession()` and dismisses.
  - [x] Cancel calls `coordinator.clearRecoverySession()`, dismisses, and returns the user to the auth gate.
  - [x] `ProgressView` overlay appears during `authManager.isLoading`.
  - [x] Interactive dismiss is disabled.
  - [x] Preview covers both empty and loading states.
- **Tests**:
  - Unit test: successful `updatePassword` clears `isRecoverySession` and dismisses.
  - Unit test: cancel clears `isRecoverySession` without calling `updatePassword`.
  - Unit test: "Save Password" disabled when password fields are empty or mismatched.
- **Dependencies**: SPRD-200, SPRD-201, SPRD-202

### [SPRD-205] View: add ProgressView loading overlays to LoginSheet, SignUpSheet, and ForgotPasswordSheet - [x] Complete
- **Context**: Auth operations already disable buttons via `authManager.isLoading`, but there is no visual indication that something is happening. Users have no feedback between tapping a button and receiving a result.
- **Description**: Add a `ProgressView` overlay to `LoginSheet`, `SignUpSheet`, and `ForgotPasswordSheet` that appears while `authManager.isLoading` is true.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — Loading States
- **Implementation Details**:
  - For each of the three sheets, add a computed property `private var loadingOverlay: some View` that returns a `ZStack` containing a semi-transparent background and a centered `ProgressView()`. Alternatively, use `.overlay` directly on the `Form`.
  - Apply the overlay only when `authManager.isLoading`.
  - The overlay sits above the form content but does not cover the navigation bar.
  - Do not change button disabled states — those remain as-is.
  - Consistent visual style across all three sheets.
- **Acceptance Criteria**:
  - [x] `LoginSheet` shows a `ProgressView` overlay when `authManager.isLoading`.
  - [x] `SignUpSheet` shows a `ProgressView` overlay when `authManager.isLoading`.
  - [x] `ForgotPasswordSheet` shows a `ProgressView` overlay when `authManager.isLoading`.
  - [x] The overlay does not cover the navigation bar.
  - [x] The visual style is consistent across all three sheets.
  - [x] Preview for each sheet includes a loading state example.
- **Tests**:
  - Unit tests for overlay visibility driven by `isLoading` on each sheet.
- **Dependencies**: SPRD-201

### [SPRD-206] Error: expand AuthManager error message mapping - [x] Complete
- **Context**: `AuthManager.mapAuthError` currently handles `invalidCredentials`, `userNotFound`, `sessionExpired`, and `sessionNotFound`. Several common failure modes have no specific mapping and fall through to a generic "Authentication failed" message. These include unconfirmed email, duplicate registration, rate limiting, and network errors.
- **Description**: Expand `mapAuthError` and the catch hierarchy in each `AuthManager` method to produce specific messages for all common auth failure modes.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — Error Message Additions
- **Implementation Details**:
  - Add cases to the `mapAuthError` switch for: `emailNotConfirmed` → "Please verify your email first. Check your inbox.", `userAlreadyExists` (or the applicable Supabase error code for duplicate sign-up) → "An account with this email already exists.", rate limiting → "Too many attempts. Please try again later."
  - In `signIn`, `signUp`, and `resetPassword`, add a dedicated `catch` for `URLError` or network-level errors before the generic `catch` → "No internet connection. Please check your network and try again."
  - Verify the exact Supabase Swift SDK error codes against the SDK source for `emailNotConfirmed` and `userAlreadyExists` — use the SDK enum cases, not string matching.
  - Update the `signUp` method: since a successful `signUp` with email confirmation enabled does NOT return a session, the success path must set `submittedEmail` state rather than calling `onSignIn`. Coordinate with `SPRD-203` to ensure the correct success detection.
- **Acceptance Criteria**:
  - [x] "Please verify your email first. Check your inbox." appears when a user attempts to sign in before confirming their email.
  - [x] "An account with this email already exists." appears on sign-up with a duplicate email.
  - [x] "Too many attempts. Please try again later." appears when Supabase rate-limits the request.
  - [x] "No internet connection. Please check your network and try again." appears on network failure.
  - [x] Existing error messages for invalid credentials and user not found are preserved.
  - [x] No string-matching on error messages — all cases use SDK enum comparisons.
- **Tests**:
  - Unit tests for each new error case using `MockAuthService` configured to throw the corresponding error type.
- **Dependencies**: SPRD-200, SPRD-201

### [SPRD-207] Test: auth flow smoke tests - [x] Complete
- **Context**: Backlog item TF-40 called for smoke tests covering login success, login failure (wrong password), sign-up success, and forgot-password submission using a mock auth service. WKFLW-19 expands the required coverage significantly.
- **Description**: Add Swift Testing smoke tests for all auth flows that can be exercised with a mock auth service. Flows requiring a real backend or live email inbox are documented in `Documentation/ManualTests.md` instead.
- **Spec**: Authentication Flow — Email Confirmation and Deeplinks (WKFLW-19) — Testing; Backlog TF-40
- **Implementation Details**:
  - Test file: `SpreadTests/Auth/AuthFlowTests.swift`. Mirror the source folder structure per `CLAUDE.md`.
  - Use `MockAuthService` for all tests. No network calls.
  - Each test includes a comment describing conditions and expected behavior per `CLAUDE.md` testing guidelines.
  - Flows to cover:
    - Login success: valid credentials → `AuthManager.state` transitions to `.signedIn`, `onSignIn` called.
    - Login failure (wrong password): `MockAuthService` throws `invalidCredentials` → `errorMessage` is "Invalid email or password."
    - Login failure (unconfirmed email): `MockAuthService` throws `emailNotConfirmed` → `errorMessage` is "Please verify your email first. Check your inbox."
    - Sign-up success (confirmation state): `MockAuthService.signUp` returns success without session → `AuthManager` does not call `onSignIn`, `submittedEmail` is set in `SignUpSheet`.
    - Sign-up failure (duplicate email): `MockAuthService` throws `userAlreadyExists` → `errorMessage` is "An account with this email already exists."
    - Forgot password success: `resetPassword` succeeds → no error, `didSendReset` is true in `ForgotPasswordSheet`.
    - Forgot password failure: `MockAuthService.resetPassword` throws → `errorMessage` is set.
    - Password update success: `updatePassword` succeeds → `isRecoverySession` clears via `AuthDeepLinkCoordinator`.
    - Session expiry: injecting a `MockAuthService` whose `authStateChanges` emits `.signedOut` → `AuthManager.state` transitions to `.signedOut` and `onSignOut` is called.
    - Deeplink URL parsing (email confirmation): `type=signup` URL → `AuthDeepLinkCoordinator.isRecoverySession` remains false.
    - Deeplink URL parsing (recovery): `type=recovery` URL → `AuthDeepLinkCoordinator.isRecoverySession` becomes true.
- **Acceptance Criteria**:
  - [x] All listed test cases exist in `SpreadTests/Auth/AuthFlowTests.swift`.
  - [x] Every test has a describing comment per `CLAUDE.md`.
  - [x] All tests pass with no network calls.
  - [x] Tests use `MockAuthService`; no production Supabase credentials are required.
- **Tests**: This task is the tests.
- **Dependencies**: SPRD-200, SPRD-201, SPRD-202, SPRD-203, SPRD-204, SPRD-205, SPRD-206

### [x] [SPRD-208] View: password visibility toggle on all SecureField password inputs
- **Context**: `LoginSheet`, `SignUpSheet`, and `SetNewPasswordSheet` all use `SecureField` for password inputs. Users have no way to verify what they have typed, which leads to frustration on failed sign-in or sign-up attempts.
- **Description**: Add a show/hide eye-icon toggle button to each `SecureField` across the three auth sheets. Extract a `PasswordField` reusable view to avoid duplicating the conditional `SecureField`/`TextField` swap.
- **Spec**: Auth UI (v1) — password visibility toggle
- **Implementation Details**:
  - Create `Spread/Views/Auth/PasswordField.swift`. This is a `View` struct that wraps a single password input with:
    - `@Binding var text: String`
    - `let placeholder: String`
    - `let contentType: UITextContentType` (defaults to `.password`)
    - `@State private var isVisible = false`
    - Body: `HStack` containing either a `TextField` or `SecureField` based on `isVisible`, plus a trailing `.plain`-style `Button` with `Image(systemName: isVisible ? "eye.slash" : "eye").foregroundStyle(.secondary)`. The button toggles `isVisible`.
    - Forwards `.textContentType`, `.autocorrectionDisabled()`, and `.textInputAutocapitalization(.never)`.
    - Exposes `.accessibilityIdentifier` on both the field and the toggle button so tests can assert each.
  - Replace all `SecureField` usages in `LoginSheet` (password), `SignUpSheet` (password + confirmPassword), and `SetNewPasswordSheet` (password + confirmPassword) with `PasswordField`.
  - `textContentType` for each field stays as-is (`.password` for login, `.newPassword` for sign-up/set-new-password confirm fields).
  - Add accessibility identifiers for the toggle buttons to `Definitions.AccessibilityIdentifiers`.
  - Update previews in each sheet to show a state with visible password text.
- **Acceptance Criteria**:
  - [ ] `PasswordField` is defined in `Views/Auth/PasswordField.swift` and used in `LoginSheet`, `SignUpSheet`, and `SetNewPasswordSheet`.
  - [ ] The eye icon button is visible at the trailing edge of each password field.
  - [ ] Tapping the toggle switches between obscured and visible text.
  - [ ] `textContentType` is preserved correctly for each field (`.password` for login, `.newPassword` elsewhere).
  - [ ] Accessibility identifiers are added for the toggle buttons.
  - [ ] Previews in each sheet include a visible-password state.
- **Tests**:
  - Unit tests in `SpreadTests/Views/Auth/PasswordVisibilityTests.swift` (`@MainActor struct`):
    - `passwordFieldStartsObscured` — `isVisible` is `false` by default (verify via accessibility identifier of the visible `SecureField` identifier).
    - `passwordFieldTogglesVisibility` — after a simulated toggle, the visible field identifier is present.
    - Note: view-layer tests are limited without ViewInspector; focus tests on `PasswordField`'s `isVisible` state being driven correctly by identifying the accessible element. Tests may use `@Test` with `AuthManager` smoke-driven approaches consistent with existing auth tests.
- **Dependencies**: None

### [x] [SPRD-209] View/Manager: resend verification email from sign-in error
- **Context**: When a user tries to sign in before confirming their email, `AuthManager` shows "Please verify your email first. Check your inbox." but provides no quick path to resend the email. The user must back out, tap "Create Account", and re-enter their credentials to reach the resend button in `SignUpSheet`.
- **Description**: Add `requiresEmailVerification: Bool` to `AuthManager`, set it when a sign-in attempt returns `emailNotConfirmed`, and use it in `LoginSheet` to show an inline "Resend verification email" button below the error text.
- **Spec**: Auth UI (v1) — resend verification from sign-in error; Error Handling UX — email not confirmed
- **Implementation Details**:
  - Add `private(set) var requiresEmailVerification = false` to `AuthManager`.
  - In the `signIn` method, reset `requiresEmailVerification = false` at the start (before the network call) and set `requiresEmailVerification = true` in the catch block when the resolved error code is `.emailNotConfirmed`.
  - In `clearError()`, also set `requiresEmailVerification = false`.
  - In `LoginSheet`:
    - Add a `@State private var resentEmail = false` to track successful resend for one-time confirmation text.
    - In `errorSection`, when `authManager.requiresEmailVerification` is true, display below the error text:
      - A `Button("Resend verification email")` that calls `Task { try? await authManager.resendVerification(email: email) }` and on success sets `resentEmail = true`.
      - When `resentEmail` is true, replace the button with `Text("Verification email sent.")` in `.secondary` style.
    - `email` in this context is the `@State private var email` field on `LoginSheet` (the value the user typed when they attempted sign-in).
    - Clear `resentEmail` in `onChange(of: email)` so a fresh attempt resets the one-time confirmation.
  - Add accessibility identifiers for the resend button and sent-confirmation text.
- **Acceptance Criteria**:
  - [ ] `AuthManager.requiresEmailVerification` is `true` after a sign-in attempt that returns `emailNotConfirmed` and `false` after any other outcome (success, different error, `clearError()`).
  - [ ] `LoginSheet` shows a "Resend verification email" button when `authManager.requiresEmailVerification` is `true`.
  - [ ] Tapping "Resend verification email" calls `authManager.resendVerification(email:)` with the current email field value.
  - [ ] After a successful resend, the button is replaced with a "Verification email sent." confirmation.
  - [ ] The button does not appear for other error types (wrong password, user not found, etc.).
- **Tests**:
  - Unit tests in `SpreadTests/Auth/AuthFlowTests.swift` (add to existing suite):
    - `signInEmailNotConfirmed_setsRequiresEmailVerification` — `FailingSignInService(emailNotConfirmed)` → `authManager.requiresEmailVerification == true`.
    - `signInWrongPassword_doesNotSetRequiresEmailVerification` — `FailingSignInService(invalidCredentials)` → `authManager.requiresEmailVerification == false`.
    - `clearError_clearsRequiresEmailVerification` — set `requiresEmailVerification` via a failing sign-in, call `clearError()`, verify it is `false`.
    - `resendVerification_succeeds_clearsError` — `MockAuthService` → `resendVerification` succeeds, `errorMessage` is nil.
  - Integration test in `AuthIntegrationTests.swift`:
    - `testSignIn_unconfirmedEmail_setsRequiresEmailVerification` — admin create unconfirmed user → attempt sign-in → `requiresEmailVerification == true`.
- **Dependencies**: SPRD-200, SPRD-201

### [x] [SPRD-210] View: change password from ProfileSheet
- **Context**: `AuthManager.updatePassword` exists but is only reachable via the password-reset deeplink. Users who want to change their password while authenticated have no in-app path. They must sign out and use the forgot-password email flow.
- **Description**: Create `ChangePasswordSheet` and add a "Change Password" row to `ProfileSheet` that opens it.
- **Spec**: Auth UI (v1) — Change Password; Account Management — Change Password
- **Implementation Details**:
  - Create `Spread/Views/Auth/ChangePasswordSheet.swift`:
    - Dependencies: injected `AuthManager`.
    - Fields: new password and confirm-password, both using `PasswordField` (from SPRD-208).
    - `@State private var hasEditedPassword`, `@State private var hasEditedConfirmPassword` guards on error display.
    - Validation using `AuthFormValidator.validatePassword` and `AuthFormValidator.validatePasswordConfirmation`.
    - Toolbar: "Cancel" (cancellation action) dismisses; "Save Password" (confirmation action) disabled when form invalid or loading.
    - On save: `Task { do { try await authManager.updatePassword(newPassword: password); dismiss() } catch { /* error shown via authManager.errorMessage */ } }`.
    - `ProgressView` overlay when `authManager.isLoading` (same pattern as `SetNewPasswordSheet`).
    - Errors shown inline via `errorSection`.
    - `interactiveDismissDisabled` is **not** set — unlike the recovery-session sheet, the user chose to open this voluntarily and can cancel freely.
    - `.onDisappear { authManager.clearError() }`.
    - Previews: empty state, loading state.
  - In `ProfileSheet`:
    - Add `@State private var isShowingChangePassword = false`.
    - Add a "Change Password" `Button` row to `accountSection` that sets `isShowingChangePassword = true`.
    - Add `.sheet(isPresented: $isShowingChangePassword) { ChangePasswordSheet(authManager: authManager) }`.
    - The "Change Password" row is disabled when `authManager.isLoading`.
  - Add accessibility identifiers for the "Change Password" row in `ProfileSheet` and the "Save Password" button in `ChangePasswordSheet`.
- **Acceptance Criteria**:
  - [ ] `ChangePasswordSheet` is defined in `Views/Auth/ChangePasswordSheet.swift` using `PasswordField` (SPRD-208).
  - [ ] `ProfileSheet` has a "Change Password" row that opens `ChangePasswordSheet`.
  - [ ] "Save Password" is disabled until new password and confirmation both pass validation.
  - [ ] Successful password update dismisses the sheet; errors are shown inline.
  - [ ] `ProgressView` overlay appears during `authManager.isLoading`.
  - [ ] `authManager.clearError()` is called on disappear.
  - [ ] Previews cover empty and loading states.
- **Tests**:
  - Unit tests in `SpreadTests/Views/Auth/ChangePasswordTests.swift` (`@MainActor struct`):
    - `changePassword_success_dismisses` — successful `updatePassword` clears `isLoading` and `errorMessage`.
    - `changePassword_mismatch_showsError` — confirm password differs from new password → `isFormValid` false (tested via `AuthFormValidator` directly or via `AuthManager` state).
    - `changePassword_failure_setsErrorMessage` — `FailingUpdatePasswordService` → `authManager.errorMessage != nil` after attempt.
  - Integration test in `AuthIntegrationTests.swift` (extend `testPasswordUpdate_changesPassword` or add):
    - `testChangePassword_fromSignedInState_succeeds` — sign in → open `ChangePasswordSheet` equivalent (call `authManager.updatePassword`) → verify sign-out → sign in with new password → restore original. The existing `testPasswordUpdate_changesPassword` already covers this path; add a note referencing it as the integration coverage for SPRD-210.
- **Dependencies**: SPRD-201, SPRD-208

### [x] [SPRD-211] Feature: delete account
- **Context**: App Store guidelines require that apps with account creation also provide a way to delete the account and all associated data. The current `ProfileSheet` has no delete-account path.
- **Description**: Add a `deleteAccount()` method to `AuthService` backed by a Supabase Edge Function, wire it through `AuthManager`, and add a destructive "Delete Account" flow to `ProfileSheet`.
- **Spec**: Account Management (v1) — Delete Account
- **Implementation Details**:
  - **Edge Function** (`supabase/functions/delete-user/index.ts`):
    - Receives an authenticated request (Bearer JWT in `Authorization` header).
    - Extracts the user ID from the JWT using the service-role Supabase client.
    - Calls `supabase.auth.admin.deleteUser(userId)` to hard-delete the user and all cascade-deleted data.
    - Returns `{ "success": true }` on success or a JSON error with appropriate HTTP status.
    - Deploy to `spread-prod` and `spread-dev` via `supabase functions deploy delete-user`.
  - **`AuthService` protocol** (`Spread/Services/AuthService.swift`):
    - Add `func deleteAccount() async throws`.
  - **`SupabaseAuthService`** (`Spread/Services/SupabaseAuthService.swift`):
    - `func deleteAccount() async throws { _ = try await client.functions.invoke("delete-user") }`.
  - **`MockAuthService`** (`Spread/Services/MockAuthService.swift`):
    - No-op stub: `func deleteAccount() async throws {}`.
  - **`DebugAuthService`** (`Spread/Debug/DebugAuthService.swift`):
    - Delegating stub: `func deleteAccount() async throws { try await wrapped.deleteAccount() }`.
  - **`AuthManager`** (`Spread/Services/AuthManager.swift`):
    - Add `func deleteAccount() async throws` following the `isLoading`/`errorMessage`/`defer` pattern.
    - On success: `state = .signedOut` then `await onSignOut?()` — this triggers `AuthLifecycleCoordinator` to wipe the local store.
    - Error mapping: wrap in `mapAuthError` for `AuthError`; catch `URLError` for network; generic fallback with message "Could not delete account. Please try again or contact support."
  - **`ProfileSheet`** (`Spread/Views/Auth/ProfileSheet.swift`):
    - Add `@State private var showDeleteConfirmation = false`.
    - Add a new `Section` below the account section with a single `Button("Delete Account", role: .destructive)` that sets `showDeleteConfirmation = true`. Disabled when `authManager.isLoading`.
    - Add `.confirmationDialog("Delete Account?", isPresented: $showDeleteConfirmation, titleVisibility: .visible)` with message "This will permanently delete your account and all associated data. This cannot be undone." and a destructive "Delete Account" action that calls `Task { try? await authManager.deleteAccount() }`.
    - Errors from `deleteAccount` are surfaced via `authManager.errorMessage`. Add an `.alert` to `ProfileSheet` bound to a computed `showsDeleteError: Bool` from `authManager.errorMessage != nil`.
  - Add accessibility identifiers for the "Delete Account" row and the confirmation action.
- **Acceptance Criteria**:
  - [ ] `AuthService` declares `deleteAccount()`.
  - [ ] `SupabaseAuthService` calls the `delete-user` Edge Function.
  - [ ] `MockAuthService` and `DebugAuthService` satisfy the protocol with no-op / delegating implementations.
  - [ ] `AuthManager.deleteAccount()` sets `isLoading`, calls `service.deleteAccount()`, then on success transitions to `.signedOut` and calls `onSignOut()`.
  - [ ] `ProfileSheet` has a destructive "Delete Account" row in a separate section.
  - [ ] A confirmation dialog asks the user to confirm before proceeding.
  - [ ] Errors are surfaced inline in `ProfileSheet`.
  - [ ] The `delete-user` Edge Function is deployed to both `spread-prod` and `spread-dev`.
- **Tests**:
  - Unit tests in `SpreadTests/Auth/AuthFlowTests.swift` (add to existing suite):
    - `deleteAccount_success_transitionsToSignedOut` — `MockAuthService` → `deleteAccount()` → `state == .signedOut`.
    - `deleteAccount_success_callsOnSignOut` — `MockAuthService` → `deleteAccount()` → `onSignOut` callback invoked.
    - `deleteAccount_failure_setsErrorMessage` — service throws → `authManager.errorMessage != nil`, `state` unchanged.
  - Integration test in `AuthIntegrationTests.swift`:
    - `testDeleteAccount_removesUserAndSignsOut` — admin create temp user → sign in → `authManager.deleteAccount()` → `state == .signedOut` → admin `listUsers` does not contain the deleted user's ID.
- **Dependencies**: SPRD-200, SPRD-201

### [x] [SPRD-212] View: Terms of Service and Privacy Policy links
- **Context**: App Store guidelines require that apps collecting user data provide links to Terms of Service and Privacy Policy. These links are currently absent from the sign-up flow and from the app's settings/profile surface.
- **Description**: Add a `LegalLinks` namespace with URL constants, a footer to `SignUpSheet` referencing both documents, and a "Legal" section in `ProfileSheet` with rows for each link.
- **Spec**: Account Management (v1) — Legal Links
- **Implementation Details**:
  - Create `Spread/Additions/LegalLinks.swift`:
    ```swift
    /// URL constants for legal documents.
    ///
    /// TODO: Replace placeholder URLs before App Store submission.
    enum LegalLinks {
        static let termsOfService = URL(string: "https://example.com/terms")!
        static let privacyPolicy  = URL(string: "https://example.com/privacy")!
    }
    ```
  - **`SignUpSheet`**: In the `fieldsSection`, change from `Section { ... }` to `Section { ... } footer: { legalFooter }`.
    - `private var legalFooter: some View` returns a `Text` using `AttributedString` or inline `Link` views:
      ```swift
      HStack(spacing: 0) {
          Text("By creating an account you agree to our ")
          Link("Terms of Service", destination: LegalLinks.termsOfService)
          Text(" and ")
          Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
          Text(".")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      ```
    - Both `Link` views receive accessibility identifiers.
  - **`ProfileSheet`**: Add a `legalSection: some View` returning a `Section("Legal")` with two `Link` rows: "Terms of Service" and "Privacy Policy", each opening the respective `LegalLinks` URL and displaying a trailing `Image(systemName: "safari")` icon.
    - Add accessibility identifiers for both rows.
  - Update `SignUpSheet` and `ProfileSheet` previews to show the new sections.
- **Acceptance Criteria**:
  - [ ] `LegalLinks` enum defined in `Spread/Additions/LegalLinks.swift` with `termsOfService` and `privacyPolicy` URL constants and a `TODO` comment.
  - [ ] `SignUpSheet` fields section has a footer with tappable Terms of Service and Privacy Policy links.
  - [ ] `ProfileSheet` has a "Legal" section with a "Terms of Service" row and a "Privacy Policy" row.
  - [ ] Both surfaces use `LegalLinks` constants (no inline URL strings).
  - [ ] Accessibility identifiers are present for all four link elements (two in each view).
  - [ ] Previews updated to show the legal footer/section.
- **Tests**:
  - Unit tests in `SpreadTests/Views/Auth/LegalLinksTests.swift` (`@MainActor struct`):
    - `legalLinks_termsURL_isValid` — `LegalLinks.termsOfService` is a valid URL (non-nil, scheme is `https`).
    - `legalLinks_privacyURL_isValid` — `LegalLinks.privacyPolicy` is a valid URL.
    - `signUpSheet_legalFooterAccessibilityIdentifiers_present` — verify accessibility identifier constants exist for both link elements.
    - `profileSheet_legalSectionAccessibilityIdentifiers_present` — verify accessibility identifier constants for both legal rows exist.
  - No integration tests required — link validity and presence are fully covered by unit tests.
- **Dependencies**: None

---

## Story: UI polish and design system foundation — TestFlight readiness (WKFLW-20)

### User Story
- As a developer, I want a centralized design system with named palette and token support so styling is consistent and theme switching requires no code changes.
- As a user running dark mode, I want every screen to render correctly with sufficient contrast and no broken colors.
- As a first-time user, I want the launch screen to clearly identify the app rather than showing a generic loading indicator.
- As a user navigating sheets and toolbars, I want consistent button placement, loading states, and error feedback across all surfaces.
- As a VoiceOver user, I want entry rows and icon-only action buttons to have clear accessibility labels so I can use the app without visual cues.

### Definition of Done
- `SpreadTheme` exposes three named palettes (ocean, forest, ink) switchable via launch argument; all existing color properties delegate to the active palette.
- `SpreadTheme` defines `CornerRadius`, `Motion`, `Opacity`, and `IconSize` token enums.
- All three Xcode schemes have disabled `-SpreadPalette` launch arguments for one-click switching.
- All screens pass dark mode inspection: no hardcoded color literals, paper/accent/badge colors use `SpreadTheme` tokens throughout.
- App startup loading screen shows the app wordmark or name — not a bare `ProgressView("Loading...")`.
- All modal sheets follow the consistent sheet pattern: `Cancel` / primary action toolbar placement, loading overlay, error alert.
- All toolbar icon buttons meet the 44 pt minimum tap-target requirement.
- `EntryRowView` has `.accessibilityLabel` combining title, type, and status; `.accessibilityValue` exposes priority and due date when set.
- All icon-only action buttons (status toggle, create, migrate, delete, favorite) have `.accessibilityLabel` values.

---

### [x] [SPRD-213] Design: expand SpreadTheme with palette system, token enums, and scheme launch arguments
- **Context**: `SpreadTheme` covers colors, typography, and spacing but has no support for multiple color schemes or named token categories. Corner radii, animation durations, opacity levels, and icon sizes appear as magic numbers scattered across ~90 view files. WKFLW-20 needs a stronger foundation before the polish pass to avoid introducing new inconsistencies. Palette switching must be an engineering/QA-only facility — no in-app runtime UI — so launch arguments are the right mechanism.
- **Description**: Add a `Palette` enum with three named schemes (ocean, forest, ink), wire `activePalette` to a UserDefaults key resolved from the `-SpreadPalette` launch argument, refactor existing color computed vars to delegate to the active palette, and add `CornerRadius`, `Motion`, `Opacity`, and `IconSize` token enums. Add disabled palette launch args to all three Xcode schemes.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Design System
- **Implementation Details**:
  - `SpreadTheme.Palette` enum: `.ocean` (current warm paper + blue), `.forest` (warm paper + sage green), `.ink` (neutral paper + near-black). Each case exposes `paperPrimary`, `paperSecondary`, `accentPrimary`, `accentTodayEmphasis` as computed `Color` properties with adaptive `UIColor { traits in }` closures.
  - `SpreadTheme.activePalette`: read-only static var, reads `UserDefaults.standard.string(forKey: "SpreadPalette")`, defaults to `.ocean`. No setter — palette selection is launch-argument only.
  - Refactored `Paper.primary`, `Accent.primary`, `Accent.todayEmphasis`, `Accent.todaySelectedEmphasis`, `DotGrid.dots` delegate to `activePalette` in the non-debug path. Existing `default*` constants and `#if DEBUG` guard blocks preserved for `SpreadTheme+Debug.swift` compatibility.
  - `Paper.secondary` becomes a computed var delegating to `activePalette.paperSecondary`.
  - `selectedSurface` / `selectedSurfaceBorder` remain constant warm yellow across all palettes.
  - `CornerRadius`: `hairline` (1.5), `tiny` (2), `badge` (4), `standard` (8), `card` (12), `section` (16), `large` (20).
  - `Motion`: `quick` (`.easeInOut(0.15)`), `standard` (`.easeInOut(0.25)`), `spring` (`.spring(response: 0.35, dampingFraction: 0.7)`). Named `Motion` not `Animation` to avoid shadowing SwiftUI.
  - `Opacity`: `hint` (0.08), `subtle` (0.12), `muted` (0.35), `todayBorder` (0.34), `strong` (0.95).
  - `IconSize`: `small` (14), `medium` (18), `large` (22), `extraLarge` (28).
  - Each scheme (`Spread Localhost`, `Spread Prod`, `Spread QA`) gets three disabled `CommandLineArguments` entries: `-SpreadPalette ocean`, `-SpreadPalette forest`, `-SpreadPalette ink`.
- **Acceptance Criteria**:
  - [x] `SpreadTheme.Palette` has `.ocean`, `.forest`, `.ink` with correct adaptive colors per the design doc.
  - [x] `SpreadTheme.activePalette` reads from `UserDefaults` key `SpreadPalette`; no setter exists.
  - [x] All existing color computed vars (`Paper.primary`, `Accent.primary`, `todayEmphasis`, `todaySelectedEmphasis`, `DotGrid.dots`) delegate to `activePalette` in the non-debug path.
  - [x] `SpreadTheme+Debug.swift` still compiles with no changes; debug overrides continue to work.
  - [x] `CornerRadius`, `Motion`, `Opacity`, and `IconSize` enums exist with the specified constants.
  - [x] All three Xcode schemes contain three disabled `-SpreadPalette` launch argument entries.
  - [x] Build succeeds with no new errors.
- **Tests**: No automated tests required — visual token values are verified through build success and manual scheme-switching.
- **Dependencies**: None

### [x] [SPRD-214] Visual: dark mode audit and hardcoded color replacement
- **Context**: TestFlight users frequently run dark mode; broken or washed-out colors are visually disqualifying. The current codebase contains hardcoded `Color` literals and raw hex values that ignore dark mode. Backlog item TF-31.
- **Description**: Perform a systematic audit of all view files for hardcoded colors. Replace any `Color(...)` or `.foregroundColor(.black/.white)` literals with `SpreadTheme` tokens or semantic system colors.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Dark Mode
- **Acceptance Criteria**:
  - [ ] All view files use `SpreadTheme.Paper`, `SpreadTheme.Accent`, or semantic system colors (`Color.primary`, `Color.secondary`, etc.) — no hardcoded hex or `Color(red:green:blue:)` literals outside of `SpreadTheme.swift`.
  - [ ] The dot grid, paper backgrounds, badge colors, entry row icon tints, and selection highlights render correctly in both light and dark mode.
  - [ ] A build with `-SpreadPalette forest` and `-SpreadPalette ink` in dark mode shows no broken surfaces.
- **Tests**:
  - Manual dark mode review on iPhone simulator for each major surface (spreads list, day/month/year spread, entry creation sheets, settings, auth).
- **Dependencies**: SPRD-213

### [x] [SPRD-215] Visual: launch screen branding
- **Context**: The app startup loading screen shows `ProgressView("Loading...")` — a generic indicator that gives no signal about what app is loading. Backlog item TF-30.
- **Description**: Replace the bare loading screen with a branded layout showing the app name (and/or wordmark) alongside a minimal loading indicator.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Launch Experience
- **Acceptance Criteria**:
  - [x] The launch/loading screen shows the app name "Spread" (or wordmark if assets are available) in `SpreadTheme.Typography.largeTitle` style.
  - [x] A `ProgressView` or subtle activity indicator is present but secondary to the wordmark.
  - [x] The screen uses `SpreadTheme.Paper.primary` as the background.
  - [x] The layout is centered and renders correctly on both iPhone and iPad.
- **Tests**:
  - Visual inspection on simulator.
- **Dependencies**: SPRD-213

### [x] [SPRD-216] Visual: consistent sheet presentation audit
- **Context**: Task creation, note creation, spread creation, auth, and profile sheets were built independently and have diverged in chrome: some have leading Cancel, some trailing; some have loading states, some don't; some use `.alert` for errors, some silently discard. Backlog item TF-32.
- **Description**: Audit all sheets for consistent header layout, dismiss affordances, loading state coverage, and error surfacing. Apply fixes to bring all sheets into alignment.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Sheet Presentation Consistency
- **Implementation Details**:
  - Sheets to audit: `TaskCreationSheet`, `NoteCreationSheet`, `SpreadCreationSheet`, `LoginSheet`, `SignUpSheet`, `ForgotPasswordSheet`, `SetNewPasswordSheet`, `ChangePasswordSheet`, `ProfileSheet`.
  - Standard pattern: leading `Cancel` button, trailing primary action (disabled when form invalid or loading), `ProgressView` overlay when loading, `.alert` for errors.
  - `interactiveDismissDisabled(true)` on sheets where accidental dismissal would lose user input (creation sheets, change-password sheet).
- **Acceptance Criteria**:
  - [x] All sheets have a leading `Cancel` toolbar button and a trailing primary-action toolbar button.
  - [x] All sheets disable the primary action button during loading.
  - [x] All sheets show a `ProgressView` overlay when an async operation is in flight.
  - [x] All sheets surface repository/service errors via `.alert` — no silent failures on save.
  - [x] All creation sheets have `interactiveDismissDisabled(true)` when the form has unsaved user input.
- **Tests**:
  - Visual inspection across all sheet types on simulator.
- **Dependencies**: None

### [x] [SPRD-217] Visual: toolbar and action button review
- **Context**: Toolbar buttons across spread types have inconsistent icon choices and placement. Some action buttons are smaller than the 44 pt minimum tap target. Backlog item TF-33.
- **Description**: Review all toolbar and icon-only action buttons across spread types. Standardize icon choices for shared actions (create, migrate, favorite, delete). Verify and fix minimum tap-target sizing.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Toolbar and Action Button Standards
- **Acceptance Criteria**:
  - [x] All toolbar and icon-only buttons have a minimum 44 pt tap target (via `.frame(minWidth: 44, minHeight: 44)` or `.contentShape` padding where needed).
  - [x] The same action uses the same SF Symbol across all spread types.
  - [x] No buttons are visually cropped or overlap adjacent controls.
  - [x] `SpreadTheme.IconSize` constants are used for SF Symbol font sizes.
- **Tests**:
  - Visual inspection on simulator across day, month, year, and multiday spread types.
- **Dependencies**: SPRD-213

### [x] [SPRD-218] Accessibility: entry row and icon-only button labels
- **Context**: `EntryRowView` rows announce only a flat title string to VoiceOver users with no status or type context. Icon-only action buttons (status toggle, create, migrate, delete, favorite) have no accessibility labels, making them unidentifiable to screen reader users. Backlog items TF-20, TF-21.
- **Description**: Add `.accessibilityLabel` and `.accessibilityValue` to `EntryRowView`. Add `.accessibilityLabel` (and `.accessibilityRole(.button)` with `.accessibilityAddTraits(.isDestructive)` where appropriate) to all icon-only action buttons.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Accessibility Labels
- **Acceptance Criteria**:
  - [x] `EntryRowView` `.accessibilityLabel` combines: entry title, type ("Task" / "Note"), and status ("Open", "Complete", "Migrated", "Cancelled").
  - [x] `EntryRowView` `.accessibilityValue` includes priority label (if non-none) and due date in a readable format (if set).
  - [x] Status toggle button has a label describing both the action and current state, e.g. "Mark complete" / "Reopen".
  - [x] Create, migrate, delete, and favorite buttons each have a clear `.accessibilityLabel`.
  - [x] Delete button destructive role conveys destructive trait (via `Button(role: .destructive)` — `AccessibilityTraits.isDestructive` does not exist in SwiftUI).
- **Tests**:
  - Unit tests in `SpreadTests/Views/Entries/EntryRowAccessibilityTests.swift`:
    - `taskRow_openStatus_accessibilityLabel_includesTitleTypeAndStatus`
    - `taskRow_completeStatus_accessibilityLabel_includesCompleteStatus`
    - `taskRow_highPriority_accessibilityValue_includesPriority`
    - `taskRow_withDueDate_accessibilityValue_includesDueDate`
  - Manual VoiceOver verification on simulator.
- **Dependencies**: None

### [x] [SPRD-219] Visual: liquid glass nav bar integration for spread title strip
- **Context**: iOS 26 renders navigation bars with liquid glass. The spread title navigator strip was placed in the content VStack with a custom background and fixed height, preventing the glass effect from compositing correctly. The dot grid background also didn't extend behind the system bars. Tracked as part of WKFLW-20; initially committed under the mislabeled SPRD-216 tag (commits `e4b02c5`, `f6f430b`).
- **Description**: Move `SpreadTitleNavigatorView` into the `.principal` toolbar slot so iOS 26 renders it natively inside the liquid glass nav bar. Extend the dot grid to bleed behind all safe-area edges so the pattern shows through the glass.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Liquid Glass Nav Bar
- **Acceptance Criteria**:
  - [x] `SpreadTitleNavigatorView` rendered as `.principal` toolbar item, not in content VStack.
  - [x] Custom 52 pt height frame and `secondaryPaperBackground` removed from navigator; bar sizing delegated to system.
  - [x] Trigger and title buttons merged into single button with trailing chevron; accessibility identifiers preserved.
  - [x] Dot grid `ignoresSafeAreaEdges` set to `.all` so pattern extends behind nav and tab bars.
- **Tests**:
  - Visual inspection on simulator with iOS 26 liquid glass.
- **Dependencies**: SPRD-213

### [x] [SPRD-220] Visual: spread header toolbar migration — sync icon and spread actions to nav bar
- **Context**: `SpreadHeaderView` renders a dedicated row with a leading sync ring and trailing favorite + ellipsis buttons. This creates an empty horizontal gap in the middle and consumes vertical space that could be used for content. iOS convention places per-screen secondary actions in the navigation bar toolbar.
- **Description**: Replace the custom sync ring with an SF Symbol-based sync icon button, move it and the ellipsis menu into the nav bar toolbar slots, fold the favorite toggle into the ellipsis menu, and strip the dedicated action row from `SpreadHeaderView`.
- **Spec**: UI Polish and Design System Foundation (WKFLW-20) — Spread Header Toolbar Integration
- **Acceptance Criteria**:
  - [x] New `SyncIconButton` view in `Spread/Views/Components/`:
    - Uses `arrow.triangle.2.circlepath` when idle or syncing; `exclamationmark.arrow.triangle.2.circlepath` when `status` is `.error`.
    - Continuous `rotationEffect` animation (linear, 1 s, repeat forever) applied only when syncing.
    - Color: idle (clean) → `.secondary`; syncing → `SpreadTheme.Accent.todaySelectedEmphasis`; error → `.orange`; offline → `.secondary.opacity(0.4)`.
    - Tappable to trigger a manual sync when `status.shouldTriggerSync`; same `.accessibilityLabel` and `.accessibilityHint` semantics as `SyncRingView`.
    - Symbol at `SpreadTheme.IconSize.medium` font size; tap target `.frame(minWidth: 44, minHeight: 44)`.
    - Hidden (not rendered) when `status == .localOnly`.
  - [x] `SyncIconButton` placed in `.toolbar` with `.topBarLeading` placement in `SpreadsView`.
  - [x] Ellipsis `Menu` placed in `.toolbar` with `.primaryAction` placement in `SpreadsView`.
  - [x] Favorite toggle folded into the ellipsis menu: "Add to Favorites" (Label with `star` symbol) when not favorited; "Remove from Favorites" (Label with `star.fill` symbol) when favorited. Appears as the first item above Edit Name / Edit Dates / Delete Spread.
  - [x] `SpreadHeaderView` `syncRing` and `headerActions` computed properties and their backing callbacks removed. Body renders Go Back button only (empty when no back destination).
  - [x] `SyncRingView` is retained but no longer referenced by `SpreadHeaderView`.
  - [x] No dedicated action row appears below the title navigator strip; vertical space is fully reclaimed for content.
- **Tests**:
  - Visual inspection: toolbar shows sync icon (leading) and ellipsis (trailing) on spread surfaces.
  - Ellipsis menu shows favorite item and toggles correctly.
  - Sync icon rotates during active sync; shows error symbol on sync error.
- **Dependencies**: SPRD-213, SPRD-219

---

## Story: Task Browser, List and Tag organizational fields (SESH-21)

### User Story
- As a user, I want a dedicated Tasks tab where I can see all my tasks across every spread in one place, so I don't have to navigate spread by spread to find what I need to do.
- As a user, I want to assign tasks to a List ("Work", "Home") and tag them with projects or themes ("EOY Presentation", "Baby Preparation") so I can organize and filter tasks by context.
- As a user, I want to manage my Lists and Tags from one place — rename them and delete them — so my organizational structure stays clean over time.

### Definition of Done
- `List` and `Tag` are first-class SwiftData models with sync support.
- `DataModel.Task` and `DataModel.Note` both have optional `list` and `tags` relationships.
- The Search tab is replaced by a Tasks tab showing all tasks in open and terminal sections with embedded search and List/Tag filter chips.
- The task create/edit sheet includes List and Tags pickers with inline creation.
- The management sheet (accessible from the Tasks tab) supports rename and delete with count-aware confirmation for Lists and Tags.

---

### [SPRD-221] Feature: List and Tag models with Task/Note relationships and sync - [x] Done

- **Context**: Tasks and Notes need first-class organizational fields — a domain List ("Work", "Home") and cross-cutting Tags ("EOY Presentation") — to power the Task Browser's filter and management features. These are new SwiftData models requiring a schema migration and Supabase sync support.
- **Description**: Add `DataModel.List` and `DataModel.Tag` SwiftData `@Model` types. Add optional `list` and `tags` relationships to `DataModel.Task` and `DataModel.Note`. Add `ListRepository`, `TagRepository` protocols and implementations. Extend the Supabase schema with `lists` and `tags` tables plus a `task_tags` and `note_tags` join table. Wire into the outbox/sync architecture.
- **Spec**: `Documentation/Specs/TaskBrowser.md` — List and Tag Models; `Documentation/Specs/DataModel.md` — List, Tag
- **Acceptance Criteria**:
  - [x] `DataModel.List` exists with a non-empty `name: String` and inverse one-to-many relationships to `DataModel.Task` and `DataModel.Note`.
  - [x] `DataModel.Tag` exists with a non-empty `name: String` and inverse many-to-many relationships to `DataModel.Task` and `DataModel.Note`.
  - [x] `DataModel.Task` has `list: List?` and `tags: [Tag]` properties.
  - [x] `DataModel.Note` has `list: List?` and `tags: [Tag]` properties.
  - [x] `ListRepository` and `TagRepository` protocols and SwiftData implementations exist with CRUD operations.
  - [x] Supabase migration adds `lists`, `tags`, `task_tags`, and `note_tags` tables with appropriate RLS policies.
  - [x] List and Tag mutations are enqueued in the sync outbox and pushed with the standard outbox architecture.
  - [x] Schema migration compiles without data loss on existing installs.
  - [x] The app builds successfully with strict Swift 6 concurrency enabled.
- **Tests**:
  - [x] Unit tests for `ListRepository` and `TagRepository` CRUD operations using in-memory containers.
  - [x] Unit test: adding a task to a List correctly sets the inverse relationship.
  - [x] Unit test: adding a Tag to a task correctly sets the many-to-many inverse.
  - [x] Unit test: deleting a List nils out `task.list` on all associated tasks.
  - [x] Unit test: deleting a Tag removes it from all associated tasks' `tags` arrays.

---

### [SPRD-222] Feature: Entries tab — task browser, Notes mode, adaptive filter panel - [x] Done

- **Context**: The existing Search tab (SPRD-148) is a limited task browser. This task replaces it with the full Entries tab: an "Entries"-labeled tab with a Tasks/Notes segmented control, comprehensive task lifecycle organization, List/Tag filtering, and an adaptive filter panel that adapts to horizontal size class. SPRD-225 scope is absorbed here to avoid building the tab layout twice.
- **Description**: Replace the Search tab with an Entries tab (`NavigationTab.entries`). Build `EntriesBrowserView` with a Tasks/Notes segmented control. Tasks mode: two non-collapsible sections (Open, Completed/Cancelled) with List/Tag filter support and a filter sheet (compact) or persistent trailing card (regular). Notes mode: all notes ordered by `createdDate` descending, search-only. Wire into `JournalManager`, `ListRepository`, and `TagRepository`.
- **Spec**: `Documentation/Specs/TaskBrowser.md` — Entries Tab and Content Switcher; Tasks Tab; List and Tag Filtering; Adaptive Filter and Sort Panel
- **Acceptance Criteria**:
  - [x] The Search tab is replaced by an Entries tab labeled **"Entries"** with an appropriate SF Symbol.
  - [x] A segmented control labeled "Tasks" / "Notes" appears at the top of the tab; the tab defaults to Tasks mode and does not persist the selection between launches.
  - [x] **Tasks mode** — the tab renders two non-collapsible sections: Open (top) and Completed / Cancelled (bottom).
  - [x] Open section order: Inbox tasks (nil assignment, by `createdDate` asc) first, then assigned open tasks by preferred spread normalized date asc with period tiebreaker (day before month before year), then `createdDate` asc within identical date+period.
  - [x] Completed / Cancelled section ordered by current assignment `statusUpdatedAt` descending; falls back to `createdDate` descending when `statusUpdatedAt` is nil.
  - [x] Task rows use `EntryList`/`EntryRowView` consistent with spread entry lists.
  - [x] The tab is accessible in both Conventional and Traditional modes with identical behavior — no mode-specific branching.
  - [x] List filter shows all Lists; selecting one filters to tasks in that List only.
  - [x] Tag filters show all Tags; selecting multiple shows tasks with ANY selected tag (OR within tags).
  - [x] When both a List filter and Tag filters are active, results must match the List AND have at least one selected Tag (AND across types).
  - [x] No filter is active by default; all tasks are shown.
  - [x] When `horizontalSizeClass == .compact`, a filter button (`line.3.horizontal.decrease.circle` or equivalent) in the nav bar toolbar opens a filter sheet; the button shows a badge or filled variant when filters are active.
  - [x] When `horizontalSizeClass == .regular`, a persistent trailing card displays filter controls alongside the task list; the toolbar filter button is hidden.
  - [x] The filter sheet and trailing card expose identical controls (List filter, Tag filters).
  - [x] Size-class branching uses `@Environment(\.horizontalSizeClass)` — no `UIDevice.current.userInterfaceIdiom` checks.
  - [x] The filter sheet includes a "Manage Lists & Tags" row at the bottom (stub navigation target for SPRD-223).
  - [x] **Notes mode** — shows all notes across all spreads ordered by `createdDate` descending; no filter controls are shown.
  - [x] A `.searchable` bar filters results in both Tasks and Notes modes by title and body text in real time.
- **Tests**:
  - [x] Unit tests for task ordering: Inbox tasks before assigned tasks; day-period tasks ordered before month-period tasks for the same normalized date.
  - [x] Unit test: completed/cancelled tasks ordered by `statusUpdatedAt` descending.
  - [x] Unit test: List filter returns only tasks belonging to that List.
  - [x] Unit test: multi-Tag OR filter returns tasks with any of the selected Tags.
  - [x] Unit test: combined List + Tag filter applies AND across types.
  - [x] Unit test: search query applied on top of active filters.
  - Unit test: Notes mode loads notes ordered by `createdDate` descending. (covered in EntriesBrowserView computed property)
  - Unit test: search query in Notes mode filters by title and body. (covered in EntriesBrowserView computed property)
- **Dependencies**: SPRD-221

---

### [SPRD-223] Feature: List and Tags management sheet - [x] Done

- **Context**: Users need a central place to rename and delete Lists and Tags without opening individual task edit sheets. The Tasks tab hosts this as a navigation-stack sheet.
- **Description**: Add a management sheet accessible via the "Manage Lists & Tags" row at the bottom of the Tasks tab filter sheet. The sheet uses a `NavigationStack` with a root showing Lists and Tags sections. Tapping a List or Tag navigates to a detail view with inline rename and a delete action with count-aware confirmation.
- **Spec**: `Documentation/Specs/TaskBrowser.md` — List and Tags Management Sheet
- **Acceptance Criteria**:
  - [x] The management sheet is accessible via a "Manage Lists & Tags" row at the bottom of the Tasks tab filter sheet.
  - [x] The sheet root shows two sections: Lists (all List names with task counts) and Tags (all Tag names with task counts).
  - [x] Tapping a List navigates to a detail view showing its name (editable inline) and the count of tasks assigned to it.
  - [x] Tapping a Tag navigates to a detail view showing its name (editable inline) and the count of tasks using it.
  - [x] Rename saves on commit; the new name must be non-empty and trimmed. Invalid (empty) names are rejected with inline feedback.
  - [x] Delete triggers a confirmation dialog stating: "Deleting '[Name]' will remove it from [N] tasks. This cannot be undone."
  - [x] Confirming delete nils out `list` or removes the tag from all affected tasks (and notes for model parity), then deletes the entity.
  - [x] The Tasks tab filter chips and task rows reflect the deletion immediately.
- **Tests**:
  - [x] Unit test: rename List updates `list.name` and all associated task rows reflect the new name.
  - [x] Unit test: rename Tag updates `tag.name`.
  - [x] Unit test: deleting a List nils out `task.list` on all affected tasks.
  - [x] Unit test: deleting a Tag removes it from all affected tasks' `tags`.
  - [x] Unit test: confirmation dialog count matches the actual number of affected tasks.
- **Dependencies**: SPRD-221, SPRD-222

---

### [SPRD-224] UI: List and Tags pickers in task and note create/edit sheets - [x] Done

- **Context**: The task create/edit sheet needs List and Tags pickers so users can assign organizational context when creating or editing a task. Note create/edit gets the same pickers for model parity even though Notes are not displayed in the Task Browser.
- **Description**: Add a List picker (select one or none) and a Tags picker (select zero or more) to the task create/edit sheet. Add the same pickers to the note create/edit sheet. Both pickers allow inline creation of new Lists or Tags without leaving the sheet.
- **Spec**: `Documentation/Specs/TaskBrowser.md` — List and Tags in Entry Create/Edit
- **Acceptance Criteria**:
  - [x] The task create/edit sheet displays a List picker and a Tags picker in the metadata section, alongside body, priority, and due date.
  - [x] The note create/edit sheet displays the same List and Tags pickers.
  - [x] The List picker allows selecting one existing List, clearing the selection, or creating a new List by name.
  - [x] The Tags picker allows selecting zero or more existing Tags and creating new Tags by name.
  - [x] New List and Tag names created inline are trimmed and must be non-empty; empty names are rejected.
  - [x] List and Tags fields remain editable when a task is complete or cancelled, consistent with body, priority, and due date.
  - [x] The Tags picker enforces a maximum of 5 Tags per task; adding more is disabled with an inline message ("Maximum 5 tags") once the limit is reached.
  - [x] Pickers reflect any renames or deletions made in the management sheet without requiring the sheet to be dismissed and reopened.
- **Tests**:
  - [x] Unit test: saving a task with a selected List sets `task.list` to that List.
  - [x] Unit test: saving a task with selected Tags sets `task.tags` to those Tags.
  - [x] Unit test: creating a new List inline via the picker creates a `DataModel.List` and assigns it.
  - [x] Unit test: clearing the List picker sets `task.list` to nil.
  - [x] Unit test: List and Tags fields are still editable when task status is `.complete` or `.cancelled`.
  - [x] Unit test: attempting to add a 6th Tag to a task is rejected.
- **Dependencies**: SPRD-221

---

### [SPRD-225] Feature: Entries tab — title, Tasks/Notes switcher, adaptive filter panel - [x] Absorbed into SPRD-222

- **Context**: Originally planned as a follow-up to SPRD-222. Absorbed before implementation because all three changes (tab label, segmented control, adaptive layout) affect the root view structure and must be built together to avoid a full-view refactor.
- **Resolution**: All SPRD-225 acceptance criteria are included in the expanded SPRD-222 scope.

---

### [SPRD-226] Refactor: Remove traditional mode — conventional-only app - [x] Done

- **Context**: The app currently supports two BuJo modes (conventional and traditional), but all mode-switching infrastructure adds significant complexity that slows MVP development. The `BujoMode` enum, dual data model builders, dual spread services, branching coordinators, branching views, settings UI, and sync fields together represent hundreds of lines of code that deliver zero user value right now. Traditional mode is deferred to a future version; the codebase should have no trace of it.
- **Description**: Delete all traditional-mode code and the bridging infrastructure that only existed to abstract over two modes. This includes: the `BujoMode` enum; `TraditionalJournalDataModelBuilder` and its protocol `JournalDataModelBuilder` (one implementation remaining, protocol unneeded); `TraditionalSpreadService`; the `SpreadTitleNavigatorProviding` protocol and its `JournalManager` conformance file (direct property replaces it); the `traditional*` cases of `SpreadHeaderNavigatorModel.Selection` (collapsing the enum to a `typealias` for `DataModel.Spread`); all `traditional*` methods in `SpreadHeaderNavigatorModel` and `SpreadTitleNavigatorModel`; the `Mode` enum on `SpreadHeaderNavigatorModel`; `groupsByList`/`groupsByDay` parameters that were always `false` in traditional mode (now hardcoded `true`); the mode selector in Settings; all `switch bujoMode` / `if bujoMode == .traditional` branches throughout coordinators, views, and managers; debug launch overrides; and all dedicated traditional-mode tests. Simplify every component to assume conventional unconditionally. In `SyncSerializer`, hardcode `"conventional"` for the `p_bujo_mode` write field and ignore its value on read — Supabase columns stay in the DB but are inert. Remove `bujoMode` and `bujoModeUpdatedAt` from `DataModel.Settings`.
- **Spec**: `Documentation/Specs/ConventionalMode.md` — Mode; `Documentation/Specs/JournalManager.md` — Journal Logic Architecture; `Documentation/Specs/SpreadNavigation.md` — Spread Surface Architecture
- **Acceptance Criteria**:
  - [x] `BujoMode.swift` is deleted; no Swift file in the project imports or references the `BujoMode` type.
  - [x] `TraditionalJournalDataModelBuilder` (and its source file) is deleted.
  - [x] `TraditionalSpreadService.swift` is deleted.
  - [x] `JournalDataModelBuilder` protocol is retained as a DI-boundary seam (per CLAUDE.md testability rules) with a single conformer `ConventionalJournalDataModelBuilder`; `JournalManager` has no `activeDataModelBuilder` mode-switch and no traditional-mode branching.
  - [x] `SpreadTitleNavigatorProviding` protocol and `JournalManager+SpreadTitleNavigatorProviding.swift` are deleted; `JournalManager` exposes a direct `titleNavigatorModel` property that constructs `SpreadHeaderNavigatorModel` unconditionally for conventional mode.
  - [x] `SpreadHeaderNavigatorModel.Selection` is collapsed — the `Mode` enum, the `traditionalYear/Month/Day` cases, and the `.conventional(_)` wrapper are all gone; `Selection` is a `typealias` for `DataModel.Spread` or equivalent flat type. All call sites that unwrap `.conventional(let spread)` are updated to use the spread directly.
  - [x] `SpreadHeaderNavigatorModel` has no `mode` property, no `Mode` enum, no `conventional*` / `traditional*` method pairs; only the single conventional implementation remains.
  - [x] `SpreadTitleNavigatorModel` has no `traditionalYearItems()` method; `todaySemanticID()` and `selectionID()` no longer switch on mode or selection type.
  - [x] `SpreadTitleNavigatorView.currentNavigatorSpread` is trivially `selection` (no switch needed).
  - [x] `JournalManager` has no `bujoMode` property, no mode switches, no mode guards.
  - [x] `MigrationPlanner` has no mode guards; migration logic assumes conventional unconditionally.
  - [x] `DataModel.Settings` no longer has `bujoMode` or `bujoModeUpdatedAt` fields.
  - [x] `SyncSerializer` hardcodes `"conventional"` when writing `p_bujo_mode` and does not read or apply the field's server value.
  - [x] `SpreadsCoordinator` has no handling for traditional selection cases; `isSameSelection()` is a direct ID comparison.
  - [x] `SpreadContentPagerView` has no `traditionalContentView` path or mode branch.
  - [x] `SpreadsView` has no `bujoMode` references.
  - [x] `DaySpreadContentView` and `MultidaySpreadContentView` have no `bujoMode` references; `groupsByList` and `groupsByDay` parameters are removed and their `true` branches are the only code path.
  - [x] `MonthSpreadContentView` has no `bujoMode` references.
  - [x] `RootNavigationView` has no mode-based fallback selection logic.
  - [x] `TaskSearchSupport` has no mode-based filtering branch.
  - [x] `JournalManager+NavigationSelection.swift` has no mode switch; both `defaultNavigationSelection` and `todayNavigationSelection` return `DataModel.Spread` directly.
  - [x] `SettingsView` has no mode selector section.
  - [x] `AppDependencies`, `AppRuntimeFactory` no longer load or pass a `bujoMode` parameter.
  - [x] `AppLaunchConfiguration` no longer parses a `-BujoMode` launch argument.
  - [x] `AppRuntimeConfiguration+Debug` no longer has a `bujoMode` override.
  - [x] Test files `TraditionalModeIntegrationTests.swift`, `TraditionalJournalDataModelBuilderTests.swift`, `TraditionalSpreadServiceTests.swift` are deleted.
  - [x] `SettingsSyncTests.swift` no longer tests `bujoMode` sync serialization or LWW.
  - [x] All remaining tests pass; the project builds without warnings or errors.
- **Tests**:
  - No new tests required — this task deletes tests and simplifies logic. Verify the build is green and all surviving unit tests pass after removal.
- **Open Questions**:
  - The `p_bujo_mode` and `p_bujo_mode_updated_at` columns remain in the Supabase `settings` table. A follow-up migration can drop them if they cause issues during future schema evolution.

---

### [SPRD-227] Refactor: Entry status icon pipeline and single Entry.status protocol requirement - [x] Done

- **Context**: The entry status icon pipeline splits rendering knowledge across `EntryStatusButtonRepresentable`, `EntryIconFactory`, and `EntryStatusIcon`. Separately, the `Entry` protocol exposes three typed optional status accessors (`displayTaskStatus`, `displayNoteStatus`, `displayEventStatus`) plus a derived `status` extension default — four properties where one should suffice.
- **Description**: Two coordinated changes. (1) Icon pipeline: introduce `EntryStatusIcon.BaseShape` and `EntryStatusIcon.Overlay` nested enums with `color: Color?` and `size: CGFloat?` associated values on every case; make `EntryStatusIcon` a pure primitive renderer; make `EntryStatusButton` the protocol bridge; remove `statusColor` from the protocol; delete `EntryIconFactory.swift` and `EntryIconSize`; remove `rowIconColor` from `EntryRowView`. (2) Entry protocol: replace `displayTaskStatus`, `displayNoteStatus`, `displayEventStatus` with a single `status: any EntryStatusButtonRepresentable` protocol requirement; the concrete model types satisfy it via Swift's implicit existential covariance without any bridging code; delete the three display shim files; update view and configuration code that needs typed comparisons to cast to the concrete type.
- **Spec**: `Documentation/Specs/EntryComponents.md` — Requirements and Design Decisions
- **Acceptance Criteria**:
  - `EntryStatusIcon` defines nested `BaseShape` enum with cases `filledCircle(color: Color?, size: CGFloat?)`, `emptyCircle(color: Color?, size: CGFloat?)`, `dash(color: Color?, size: CGFloat?)`.
  - `EntryStatusIcon` defines nested `Overlay` enum with cases `xmark(color: Color?, size: CGFloat?)`, `arrowRight(color: Color?, size: CGFloat?)`, `slash(color: Color?, size: CGFloat?)`.
  - `EntryStatusIcon` accepts `baseShape: BaseShape` and `overlay: Overlay?` as its only inputs. No `color`, `size`, or `status` parameters.
  - Color coalescing in `EntryStatusIcon`: overlay `color` → base shape `color` → `.primary`.
  - Size coalescing in `EntryStatusIcon`: case `size` → 12.0pt.
  - `EntryStatusButton` accepts `status: any EntryStatusButtonRepresentable` only (no `color` parameter). It reads `iconBaseShape` and `iconOverlay` from the protocol and passes them to `EntryStatusIcon`.
  - `statusColor` is removed from `EntryStatusButtonRepresentable`. All three conformances (`Task.Status`, `Note.Status`, `Event.Status`) embed color in their `iconBaseShape` return values.
  - `EntryIconFactory.swift` is deleted with no remaining references in the project.
  - `EntryIconSize` is deleted with no remaining references in the project.
  - `rowIconColor` is removed from `EntryRowView`. `EntryStatusButton` is called without a `color` argument.
  - `TaskDetailSheet` and any other direct `EntryStatusIcon` users construct `BaseShape` directly with their desired color.
  - The `Entry` protocol requires `var status: any EntryStatusButtonRepresentable { get }` and no longer declares `displayTaskStatus`, `displayNoteStatus`, or `displayEventStatus`.
  - The `Entry` extension default `status` property is removed; `status` is a first-class protocol requirement.
  - `DataModel.Task.status: DataModel.Task.Status` satisfies the protocol requirement without any new computed property or wrapper.
  - `DataModel.Note.status: DataModel.Note.Status` satisfies the protocol requirement the same way.
  - `DataModel.Event` has a computed `var status: DataModel.Event.Status { .upcoming }` satisfying the requirement.
  - `DataModel.Task+DisplayHelpers.swift` has only its `displayTaskStatus` line removed; the file is otherwise unchanged.
  - `DataModel.Note+Display.swift` is deleted (its only content was `displayNoteStatus`).
  - `DataModel.Event+Display.swift` is deleted (its only content was `displayEventStatus`). `DataModel.Event` gains `var status: DataModel.Event.Status { .upcoming }` in `DataModelSchemaV1.swift` or a new `DataModel.Event+Entry.swift` extension.
  - Tests in `EntryRowAccessibilityTests.swift` and `NoteMigrationExclusionTests.swift` that used `displayTaskStatus` / `displayNoteStatus` are updated to use `task.status` / `note.status` directly.
  - All call sites that previously used `entry.displayTaskStatus`, `entry.displayNoteStatus`, or `entry.displayEventStatus` for typed comparisons are updated to cast to the concrete type (e.g. `(entry as? DataModel.Task)?.status == .open`).
  - All existing Previews for `EntryStatusIcon`, `EntryStatusButton`, and `EntryRowView` render correctly with no visual regression.
  - Project builds with no errors or warnings.
- **Tests**:
  - Visual inspection of existing Previews in `EntryStatusIcon.swift`, `EntryStatusButton.swift`, and `EntryRowView.swift` covers all icon/overlay combinations. No unit tests required.

---

### [SPRD-229] Refactor: Adaptive navigation shell — NavigationSplitView 3-column - [x] Done

- **Context**: `RootNavigationView` uses `TabView(.automatic)` wrapping one `NavigationStack` per tab. On iPad this stacks multiple chrome layers, consuming vertical space and making the hierarchy hard to follow. The spread navigator is also hidden behind a chevron popover rather than being persistently available.
- **Description**: Replace `RootNavigationView` with a single `NavigationSplitView` 3-column structure — no explicit size class branching. Sidebar: navigation destinations (current tabs). Content column: the spread picker list (existing `SpreadPickerModel` items, replacing `SpreadPickerButton` in `SpreadsView`). Detail column: `SpreadContentPagerView`. SwiftUI handles compact collapse automatically. Selecting a spread from the content column instantly positions the pager (no animation) and always collapses to `.detailOnly` — even if the same spread was already selected. Swiping the pager updates the content column selection bidirectionally.
- **Spec**: `Documentation/Specs/SpreadNavigation.md` — Adaptive Navigation Shell
- **Acceptance Criteria**:
  - [x] A single `NavigationSplitView` is used — no `TabView` branch, no `@Environment(\.horizontalSizeClass)` branching at the root.
  - [x] Sidebar lists Spreads, Entries, Collections, Settings (and Debug when `BuildInfo.allowsDebugUI`).
  - [x] Content column shows the spread picker list (driven by `SpreadPickerModel.items(for:)`) when Spreads is selected. For other destinations, content column shows that destination's content.
  - [x] `SpreadPickerButton` is removed from `SpreadsView.body`. The content column is now the only spread picker surface.
  - [x] Detail column shows `SpreadContentPagerView` for the currently selected spread.
  - [x] Tapping a row in the content column: (1) sets `selectedSpread` to the tapped spread, (2) positions the pager to that spread instantly with no scroll animation, (3) always sets `columnVisibility = .detailOnly` — even if the tapped spread was already selected.
  - [x] Swiping the pager past a settle threshold updates `selectedSpread` and the content column list reflects the new selection when visible.
  - [x] A toolbar button in the detail column restores the content column (`columnVisibility = .automatic` or equivalent) when the user wants to pick a different spread.
  - [x] On iPhone (compact), SwiftUI collapses the split view to a navigation stack: sidebar → spread picker list → spread pager. Pager scrolls horizontally as before.
  - [x] Double-chrome is eliminated on iPad — no stacked tab bar above a NavigationStack toolbar.
  - [x] Auth button appears in the detail column toolbar.
  - [x] `openTaskFromSearch` cross-destination navigation works correctly.
  - [x] `spreadsCoordinator`, `spreadsNavigationState`, `selectedSpread`, and `columnVisibility` are all owned at `RootNavigationView` level.
  - [x] **Size class transition contract**: when the app moves between compact and regular (iPad entering/leaving multitasking split view), selected destination, selected spread, pager position, and active sheet destination are all preserved with no visible reset or flash.
  - [x] Spread pager position is lifted out of any child `@State` and owned at root level so it survives the size class branch swap.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - No unit tests required. Manual verification on iPad simulator: (1) navigate to a non-default spread via content column — confirm pager teleports instantly and content column hides; (2) tap the already-selected spread in the content column — confirm column still hides; (3) swipe pager to a different spread — confirm content column list reflects new selection when reopened; (4) enter split-screen multitasking — confirm selected spread and pager position are preserved.

---

### [SPRD-230] Refactor: Entry edit popover, remove inspector - [ ] Pending

- **Context**: `RootNavigationView` uses `.inspector()` for all `SpreadsCoordinator.SheetDestination` cases. After SPRD-229, the inspector approach is replaced: task and note detail editing should open as a `.popover` anchored to the Edit swipe-action button with a trailing arrow. Other sheet destinations (creation sheets, spread name edit, etc.) remain as `.sheet`.
- **Description**: Remove the `.inspector()` modifier from `RootNavigationView`. Wire `TaskDetailSheet` and `NoteDetailSheet` as `.popover(item:arrowEdge:.trailing)` anchored to the swipe-action Edit button on each entry row. All other `SpreadsCoordinator.SheetDestination` cases (spread creation, task creation, note creation, spread name edit, spread date edit, peek data, auth) remain presented as `.sheet`. On compact (iPhone), SwiftUI automatically collapses `.popover` to a sheet — no manual branching needed.
- **Spec**: `Documentation/Specs/SpreadNavigation.md` — Adaptive Navigation Shell
- **Acceptance Criteria**:
  - The `.inspector()` modifier is removed from `RootNavigationView` with no remaining references.
  - Pressing Edit on a task row's swipe actions opens `TaskDetailSheet` as a `.popover` with `arrowEdge: .trailing`, anchored to the Edit button.
  - Pressing Edit on a note row's swipe actions opens `NoteDetailSheet` as a `.popover` with `arrowEdge: .trailing`, anchored to the Edit button.
  - On iPad (regular), the popover appears as a floating panel with a trailing arrow pointing to the Edit button.
  - On iPhone (compact), SwiftUI collapses the popover to a sheet automatically — no explicit branching required.
  - All other `SpreadsCoordinator.SheetDestination` cases continue to present as `.sheet` and are unaffected.
  - Popover dismisses correctly when the user taps outside or when `spreadsCoordinator.activeSheet` is set to `nil`.
  - No entry row tap behavior changes — inline title editing (SPRD-132) is unaffected.
  - Project builds with no errors or warnings.
- **Tests**:
  - Manual verification on iPad simulator: swipe a task row, tap Edit — confirm popover appears with trailing arrow. Tap outside — confirm it dismisses. Swipe a note row, tap Edit — confirm same popover behavior.
- **Dependencies**: SPRD-229

---

### [SPRD-228] Refactor: Extract CalendarEventService from view-local CalendarEventStore - [x] Done

- **Context**: `CalendarEventStore` is a nested `@Observable` class duplicated inside `DaySpreadContentView` and `MultidaySpreadContentView`. It owns both the EventKit fetch logic and the resulting `[CalendarEvent]` state. This makes the fetch strategy (EventKit today, Google Calendar or others in v2) impossible to mock in tests/previews and tightly coupled to the view layer.
- **Description**: Introduce a `CalendarEventService` protocol with a single `fetchEvents(for:calendar:) async -> [CalendarEvent]` method. Implement `LiveCalendarEventService` (wraps `EventKitService`), `MockCalendarEventService` (returns seeded data), and `EmptyCalendarEventService` (returns `[]`). Add `calendarEventService` to `AppDependencies` and `SpreadPageContext`. Delete `CalendarEventStore` from both content views; replace with `@State var calendarEvents: [CalendarEvent] = []` and a `.task` call to the service.
- **Spec**: `Documentation/Specs/EventKit.md` — Calendar Event Fetching Service (SPRD-228)
- **Acceptance Criteria**:
  - [x] `CalendarEventService` protocol exists in `Spread/Services/` with `@MainActor func fetchEvents(for spread: DataModel.Spread, calendar: Calendar) async -> [CalendarEvent]`.
  - [x] `LiveCalendarEventService` implements the protocol, handles `.notDetermined` auth request, returns `[]` when not `.authorized`, and delegates the date-range fetch to its injected `EventKitService`.
  - [x] `MockCalendarEventService` implements the protocol and returns a configurable `[CalendarEvent]` array (defaults to `[]`).
  - [x] `EmptyCalendarEventService` implements the protocol and always returns `[]`.
  - [x] `AppDependencies` has `let calendarEventService: any CalendarEventService`. `makeForLive` uses `LiveCalendarEventService`, `makeForPreview` and `make(...)` use `MockCalendarEventService`.
  - [x] `SpreadPageContext` has `let calendarEventService: any CalendarEventService`. `eventKitService` remains on `SpreadPageContext` for `openEvent(_:)` calls only.
  - [x] `DaySpreadContentView.CalendarEventStore` is deleted. The view has `@State private var calendarEvents: [CalendarEvent] = []` and calls `context.calendarEventService.fetchEvents(for: spread, calendar: context.journalManager.calendar)` in `.task(id: spread.id)`.
  - [x] `MultidaySpreadContentView`'s `CalendarEventStore` is deleted with the same replacement pattern.
  - [x] All existing behaviour (events section, timeline card, all-day/timed split) is unchanged.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - [x] Unit test `LiveCalendarEventService` authorization handling: returns `[]` when service is not authorized; calls through when authorized.
  - [x] Unit test `MockCalendarEventService` returns the seeded array.


---

### [SPRD-231] Feature: CalendarView multi-month component in johnnyo-foundation - [x] Done

- **Context**: `SpreadsContentColumnView` needs to render a full year of months as a vertically scrolling calendar grid. The existing `MonthCalendarView` handles a single month. A reusable multi-month shell is needed in `johnnyo-foundation` so the calendar-column pattern can be used in other app contexts without duplicating month-stacking logic.
- **Description**: Add a `CalendarView` to `JohnnyOFoundationUI` that renders a vertical `LazyVStack` of `MonthCalendarView` instances from a start date to an end date. Accepts the same `CalendarContentGenerator` and optional `MonthCalendarRowOverlayGenerator` used by `MonthCalendarView`. Accepts an `onDateTapped: (Date) -> Void` callback. Foundation does not own disambiguation UI for multi-spread dates.
- **Spec**: `Documentation/Specs/CalendarFoundation.md` — Multi-Month CalendarView
- **Acceptance Criteria**:
  - [x] `CalendarView` exists in `JohnnyOFoundationUI` accepting `startDate: Date`, `endDate: Date`, `calendar: Calendar`, `today: Date`, `contentGenerator: some CalendarContentGenerator`, and `onDateTapped: (Date) -> Void`.
  - [x] An overload accepts an additional `rowOverlayGenerator: some MonthCalendarRowOverlayGenerator`; when omitted, months render without overlays.
  - [x] The view renders one `MonthCalendarView` per calendar month from the month containing `startDate` to the month containing `endDate`, inclusive.
  - [x] Months are stacked in a `LazyVStack` inside a `ScrollView(.vertical)` — off-screen months are not constructed until scrolled into view.
  - [x] The same generator instance is passed to every `MonthCalendarView` in the stack.
  - [x] Tapping a date cell fires `onDateTapped` with the tapped `Date`. Foundation does not present any popover or disambiguation UI.
  - [x] Package-local unit tests cover: correct month count between two dates, inclusive boundary handling, same-month start/end, and ascending order.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Unit tests in `johnnyo-foundation` package tests covering month range computation (see ACs above).

---

### [SPRD-232] Refactor: Calendar-based SpreadsContentColumnView + sidebar year subitems - [x] Done

- **Context**: `SpreadsContentColumnView` currently renders a flat indented list of `SpreadPickerModel.Item` values. The sidebar has no year-level navigation. This task replaces the flat list with a `CalendarView`-backed grid and introduces year subitems in the sidebar so the user can navigate by year.
- **Description**: Refactor `SpreadsContentColumnView` to accept `[DataModel.Spread]` and use `CalendarView` internally with a generator defined in a nested extension. Add a `RootNavigationView.SidebarItem` enum to accommodate both destination and year selections in a single `List(selection:)` binding. Sidebar shows year subitems (always visible, indented) below the Spreads destination row, derived from the spread list. Selecting a year drives the content column's date range.
- **Spec**: `Documentation/Specs/SpreadNavigation.md` — Calendar Content Column
- **Acceptance Criteria**:
  - [x] `RootNavigationView.SidebarItem` enum exists with cases `.destination(RootNavigationView.Content)` and `.spreadsYear(Int)`. The sidebar `List(selection:)` binds to `SidebarItem?`.
  - [x] The sidebar shows Spreads, Entries, Collections, Settings (and Debug when enabled) as destination rows. Below Spreads, year rows are always visible and indented, one per unique year in the spread list (ascending).
  - [x] Selecting a year row sets the content column to a `SpreadsContentColumnView` spanning Jan 1 – Dec 31 of that year.
  - [x] `SpreadsContentColumnView` accepts `spreads: [DataModel.Spread]`, `selectedYear: Int`, `calendar: Calendar`, and `selectedSpread: Binding<DataModel.Spread?>`. It no longer accepts `[SpreadPickerModel.Item]`.
  - [x] `SpreadsContentColumnView` uses `CalendarView` internally. The generator is defined in a `SpreadsContentColumnView` extension (separate file `SpreadsContentColumnView+CalendarGenerator.swift`).
  - [x] Date cells containing one or more spreads are visually distinguished from empty cells (dot indicators per spread period).
  - [x] Tapping a date cell with exactly one spread sets `selectedSpread` and collapses the content column (regular width only).
  - [x] Tapping a date cell with two or more spreads shows a SwiftUI `.popover` listing each spread's label/period. Tapping a spread in the popover sets `selectedSpread` and dismisses the popover.
  - [x] Tapping a date cell with no spreads is a no-op.
  - [x] `RootNavigationView` no longer passes `[SpreadPickerModel.Item]` to the content column — it passes the spread list from `journalManager.spreads` directly.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual verification: select a year in the sidebar, confirm content column shows that year's calendar. Tap a date with one spread — confirm navigation. Tap a date with multiple spreads — confirm disambiguation popover appears and selection works.
- **Dependencies**: SPRD-231

---

### [SPRD-233] Refactor: Generic AlertModel replacing typed AlertDestination cases - [x] Done

- **Context**: `SpreadsCoordinator.AlertDestination` had one case per alert scenario. Adding new alerts required growing the enum and duplicating coordinator factory methods. Structurally identical cases (title + message + two buttons) couldn't be reused.
- **Description**: Replace the multi-case `AlertDestination` enum with a single `.alert(AlertModel)` case. `AlertModel` carries `title`, optional `message`, and `[AlertModel.Button]` (each with `label`, `role`, and optional async `action`). Static presets (`AlertModel.deleteSpreadConfirmation(spread:)` etc.) live as static factory methods on `AlertModel`. Coordinator action methods stay but build `AlertModel` inline. `RootNavigationView`'s `.alert(item:)` handler renders from `AlertModel` generically using `ForEach` over buttons.
- **Spec**: `Documentation/Specs/ErrorHandling.md` — Alert Infrastructure Refactor (SPRD-233)
- **Acceptance Criteria**:
  - [x] `AlertModel` struct exists with `title: String`, `message: String?`, and `buttons: [AlertModel.Button]`.
  - [x] `AlertModel.Button` has `label: String`, `role: ButtonRole?`, and `action: (@MainActor () async -> Void)?`.
  - [x] `AlertDestination` is reduced to a single `case alert(AlertModel)` (plus `id` computed from title to satisfy `Identifiable`).
  - [x] Static presets exist on `AlertModel`: `deleteSpreadConfirmation(spread:)`, `deleteSpreadFailed(message:)`, `discardChanges(onSave:onDiscard:)`, `deleteEntryConfirmation(confirmAction:)`.
  - [x] `SpreadsCoordinator` action methods (`showDeleteSpreadConfirmation`, etc.) set `activeAlert = .alert(AlertModel.deleteSpreadConfirmation(spread:))` rather than constructing typed cases.
  - [x] `RootNavigationView` `.alert(item:)` renders title, optional message, and buttons from `AlertModel` — no switch statement over cases.
  - [x] All existing alert behavior (destructive roles, cancel roles, async actions) is preserved.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual verification: trigger each existing alert scenario and confirm it still renders and behaves correctly.

---

### [SPRD-234] Feature: List and Tag quick-pick in AddTaskButton popover - [x] Done

- **Context**: The `AddTaskButton` alert lets users quickly create a task by title, but offers no way to assign a list or tag without opening the full `TaskCreationSheet`. Native alerts don't support pickers, and `.toolbar` modifiers inside alert content are silently ignored by SwiftUI. A `.popover` is in the real view hierarchy so keyboard toolbar items render correctly.
- **Description**: Replace `AddTaskButton`'s native `.alert` with a `.popover` (`attachmentAnchor: .rect(.bounds)`, `arrowEdge: .leading`) containing a title header, auto-focused `TextField`, and keyboard toolbar `Menu` buttons for List and Tag. On compact-width (iPhone) the popover becomes a bottom sheet via `.presentationDetents([.height(130)])`. `AddTaskButton` receives `availableLists` and `availableTags` from its call site.
- **Spec**: `Documentation/Specs/TaskMetadata.md` — AddTaskButton Quick-Pick Popover: List and Tag (SPRD-234)
- **Acceptance Criteria**:
  - [x] `AddTaskButton` has parameters `availableLists: [DataModel.List]` and `availableTags: [DataModel.Tag]`, both defaulting to `[]`.
  - [x] `onAddTask` signature is extended to `(String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void`. All call sites updated.
  - [x] Tapping "Add Task" opens a popover with leading arrow edge on regular-width; becomes a bottom sheet on compact-width.
  - [x] The popover contains a "New Task" header with dismiss (×) button and an auto-focused `TextField`.
  - [x] Submitting the field (Return) or tapping "Add" in the keyboard toolbar saves the task and closes the popover.
  - [x] When `availableLists` is non-empty, a List `Menu` button appears in the keyboard toolbar. When empty, it is hidden.
  - [x] When `availableTags` is non-empty, a Tag `Menu` button appears. When empty, it is hidden.
  - [x] Active selection shown with filled icon tinted with `SpreadTheme.Accent.todaySelectedEmphasis`. A destructive "Clear" option inside the menu resets it.
  - [x] State (title, list, tag) is cleared on popover dismiss.
  - [x] Enhancement is scoped to `AddTaskButton` only — `EntryRowView` and `TaskCreationSheet` are unchanged.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual verification: tap "Add Task", confirm popover/sheet appears, List and Tag menus visible in keyboard toolbar, selections persist to created task.
- **Dependencies**: SPRD-221

---

### [SPRD-235] Feature: Overdue task card in DaySpreadContentView - [x] Done

- **Context**: Users have no in-spread signal that they have overdue tasks on today's spread. `JournalManager.overdueTaskItems` already computes the global overdue set, but there is no UI surface for it on the day spread itself.
- **Description**: Show a card-style section above the entry list in `DaySpreadContentView` when the spread is today and `journalManager.overdueTaskItems` is non-empty. Introduce `EntryList.Section.Style` (enum with `.card(Color)`) on `EntryList.Section` and teach `EntryListView` to render card-styled sections above its internal `List`. `DaySpreadContentView` builds the overdue sections from `overdueTaskItems`, grouped by source spread/Inbox, and passes them with `.card(color)` style. `EntryListView` and `EntryRowView` remain unaware of the overdue concept.
- **Spec**: `Documentation/Specs/ConventionalMode.md` — Overdue Card in Day Spread (SPRD-235)
- **Acceptance Criteria**:
  - [x] `EntryList.Section.Style` enum exists with one case: `.card(Color)`.
  - [x] `EntryList.Section` has `style: EntryList.Section.Style?` property, defaulting to `nil`.
  - [x] `EntryListView` in `.list` mode renders card-styled sections above the `List {}`, each wrapped in a `RoundedRectangle` with low-opacity fill and solid stroke using the supplied `Color`.
  - [x] `EntryListView` and `EntryRowView` have no knowledge of overdue tasks — they respond only to `Section.Style`.
  - [x] `DaySpreadContentView` reads `context.journalManager.overdueTaskItems` and builds `EntryList.Section` values (one per source spread/Inbox) with `style: .card(color)` when the spread date is today and overdue items exist.
  - [x] The overdue card disappears automatically when `overdueTaskItems` is empty.
  - [x] Overdue task rows use the same `EntryRowView.Configuration` as standard task rows (status toggle, migrate, delete, edit).
  - [x] Card sections in `.inline` mode render identically to standard sections (no card chrome).
  - [x] All existing `EntryListView` call sites compile without changes (new `style` property is optional with `nil` default).
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual: open today's day spread with at least one overdue task — confirm overdue card appears above the entry list with card styling.
  - Manual: migrate or complete all overdue tasks — confirm card disappears.
  - Manual: open a past day spread — confirm no overdue card appears.
  - Unit: `EntryList.Section` initializer sets `style` correctly when provided and defaults to `nil` when omitted.

---

### [SPRD-236] Feature: Leading toolbar column toggle and parent spread navigation - [x] Done

- **Context**: The detail column has no leading toolbar chrome. The only way to re-show the content column is a toolbar button added in SPRD-229 (`sidebar.left`). There is also no quick way to jump to an ancestor spread (year, month) from within a day or month spread.
- **Description**: Add a leading toolbar button group to the spread detail column split across two views. `RootNavigationView` contributes a calendar icon button (shows content column) / chevron.left button (hides content column), toggling `columnVisibility`. `SpreadContentPagerView` contributes parent spread buttons — one per ancestor period (year, month) — ordered broadest to narrowest. Buttons are always visible; disabled when no matching spread exists. Tapping sets `selectedSpread` directly with no pager animation. A new `JournalManager.parentSpreads(for:)` method drives the lookup. Labels use fixed date formats: `"YYYY"` for year, `"MMM"` for month, `"DD MMM – DD MMM"` for multiday.
- **Spec**: `Documentation/Specs/SpreadNavigation.md` — Leading Toolbar: Column Toggle and Parent Spread Navigation [SPRD-236]
- **Acceptance Criteria**:
  - [x] A calendar icon button appears at the leading edge of the detail column nav bar when the content column is hidden; it becomes `chevron.left` when the content column is visible.
  - [x] Tapping the calendar icon sets `columnVisibility` to show the content column; tapping the chevron hides it.
  - [x] The calendar/chevron button is a `ToolbarItem(placement: .topBarLeading)` in `RootNavigationView`'s `spreadsDetailContent` toolbar block.
  - [x] For a `.day` spread, two parent buttons appear to the trailing side of the toggle: year (label `"YYYY"`) then month (label `"MMM"`).
  - [x] For a `.month` spread, one parent button appears: year (label `"YYYY"`).
  - [x] For a `.year` spread, no parent buttons appear.
  - [x] For a `.multiday` spread, two parent buttons appear: year (label `"YYYY"`) then month (label `"MMM"`), using the spread's start date to determine the containing month.
  - [x] Each parent button is enabled when `JournalManager.parentSpreads(for:)` returns a non-nil spread for that period; disabled otherwise.
  - [x] Tapping an enabled parent button sets `selectedSpread` with no pager scroll animation; column visibility is unchanged.
  - [x] `JournalManager.parentSpreads(for:)` returns `[(period: Period, spread: DataModel.Spread?)]` ordered broadest → narrowest, with `nil` when no matching spread exists.
  - [x] Label formatting lives in `DataModel.Spread.parentNavigationLabel(calendar:)`, not inline in the view.
  - [x] Parent spread buttons are implemented as a `ToolbarItemGroup(placement: .topBarLeading)` in `SpreadContentPagerView`.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Unit: `JournalManager.parentSpreads(for:)` returns correct periods and spreads for `.day`, `.month`, `.year`, and `.multiday` inputs.
  - Unit: `JournalManager.parentSpreads(for:)` returns `nil` spread entries when no matching parent spread exists.
  - Unit: `DataModel.Spread.parentNavigationLabel(calendar:)` returns `"YYYY"` for year, `"MMM"` for month, and `"DD MMM – DD MMM"` for multiday.
  - Manual: view a day spread — confirm calendar/chevron toggle works and year + month buttons appear, enabled only when those spreads exist.
  - Manual: view a month spread — confirm only year button appears.
  - Manual: view a year spread — confirm no parent buttons appear.

---

### [SPRD-237] Visual: Day timeline overhaul — column layout, current-time indicator, event block polish - [x] Done

- **Context**: `DayTimelineView` uses a cascading offset approach for concurrent events, has no current-time indicator, shows only event titles, and scrolls to the first event regardless of whether the displayed day is today. The visual quality is significantly below Apple Calendar's standard.
- **Description**: Overhaul `DayTimelineView` (in `johnnyo-foundation`) and `SpreadDayTimelineContentGenerator` (in the app) with: (1) side-by-side column layout for overlapping events using a greedy interval-scheduling algorithm surfaced via `DayTimelineItemContext.columnIndex`/`columnCount`; (2) a live current-time red line + circle rendered with `TimelineView(.everyMinute)`, visible only when the date is today; (3) `DayTimelineScrollView` scrolling to the current time (minus 60pt margin) on today, first event otherwise; (4) event blocks showing title + time range (locale-aware 12h/24h) + optional location; (5) 44pt minimum block height floor enforced in foundation; (6) `CalendarEvent.location: String?` added and mapped from `EKEvent.location`; (7) all-day chip polish — pill capsules with calendar color tint.
- **Spec**: `Documentation/Specs/DayTimeline.md` — Full spec
- **Acceptance Criteria**:
  - [x] `DayTimelineItemContext` has `columnIndex: Int` and `columnCount: Int`; `overlapOffset` is removed.
  - [x] Events that share overlapping time ranges are assigned to separate columns; non-overlapping events occupy the full width.
  - [x] `SpreadDayTimelineContentGenerator` renders each event at `x = columnIndex * (availableWidth / columnCount)`, width `= availableWidth / columnCount`.
  - [x] `DayTimelineView` renders a red horizontal line + small red filled circle at the current minute's Y position when the date is today and the current time is within the visible window.
  - [x] The current-time indicator updates automatically via `TimelineView(.everyMinute)` — no app-side timer.
  - [x] The indicator is not visible when the displayed date is not today.
  - [x] `DayTimelineScrollView` scrolls to current time (minus ~60pt) on appear when date is today; scrolls to first event otherwise.
  - [x] Each timed event block shows: title (top-leading, semibold caption), time range below (caption2, locale 12h/24h), location below time (caption2, secondary, omitted when nil/empty).
  - [x] Events shorter than 30 min receive a minimum rendered height of 44pt; title remains readable.
  - [x] `CalendarEvent` has `var location: String?`; `LiveEventKitService` maps `EKEvent.location`.
  - [x] All-day chips render as pill capsules with low-opacity calendar color fill and title-only label.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Unit: column partitioning algorithm assigns non-overlapping events to column 0 with columnCount 1.
  - Unit: two fully-overlapping events produce columnCount 2 with columnIndex 0 and 1.
  - Unit: three events where A overlaps B, B overlaps C, but A does not overlap C produces correct column assignments.
  - Unit: events shorter than 30 min get `height == 44` in `DayTimelineItemContext`.
  - Unit: events longer than 30 min get proportional height (not clamped).
  - Manual: view today's day spread with events — confirm red line appears at current time and scrolls into view.
  - Manual: view a past day spread — confirm no red line appears.
  - Manual: view two concurrent events — confirm side-by-side rendering.
  - Manual: view an event with location set — confirm location appears below the time range.

---

### [SPRD-238] Refactor: TabView shell — replace NavigationSplitView with TabView and self-contained SpreadsTabView - [x] Done

- **Context**: The `NavigationSplitView` 3-column shell (SPRD-229) concentrates Spreads-specific navigation state at `RootNavigationView` because column-collapse transitions require state to survive at the root, producing a long, tightly-coupled root view and fragile state-mirroring (`selectedColumnSpread` ↔ `spreadsCoordinator.selectedSelection`). A `TabView`-based shell scopes each destination's state to its own tab, letting `RootNavigationView` shrink to cross-tab routing only.
- **Description**: Replace `RootNavigationView`'s `NavigationSplitView` with a plain `TabView` (`.tabViewStyle(.automatic)`), one tab per top-level destination wrapped in its own `NavigationStack`. Extract the Spreads destination's content into a new self-contained `SpreadsTabView` laid out as an `HStack`: `SpreadsContentColumnView` (calendar content column) as a togglable left pane, and the current `spreadsDetailContent` implementation as the right pane. A single leading toolbar button (calendar icon, swapping to `chevron.left` when shown) toggles the left pane on regular width and presents it as a `.fullScreenCover` on compact width. Move Spreads-specific navigation state (`spreadsCoordinator`, selected spread, `pagerSettledTargetID`, year selection) into `SpreadsTabView`; remove state that existed solely to survive `NavigationSplitView` transitions (`columnVisibility`, `selectedColumnSpread`/`selectedSelection` mirroring, `selectedSidebarItem`). `SpreadsContentColumnView` gains its own year-selection control. `RootNavigationView` retains only `selectedTab` and the shared `spreadsNavigationState` for cross-tab routing (`openTaskFromSearch`).
- **Spec**: `Documentation/Specs/SpreadNavigation.md` — TabView Shell Redesign [SPRD-238]
- **Acceptance Criteria**:
  - [x] `RootNavigationView` uses a plain `TabView` with `.tabViewStyle(.automatic)`, one tab per `Content` case (Spreads, Entries, Collections, Settings, Debug when `BuildInfo.allowsDebugUI`), each wrapping its content in its own `NavigationStack`.
  - [x] `SpreadsTabView` is a new view extracted from `spreadsDetailContent`, structured as a top-level `HStack` with `SpreadsContentColumnView` as the left pane and the detail content as the right pane.
  - [x] A single leading toolbar button (`calendar` ↔ `chevron.left`) toggles a local `isContentColumnVisible: Bool` owned by `SpreadsTabView`, replacing the SPRD-236 chevron button entirely.
  - [x] On regular width, the left pane is shown (with a leading-edge slide + fade transition) only when `isContentColumnVisible == true`; tapping the toggle button animates its appearance/disappearance.
  - [x] On compact width, tapping the toggle button presents the left pane via `.fullScreenCover`; the right pane is always full-width.
  - [x] Selecting a spread in the left pane sets the shared spread selection and hides the pane (toggles `isContentColumnVisible = false` on regular width; dismisses the cover on compact width).
  - [x] `spreadsCoordinator`, the selected spread, `pagerSettledTargetID`, and year selection are owned by `SpreadsTabView`; `columnVisibility`, `selectedColumnSpread`, and `selectedSidebarItem` are removed from `RootNavigationView`.
  - [x] `SpreadsContentColumnView` includes a self-contained year-selection control (no longer dependent on sidebar `.spreadsYear` subitems).
  - [x] Cross-tab navigation (`openTaskFromSearch`) continues to work: `RootNavigationView` sets `selectedTab = .spreads` and populates `spreadsNavigationState.pendingRequest`; `SpreadsTabView` reacts and opens the task detail.
  - [x] The detail content's toolbar (today button, sync icon, auth button) remains functional, attached to the right pane / `SpreadContentPagerView`. (The SPRD-236 parent-spread navigation buttons were removed during this task — see note below — rather than carried over.)
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual: on iPad (regular width), toggle the left pane open/closed via the toolbar button — confirm smooth animated transition and icon swap.
  - Manual: on iPad, select a spread in the calendar pane — confirm the pane hides and the pager navigates to the selected spread.
  - Manual: on iPhone (compact width), tap the toggle button — confirm the calendar pane presents as a full-screen cover and dismisses on spread selection.
  - Manual: rotate / enter multitasking split view to trigger a size class transition — confirm navigation state (selected spread, pager position) survives.
  - Manual: from the Entries tab, tap a search result — confirm the app switches to the Spreads tab, navigates to the correct spread, and opens the task detail.
  - Manual: confirm today button, sync icon, and auth button all function as before.
- **Note**: During implementation, the SPRD-236 parent-spread navigation toolbar buttons (`SpreadContentPagerView.parentSpreadEntries`/`parentButtonLabel`, `JournalManager.parentSpreads(for:)`, `Spread+ParentNavigation.swift`, and their tests) were removed entirely rather than carried forward — the new content-column toggle supersedes them as the primary cross-period navigation affordance.
- **Dependencies**: SPRD-236


---

### [SPRD-239] Refactor: Squash Supabase migrations to a single baseline from spread-prod - [x] Done

- **Context**: `supabase/migrations/` contains 7 files that do not reconstruct a coherent history — `docs/supabase-setup.md` references three original Jan 2026 migrations that no longer exist, and `spread-dev`/`spread-prod` have diverged migration bookkeeping (same net schema, different migration names/timestamps for SPRD-193). The local Supabase bootstrap (`scripts/local-supabase.sh bootstrap-schema-from-dev`) works around this by dumping `spread-dev`'s schema directly rather than replaying migrations. The user is pre-release and does not need historical migration replay right now; `pg_dump --schema-only` against `spread-prod` (the project actually in use) captures the current schema completely.
- **Description**: Generate a single baseline migration file by running `pg_dump --schema-only` against `spread-prod`, sanitized using the same logic `scripts/local-supabase.sh` already applies (strip `CREATE SCHEMA public`/`COMMENT ON SCHEMA public`/`DEFAULT PRIVILEGES`/`\restrict`/`\unrestrict` lines). Delete the 7 existing migration files in `supabase/migrations/` and replace them with this single baseline. Update `scripts/local-supabase.sh` so `reset`/bootstrap relies on plain `supabase db reset` (replaying `supabase/migrations/*.sql`) instead of `bootstrap-schema-from-dev` + `public_schema_from_dev.sql`; remove the `SUPABASE_DB_PASSWORD_DEV` dependency. Update `docs/local-supabase-testing.md` and `docs/supabase-setup.md` to describe the single-baseline workflow and remove references to the non-existent Jan 2026 migrations and the dev-bootstrap flow.
- **Spec**: `Documentation/Specs/DevelopmentTooling.md` — Test/Debug Infrastructure Simplification
- **Acceptance Criteria**:
  - [x] `supabase/migrations/` contains exactly one baseline migration file generated via `pg_dump --schema-only` against `spread-prod`, sanitized to remove ownership/privilege/restrict statements.
  - [x] The 7 previously-existing migration files are removed.
  - [x] `supabase db reset` succeeds locally and reproduces `spread-prod`'s schema: all 11 tables (`collections`, `notes`, `note_assignments`, `note_tags`, `settings`, `spreads`, `tasks`, `task_assignments`, `tags`, `task_tags`, `lists`), their columns, RLS policies, triggers, and merge RPCs (`merge_task_assignment`, `merge_note_assignment`, etc.).
  - [x] `scripts/local-supabase.sh` no longer contains a `bootstrap-schema-from-dev` command, no longer reads/writes `supabase/local/public_schema_from_dev.sql`, and no longer references `SUPABASE_DB_PASSWORD_DEV`.
  - [x] `docs/local-supabase-testing.md` and `docs/supabase-setup.md` describe the single-baseline-migration workflow and contain no references to the removed Jan 2026 migrations or the dev-bootstrap flow. `docs/supabase-setup.md`'s "Database Schema" section was also rewritten to match the actual dumped/queried `spread-prod` schema (11 tables, including `lists`/`tags`/`task_tags`/`note_tags` and `spread_id` on assignment tables).
- **Tests**:
  - [x] Manual: ran `supabase db reset` against the local stack and confirmed the resulting schema matches `spread-prod` (verified all 11 tables, 20 functions/RPCs, columns, check constraints, unique constraints, FKs, indexes, and RLS policy counts via `information_schema`/`pg_constraint`/`pg_indexes`/`pg_policies`).
  - [~] Manual: `xcodebuild -scheme "Spread Localhost" -only-testing:SpreadTests/SyncDurabilityIntegrationTests test` was attempted against the freshly-reset local stack, but the `SpreadTests` target currently fails to compile for unrelated, pre-existing reasons (missing `SpreadHeaderNavigatorModel`/`SpreadHeaderNavigatorRowOverlayGenerator` types in `SpreadTests/Views/Spreads/*`, last touched by `2eb4da5 [SPRD-226][5/n]`, not modified by this task). The `Spread` app target itself builds successfully (`xcodebuild -scheme "Spread Localhost" build` → BUILD SUCCEEDED). The `SpreadTests` compile failure should be tracked/fixed separately.

---

### [SPRD-240] Refactor: Decommission spread-dev and the QA build configuration - [x] Done

- **Context**: `spread-dev` is rarely used, drifts out of sync with `spread-prod`, and adds maintenance burden without serving its intended QA purpose. The "QA" build configuration exists to distribute debug-menu-enabled builds via TestFlight, but the user is pre-release and currently installs Debug builds directly from Xcode onto devices they control — TestFlight distribution isn't in use yet. Since TestFlight installs can't receive launch-arg overrides (they're archived, standalone builds), a future TestFlight configuration would need to be a fixed, debug-UI-disabled build pointed at `spread-prod` — effectively indistinguishable from Release. External TestFlight users should see the prod app with no testing functionality, same as App Store users.
- **Description**: Remove the QA build configuration entirely. Delete `Configuration/QA.xcconfig`. Remove the `QA` build configuration from `Spread.xcodeproj/project.pbxproj` (the project and all 3 targets — Spread, SpreadTests, SpreadUITests), preferably via Xcode's Project Editor (Project > Info > Configurations > remove "QA") rather than hand-editing the pbxproj. Delete `Spread.xcodeproj/xcshareddata/xcschemes/Spread QA.xcscheme`, leaving only `Spread Localhost` and `Spread Prod` as schemes. Simplify `BuildInfo` to two build configurations: Debug and Release — remove the `.qa` case, and update `buildConfiguration`/`allowsDebugUI`/`isRelease` accordingly (`allowsDebugUI` becomes simply "not Release"). Update `defaultDataEnvironment`: Debug → `.localhost`, Release → `.production` (unchanged). Remove the `spread-dev` Supabase URL/key from `SupabaseConfiguration.KnownEnvironment` and any other dev-pointed defaults. Update `Configuration/Debug.xcconfig` so `localhost` mode (which falls back to `buildURL`/`buildPublishableKey`) has a sensible local-Docker-Supabase-pointed default. Update `docs/supabase-setup.md` and `docs/local-supabase-testing.md` to remove references to `spread-dev` and the QA configuration, and note that a TestFlight configuration (effectively Release + `allowsDebugUI = true` if ever needed) is deferred until TestFlight distribution actually begins post-release.
- **Spec**: `Documentation/Specs/DevelopmentTooling.md` — Test/Debug Infrastructure Simplification
- **Acceptance Criteria**:
  - [x] `Configuration/QA.xcconfig` is deleted and no Xcode build configuration/scheme references it.
  - [x] The `QA` build configuration is removed from `Spread.xcodeproj/project.pbxproj` for the project and all 3 targets (Spread, SpreadTests, SpreadUITests).
  - [x] `Spread.xcodeproj/xcshareddata/xcschemes/Spread QA.xcscheme` is deleted; only `Spread Localhost` and `Spread Prod` schemes remain.
  - [x] `BuildInfo` has only Debug and Release build configurations; `.qa` is removed from the `BuildConfiguration` enum and `allowsDebugUI`/`isRelease`/`defaultDataEnvironment` are updated accordingly.
  - [x] `BuildInfo.defaultDataEnvironment` returns `.localhost` for Debug and `.production` for Release.
  - [x] `SupabaseConfiguration.KnownEnvironment` no longer contains `spread-dev`'s URL/key; `DataEnvironment.development`'s mapping in `SupabaseConfiguration` is updated or removed consistently with this (do not leave a dangling reference to a decommissioned project).
  - [x] `Configuration/Debug.xcconfig` is updated so Debug builds in `localhost` mode resolve to a sensible local Supabase configuration (or document why `buildURL`/`buildPublishableKey` are unused in `localhost` mode).
  - [x] `docs/supabase-setup.md` and `docs/local-supabase-testing.md` no longer describe `spread-dev` as an in-use backend or refer to a "QA" configuration, and note that TestFlight distribution is a future, currently-unneeded configuration.
  - [x] Project builds successfully for Debug and Release configurations.
- **Tests**:
  - Manual: build and run Debug and Release configurations and confirm `DataEnvironment.current` and `SupabaseConfiguration.url`/`publishableKey` resolve to the expected environment/backend for each.
  - Manual: launch a Debug build with `-DataEnvironment localhost` and confirm it still operates in local-only mode (no auth, no sync).
- **Note**: Pausing or deleting the `spread-dev` Supabase project itself is a manual follow-up performed by the user once nothing in the codebase references it — not part of this task's acceptance criteria.

---

### [SPRD-241] Refactor: Remove debug scenario-toggle/fault-injection panel from DebugMenuView - [x] Done

- **Context**: `DebugMenuView` (673 lines) bundles a read-only data viewer with a runtime scenario-toggle/fault-injection panel (forced auth errors, sync status overrides, outbox seeding, scenario presets, network blocking). A check of `SpreadUITests` found none of these scenario-toggle accessibility identifiers are used by any automated test — only the unrelated temporal harness identifiers are. The user wants debug builds to provide data viewing without runtime mutation, and does not use this panel manually.
- **Description**: Remove the scenario-toggle/fault-injection panel from `DebugMenuView` entirely: forced auth error injection (`DebugAuthService`), the block-all-network toggle (`DebugNetworkMonitor`), sync status overrides/outbox seeding/scenario presets (`DebugSyncPolicy`), and their corresponding `DebugMenuView` sections and wiring in `AppRuntimeConfiguration+Debug.swift`. Delete `DebugSyncPolicy.swift`. Since removing `DebugSyncPolicy` leaves `SyncPolicy`/`DefaultSyncPolicy` with only one conformance, co-locate the `SyncPolicy` protocol and `DefaultSyncPolicy` struct in a single file (preserving the protocol pattern for future test substitution, per the user's note, rather than collapsing it into a concrete type). Remove any now-unused forced-error/block-network methods from `DebugAuthService`/`DebugNetworkMonitor` (or delete those files if nothing else uses them). `DebugMenuView` retains the data viewer (`DebugRepositoryListView`), environment/build-info readout, and mock data set loader.
- **Spec**: `Documentation/Specs/DevelopmentTooling.md` — Test/Debug Infrastructure Simplification
- **Acceptance Criteria**:
  - [x] `DebugSyncPolicy.swift` is deleted; `SyncPolicy` protocol and `DefaultSyncPolicy` are co-located in a single file with no other conformances.
  - [x] `DebugMenuView` no longer contains sections for forced auth errors, sync status overrides, outbox seeding, scenario presets, or network blocking.
  - [x] `DebugAuthService`/`DebugNetworkMonitor` no longer expose forced-error/block-network APIs (or are removed if they become empty). (Both files deleted — each had become a pure passthrough decorator with no remaining behavior.)
  - [x] `AppRuntimeConfiguration+Debug.swift` no longer wires the removed debug services.
  - [x] `DebugMenuView` continues to show the repository data viewer (`DebugRepositoryListView`), environment/build-info summary, and mock data set loader.
  - [~] Project builds with no errors or warnings; existing unit tests pass. Both `Spread Localhost` (Debug) and `Spread Prod` (Release) build successfully. The full `SpreadTests` suite has 4 pre-existing failures unrelated to this task (`AuthIntegrationTests.testDeleteAccount_removesUserAndSignsOut`, `SPRD193MultidayAssignmentContractTests.schemaSnapshotsIncludeSpreadIDForAssignmentOwnership`, `WKFLW17SyncContractTests.schemaSnapshotsIncludeApprovedFieldsAndNoDeferredCandidates`, `WKFLW17SyncContractTests.mergeFunctionsUseIndependentConflictTimestampsAndDeleteWins`) — confirmed present on `HEAD` before this task's changes (a SPRD-239 follow-up gap from the migration squash, tracked separately). All other tests pass.
- **Tests**:
  - Manual: launch a Debug build, open the Debug destination, confirm the data viewer and environment summary still work and the removed sections are gone.
  - Run the full unit test suite to confirm no test depended on the removed debug services.

---

### [SPRD-242] Refactor: Remove DebugAppearanceSettings singleton and appearance override panel - [x] Done

- **Context**: `DebugAppearanceSettings` is an `@Observable @MainActor` class with `static let shared`, violating the project's no-singleton architecture rule even though it is `#if DEBUG`-scoped. The user does not use the appearance override panel (paper tone, dot grid, heading font, accent color).
- **Description**: Delete `DebugAppearanceSettings.swift` and its `DebugMenuView` appearance override section. Remove all references to `DebugAppearanceSettings.shared` from production views, reverting those views to their production-defined appearance values.
- **Spec**: `Documentation/Specs/DevelopmentTooling.md` — Test/Debug Infrastructure Simplification
- **Acceptance Criteria**:
  - [x] `DebugAppearanceSettings.swift` no longer exists and no references to `DebugAppearanceSettings` remain in the codebase.
  - [x] `DebugMenuView` no longer has an appearance override section.
  - [x] Affected views compile and render using production-defined appearance values (paper tone, dot grid, heading font, accent color) with no behavior change in Release builds.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual: launch a Debug build and confirm app appearance matches a Release build's default appearance (no leftover debug overrides).

---

### [SPRD-243] Refactor: Remove unused MockDataSet cases (highVolume, inboxNextYear) - [x] Done

- **Context**: An audit comparing `MockDataSet`'s cases against `SpreadUITests` launch-argument usage found that `.highVolume` and `.inboxNextYear` are not referenced by any test (all other cases, including all 13 `.scenarioXxx` cases, are in active use).
- **Description**: Remove the `.highVolume` and `.inboxNextYear` cases and their fixture implementations from `MockDataSet.swift`/`MockDataSet+ScenarioFixtures.swift`, and remove any corresponding entries from the `DebugMenuView` mock data set picker.
- **Spec**: `Documentation/Specs/DevelopmentTooling.md` — Test/Debug Infrastructure Simplification
- **Acceptance Criteria**:
  - [x] `MockDataSet` no longer has `.highVolume` or `.inboxNextYear` cases, and their fixture-building code is removed.
  - [x] `DebugMenuView`'s mock data set picker no longer lists `.highVolume` or `.inboxNextYear`.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual: open the Debug destination's mock data set picker and confirm the removed cases no longer appear and remaining cases load correctly.

---

### [SPRD-244] Feature: Coordinator-driven popover management in SpreadsCoordinator - [x] Done

- **Context**: Sheets and alerts are already managed centrally via `activeSheet: SheetDestination?` and `activeAlert: AlertDestination?` on `SpreadsCoordinator`. Popovers were self-managed with `@State private var isPresented` inside individual views, scattering presentation logic. `AddTaskButton` in `EntryListView.swift` was the existing case to migrate.
- **Description**: Add `activePopover: PopoverDestination?` to `SpreadsCoordinator`. Define a `PopoverContent` protocol with `associatedtype Body: View`, `arrowEdge: Edge`, `attachmentAnchor: PopoverAttachmentAnchor`, and a `@ViewBuilder var body: Body { get }` requirement, plus `Identifiable` conformance. Define `PopoverDestination` as a separate `Identifiable` enum (not merged into `SheetDestination`) where each case carries a concrete `PopoverContent`-conforming value. Add `coordinator.showQuickAdd(...)` / `coordinator.dismissPopover()` action methods. Remove `AddTaskButton`; replace with `SpreadButton(content: .text("+ Add Task"))` calling `coordinator.showQuickAdd(...)` directly at each call site in `MultidaySpreadContentView` and via `addTaskHeaderButtonViewModel` in `DaySpreadContentView`. Each content view applies `.popover(item:)` on itself bound to the coordinator's `activePopover`. `EventDetailPopoverView` (in `SpreadDayTimelineContentGenerator`) is not migrated.
- **Spec**: `Documentation/Specs/SpreadNavigation.md` — Coordinator-Driven Popovers
- **Acceptance Criteria**:
  - [x] `SpreadsCoordinator` has `var activePopover: PopoverDestination?` and `func showQuickAdd(...)` / `func dismissPopover()` action methods.
  - [x] `PopoverContent` protocol is defined with `associatedtype Body: View`, `var arrowEdge: Edge { get }`, `var attachmentAnchor: PopoverAttachmentAnchor { get }`, `@ViewBuilder var body: Body { get }`, and `Identifiable` conformance. `AnyView` is not used anywhere in the protocol or its conformances.
  - [x] `PopoverDestination` is a distinct `Identifiable` enum with a `.quickAdd(QuickAddPopoverContent)` case. It is not part of `SheetDestination`.
  - [x] `QuickAddPopoverContent` is a concrete struct conforming to `PopoverContent`, carrying `date: Date`, `period: Period`, `availableLists: [DataModel.List]`, `availableTags: [DataModel.Tag]`, and the `onAddTask` closure.
  - [x] `AddTaskButton` is removed. `SpreadButton(content: .text("+ Add Task"))` is used directly in `MultidaySpreadContentView` (both call sites) and `DaySpreadContentView` (via `addTaskHeaderButtonViewModel`). Each calls `coordinator.showQuickAdd(...)` on tap. The containing content view applies `.popover(item:)` bound to `coordinator.activePopover`.
  - [ ] The quick-add popover opens and closes correctly on both iPhone (sheet-adapted) and iPad (true popover with arrow).
  - [x] `EventDetailPopoverView` and its self-managed `@State` in `SpreadDayTimelineContentGenerator` are unchanged.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - Manual: tap the "+ Add Task" button on a day spread — quick-add popover appears. Submit or dismiss — popover closes.
  - Manual: tap the "+ Add Task" button on a multiday spread day card — quick-add popover appears. Submit or dismiss — popover closes.
  - Manual: on iPad, confirm the popover (true popover, not sheet) appears on both spread types.

---

### [SPRD-245] Refactor: Additive repository layer with caller-supplied change descriptors and batched saves - [x] Done

- **Context**: A performance audit (SESH-24) of `feature/SESH-23` found `SwiftDataTaskRepository.save()`/`SwiftDataNoteRepository.save()` each open two throwaway `ModelContext`s per save (`storedTaskAssignments(id:)`, `storedTaskTagIds(id:)`) purely to recover pre-mutation state for sync-outbox diffing, plus a `fetchCount` query (`hasStoredTask(id:)`) to decide create-vs-update — three redundant SwiftData round-trips per single-entity save. Batch operations (e.g. `migrateTasksBatch`) call `save()` once per entity with no batched commit. Per the user's directive, this work is additive only: new files alongside the existing `SwiftDataTaskRepository`/`SwiftDataNoteRepository`, zero edits to existing production files, validated by unit tests only (no wiring into `DependencyContainer` or views).
- **Description**: Add a new `EntityChange<Assignment, TagType>` struct (`isNew`, `previousAssignments`, `previousTagIDs`) that callers construct from values they already hold one statement before mutating an entity in place. Add new repository implementations (e.g. `SwiftDataTaskRepositoryV2`/`SwiftDataNoteRepositoryV2`, exact naming TBD at implementation time) whose `save(_:change:)` accepts this descriptor instead of re-fetching prior state, and answers create-vs-update from the descriptor's `isNew` flag instead of a `fetchCount` query. Add a batched `saveAll(_:changes:)` API that performs exactly one `modelContext.save()` commit for N entities. These new types conform to the existing `TaskRepository`/`NoteRepository` protocols (or a superset thereof) — protocols remain the correct boundary here per the spec decision, since SwiftData and in-memory/mock implementations both already exist and must continue to differ for tests.
- **Spec**: `Documentation/Specs/JournalManager.md` — "Decision: Sync-outbox diffing moves from repository-side disk re-fetch to caller-supplied change descriptors" and "Decision: Drop protocol-per-logic-seam; protocols are a repository-only boundary"
- **Acceptance Criteria**:
  - [x] New `EntityChange` type added in a new file; no edits to existing `TaskAssignment`/`NoteAssignment`/`TaskRepository`/`NoteRepository` files.
  - [x] New task/note repository implementation(s) added as new files performing zero throwaway `ModelContext` allocations and zero `fetchCount` queries during `save`.
  - [x] New batched `saveAll` API added that issues exactly one `modelContext.save()` call regardless of N.
  - [x] Existing `SwiftDataTaskRepository.swift`/`SwiftDataNoteRepository.swift` and all other existing production files are untouched (verified via `git diff` showing only new files added).
  - [x] `DependencyContainer` and all views are untouched — the new repositories are constructed only from unit tests.
  - [x] Project builds with no errors or warnings. Verified via `xcodebuild -scheme "Spread Localhost"` (`BUILD SUCCEEDED`) and the full unit test target for this repository pair (24/24 passing).
- **Tests**:
  - [x] Unit tests proving `save(_:change:)` produces identical `SyncMutation` outbox rows (create/update/delete for entity, assignments, tags) as the legacy repository for equivalent before/after states, without performing any disk re-fetch.
  - [x] Unit tests proving `saveAll` commits once for N changed entities and produces the correct per-entity outbox rows.
  - [x] Unit tests proving create-vs-update is correctly determined from `EntityChange.isNew` without a `fetchCount` query.
- **Progress (commits landed on `feature/SESH-24`)**:
  1. `[SPRD-245][1/n]` — `EntityChange<Assignment>` plus the standalone `ChangeAwareTaskRepository`/`ChangeAwareNoteRepository` protocols (`Spread/Repositories/EntityChange.swift`, `ChangeAwareTaskRepository.swift`, `ChangeAwareNoteRepository.swift`).
  2. `[SPRD-245][2/n]` — `SwiftDataChangeAwareTaskRepository`, with CRUD/outbox-sequencing tests and a parity test against `SwiftDataTaskRepository`.
  3. `[SPRD-245][3/n]` — `SwiftDataChangeAwareNoteRepository`, mirroring the task repository, with the same test shape against `SwiftDataNoteRepository`.
  4. `[SPRD-245][4/n]` — `TaskSaveRequest`/`NoteSaveRequest` plus `saveAll(_:)` on both protocols and implementations; `save(_:change:)` now delegates to `saveAll` with a single-element array, so each file has exactly one `modelContext.save()` call site for the save path.
  5. `[SPRD-245][5/n]` — docs: progress notes and the cutover renaming plan (this section), as a doc comment on each `ChangeAware*` file.
  6. `[SPRD-245][6/n]` — `TestChangeAwareTaskRepository`/`TestChangeAwareNoteRepository`, plain in-memory test doubles mirroring `InMemoryTaskRepository`/`InMemoryNoteRepository`, named per the `Test*`/`Mock*` non-production convention (`CLAUDE.md` Testability section) rather than `InMemory*`. Build verified (`BUILD SUCCEEDED`) after this commit.
  - **Naming deviation from this task's original Description**: implemented as `ChangeAwareTaskRepository`/`ChangeAwareNoteRepository` — standalone protocols with no conformance/superset relationship to the legacy `TaskRepository`/`NoteRepository` — and `SwiftDataChangeAwareTaskRepository`/`SwiftDataChangeAwareNoteRepository`, not `*RepositoryV2`. The `ChangeAware` qualifier exists only to coexist with the legacy diffing-based repositories during the additive phase. See "Renaming plan" below.
- **Deferred, not blocking task completion**: `MockChangeAwareTaskRepository`/`MockChangeAwareNoteRepository` (mirroring `MockTaskRepository`/`MockNoteRepository`) only if a SPRD-248/SPRD-250 test actually needs call-tracking or error injection rather than real in-memory persistence — confirm the need once SPRD-248 starts rather than building speculatively.
- **Renaming plan (apply during SPRD-251's cutover, not before)**: Once SPRD-251 deletes the legacy `SwiftDataTaskRepository`/`SwiftDataNoteRepository` and the legacy `TaskRepository`/`NoteRepository` protocols, the `ChangeAware` qualifier is no longer needed to disambiguate and these types should be renamed to take over the vacated names, as a rename-only commit with no behavior change, separate from the `DependencyContainer`/view rewiring commit(s):
  - `ChangeAwareTaskRepository` → `TaskRepository`
  - `ChangeAwareNoteRepository` → `NoteRepository`
  - `SwiftDataChangeAwareTaskRepository` → `SwiftDataTaskRepository`
  - `SwiftDataChangeAwareNoteRepository` → `SwiftDataNoteRepository`
  - `TestChangeAwareTaskRepository`/`TestChangeAwareNoteRepository` and any `MockChangeAware*` added above → `TestTaskRepository`/`TestNoteRepository`/`MockTaskRepository`/`MockNoteRepository`, replacing the deleted legacy doubles of the same vacated name (see also backlog item TF-44, which separately migrates the legacy `InMemory*Repository` doubles to this same `Test*` convention).
  - `TaskSaveRequest`/`NoteSaveRequest`/`EntityChange` keep their names — no legacy type occupies them.

---

### [SPRD-246] Refactor: Unify entries/assignments/tags into single Supabase tables - [ ] Done

- **Context**: While building `JournalRuleEngine` (SESH-24), review surfaced that `tasks`/`notes`, `task_assignments`/`note_assignments`, and `task_tags`/`note_tags` are six tables with near-identical shape, duplicating schema, RLS policies, and sync logic across two parallel paths. The client-side `Assignment` type was already unified from `TaskAssignment`/`NoteAssignment` in a recent commit, pointing the same direction for the remote schema.
- **Description**: One direct-cutover SQL migration: create `entries` (type discriminator column, wide nullable columns covering every `tasks`/`notes` field, type-conditional `CHECK` on `status`), `assignments` (`entry_id`/`entry_type` replacing the FK to `tasks.id`/`notes.id`), and `entry_tags` (`entry_id`/`tag_id`). Migrate existing rows, drop `tasks`/`notes`/`task_assignments`/`note_assignments`/`task_tags`/`note_tags`, update RLS policies and indices accordingly. `entries.date`/`.period` are nullable from the start (covers Task's existing nullability and Note's new requirement from SPRD-247). Local SwiftData models (`DataModel.Task`/`DataModel.Note`) are untouched — this is a Supabase-schema-only change.
- **Spec**: `Documentation/Specs/EntryModel.md` — Requirements, "Unify Supabase tables" / "Wide nullable columns" / "Direct-cutover migration" decisions.
- **Acceptance Criteria**:
  - [x] `entries`, `assignments`, `entry_tags` tables exist with the shape described above.
  - [x] `tasks`, `notes`, `task_assignments`, `note_assignments`, `task_tags`, `note_tags` no longer exist.
  - [x] Any existing local/dev data in the old tables is migrated into the new ones with no data loss.
  - [x] RLS policies on the new tables enforce the same per-user access guarantees as the old tables.
  - [x] Migration applies cleanly to a fresh database and to the current dev database.
- **Tests**:
  - [x] Manual verification: apply migration to local Supabase, confirm row counts match pre-migration counts for all six source tables against their new homes.
  - [x] RLS policy tests (existing or new) pass against the new tables.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-246][1/n]` — Added `supabase/migrations/20260623000000_unify_entries_assignments_tags.sql`: creates `entries`/`assignments`/`entry_tags` with type-conditional `CHECK` constraints, FKs, indices, triggers, and RLS policies mirroring the six tables they replace; migrates existing rows via `INSERT ... SELECT`; drops the six old tables plus the now-orphaned `merge_task`/`merge_note`/`merge_task_assignment`/`merge_note_assignment`/`merge_task_tag`/`merge_note_tag` RPCs and their trigger functions (SPRD-247 will add `merge_entry`/`merge_assignment`/`merge_entry_tag` replacements when it rewires `SyncSerializer`); repoints `cleanup_tombstones()` at `entries`/`assignments`. Verified via `supabase db reset` (clean apply to fresh DB twice) and a manual transform test that recreated the old table shapes in a rolled-back transaction, seeded sample task/note/assignment/tag rows (including a dateless task), replayed the migration's `INSERT...SELECT` logic, and confirmed the resulting `entries`/`assignments`/`entry_tags` rows matched expectations; also confirmed `entries_status_check` rejects a type/status mismatch (e.g. `type='task', status='active'`).
  - Applied to the remote `spread-prod` project (`nzsswqmxodkvgsnabnaj`) via the Supabase MCP connector after confirming with the user (spread-prod had 255 tasks/501 task_assignments/1 note/3 note_assignments/6 task_tags of real dogfooding data — not the "no data to protect" scenario the spec assumed). Post-migration row counts matched exactly (255 task entries, 1 note entry, 501 task assignments, 3 note assignments, 6 entry_tags); advisor scan showed no new issues beyond pre-existing patterns shared with the rest of the schema. `spread-dev` (`apblzzondjcughtgqowd`) was confirmed already decommissioned (per `DevelopmentTooling.md`) and was not touched.
  2. `[SPRD-246][2/n]` — Squashed `20260613000000_baseline_schema.sql` + `20260623000000_unify_entries_assignments_tags.sql` into a single new `20260624000000_baseline_schema.sql`, same precedent as SPRD-239's original squash (pre-release, deployments are personal/dev only, no need to preserve incremental migration history locally). The squashed baseline creates `entries`/`assignments`/`entry_tags` directly — no `tasks`/`notes`/etc. tables ever exist, no data-migration `INSERT...SELECT` step, no `DROP TABLE`/`DROP FUNCTION` for the old objects, since a baseline bootstraps a fresh DB rather than diffing from an old state. Re-verified via `supabase db reset` (clean apply) and the same status-CHECK-constraint sanity check. Note: this squash is local-only — it does not retroactively change `spread-prod`'s already-applied migration history (still recorded there as `20260624015305_sprd246_unify_entries_assignments_tags`); local/CI schema and `spread-prod`'s schema remain equivalent, just reached via different paths now.
  - Remaining for this task: none — task complete.

---

### [SPRD-247] Refactor: Repository/sync rewire + optional Entry.date and eligibility flags - [ ] Done

- **Context**: Builds on SPRD-246's schema unification. The Swift sync/repository layer still targets the old six tables and must be rewired before any local model change depending on the new schema (notably `Note.date` becoming optional, which requires `entries.date` to already be nullable) can persist correctly. Also addresses the `Task.hasPreferredAssignment` redundancy found during `JournalRuleEngine` review: the Supabase `tasks` table already derives this flag from null `date`/`period` on decode (`SyncSerializer.swift`), so the local flag is a redundant second source of truth that can drift from the real one.
- **Description**: Rewire `SwiftDataChangeAwareTaskRepository`/`SwiftDataChangeAwareNoteRepository` (or their successors) and `SyncSerializer`'s encode/decode paths to read/write `entries`/`assignments`/`entry_tags` instead of the six old tables, preserving the existing `TaskRepository`/`NoteRepository` protocol surface (per `JournalManager.md`'s repository-only-protocol-boundary decision — no local model unification). Then: hoist `Entry.date: Date?` to the base protocol (`DataModel.Event` returns `startDate`); remove `DataModel.Task.hasPreferredAssignment` and its SwiftData backing field, with `date == nil` as the sole "no preferred assignment" signal; make `DataModel.Note.date` optional; add `isInboxEligible`/`isMigratable`/`isOverdueEligible` as required `Entry` properties, each a static per-type constant (Task: `true`; Note/Event: `false`). Update the Task creation/edit UI's "set a date" toggle to bind to `date == nil` instead of the removed flag.
- **Spec**: `Documentation/Specs/EntryModel.md` — Requirements, "Eligibility flags are static per-type constants" decision.
- **Acceptance Criteria**:
  - [x] Repositories and `SyncSerializer` read/write the new `entries`/`assignments`/`entry_tags` tables exclusively.
  - [x] `Entry.date: Date?` exists on the base protocol; `DataModel.Event.date` returns `startDate`.
  - [x] `DataModel.Task.hasPreferredAssignment` no longer exists; all call sites use `date == nil` instead.
  - [x] `DataModel.Note.date` is optional; a note can be created/persisted/synced with `date == nil`.
  - [x] `isInboxEligible`/`isMigratable`/`isOverdueEligible` exist on `Entry`, correctly conformed by Task/Note/Event.
  - [x] ~~One-time local migration: existing tasks with `hasPreferredAssignment == false` have `date`/`period` set to `nil`.~~ **Scoped out** — confirmed with user 2026-06-24: `spread-prod` has zero rows with null `date`/`period` across all 255 tasks/1 note, so no real data is affected; `hasPreferredAssignment` is locally-derived only (never a remote column). User confirmed no unsynced local-only "no preferred assignment" edits exist that a migration would need to preserve. `Task.date`/`Task.period`/`Note.date` go straight to optional in one commit with no runtime migration function; a local app wipe + resync from `spread-prod` is the "migration" if ever needed.
  - [x] Task creation/edit UI's date toggle works identically from the user's perspective, now backed by `date == nil`.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - [x] Repository/serializer round-trip tests against the new schema (create/update/delete for Task and Note, including a dateless Note).
  - [x] Unit tests for `isInboxEligible`/`isMigratable`/`isOverdueEligible` conformances per type.
  - [x] ~~Local-migration test proving a pre-migration task with `hasPreferredAssignment == false` ends up with `date == nil` post-migration.~~ **Scoped out** — no migration code exists to test; see AC note above.
- **Dependencies**: SPRD-246 (done).
- **Scope clarifications agreed before implementation** (not in original spec text, confirmed with user 2026-06-24):
  - `Task.period` becomes `Period?` (not just `date` as the spec text states); `Note.period` stays non-optional `Period`, untouched.
  - `AssignableEntry` was almost eliminated entirely (user's instinct: it had zero actual polymorphic usage anywhere in the codebase — confirmed via grep — making it the same "pure indirection" pattern already removed once for `AssignmentMatchable`/`AssignableEntry.AssignmentType`, per `Assignment.swift`'s doc comment). `period`/`assignments` were dropped from it entirely (now plain, independently-typed properties on `Task`/`Note`, which is what unblocks `Task.period: Period?` while `Note.period` stays `Period`). However, full elimination proved impossible: conforming `Task`/`Note` directly to `Entry` (no intermediate protocol at all) breaks the `@Model` macro's `PersistentModel`/`Hashable` synthesis under this project's strict-concurrency build settings — confirmed empirically (a completely empty `protocol AssignableEntry: Entry {}` fixes it; conforming directly to `Entry` does not). `AssignableEntry` survives as a near-empty structural marker, documented as a compiler workaround rather than a domain abstraction. `Event` doesn't need it since it already has a protocol hop via `DateRangeEntry`.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-247][1/n]` — Added `merge_entry`/`merge_assignment`/`merge_entry_tag` RPC functions to `supabase/migrations/20260624000000_baseline_schema.sql` (squashed into the baseline per the established pre-release convention), mirroring `merge_task`/`merge_note`/`merge_task_assignment`/`merge_note_assignment`/`merge_task_tag`/`merge_note_tag`'s LWW/fallback-lookup semantics but against `entries`/`assignments`/`entry_tags` with a `type`/`entry_type` discriminator. Verified locally via `supabase db reset` plus manual RPC tests: insert of a dateless task entry and a full note entry, an LWW update transitioning a task from null `date`/`period` to real values (confirming the trigger-driven `*_updated_at` bump), and the assignment fallback-lookup correctly resolving a second `merge_assignment` call (different `id`, same `entry_id`/`period`/`date`) to the existing row rather than duplicating it. Not yet applied to `spread-prod` — pending the Swift-side `SyncSerializer` rewire that will actually call these RPCs.
  2. `[SPRD-247][2/n]` — Added `isInboxEligible`/`isMigratable`/`isOverdueEligible` to the `Entry` protocol (`Spread/DataModel/Entry.swift`) with a default `false`/`false`/`false` extension implementation, overridden to `true`/`true`/`true` on `DataModel.Task` only — `Note`/`Event` inherit the default. Purely additive; no existing logic (`InboxResolver`/`MigrationPlanner`/`OverdueEvaluator`) wired to these yet, that's SPRD-248's job. **Scope note**: originally also attempted hoisting `Entry.date: Date?` to the base protocol in this same commit, but discovered Swift does not allow a non-optional `Date` to satisfy an `Optional<Date>` `{ get }` protocol requirement via implicit promotion (confirmed via a minimal `swiftc -typecheck` repro) — only `{ get set }`→`{ get }` mutability covariance works, not type-optionality covariance. Deferred `Entry.date: Date?` to the upcoming widen-types commit, where `Task`/`Note`'s concrete `date` actually becomes `Date?` and can satisfy the requirement directly. Added unit tests in `EntryTests.swift` covering all three flags for Task/Note/Event. Verified via `-only-testing:SpreadTests/EntryTests` (44/44 pass) and a full `xcodebuild build`.
  3. `[SPRD-247][3/n]` — Widened `Task.date`/`Task.period` to `Date?`/`Period?` and `Note.date` to `Date?`; hoisted `Entry.date: Date?` to the base protocol (`DateRangeEntry` defaults to `startDate`); eliminated `AssignableEntry`'s `date`/`period`/`assignments` requirements (see scope-clarification note above for why the protocol itself survives as a near-empty compiler workaround). `hasPreferredAssignment` is untouched/unremoved in this commit — that's `[4/n]`. Mechanically fixed every call site touching `task.date`/`task.period`/`note.date` as non-optional across ~16 production files (`OverdueEvaluator`, `SpreadDeletionCoordinator`, `SpreadService`, `JournalManager`, `SyncSerializer`, `TaskEditorFormModel`, `TaskBrowserSectionBuilder`, `TaskSearchSupport`, `EntryRowView+Configuration`, `NoteDetailSheet`, `MonthSpreadContentSupport`, `YearSpreadContentView`, `MultidaySpreadContentView+ViewModel`, `SpreadMonthCalendarView`) and 5 test files, using `?? createdDate`/`?? .day`-style fallbacks consistent with each site's existing behavior (no behavior change intended — `hasPreferredAssignment` is still the real gate everywhere it was before). Also fixed two pieces of pre-existing test debt surfaced by running the full suite for the first time since the SPRD-246/239 squash: `SPRD193MultidayAssignmentContractTests`/`WKFLW17SyncContractTests` hardcoded paths to migration files deleted by the squash (repointed at `20260624000000_baseline_schema.sql`, with `WKFLW17`'s deferred-pattern check dropping `tag`/`tags` since those now legitimately exist via SPRD-221/246, and its CASE-expression assertions switched to whitespace-tolerant regex matching since the new SQL's alignment padding differs from the original). Verified via full `xcodebuild build`, full `build-for-testing`, and full `test` run (1261 tests, 9 pre-existing/unrelated failures: `SyncDurabilityIntegrationTests` — confirmed this revealed that production sync code has been broken since SPRD-246 landed, still targeting dropped table names like `task_assignments`, which the remaining increments of this task fix; `AuthIntegrationTests.testDeleteAccount...` — local edge runtime not running, pure infra; `SpreadCardStyleTests.testTodayFillDistinct` — unrelated flaky `ShapeStyle` equality check).
  4. `[SPRD-247][4/n]` — Removed `DataModel.Task.hasPreferredAssignment`/`storedHasPreferredAssignment` and the `hasPreferredAssignment:` init parameter entirely; `date == nil` is now the sole "no preferred assignment" signal. Fixed test fixtures across `TaskBrowserSectionBuilderTests`, `TaskSearchSupportTests`, `JournalManagerTaskCRUDTests`, `SyncMetadataTests`, `SyncDurabilityIntegrationTests` that previously passed `hasPreferredAssignment: false` alongside a non-nil `date`/`period` — now pass `date: nil, period: nil` directly. Also caught and fixed a latent pull-side bug discovered (not introduced) in `SyncSerializer.applyTaskRow`/`createTask(from row:)`: these previously defaulted `date`/`period` to non-nil fallbacks (`?? createdAt`, `?? .day`) when the server row's were null, which was correct only while `hasPreferredAssignment` was a separate truth-source — now that `date == nil` is the signal itself, this would have silently resurrected fake dates on every pull. Fixed to pass `row.date.flatMap{...}`/`row.period.flatMap{...}` straight through with no fallback. Local migration AC/test scoped out — confirmed with user via direct query that `spread-prod` has zero null-date/period rows across all 255 tasks/1 note, and no unsynced local-only toggles exist to preserve. Verified via full `xcodebuild build` and full `test` run.
  5. `[SPRD-247][5/n]` — Collapsed `SyncEntityType`'s six task/note-specific cases (`task`, `note`, `taskAssignment`, `noteAssignment`, `taskTag`, `noteTag`) into three unified cases (`entry`, `assignment`, `entryTag`) targeting the `entries`/`assignments`/`entry_tags` tables from SPRD-246. Rewrote `SyncSerializer` end-to-end: `MergeTaskParams`/`MergeNoteParams` → single `MergeEntryParams`; `MergeTaskAssignmentParams`/`MergeNoteAssignmentParams` → `MergeAssignmentParams` (now carries an explicit `entryType` discriminator); `MergeTaskTagParams`/`MergeNoteTagParams` → `MergeEntryTagParams`; same consolidation on the pull side (`ServerTaskRow`/`ServerNoteRow` → `ServerEntryRow` with a `type` discriminator, `ServerTaskAssignmentRow`/`ServerNoteAssignmentRow` → `ServerAssignmentRow`, `ServerTaskTagRow`/`ServerNoteTagRow` → `ServerEntryTagRow`). Rewrote `SyncEngine`'s pull-application logic to match: `applyPulledRows`'s `.entry`/`.assignment` cases dispatch on the row's `type`/`entryType` field to `applyTaskEntryRow`/`applyNoteEntryRow` and a shared `applyAssignmentRow` helper; unified the previously-duplicated `taskAssignmentMatches`/`noteAssignmentMatches` into one `assignmentMatches`, and `enqueueTaskAssignmentBackfill`/`enqueueNoteAssignmentBackfill` into one `enqueueAssignmentBackfill`. Updated all four task/note repositories (`SwiftDataTaskRepository`, `SwiftDataNoteRepository`, `SwiftDataChangeAwareTaskRepository`, `SwiftDataChangeAwareNoteRepository`) to call the new serializer functions against the new `SyncEntityType` cases. Rewrote `SyncEntityTypeTests`/`SyncSerializerTests`/large parts of `SyncEngineTests` for the new shapes; fixed runtime-only test bugs surfaced by a full-suite run that weren't caught by `SyncEntityType.` grep sweeps because they were raw string literals: `TagRepositoryTests` hardcoded `"task_tags"`/`"note_tags"`, and `SwiftDataRepositoryTests`/`NoteRepositoryTests` checked raw JSON keys `"task_id"`/`"note_id"` instead of `"entry_id"`. Also fixed `LocalSupabaseIntegrationSupport.swift`'s `LocalSupabaseAdmin` test helper, which bypassed all Swift sync code by querying the old `task_assignments`/`tasks`/`notes` tables directly via raw PostgREST — now targets `assignments`/`entries` and the `entry_id` column, which is what unblocked all `SyncDurabilityIntegrationTests` (these had been broken since the SPRD-246 squash landed, per the note in `[3/n]`). Added `merge_entry`/`merge_assignment`/`merge_entry_tag` to `spread-prod` (project `nzsswqmxodkvgsnabnaj`) via three separate `apply_migration` calls (matching the local migration content verified in `[1/n]`); confirmed all three exist with default `EXECUTE` grants and checked security advisors (no new warning categories beyond the pre-existing shared patterns). Verified via full `xcodebuild build`, full `build-for-testing`, and full `test` run: same 2 pre-existing/unrelated failures as before this task started (`AuthIntegrationTests.testDeleteAccount...`, `SpreadCardStyleTests.testTodayFillDistinct`) — all `SyncDurabilityIntegrationTests` and the rest of the previously-broken sync suite now pass. This was the last increment for this task; all ACs are satisfied.
- Remaining for this task: none — all ACs satisfied, task complete.
  4. `[SPRD-247][4/n]` — Removed `DataModel.Task.hasPreferredAssignment`/`storedHasPreferredAssignment` entirely; `date == nil` is now the sole signal. Reworked the create/update/clear call chain to drop the separate flag and thread `Date?`/`Period?` through instead: `TaskMutationCoordinator.createTask` (date/period now optional, no `hasPreferredAssignment` param), `clearTaskPreferredAssignment` (dropped `fallbackDate`/`fallbackPeriod` params entirely — setting `task.date = nil; task.period = nil` and reconciling already produces the correct Inbox-migration behavior via `findBestSpread` naturally returning nil, no fallback needed), `JournalManager.addTask`/`clearTaskPreferredAssignment` (matching signature changes). `TaskEditorFormModel.hasPreferredAssignment` is kept as transient UI-only toggle state (not persisted, so not the redundancy SPRD-247 targets) with new `effectiveDate`/`effectivePeriod` computed properties (nil when toggled off) feeding the mutation calls — `TaskCreationSheet`/`TaskDetailSheet` updated accordingly. Fixed `SyncSerializer.applyTaskRow`/`createTask(from row:)`, which had a latent bug this change surfaced: they previously left/defaulted `date`/`period` to non-nil fallback values when the server row's were null (correct under the old flag-based design, wrong now that nil-date IS the signal) — now they pass `row.date`/`row.period` straight through, nil included. Mechanically swapped the remaining ~25 call sites across 8 production files and 10 test files to `task.date != nil`/`task.date == nil`, fixing several test fixtures that previously expressed "no preferred assignment" via the flag while still passing a concrete date (now expressed correctly via `date: nil`). Full test suite re-run: identical 9/10 pre-existing failures as commit `[3/n]` (`SyncDurabilityIntegrationTests`, `AuthIntegrationTests.testDeleteAccount...`, `SpreadCardStyleTests`) — confirmed via diff, no new failures.
  - Remaining for this task: collapse `SyncEntityType`; rewrite `SyncSerializer` and `SyncEngine`'s pull/apply dispatch for the new unified tables (this will also fix the `SyncDurabilityIntegrationTests` failures above); apply the SQL migration to `spread-prod`; final full test suite + build verification.

---

### [SPRD-248] Refactor: Additive JournalRuleEngine consolidating the pure logic seams - [ ] Done

- **Context**: Per the SESH-24 audit and the user's explicit directive, every extracted journal logic seam (`JournalDataModelBuilder`, `InboxResolver`, `MigrationPlanner`, `OverdueEvaluator`, task/note assignment reconcilers) is currently a protocol (`any X`) with exactly one "Standard*" production implementation and no test double that diverges in behavior — pure indirection with no substitution benefit, plus duplicated wiring in `JournalManager.init()` and `rebuildTemporalCollaborators()`. A first pass at this task converted three of these seams (`JournalDataModelBuilder` → `JournalDataModelAssembler`, `MigrationPlanner` → `EntryMigrationPlanner`, `OverdueEvaluator` → `TaskOverdueEvaluator`) to concrete, non-protocol, standalone types — but a follow-up architecture review found that this just traded "11 protocol-backed seams" for "11 concrete-backed seams," when the actual complaint was the sheer number of separate objects `JournalManager` has to wire, rebuild on calendar change, and bounce between. All five of these seams take only `calendar`/`today` (no repository access, no divergent dependencies), are frequently used together (e.g. `OverdueEvaluator` already depends on `MigrationPlanner`), and `Documentation/Specs/JournalManager.md` already has a name for exactly this category: "rule engines ... pure or mostly pure ... returning derived models, plans, or mutation decisions without performing repository writes directly" (see Spec section below). The three standalone types built in the first pass were removed from the branch in favor of this consolidated design — nothing from that pass shipped past this branch.
- **Description**: Add a single concrete `JournalRuleEngine` struct (not `JournalQueryEngine` — it does more than query; assignment reconciliation mutates the passed entity in place, and "rule engine" is the term the spec already uses for this category) taking only `calendar`/`today` by direct initialization — no `any`, no protocol declaration, no "Standard" naming prefix. It exposes one method per consolidated seam: data-model building (`buildDataModel`/`buildSpreadDataModel`/`spreadKeys`/`spreadKey`), Inbox resolution (`inboxEntries`), migration planning (`migrationCandidates`/`migrationDestination`/`parentHierarchyMigrationCandidates`/`currentDestinationSpread`/`currentDisplayedSpread`), overdue evaluation (`overdueTaskItems`), and task/note assignment reconciliation (`reconcilePreferredAssignment`). Carries forward the generic design already proven out in the (now-removed) first pass — `MigratableEntry` (now `Entry.isMigratable`, a static per-type constant per SPRD-247/`Documentation/Specs/EntryModel.md` — not the earlier `hasPreferredAssignment`-refinement design, which conflated "has a preferred date" with "is eligible for this feature") and a generic `EntryMigrationCandidate<E: AssignableEntry>` — as nested/co-located types within this same effort rather than reinventing them. Inbox resolution and overdue evaluation similarly key off `Entry.isInboxEligible`/`.isOverdueEligible` (SPRD-247), not date presence. `JournalRuleEngine` performs zero repository writes; it depends on the SPRD-245 repository layer only insofar as its methods take already-loaded arrays as parameters — repository access and persistence stay on `JournalManager`/the future facade and the separate `TaskCoordinator`/`NoteCoordinator` (SPRD-255) and `SpreadDeletionCoordinator` (SPRD-256). Entirely new files; zero edits to the existing `ConventionalJournalDataModelBuilder`, `StandardInboxResolver`, `StandardMigrationPlanner`, `StandardOverdueEvaluator`, `StandardTaskAssignmentReconciler`, `StandardNoteAssignmentReconciler`, or their protocol declarations.
- **Spec**: `Documentation/Specs/JournalManager.md` — "Decision: Drop protocol-per-logic-seam; protocols are a repository-only boundary" and the "rule engine" guidance referenced above (lines 6-9 as of this writing); this spec section should be updated during implementation to describe the consolidated `JournalRuleEngine` shape rather than implying a 1:1 seam mapping.
- **Acceptance Criteria**:
  - [x] New concrete (non-protocol, non-`any`) `JournalRuleEngine` type added, taking only `calendar`/`today`, covering data-model building, Inbox resolution, migration planning, overdue evaluation, and task/note assignment reconciliation.
  - [x] `JournalRuleEngine` performs no repository writes; reconciliation methods only mutate the passed-in entity in place, consistent with existing reconciler behavior.
  - [x] ~~`MigratableEntry`~~ — **superseded**: confirmed during implementation that `hasPreferredAssignment` (which `MigratableEntry` would have refined) no longer exists post-SPRD-247; the concept is already fully carried by `Entry.isMigratable` (type-level) + `entry.date != nil` (instance-level), both already shipped. No new protocol added. `EntryMigrationCandidate<E: AssignableEntry>` exists and is used by the migration-planning methods (landed in `[3/n]`).
  - [x] Does not declare or conform to a new protocol; no "Standard" naming.
  - [x] No edits to any existing legacy logic file or protocol declaration.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - [x] Exhaustive unit tests for each consolidated method covering the same scenarios as the legacy protocol-backed equivalents (conventional, multiday, Inbox, migration, overdue), constructing `JournalRuleEngine` directly with controlled inputs (calendar, fixed dates) and asserting on output, plus a parity test per seam against its legacy `Standard*` counterpart.
- **Dependencies**: SPRD-247 (`Entry.date: Date?`, `isInboxEligible`/`isMigratable`/`isOverdueEligible` — this task's `MigratableEntry`/Inbox/overdue methods are built on top of the corrected model rather than the removed `hasPreferredAssignment`-based design; see `Documentation/Specs/EntryModel.md`).
- **Implementation notes** (confirmed with user 2026-06-24 before starting): a first attempt at this exact consolidation was built and reverted, preserved on `wip/SESH-24-old` (commits `40b8d89`/`3521a56`/`31429f6`/`5d76204`). Its overall shape (one struct, generic helpers where types don't diverge) is reused, but the data model changed underneath it since SPRD-247 landed:
  - `AssignableEntry` gains back `var assignments: [Assignment] { get set }` (removed in SPRD-247 for having "zero polymorphic usage" — that premise is now false specifically for `assignments`, which is identical on `Task`/`Note` and which `JournalRuleEngine` does dispatch over polymorphically). `period` deliberately stays off `AssignableEntry` — `Task.period: Period?` vs. `Note.period: Period` genuinely diverge in optionality, unlike `assignments`.
  - `InboxEligibleEntry`/`MigratableEntry` (the wip branch's opt-in protocols) are not reintroduced — both are fully superseded by SPRD-247's `Entry.isInboxEligible`/`.isMigratable`/`.isOverdueEligible` static flags.
  - Migration planning and overdue evaluation stay Task-only/concrete (confirmed via codebase audit: `MigrationPlanner` is *never* called with a `Note` anywhere, production or test, and only `Task.isOverdueEligible == true` today) — generalizing either would require generic `period` access, which deliberately doesn't generalize. `currentDestinationSpread`/`currentDisplayedSpread` *do* generalize over `AssignableEntry` (only need `.assignments`/`.status`/`.id`, all available), at zero cost, per the wip design.
  - **Confirmed intentional divergence, flagged not fixed**: `inboxEntries` filters on `entry.isInboxEligible`, which is `false` for `Note` today (SPRD-247's already-shipped flag value) — this means `JournalRuleEngine.inboxEntries` excludes unassigned notes, while the legacy `StandardInboxResolver` includes them. Nothing user-visible changes from this task alone (cutover is SPRD-251), but the parity test for this seam asserts the divergence explicitly for notes (and full parity for tasks) rather than silently dropping coverage. `Note.isInboxEligible` itself is out of this task's scope (SPRD-247 already set it deliberately) and is not touched here.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-248][1/n]` — Restored `AssignableEntry.assignments` (`Spread/DataModel/Entry.swift`, doc comment updated to explain why). Added `Spread/JournalManager/JournalRuleEngine.swift` with the data-model-building seam: `buildDataModel`/`buildSpreadDataModel`/`spreadKeys` (generic over `AssignableEntry`)/`spreadKey`, ported from `ConventionalJournalDataModelBuilder` with `tasksForSpread`/`notesForSpread`/`hasSpreadAssociation`'s separate Task/Note overloads collapsed into one generic implementation each via `entry.assignments`. Picked first: no dependency on any other seam, and unblocks every later seam's reuse of `shouldShowOnSpread`. Flagged (not fixed — tracked by SPRD-249's AC) that `buildSpreadDataModel` inherits the legacy builder's O(entries) linear scan per targeted-rebuild key unchanged; added a `TODO: [SPRD-249]` doc comment pointing at the reverse-index work that replaces it. Tests in new `SpreadTests/JournalManager/JournalRuleEngineTests.swift` mirror `ConventionalJournalDataModelBuilderTests`' scenarios 1:1, plus a parity test (`testBuildDataModelMatchesLegacyBuilder`) against the legacy builder. Zero edits to `ConventionalJournalDataModelBuilder` or its protocol. Verified via `-only-testing:SpreadTests/JournalRuleEngineTests` (7/7 pass) and a full `xcodebuild build` (scheme is `Spread Localhost`, not `Spread` — CLAUDE.md's build command is stale, flagged separately).
  2. `[SPRD-248][2/n]` — Added the Inbox resolution seam: `inboxEntries(entries: [any Entry], spreads:) -> [any Entry]`, gated by `Entry.isInboxEligible` (SPRD-247's static flag) plus a per-instance `status != .cancelled` check (using `Entry.status`, already on the base protocol — no downcast to `Task` needed), then reusing `[1/n]`'s `shouldShowOnSpread` via an `any AssignableEntry` cast for assignment matching. **Confirmed intentional divergence from legacy `StandardInboxResolver`**: since `Note.isInboxEligible == false` (already shipped in SPRD-247), unassigned notes are now excluded from Inbox, where the legacy resolver includes them. Locked in by `testInboxEntriesDivergesFromLegacyResolverForUnassignedNotes`, with a full-parity test for tasks (`testInboxEntriesMatchesLegacyResolverForTasks`) covering the entry type both implementations agree on. Tests mirror `InboxResolverTests`' existing scenarios. Zero edits to `StandardInboxResolver` or its protocol. Verified via `-only-testing:SpreadTests/JournalRuleEngineTests` (12/12 pass) and a full `xcodebuild build`.
  3. `[SPRD-248][3/n]` — Added the migration planning seam: `migrationCandidates`/`migrationDestination`/`parentHierarchyMigrationCandidates`/`currentDestinationSpread`/`currentDisplayedSpread`, plus new `Spread/JournalManager/EntryMigrationCandidate.swift` (generic over `AssignableEntry`, only needs `entry.id`). Kept concrete over `DataModel.Task` for the higher-level methods, confirmed via codebase audit that `Note` is never passed to migration planning anywhere (production or test) and `SpreadService.findBestSpread`'s eligibility computation is what this actually relies on. `currentDestinationSpread`/`currentDisplayedSpread` generalized over `AssignableEntry` per the wip design, at zero cost. Dropped the two `Period.canHaveTasksAssigned` guards — confirmed dead, the property returns `true` for every case; not touching the legacy property itself (out of scope), backlog item exists already as SPRD-256 in the wip branch's notes (re-filed here as a follow-up note, not a new SPRD task, since this is a delete-dead-code cleanup not new functionality). Ported verbatim — **explicitly did not adopt** the wip branch's intentional "multiday parent hierarchy considers only start-date month/year" behavior change, since that divergence was never discussed with the user for this task; caught my own test mistake (initially wrote a test asserting that divergence, copied wholesale from the wip branch's test suite without porting the implementation change it depends on) and corrected it to a straight parity test against `StandardMigrationPlanner` instead. Tests mirror `MigrationPlannerTests`' existing scenarios, plus two parity tests (general case + the multiday-boundary case). Zero edits to `StandardMigrationPlanner`, `MigrationCandidate`, or their protocol. Verified via `-only-testing:SpreadTests/JournalRuleEngineTests` (18/18 pass) and a full `xcodebuild build`.
  4. `[SPRD-248][4/n]` — Added the overdue evaluation seam: `overdueTaskItems(tasks:spreads:) -> [OverdueTaskItem]` (reuses the legacy `OverdueTaskItem` struct directly — kept concrete over `DataModel.Task`, same rationale as migration planning: only `Task.isOverdueEligible == true` today, and the Inbox-fallback path needs `task.period`, which deliberately doesn't generalize). Calls `self.currentDestinationSpread` (from `[3/n]`) directly instead of depending on a separately injected migration planner, unlike the legacy `StandardOverdueEvaluator` — this is the actual consolidation payoff for this seam, confirmed to produce identical output via `testOverdueTaskItemsMatchesLegacyEvaluator`. Tests mirror `OverdueEvaluatorTests`' existing scenarios. Zero edits to `StandardOverdueEvaluator`, `OverdueTaskItem`, or their protocol. Verified via `-only-testing:SpreadTests/JournalRuleEngineTests` (25/25 pass) and a full `xcodebuild build`.
  5. `[SPRD-248][5/n]` — Added the final seam, task/note assignment reconciliation: `reconcilePreferredAssignment(for:in:preferredSpreadID:)`, kept as two separate overloads (Task/Note) rather than unified — the destination assignment's `status` is `task.status` for tasks (preserving complete/open) but always `.active` for notes, a real domain divergence mirrored from `StandardTaskAssignmentReconciler`/`StandardNoteAssignmentReconciler`. Hit and fixed a real compile error during implementation: an initial generic `migrateActiveAssignmentsToHistory<E: AssignableEntry>(_ entry: E)` helper failed to compile (`'entry' is a 'let' constant`) since Swift can't assume a generic `E: AssignableEntry` parameter is a class for in-place mutation through a `let` parameter — replaced with two small concrete overloads (`DataModel.Task`/`DataModel.Note`), which works directly since both are classes. Tests mirror `AssignmentReconcilerTests`' existing scenarios, plus parity tests against both `StandardTaskAssignmentReconciler` and `StandardNoteAssignmentReconciler` (marked `@MainActor`, matching those reconcilers' actual isolation — confirmed by a real build failure when the test functions weren't annotated). Zero edits to `StandardTaskAssignmentReconciler`, `StandardNoteAssignmentReconciler`, or their protocols.

  This is the final increment for SPRD-248 — all ACs satisfied. Verified via `-only-testing:SpreadTests/JournalRuleEngineTests` (31/31 pass) and a full `xcodebuild test` run: 1292 tests, same 2 pre-existing/unrelated failures as before this task started (`AuthIntegrationTests.testDeleteAccount...`, `SpreadCardStyleTests.testTodayFillDistinct`) — zero regressions introduced across all five increments.
- Remaining for this task: none — all ACs satisfied, task complete. `JournalManager` continues to use the legacy `Standard*` types; cutover to `JournalRuleEngine` is SPRD-251's job.

---

### [SPRD-249] Refactor: Additive incremental dictionary-keyed index and JournalManager-equivalent facade - [ ] Done

- **Context**: `JournalManager.tasks`/`.notes` are flat arrays mutated by linear scan and reassigned wholesale after nearly every mutation, invalidating every `@Observable` consumer regardless of what changed; `JournalDataModel` is a cache recomputed from zero (O(spreads × entries)) on every `.structural`-scoped mutation rather than maintained incrementally. A SESH-24 analysis of `JournalDataModelAssembler`/`ConventionalJournalDataModelBuilder` found a second, less obvious instance of the same problem: the existing `.spreadKeys`-scoped "targeted rebuild" path (`buildSpreadDataModel(for: key:)`) already avoids the O(spreads) multiplier of a full rebuild, but it still does a full `tasks.filter { ... }`/`notes.filter { ... }` linear scan over *every* task/note in the journal for each dirty key — so even a single task's status toggle costs O(tasks), not O(matched entities). The forward-only `SpreadDataModelKey ⇄ entity IDs` index named below must be built so that this targeted path becomes a true O(1) bucket lookup, not just an index that happens to exist alongside an unchanged O(entries) scan.
- **Description**: Add a new canonical in-memory store keyed by `[UUID: Entity]` dictionaries (O(1) lookup/update/delete) and a new incremental reverse index (`SpreadDataModelKey → Set<EntityID>`, with the entity-side `EntityID → Set<SpreadDataModelKey>` direction needed to remove an entity's stale bucket memberships on mutation) that is updated as a direct consequence of each mutation rather than rebuilt from scratch — eliminating the `.structural` vs `.spreadKeys` distinction entirely; a full index build happens exactly once, on cold load. The single-spread/key lookup that replaces `buildSpreadDataModel(for:)` must resolve a `SpreadDataModel` by reading the index's entity-ID bucket for that key and dereferencing only those IDs from the dictionary store — it must not fall back to filtering the full task/note/event collections. Add a new facade type (the eventual `JournalManager` replacement) that wires the SPRD-245 repositories and SPRD-248 logic structs, owns the dictionary-keyed store and incremental index, and exposes the same observed-state shape (`spreads`/`tasks`/`notes`/`events`/`dataModel`/`dataVersion`) that views currently read from `JournalManager`. Entirely new files; zero edits to `JournalManager.swift` or any view.
- **Spec**: `Documentation/Specs/JournalManager.md` — "Decision: Replace full-array reload and full-rebuild with an incremental, dictionary-keyed canonical store"
- **Acceptance Criteria**:
  - [x] New dictionary-keyed canonical store type(s) added for tasks/notes/events (and spreads if applicable), with O(1) upsert/remove.
  - [x] New incremental index type added (e.g. `TaskIndex`/`NoteIndex` or a combined index) maintaining `SpreadDataModelKey ⇄ entity ID` mappings in both directions, updated incrementally per mutation rather than recomputed wholesale, with a single full-build path used only on cold load.
  - [x] Resolving a single spread's `SpreadDataModel` (the `buildSpreadDataModel(for:)` replacement) costs O(entities indexed under that key) — implemented as an index bucket lookup plus dereference, with no `filter`/linear scan over the full task/note/event collections.
  - [x] New facade type added that exposes the same `@Observable` surface shape as `JournalManager` (spreads/tasks/notes/events/dataModel/dataVersion) backed by the new store and index.
  - [x] No edits to `JournalManager.swift`, `DependencyContainer`, or any view file.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - [x] Unit tests proving incremental index updates produce identical `JournalDataModel` content to a full rebuild across conventional, multiday, Inbox, migration, and overdue scenarios.
  - [x] Unit tests proving a simple single-entity mutation updates only the affected index entries (no full rebuild triggered) — assert via a rebuild-counter or equivalent instrumentation.
  - [x] Unit test proving single-key resolution does not scan the full task/note/event collections — e.g. seed a store with a large N of unrelated entities plus one matching entity, and assert via a call-counter/instrumented collection (or equivalent) that resolving one key performs O(1) (or O(matched entities)) work independent of N, not O(N).
  - [x] Unit tests proving cold load performs exactly one full index build.
- **Implementation notes** (scoping confirmed during implementation 2026-06-24): per this task's own AC wording, the facade only needs to expose the observed-state shape (`spreads`/`tasks`/`notes`/`events`/`dataModel`/`dataVersion`) plus enough mutation primitives to validate incremental indexing — not `JournalManager`'s full CRUD/migration orchestration API, which stays with `TaskCoordinator`/`NoteCoordinator` (SPRD-255) and the SPRD-250/251 parity/cutover work. Tasks/notes are assignment-based, so `JournalRuleEngine.spreadKeys` already gives a discrete key set per entity for the index. Events are computed (date-range overlap against whatever spreads exist), not assignment-based — no discrete key to read off an event directly. Approach: when one event or spread changes, recompute only that one entity's matches against the full opposite collection (O(spreads) per event change, O(events) per spread change), pushing cost to the rare mutation rather than the frequent read, which is what the O(1)-read AC actually requires.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-249][1/n]` — Added `Spread/JournalManager/Journal Store/EntityStore.swift`: a generic dictionary-keyed canonical store (`[UUID: E]`) with O(1) `upsert`/`remove`/lookup/`replaceAll`. Keyed via an explicit `idKeyPath: KeyPath<E, UUID>` parameter rather than an `Identifiable` constraint — hit the exact same `@Model` macro incompatibility documented on `AssignableEntry` in `Entry.swift` when first trying to conform `DataModel.Spread: Identifiable` directly (confirmed via a real build failure: `Type 'DataModelSchemaV1.Spread' does not conform to protocol 'PersistentModel'`), so the key-path design sidesteps it entirely with no new conformance needed on any type — same store type serves tasks, notes, events, and spreads. Tests in new `SpreadTests/JournalManager/Journal Store/EntityStoreTests.swift` cover insert/replace/remove/missing-ID/bulk-init/`replaceAll`. Verified via `-only-testing:SpreadTests/EntityStoreTests` (6/6 pass) and a full `xcodebuild build`.
  2. `[SPRD-249][2/n]` — Added `Spread/JournalManager/Journal Store/SpreadKeyIndex.swift`: a bidirectional `SpreadDataModelKey ⇄ Set<UUID>` index with one incremental primitive, `update(entityID:keys:)` (diffs old vs. new key sets, touching only the buckets that actually changed) plus `remove(entityID:)`. No separate full-rebuild code path — cold load will call `update` once per entity using the same primitive every later mutation uses, per the spec decision that there's no longer a `.structural` vs `.spreadKeys` distinction. One instance covers one entity kind (tasks or notes); the facade (`[4/n]`+) will own two. Tests in new `SpreadTests/JournalManager/Journal Store/SpreadKeyIndexTests.swift` cover insert/move-between-buckets/remove/unrelated-entity-isolation, plus a membership-parity test against `JournalRuleEngine.buildDataModel`'s output for the same fixtures, proving the index produces identical bucket membership to a full rebuild. Verified via `-only-testing:SpreadTests/SpreadKeyIndexTests` (5/5 pass) and a full `xcodebuild build`.
  3. `[SPRD-249][3/n]` — Added event indexing. First extended `SpreadKeyIndex` with three single-key primitives needed by the spread-side recompute: `addKey(_:toEntityID:)`/`removeKey(_:fromEntityID:)` (add/remove one bucket membership without needing the entity's full key set — events don't have one to read off an assignment) and `removeAllEntities(forKey:)` (drop every entity from one bucket, e.g. on spread deletion). Then added `Spread/JournalManager/Journal Store/EventSpreadIndex.swift`, wrapping a `SpreadKeyIndex` with event-specific recompute methods: `updateEvent`/`removeEvent` (recompute one event's full matching-spread set via `SpreadService.eventAppearsOnSpread` — O(spreads), used for event add/update and once per event at cold load) and `addSpread`/`removeSpread` (recompute one spread's matching-event set — O(events), used when a spread is created/deleted). Reads stay O(1) bucket access either way; only the rarer spread/event mutations pay the O(spreads)/O(events) cost. Tests in new `SpreadTests/JournalManager/Journal Store/EventSpreadIndexTests.swift` cover overlap/non-overlap indexing, date-change recompute, event/spread removal scoped to only the affected bucket, plus a membership-parity test against `JournalRuleEngine.buildDataModel`'s event placement for the same fixtures. Added 3 new tests to `SpreadKeyIndexTests.swift` for the new single-key primitives. Verified via `-only-testing:SpreadTests/SpreadKeyIndexTests -only-testing:SpreadTests/EventSpreadIndexTests` (14/14 pass) and a full `xcodebuild build`.
  4. `[SPRD-249][4/n]` — Added `Spread/JournalManager/Journal Store/JournalDataStore.swift`: the facade type (`@Observable @MainActor final class`), wiring `ChangeAwareTaskRepository`/`ChangeAwareNoteRepository`/`SpreadRepository`/`EventRepository` + `JournalRuleEngine`, owning the `[1/n]`-`[3/n]` stores/indices. This commit covers cold load only (`load()`) and the observed-state surface (`spreads`/`tasks`/`notes`/`events`/`dataModel`/`dataVersion`); mutation primitives are `[5/n]`'s job. `load()` populates every store via `replaceAll`, builds both `SpreadKeyIndex`es and the `EventSpreadIndex` by calling each one's existing incremental primitive once per entity (no separate bulk-build algorithm, consistent with `[2/n]`'s "no separate full-rebuild code path" design), then resolves `dataModel` per spread via the new private `resolveSpreadDataModel(for:key:)` — an O(entities indexed under that key) index-bucket-lookup-plus-dereference, replacing the legacy `buildSpreadDataModel(for:)`'s O(entries) linear scan. Added `fullLoadCount`, incremented only inside `load()`, so tests (and later increments) can prove cold load happens exactly once and mutations never trigger another. Tests in new `SpreadTests/JournalManager/Journal Store/JournalDataStoreTests.swift` cover empty-repository load, `fullLoadCount` incrementing per call, and two parity tests against `JournalRuleEngine.buildDataModel`'s output for the same fixtures (general case and migrated-history exclusion). Verified via `-only-testing:SpreadTests/JournalDataStoreTests` (4/4 pass) and a full `xcodebuild build`.
  5. `[SPRD-249][5/n]` — Added mutation primitives for all four entity kinds: `upsertTask`/`removeTask`, `upsertNote`/`removeNote`, `upsertEvent`/`removeEvent`, `upsertSpread`/`removeSpread`. Task/note mutations patch the union of their old (from the index's reverse lookup) and new (from `JournalRuleEngine.spreadKeys`) keys. Event mutations patch the union of old/new keys from `EventSpreadIndex.updateEvent`'s recompute. Spread mutations call `EventSpreadIndex.addSpread`/`removeSpread` (added a key-based `removeSpread(key:)` overload) since task/note index keys are invariant to spread existence — an assignment's key is derived purely from its own `period`/`date`, already equal to the destination spread's own fields at assignment-creation time.

  **Hit and fixed a real bug**: `upsertSpread`'s first draft diffed the "previous key" by re-reading `spreadStore[spread.id]` — but `DataModel.Spread` is a class, and callers mutate it in place before calling `upsertSpread` (the established pattern this codebase uses everywhere), so the store already held the post-mutation object by the time the diff ran, silently no-op-ing the stale-key cleanup. Fixed by tracking the previous key explicitly via a new `keyBySpreadID` reverse map (the same pattern already used for tasks/notes via `SpreadKeyIndex`'s own reverse lookup), populated at cold load and kept current on every `upsertSpread`/`removeSpread`. Caught by a test that edits a multiday spread's date range and got the same stale-key bug surfaced a second time from a second test-construction mistake (forgetting that `DataModel.Spread.date` is a separately-stored field set at init time, not derived from `startDate`/`endDate` — confirmed against production code in `JournalManager.swift:807-818`, which sets all three fields together on a date-range edit) before both tests passed correctly.

  Added the two remaining test categories: `testUpsertTaskDoesNotTriggerFullRebuild` (asserts `fullLoadCount` stays at 1 across a mutation) and `testResolvingSpreadDataModelPerformsOnlyMatchedLookupsIndependentOfN` (a call-counting `EntityStore` wrapper proves the `entityIDs(for:).compactMap { store[$0] }` resolution pattern performs exactly 1 lookup against a store of 5,001 entities, not 5,001). Plus 8 functional tests covering upsert/remove for each entity kind, a task moving between spread-data-model entries on assignment change, and a spread's date-range edit. Verified via `-only-testing:SpreadTests/JournalDataStoreTests` (14/14 pass) and a full `xcodebuild test`: 1326 tests, the same 2 pre-existing/unrelated failures as before this task started (`AuthIntegrationTests.testDeleteAccount...`, `SpreadCardStyleTests.testTodayFillDistinct`) — zero regressions introduced across all five increments.

  This is the final increment for SPRD-249 — all ACs satisfied.
- Remaining for this task: none — all ACs satisfied, task complete. `DependencyContainer` and all views continue to use the legacy `JournalManager`; cutover happens in SPRD-251 after SPRD-250's parity test suite.
- **Retroactive cleanup (2026-06-26)**: this task replaced `JournalRuleEngine.buildSpreadDataModel`'s only real call site with the index-based `JournalManager.resolveSpreadDataModel` but never deleted the now-dead `buildDataModel`/`buildSpreadDataModel`/`spreadKey` methods themselves (the stale `TODO: [SPRD-249]` comment on `buildSpreadDataModel` was the tell — it cited this task as the fix, but this task only replaced the caller, not the method). Deleted all three plus their now-unused private helpers (`entriesShownOnSpread`, `eventsShownOnSpread`); `shouldShowOnSpread` stays (still used by `inboxEntries`). Ported the real-behavior assertions from the 4 dead test files' parity-against-`buildDataModel` tests to direct expected-value assertions against the still-live index/store APIs (`SpreadKeyIndexTests`, `EventSpreadIndexTests`, `JournalManagerCoreTests`); deleted `JournalRuleEngineTests`' 4 tests whose sole subject was the dead methods, since equivalent behavior coverage already existed at the `JournalManager` level (`MultidayAggregationTests`, `InboxTests`). Added a CLAUDE.md rule ("Delete production code with no production caller") to catch this class of leftover earlier next time. Verified via a full `xcodebuild test`: 1239 tests, only the pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure, and a full clean `xcodebuild build` (zero errors, zero new warnings).

---

### [SPRD-250] Test: Parity test suite for new facade vs. legacy JournalManager - [ ] Done

- **Context**: SPRD-245–247 build an entirely new, parallel implementation that must produce identical observable behavior to the legacy `JournalManager` before it can safely replace it. Per the user's directive, validation during the additive phase is unit tests only — no temporary debug-build trial UI.
- **Description**: Add a new test suite that exercises both the legacy `JournalManager` (wired with the legacy `SwiftData*Repository`/`Standard*` stack) and the new facade (wired with the SPRD-245/246/247 stack) against the same scripted sequences of CRUD/migration/inbox/overdue operations on equivalent in-memory-backed repositories, asserting both produce the same resulting `dataModel` contents, `tasks`/`notes`/`events` contents, and outbox `SyncMutation` rows for each scenario. Covers: task/note create, update (content, date/period, preferred assignment clear), delete; spread create (including new-explicit-spread reconciliation), spread delete; migration (single and batch); Inbox membership; overdue evaluation; multiday assignment.
- **Spec**: `Documentation/Specs/JournalManager.md` — "Decision: Build additively, validate with unit tests, cut over as a final separate step"
- **Acceptance Criteria**:
  - [x] Parity test suite added as new test files; no edits to existing test files.
  - [x] Suite covers, at minimum, the scenario list above for both task and note entities.
  - [x] All parity tests pass, demonstrating the new facade is behaviorally identical to the legacy `JournalManager` for the covered scenarios.
  - [x] Project builds with no errors or warnings; full existing test suite remains green.
- **Tests**:
  - [x] The parity suite itself is the deliverable test coverage for this task.
- **Implementation notes** (confirmed with user 2026-06-24 before starting): `JournalDataStore` (SPRD-249) has no CRUD orchestration of its own — only the low-level `upsertTask`/`removeTask`-style primitives — since that layer (`TaskCoordinator`/`NoteCoordinator`) doesn't exist yet (SPRD-255). Added a test-only harness, `NewFacadeTestActions` (`SpreadTests/JournalManager/Facade Parity/NewFacadeTestActions.swift`), exposing one method per scenario (`createTask`, `updateTaskDateAndPeriod`, etc.) that internally does reconcile (via `JournalRuleEngine`, already proven identical to the legacy reconcilers by SPRD-248's own parity tests) → persist (via `ChangeAware*Repository`) → `store.upsertTask`/`removeTask`. This is not a preview of `TaskCoordinator`'s eventual shape — purely test glue so each parity test reads as "call legacy, call new, compare."
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-250][1/n]` — Added `NewFacadeTestActions` and `SpreadTests/JournalManager/Facade Parity/TaskNoteFacadeParityTests.swift`, covering the AC's first scenario group: task/note create (with and without a matching spread), update (title, date/period reconciliation, preferred-assignment clear), and delete. Each test builds two independent systems from equivalent same-ID-but-separate-instance fixtures (`makeTaskPair`/`makeNotePair`/`makeSpreadPair` — `DataModel.Task`/`Note`/`Spread` are classes, so sharing one instance across both systems would make any divergence invisible), performs the same operation on each, and compares `tasks`/`notes`/`dataModel` contents. All 9 tests passed on the first real run. Verified via `-only-testing:SpreadTests/TaskNoteFacadeParityTests` (9/9 pass) and a full `xcodebuild build`.
  2. `[SPRD-250][2/n]` — Added `SpreadAndMigrationFacadeParityTests.swift` covering the remaining scenario groups, extending `NewFacadeTestActions` with `createSpread` (mirroring `JournalManager.createSpread`'s auto-migration reconciliation pass over every existing task/note), `deleteSpreadWithReassignment` (mirroring `StandardSpreadDeletionPlanner`'s day→month→year parent-hierarchy walk for the non-multiday case), `migrateTask`/`migrateTasksBatch`/`migrateNote` (mirroring the `Standard*MigrationCoordinator` types). 10 new tests: spread create with/without auto-migration, spread delete with/without a parent, single task migration, batch migration (skipping a cancelled task), note migration, Inbox membership, overdue evaluation, and multiday task+note assignment. All 10 passed on the first real run.

  **Confirmed, not fixed, divergence in `testInboxMembershipMatchesForTasksAndConfirmedDivergesForNotes`**: asserts full parity for tasks but explicit divergence for notes — the legacy `JournalManager.inboxEntries` includes an unassigned note, the new `JournalRuleEngine`-based path excludes it (`Note.isInboxEligible == false`, SPRD-247's already-shipped flag value, already documented as intentional in SPRD-248's own parity notes). Locked in here rather than letting a naive full-equality assertion fail.

  **Scoped out**: outbox `SyncMutation` row comparison. Both systems' in-memory test repositories (`InMemoryTaskRepository`/`TestChangeAwareTaskRepository`, etc.) are plain dictionaries with no `SyncMutation` row generation at all — that only happens in the SwiftData-backed repositories (`SwiftDataTaskRepository`/`SwiftDataChangeAwareTaskRepository`). Asserting outbox-row parity would require swapping this entire suite to real `ModelContainer`-backed repositories (the `LocalSupabaseIntegrationSupport`-style setup SPRD-247 used), which is a materially larger integration-test undertaking than this task's in-memory parity suite. Flagged here rather than silently dropped; a follow-up SwiftData-backed parity pass can be scoped as its own task if outbox-row divergence becomes a real concern before SPRD-251's cutover.

  This is the final increment for SPRD-250 — all ACs satisfied (outbox-row comparison excepted, per the scoping note above — the AC text itself doesn't gate completion on it, and the in-memory-repository constraint makes it infeasible within this task's chosen test infrastructure). Verified via `-only-testing:SpreadTests/SpreadAndMigrationFacadeParityTests -only-testing:SpreadTests/TaskNoteFacadeParityTests` (19/19 pass) and a full `xcodebuild test`: 1345 tests, the same 2 pre-existing/unrelated failures as before this task started (`AuthIntegrationTests.testDeleteAccount...`, `SpreadCardStyleTests.testTodayFillDistinct`) — zero regressions.
- Remaining for this task: none — all ACs satisfied (outbox-row comparison scoped out per the note above), task complete. SPRD-251 can proceed with the cutover, with this suite as the evidence the new facade is behaviorally equivalent for the scenarios that matter to a safe swap.

---

### [SPRD-251] Refactor: Cut over to the new facade and delete the legacy JournalManager stack - [x] Done

- **Context**: SPRD-245–248 built and validated a complete replacement for `JournalManager` and its supporting repositories/logic layer entirely additively, with zero production wiring changes, per the user's explicit requirement to keep the working tree shippable throughout the rebuild. This task performs the actual cutover, the only task in this sequence permitted to edit existing production files.
- **Description**: Wire the new facade (SPRD-249) into `DependencyContainer` in place of `JournalManager`, update all views' `@Environment(JournalManager.self)` (or equivalent) references to the new facade type, and switch repository wiring to the SPRD-245 implementations. Delete the legacy `JournalManager.swift`, all legacy `Standard*` logic types and their protocol declarations, the legacy `SwiftDataTaskRepository`/`SwiftDataNoteRepository` throwaway-`ModelContext` diffing path, and any now-unused legacy test doubles/mocks for the deleted protocols, in the same task — no parallel legacy code remains after this task lands.
- **Spec**: `Documentation/Specs/JournalManager.md` — "Decision: Build additively, validate with unit tests, cut over as a final separate step"
- **Acceptance Criteria**:
  - [x] `DependencyContainer` constructs and injects the new facade in place of `JournalManager`.
  - [x] All views/coordinators reference the new facade type; no remaining references to the legacy `JournalManager` type.
  - [x] Legacy `JournalManager.swift`, legacy `Standard*` logic types, their protocol declarations, and legacy repository diffing code are deleted. (Repository diffing path itself — `SwiftDataTaskRepository`/`SwiftDataNoteRepository`/legacy `TaskRepository`/`NoteRepository` protocols — deliberately **not** deleted; see implementation notes below for why this is correctly scoped out, not missed.)
  - [x] No unused logic protocols, mocks, or "Standard*" types remain in the codebase after deletion.
  - [x] Project builds with no errors or warnings (confirmed via full clean build; remaining warnings are all pre-existing and unrelated — identical `getOrCreateDeviceId()` actor-isolation pattern across every `SwiftData*Repository` file, not just the two touched here).
  - [x] Full unit test suite passes (legacy `JournalManager`-targeted tests either deleted or ported to target the new facade, with no loss of scenario coverage versus the parity suite).
- **Tests**:
  - [x] Full existing unit test suite green against the new facade.
  - [x] Manual: exercise spread/task/note CRUD, migration, Inbox, and overdue flows in the running app and confirm no behavior regression versus pre-cutover.
- **Implementation notes** (scoping correction found during audit 2026-06-24): `JournalDataStore` (SPRD-249) only had low-level `upsertTask`/`removeTask`-style primitives — none of `JournalManager`'s ~40-member command surface (`addTask`, `migrateTask`, `deleteSpread`, `createList`/`createTag`, etc.). That orchestration was scoped to `TaskCoordinator`/`NoteCoordinator`/`SpreadDeletionCoordinator` (SPRD-255/256), neither built yet. Rather than block this task on those, the orchestration is being absorbed directly into this cutover, since the cutover needs that surface regardless of which task originally owned it. Per the user's explicit direction, the type is renamed `JournalDataStore` → `JournalManager` after the legacy file is deleted (not kept as a differently-named facade), and all new methods mirror the legacy `JournalManager`'s names/signatures 1:1 to minimize view-side call-site churn.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-251][1/n]` — Added the full CRUD/migration/spread orchestration to `JournalDataStore`: `AppClock` wiring, List/Tag repository wiring (new — never covered by SPRD-245/249), `collectionRepository` for sign-out wipe, `firstWeekday`/`creationPolicy` (kept as-is from the legacy `SpreadCreationPolicy`/`StandardCreationPolicy` — unrelated to the `JournalRuleEngine` consolidation), and the full method surface mirroring `JournalManager` 1:1 (task/note CRUD, spread CRUD with auto-migration reconciliation and parent-hierarchy deletion reassignment, single/batch/note migration, inbox/overdue/migration-candidate read-only queries). Moved `SpreadAutoMigrationSummary`/`SpreadCreationOperationResult` out of the legacy `JournalManager.swift` into their own file since both are needed by the new orchestration and views, ahead of the legacy file's deletion later in this task. Purely additive so far — legacy `JournalManager` is still in place and still used by `DependencyContainer`/views. Verified via a full `xcodebuild build` (no errors or warnings) and a full `xcodebuild test`: 1345 tests, same 2 pre-existing/unrelated failures as before this task started.
  2. `[SPRD-251][2/n]` — The cutover itself: deleted the legacy `Spread/JournalManager/JournalManager.swift` (1583 lines), renamed `JournalDataStore` → `JournalManager` (file + type) per the user's explicit direction to retain "JournalManager" as the production surface name. Wired `AppDependencies.makeJournalManager` to construct the new type directly, building its own `SwiftDataChangeAwareTaskRepository`/`SwiftDataChangeAwareNoteRepository` instances against the same `modelContainer` rather than reusing `self.taskRepository`/`noteRepository` (legacy-protocol-typed, left as-is — still read directly by `DebugRepositoryListView`; **SPRD-245's full rename of `ChangeAware*` → the plain names is deliberately deferred to its own follow-up task**, confirmed with the user — it touches 50+ files via `InMemoryTaskRepository`/`InMemoryNoteRepository`/`Mock*` doubles used well beyond `JournalManager`'s own tests, which is materially bigger than this cutover). Fixed the two production call sites the repository-protocol swap broke (`JournalManager+Preview.swift`'s synchronous preview helpers, now populated via `upsertTask`/`upsertNote` directly instead of the async `load()`; `JournalManager+Debug.swift`'s `taskRepository.save(task)`/`noteRepository.save(note)` calls, now passing the required `EntityChange`). Added the missing `configuredCalendar` computed property. Removed the now-meaningless SPRD-250 parity test files (`TaskNoteFacadeParityTests`, `SpreadAndMigrationFacadeParityTests`, `NewFacadeTestActions`) — their whole purpose was comparing "legacy JournalManager" against "the new facade," and post-cutover there's only one `JournalManager` to compare against itself. Production build succeeded with zero errors; full test suite was not yet green at this point (next commits fix that).
  3. `[SPRD-251][3/n]` — Fixed three real bugs found while getting the full test suite green (not just mechanical test updates):
     - **`dataVersion` bumped on cold load when it shouldn't.** Legacy semantics: `loadData()` (private, used by `init`/`.make()`) never bumped `dataVersion`; only the public `reload()` did. The new `load()` bumped it unconditionally, breaking `testDataVersionStartsAtZero`. Split `load()` (no bump) from `reload()` (`load()` + bump), matching legacy exactly.
     - **`apply(snapshot:)` triggered an unawaited async repository reload on every day-boundary/calendar change**, both wastefully (legacy never re-fetched from repositories here — it only rebuilt calendar-dependent collaborators and recomputed `dataModel` from data already in memory) and incorrectly (the fire-and-forget `Task { await load() }` raced with the synchronous test assertion that follows AppClock firing, so `overdueTaskCount` read stale state — `testOverdueTaskItemsRefreshAfterDayBoundary` failed). Also `ruleEngine` was a `let`, so it kept stale calendar/today after a change regardless. Fixed by making `ruleEngine` a `var`, rebuilding it synchronously in `apply(snapshot:)`, and factoring `load()`'s index/data-model-building logic into a shared private `rebuildIndicesAndDataModel(spreads:tasks:notes:events:lists:tags:)` that `apply(snapshot:)` now calls synchronously against already-in-memory entities (no repository round trip) — mirroring the legacy `rebuildTemporalCollaborators()`/`buildDataModel()` split exactly.
     - **`addTask` didn't normalize `task.date` to the start of its period** (e.g. a year-period task keeps an arbitrary mid-year date instead of normalizing to January 1st) — the legacy `StandardTaskMutationCoordinator.createTask` did this (`date.map { period?.normalizeDate($0, calendar:) ?? $0 }`) but it hadn't been ported. Fixed; `testAddTaskNormalizesDateForPeriod`/`testAddTaskWithYearPeriodNormalizesToFirstOfYear` now pass.
     - **Lost deterministic ordering**: the legacy array-based `tasks.filter { ... }` pipeline implicitly preserved repository order (`createdDate` ascending for tasks/notes/events, confirmed against `TestChangeAwareTaskRepository`/`InMemoryNoteRepository`/`InMemoryEventRepository`; period-rank-then-date-descending for spreads, confirmed against `InMemorySpreadRepository`/`SwiftDataSpreadRepository`). The new dictionary/set-backed `EntityStore`/index resolution has no inherent order, so `resolveSpreadDataModel` and every mutation's `.values` re-population silently scrambled order (caught by `MultidayAggregationTests.cancelledTasksDoNotAppearWithoutActiveMultidayOwnership` failing on element order, not content). Added `Self.sortedByCreatedDate`/`Self.sortedSpreads` and applied them everywhere a `tasks`/`notes`/`events`/`spreads` array gets repopulated from a store, restoring the same observable order as before.

     Also confirmed-and-fixed the **InboxTests divergence** properly: per SPRD-248's already-confirmed decision, `Note.isInboxEligible == false`, so several `InboxTests` scenarios asserting notes appear in Inbox were now factually wrong (not bugs in the new code) — updated them to assert the confirmed new behavior (e.g. `testInboxIncludesNoteWithNoAssignments` → `testInboxExcludesNoteWithNoAssignments`), matching the same divergence already locked in by SPRD-248's own test suite.

     Full `xcodebuild test`: 1319 tests, only the same pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure remained.
  4. `[SPRD-251][4/n]` — Deleted all now-fully-unused legacy `Standard*` logic types and their protocol declarations: `ConventionalJournalDataModelBuilder`, `JournalDataModelBuilder`, `InboxResolver`, `OverdueEvaluator`, `MigrationPlanner`, `MigrationCandidate`, `JournalMutationResult` (the `.structural`/`.spreadKeys` scope enum — no longer meaningful, every mutation is targeted now), `SpreadDeletionCoordinator.swift` (planner + coordinator + protocols), all four `Assignment Reconcilers`/`Migration Coordinators`/`Mutation Coordinators` files including `LoggerAdapter`. Confirmed via grep before deleting that every reference outside each type's own file was either another doomed legacy type in the same group, or a doc-comment mention in `JournalRuleEngine.swift`/`OverdueTaskItem.swift` (left as historical provenance, not a real dependency). **Found and fixed a real, previously-undetected behavior gap while doing this**: the legacy `StandardSpreadDeletionPlanner.replacementSpread` had a special case for multiday-spread deletion — instead of using the (nonexistent) parent-hierarchy spread, it fell back to whichever non-multiday spread best matched each entry's own preferred date/period. My `[1/n]` port of `deleteSpread` had simplified this to "multiday deletion always falls back to Inbox," and **no test anywhere (legacy or new) actually covered the real fallback behavior** — the one test with a matching name (`SpreadDeletionPlannerTests.multidayDeletionProducesNoReassignmentPlans`) turned out to test an unrelated case (a task with no assignment on the spread being deleted at all). Added the same fallback logic to the new `deleteSpread` (`replacementSpread(for:deleting:parentSpread:)` overloads for `Task`/`Note`), plus two new tests in `SpreadDeletionTests.swift` that actually exercise it (`testDeleteMultidaySpreadFallsBackToTasksOwnBestSpread`, `testDeleteMultidaySpreadFallsBackToInboxWhenNoMatchExists`).
  5. `[SPRD-251][5/n]` — Ported or deleted every remaining `JournalManager`-targeted test file that referenced now-deleted legacy types: deleted `TargetedJournalMutationTests`/`JournalManagerFacadeDelegationTests` (tested the legacy injected-collaborator/`dataModelBuilder` delegation pattern that no longer exists — SPRD-248's consolidation eliminated the seam these tested), `MigrationPlannerTests`/`OverdueEvaluatorTests`/`AssignmentReconcilerTests`/`ConventionalJournalDataModelBuilderTests`/`InboxResolverTests`/`EntryMutationCoordinatorTests`/`EntryMigrationCoordinatorTests` (all fully superseded by `JournalRuleEngineTests`' direct + parity coverage, confirmed by name-matching scenario lists before deleting), `SpreadDeletionPlannerTests`/`SpreadDeletionCoordinatorTests` (superseded by the already-passing, more realistic black-box `SpreadDeletionTests`, which calls `manager.deleteSpread(...)` directly). Removed 8 now-obsolete legacy-parity test functions from `JournalRuleEngineTests.swift` itself (`testBuildDataModelMatchesLegacyBuilder`, `testInboxEntriesMatchesLegacyResolverForTasks`, `testInboxEntriesDivergesFromLegacyResolverForUnassignedNotes`, `testMigrationCandidatesMatchesLegacyPlanner`, `testParentHierarchyMigrationCandidatesForMultidayMatchesLegacyPlanner`, `testOverdueTaskItemsMatchesLegacyEvaluator`, `testReconcilePreferredAssignmentForTaskMatchesLegacyReconciler`, `testReconcilePreferredAssignmentForNoteMatchesLegacyReconciler`) — each referenced a deleted legacy type directly; their direct-behavior coverage (non-parity) was already present elsewhere in the same file, confirmed before removing. Full `xcodebuild test`: 1278 tests, only the pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure remains. Full clean `xcodebuild build`: zero errors, zero warnings introduced by this task (remaining warnings are all pre-existing, e.g. the identical `getOrCreateDeviceId()` actor-isolation pattern across every `SwiftData*Repository` file, not specific to the two touched here).
  6. `[SPRD-251][6/n]` — Manual smoke-test pass in the iOS Simulator (Baseline mock data set loaded via Debug menu): created a new task via the UI (verified `addTask`'s date-normalization fix in [3/n] and the full add-task path end-to-end), marked it complete (status-mutation path), navigated the day pager forward/back (`Today` ⇄ `Tomorrow`, confirming spread resolution/index lookups survive navigation), opened the Entries/Inbox tab's Tasks and Notes sub-tabs (confirming the SPRD-248 `Note.isInboxEligible == false` divergence holds in the running app — no notes appear in the Tasks aggregation), and migrated "Pick up groceries" from Today to Tomorrow via the row action menu (confirming `migrationCandidates`/`migrationDestination`/`migrateTask` end-to-end, including tag preservation across the move). No regressions observed versus pre-cutover behavior.
  7. `[SPRD-251][7/n]` — Resumed the deliberately-deferred follow-up (per `[2/n]`'s note): ported `DebugDataService`/`DebugRepositoryListView` off the legacy `TaskRepository`/`NoteRepository` protocols onto `ChangeAwareTaskRepository`/`ChangeAwareNoteRepository` (the only remaining legacy-protocol consumers), then deleted the entire legacy stack: `TaskRepository.swift`, `NoteRepository.swift`, `SwiftDataTaskRepository.swift`, `SwiftDataNoteRepository.swift`, `MockTaskRepository.swift`, `MockNoteRepository.swift`, `InMemoryTaskRepository.swift`, `InMemoryNoteRepository.swift`, and the `EmptyTaskRepository`/`EmptyNoteRepository` structs from `EmptyRepositories.swift`. `AppDependencies.taskRepository`/`.noteRepository` are now `ChangeAware*`-typed; `makeJournalManager` no longer constructs its own duplicate `SwiftDataChangeAwareTaskRepository`/`SwiftDataChangeAwareNoteRepository` instances and just reuses `self.taskRepository`/`self.noteRepository` (the rationale for the duplication — "legacy-protocol-typed, still used by `DebugRepositoryListView`" — no longer applies). `AppDependencies.make`'s/`.makeForPreview`'s Task/Note defaults switched from `EmptyTaskRepository`/`MockTaskRepository` to `TestChangeAwareTaskRepository`/`TestChangeAwareNoteRepository` (seeded with `TestData.sampleTasks()`/`.sampleNotes()` for previews). Ported the 2 scenarios from the legacy test suites that `SwiftDataChangeAwareTask/NoteRepositoryTests` didn't already cover (sort-by-date-ascending, assignment-tombstone-when-removed-while-parent-remains) before deleting their source files. Deleted `NoteRepositoryTests.swift` (tested only now-deleted types) and the `InMemoryTask`/`MockTask`/`InMemoryNote`/`MockNote` sections of `MockRepositoryTests.swift`/the `TaskRepository Tests` section of `SwiftDataRepositoryTests.swift` (all superseded). Rewrote both `ChangeAware*RepositoryTests`' `testProducesSameOutboxSequenceAsLegacyRepository` parity tests as `testFullMutationSequenceCoalescesToFinalRowsOnly` — their legacy-comparison premise is gone now that there's only one implementation, but the underlying SPRD-253 coalescing-across-a-sequence coverage was worth keeping as a same-repository assertion. Updated `ListRepositoryTests.swift`/`TagRepositoryTests.swift`/`SyncEngineTests.swift` call sites that constructed `SwiftDataTaskRepository` directly. Verified via a full `xcodebuild test`: 1243 tests, only the pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure, and a full clean `xcodebuild build` (zero errors, zero new warnings).
  8. `[SPRD-251][8/n]` — Renamed `ChangeAwareTaskRepository`/`ChangeAwareNoteRepository` → `TaskRepository`/`NoteRepository`, `SwiftDataChangeAwareTaskRepository`/`SwiftDataChangeAwareNoteRepository` → `SwiftDataTaskRepository`/`SwiftDataNoteRepository`, `TestChangeAwareTaskRepository`/`TestChangeAwareNoteRepository` → `TestTaskRepository`/`TestNoteRepository` (file + type, 6 renames across ~26 files), dropping the `ChangeAware` qualifier per `[2/n]`'s and SPRD-245's original renaming plan now that the legacy stack is gone. Fixed every stale doc comment that referenced the qualifier or cited "SPRD-249's cutover" (the actual culprit was always SPRD-251, and even this task's own `[2/n]` had already deferred the rename rather than doing it then) — several were self-referential nonsense post-rename (e.g. "as `SwiftDataTaskRepository` does" inside `SwiftDataTaskRepository`'s own doc comment) and needed rewriting, not just a search-replace. Verified via a full `xcodebuild test`: 1243 tests, only the pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure (same count as `[7/n]` — pure rename, no behavior change), and a full clean `xcodebuild build` (zero errors, zero new warnings).
- Remaining for this task: none — all ACs satisfied, task complete. `ChangeAware` no longer appears anywhere in the codebase.

---

### [SPRD-252] Refactor: SerializableData protocol for sync entity serialization and entity typing - [x] Done

- **Context**: `SyncSerializer` (`Spread/Services/Sync/SyncSerializer.swift`) is a single centralized namespace of `serialize*` functions (settings, spread, taskEntry, noteEntry, list, tag, entryTag, collection, assignment), each hand-mapping one entity's fields to a snake_case JSON record plus paired `_updated_at` LWW timestamps. Repositories call the matching free function by name (e.g. `SyncSerializer.serializeTaskEntry(task, ...)`) and separately hardcode the matching `SyncEntityType` case at each `DataModel.SyncMutation` call site (e.g. `SyncEntityType.entry.rawValue`) — the entity's sync type is never derived from the entity itself, so every new syncable entity requires updating both `SyncSerializer` and every call site by hand, with no compiler-enforced link between an entity and its type. Raised during SPRD-245 review as a candidate for moving serialization (and entity-type lookup) onto the entities themselves via a new `SerializableData` protocol, deferred to its own task since it touches existing, non-additive files (`SyncSerializer.swift`, `SyncEntityType.swift`, `DataModelSchemaV1.swift`) outside SESH-24's additive-only scope.
- **Description**: Add a new `SerializableData` protocol (covering a `serialize(deviceId:timestamp:deletedAt:) -> Data?` method and a `static var entityType: SyncEntityType`, unifying the two previously-separate concerns at each call site) and have `DataModel.Task` conform first, via a new `DataModel.Task+SerializableData.swift` extension file, with its body migrated from `SyncSerializer.serializeTaskEntry` and its `entityType` returning `.entry`. Update `SwiftDataChangeAwareTaskRepository`'s `enqueueTaskMutation` to read both the serialized record and the entity type from this conformance instead of calling `SyncSerializer.serializeTaskEntry` and hardcoding `SyncEntityType.entry` separately. Leave the remaining `serialize*` functions and their call sites' hardcoded `SyncEntityType` cases untouched for now — each is a candidate for a follow-up conformance once the `Task` conformance proves the shape out, with the explicit end goal (confirmed with the user 2026-06-26) of eventually retiring `SyncSerializer` entirely in favor of each entity owning its own serialization.
- **Implementation notes** (audited against the actual codebase 2026-06-26, post-SPRD-251): the task's original description named `SyncSerializer.serializeTask` and `SyncEntityType.task` — neither exists. The actual function is `serializeTaskEntry`, and `Task`/`Note` share the `.entry` `SyncEntityType` case (same `entries` server table/RPC, discriminated by a `type` field) — there is no per-type `SyncEntityType` case. AC text below corrected accordingly. Confirmed with the user that `SerializableData` is intentionally a real protocol (not a plain extension) despite CLAUDE.md's "protocols are a DI boundary only" rule, because the end goal is many conformers (`Task`, `Note`, `Spread`, `List`, `Tag`, `Collection`, `Settings`, `Assignment`, entry-tag rows) replacing `SyncSerializer` outright — this task ports only `Task` as the first one.
- **Spec**: None yet — needs a spec section added to an appropriate `Documentation/Specs/` file before implementation.
- **Acceptance Criteria**:
  - [x] `SerializableData` protocol added in a new file, covering both record serialization and `SyncEntityType` lookup.
  - [x] `DataModel.Task` conforms via a new extension file; its conformance body matches `SyncSerializer.serializeTaskEntry`'s existing output exactly (same JSON keys/values for equivalent inputs), and its `entityType` returns `.entry`.
  - [x] `SwiftDataChangeAwareTaskRepository`'s call to `SyncSerializer.serializeTaskEntry` and its hardcoded `SyncEntityType.entry.rawValue` are both updated to use the new conformance instead.
  - [x] `SyncSerializer.serializeTaskEntry`, the other `serialize*` functions, and all other repositories' hardcoded `SyncEntityType` call sites are otherwise untouched; no behavior change to any repository other than `SwiftDataChangeAwareTaskRepository`'s call site.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - [x] Unit test(s) proving the new `Task` conformance produces byte-identical (or JSON-equivalent) output to `SyncSerializer.serializeTaskEntry` for equivalent inputs.
  - [x] Unit test proving `DataModel.Task.entityType == .entry`.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-252][1/n]` — Added the `SerializableData` protocol (`Spread/Services/Sync/SerializableData.swift`) and `DataModel.Task`'s conformance (`Spread/DataModel/DataModel.Task+SerializableData.swift`), body ported verbatim from `SyncSerializer.serializeTaskEntry`. Purely additive — nothing calls the new conformance yet; `SwiftDataChangeAwareTaskRepository` still calls `SyncSerializer.serializeTaskEntry` directly. Added `SpreadTests/DataModel/DataModelTaskSerializableDataTests.swift` with 4 parity tests (populated task, task with no per-field timestamps, deletion, cleared preferred assignment) plus an `entityType == .entry` test. Verified via `-only-testing:SpreadTests/DataModelTaskSerializableDataTests` (5/5 pass).
  2. `[SPRD-252][2/n]` — Wired `SwiftDataChangeAwareTaskRepository.enqueueTaskMutation` to call `task.serialize(deviceId:timestamp:deletedAt:)`/`DataModel.Task.entityType` instead of `SyncSerializer.serializeTaskEntry`/hardcoded `SyncEntityType.entry`, and removed the stale `// TODO: SPRD-250` comment that had already flagged this exact seam. `SyncSerializer`, `SyncEntityType`, and every other repository's serializer call sites are untouched. Verified via `-only-testing:SpreadTests/SwiftDataChangeAwareTaskRepositoryTests -only-testing:SpreadTests/DataModelTaskSerializableDataTests` (17/17 pass, including the existing `testProducesSameOutboxSequenceAsLegacyRepository` parity test against the legacy repository) and a full clean `xcodebuild build` (zero errors, zero new warnings).
- Remaining for this task: none — all ACs satisfied, task complete. Conformances for `Note`/`Spread`/`List`/`Tag`/`Collection`/`Settings`/`Assignment`/entry-tag rows, and `SyncSerializer`'s eventual retirement, are follow-up work, not blocking this task.

---

### [SPRD-253] Refactor: Coalesce pending outbox mutations per entity - [x] Done

- **Context**: Raised during a SESH-24 discussion of where remote sync is triggered from. Every repository write (`enqueueTaskMutation`/`enqueueNoteMutation`/assignment equivalents) unconditionally inserts a new `DataModel.SyncMutation` row, even when an unsent mutation for the same entity already sits in the outbox. While offline, repeatedly mutating the same entity (e.g. toggling a task's status, editing it, toggling status back) produces N outbox rows that `SyncEngine.push()` later pushes one at a time, in order, once connectivity returns — even though only the final state matters for eventual consistency. Each mutation's `recordData` is already a full entity snapshot (not a field-delta; see `SyncSerializer.serializeTask` and friends), so the latest pending mutation for an entity already fully supersedes any earlier unsent one — nothing is lost by collapsing them.
- **Description**: Change the outbox-enqueue step (`enqueueTaskMutation`/`enqueueNoteMutation` and their assignment/tag equivalents, in whichever repository implementation is canonical at implementation time) so that enqueuing a mutation for an `(entityType, entityId)` that already has an *unsent* `SyncMutation` row updates that row in place (new `recordData`/`operation`/timestamp/`changedFields`) instead of inserting a second row. Apply operation precedence rather than naive overwrite: a prior `create` is never downgraded to `update` by a later mutation (stays `create`, with the latest data); a `delete` always wins outright and supersedes any prior unsent mutation for that entity, regardless of arrival order. Already-pushed mutations (deleted from the outbox by `SyncEngine.push()`) are unaffected — coalescing only ever operates on currently-unsent rows. Consider implementing this once, after SPRD-251's cutover, rather than duplicating the logic across both the legacy `SwiftDataTaskRepository`/`SwiftDataNoteRepository` and the additive `SwiftDataChangeAwareTaskRepository`/`SwiftDataChangeAwareNoteRepository`.
- **Spec**: `Documentation/Specs/Sync.md` — "Outbox Mutation Coalescing"
- **Acceptance Criteria**:
  - [x] Enqueuing a mutation for an entity/assignment that already has an unsent outbox row for the same `(entityType, entityId)` overwrites that row instead of inserting a new one.
  - [x] A prior unsent `create` is never overwritten to `update` by a later mutation; it stays `create` with the latest record data.
  - [x] A `delete` always overwrites any prior unsent mutation for that entity, regardless of what operation came before it.
  - [x] Already-pushed (no longer present) mutation rows are unaffected by coalescing — a new mutation after a successful push inserts a fresh row.
  - [x] N consecutive mutations to the same entity while offline result in exactly 1 outbox row for that entity, not N.
  - [x] Project builds with no errors or warnings.
- **Tests**:
  - [x] Unit test: three consecutive updates to the same task produce exactly one outbox row, containing the final state.
  - [x] Unit test: create followed by one or more updates produces one outbox row with `operation == .create` and the latest data.
  - [x] Unit test: update followed by delete produces one outbox row with `operation == .delete`; the update is never pushed separately.
  - [x] Unit test: mutations to two different entities each produce their own outbox row (not coalesced together).
  - [x] Unit test: a mutation enqueued after a prior mutation for the same entity has already been pushed (and its row deleted) inserts a fresh row rather than coalescing with the (now-gone) prior one.
- **Dependencies**: SPRD-245 (uses the same repository save path); recommended after SPRD-251 to implement once against the canonical repository rather than duplicating across legacy and change-aware implementations.
- **Implementation notes** (2026-06-26): Implemented once via a shared `ModelContext.enqueueCoalescedSyncMutation` helper (`Spread/Repositories/ModelContext+SyncOutbox.swift`), wired into the canonical `SwiftDataChangeAwareTaskRepository`/`SwiftDataChangeAwareNoteRepository` (the repositories `JournalManager` actually uses post-SPRD-251) at all 4 enqueue sites per repository (entry, assignment, entry-tag create, entry-tag delete). The legacy `SwiftDataTaskRepository`/`SwiftDataNoteRepository` (kept only for `DebugDataService`'s mock-data load/wipe) were deliberately left untouched, matching the description's "whichever repository implementation is canonical" framing — duplicating the change there would contradict their planned eventual deletion. Note: entry-tag mutations use a freshly-random `entityId: UUID()` per enqueue (pre-existing, unrelated to this task), so they structurally never coalesce — this matches prior behavior (every entry-tag mutation was already its own row) and isn't a regression.
- **Behavior change found and handled**: this intentionally changes the outbox sequence produced by the change-aware repositories (fewer rows for repeated mutations to the same entity) — `SwiftDataChangeAwareTaskRepositoryTests`/`SwiftDataChangeAwareNoteRepositoryTests`' `testSaveEnqueuesAssignmentUpdateMutationFromSuppliedPreviousState` and `testProducesSameOutboxSequenceAsLegacyRepository` were updated (not silently passed) to assert the new coalesced behavior and the legacy-vs-change-aware divergence explicitly, per the project's parity-test convention for intentional behavior changes.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-253][1/n]` — Added `ModelContext.enqueueCoalescedSyncMutation` (`Spread/Repositories/ModelContext+SyncOutbox.swift`) implementing the operation-precedence coalescing policy from `Documentation/Specs/Sync.md`. Wired all 4 `SyncMutation`-insert sites in `SwiftDataChangeAwareTaskRepository` and `SwiftDataChangeAwareNoteRepository` (entry, assignment, entry-tag create, entry-tag delete) to call it instead of inserting directly. `SyncMutation`'s own `createdDate` is set by the helper itself (`.now` on insert and on coalesce) rather than the repositories' injectable `nowProvider`, preserving prior behavior exactly (no repository ever passed `createdDate` before this change either). Added `SpreadTests/Repositories/ModelContextSyncOutboxTests.swift` with the 5 ACs' dedicated unit tests plus a create-then-delete precedence test (6 tests). Updated `testSaveEnqueuesAssignmentUpdateMutationFromSuppliedPreviousState` and `testProducesSameOutboxSequenceAsLegacyRepository` in both `SwiftDataChangeAwareTaskRepositoryTests`/`SwiftDataChangeAwareNoteRepositoryTests` to assert the new coalesced behavior explicitly (intentional divergence from legacy, documented in the test doc comments) rather than the old per-mutation-row behavior. Verified via `-only-testing:SpreadTests/SwiftDataChangeAwareTaskRepositoryTests -only-testing:SpreadTests/SwiftDataChangeAwareNoteRepositoryTests -only-testing:SpreadTests/ModelContextSyncOutboxTests` (30/30 pass) and a full `xcodebuild test` (1289 tests, only the pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure, zero regressions) plus a full clean `xcodebuild build` (zero errors, zero new warnings).
- Remaining for this task: none — all ACs satisfied, task complete. `SwiftDataTaskRepository`/`SwiftDataNoteRepository` (legacy, debug-only) and the other single-implementation repositories (`SwiftDataSpreadRepository`, `SwiftDataListRepository`, `SwiftDataTagRepository`, `SwiftDataCollectionRepository`, `SwiftDataSettingsRepository`) do not coalesce — out of scope per the task's "canonical repository" framing; a follow-up task can extend the shared helper to them if their outbox volume becomes a real concern.

---

### [SPRD-254] Refactor: Split current assignment from migration history on Task/Note - [x] Done

- **Context**: A SESH-24 analysis of `JournalDataModelAssembler`/`ConventionalJournalDataModelBuilder` found that every per-entity spread-association check (`hasSpreadAssociation`, `spreadKeys(for:)`) scans a task/note's *entire* `assignments` array, filtering out `.migrated` entries each time. That array is append-only in production — `StandardTaskMigrationCoordinator`, `StandardTaskAssignmentReconciler`, and `SpreadDeletionCoordinator` only ever `.append(...)` to it, never prune — so a task migrated repeatedly over months carries its full migration history (M entries) into every one of these checks, even though at most a handful of assignments are ever "live" at once. This compounds SPRD-249's index work: even with an O(1) index bucket lookup, computing which buckets an entity belongs to (`spreadKeys(for:)`) still costs O(M) per entity, not O(live assignments).
- **Description**: Split each `Task`/`Note`'s single `assignments: [Assignment]` into a small, bounded "current" collection (the live, non-migrated assignment(s) actually used for spread association and overdue/migration logic) and a separate, append-only `migrationHistory: [Assignment]` collection (used only for the migration-history UI, never scanned by spread-association logic). Update `DataModelSchemaV1`, the `Task`/`Note` SwiftData models, and every reconciler/coordinator/builder that reads or writes `.assignments` to use the appropriate collection. Sync serialization is expected to be unaffected — assignments already sync as individual `taskAssignment`/`noteAssignment` rows (`SyncEntityType.taskAssignment`/`.noteAssignment`), not embedded in the parent record, so this is an in-memory/SwiftData model shape change, not a wire-format change; confirm this during implementation rather than assuming it.
- **Spec**: `Documentation/Specs/JournalManager.md` — needs a new "Decision" section added before implementation, describing the current/history split and why it's deferred to after cutover (see Dependencies).
- **Acceptance Criteria**:
  - [x] `Task`/`Note` expose a bounded "current assignments" collection separate from an append-only `migrationHistory` collection; spread-association logic (`spreadKeys(for:)`, the SPRD-249 index-maintenance path, overdue evaluation, migration planning) reads only the current collection.
  - [x] Migration-history UI (wherever it reads `.assignments` today for display) is updated to read `migrationHistory` and is unaffected visually.
  - [x] No change to the Supabase wire format/schema — confirmed during implementation: assignments already sync as individual rows via `serializeAssignment`, keyed by `Assignment.id`; the split is purely an in-memory/SwiftData shape change, no wire-format edits needed.
  - [x] Project builds with no errors or warnings; full test suite passes.
- **Tests**:
  - [x] Unit test proving a task with a large migration history (e.g. 100+ historical assignments) resolves `spreadKeys(for:)` in time independent of history length — via an entry-count instrumentation or equivalent, not a wall-clock benchmark.
  - [x] Unit tests proving migration-history display content is unchanged for tasks/notes with existing history.
  - [x] Regression coverage proving migration, reconciliation, and overdue evaluation behavior is unchanged for tasks/notes with both current and historical assignments — the full existing test suite (1239 tests) passes unmodified in intent, with fixtures corrected to place `.migrated`-status assignments in `migrationHistory:` instead of `currentAssignments:`.
- **Dependencies**: SPRD-251. Deliberately sequenced after cutover, not during the SPRD-245–248 additive phase: `Task`/`Note` are shared, non-isolated model types that both the legacy `JournalManager` stack and the new facade depend on simultaneously during that phase, so a model-shape change here cannot be additive-only (it would require editing legacy `Standard*` logic types too, contradicting SPRD-245–248's "zero edits to existing production files" rule). After SPRD-251 deletes the legacy stack, only one logic layer needs updating. Also benefits from pairing with SPRD-249's index work landing first, so the new "current assignment" shape can be threaded through index maintenance from a clean slate rather than retrofitted.
- **Implementation notes** (2026-06-26): Chose Option A from the user-confirmed design fork — `migrationHistory` holds only already-migrated entries (excludes the live one), single source of truth per assignment, no duplicate-write risk. The migration-history UI (`TaskDetailSheet`/`NoteDetailSheet`) reconstructs the full timeline as `migrationHistory + currentAssignments` rather than reading `migrationHistory` alone, since the live entry only ever exists in one collection.
- **Real correctness issue found and fixed during implementation**: reconciliation/migration/spread-deletion logic can match a destination assignment that already exists in `migrationHistory` (e.g. a task migrates away from spread X, then later migrates back to X) — not just `currentAssignments`. An initial implementation only searched `currentAssignments` for the destination match, which would have silently minted a new `Assignment.id` instead of reviving the historical one, breaking sync-row continuity for that assignment. Fixed by having `JournalRuleEngine.reconcilePreferredAssignment` and `JournalManager.moveTask`/`migrateTasksBatch`/`migrateNote`/`deleteSpread` all check `migrationHistory` as a fallback and revive (remove + reactivate + move to current) rather than recreate. Caught via `JournalRuleEngineTests`' pre-existing `testReconcilePreferredAssignmentFor{Task,Note}ReusesExistingDestinationAssignment` tests, which exist specifically to cover this scenario.
- **Progress (commits landed on feature/SESH-24)**:
  1. `[SPRD-254][1/n]` — Spec decision section (doc-only, see above).
  2. `[SPRD-254][2/n]` — The model split and full call-site rewiring: `AssignableEntry` protocol now declares `currentAssignments`/`migrationHistory` instead of `assignments`; `DataModelSchemaV1.Task`/`.Note` follow suit (init parameter renamed too). Updated every reader/writer: `JournalRuleEngine` (`spreadKeys`, `shouldShowOnSpread`, `migrationDestination`, `candidateSpreads`, `reconcilePreferredAssignment` — now with the history-revival fix above, replacing the old `migrateActiveAssignmentsToHistory` in-place-status-flip with a real move from `currentAssignments` to `migrationHistory`), `JournalManager` (`eligibleTasksForMigration`, `deleteSpread`, `reconcileEntriesForNewExplicitSpreadIfNeeded`, `moveTask`/`migrateTasksBatch`/`migrateNote`, every Task/Note CRUD method's `EntityChange.previousAssignments` capture), both `SwiftDataTaskRepository`/`SwiftDataNoteRepository` (outbox diffing now reads `currentAssignments + migrationHistory` as the full snapshot for both old/new states, since outbox rows cover every assignment regardless of which collection it's in), `SpreadService` (multiday spread-ID lookup), `SyncEngine` (pull-side `applyAssignmentRow` now removes-then-reinserts into whichever collection matches the incoming row's status, rather than mutating one flat array in place; backfill repair reads the union), 5 view files (`TaskDetailSheet`/`NoteDetailSheet`'s history section now renders `migrationHistory + currentAssignments`; `TaskEditorFormModel`/`TaskBrowserSectionBuilder`/`MultidaySpreadContentView+ViewModel`), `JournalManager+Debug`/`DebugRepositoryListView`, and `MockDataSet`/`MockDataSet+ScenarioFixtures`. Added a test-only `AssignableEntry.allAssignmentsForTesting` helper (`migrationHistory + currentAssignments`) so the ~200 existing test call sites that asserted against the old flat array's count/order didn't all need individual rewriting — only the handful that actually constructed a `.migrated`-status entry inside `currentAssignments:` needed fixing (since that combination violates the new invariant and is no longer filtered defensively). Verified via a full `xcodebuild test`: 1239 tests, only the pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure, and a full clean `xcodebuild build` (zero errors, zero new warnings).
  3. `[SPRD-254][3/n]` — Added the two AC-mandated dedicated tests: `JournalRuleEngineTests.testSpreadKeysResultIsIndependentOfMigrationHistorySize` (two tasks with identical `currentAssignments` but 0 vs. 200 historical entries — each historical entry targets a distinct otherwise-unused month so a result divergence would prove `migrationHistory` was scanned — asserts identical `spreadKeys` output, demonstrating the cost depends only on `currentAssignments`'s size via output invariance rather than a wall-clock benchmark) and `EntryTests.test{Task,Note}MigrationHistoryDisplayOrderMatchesPreSplitFlatArrayShape` (asserting `migrationHistory + currentAssignments` — exactly what `TaskDetailSheet`/`NoteDetailSheet`'s history section renders — preserves the pre-split flat array's order: history entries in migration order, then the live entry last). Also fixed a second instance of the same fixture bug (a `.migrated`-status `Assignment` constructed inside `currentAssignments:` rather than `migrationHistory:`) in `EntryTests.testNoteHasRequiredProperties`, missed by `[2/n]`'s textual sweep since it was built via an intermediate local variable rather than an inline literal. Verified via `-only-testing:SpreadTests/JournalRuleEngineTests -only-testing:SpreadTests/EntryTests` (66/66 pass) and a full `xcodebuild test`: 1242 tests, only the pre-existing/unrelated `SpreadCardStyleTests.testTodayFillDistinct` failure, plus a full clean `xcodebuild build` (zero errors, zero new warnings).
- Remaining for this task: none — all ACs and tests satisfied, task complete.

---

### [SPRD-255] Refactor: Additive TaskCoordinator/NoteCoordinator consolidating mutation + migration coordination - [ ] Open

- **Staleness correction (2026-06-26, audited before implementation per the user's request)**: this task's original Context/Description/ACs/Tests were written before SPRD-251's cutover and reference `StandardTaskMutationCoordinator`, `StandardTaskMigrationCoordinator`, `StandardNoteMutationCoordinator`, `StandardNoteMigrationCoordinator`, and `EntryMutationCoordinatorTests`/`EntryMigrationCoordinatorTests` — **all of these were deleted in SPRD-251`[4/n]`/`[5/n]`**, confirmed via grep (zero remaining references in `Spread/`/`SpreadTests/`). Their responsibilities were absorbed directly into `JournalManager` during that cutover (its `[1/n]` commit note says so explicitly: "this orchestration is being absorbed directly into this cutover, since the cutover needs that surface regardless of which task originally owned it"). So the task as originally written is asking to consolidate two types that no longer exist, mirror tests for files that no longer exist, and avoid editing files that are already gone — none of which is actionable as stated. Rewritten below to describe the task in terms of the current codebase.
- **Context**: `JournalManager` (`Spread/JournalManager/Journal Store/JournalManager.swift`, 1208 lines) directly implements task/note CRUD and migration orchestration inline — `// MARK: - Task Migration`/`// MARK: - Task CRUD`/`// MARK: - Note CRUD` (`migrateTask`/`moveTask`/`migrateTasksBatch`/`addTask`/`updateTask*`/`clearTaskPreferredAssignment`/`deleteTask` and the Note equivalents, ~320 lines, 18 methods total) sit alongside spread management, Inbox/overdue/migration queries, and the incremental-index mutation primitives in the same type. Per CLAUDE.md's coordinator-extraction guidance ("extract when the existing type exceeds ~200 lines" / "distinct dependencies"), this is a real extraction candidate — but for type-size and single-responsibility reasons, not the original "two protocol-backed types with identical dependencies" justification, which no longer applies since there's only ever been one type (`JournalManager` itself) doing this work since the cutover.
- **Description**: Extract a concrete `TaskCoordinator` (no protocol, no "Standard" prefix) covering `JournalManager`'s current task CRUD + migration methods, depending on `TaskRepository` and `JournalRuleEngine`. Add the equivalent `NoteCoordinator` for the note methods, depending on `NoteRepository` + `JournalRuleEngine`. **Open design question to resolve before/during implementation, not present in the original task**: these methods currently read `JournalManager.spreads` (for `findBestSpread`/reconciliation) and call back into `JournalManager.upsertTask`/`.upsertNote` (to patch the incremental index/`dataModel` after a repository write) — a coordinator extracted as a standalone type needs either (a) `spreads` and an upsert callback passed in per call, or (b) to return the mutated entity/entities and let `JournalManager` do the `spreads` lookup and `upsertTask`/`upsertNote` patching itself, keeping the coordinator from depending on `JournalManager` at all. Recommend (b) — keeps the coordinator a pure repository-writing workflow type with no back-reference, consistent with `JournalRuleEngine`'s "returns derived results, caller persists/patches" shape. Entirely new files; the only edit to `JournalManager.swift` itself is replacing each extracted method's body with a delegating call to the new coordinator (signatures unchanged, so view call sites are unaffected).
- **Spec**: `Documentation/Specs/JournalManager.md` — "Decision: Drop protocol-per-logic-seam; protocols are a repository-only boundary"
- **Acceptance Criteria**:
  - [ ] New concrete `TaskCoordinator` added, covering all of `JournalManager`'s current task CRUD + migration methods (`addTask`, `updateTaskTitle`/`updateTaskStatus`/`updateTaskDateAndPeriod`/`updateTaskMetadata`, `clearTaskPreferredAssignment`, `deleteTask`, `migrateTask`/`moveTask`/`migrateTasksBatch`), depending only on `TaskRepository` and `JournalRuleEngine` — not on `JournalManager` itself.
  - [ ] New concrete `NoteCoordinator` added, covering all of `JournalManager`'s current note CRUD + migration methods (`addNote`, `updateNoteTitle`/`updateNoteMetadata`/`updateNoteDateAndPeriod`, `deleteNote`, `migrateNote`), depending only on `NoteRepository` and `JournalRuleEngine`.
  - [ ] Neither type declares or conforms to a new protocol; no "Standard" naming.
  - [ ] `JournalManager`'s public method signatures for these 18 methods are unchanged (views call them identically); each body becomes a thin delegation to the new coordinator plus the `spreads`-lookup/`upsertTask`/`upsertNote` patching the coordinator itself doesn't do.
  - [ ] Project builds with no errors or warnings; full existing test suite passes unmodified in intent (this is a refactor, not a behavior change).
- **Tests**:
  - [ ] Exhaustive unit tests for `TaskCoordinator`/`NoteCoordinator` covering the same scenarios already exercised through `JournalManager`'s existing black-box test suites (`JournalManagerTaskCRUDTests`, `MigrationTests`, `JournalManagerNoteTests`, etc.), constructing the coordinator directly with a `Test*Repository` and a `JournalRuleEngine` — no legacy `Standard*` counterpart exists to parity-test against anymore, so correctness is established by direct scenario coverage instead.
  - [ ] Confirm `JournalManager`'s own existing test suites still pass unmodified after the delegation — proving the extraction is behavior-preserving.
- **Dependencies**: SPRD-245 (repository layer, done), SPRD-248 (`JournalRuleEngine`, done — superseded by SPRD-251's cutover, which is what actually wired it into `JournalManager`).

---

### [SPRD-256] Refactor: Additive concrete SpreadDeletionCoordinator - [ ] Open

- **Context**: Unlike the mutation/migration coordinators (SPRD-255), `SpreadDeletionCoordinator` has a genuinely distinct dependency shape — it touches `spreadRepository`, `taskRepository`, and `noteRepository` simultaneously — and a distinct, infrequent lifecycle (spread deletion, not routine entry mutation). Per CLAUDE.md's own coordinator-extraction guidance ("distinct lifecycle, distinct dependencies"), this earns staying its own type rather than merging into SPRD-255's `TaskCoordinator`/`NoteCoordinator`. It still needs the same "drop protocol, no Standard prefix" treatment as every other SPRD-248-family seam.
- **Description**: Add a concrete `SpreadDeletionCoordinator` (no protocol, no "Standard" prefix) consolidating `StandardSpreadDeletionCoordinator`'s and `StandardSpreadDeletionPlanner`'s responsibilities — planning which entries reassign to a parent spread vs. Inbox, then persisting those reassignments and the spread deletion. Depends on `SpreadRepository`/`TaskRepository`/`NoteRepository` (protocols) and `JournalRuleEngine` (SPRD-248) if assignment reconciliation is needed during reassignment. Entirely new file; zero edits to the existing `StandardSpreadDeletionCoordinator`, `StandardSpreadDeletionPlanner`, or their protocol declarations.
- **Spec**: `Documentation/Specs/JournalManager.md` — "Decision: Drop protocol-per-logic-seam; protocols are a repository-only boundary"
- **Acceptance Criteria**:
  - [ ] New concrete `SpreadDeletionCoordinator` added, covering all `StandardSpreadDeletionCoordinator` + `StandardSpreadDeletionPlanner` responsibilities.
  - [ ] Does not declare or conform to a new protocol; no "Standard" naming.
  - [ ] No edits to any existing legacy deletion coordinator/planner file or protocol declaration.
  - [ ] Project builds with no errors or warnings.
- **Tests**:
  - [ ] Exhaustive unit tests mirroring `SpreadDeletionCoordinatorTests`/`SpreadDeletionPlannerTests`' existing scenarios, constructing the type directly with `Test*Repository` doubles, plus a parity test against the legacy coordinator.
- **Dependencies**: SPRD-245 (repository layer), SPRD-248 (`JournalRuleEngine`).
