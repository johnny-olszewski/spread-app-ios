import Foundation
import OSLog
import Observation

struct TaskReviewSourceKey: Hashable, Identifiable {
    enum Kind: Hashable {
        case inbox
        case spread(id: UUID, period: Period, date: Date)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .inbox:
            return "inbox"
        case .spread(let id, _, _):
            return "spread-\(id.uuidString)"
        }
    }

    var period: Period? {
        switch kind {
        case .inbox:
            return nil
        case .spread(_, let period, _):
            return period
        }
    }

    var date: Date? {
        switch kind {
        case .inbox:
            return nil
        case .spread(_, _, let date):
            return date
        }
    }

    var sourceRank: Int {
        period?.granularityRank ?? 0
    }
}

struct MigrationCandidate: Identifiable {
    let task: DataModel.Task
    let sourceKey: TaskReviewSourceKey
    let sourceSpread: DataModel.Spread?
    let destination: DataModel.Spread

    var id: String {
        "\(task.id.uuidString)-\(sourceKey.id)-\(destination.id.uuidString)"
    }
}

struct OverdueTaskItem: Identifiable {
    let task: DataModel.Task
    let sourceKey: TaskReviewSourceKey

    var id: UUID { task.id }
}

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

    /// Service for finding best spreads for entry assignment in conventional mode.
    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    /// Service for virtual spread generation and entry mapping in traditional mode.
    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    // MARK: - Inbox

    /// Entries that have no matching spread assignment.
    ///
    /// Includes tasks and notes that either have no assignments or have no
    /// assignment matching any existing spread. Events are excluded (they use
    /// computed visibility). Cancelled tasks are excluded.
    var inboxEntries: [any Entry] {
        var entries: [any Entry] = []

        // Add unassigned tasks (excluding cancelled)
        for task in tasks where task.status != .cancelled {
            if task.assignments.isEmpty || !hasMatchingAssignment(for: task) {
                entries.append(task)
            }
        }

        // Add unassigned notes
        for note in notes {
            if note.assignments.isEmpty || !hasMatchingAssignment(for: note) {
                entries.append(note)
            }
        }

        return entries
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
        guard bujoMode == .conventional, destination.period.canHaveTasksAssigned else {
            return []
        }

        return tasks.compactMap { task in
            migrationCandidate(for: task, to: destination)
        }
    }

    /// Returns the smallest valid existing destination spread for a task on a specific source spread.
    ///
    /// Used by the source-side row affordance to determine whether an inline migration action
    /// should be shown on the current spread.
    func migrationDestination(
        for task: DataModel.Task,
        on source: DataModel.Spread
    ) -> DataModel.Spread? {
        guard bujoMode == .conventional,
              source.period.canHaveTasksAssigned,
              task.status == .open else {
            return nil
        }

        guard task.assignments.contains(where: { assignment in
            assignment.status == .open &&
            assignment.matches(period: source.period, date: source.date, calendar: calendar)
        }) else {
            return nil
        }

        return mostGranularValidDestination(
            for: task,
            sourceRank: source.period.granularityRank
        )
    }

    /// Returns migration candidates that come only from the destination's parent hierarchy.
    ///
    /// This powers the destination-side inline migration section. Inbox-origin tasks are
    /// intentionally excluded from this UI.
    func parentHierarchyMigrationCandidates(
        to destination: DataModel.Spread
    ) -> [MigrationCandidate] {
        let parentSpreadIDs = Set(parentHierarchySpreads(for: destination).map(\.id))

        return migrationCandidates(to: destination)
            .filter { candidate in
                guard let sourceSpread = candidate.sourceSpread else { return false }
                return parentSpreadIDs.contains(sourceSpread.id)
            }
            .sorted { lhs, rhs in
                lhs.task.title.localizedCaseInsensitiveCompare(rhs.task.title) == .orderedAscending
            }
    }

    /// Open tasks that are overdue anywhere in the journal.
    var overdueTaskItems: [OverdueTaskItem] {
        tasks.compactMap { task in
            overdueTaskItem(for: task)
        }
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
        creationPolicy: SpreadCreationPolicy
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
        switch bujoMode {
        case .conventional:
            buildConventionalDataModel()
        case .traditional:
            buildTraditionalDataModel()
        }
    }

    /// Builds the data model for conventional mode using created spreads and assignments.
    private func buildConventionalDataModel() {
        var model: JournalDataModel = [:]

        // Organize spreads by period and normalized date
        for spread in spreads {
            let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)

            if model[spread.period] == nil {
                model[spread.period] = [:]
            }

            var spreadData = SpreadDataModel(spread: spread)

            // Associate tasks with this spread
            spreadData.tasks = tasksForSpread(spread)

            // Associate notes with this spread
            spreadData.notes = notesForSpread(spread)

            // Associate events based on date overlap
            spreadData.events = events.filter { event in
                eventAppearsOnSpread(event, spread: spread)
            }

            model[spread.period]?[normalizedDate] = spreadData
        }

        dataModel = model
    }

    /// Builds the data model for traditional mode using virtual spreads from entry preferred dates.
    ///
    /// Generates virtual spreads for every year, month, and day that contains entries.
    /// Entries appear only on their preferred date/period (no assignment history).
    private func buildTraditionalDataModel() {
        var model: JournalDataModel = [:]
        let service = traditionalSpreadService

        // Collect all unique period/date combinations from entries
        var virtualSpreads: [(period: Period, date: Date)] = []

        // Gather year-level virtual spreads
        let years = service.yearsWithEntries(tasks: tasks, notes: notes, events: events)
        for yearDate in years {
            virtualSpreads.append((.year, yearDate))
        }

        // Gather month-level virtual spreads
        for yearDate in years {
            let months = service.monthsWithEntries(inYear: yearDate, tasks: tasks, notes: notes, events: events)
            for monthDate in months {
                virtualSpreads.append((.month, monthDate))
            }
        }

        // Gather day-level virtual spreads
        let allMonths = years.flatMap {
            service.monthsWithEntries(inYear: $0, tasks: tasks, notes: notes, events: events)
        }
        for monthDate in allMonths {
            let days = service.daysWithEntries(inMonth: monthDate, tasks: tasks, notes: notes, events: events)
            for dayDate in days {
                virtualSpreads.append((.day, dayDate))
            }
        }

        // Build SpreadDataModel for each virtual spread
        for (period, date) in virtualSpreads {
            let spreadData = service.virtualSpreadDataModel(
                period: period,
                date: date,
                tasks: tasks,
                notes: notes,
                events: events
            )

            if model[period] == nil {
                model[period] = [:]
            }

            let normalizedDate = period.normalizeDate(date, calendar: calendar)
            model[period]?[normalizedDate] = spreadData
        }

        dataModel = model
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

    // MARK: - Entry Association Helpers

    /// Returns tasks that should appear on the given spread.
    ///
    /// Cancelled tasks are excluded from spread entry lists.
    private func tasksForSpread(_ spread: DataModel.Spread) -> [DataModel.Task] {
        if spread.period == .multiday {
            return tasks.filter { $0.status != .cancelled && entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return tasks.filter { $0.status != .cancelled && hasSpreadAssociation($0, for: spread) }
    }

    /// Returns notes that should appear on the given spread.
    private func notesForSpread(_ spread: DataModel.Spread) -> [DataModel.Note] {
        if spread.period == .multiday {
            return notes.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return notes.filter { hasSpreadAssociation($0, for: spread) }
    }

    /// Checks whether a preferred date falls within a multiday spread's range.
    private func entryDateFallsWithinMultidayRange(_ date: Date, spread: DataModel.Spread) -> Bool {
        guard spread.period == .multiday,
              let startDate = spread.startDate,
              let endDate = spread.endDate else {
            return false
        }

        let normalizedDate = date.startOfDay(calendar: calendar)
        return normalizedDate >= startDate && normalizedDate <= endDate
    }

    /// Checks if a task has an assignment matching the given spread.
    private func hasAssignment(_ task: DataModel.Task, for spread: DataModel.Spread) -> Bool {
        task.assignments.contains { assignment in
            assignment.status != .migrated &&
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    /// Checks if a note has an assignment matching the given spread.
    private func hasAssignment(_ note: DataModel.Note, for spread: DataModel.Spread) -> Bool {
        note.assignments.contains { assignment in
            assignment.status != .migrated &&
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    /// Checks if a task has any assignment, including migrated history, on the given spread.
    private func hasSpreadAssociation(_ task: DataModel.Task, for spread: DataModel.Spread) -> Bool {
        task.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    /// Checks if a note has any assignment, including migrated history, on the given spread.
    private func hasSpreadAssociation(_ note: DataModel.Note, for spread: DataModel.Spread) -> Bool {
        note.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    /// Checks if an event should appear on the given spread.
    private func eventAppearsOnSpread(_ event: DataModel.Event, spread: DataModel.Spread) -> Bool {
        if spread.period == .multiday {
            // For multiday spreads, check if event overlaps with the custom range
            guard let startDate = spread.startDate, let endDate = spread.endDate else {
                return false
            }
            let eventStart = event.startDate.startOfDay(calendar: calendar)
            let eventEnd = event.endDate.startOfDay(calendar: calendar)
            return eventStart <= endDate && eventEnd >= startDate
        }

        return event.appearsOn(period: spread.period, date: spread.date, calendar: calendar)
    }

    // MARK: - Inbox Helpers

    /// Checks if a task has an assignment matching any existing spread.
    ///
    /// Returns `true` if at least one assignment matches a spread, meaning it
    /// should not appear in the Inbox.
    private func hasMatchingAssignment(for task: DataModel.Task) -> Bool {
        spreads.contains { hasAssignment(task, for: $0) }
    }

    /// Checks if a note has an assignment matching any existing spread.
    ///
    /// Returns `true` if at least one assignment matches a spread, meaning it
    /// should not appear in the Inbox.
    private func hasMatchingAssignment(for note: DataModel.Note) -> Bool {
        spreads.contains { hasAssignment(note, for: $0) }
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

        buildDataModel()
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

        // Rebuild data model and trigger UI update
        buildDataModel()
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
        // Cancelled tasks cannot be migrated
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        // Multiday spreads cannot accept direct assignments
        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        switch sourceKey.kind {
        case .inbox:
            break
        case .spread(_, let sourcePeriod, let sourceDate):
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: sourcePeriod, date: sourceDate, calendar: calendar)
            }) else {
                throw MigrationError.noSourceAssignment
            }

            // Mark source as migrated
            task.assignments[sourceIndex].status = .migrated
        }

        // Check if destination assignment already exists
        if let destIndex = task.assignments.firstIndex(where: { assignment in
            assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
        }) {
            // Update existing destination assignment
            task.assignments[destIndex].status = .open
        } else {
            // Create new destination assignment
            let destinationAssignment = TaskAssignment(
                period: destination.period,
                date: destination.date,
                status: .open
            )
            task.assignments.append(destinationAssignment)
        }

        task.status = .open

        // Persist changes
        try await taskRepository.save(task)
        let sourceDescription: String = switch sourceKey.kind {
        case .inbox:
            "inbox"
        case .spread(_, let period, _):
            period.rawValue
        }
        Self.logger.info("Migration performed: task \(task.id) from \(sourceDescription) to \(destination.period.rawValue)")

        // Reload tasks to ensure state is synchronized
        tasks = await taskRepository.getTasks()

        // Rebuild data model and trigger UI update
        buildDataModel()
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
        // Multiday spreads cannot accept direct assignments
        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        // Find source assignment
        guard let sourceIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: source.period, date: source.date, calendar: calendar)
        }) else {
            throw MigrationError.noSourceAssignment
        }

        // Mark source as migrated
        note.assignments[sourceIndex].status = .migrated

        // Check if destination assignment already exists
        if let destIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
        }) {
            // Update existing destination assignment
            note.assignments[destIndex].status = .active
        } else {
            // Create new destination assignment
            let destinationAssignment = NoteAssignment(
                period: destination.period,
                date: destination.date,
                status: .active
            )
            note.assignments.append(destinationAssignment)
        }

        // Persist changes
        try await noteRepository.save(note)
        Self.logger.info(
            "Migration performed: note \(note.id) from \(source.period.rawValue) to \(destination.period.rawValue)"
        )

        // Reload notes to ensure state is synchronized
        notes = await noteRepository.getNotes()

        // Rebuild data model and trigger UI update
        buildDataModel()
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
        // Early return for empty batch
        guard !tasks.isEmpty else { return }

        // Multiday spreads cannot accept direct assignments
        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        var migratedAny = false

        for task in tasks {
            // Skip cancelled tasks
            guard task.status != .cancelled else { continue }

            // Find source assignment
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: source.period, date: source.date, calendar: calendar)
            }) else {
                continue
            }

            // Mark source as migrated
            task.assignments[sourceIndex].status = .migrated

            // Check if destination assignment already exists
            if let destIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                // Update existing destination assignment
                task.assignments[destIndex].status = .open
            } else {
                // Create new destination assignment
                let destinationAssignment = TaskAssignment(
                    period: destination.period,
                    date: destination.date,
                    status: .open
                )
                task.assignments.append(destinationAssignment)
            }

            task.status = .open

            // Persist changes
            try await taskRepository.save(task)
            migratedAny = true
        }

        // Only update state if we actually migrated something
        if migratedAny {
            Self.logger.info(
                "Batch migration performed: \(tasks.count) task(s) from \(source.period.rawValue) to \(destination.period.rawValue)"
            )

            // Reload tasks to ensure state is synchronized
            self.tasks = await taskRepository.getTasks()

            // Rebuild data model and trigger UI update
            buildDataModel()
            dataVersion += 1
        }
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
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)

        // Update preferred date/period
        task.date = normalizedDate
        task.period = newPeriod

        // Clear all existing assignments and create a new one via conventional logic
        task.assignments.removeAll()

        if let bestSpread = traditionalSpreadService.findConventionalSpread(
            forPreferredDate: normalizedDate,
            preferredPeriod: newPeriod,
            in: spreads
        ) {
            let assignment = TaskAssignment(
                period: bestSpread.period,
                date: bestSpread.date,
                status: task.status == .complete ? .complete : .open
            )
            task.assignments.append(assignment)
        }
        // If no spread found, task goes to Inbox (no assignment)

        try await taskRepository.save(task)
        Self.logger.info(
            "Traditional migration: task \(task.id) → \(newPeriod.rawValue) \(normalizedDate)"
        )

        // Reload and rebuild
        tasks = await taskRepository.getTasks()
        buildDataModel()
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
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)

        // Update preferred date/period
        note.date = normalizedDate
        note.period = newPeriod

        // Clear all existing assignments and create a new one via conventional logic
        note.assignments.removeAll()

        if let bestSpread = traditionalSpreadService.findConventionalSpread(
            forPreferredDate: normalizedDate,
            preferredPeriod: newPeriod,
            in: spreads
        ) {
            let assignment = NoteAssignment(
                period: bestSpread.period,
                date: bestSpread.date,
                status: .active
            )
            note.assignments.append(assignment)
        }
        // If no spread found, note goes to Inbox (no assignment)

        try await noteRepository.save(note)
        Self.logger.info(
            "Traditional migration: note \(note.id) → \(newPeriod.rawValue) \(normalizedDate)"
        )

        // Reload and rebuild
        notes = await noteRepository.getNotes()
        buildDataModel()
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

    private func migrationCandidate(
        for task: DataModel.Task,
        to destination: DataModel.Spread
    ) -> MigrationCandidate? {
        guard task.status == .open else {
            return nil
        }

        guard destinationMatchesDesiredPath(destination, forDesiredDate: task.date) else {
            return nil
        }

        guard destination.period.granularityRank <= task.period.granularityRank else {
            return nil
        }

        let sourceKey: TaskReviewSourceKey
        let sourceSpread: DataModel.Spread?
        if let openSpread = currentOpenSpread(for: task) {
            sourceKey = sourceSpreadSource(openSpread)
            sourceSpread = openSpread
        } else {
            sourceKey = .init(kind: .inbox)
            sourceSpread = nil
        }

        guard destination.period.granularityRank > sourceKey.sourceRank else {
            return nil
        }

        guard let bestDestination = mostGranularValidDestination(
            for: task,
            sourceRank: sourceKey.sourceRank
        ) else {
            return nil
        }

        guard bestDestination.id == destination.id else {
            return nil
        }

        return MigrationCandidate(
            task: task,
            sourceKey: sourceKey,
            sourceSpread: sourceSpread,
            destination: destination
        )
    }

    private func overdueTaskItem(for task: DataModel.Task) -> OverdueTaskItem? {
        guard task.status == .open else {
            return nil
        }

        if let openSpread = currentOpenSpread(for: task) {
            let sourceKey = sourceSpreadSource(openSpread)
            guard isOverdue(
                date: openSpread.date,
                period: openSpread.period
            ) else {
                return nil
            }
            return OverdueTaskItem(task: task, sourceKey: sourceKey)
        }

        guard isOverdue(date: task.date, period: task.period) else {
            return nil
        }
        return OverdueTaskItem(task: task, sourceKey: .init(kind: .inbox))
    }

    func currentDestinationSpread(
        for task: DataModel.Task,
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        task.assignments
            .filter { $0.status == .open }
            .compactMap { assignment in
                spreads.first(where: { spread in
                    spread.period == assignment.period &&
                    spread.period.normalizeDate(spread.date, calendar: calendar) ==
                    assignment.period.normalizeDate(assignment.date, calendar: calendar)
                })
            }
            .filter { spread in
                guard let excludedSpread else { return true }
                return spread.id != excludedSpread.id
            }
            .max { lhs, rhs in
                if lhs.period.granularityRank == rhs.period.granularityRank {
                    return lhs.date < rhs.date
                }
                return lhs.period.granularityRank < rhs.period.granularityRank
            }
    }

    func currentDisplayedSpread(
        for task: DataModel.Task,
        excluding excludedSpread: DataModel.Spread? = nil
    ) -> DataModel.Spread? {
        task.assignments
            .filter { $0.status != .migrated }
            .compactMap { assignment in
                spreads.first(where: { spread in
                    spread.period == assignment.period &&
                    spread.period.normalizeDate(spread.date, calendar: calendar) ==
                    assignment.period.normalizeDate(assignment.date, calendar: calendar)
                })
            }
            .filter { spread in
                guard let excludedSpread else { return true }
                return spread.id != excludedSpread.id
            }
            .max { lhs, rhs in
                if lhs.period.granularityRank == rhs.period.granularityRank {
                    return lhs.date < rhs.date
                }
                return lhs.period.granularityRank < rhs.period.granularityRank
            }
    }

    private func currentOpenSpread(for task: DataModel.Task) -> DataModel.Spread? {
        currentDestinationSpread(for: task)
    }

    private func destinationMatchesDesiredPath(
        _ destination: DataModel.Spread,
        forDesiredDate desiredDate: Date
    ) -> Bool {
        destination.period.normalizeDate(destination.date, calendar: calendar) ==
        destination.period.normalizeDate(desiredDate, calendar: calendar)
    }

    private func mostGranularValidDestination(
        for task: DataModel.Task,
        sourceRank: Int
    ) -> DataModel.Spread? {
        spreads
            .filter { spread in
                spread.period.canHaveTasksAssigned &&
                destinationMatchesDesiredPath(spread, forDesiredDate: task.date) &&
                spread.period.granularityRank <= task.period.granularityRank &&
                spread.period.granularityRank > sourceRank
            }
            .max { lhs, rhs in
                lhs.period.granularityRank < rhs.period.granularityRank
            }
    }

    private func sourceSpreadSource(_ spread: DataModel.Spread) -> TaskReviewSourceKey {
        TaskReviewSourceKey(
            kind: .spread(
                id: spread.id,
                period: spread.period,
                date: spread.period.normalizeDate(spread.date, calendar: calendar)
            )
        )
    }

    private func parentHierarchySpreads(
        for destination: DataModel.Spread
    ) -> [DataModel.Spread] {
        var parentSpreads: [DataModel.Spread] = []
        var currentPeriod = destination.period.parentPeriod

        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(destination.date, calendar: calendar)
            if let spread = spreads.first(where: { existingSpread in
                existingSpread.period == period &&
                existingSpread.period.normalizeDate(existingSpread.date, calendar: calendar) == normalizedDate
            }) {
                parentSpreads.append(spread)
            }
            currentPeriod = period.parentPeriod
        }

        return parentSpreads
    }

    private func isOverdue(date: Date, period: Period) -> Bool {
        let todayStart = today.startOfDay(calendar: calendar)

        switch period {
        case .day:
            let dueDay = date.startOfDay(calendar: calendar)
            return todayStart > dueDay
        case .month:
            let startOfMonth = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return false
            }
            return todayStart >= startOfNextMonth
        case .year:
            let startOfYear = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return false
            }
            return todayStart >= startOfNextYear
        case .multiday:
            return false
        }
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
        // Find parent spread for reassignment
        let parentSpread = findParentSpread(for: spread)

        // Reassign tasks
        for task in tasksWithAssignment(on: spread) {
            try await reassignTaskOnSpreadDeletion(task, from: spread, toParent: parentSpread)
        }

        // Reassign notes
        for note in notesWithAssignment(on: spread) {
            try await reassignNoteOnSpreadDeletion(note, from: spread, toParent: parentSpread)
        }

        // Delete spread from repository
        try await spreadRepository.delete(spread)
        Self.logger.info("Spread deleted: \(spread.period.rawValue) spread \(spread.id)")

        // Remove spread from local list
        spreads.removeAll { $0.id == spread.id }

        // Reload entries to ensure state is synchronized
        tasks = await taskRepository.getTasks()
        notes = await noteRepository.getNotes()

        // Rebuild data model and trigger UI update
        buildDataModel()
        dataVersion += 1
    }

    // MARK: - Spread Deletion Helpers

    /// Finds the parent spread for reassignment during deletion.
    ///
    /// Searches from the spread's parent period up through coarser periods
    /// (day → month → year) to find an existing spread.
    private func findParentSpread(for spread: DataModel.Spread) -> DataModel.Spread? {
        var currentPeriod: Period? = spread.period.parentPeriod

        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(spread.date, calendar: calendar)

            if let parentSpread = spreads.first(where: { existingSpread in
                existingSpread.period == period &&
                existingSpread.period.normalizeDate(existingSpread.date, calendar: calendar) == normalizedDate
            }) {
                return parentSpread
            }

            currentPeriod = period.parentPeriod
        }

        return nil
    }

    /// Returns tasks that have an assignment on the given spread.
    private func tasksWithAssignment(on spread: DataModel.Spread) -> [DataModel.Task] {
        tasks.filter { hasSpreadAssociation($0, for: spread) }
    }

    /// Returns notes that have an assignment on the given spread.
    private func notesWithAssignment(on spread: DataModel.Spread) -> [DataModel.Note] {
        notes.filter { hasSpreadAssociation($0, for: spread) }
    }

    /// Reassigns a task during spread deletion.
    ///
    /// Marks the current assignment as migrated and creates a new assignment
    /// on the parent spread. If no parent exists, the task goes to Inbox.
    private func reassignTaskOnSpreadDeletion(
        _ task: DataModel.Task,
        from spread: DataModel.Spread,
        toParent parent: DataModel.Spread?
    ) async throws {
        // Find assignment on the deleted spread
        guard let assignmentIndex = task.assignments.firstIndex(where: { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }) else {
            return
        }

        // Get the status before marking as migrated (to preserve on parent)
        let originalStatus = task.assignments[assignmentIndex].status

        // Mark current assignment as migrated
        task.assignments[assignmentIndex].status = .migrated

        // Create new assignment on parent if exists
        if let parent = parent {
            // Check if assignment already exists on parent
            if let parentIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: parent.period, date: parent.date, calendar: calendar)
            }) {
                // Update existing parent assignment with original status
                task.assignments[parentIndex].status = originalStatus
            } else {
                // Create new assignment on parent
                let parentAssignment = TaskAssignment(
                    period: parent.period,
                    date: parent.date,
                    status: originalStatus
                )
                task.assignments.append(parentAssignment)
            }
        }
        // If no parent, task goes to Inbox (no new assignment needed)

        try await taskRepository.save(task)
    }

    /// Reassigns a note during spread deletion.
    ///
    /// Marks the current assignment as migrated and creates a new assignment
    /// on the parent spread. If no parent exists, the note goes to Inbox.
    private func reassignNoteOnSpreadDeletion(
        _ note: DataModel.Note,
        from spread: DataModel.Spread,
        toParent parent: DataModel.Spread?
    ) async throws {
        // Find assignment on the deleted spread
        guard let assignmentIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }) else {
            return
        }

        // Get the status before marking as migrated (to preserve on parent)
        let originalStatus = note.assignments[assignmentIndex].status

        // Mark current assignment as migrated
        note.assignments[assignmentIndex].status = .migrated

        // Create new assignment on parent if exists
        if let parent = parent {
            // Check if assignment already exists on parent
            if let parentIndex = note.assignments.firstIndex(where: { assignment in
                assignment.matches(period: parent.period, date: parent.date, calendar: calendar)
            }) {
                // Update existing parent assignment with original status
                note.assignments[parentIndex].status = originalStatus
            } else {
                // Create new assignment on parent
                let parentAssignment = NoteAssignment(
                    period: parent.period,
                    date: parent.date,
                    status: originalStatus
                )
                note.assignments.append(parentAssignment)
            }
        }
        // If no parent, note goes to Inbox (no new assignment needed)

        try await noteRepository.save(note)
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
        // Normalize the date for the selected period
        let normalizedDate = period.normalizeDate(date, calendar: calendar)

        // Create the task
        let task = DataModel.Task(
            title: title,
            createdDate: .now,
            date: normalizedDate,
            period: period,
            status: .open,
            assignments: []
        )

        reconcileTaskAssignmentsForPreferredAssignment(task)

        // Save task
        try await taskRepository.save(task)

        // Add to local list
        tasks.append(task)

        if task.assignments.isEmpty {
            Self.logger.debug("Task created: \(task.id) '\(task.title)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Task created: \(task.id) '\(task.title)' → \(task.period.rawValue) spread")
        }

        // Rebuild data model and trigger UI update
        buildDataModel()
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
        task.title = newTitle

        try await taskRepository.save(task)
        tasks = await taskRepository.getTasks()

        Self.logger.debug("Task title updated: \(task.id) '\(task.title)'")

        buildDataModel()
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

        task.status = newStatus

        try await taskRepository.save(task)
        tasks = await taskRepository.getTasks()

        Self.logger.debug("Task status updated: \(task.id) → \(newStatus.rawValue)")

        buildDataModel()
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
        task.date = normalizedDate
        task.period = newPeriod
        reassignTaskAfterDateChange(task)

        try await taskRepository.save(task)
        tasks = await taskRepository.getTasks()

        Self.logger.debug("Task date updated: \(task.id) → \(newPeriod.rawValue) \(normalizedDate)")

        buildDataModel()
        dataVersion += 1
    }

    /// Deletes a task from the repository and local state.
    ///
    /// - Parameter task: The task to delete.
    /// - Throws: Repository errors if deletion fails.
    func deleteTask(_ task: DataModel.Task) async throws {
        try await taskRepository.delete(task)
        tasks.removeAll { $0.id == task.id }

        Self.logger.debug("Task deleted: \(task.id) '\(task.title)'")

        buildDataModel()
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
        let normalizedDate = period.normalizeDate(date, calendar: calendar)

        let note = DataModel.Note(
            title: title,
            content: content,
            date: normalizedDate,
            period: period,
            assignments: []
        )

        // Find the best spread for assignment
        if let bestSpread = spreadService.findBestSpread(for: note, in: spreads) {
            let assignment = NoteAssignment(
                period: bestSpread.period,
                date: bestSpread.date,
                status: .active
            )
            note.assignments.append(assignment)
        }
        // If no spread found, note goes to Inbox (no assignment)

        try await noteRepository.save(note)
        notes.append(note)

        if note.assignments.isEmpty {
            Self.logger.debug("Note created: \(note.id) '\(note.title)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Note created: \(note.id) '\(note.title)' → \(note.period.rawValue) spread")
        }

        buildDataModel()
        dataVersion += 1

        return note
    }

    /// Deletes a note from the repository and local state.
    ///
    /// - Parameter note: The note to delete.
    /// - Throws: Repository errors if deletion fails.
    func deleteNote(_ note: DataModel.Note) async throws {
        try await noteRepository.delete(note)
        notes.removeAll { $0.id == note.id }

        Self.logger.debug("Note deleted: \(note.id) '\(note.title)'")

        buildDataModel()
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
        note.title = newTitle
        note.content = newContent

        try await noteRepository.save(note)
        notes = await noteRepository.getNotes()

        Self.logger.debug("Note updated: \(note.id) '\(note.title)'")

        buildDataModel()
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
        note.date = normalizedDate
        note.period = newPeriod
        reassignNoteAfterDateChange(note)

        try await noteRepository.save(note)
        notes = await noteRepository.getNotes()

        Self.logger.debug("Note date updated: \(note.id) → \(newPeriod.rawValue) \(normalizedDate)")

        buildDataModel()
        dataVersion += 1
    }

    private func reassignTaskAfterDateChange(_ task: DataModel.Task) {
        reconcileTaskAssignmentsForPreferredAssignment(task)
    }

    private func reconcileTaskAssignmentsForPreferredAssignment(_ task: DataModel.Task) {
        let destination = spreadService.findBestSpread(for: task, in: spreads)
        let destinationStatus = task.status == .complete ? DataModel.Task.Status.complete : task.status

        if let destination {
            if let destinationIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                for index in task.assignments.indices where index != destinationIndex && task.assignments[index].status != .migrated {
                    task.assignments[index].status = .migrated
                }
                task.assignments[destinationIndex].status = destinationStatus
            } else {
                migrateActiveTaskAssignmentsToHistory(task)
                task.assignments.append(
                    TaskAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: destinationStatus
                    )
                )
            }
        } else {
            migrateActiveTaskAssignmentsToHistory(task)
        }
    }

    private func reassignNoteAfterDateChange(_ note: DataModel.Note) {
        let destination = spreadService.findBestSpread(for: note, in: spreads)

        if let destination {
            if let destinationIndex = note.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                for index in note.assignments.indices where index != destinationIndex && note.assignments[index].status != .migrated {
                    note.assignments[index].status = .migrated
                }
                note.assignments[destinationIndex].status = .active
            } else {
                migrateActiveNoteAssignmentsToHistory(note)
                note.assignments.append(
                    NoteAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: .active
                    )
                )
            }
        } else {
            migrateActiveNoteAssignmentsToHistory(note)
        }
    }

    private func migrateActiveTaskAssignmentsToHistory(_ task: DataModel.Task) {
        for index in task.assignments.indices where task.assignments[index].status != .migrated {
            task.assignments[index].status = .migrated
        }
    }

    private func migrateActiveNoteAssignmentsToHistory(_ note: DataModel.Note) {
        for index in note.assignments.indices where note.assignments[index].status != .migrated {
            note.assignments[index].status = .migrated
        }
    }
}
