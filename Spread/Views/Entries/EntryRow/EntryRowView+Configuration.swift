import SwiftUI
import JohnnyOFoundationUI

extension EntryRowView {

    /// A type-level configuration describing how entries of one type are displayed and what actions they support.
    ///
    /// One configuration per entry type is stored in `EntryListViewModel.configurationMap`. At render time
    /// `EntryRowView` calls each closure with the specific entry to derive per-row values. All business logic —
    /// date formatting, persistence callbacks — lives in closures built at the call site.
    ///
    /// `actions` covers menu/toolbar-item gestures only. Drag-to-migrate and swipe actions (both possible
    /// eventually, no concrete priority yet) are a deliberately deferred, separate extension point — they're
    /// gestures applied to the row's container view (`.draggable`/`.swipeActions`), not menu items, so they
    /// can't be folded into `Action`. No speculative closures are added for them here until that work is
    /// actually scoped.
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

            /// Builds this action's menu/toolbar item.
            ///
            /// `editEntryButton`/`onConfirmChanges` exist because `.openEdit`'s button and the
            /// inline-edit-confirmation flow are owned by `EntryRowView` itself (a pre-built
            /// button view and `@State`-backed confirmation respectively) — `Action` has no
            /// view identity of its own to hold either, so the caller supplies them.
            @ViewBuilder
            func menuLabel(
                labelStyle: some LabelStyle,
                entry: any Entry,
                editEntryButton: @escaping () -> AnyView,
                onConfirmChanges: @escaping (@escaping @MainActor () async -> Void) -> Void,
                showAlert: ((SpreadsCoordinator.AlertDestination) -> Void)?
            ) -> some View {
                switch self {
                case .openEdit:
                    editEntryButton()
                case .migrate(let migrationOptions, let onMigrationSelected):
                    let options = migrationOptions(entry)
                    if !options.isEmpty {
                        Menu {
                            ForEach(options) { option in
                                Button {
                                    onConfirmChanges {
                                        await onMigrationSelected(entry, option)
                                    }
                                } label: {
                                    Label(option.label, systemImage: systemImageName)
                                }
                                .accessibilityIdentifier(
                                    Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationOption(
                                        entry.title,
                                        option: option.kind.rawValue
                                    )
                                )
                            }
                        } label: {
                            Label("Migrate", systemImage: systemImageName)
                                .font(.system(size: SpreadTheme.IconSize.medium))
                                .labelStyle(labelStyle)
                        }
                        .accessibilityLabel("Migrate")
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu(entry.title)
                        )
                    }
                case .delete(let deleteEntry):
                    Button {
                        let alert = SpreadsCoordinator.AlertDestination.alert(
                            AlertModel.deleteEntryConfirmation(confirmAction: { await deleteEntry(entry) })
                        )
                        showAlert?(alert)
                    } label: {
                        Label("Delete", systemImage: systemImageName)
                    }
                }
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
        
        let calendar = journalManager.configuredCalendar
        let today = journalManager.today

        return EntryRowView.Configuration(
            isGreyedOut: { entry in
                guard entry.entryType == .task else { return false }
                return entry.status == .complete || entry.status == .migrated || entry.status == .cancelled
            },
            hasStrikethrough: {
                entry in entry.status == .cancelled
            },
            dueDateLabel: typed { (task: DataModel.Task) in task.dueDateLabel(calendar: calendar) },
            isDueDateHighlighted: typed(default: false) { (task: DataModel.Task) in
                task.isDueDateHighlighted(today: today, calendar: calendar)
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
            getChips: typed(default: []) { (task: DataModel.Task) in getChips?(task) ?? task.tags }
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
            isGreyedOut: typed(default: false) { (note: DataModel.Note) in note.status == .migrated },
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
        let calendar = journalManager.configuredCalendar
        let today = journalManager.today
        return EntryRowView.Configuration(
            isGreyedOut: typed(default: false) { (event: DataModel.Event) in
                (event.calendarEvent?.endDate ?? event.endDate) < today
            },
            subtitle: typed { (event: DataModel.Event) -> String? in
                guard let calEvent = event.calendarEvent else { return nil }
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

// MARK: - Type-Narrowing Helpers

/// Wraps a closure typed over a concrete `Entry` conformer, downcasting once instead of
/// repeating `entry as? Concrete` guards throughout each `standard*Config` factory. Returns
/// `nil` when `entry` isn't an `E` — for closures whose own return type is already `Optional`.
fileprivate func typed<E: Entry, T>(_ body: @escaping (E) -> T?) -> (any Entry) -> T? {
    { entry in (entry as? E).flatMap(body) }
}

/// Variant of `typed` for closures returning a non-optional value, substituting `defaultValue`
/// when `entry` isn't an `E`.
fileprivate func typed<E: Entry, T>(default defaultValue: T, _ body: @escaping (E) -> T) -> (any Entry) -> T {
    { entry in
        guard let typedEntry = entry as? E else { return defaultValue }
        return body(typedEntry)
    }
}

// MARK: - Migration option computation

fileprivate func taskMigrationOptions(
    for task: DataModel.Task,
    today: Date,
    calendar: Calendar
) -> [EntryRowView.Configuration.Action.MigrationOption] {
    guard task.status == .open else { return [] }

    // No preferred date means the task has no current position, so no candidate should be
    // excluded as "already there" — .distantPast never matches a real comparison below.
    let taskCurrentDate = task.date ?? .distantPast

    let normalizedToday = Period.day.normalizeDate(today, calendar: calendar)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: normalizedToday)
    let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: normalizedToday)?
        .firstDayOfMonth(calendar: calendar)
    let sameDayNextMonth = calendar.date(byAdding: .month, value: 1, to: normalizedToday)

    let todayComponents = calendar.dateComponents([.day], from: normalizedToday)
    let sameDayComponents = sameDayNextMonth.map { calendar.dateComponents([.day], from: $0) }

    var options: [EntryRowView.Configuration.Action.MigrationOption] = []

    if task.period != .day || !calendar.isDate(taskCurrentDate, inSameDayAs: normalizedToday) {
        options.append(.init(kind: .today, label: "Today", date: normalizedToday, period: .day))
    }

    if let tomorrow, (task.period != .day || !calendar.isDate(taskCurrentDate, inSameDayAs: tomorrow)) {
        options.append(.init(kind: .tomorrow, label: "Tomorrow", date: tomorrow, period: .day))
    }

    if let nextMonthStart,
       task.period != .month || !calendar.isDate(taskCurrentDate, equalTo: nextMonthStart, toGranularity: .month) {
        options.append(.init(
            kind: .nextMonth,
            label: migrationMonthLabel(for: nextMonthStart, calendar: calendar),
            date: nextMonthStart,
            period: .month
        ))
    }

    if let sameDayNextMonth,
       todayComponents.day == sameDayComponents?.day,
       task.period != .day || !calendar.isDate(taskCurrentDate, inSameDayAs: sameDayNextMonth) {
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
