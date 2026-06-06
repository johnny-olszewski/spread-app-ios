import SwiftUI
import JohnnyOFoundationUI

extension EntryRowView {

    /// A type-level configuration describing how entries of one type are displayed and what actions they support.
    ///
    /// One configuration per entry type is stored in `EntryListViewModel.configurationMap`. At render time
    /// `EntryRowView` calls each closure with the specific entry to derive per-row values. All business logic —
    /// date formatting, persistence callbacks — lives in closures built at the call site.
    /// A dictionary mapping concrete `Entry` metatypes (via `ObjectIdentifier`) to row configurations.
    ///
    /// Build maps using `Entry.configurationKey` on each conforming type:
    /// ```swift
    /// [DataModel.Task.configurationKey: taskConfig, DataModel.Note.configurationKey: noteConfig]
    /// ```
    typealias ConfigurationMap = [ObjectIdentifier: Configuration]

    struct Configuration {

        enum Action: Identifiable {
            case openEdit(onTapEditButton: (any Entry) -> Void)
            case migrate(
                migrationOptions: (any Entry) -> [MigrationOption],
                onMigrationSelected: (any Entry, MigrationOption) async -> Void
            )
            case delete(deleteEntry: (any Entry) async -> Void)

            var id: String {
                switch self {
                case .openEdit: return "edit"
                case .migrate: return "migrate"
                case .delete: return "delete"
                }
            }
            
            var systemImageName: String {
                switch self {
                case .openEdit(_): "square.and.pencil"
                case .migrate(_, _): "arrow.right"
                case .delete(_): "trash"
                }
            }

            struct MigrationOption: Identifiable, Equatable {
                enum Kind: String, CaseIterable {
                    case today
                    case tomorrow
                    case nextMonth
                    case nextMonthSameDay
                }

                let kind: Kind
                let label: String
                let date: Date
                let period: Period

                var id: String { kind.rawValue }
            }
        }

        // MARK: - Context-dependent display derivations

        /// Returns whether the row should render greyed out.
        var isGreyedOut: ((any Entry) -> Bool)?

        /// Returns whether the row title should use strikethrough styling.
        var hasStrikethrough: ((any Entry) -> Bool)?

        /// Returns the formatted due date label (tasks only).
        var dueDateLabel: ((any Entry) -> String?)?

        /// Returns whether the due date label should use urgent styling.
        var isDueDateHighlighted: ((any Entry) -> Bool)?

        /// Returns the subtitle shown below the title (e.g. event time range + calendar name).
        var subtitle: ((any Entry) -> String?)?

        // MARK: - Action callbacks

        var onStatusIconTap: ((any Entry) -> Void)?

        var onTitleCommit: (@MainActor (any Entry, String) async -> Void)?
        
        var showAlert: ((SpreadsCoordinator.AlertDestination) -> Void)?

        var actions: [Action] = []
        
        var getChips: ((any Entry) -> [any LabelChipRepresentable])?
    }
}

// MARK: - Standard configurations

extension EntryRowView.Configuration {

    /// Standard task row configuration shared across all spread periods.
    @MainActor
    static func standardTaskConfig(
        journalManager: JournalManager,
        syncEngine: SyncEngine?,
        coordinator: SpreadsCoordinator,
        getChips: ((any Entry) -> [any LabelChipRepresentable])? = nil
    ) -> EntryRowView.Configuration {
        
        let calendar = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
        let today = journalManager.today
        
        return EntryRowView.Configuration(
            isGreyedOut: { entry in
                guard entry.entryType == .task else { return false }
                return entry.status == .complete || entry.status == .migrated || entry.status == .cancelled
            },
            hasStrikethrough: {
                entry in entry.status == .cancelled
            },
            dueDateLabel: {
                entry in (entry as? DataModel.Task)?.dueDateLabel(calendar: calendar)
            },
            isDueDateHighlighted: { entry in
                (entry as? DataModel.Task)?.isDueDateHighlighted(today: today, calendar: calendar) ?? false
            },
            onStatusIconTap: { entry in
                
                // impossible path if configuration is associated with tasks
                guard let task = entry as? DataModel.Task else { return }
                
                Task { @MainActor in
                    let newStatus: EntryStatus = task.status.rotate(in: [.open, .complete, .cancelled])
                    try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                    await syncEngine?.syncNow()
                }
            },
            onTitleCommit: { @MainActor entry, newTitle in
                guard let task = entry as? DataModel.Task else { return }
                try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                Task { @MainActor in await syncEngine?.syncNow() }
            },
            showAlert: { alert in
                coordinator.activeAlert = alert
            },
            actions: [
                .openEdit(onTapEditButton: { entry in
                    if let task = entry as? DataModel.Task { coordinator.showTaskDetail(task) }
                }),
                .migrate(
                    migrationOptions: { entry in
                        guard let task = entry as? DataModel.Task else { return [] }
                        return taskMigrationOptions(for: task, today: today, calendar: calendar)
                    },
                    onMigrationSelected: { entry, option in
                        guard let task = entry as? DataModel.Task else { return }
                        try? await journalManager.updateTaskDateAndPeriod(task, newDate: option.date, newPeriod: option.period)
                        await syncEngine?.syncNow()
                    }),
                .delete(deleteEntry: { entry in
                    guard let task = entry as? DataModel.Task else { return }
                    try? await journalManager.deleteTask(task)
                    await syncEngine?.syncNow()
                })
                
            ],
            getChips: { entry in
                guard let task = entry as? DataModel.Task else { return [] }
                return getChips?(task) ?? task.tags
            }
        )
    }

    /// Standard note row configuration shared across all spread periods.
    @MainActor
    static func standardNoteConfig(
        journalManager: JournalManager,
        syncEngine: SyncEngine?,
        coordinator: SpreadsCoordinator
    ) -> EntryRowView.Configuration {
        return EntryRowView.Configuration(
            isGreyedOut: { entry in (entry as? DataModel.Note)?.status == .migrated },
            showAlert: { alert in coordinator.activeAlert = alert },
            actions: [
                .openEdit(onTapEditButton: { entry in
                    if let note = entry as? DataModel.Note { coordinator.showNoteDetail(note) }
                }),
                .delete(deleteEntry: { entry in
                    guard let note = entry as? DataModel.Note else { return }
                    try? await journalManager.deleteNote(note)
                    await syncEngine?.syncNow()
                })
            ]
        )
    }

    /// Standard calendar event row configuration shared across periods that surface calendar events.
    @MainActor
    static func standardEventConfig(journalManager: JournalManager) -> EntryRowView.Configuration {
        let calendar = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
        let today = journalManager.today
        return EntryRowView.Configuration(
            isGreyedOut: { entry in
                guard let event = entry as? DataModel.Event else { return false }
                return (event.calendarEvent?.endDate ?? event.endDate) < today
            },
            subtitle: { entry in
                guard let event = entry as? DataModel.Event,
                      let calEvent = event.calendarEvent else { return nil }
                if calEvent.isAllDay {
                    return "All Day · \(calEvent.calendarTitle)"
                } else {
                    let fmt = DateFormatter()
                    fmt.calendar = calendar
                    fmt.timeZone = calendar.timeZone
                    fmt.timeStyle = .short
                    fmt.dateStyle = .none
                    return "\(fmt.string(from: calEvent.startDate))–\(fmt.string(from: calEvent.endDate)) · \(calEvent.calendarTitle)"
                }
            },
        )
    }
}

// MARK: - Migration option computation

fileprivate func taskMigrationOptions(
    for task: DataModel.Task,
    today: Date,
    calendar: Calendar
) -> [EntryRowView.Configuration.Action.MigrationOption] {
    guard task.status == .open else { return [] }

    let normalizedToday = Period.day.normalizeDate(today, calendar: calendar)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: normalizedToday)
    let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: normalizedToday)?
        .firstDayOfMonth(calendar: calendar)
    let sameDayNextMonth = calendar.date(byAdding: .month, value: 1, to: normalizedToday)

    let todayComponents = calendar.dateComponents([.day], from: normalizedToday)
    let sameDayComponents = sameDayNextMonth.map { calendar.dateComponents([.day], from: $0) }

    var options: [EntryRowView.Configuration.Action.MigrationOption] = []

    if task.period != .day || !calendar.isDate(task.date, inSameDayAs: normalizedToday) {
        options.append(.init(kind: .today, label: "Today", date: normalizedToday, period: .day))
    }

    if let tomorrow, (task.period != .day || !calendar.isDate(task.date, inSameDayAs: tomorrow)) {
        options.append(.init(kind: .tomorrow, label: "Tomorrow", date: tomorrow, period: .day))
    }

    if let nextMonthStart,
       task.period != .month || !calendar.isDate(task.date, equalTo: nextMonthStart, toGranularity: .month) {
        options.append(.init(
            kind: .nextMonth,
            label: migrationMonthLabel(for: nextMonthStart, calendar: calendar),
            date: nextMonthStart,
            period: .month
        ))
    }

    if let sameDayNextMonth,
       todayComponents.day == sameDayComponents?.day,
       task.period != .day || !calendar.isDate(task.date, inSameDayAs: sameDayNextMonth) {
        options.append(.init(
            kind: .nextMonthSameDay,
            label: migrationDayLabel(for: sameDayNextMonth, calendar: calendar),
            date: sameDayNextMonth,
            period: .day
        ))
    }

    return options
}

fileprivate func migrationMonthLabel(for date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "LLLL yyyy"
    return formatter.string(from: date)
}

fileprivate func migrationDayLabel(for date: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "MMMM d, yyyy"
    return formatter.string(from: date)
}
