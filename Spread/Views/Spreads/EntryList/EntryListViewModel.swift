import SwiftUI

/// The public interface for `EntryListView`.
///
/// Callers create and own this ViewModel, configure it with pre-computed sections and
/// callbacks, then pass it to `EntryListView`. The view is a pure renderer.
@Observable @MainActor final class EntryListViewModel {

    // MARK: - Nested Types

    struct InlineCreationTarget: Equatable {
        let sectionID: String
        let date: Date
        let period: Period
    }

    struct PendingSourceMigration: Identifiable {
        let task: DataModel.Task
        let destination: DataModel.Spread

        var id: UUID { task.id }
    }

    // MARK: - Data (set by caller)

    /// Pre-computed sections to render. Callers use `EntryListGrouper` to produce these.
    var sections: [EntryListSection] = []

    var calendar: Calendar = .current
    var today: Date = Date()
    var calendarEvents: [CalendarEvent] = []

    /// Notes that have been migrated from the current spread, shown in the collapsed history section.
    var migratedNotes: [DataModel.Note] = []

    /// Migration affordances for tasks migrated to/from this spread.
    var migrationConfiguration: EntryListMigrationConfiguration?

    var syncStatus: SyncStatus?

    /// The spread currently being viewed, used for migration status resolution.
    /// Set by callers in a spread context; nil in contexts like EntryBrowser.
    var spread: DataModel.Spread?

    /// When `true`, tasks migrated from the current spread display with migrated status and a destination label.
    /// Set by callers in conventional spread mode; leave `false` for traditional mode or non-spread contexts.
    var showsMigrationHistory: Bool = false

    // MARK: - Callbacks (set by caller)

    var onEdit: ((any Entry) -> Void)?
    var onOpenMigratedTask: ((DataModel.Task) -> Void)?
    var onDelete: ((any Entry) -> Void)?
    var onComplete: ((DataModel.Task) -> Void)?
    var onTitleCommit: (@MainActor (DataModel.Task, String) async -> Void)?
    var onReassignTask: (@MainActor (DataModel.Task, Date, Period) async -> Void)?
    var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?
    var onRefresh: (() async -> Void)?

    // MARK: - UI State

    var activeInlineCreationTarget: InlineCreationTarget?
    var inlineTitle: String = ""
    var inlineCreationID: UUID = UUID()
    var activeInlineTaskID: UUID?
    var pendingSourceMigration: PendingSourceMigration?
    var hasAcquiredInlineCreationFocus: Bool = false

    // MARK: - Computed

    var hasAnyEntries: Bool {
        !sections.allSatisfy { $0.entries.isEmpty } ||
        !migratedNotes.isEmpty ||
        !(migrationConfiguration?.destinationItems.isEmpty ?? true) ||
        !calendarEvents.isEmpty
    }

    var destinationFormatter: MigrationDestinationFormatter {
        MigrationDestinationFormatter(calendar: calendar)
    }

    // MARK: - Business Logic

    func rowStatus(for task: DataModel.Task) -> DataModel.Task.Status {
        let isMigrated = showsMigrationHistory && isMigratedOnSpread(task)
        return isMigrated ? .migrated : task.status
    }

    func isMigratedOnSpread(_ task: DataModel.Task) -> Bool {
        guard let spread else { return false }
        return task.assignments.contains { assignment in
            assignment.status == .migrated &&
            assignment.matches(spread: spread, calendar: calendar)
        }
    }

    func calendarEventsForDay(_ date: Date) -> [CalendarEvent] {
        let dayStart = date.startOfDay(calendar: calendar)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }
        return calendarEvents.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
    }

    func sourceMigrationDestinationTitle(for dest: DataModel.Spread) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long

        switch dest.period {
        case .year:
            return String(calendar.component(.year, from: dest.date))
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: dest.date)
        case .day, .multiday:
            return formatter.string(from: dest.date)
        }
    }

    func inlineActionConfiguration(for task: DataModel.Task) -> EntryRowInlineActionConfiguration? {
        guard task.status == .open else { return nil }
        let migrationOptions = EntryRowInlineEditSupport.migrationOptions(
            for: task,
            today: today,
            calendar: calendar
        )
        return EntryRowInlineActionConfiguration(
            migrationOptions: migrationOptions,
            onEditSheet: { [weak self] in self?.onEdit?(task) },
            onMigrationSelected: { [weak self] option in
                await self?.onReassignTask?(task, option.date, option.period)
            }
        )
    }

    // MARK: - Inline Creation

    func activateInlineCreation(for target: InlineCreationTarget) {
        dismissActiveInlineEditing()
        inlineTitle = ""
        inlineCreationID = UUID()
        activeInlineCreationTarget = target
    }

    func commitInlineTask(target: InlineCreationTarget) {
        let trimmed = inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dismissInlineCreation()
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await onAddTask?(trimmed, target.date, target.period)
                dismissInlineCreation()
            } catch {
                // Keep the inline row open on failure
            }
        }
    }

    func dismissInlineCreation() {
        activeInlineCreationTarget = nil
        inlineTitle = ""
        hasAcquiredInlineCreationFocus = false
    }

    func dismissActiveInlineEditing() {
        activeInlineTaskID = nil
    }

    func creationTarget(for section: EntryListSection) -> InlineCreationTarget {
        InlineCreationTarget(
            sectionID: section.id,
            date: section.creationDate,
            period: section.creationPeriod
        )
    }
}
