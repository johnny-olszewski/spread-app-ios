import SwiftUI

/// Day view for traditional mode showing entries for a single day.
///
/// Displays a date header with back-to-month navigation, followed by a flat
/// entry list. Uses `TraditionalSpreadService` to build a virtual spread data
/// model containing only entries with preferred date matching this day.
struct TraditionalDayView: View {

    // MARK: - Properties

    /// The journal manager providing entry data.
    @Bindable var journalManager: JournalManager

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// The day to display (normalized to start of day).
    let dayDate: Date

    /// Callback to navigate back to month view.
    var onBackToMonth: (() -> Void)?

    let navigatorModel: SpreadHeaderNavigatorModel
    var onSelectSelection: ((SpreadHeaderNavigatorModel.Selection) -> Void)?

    /// The note currently being edited via detail sheet.
    @State private var noteBeingEdited: DataModel.Note?

    /// The task currently being edited via detail sheet.
    @State private var taskBeingEdited: DataModel.Task?

    // MARK: - Private

    private var calendar: Calendar { journalManager.calendar }

    private var traditionalService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    /// The virtual spread data model for this day.
    private var dayDataModel: SpreadDataModel {
        traditionalService.virtualSpreadDataModel(
            period: .day,
            date: dayDate,
            tasks: journalManager.tasks,
            notes: journalManager.notes,
            events: FeatureFlags.eventsEnabled ? journalManager.events : []
        )
    }

    /// Day title (e.g., "March 10, 2026").
    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long
        return formatter.string(from: dayDate)
    }

    /// Short month name for the back button (e.g., "March").
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM"
        return formatter.string(from: dayDate)
    }

    /// Whether the displayed date is today.
    private var isToday: Bool {
        calendar.isDate(dayDate, inSameDayAs: journalManager.today)
    }

    @State private var isShowingNavigator = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation header
            dayHeader

            Divider()

            // Entry list
            EntryListView(
                spreadDataModel: dayDataModel,
                calendar: calendar,
                today: journalManager.today,
                onEdit: { entry in
                    if let task = entry as? DataModel.Task {
                        taskBeingEdited = task
                    } else if let note = entry as? DataModel.Note {
                        noteBeingEdited = note
                    }
                },
                onDelete: { entry in
                    if let task = entry as? DataModel.Task {
                        Task { @MainActor in
                            try? await journalManager.deleteTask(task)
                            await syncEngine?.syncNow()
                        }
                    } else if let note = entry as? DataModel.Note {
                        Task { @MainActor in
                            try? await journalManager.deleteNote(note)
                            await syncEngine?.syncNow()
                        }
                    }
                },
                onComplete: { task in
                    Task { @MainActor in
                        let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                        try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                        await syncEngine?.syncNow()
                    }
                },
                onTitleCommit: { task, newTitle in
                    try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                    Task { @MainActor in
                        await syncEngine?.syncNow()
                    }
                },
                onReassignTask: { task, date, period in
                    try? await journalManager.updateTaskDateAndPeriod(task, newDate: date, newPeriod: period)
                    await syncEngine?.syncNow()
                },
                onAddTask: { title, date, period in
                    try await journalManager.addTask(title: title, date: date, period: period)
                    await syncEngine?.syncNow()
                },
                onRefresh: {
                    guard let engine = syncEngine, engine.status.shouldTriggerSync else { return }
                    await engine.syncNow()
                },
                syncStatus: syncEngine?.status
            )
        }
        .dotGridBackground(.paper)
        .sheet(item: $noteBeingEdited) { note in
            NoteDetailSheet(
                note: note,
                journalManager: journalManager,
                onDelete: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        }
        .sheet(item: $taskBeingEdited) { task in
            TaskDetailSheet(
                task: task,
                journalManager: journalManager,
                onDelete: {
                    Task { @MainActor in await syncEngine?.syncNow() }
                }
            )
        }
        .accessibilityIdentifier("traditionalDayView")
    }

    // MARK: - Subviews

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Back to month button
            if onBackToMonth != nil {
                Button {
                    onBackToMonth?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text(monthName)
                            .font(SpreadTheme.Typography.subheadline)
                    }
                }
            }

            // Day title
            HStack(spacing: 8) {
                Group {
                    SpreadHeaderView(
                        configuration: SpreadHeaderConfiguration(
                            spread: DataModel.Spread(period: .day, date: dayDate, calendar: calendar),
                            calendar: calendar,
                            taskCount: 0,
                            noteCount: 0
                        ),
                        isShowingNavigator: $isShowingNavigator,
                        navigatorModel: navigatorModel,
                        currentSpread: DataModel.Spread(period: .day, date: dayDate, calendar: calendar),
                        onNavigatorSelect: { selection in
                            onSelectSelection?(selection)
                        }
                    )
                }

                if isToday {
                    Text("Today")
                        .font(SpreadTheme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                }
            }
            .accessibilityIdentifier("traditionalDayTitle")

            // Entry count summary
            let totalEntries = dayDataModel.tasks.count + dayDataModel.notes.count
            if totalEntries > 0 {
                Text("\(totalEntries) entr\(totalEntries == 1 ? "y" : "ies")")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Day with entries") {
    TraditionalDayView(
        journalManager: .previewInstance,
        syncEngine: nil,
        dayDate: Date(),
        onBackToMonth: {
            print("Back to month")
        },
        navigatorModel: .traditionalPreview
    )
}

#Preview("Empty day") {
    TraditionalDayView(
        journalManager: .previewInstance,
        syncEngine: nil,
        dayDate: Calendar.current.date(from: DateComponents(year: 2030, month: 6, day: 15))!,
        onBackToMonth: nil,
        navigatorModel: .traditionalPreview
    )
}
