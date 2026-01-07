# Bulleted Implementation Plan (v1.0)

## Implementation Phases

```
Phase 1: Foundation (SPRD-1 to SPRD-7)
Phase 2: Data Models (SPRD-8 to SPRD-10)
Phase 3: Core Business Logic (SPRD-11 to SPRD-18, SPRD-57 to SPRD-59)
Phase 4: Navigation Shell (SPRD-19 to SPRD-20)
Phase 5: Entry Components (SPRD-21 to SPRD-24, SPRD-60, SPRD-61)
Phase 6: Conventional Mode UI (SPRD-25 to SPRD-34)
Phase 7: Traditional Mode UI (SPRD-35 to SPRD-38)
Phase 8: Collections (SPRD-39 to SPRD-41)
Phase 9: Sync & Persistence (SPRD-42 to SPRD-44)
Phase 10: Debug & Dev Tools (SPRD-45 to SPRD-48)
Phase 11: Testing (SPRD-49 to SPRD-56)
```

---

## Phase 1: Foundation

### [SPRD-1] Feature: New Xcode project bootstrap (iOS 26) - [x] Complete
- **Context**: Work starts from a brand-new SwiftUI project with only boilerplate code.
- **Description**: Create a new iOS 26 SwiftUI app, set up folder structure, minimal root view, and baseline build/test configuration.
- **Implementation Details**:
  - Create new Xcode project targeting iOS 26 with SwiftUI lifecycle
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
  - App targets iOS 26, builds, and launches with a placeholder root view. (Spec: Platform)
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

### [SPRD-4] Feature: SwiftData schema + migration plan scaffold
- **Context**: Data models must be versioned from day one.
- **Description**: Add versioned SwiftData schema and empty migration plan.
- **Implementation Details**:
  - `DataModelSchemaV1: VersionedSchema` with version `1.0.0`
  - Models: `DataModel.Spread`, `DataModel.Task`, `DataModel.Event`, `DataModel.Note`, `DataModel.Collection`
  - `DataModelMigrationPlan: SchemaMigrationPlan` with empty stages (ready for future migrations)
  - Schema used by `ModelContainerFactory`
- **Acceptance Criteria**:
  - Schema versioning exists and compiles with all models. (Spec: Persistence)
- **Tests**:
  - Unit test that ModelContainer can be created with schema + migration plan.
- **Dependencies**: SPRD-3

### [SPRD-5] Feature: SwiftData repositories (Task/Spread)
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

### [SPRD-6] Feature: Mock/test repositories + in-memory containers
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

### [SPRD-7] Feature: Date utilities + period normalization
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

---

## Phase 2: Data Models

### [SPRD-8] Feature: Spread model with multiday range
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

### [SPRD-9] Feature: Entry protocol + Task/Event/Note models
- **Context**: Entries are the parent concept; Task/Event/Note are distinct types for scalability.
- **Description**: Implement Entry protocol and three concrete @Model classes.
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
  - `EntryType` enum: `.task`, `.event`, `.note`
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
  - `DateRangeEntry` protocol (Event):
    ```swift
    protocol DateRangeEntry: Entry {
        var startDate: Date { get }
        var endDate: Date { get }
        func appearsOn(period: Spread.Period, date: Date, calendar: Calendar) -> Bool
    }
    ```
  - `DataModel.Task` @Model: id, title, createdDate, date, period, status, assignments: [TaskAssignment]
  - `DataModel.Event` @Model:
    - `EventTiming` enum: `.singleDay`, `.allDay`, `.timed`, `.multiDay`
    - Properties: startDate, endDate, startTime?, endTime?, timing
    - `appearsOn(period:date:calendar:)` - checks date range overlap with spread
  - `DataModel.Note` @Model: id, title, content, createdDate, date, period, status, assignments: [NoteAssignment]
- **Acceptance Criteria**:
  - All entry types persist and map to correct symbols. (Spec: Core Concepts)
  - Events have no assignments; visibility is computed. (Spec: Entries)
  - Notes can have extended content. (Spec: Entries)
- **Tests**:
  - Unit tests for Entry protocol conformance for all types
  - Unit tests for symbol mapping per type
  - Unit tests for Event `appearsOn()` with various spread periods
- **Dependencies**: SPRD-8

### [SPRD-10] Feature: TaskAssignment + NoteAssignment models
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
  - Events have NO assignment type - visibility is computed from date range
- **Acceptance Criteria**:
  - TaskAssignment supports per-spread status (open/complete/migrated). (Spec: Migration)
  - NoteAssignment supports per-spread status (active/migrated). (Spec: Entries)
- **Tests**:
  - Unit tests for assignment matching by period/date
  - Unit tests for assignment status updates
- **Dependencies**: SPRD-9

---

## Phase 3: Core Business Logic

### [SPRD-11] Feature: JournalManager base
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
  - Data loading on init: fetch all spreads/tasks/events/notes from repositories
  - Build `dataModel` dictionary organizing spreads by period/date
  - Increment `dataVersion` on any mutation for SwiftUI reactivity
- **Acceptance Criteria**:
  - JournalManager loads spreads and entries via repositories. (Spec: Project Summary)
- **Tests**:
  - Unit test initializes JournalManager with mock repositories.
- **Dependencies**: SPRD-10

### [SPRD-12] Feature: Spread creation policy
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

### [SPRD-13] Feature: Conventional assignment engine
- **Context**: Entries must be assigned to created spreads or Inbox.
- **Description**: Assign tasks/notes to year/month/day; events have computed visibility.
- **Implementation Details**:
  - `ConventionalSpreadService`:
    - `getAvailableAssignment(for entry:, dataModel:) -> AssignmentResult?`
    - Search periods from finest to coarsest (day → month → year)
    - Skip periods that can't have tasks assigned (multiday)
    - Match entry's preferred period/date to existing spread
    - Return first available spread or nil (→ Inbox)
  - Events: no assignment needed - `eventsForSpread()` computes visibility
  - Multiday: aggregates entries whose dates fall within range (no direct assignment)
- **Acceptance Criteria**:
  - Tasks/notes assign to year/month/day only; multiday aggregates. (Spec: Entries)
  - Events appear on all applicable spreads. (Spec: Entries)
- **Tests**:
  - Unit tests for assignment to nearest created parent spread.
  - Event visibility across year/month/day and multiday ranges.
- **Dependencies**: SPRD-11

### [SPRD-14] Feature: Inbox data model + auto-resolve
- **Context**: Unassigned entries must be visible and auto-resolve.
- **Description**: Implement global Inbox for unassigned entries with auto-resolve on spread creation.
- **Implementation Details**:
  - Inbox is computed, not persisted:
    - Query tasks/notes where `assignments.isEmpty` or no matching spread exists
    - Exclude events (computed visibility)
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
  - Events and cancelled tasks excluded. (Spec: Task Status)
- **Tests**:
  - Unit tests for Inbox population query
  - Unit tests for auto-resolve when spread created
  - Unit tests confirming events excluded
  - Unit tests confirming cancelled tasks excluded
- **Dependencies**: SPRD-13

### [SPRD-15] Feature: Migration logic (manual only)
- **Context**: Migration must be user-triggered and type-specific.
- **Description**: Implement manual migration for tasks; allow explicit notes; block events.
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
  - Event migration: blocked (throw error or no-op)
  - **Spread deletion cascade**:
    - Query all entries (tasks/notes) with assignments to deleted spread
    - For each: reassign to parent spread OR Inbox if no parent
    - Preserve full assignment history (don't delete assignments)
    - Completed tasks: reassign like open tasks (never delete entries)
- **Acceptance Criteria**:
  - Migration only occurs when user triggers it. (Spec: Entries; Non-Goals)
  - Events cannot migrate; notes migrate only explicitly. (Spec: Entries)
  - Spread deletion never deletes entries. (Spec: Spreads)
- **Tests**:
  - Unit tests for migration chain and assignment updates.
  - Unit tests for spread deletion cascade behavior.
- **Dependencies**: SPRD-14

### [SPRD-16] Feature: Cancelled task behavior
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
- **Dependencies**: SPRD-16

### [SPRD-18] Feature: Multiday aggregation
- **Context**: Multiday spreads aggregate entries in range.
- **Description**: Aggregate entries by date range for multiday spreads (no direct assignment).
- **Implementation Details**:
  - `JournalManager.entriesForMultidaySpread(_:) -> [any Entry]`:
    - Query tasks/notes whose preferred date falls within multiday's startDate...endDate
    - Include events whose date range overlaps multiday's range
    - No assignment status for multiday - show aggregated view
  - Multiday spread view uses aggregated data, not assignments
- **Acceptance Criteria**:
  - Multiday spreads show aggregated entries within range. (Spec: Spreads)
- **Tests**:
  - Unit tests for range aggregation across month/year boundaries.
- **Dependencies**: SPRD-17

### [SPRD-57] Feature: Event repository
- **Context**: Events need separate CRUD operations.
- **Description**: Implement EventRepository protocol and SwiftData implementation.
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
  - Date range query uses FetchDescriptor with predicate for efficient filtering
  - Mock/test implementations for previews and tests
- **Acceptance Criteria**:
  - CRUD for events works via repository. (Spec: Persistence)
  - Date range query efficiently filters events. (Spec: Events)
- **Tests**:
  - Repository CRUD integration tests
  - Date range query tests
- **Dependencies**: SPRD-9, SPRD-3

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

### [SPRD-59] Feature: Event visibility logic in JournalManager
- **Context**: Events appear on spreads based on date overlap, not assignments.
- **Description**: Add event queries to JournalManager for computed visibility.
- **Implementation Details**:
  - `JournalManager.eventsForSpread(period:date:) -> [DataModel.Event]`:
    - Query all events from repository
    - Filter using `event.appearsOn(period:date:calendar:)`
  - `JournalManager.entriesForSpread(period:date:) -> [any Entry]`:
    - Combines tasks, events, notes for unified view
    - Tasks/notes via assignments, events via computed visibility
  - `SpreadDataModel` updated to include `events: [DataModel.Event]?`
  - Event visibility computed on data model build (not stored)
- **Acceptance Criteria**:
  - Events appear on all applicable spreads. (Spec: Entries)
  - Multiday events span multiple day spreads. (Spec: Events)
- **Tests**:
  - Unit tests for event visibility across year/month/day/multiday
  - Unit tests for multiday event spanning multiple spreads
- **Dependencies**: SPRD-57, SPRD-11

---

## Phase 4: Navigation Shell

### [SPRD-19] Feature: Root navigation shell
- **Context**: Collections must be outside spread navigation; Inbox in header.
- **Description**: Build root navigation with entry points for Spreads, Collections, Settings, and Inbox.
- **Implementation Details**:
  - `MainTabView` or similar root container
  - Navigation header with:
    - Inbox badge/button (count, opens sheet)
    - Settings gear icon (opens sheet)
    - Collections button (opens sheet or navigates)
  - Main content area switches based on BuJo mode:
    - Conventional: spread tab bar + content
    - Traditional: calendar navigation
  - Sheet presentations for Inbox, Settings, Collections
- **Acceptance Criteria**:
  - Collections are accessible outside spread navigation. (Spec: Navigation and UI)
  - Inbox badge in header. (Spec: Inbox)
- **Tests**:
  - UI-free integration test ensuring root view composes navigation containers.
- **Dependencies**: SPRD-18

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
- **Dependencies**: SPRD-19

---

## Phase 5: Entry Components

### [SPRD-21] Feature: Entry symbol component
- **Context**: Task/event/note symbols must be consistent across UI.
- **Description**: Create a reusable symbol/status component for entries.
- **Implementation Details**:
  - `StatusIcon` view:
    - Task: solid circle (●) - "circle.fill"
    - Event: empty circle (○) - "circle"
    - Note: dash (—) - "minus"
  - Task status overlays:
    - Open: base circle
    - Complete: xmark overlay
    - Migrated: arrow.right overlay
    - Cancelled: slash overlay (hidden in v1)
  - Configurable size and color
- **Acceptance Criteria**:
  - Symbols render as solid/empty/dash with task status indicators. (Spec: Core Concepts)
- **Tests**:
  - Snapshot-free unit tests verifying symbol selection logic.
- **Dependencies**: SPRD-20

### [SPRD-22] Feature: Entry row component + swipe actions
- **Context**: Lists need consistent entry rendering and actions.
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
    - Event: Edit, Delete only (no migrate)
  - Action callbacks via closures or environment
- **Acceptance Criteria**:
  - Task rows allow complete/migrate actions; notes only explicit migrate; events have no migrate. (Spec: Entries)
- **Tests**:
  - Unit tests for action availability per entry type/status.
- **Dependencies**: SPRD-21

### [SPRD-23] Feature: Task creation sheet
- **Context**: Task creation must enforce date/period rules.
- **Description**: Build task creation UI with validation (no past dates).
- **Implementation Details**:
  - `TaskCreationSheet` presented as sheet (medium detent)
  - Form fields:
    - Title (required, auto-focus)
    - Period picker (year/month/day)
    - Date picker (constrained to present/future)
  - Validation:
    - Title required
    - Date >= today (normalized for period)
  - On save: create Task via JournalManager, add initial assignment if spread exists
- **Acceptance Criteria**:
  - Past-dated tasks are blocked by UI validation. (Spec: Entries)
- **Tests**:
  - Unit tests for validation logic and default selections.
- **Dependencies**: SPRD-22

### [SPRD-60] Feature: Event creation sheet
- **Context**: Events have different fields than tasks (timing, date range).
- **Description**: Build event creation UI with timing mode selection.
- **Implementation Details**:
  - `EventCreationSheet` presented as sheet
  - Form fields:
    - Title (required)
    - Timing mode picker: Single Day, All Day, Timed, Multi-Day
    - Date picker (single date for Single/All/Timed)
    - Date range pickers (start/end for Multi-Day)
    - Time pickers (start/end for Timed mode only)
  - Validation:
    - Title required
    - End date >= start date for Multi-Day
    - End time > start time for Timed
    - No past dates in v1
  - On save: create Event via JournalManager
- **Acceptance Criteria**:
  - Event creation supports all four timing modes. (Spec: Events)
  - Past-dated events blocked by validation. (Spec: Entries)
- **Tests**:
  - Unit tests for validation logic
  - Unit tests for default selections
- **Dependencies**: SPRD-57, SPRD-11

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
- **Dependencies**: SPRD-58, SPRD-21

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
- **Dependencies**: SPRD-22

---

## Phase 6: Conventional Mode UI

### [SPRD-25] Feature: Conventional spread tab bar
- **Context**: Conventional mode uses tab-based spread navigation.
- **Description**: Implement spread tab bar listing created spreads and create action.
- **Implementation Details**:
  - `HierarchicalSpreadTabBar`:
    - Lists created spreads organized by hierarchy (year → month → day)
    - Selected tab highlighted, inactive tabs secondary style
    - Progressive disclosure: expand year → show months
    - "+" button for spread creation
    - Creatable spread suggestions (ghost tabs)
  - Tab selection updates content view
  - Design constants in `FolderTabDesign`
- **Acceptance Criteria**:
  - Tab bar lists created spreads only. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for spread list ordering and selection.
- **Dependencies**: SPRD-24

### [SPRD-26] Feature: Spread creation sheet UI
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
- **Dependencies**: SPRD-25

### [SPRD-27] Feature: Spread content header
- **Context**: Spread views need consistent metadata display.
- **Description**: Add header showing spread title and counts.
- **Implementation Details**:
  - `SpreadHeaderView`:
    - Period-appropriate title (e.g., "2026", "January 2026", "January 5, 2026")
    - Entry counts by type (tasks, events, notes)
    - Multiday: show date range in header
- **Acceptance Criteria**:
  - Header reflects spread period/date and entry counts. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for header formatting by period.
- **Dependencies**: SPRD-26

### [SPRD-28] Feature: Conventional entry list + grouping
- **Context**: Year/month/day grouping is required.
- **Description**: Implement grouping rules for entries in spread views.
- **Implementation Details**:
  - `TaskListView` with grouping:
    - Year spread: group by month
    - Month spread: group by day
    - Day spread: flat list
    - Multiday spread: group by day within range
  - Includes events in appropriate sections
  - Uses `EntryRowView` for consistent rendering
- **Acceptance Criteria**:
  - Grouping matches period rules and includes events. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for grouping logic.
- **Dependencies**: SPRD-27

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
- **Dependencies**: SPRD-28

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
- **Dependencies**: SPRD-29

### [SPRD-31] Feature: Inbox view
- **Context**: Users access Inbox via header badge.
- **Description**: Build Inbox UI with badge indicator and sheet presentation.
- **Implementation Details**:
  - `InboxBadgeView`:
    - Small badge showing count in navigation header
    - Hidden when count is 0
    - Taps present InboxSheetView
  - `InboxSheetView`:
    - List of unassigned tasks/notes (no events)
    - Grouped by entry type (tasks first, then notes)
    - Each row: entry symbol, title, preferred date
    - Swipe action: assign to spread (opens spread picker)
  - Assign action: user picks spread, creates initial assignment
- **Acceptance Criteria**:
  - Badge shows in header with count. (Spec: Navigation and UI)
  - Inbox hides cancelled tasks and events. (Spec: Modes)
  - Tapping opens sheet with unassigned entries. (Spec: Navigation and UI)
- **Tests**:
  - Unit tests for badge visibility based on count
  - Unit tests for entry grouping in sheet
- **Dependencies**: SPRD-14, SPRD-21

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
- **Dependencies**: SPRD-31

### [SPRD-33] Feature: Event visibility in spread UI
- **Context**: Events must appear on all applicable spreads based on date overlap.
- **Description**: Render events in spread views for year/month/day/multiday.
- **Implementation Details**:
  - Events rendered with empty circle symbol
  - Events grouped with other entries or in separate section
  - Event row shows: symbol, title, timing indicator (all-day, time range, date range)
  - No swipe actions for migrate (events don't migrate)
  - Swipe actions: edit, delete only
  - Tapping opens `EventDetailView`
  - Multiday events: show on each day spread they span
- **Acceptance Criteria**:
  - Events visible on all applicable spread views. (Spec: Entries)
  - Events not migratable from UI. (Spec: Entries)
- **Tests**:
  - Unit tests for event inclusion across spread types
- **Dependencies**: SPRD-59, SPRD-21

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
- **Dependencies**: SPRD-33

---

## Phase 7: Traditional Mode UI

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
- **Dependencies**: SPRD-34

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
- **Dependencies**: SPRD-35

### [SPRD-37] Feature: Traditional day view
- **Context**: Day view shows preferred assignments and events.
- **Description**: Render entries for a single day in traditional mode.
- **Implementation Details**:
  - `TraditionalDayView`:
    - Shows entries with preferred date matching this day
    - Includes events overlapping this day
    - No migration history visible
    - Uses same `EntryRowView` components
- **Acceptance Criteria**:
  - Day view shows preferred assignments plus events in range. (Spec: Modes)
- **Tests**:
  - Unit tests for day view entry filtering.
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
- **Dependencies**: SPRD-37

---

## Phase 8: Collections

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
- **Dependencies**: SPRD-40

---

## Phase 9: Sync & Persistence

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

---

## Phase 10: Debug & Dev Tools

### [SPRD-45] Feature: Debug menu (Debug builds only)
- **Context**: Debug tooling is required for faster iteration.
- **Description**: Add debug menu to inspect environment, spreads, entries, inbox, and collections.
- **Implementation Details**:
  - `DebugMenuView` gated by `#if DEBUG`
  - Shows:
    - Current `AppEnvironment` and all configuration properties (from SPRD-2)
    - Raw data for: spreads, tasks, events, notes, inbox, collections
  - Accessible from Settings (Debug builds only)
  - Expands on the simple `DebugEnvironmentOverlay` from SPRD-2 with full data inspection
- **Acceptance Criteria**:
  - Debug menu available only in Debug builds. (Spec: Development tooling)
  - Debug menu shows current AppEnvironment and configuration. (Spec: Development tooling)
- **Tests**:
  - Unit test ensures debug menu is excluded in Release builds.
- **Dependencies**: SPRD-44

### [SPRD-46] Feature: Debug quick actions
- **Context**: Developers need to create test data quickly.
- **Description**: Provide actions to create spreads/entries/multiday/inbox scenarios.
- **Implementation Details**:
  - Debug actions:
    - "Create Sample Spreads" - year, month, day for current date
    - "Create Sample Tasks" - tasks with various statuses
    - "Create Sample Events" - all timing modes
    - "Create Sample Notes" - active and migrated
    - "Create Inbox Scenario" - entries without matching spreads
    - "Clear All Data" - delete everything
- **Acceptance Criteria**:
  - Debug actions cover tasks/events/notes and multiday spreads. (Spec: Testing)
- **Tests**:
  - Unit tests for action data creation.
- **Dependencies**: SPRD-45

### [SPRD-47] Feature: Test data builders
- **Context**: Tests need consistent fixtures for entries and spreads.
- **Description**: Create test data builders for entries/spreads/multiday ranges.
- **Implementation Details**:
  - `TestData` struct with static methods:
    - `testYear`, `testMonth`, `testDay` - fixed test dates
    - `spreads(calendar:today:)` - hierarchical spread set
    - `tasks(calendar:today:)` - comprehensive task scenarios
    - `events(calendar:today:)` - all event timing modes
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

---

## Phase 11: Testing

### [SPRD-49] Feature: Unit tests for date + multiday presets
- **Context**: Date logic is error-prone.
- **Description**: Add unit tests for normalization, presets, and first weekday override.
- **Acceptance Criteria**:
  - Tests cover locale week start, overrides, and boundaries. (Spec: Edge Cases)
- **Tests**:
  - Unit tests across month/year boundaries.
- **Dependencies**: SPRD-48

### [SPRD-50] Feature: Unit tests for spread creation rules
- **Context**: Creation rules must be enforced consistently.
- **Description**: Add unit tests for present/future rules and multiday start handling.
- **Acceptance Criteria**:
  - Tests confirm past spreads are blocked except multiday within current week. (Spec: Spreads)
- **Tests**:
  - Unit tests for validation edge cases.
- **Dependencies**: SPRD-49

### [SPRD-51] Feature: Unit tests for assignment + Inbox
- **Context**: Assignment and Inbox are core behaviors.
- **Description**: Add tests for assignment engine and Inbox auto-resolve.
- **Acceptance Criteria**:
  - Tests cover nearest parent assignment and Inbox auto-resolve. (Spec: Modes)
- **Tests**:
  - Unit tests for events showing on all spreads.
- **Dependencies**: SPRD-50

### [SPRD-52] Feature: Unit tests for migration rules
- **Context**: Migration behavior differs by entry type and status.
- **Description**: Add tests for manual migration, event blocking, note explicit migration, and cancelled exclusion.
- **Acceptance Criteria**:
  - Tests enforce manual-only migration and exclusion rules. (Spec: Entries; Task Status)
- **Tests**:
  - Unit tests for duplicate assignment prevention.
- **Dependencies**: SPRD-51

### [SPRD-53] Feature: Unit tests for traditional mode mapping
- **Context**: Virtual spreads must be correct and stable.
- **Description**: Add tests for traditional mapping and parent fallback.
- **Acceptance Criteria**:
  - Tests confirm no mutation of created spread data. (Spec: Modes)
- **Tests**:
  - Unit tests for fallback to parent or Inbox.
- **Dependencies**: SPRD-52

### [SPRD-54] Feature: Integration tests for repositories
- **Context**: Persistence should be validated end-to-end.
- **Description**: Add integration tests for SwiftData repositories using test containers.
- **Acceptance Criteria**:
  - CRUD works for spreads/entries/collections. (Spec: Persistence)
- **Tests**:
  - Integration tests across all repositories.
- **Dependencies**: SPRD-53

### [SPRD-55] Feature: Integration tests for collections
- **Context**: Collections are new model + UI flow.
- **Description**: Add integration tests for collection CRUD and persistence.
- **Acceptance Criteria**:
  - Collection edits persist across reloads. (Spec: Collections)
- **Tests**:
  - Integration test with in-memory container.
- **Dependencies**: SPRD-54

### [SPRD-56] Feature: Scope guard tests
- **Context**: Non-goals must not regress into v1.
- **Description**: Add tests that enforce no week assignment, no automated migration, and no past entry creation.
- **Acceptance Criteria**:
  - Tests fail if week periods or automated migration appear. (Spec: Non-Goals)
- **Tests**:
  - Unit tests for no-past-date creation and no week period exposure.
- **Dependencies**: SPRD-55

---

## Dependency Graph (Simplified)

```
SPRD-1 → SPRD-2 → SPRD-3 → SPRD-4 → SPRD-5 → SPRD-6 → SPRD-7
                                              ↓
                          SPRD-8 → SPRD-9 → SPRD-10
                                              ↓
         SPRD-57 ←─────────────────┬──────────┴───────────┬─────────────→ SPRD-58
         SPRD-59 ←─────────────────┤                      │
                                   ↓                      ↓
                          SPRD-11 → SPRD-12 → SPRD-13 → SPRD-14 → SPRD-15 → SPRD-16 → SPRD-17 → SPRD-18
                                                                                                  ↓
                                                                                           SPRD-19 → SPRD-20
                                                                                                      ↓
                                                                                           SPRD-21 → SPRD-22
                                                                                              ↓         ↓
                                                                                     SPRD-23  SPRD-60  SPRD-61  SPRD-24
                                                                                                               ↓
         SPRD-25 → SPRD-26 → SPRD-27 → SPRD-28 → SPRD-29 → SPRD-30 → SPRD-31 → SPRD-32 → SPRD-33 → SPRD-34
                                                                                                      ↓
                                                                      SPRD-35 → SPRD-36 → SPRD-37 → SPRD-38
                                                                                                      ↓
                                                                               SPRD-39 → SPRD-40 → SPRD-41
                                                                                                      ↓
                                                                               SPRD-42 → SPRD-43 → SPRD-44
                                                                                                      ↓
                                                                      SPRD-45 → SPRD-46 → SPRD-47 → SPRD-48
                                                                                                      ↓
                                                           SPRD-49 → SPRD-50 → SPRD-51 → SPRD-52 → SPRD-53 → SPRD-54 → SPRD-55 → SPRD-56
```
