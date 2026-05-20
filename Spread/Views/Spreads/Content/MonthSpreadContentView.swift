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
    let viewModel: SpreadsCoordinator
    let syncEngine: SyncEngine?

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

    // MARK: - Configuration map

    private var configurationMap: [EntryType: EntryRowView.Configuration] {
        let cal = calendar
        let today = journalManager.today

        let taskConfig = EntryRowView.Configuration(
            effectiveTaskStatus: { $0.displayTaskStatus },
            isGreyedOut: { entry in
                guard let s = entry.displayTaskStatus else { return false }
                return s == .complete || s == .migrated || s == .cancelled
            },
            hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
            dueDateLabel: { entry in (entry as? DataModel.Task)?.dueDateLabel(calendar: cal) },
            isDueDateHighlighted: { entry in
                (entry as? DataModel.Task)?.isDueDateHighlighted(today: today, calendar: cal) ?? false
            },
            onComplete: { entry in
                guard let task = entry as? DataModel.Task else { return }
                Task { @MainActor in
                    let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                    try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                    await syncEngine?.syncNow()
                }
            },
            onEdit: { entry in
                if let task = entry as? DataModel.Task { viewModel.showTaskDetail(task) }
            },
            onDelete: { entry in
                guard let task = entry as? DataModel.Task else { return }
                Task { @MainActor in
                    try? await journalManager.deleteTask(task)
                    await syncEngine?.syncNow()
                }
            },
            onTitleCommit: { @MainActor entry, newTitle in
                guard let task = entry as? DataModel.Task else { return }
                try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                Task { @MainActor in await syncEngine?.syncNow() }
            },
            inlineActionConfiguration: { entry in
                guard let task = entry as? DataModel.Task, task.status == .open else { return nil }
                let options = EntryRowInlineEditSupport.migrationOptions(for: task, today: today, calendar: cal)
                return EntryRowInlineActionConfiguration(
                    migrationOptions: options,
                    onEditSheet: { viewModel.showTaskDetail(task) },
                    onMigrationSelected: { option in
                        try? await journalManager.updateTaskDateAndPeriod(task, newDate: option.date, newPeriod: option.period)
                        await syncEngine?.syncNow()
                    }
                )
            }
        )

        let noteConfig = EntryRowView.Configuration(
            isGreyedOut: { entry in (entry as? DataModel.Note)?.status == .migrated },
            onEdit: { entry in
                if let note = entry as? DataModel.Note { viewModel.showNoteDetail(note) }
            },
            onDelete: { entry in
                guard let note = entry as? DataModel.Note else { return }
                Task { @MainActor in
                    try? await journalManager.deleteNote(note)
                    await syncEngine?.syncNow()
                }
            }
        )

        return [.task: taskConfig, .note: noteConfig]
    }

    // MARK: - Body

    var body: some View {
        if let dataModel = spreadDataModel {
            let contentModel = MonthSpreadContentSupport.model(
                for: spread,
                spreadDataModel: dataModel,
                spreads: journalManager.spreads,
                calendar: calendar
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonthSpreadContentLayout.sectionSpacing) {
                        if autoMigrationFeedback?.anchor == .spreadHeader,
                           let message = autoMigrationFeedback?.message {
                            SpreadAutoMigrationCueView(message: message)
                        }

                        SpreadMonthCalendarView(
                            monthDate: spread.date,
                            mode: journalManager.bujoMode == .conventional ? .conventional : .traditional,
                            journalManager: journalManager,
                            calendarActionsByDate: contentModel.calendarActionsByDate,
                            onViewDaySpread: { explicitDaySpread in
                                viewModel.selectedSelection = .conventional(explicitDaySpread)
                            },
                            onRevealMonthDaySection: { date in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(date, anchor: .top)
                                }
                            }
                        )

                        monthSection(entries: contentModel.monthEntries)

                        ForEach(contentModel.daySections) { section in
                            daySection(section)
                                .id(section.id)
                        }
                    }
                    .padding(.horizontal, MonthSpreadContentLayout.contentPadding)
                    .padding(.bottom, MonthSpreadContentLayout.sectionSpacing)
                }
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
                entryRows(entries)
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
                entryRows(section.entries)
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
        Text(daySectionTitle(for: section.date))
            .font(SpreadTheme.Typography.title3)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func entryRows(_ entries: [any Entry]) -> some View {
        let configs = configurationMap
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries, id: \.id) { entry in
                if let config = configs[entry.entryType] {
                    EntryRowView(entry: entry, configuration: config)
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                }
                if entry.id != entries.last?.id {
                    Divider()
                }
            }
        }
    }

    private func daySectionTitle(for date: Date) -> String {
        date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
        )
    }

}
