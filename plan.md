# Bulleted Implementation Plan (v1.0)

## Scope Update
- Events are deferred to v2; v1 ships without event creation or display. [SPRD-69]
- Existing event scaffolding must be stubbed/hidden for v1 and kept ready for v2 integration. [SPRD-69]

## Story Overview (v1)
- Foundation and scaffolding (completed)
- Core time and data models
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
    - `static func makeForTesting(taskRepo:, spreadRepo:, ...) throws -> DependencyContainer`
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

## Story: Core time and data models

### User Story
- As a user, I want the app to understand days, months, years, and multiday ranges so my journal entries are organized correctly.

### Definition of Done
- Date utilities and period normalization support first-weekday settings.
- Spread/Entry/Assignment models exist with multiday support.
- Date and multiday preset tests pass.

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

### [SPRD-49] Feature: Unit tests for date + multiday presets
- **Context**: Date logic is error-prone.
- **Description**: Add unit tests for normalization, presets, and first weekday override.
- **Acceptance Criteria**:
  - Tests cover locale week start, overrides, and boundaries. (Spec: Edge Cases)
- **Tests**:
  - Unit tests across month/year boundaries.
- **Dependencies**: SPRD-7, SPRD-8

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



## Story: Journal core: creation, assignment, inbox, migration

### User Story
- As a user, I want to create spreads, assign entries, and migrate tasks so my journal stays current as plans change.

### Definition of Done
- JournalManager loads data and enforces spread creation rules.
- Assignment engine and Inbox auto-resolve logic are implemented.
- Migration logic and cancelled-task behavior are implemented.
- Unit tests for creation, assignment, and migration pass.

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

## Story: Conventional MVP UI: create spreads and tasks

### User Story
- As a user, I want to create spreads and tasks from a clear navigation shell so I can start journaling quickly.

### Definition of Done
- Adaptive root navigation renders spreads and content for iPad and iPhone.
- User can create spreads and tasks; tasks render in spread lists.
- Entry list grouping and Inbox sheet behavior work end-to-end.
- Entry rows and symbols are used consistently in lists.
- Spread content surfaces use dot grid background and minimal paper styling.

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

### [SPRD-23] Feature: Task creation sheet
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

## Story: Debug and dev tools

### User Story
- As a user, I want debug tools and quick actions so I can inspect data and iterate faster.

### Definition of Done
- Debug menu and quick actions are available in Debug builds only.
- Test data builders and debug logging hooks are implemented.
- Debug menu includes appearance overrides for paper tone, dot grid, heading font, and accent color.
- Debug menu is a top-level navigation destination: tab bar item on iPhone and sidebar item on iPad (SF Symbol `ant`), with the overlay removed.

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

### [SPRD-63] Feature: Debug appearance overrides
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

### [SPRD-47] Feature: Test data builders
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

### [SPRD-48] Feature: Debug logging hooks (Debug only)
- **Context**: Assignment/migration debugging needs visibility.
- **Description**: Add debug logging for assignment, migration, and inbox resolution.
- **Implementation Details**:
  - Logging wrapper gated by `#if DEBUG`
  - Log events: assignment created, migration performed, inbox resolved, spread deleted
  - Include relevant context (entry ID, spread info, status changes)
- **Acceptance Criteria**:
  - Logging is gated to Debug builds. (Spec: Development tooling)
- **Tests**:
  - Unit test for debug flag gating.
- **Dependencies**: SPRD-47

### [SPRD-65] Feature: Leap day boundary test data
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
- Migrated tasks section and migration banner are wired to JournalManager.

### [SPRD-24] Feature: Entry detail/edit view (Task)
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



### [SPRD-29] Feature: Migrated tasks section
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

### [SPRD-30] Feature: Migration banner + selection
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

## Story: Scope trim for v1 (event deferment)

### User Story
- As a user, I want a focused v1 experience without event features so I can ship quickly and avoid half-built integrations.

### Definition of Done
- Event references are removed from v1 UI and copy. [SPRD-69]
- Events never appear in Release builds (data is stubbed/hidden). [SPRD-70]
- Event scaffolding remains in the codebase for v2 integration. [SPRD-70]

### [SPRD-69] Feature: Hide event surfaces in v1 UI
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

### [SPRD-70] Feature: Stub event data paths for v1
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

### [SPRD-58] Feature: Note repository
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

### [SPRD-61] Feature: Note creation and edit views
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

### [SPRD-34] Feature: Note migration UX
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

### [SPRD-18] Feature: Multiday aggregation
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

### [SPRD-32] Feature: Multiday spread UI
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

### [SPRD-20] Feature: Settings view (Mode + First Day of Week)
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

### [SPRD-17] Feature: Traditional mode mapping
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

### [SPRD-35] Feature: Traditional year view
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

### [SPRD-36] Feature: Traditional month view
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

### [SPRD-37] Feature: Traditional day view
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

### [SPRD-38] Feature: Traditional navigation flow
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



### [SPRD-53] Feature: Unit tests for traditional mode mapping
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

### [SPRD-39] Feature: Collection model + repository
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
- **Acceptance Criteria**:
  - Collections persist title + plain text content. (Spec: Collections)
- **Tests**:
  - Unit tests for collection CRUD.
- **Dependencies**: SPRD-38

### [SPRD-40] Feature: Collections list UI
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

### [SPRD-41] Feature: Collection detail editor
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



### [SPRD-54] Feature: Integration tests for repositories
- **Context**: Persistence should be validated end-to-end.
- **Description**: Add integration tests for SwiftData repositories using test containers.
- **Acceptance Criteria**:
  - CRUD works for spreads/entries/collections. (Spec: Persistence)
- **Tests**:
  - Integration tests across all repositories.
- **Dependencies**: SPRD-41, SPRD-57, SPRD-58

### [SPRD-55] Feature: Integration tests for collections
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
- CloudKit configuration and entitlements are documented.
- Offline-first QA checklist exists.

### [SPRD-42] Feature: CloudKit configuration for SwiftData
- **Context**: iCloud sync is required.
- **Description**: Configure CloudKit-backed SwiftData for production/development.
- **Implementation Details**:
  - Update `ModelContainerFactory` for CloudKit:
    - Production: CloudKit-enabled ModelConfiguration
    - Development: CloudKit-enabled with separate container
    - Preview/Testing: unchanged (in-memory)
  - CloudKit container name convention: `iCloud.com.yourapp.Bulleted`
- **Acceptance Criteria**:
  - Production/development uses CloudKit configuration. (Spec: Persistence)
- **Tests**:
  - Unit test for container configuration selection.
- **Dependencies**: SPRD-41

### [SPRD-43] Feature: CloudKit entitlements + environment mapping
- **Context**: iCloud requires entitlements and container names.
- **Description**: Add entitlements and document container naming conventions.
- **Implementation Details**:
  - Add iCloud capability to project
  - Enable CloudKit
  - Add container identifier
  - Document in CLAUDE.md or separate doc:
    - Container naming convention
    - Environment mapping
    - Entitlement requirements
- **Acceptance Criteria**:
  - Entitlements and container names documented in repo. (Spec: Persistence)
- **Tests**:
  - Manual checklist in documentation.
- **Dependencies**: SPRD-42

### [SPRD-44] Feature: Offline-first manual QA checklist
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

### [SPRD-56] Feature: Scope guard tests
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
SPRD-38 -> SPRD-39 -> SPRD-40 -> SPRD-41 -> SPRD-54 -> SPRD-55 -> SPRD-56
SPRD-41 -> SPRD-42 -> SPRD-43 -> SPRD-44 -> SPRD-45 -> SPRD-63 -> SPRD-46 -> SPRD-47 -> SPRD-48
SPRD-46 -> SPRD-65
SPRD-62 -> SPRD-63
```
