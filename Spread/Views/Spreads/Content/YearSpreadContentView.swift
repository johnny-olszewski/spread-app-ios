import SwiftUI
import JohnnyOFoundationUI

private enum YearSpreadContentLayout {
    static let cardCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 14
    static let cardSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 20
    static let contentPadding: CGFloat = 16
    static let miniGridCellHeight: CGFloat = 24
    static let miniGridSpacing: CGFloat = 4
}

/// Renders the dedicated year surface: one top year-entry section plus month cards.
struct YearSpreadContentView: View {

    private struct PendingSourceMigration: Identifiable {
        let task: DataModel.Task
        let destination: DataModel.Spread

        var id: UUID { task.id }
    }

    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let journalManager: JournalManager
    let viewModel: SpreadsViewModel
    let syncEngine: SyncEngine?
    var entryListConfiguration: EntryListConfiguration = .init()
    var migrationConfiguration: EntryListMigrationConfiguration? = nil
    var onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil

    @State private var pendingSourceMigration: PendingSourceMigration?

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    var body: some View {
        if let dataModel = spreadDataModel {
            let contentModel = YearSpreadContentSupport.model(
                for: spread,
                spreadDataModel: dataModel,
                spreads: journalManager.spreads,
                today: journalManager.today,
                calendar: calendar
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    topYearSection(entries: contentModel.yearEntries)

                    ForEach(contentModel.monthCards) { card in
                        monthCard(card)
                    }
                }
                .padding(.horizontal, Layout.contentPadding)
                .padding(.top, Layout.contentPadding)
                .padding(.bottom, Layout.sectionSpacing)
            }
            .alert(item: $pendingSourceMigration) { migration in
                Alert(
                    title: Text("Migrate Task"),
                    message: Text("Move \"\(migration.task.title)\" to \(spreadTitle(for: migration.destination))?"),
                    primaryButton: .default(Text("Migrate")) {
                        migrationConfiguration?.onSourceMigrationConfirmed(migration.task, migration.destination)
                    },
                    secondaryButton: .cancel()
                )
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
    private func topYearSection(entries: [any Entry]) -> some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            Text("Year")
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            if entries.isEmpty {
                Text("No year-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.medium)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entries, id: \.id) { entry in
                        yearEntryRow(for: entry, contextualLabel: nil)
                            .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)

                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func monthCard(_ card: YearSpreadMonthCardModel) -> some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.monthDate.formatted(.dateTime.month(.wide)))
                    .font(SpreadTheme.Typography.title3)
                    .foregroundStyle(card.visualState.primaryHeaderColor)

                Spacer(minLength: 8)

                if card.visualState.isToday {
                    Text("This Month")
                        .font(SpreadTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(SpreadTheme.Accent.todayEmphasis)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(SpreadTheme.Accent.todayEmphasis.opacity(0.1))
                        )
                }
            }

            MiniMonthGridView(
                monthDate: card.monthDate,
                calendar: calendar,
                visualState: card.visualState
            )

            if !card.previews.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(card.previews) { preview in
                        yearEntryRow(for: preview.entry, contextualLabel: preview.contextualLabel)
                            .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)

                        if preview.id != card.previews.last?.id {
                            Divider()
                        }
                    }
                }
            }

            if card.overflowCount > 0 {
                Text("+\(card.overflowCount) more")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Button(card.action.title) {
                dismissInlineEditing()
                switch card.action {
                case .view(let spread):
                    viewModel.selectedSelection = .conventional(spread)
                case .create(let date):
                    viewModel.showSpreadCreation(prefill: .init(period: .month, date: date))
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(cardBackgroundFill(for: card.visualState))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .strokeBorder(card.visualState.borderColor, style: card.visualState.borderStyle)
        )
    }

    @ViewBuilder
    private func yearEntryRow(
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
                    pendingSourceMigration = PendingSourceMigration(task: task, destination: destination)
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
                        pendingSourceMigration = PendingSourceMigration(task: task, destination: destination)
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

    private func dismissInlineEditing() {}

    private func spreadTitle(for spread: DataModel.Spread) -> String {
        SpreadDisplayNameFormatter(
            calendar: calendar,
            today: journalManager.today,
            firstWeekday: journalManager.firstWeekday
        )
        .display(for: spread)
        .primary
    }

    private func cardBackgroundFill(for visualState: MultidayDayCardVisualState) -> Color {
        if visualState.isToday {
            return visualState.fill
        }
        if visualState.isCreated {
            return SpreadTheme.Paper.secondary.opacity(0.45)
        }
        return SpreadTheme.Paper.primary.opacity(0.65)
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

    private enum Layout {
        static let cardCornerRadius = YearSpreadContentLayout.cardCornerRadius
        static let cardPadding = YearSpreadContentLayout.cardPadding
        static let cardSpacing = YearSpreadContentLayout.cardSpacing
        static let sectionSpacing = YearSpreadContentLayout.sectionSpacing
        static let contentPadding = YearSpreadContentLayout.contentPadding
    }
}

private struct MiniMonthGridView: View {
    private let monthDate: Date
    private let calendar: Calendar
    private let visualState: MultidayDayCardVisualState

    init(
        monthDate: Date,
        calendar: Calendar,
        visualState: MultidayDayCardVisualState
    ) {
        self.monthDate = monthDate
        self.calendar = calendar
        self.visualState = visualState
    }

    private var headers: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        return formatter.shortStandaloneWeekdaySymbols.reorderedByFirstWeekday(calendar.firstWeekday).map { symbol in
            String(symbol.prefix(1)).uppercased()
        }
    }

    private var cells: [MiniMonthCell] {
        let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let firstWeekdayOfMonth = calendar.component(.weekday, from: monthStart)
        let leadingPlaceholders = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7

        var cells = Array(repeating: MiniMonthCell(dayNumber: nil), count: leadingPlaceholders)
        cells.append(contentsOf: dayRange.map { day in MiniMonthCell(dayNumber: day) })

        let trailingPlaceholders = (7 - (cells.count % 7)) % 7
        if trailingPlaceholders > 0 {
            cells.append(contentsOf: Array(repeating: MiniMonthCell(dayNumber: nil), count: trailingPlaceholders))
        }

        return cells
    }

    var body: some View {
        VStack(spacing: YearSpreadContentLayout.miniGridSpacing) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    Group {
                        if let dayNumber = cell.dayNumber {
                            Text("\(dayNumber)")
                                .font(.system(size: 10, weight: visualState.headerWeight))
                                .foregroundStyle(visualState.primaryHeaderColor)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: YearSpreadContentLayout.miniGridCellHeight)
                }
            }
        }
    }

    private struct MiniMonthCell {
        let dayNumber: Int?
    }
}

private extension Array where Element == String {
    func reorderedByFirstWeekday(_ firstWeekday: Int) -> [String] {
        guard !isEmpty else { return self }
        let normalizedIndex = Swift.max(0, Swift.min(count - 1, firstWeekday - 1))
        return Array(self[normalizedIndex...]) + Array(self[..<normalizedIndex])
    }
}
