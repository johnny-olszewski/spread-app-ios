import Foundation
import OSLog
import Observation

/// Central coordinator for journal data and operations.
///
/// JournalManager owns the in-memory data model, handles data loading from
/// repositories, and provides access to spreads and entries. It coordinates
/// between the UI layer and persistence layer.
///
/// Use `make` factory method to create instances with mock repositories.
@Observable
@MainActor
final class JournalManager {

    // MARK: - Properties

    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "JournalManager")

    /// The calendar used for date calculations.
    let calendar: Calendar

    /// The current date for determining present/future logic.
    let today: Date

    /// Repository for task persistence.
    let taskRepository: any TaskRepository

    /// Repository for spread persistence.
    let spreadRepository: any SpreadRepository

    /// Repository for event persistence.
    let eventRepository: any EventRepository

    /// Repository for note persistence.
    let noteRepository: any NoteRepository

    /// Repository for collection persistence.
    ///
    /// Optional because collections are not yet managed by JournalManager.
    /// Used by `clearAllDataFromRepositories` to wipe collections on sign-out.
    let collectionRepository: (any CollectionRepository)?

    /// The current BuJo mode (conventional or traditional).
    var bujoMode: BujoMode

    /// The user's first day of week preference.
    var firstWeekday: FirstWeekday

    /// Policy for validating spread creation.
    let creationPolicy: SpreadCreationPolicy

    /// Builds conventional-mode spread data models from explicit spreads and entries.
    let conventionalDataModelBuilder: any JournalDataModelBuilder

    /// Builds traditional-mode virtual spread data models from entry preference data.
    let traditionalDataModelBuilder: any JournalDataModelBuilder

    /// Resolves Inbox membership from the current spreads and entries.
    let inboxResolver: any InboxResolver

    /// Plans migration sources, destinations, and source-spread resolution.
    let migrationPlanner: any MigrationPlanner

    /// Evaluates overdue open-task review items.
    let overdueEvaluator: any OverdueEvaluator

    /// Reconciles task preferred assignments against the current created spreads.
    let taskAssignmentReconciler: any TaskAssignmentReconciler

    /// Reconciles note preferred assignments against the current created spreads.
    let noteAssignmentReconciler: any NoteAssignmentReconciler

    /// Coordinates task mutation workflows that combine assignment rules and persistence.
    let taskMutationCoordinator: any TaskMutationCoordinator

    /// Coordinates note mutation workflows that combine assignment rules and persistence.
    let noteMutationCoordinator: any NoteMutationCoordinator

    /// Plans and persists spread deletion reassignment workflows.
    let spreadDeletionCoordinator: any SpreadDeletionCoordinator

    /// Coordinates explicit task migration workflows and batch migration persistence.
    let taskMigrationCoordinator: any TaskMigrationCoordinator

    /// Coordinates explicit note migration workflows.
    let noteMigrationCoordinator: any NoteMigrationCoordinator

    /// Version counter that increments on data mutations.
    ///
    /// SwiftUI views can observe this to trigger refreshes when data changes.
    private(set) var dataVersion: Int = 0

    /// All spreads loaded from the repository.
    private(set) var spreads: [DataModel.Spread] = []

    /// All tasks loaded from the repository.
    private(set) var tasks: [DataModel.Task] = []

    /// All events loaded from the repository.
    private(set) var events: [DataModel.Event] = []

    /// All notes loaded from the repository.
    private(set) var notes: [DataModel.Note] = []

    /// The journal data model organized by period and date.
    ///
    /// Provides nested dictionary access: `dataModel[.month][normalizedDate]`
    /// returns the `SpreadDataModel` for that month spread.
    private(set) var dataModel: JournalDataModel = [:]

    // MARK: - Inbox

    /// Entries that have no matching spread assignment.
    ///
    /// Includes tasks and notes that either have no assignments or have no
    /// assignment matching any existing spread. Events are excluded (they use
    /// computed visibility). Cancelled tasks are excluded.
    var inboxEntries: [any Entry] {
        inboxResolver.inboxEntries(tasks: tasks, notes: notes, spreads: spreads)
    }

    /// The number of entries in the Inbox.
    ///
    /// Used for badge display. Returns 0 when no unassigned entries exist.
    var inboxCount: Int {
        inboxEntries.count
    }

    /// Tasks eligible to move into created spreads in conventional mode.
    ///
    /// The destination must be the most granular valid existing spread that:
    /// - matches the task's desired date hierarchy
    /// - is more granular than the current source
    /// - does not exceed the task's desired assignment period
    func migrationCandidates(
        to destination: DataModel.Spread
    ) -> [MigrationCandidate] {
        migrationPlanner.migrationCandidates(
            tasks: tasks,
            spreads: spreads,
            bujoMode: bujoMode,
            to: destination
        )
    }

    /// Returns the smallest valid existing destination spread for a task on a specific source spread.
    ///
    /// Used by the source-side row affordance to determine whether an inline migration action
    /// should be shown on the current spread.
    func migrationDestination(
        for task: DataModel.Task,
        on source: DataModel.Spread
    ) -> DataModel.Spread? {
        migrationPlanner.migrationDestination(
            for: task,
            on: source,
            spreads: spreads,
            bujoMode: bujoMode
        )
    }

    /// Returns migration candidates that come only from the destination's parent hierarchy.
    ///
    /// This powers the destination-side inline migration section. Inbox-origin tasks are
    /// intentionally excluded from this UI.
    func parentHierarchyMigrationCandidates(
        to destination: DataModel.Spread
    ) -> [MigrationCandidate] {
        migrationPlanner.parentHierarchyMigrationCandidates(
            tasks: tasks,
            spreads: spreads,
            bujoMode: bujoMode,
            to: destination
        )
    }

    /// Open tasks that are overdue anywhere in the journal.
    var overdueTaskItems: [OverdueTaskItem] {
        overdueEvaluator.overdueTaskItems(tasks: tasks, spreads: spreads)
    }

    /// The global overdue count used by the toolbar review button.
    var overdueTaskCount: Int {
        overdueTaskItems.count
    }

    // MARK: - Initialization

    /// Creates a new JournalManager.
    ///
    /// Loads data from repositories asynchronously. Use `make` for tests.
    ///
    /// - Parameters:
    ///   - calendar: The calendar for date calculations.
    ///   - today: The current date.
    ///   - taskRepository: Repository for tasks.
    ///   - spreadRepository: Repository for spreads.
    ///   - eventRepository: Repository for events.
    ///   - noteRepository: Repository for notes.
    ///   - collectionRepository: Optional repository for collections (used for sign-out wipe).
    ///   - bujoMode: The initial BuJo mode.
    ///   - firstWeekday: The user's first day of week preference.
    ///   - creationPolicy: Policy for validating spread creation.
    init(
        calendar: Calendar,
        today: Date,
        taskRepository: any TaskRepository,
        spreadRepository: any SpreadRepository,
        eventRepository: any EventRepository,
        noteRepository: any NoteRepository,
        collectionRepository: (any CollectionRepository)? = nil,
        bujoMode: BujoMode,
        firstWeekday: FirstWeekday = .systemDefault,
        creationPolicy: SpreadCreationPolicy,
        conventionalDataModelBuilder: (any JournalDataModelBuilder)? = nil,
        traditionalDataModelBuilder: (any JournalDataModelBuilder)? = nil,
        inboxResolver: (any InboxResolver)? = nil,
        migrationPlanner: (any MigrationPlanner)? = nil,
        overdueEvaluator: (any OverdueEvaluator)? = nil,
        taskAssignmentReconciler: (any TaskAssignmentReconciler)? = nil,
        noteAssignmentReconciler: (any NoteAssignmentReconciler)? = nil,
        taskMutationCoordinator: (any TaskMutationCoordinator)? = nil,
        noteMutationCoordinator: (any NoteMutationCoordinator)? = nil,
        spreadDeletionPlanner: (any SpreadDeletionPlanner)? = nil,
        spreadDeletionCoordinator: (any SpreadDeletionCoordinator)? = nil,
        taskMigrationCoordinator: (any TaskMigrationCoordinator)? = nil,
        noteMigrationCoordinator: (any NoteMigrationCoordinator)? = nil
    ) {
        self.calendar = calendar
        self.today = today
        self.taskRepository = taskRepository
        self.spreadRepository = spreadRepository
        self.eventRepository = eventRepository
        self.noteRepository = noteRepository
        self.collectionRepository = collectionRepository
        self.bujoMode = bujoMode
        self.firstWeekday = firstWeekday
        self.creationPolicy = creationPolicy
        self.conventionalDataModelBuilder = conventionalDataModelBuilder ?? ConventionalJournalDataModelBuilder(
            calendar: calendar
        )
        self.traditionalDataModelBuilder = traditionalDataModelBuilder ?? TraditionalJournalDataModelBuilder(
            calendar: calendar
        )
        let resolvedMigrationPlanner = migrationPlanner ?? StandardMigrationPlanner(calendar: calendar)
        let resolvedTaskAssignmentReconciler = taskAssignmentReconciler ?? StandardTaskAssignmentReconciler(
            calendar: calendar
        )
        let resolvedNoteAssignmentReconciler = noteAssignmentReconciler ?? StandardNoteAssignmentReconciler(
            calendar: calendar
        )
        let resolvedSpreadDeletionPlanner = spreadDeletionPlanner ?? StandardSpreadDeletionPlanner(calendar: calendar)
        self.inboxResolver = inboxResolver ?? StandardInboxResolver(calendar: calendar)
        self.migrationPlanner = resolvedMigrationPlanner
        self.overdueEvaluator = overdueEvaluator ?? StandardOverdueEvaluator(
            calendar: calendar,
            today: today,
            migrationPlanner: resolvedMigrationPlanner
        )
        self.taskAssignmentReconciler = resolvedTaskAssignmentReconciler
        self.noteAssignmentReconciler = resolvedNoteAssignmentReconciler
        self.taskMutationCoordinator = taskMutationCoordinator ?? StandardTaskMutationCoordinator(
            taskRepository: taskRepository,
            taskAssignmentReconciler: resolvedTaskAssignmentReconciler,
            logger: LoggerAdapter(info: { message in
                Self.logger.info("\(message, privacy: .public)")
            }),
            calendar: calendar
        )
        self.noteMutationCoordinator = noteMutationCoordinator ?? StandardNoteMutationCoordinator(
            noteRepository: noteRepository,
            noteAssignmentReconciler: resolvedNoteAssignmentReconciler,
            logger: LoggerAdapter(info: { message in
                Self.logger.info("\(message, privacy: .public)")
            }),
            calendar: calendar
        )
        self.spreadDeletionCoordinator = spreadDeletionCoordinator ?? StandardSpreadDeletionCoordinator(
            planner: resolvedSpreadDeletionPlanner,
            spreadRepository: spreadRepository,
            taskRepository: taskRepository,
            noteRepository: noteRepository,
            logger: LoggerAdapter(info: { message in
                Self.logger.info("\(message, privacy: .public)")
            })
        )
        self.taskMigrationCoordinator = taskMigrationCoordinator ?? StandardTaskMigrationCoordinator(
            taskRepository: taskRepository,
            logger: LoggerAdapter(info: { message in
                Self.logger.info("\(message, privacy: .public)")
            })
        )
        self.noteMigrationCoordinator = noteMigrationCoordinator ?? StandardNoteMigrationCoordinator(
            noteRepository: noteRepository,
            logger: LoggerAdapter(info: { message in
                Self.logger.info("\(message, privacy: .public)")
            })
        )
    }

    // MARK: - Factory Methods

    /// Creates a JournalManager for testing with mock repositories.
    ///
    /// - Parameters:
    ///   - calendar: The calendar for date calculations (defaults to gregorian UTC).
    ///   - today: The current date (defaults to now).
    ///   - taskRepository: Repository for tasks (defaults to empty in-memory).
    ///   - spreadRepository: Repository for spreads (defaults to empty in-memory).
    ///   - eventRepository: Repository for events (defaults to empty in-memory).
    ///   - noteRepository: Repository for notes (defaults to empty in-memory).
    ///   - bujoMode: The initial BuJo mode (defaults to conventional).
    ///   - firstWeekday: The user's first day of week preference (defaults to system default).
    ///   - creationPolicy: Policy for spread creation (defaults to standard policy).
    /// - Returns: A configured JournalManager with data loaded.
    static func make(
        calendar: Calendar? = nil,
        today: Date? = nil,
        taskRepository: (any TaskRepository)? = nil,
        spreadRepository: (any SpreadRepository)? = nil,
        eventRepository: (any EventRepository)? = nil,
        noteRepository: (any NoteRepository)? = nil,
        collectionRepository: (any CollectionRepository)? = nil,
        bujoMode: BujoMode = .conventional,
        firstWeekday: FirstWeekday = .systemDefault,
        creationPolicy: SpreadCreationPolicy? = nil
    ) async throws -> JournalManager {
        var testCalendar: Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .init(identifier: "UTC")!
            return cal
        }

        let resolvedToday = today ?? .now
        let defaultPolicy = StandardCreationPolicy(today: resolvedToday, firstWeekday: firstWeekday)

        let manager = JournalManager(
            calendar: calendar ?? testCalendar,
            today: resolvedToday,
            taskRepository: taskRepository ?? InMemoryTaskRepository(),
            spreadRepository: spreadRepository ?? InMemorySpreadRepository(),
            eventRepository: eventRepository ?? InMemoryEventRepository(),
            noteRepository: noteRepository ?? InMemoryNoteRepository(),
            collectionRepository: collectionRepository,
            bujoMode: bujoMode,
            firstWeekday: firstWeekday,
            creationPolicy: creationPolicy ?? defaultPolicy
        )
        await manager.loadData()
        return manager
    }

    // MARK: - Data Loading

    /// Loads all data from repositories.
    ///
    /// Called during initialization and can be called to refresh data.
    private func loadData() async {
        spreads = await spreadRepository.getSpreads()
        tasks = await taskRepository.getTasks()
        events = await eventRepository.getEvents()
        notes = await noteRepository.getNotes()

        buildDataModel()
    }

    /// Reloads data from repositories.
    ///
    /// Increments `dataVersion` to trigger UI updates.
    func reload() async {
        await loadData()
        dataVersion += 1
    }

    /// Returns true if any local data exists in repositories.
    func hasLocalData() async -> Bool {
        if !(await spreadRepository.getSpreads()).isEmpty { return true }
        if !(await taskRepository.getTasks()).isEmpty { return true }
        if !(await eventRepository.getEvents()).isEmpty { return true }
        if !(await noteRepository.getNotes()).isEmpty { return true }
        return false
    }

    /// Clears all local data from repositories and refreshes in-memory state.
    ///
    /// Used on sign-out to wipe local content.
    func clearLocalData() async {
        do {
            try await clearAllDataFromRepositories()
        } catch {
            // Best-effort wipe; keep going to refresh UI state.
        }
        await reload()
    }

    // MARK: - Data Model Building

    /// Builds the journal data model from loaded data.
    ///
    /// In conventional mode, organizes created spreads by period and date,
    /// then associates entries via assignments.
    /// In traditional mode, generates virtual spreads from entries' preferred dates.
    private func buildDataModel() {
        dataModel = activeDataModelBuilder.buildDataModel(
            spreads: spreads,
            tasks: tasks,
            notes: notes,
            events: events
        )
    }

    private var activeDataModelBuilder: any JournalDataModelBuilder {
        switch bujoMode {
        case .conventional:
            conventionalDataModelBuilder
        case .traditional:
            traditionalDataModelBuilder
        }
    }

    private func refreshDataModel(for scope: JournalMutationScope) {
        switch scope {
        case .structural:
            buildDataModel()
        case .spreadKeys(let keys):
            for key in keys {
                dataModel[key: key] = activeDataModelBuilder.buildSpreadDataModel(
                    for: key,
                    spreads: spreads,
                    tasks: tasks,
                    notes: notes,
                    events: events
                )
            }
        }
    }

    private func scopeForTaskChange(
        previousKeys: Set<SpreadDataModelKey>,
        task: DataModel.Task
    ) -> JournalMutationScope {
        let nextKeys = activeDataModelBuilder.spreadKeys(for: task, spreads: spreads)
        return .spreadKeys(previousKeys.union(nextKeys))
    }

    private func scopeForNoteChange(
        previousKeys: Set<SpreadDataModelKey>,
        note: DataModel.Note
    ) -> JournalMutationScope {
        let nextKeys = activeDataModelBuilder.spreadKeys(for: note, spreads: spreads)
        return .spreadKeys(previousKeys.union(nextKeys))
    }

    /// Clears all data from repositories (without updating in-memory state).
    ///
    /// Helper for sign-out and debug data resets.
    func clearAllDataFromRepositories() async throws {
        let allTasks = await taskRepository.getTasks()
        for task in allTasks {
            try await taskRepository.delete(task)
        }

        let allSpreads = await spreadRepository.getSpreads()
        for spread in allSpreads {
            try await spreadRepository.delete(spread)
        }

        let allEvents = await eventRepository.getEvents()
        for event in allEvents {
            try await eventRepository.delete(event)
        }

        let allNotes = await noteRepository.getNotes()
        for note in allNotes {
            try await noteRepository.delete(note)
        }

        if let collectionRepository {
            let allCollections = await collectionRepository.getCollections()
            for collection in allCollections {
                try await collectionRepository.delete(collection)
            }
        }
    }

    // MARK: - Spread Management

    /// Creates a new spread.
    ///
    /// Inbox entries are not auto-assigned on spread creation. Tasks remain in Inbox
    /// until the user explicitly migrates them, and notes remain explicit-only.
    ///
    /// - Parameters:
    ///   - period: The period for the new spread.
    ///   - date: The date for the new spread.
    /// - Returns: The newly created spread.
    /// - Throws: Repository errors if persistence fails.
    func addSpread(period: Period, date: Date) async throws -> DataModel.Spread {
        let spread = DataModel.Spread(period: period, date: date, calendar: calendar)

        try await spreadRepository.save(spread)
        spreads.append(spread)

        if let key = activeDataModelBuilder.spreadKey(
            for: spread,
            spreads: spreads,
            tasks: tasks,
            notes: notes,
            events: events
        ) {
            refreshDataModel(for: .spreadKeys([key]))
        } else {
            refreshDataModel(for: .structural)
        }
        dataVersion += 1

        return spread
    }

    /// Creates a new multiday spread.
    ///
    /// Multiday spreads aggregate entries by date range and do not have direct
    /// entry assignments. No auto-resolution is performed.
    ///
    /// - Parameters:
    ///   - startDate: The start date of the multiday range.
    ///   - endDate: The end date of the multiday range.
    /// - Returns: The newly created multiday spread.
    /// - Throws: Repository errors if persistence fails.
    func addMultidaySpread(startDate: Date, endDate: Date) async throws -> DataModel.Spread {
        // Create the new multiday spread
        let spread = DataModel.Spread(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        // Save spread and add to local list
        try await spreadRepository.save(spread)
        spreads.append(spread)

        if let key = activeDataModelBuilder.spreadKey(
            for: spread,
            spreads: spreads,
            tasks: tasks,
            notes: notes,
            events: events
        ) {
            refreshDataModel(for: .spreadKeys([key]))
        } else {
            refreshDataModel(for: .structural)
        }
        dataVersion += 1

        return spread
    }

    // MARK: - Task Migration

    /// Migrates a task from one spread to another.
    ///
    /// The source assignment status is set to `.migrated` and a new assignment
    /// is created on the destination spread with `.open` status. If an assignment
    /// already exists on the destination, its status is updated.
    ///
    /// - Parameters:
    ///   - task: The task to migrate.
    ///   - source: The spread to migrate from.
    ///   - destination: The spread to migrate to.
    /// - Throws: `MigrationError` if migration is not allowed.
    func migrateTask(
        _ task: DataModel.Task,
        from source: DataModel.Spread,
        to destination: DataModel.Spread
    ) async throws {
        try await moveTask(task, from: sourceSpreadSource(source), to: destination)
    }

    /// Moves a task from either Inbox or a source spread into a destination spread.
    ///
    /// When the task comes from Inbox there is no source assignment to mark as migrated.
    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread
    ) async throws {
        let previousKeys = activeDataModelBuilder.spreadKeys(for: task, spreads: spreads)
        let result = try await taskMigrationCoordinator.moveTask(
            task,
            from: sourceKey,
            to: destination,
            calendar: calendar
        )
        tasks = result.tasks
        refreshDataModel(for: scopeForTaskChange(previousKeys: previousKeys, task: result.task))
        dataVersion += 1
    }

    // MARK: - Note Migration

    /// Migrates a note from one spread to another.
    ///
    /// The source assignment status is set to `.migrated` and a new assignment
    /// is created on the destination spread with `.active` status. If an assignment
    /// already exists on the destination, its status is updated.
    ///
    /// Notes can only be migrated via explicit user action, not batch migration.
    ///
    /// - Parameters:
    ///   - note: The note to migrate.
    ///   - source: The spread to migrate from.
    ///   - destination: The spread to migrate to.
    /// - Throws: `MigrationError` if migration is not allowed.
    func migrateNote(
        _ note: DataModel.Note,
        from source: DataModel.Spread,
        to destination: DataModel.Spread
    ) async throws {
        let previousKeys = activeDataModelBuilder.spreadKeys(for: note, spreads: spreads)
        let result = try await noteMigrationCoordinator.migrateNote(
            note,
            from: source,
            to: destination,
            calendar: calendar
        )
        notes = result.notes
        refreshDataModel(for: scopeForNoteChange(previousKeys: previousKeys, note: result.note))
        dataVersion += 1
    }

    // MARK: - Batch Task Migration

    /// Migrates multiple tasks from one spread to another.
    ///
    /// Skips cancelled tasks silently. Notes are not included in batch migration.
    ///
    /// - Parameters:
    ///   - tasks: The tasks to migrate.
    ///   - source: The spread to migrate from.
    ///   - destination: The spread to migrate to.
    /// - Throws: Repository errors if persistence fails.
    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread
    ) async throws {
        let previousKeys = Set(tasks.flatMap { activeDataModelBuilder.spreadKeys(for: $0, spreads: spreads) })
        let result = try await taskMigrationCoordinator.migrateTasksBatch(
            tasks,
            from: source,
            to: destination,
            calendar: calendar
        )

        guard result.migratedAny else { return }

        self.tasks = result.tasks
        let nextKeys = Set(result.migratedTasks.flatMap { activeDataModelBuilder.spreadKeys(for: $0, spreads: spreads) })
        refreshDataModel(for: .spreadKeys(previousKeys.union(nextKeys)))
        dataVersion += 1
    }

    // MARK: - Traditional Mode Migration

    /// Migrates a task in traditional mode by updating its preferred date and period.
    ///
    /// After updating the preferred date/period, conventional reassignment logic applies:
    /// - If a conventional spread exists for the new date/period, an assignment is created
    /// - If no spread exists, falls back to nearest parent or Inbox
    ///
    /// Does NOT create or mutate Spread records.
    ///
    /// - Parameters:
    ///   - task: The task to migrate.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    /// - Throws: Repository errors if persistence fails.
    func traditionalMigrateTask(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period
    ) async throws {
        let previousKeys = activeDataModelBuilder.spreadKeys(for: task, spreads: spreads)
        let result = try await taskMutationCoordinator.traditionalMigrateTask(
            task,
            newDate: newDate,
            newPeriod: newPeriod,
            calendar: calendar,
            spreads: spreads
        )
        tasks = result.tasks
        refreshDataModel(for: scopeForTaskChange(previousKeys: previousKeys, task: result.task))
        dataVersion += 1
    }

    /// Migrates a note in traditional mode by updating its preferred date and period.
    ///
    /// After updating the preferred date/period, conventional reassignment logic applies:
    /// - If a conventional spread exists for the new date/period, an assignment is created
    /// - If no spread exists, falls back to nearest parent or Inbox
    ///
    /// Does NOT create or mutate Spread records.
    ///
    /// - Parameters:
    ///   - note: The note to migrate.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    /// - Throws: Repository errors if persistence fails.
    func traditionalMigrateNote(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period
    ) async throws {
        let previousKeys = activeDataModelBuilder.spreadKeys(for: note, spreads: spreads)
        let result = try await noteMutationCoordinator.traditionalMigrateNote(
            note,
            newDate: newDate,
            newPeriod: newPeriod,
            calendar: calendar,
            spreads: spreads
        )
        notes = result.notes
        refreshDataModel(for: scopeForNoteChange(previousKeys: previousKeys, note: result.note))
        dataVersion += 1
    }

    // MARK: - Event Migration (Blocked)

    /// Events cannot be migrated.
    ///
    /// Events use computed visibility based on date range overlap, not assignments.
    /// This method always throws `MigrationError.eventMigrationNotSupported`.
    ///
    /// - Parameters:
    ///   - event: The event (ignored).
    ///   - source: The source spread (ignored).
    ///   - destination: The destination spread (ignored).
    /// - Throws: Always throws `MigrationError.eventMigrationNotSupported`.
    func migrateEvent(
        _ event: DataModel.Event,
        from source: DataModel.Spread,
        to destination: DataModel.Spread
    ) async throws {
        throw MigrationError.eventMigrationNotSupported
    }

    // MARK: - Migration Eligibility

    /// Returns tasks eligible for migration from one spread to another.
    ///
    /// Eligible tasks are those with:
    /// - An open assignment on the source spread
    /// - Non-cancelled status
    ///
    /// Excludes tasks that are:
    /// - Cancelled
    /// - Completed on the source spread
    /// - Already migrated from the source spread
    ///
    /// - Parameters:
    ///   - source: The spread to check for eligible tasks.
    ///   - destination: The target spread (used to filter incompatible destinations).
    /// - Returns: Array of tasks eligible for migration.
    func eligibleTasksForMigration(
        from source: DataModel.Spread,
        to destination: DataModel.Spread
    ) -> [DataModel.Task] {
        // Multiday spreads cannot accept direct assignments
        guard destination.period.canHaveTasksAssigned else {
            return []
        }

        return tasks.filter { task in
            // Exclude cancelled tasks
            guard task.status != .cancelled else { return false }

            // Find assignment on source spread
            guard let sourceAssignment = task.assignments.first(where: { assignment in
                assignment.matches(period: source.period, date: source.date, calendar: calendar)
            }) else {
                return false
            }

            // Only open assignments are eligible
            return sourceAssignment.status == .open
        }
    }

    /// Returns all tasks eligible for migration from any parent spread to the given destination.
    ///
    /// Walks up the period hierarchy (day → month → year) collecting eligible tasks
    /// from each parent spread that exists. Deduplicates tasks that appear on multiple parents.
    ///
    /// - Parameter destination: The target spread.
    /// - Returns: Array of unique tasks eligible for migration, with their source spreads.
    func allEligibleTasksForMigration(
        to destination: DataModel.Spread
    ) -> [(task: DataModel.Task, source: DataModel.Spread)] {
        migrationCandidates(to: destination).compactMap { candidate in
            guard let sourceSpread = candidate.sourceSpread else {
                return nil
            }
            return (task: candidate.task, source: sourceSpread)
        }
    }

    // MARK: - Migration + Overdue Helpers

    /// Returns the spread where the task has an open assignment, if any.
    ///
    /// The "destination spread" is the spread a task is currently assigned to with
    /// an `.open` status — i.e., where it is actively due. Used to determine the
    /// current source location before initiating a migration.
    ///
    /// - Parameters:
    ///   - task: The task to inspect.
    ///   - excludedSpread: An optional spread to exclude from the search (e.g., the spread being deleted).
    /// - Returns: The most granular spread with an open assignment, or `nil` if none exists.
    func currentDestinationSpread(
        for task: DataModel.Task,
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        migrationPlanner.currentDestinationSpread(
            for: task,
            spreads: spreads,
            excluding: excludedSpread
        )
    }

    /// Returns the spread where the task is currently visible to the user.
    ///
    /// The "displayed spread" is the most granular spread where the task has any
    /// non-migrated assignment. This differs from `currentDestinationSpread` in that
    /// it includes completed assignments, not just open ones. Used to show the task's
    /// current location in migration review UIs.
    ///
    /// - Parameters:
    ///   - task: The task to inspect.
    ///   - excludedSpread: An optional spread to exclude from the search.
    /// - Returns: The most granular spread with a non-migrated assignment, or `nil` if none exists.
    func currentDisplayedSpread(
        for task: DataModel.Task,
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        migrationPlanner.currentDisplayedSpread(
            for: task,
            spreads: spreads,
            excluding: excludedSpread
        )
    }

    /// Creates a `TaskReviewSourceKey` for the given spread.
    ///
    /// Normalizes the spread's date to the period before packaging it into a key,
    /// ensuring consistent date representation across the migration system.
    private func sourceSpreadSource(_ spread: DataModel.Spread) -> TaskReviewSourceKey {
        TaskReviewSourceKey(
            kind: .spread(
                id: spread.id,
                period: spread.period,
                date: spread.period.normalizeDate(spread.date, calendar: calendar)
            )
        )
    }

    // MARK: - Spread Deletion

    /// Deletes a spread and reassigns all entries to a parent spread or Inbox.
    ///
    /// Entries are never deleted. The deletion process:
    /// 1. Finds all tasks/notes with assignments on the spread
    /// 2. For each entry: marks current assignment as migrated, creates new assignment on parent
    /// 3. If no parent spread exists, entry goes to Inbox
    /// 4. Removes spread from repository
    ///
    /// - Parameter spread: The spread to delete.
    /// - Throws: Repository errors if persistence fails.
    func deleteSpread(_ spread: DataModel.Spread) async throws {
        let result = try await spreadDeletionCoordinator.deleteSpread(
            spread,
            spreads: spreads,
            tasks: tasks,
            notes: notes
        )

        spreads = result.spreads
        tasks = result.tasks
        notes = result.notes

        refreshDataModel(for: .structural)
        dataVersion += 1
    }

    // MARK: - Task Creation

    /// Creates a new task with the specified parameters.
    ///
    /// The task is created with:
    /// - Normalized date for the selected period
    /// - Status `.open`
    /// - Assignment to the best matching spread (or Inbox if none)
    ///
    /// - Parameters:
    ///   - title: The task title.
    ///   - date: The preferred date for the task.
    ///   - period: The preferred period for the task.
    /// - Returns: The newly created task.
    /// - Throws: Repository errors if persistence fails.
    func addTask(title: String, date: Date, period: Period) async throws -> DataModel.Task {
        let result = try await taskMutationCoordinator.createTask(
            title: title,
            date: date,
            period: period,
            calendar: calendar,
            spreads: spreads
        )
        let task = result.task
        tasks = result.tasks

        if task.assignments.isEmpty {
            Self.logger.debug("Task created: \(task.id) '\(task.title)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Task created: \(task.id) '\(task.title)' → \(task.period.rawValue) spread")
        }

        refreshDataModel(for: .spreadKeys(activeDataModelBuilder.spreadKeys(for: task, spreads: spreads)))
        dataVersion += 1

        return task
    }

    // MARK: - Task CRUD

    /// Updates a task's title.
    ///
    /// - Parameters:
    ///   - task: The task to update.
    ///   - newTitle: The new title for the task.
    /// - Throws: Repository errors if persistence fails.
    func updateTaskTitle(_ task: DataModel.Task, newTitle: String) async throws {
        let scope = JournalMutationScope.spreadKeys(activeDataModelBuilder.spreadKeys(for: task, spreads: spreads))
        task.title = newTitle

        try await taskRepository.save(task)

        Self.logger.debug("Task title updated: \(task.id) '\(task.title)'")

        refreshDataModel(for: scope)
        dataVersion += 1
    }

    /// Updates a task's status.
    ///
    /// - Parameters:
    ///   - task: The task to update.
    ///   - newStatus: The new status for the task.
    /// - Throws: Repository errors if persistence fails.
    func updateTaskStatus(_ task: DataModel.Task, newStatus: DataModel.Task.Status) async throws {
        guard newStatus != .migrated else {
            throw TaskMutationError.manualMigratedStatusNotAllowed
        }

        let scope = JournalMutationScope.spreadKeys(activeDataModelBuilder.spreadKeys(for: task, spreads: spreads))
        task.status = newStatus

        try await taskRepository.save(task)

        Self.logger.debug("Task status updated: \(task.id) → \(newStatus.rawValue)")

        refreshDataModel(for: scope)
        dataVersion += 1
    }

    /// Updates a task's preferred date and period.
    ///
    /// - Parameters:
    ///   - task: The task to update.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    /// - Throws: Repository errors if persistence fails.
    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period
    ) async throws {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        let previousKeys = activeDataModelBuilder.spreadKeys(for: task, spreads: spreads)
        let result = try await taskMutationCoordinator.updateTaskDateAndPeriod(
            task,
            newDate: newDate,
            newPeriod: newPeriod,
            calendar: calendar,
            spreads: spreads
        )
        tasks = result.tasks

        Self.logger.debug("Task date updated: \(task.id) → \(newPeriod.rawValue) \(normalizedDate)")

        refreshDataModel(for: scopeForTaskChange(previousKeys: previousKeys, task: result.task))
        dataVersion += 1
    }

    /// Deletes a task from the repository and local state.
    ///
    /// - Parameter task: The task to delete.
    /// - Throws: Repository errors if deletion fails.
    func deleteTask(_ task: DataModel.Task) async throws {
        let scope = JournalMutationScope.spreadKeys(activeDataModelBuilder.spreadKeys(for: task, spreads: spreads))
        try await taskRepository.delete(task)
        tasks.removeAll { $0.id == task.id }

        Self.logger.debug("Task deleted: \(task.id) '\(task.title)'")

        refreshDataModel(for: scope)
        dataVersion += 1
    }

    // MARK: - Note CRUD

    /// Creates a new note with the given parameters.
    ///
    /// The note is created with:
    /// - Normalized date for the selected period
    /// - Status `.active`
    /// - Assignment to the best matching spread (or Inbox if none)
    ///
    /// - Parameters:
    ///   - title: The note title.
    ///   - content: The note content (optional extended text).
    ///   - date: The preferred date for the note.
    ///   - period: The preferred period for the note.
    /// - Returns: The newly created note.
    /// - Throws: Repository errors if persistence fails.
    func addNote(
        title: String,
        content: String = "",
        date: Date,
        period: Period
    ) async throws -> DataModel.Note {
        let result = try await noteMutationCoordinator.createNote(
            title: title,
            content: content,
            date: date,
            period: period,
            calendar: calendar,
            spreads: spreads
        )
        let note = result.note
        notes = result.notes

        if note.assignments.isEmpty {
            Self.logger.debug("Note created: \(note.id) '\(note.title)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Note created: \(note.id) '\(note.title)' → \(note.period.rawValue) spread")
        }

        refreshDataModel(for: .spreadKeys(activeDataModelBuilder.spreadKeys(for: note, spreads: spreads)))
        dataVersion += 1

        return note
    }

    /// Deletes a note from the repository and local state.
    ///
    /// - Parameter note: The note to delete.
    /// - Throws: Repository errors if deletion fails.
    func deleteNote(_ note: DataModel.Note) async throws {
        let scope = JournalMutationScope.spreadKeys(activeDataModelBuilder.spreadKeys(for: note, spreads: spreads))
        try await noteRepository.delete(note)
        notes.removeAll { $0.id == note.id }

        Self.logger.debug("Note deleted: \(note.id) '\(note.title)'")

        refreshDataModel(for: scope)
        dataVersion += 1
    }

    /// Updates a note's title and content.
    ///
    /// - Parameters:
    ///   - note: The note to update.
    ///   - newTitle: The new title for the note.
    ///   - newContent: The new content for the note.
    /// - Throws: Repository errors if persistence fails.
    func updateNoteTitle(_ note: DataModel.Note, newTitle: String, newContent: String) async throws {
        let scope = JournalMutationScope.spreadKeys(activeDataModelBuilder.spreadKeys(for: note, spreads: spreads))
        note.title = newTitle
        note.content = newContent

        try await noteRepository.save(note)

        Self.logger.debug("Note updated: \(note.id) '\(note.title)'")

        refreshDataModel(for: scope)
        dataVersion += 1
    }

    /// Updates a note's preferred date and period.
    ///
    /// Also updates the note's assignment to the best matching spread.
    ///
    /// - Parameters:
    ///   - note: The note to update.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    /// - Throws: Repository errors if persistence fails.
    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period
    ) async throws {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        let previousKeys = activeDataModelBuilder.spreadKeys(for: note, spreads: spreads)
        let result = try await noteMutationCoordinator.updateNoteDateAndPeriod(
            note,
            newDate: newDate,
            newPeriod: newPeriod,
            calendar: calendar,
            spreads: spreads
        )
        notes = result.notes

        Self.logger.debug("Note date updated: \(note.id) → \(newPeriod.rawValue) \(normalizedDate)")

        refreshDataModel(for: scopeForNoteChange(previousKeys: previousKeys, note: result.note))
        dataVersion += 1
    }

}
