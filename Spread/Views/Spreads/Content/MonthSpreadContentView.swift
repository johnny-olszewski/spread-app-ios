import SwiftUI

private enum MonthSpreadContentLayout {
    static let sectionSpacing: CGFloat = 20
    static let contentPadding: CGFloat = 16
    static let sectionRowSpacing: CGFloat = 8
}

/// Renders a month spread as a calendar, month-level section, and day-section list.
struct MonthSpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let journalManager: JournalManager
    let viewModel: SpreadsViewModel
    let syncEngine: SyncEngine?
    var entryListConfiguration: EntryListConfiguration = .init()
    var migrationConfiguration: EntryListMigrationConfiguration? = nil
    var onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var autoMigrationFeedback: SpreadAutoMigrationFeedback? {
        guard let feedback = viewModel.autoMigrationFeedback,
              feedback.surfaceSpreadID == spread.id else {
            return nil
        }
        return feedback
    }

    var body: some View {
        if let dataModel = spreadDataModel {
            let contentModel = MonthSpreadContentSupport.model(
                for: spread,
                spreadDataModel: dataModel,
                spreads: journalManager.spreads,
                calendar: calendar
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonthSpreadContentLayout.sectionSpacing) {
                    if autoMigrationFeedback?.anchor == .spreadHeader,
                       let message = autoMigrationFeedback?.message {
                        SpreadAutoMigrationCueView(message: message)
                    }

                    SpreadMonthCalendarView(
                        monthDate: spread.date,
                        mode: journalManager.bujoMode == .conventional ? .conventional : .traditional,
                        journalManager: journalManager
                    )

                    monthSection(entries: contentModel.monthEntries)

                    ForEach(contentModel.daySections) { section in
                        daySection(section)
                    }
                }
                .padding(.horizontal, MonthSpreadContentLayout.contentPadding)
                .padding(.bottom, MonthSpreadContentLayout.sectionSpacing)
            }
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }

    @ViewBuilder
    private func monthSection(entries: [any Entry]) -> some View {
        VStack(alignment: .leading, spacing: MonthSpreadContentLayout.sectionRowSpacing) {
            Text("Month")
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            if entries.isEmpty {
                Text("No month-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.medium)
            } else {
                entryRows(entries, contextualLabels: [:])
            }
        }
    }

    @ViewBuilder
    private func daySection(_ section: MonthSpreadDaySectionModel) -> some View {
        let isAutoMigrationDestination = autoMigrationFeedback.map {
            if case .monthDay(let date) = $0.anchor {
                return date == section.date
            }
            return false
        } ?? false

        VStack(alignment: .leading, spacing: MonthSpreadContentLayout.sectionRowSpacing) {
            daySectionHeader(section)

            if isAutoMigrationDestination, let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
            }

            if section.entries.isEmpty {
                Text("No day-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.small)
            } else {
                let contextualLabels = Dictionary(
                    uniqueKeysWithValues: section.entries.map { entry in
                        (entry.id, dayContextLabel(for: entry))
                    }
                )
                entryRows(section.entries, contextualLabels: contextualLabels)
            }
        }
        .padding(.horizontal, isAutoMigrationDestination ? 12 : 0)
        .padding(.vertical, isAutoMigrationDestination ? 10 : 0)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isAutoMigrationDestination
                        ? SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.08)
                        : Color.clear
                )
        )
    }

    @ViewBuilder
    private func daySectionHeader(_ section: MonthSpreadDaySectionModel) -> some View {
        if journalManager.bujoMode == .conventional,
           case .view(let explicitDaySpread) = section.action {
            Button {
                viewModel.selectedSelection = .conventional(explicitDaySpread)
            } label: {
                HStack(spacing: 8) {
                    Text(daySectionTitle(for: section.date))
                        .font(SpreadTheme.Typography.title3)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(daySectionTitle(for: section.date))
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func entryRows(
        _ entries: [any Entry],
        contextualLabels: [UUID: String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries, id: \.id) { entry in
                monthEntryRow(for: entry, contextualLabel: contextualLabels[entry.id])
                    .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)

                if entry.id != entries.last?.id {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func monthEntryRow(
        for entry: any Entry,
        contextualLabel: String?
    ) -> some View {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                taskRow(task, contextualLabel: contextualLabel)
            }
        case .note:
            if let note = entry as? DataModel.Note {
                noteRow(note, contextualLabel: contextualLabel)
            }
        case .event:
            EmptyView()
        }
    }

    private func taskRow(_ task: DataModel.Task, contextualLabel: String?) -> some View {
        let destinationFormatter = MigrationDestinationFormatter(calendar: calendar)
        let sourceMigrationDestination = migrationConfiguration?.sourceDestinations[task.id]

        return EntryRowView(
            configuration: EntryRowConfiguration(
                entryType: .task,
                taskStatus: task.status,
                title: task.title,
                migrationDestination: destinationFormatter.destination(for: task, from: spread),
                contextualLabel: contextualLabel,
                taskBodyPreview: bodyPreview(for: task),
                taskPriority: task.priority,
                taskDueDateLabel: dueDateLabel(for: task),
                isTaskDueDateHighlighted: isDueDateHighlighted(for: task)
            ),
            iconConfiguration: StatusIconConfiguration(
                entryType: .task,
                taskStatus: task.status
            ),
            onComplete: task.status == .open ? {
                Task { @MainActor in
                    let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                    try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                    await syncEngine?.syncNow()
                }
            } : nil,
            onMigrate: task.status == .open ? sourceMigrationDestination.map { destination in
                {
                    migrationConfiguration?.onSourceMigrationConfirmed(task, destination)
                }
            } : nil,
            onEdit: {
                if task.status == .migrated {
                    onOpenMigratedTask?(task)
                } else {
                    viewModel.showTaskDetail(task)
                }
            },
            onDelete: {
                Task { @MainActor in
                    try? await journalManager.deleteTask(task)
                    await syncEngine?.syncNow()
                }
            },
            onTitleCommit: { @MainActor newTitle in
                try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                await syncEngine?.syncNow()
            },
            trailingAction: task.status == .open ? sourceMigrationDestination.map { destination in
                EntryRowTrailingAction(
                    systemImage: "arrow.right",
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.Migration.sourceButton(task.title),
                    action: {
                        migrationConfiguration?.onSourceMigrationConfirmed(task, destination)
                    }
                )
            } : nil
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.taskRow(task.title))
    }

    private func noteRow(_ note: DataModel.Note, contextualLabel: String?) -> some View {
        EntryRowView(
            note: note,
            contextualLabel: contextualLabel,
            onEdit: { viewModel.showNoteDetail(note) },
            onDelete: {
                Task { @MainActor in
                    try? await journalManager.deleteNote(note)
                    await syncEngine?.syncNow()
                }
            }
        )
    }

    private func dayContextLabel(for entry: any Entry) -> String {
        String(calendar.component(.day, from: entryDate(for: entry)))
    }

    private func daySectionTitle(for date: Date) -> String {
        date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
        )
    }

    private func entryDate(for entry: any Entry) -> Date {
        if let task = entry as? DataModel.Task {
            return task.date
        }

        if let note = entry as? DataModel.Note {
            return note.date
        }

        return entry.createdDate
    }

    private func bodyPreview(for task: DataModel.Task) -> String? {
        guard let body = task.body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return nil
        }
        return body
    }

    private func dueDateLabel(for task: DataModel.Task) -> String? {
        guard let dueDate = task.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return "Due \(formatter.string(from: dueDate))"
    }

    private func isDueDateHighlighted(for task: DataModel.Task) -> Bool {
        guard task.status == .open,
              let dueDate = task.dueDate else {
            return false
        }
        return dueDate.startOfDay(calendar: calendar) <= journalManager.today.startOfDay(calendar: calendar)
    }
}
