import SwiftUI
import JohnnyOFoundationUI

/// Renders the dedicated year surface: one top year-entry section plus month cards.
struct YearSpreadContentView: View {

    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let context: SpreadPageContext

    // MARK: - Layout

    private enum Layout {
        static let sectionSpacing: CGFloat = 20
        static let contentPadding: CGFloat = 16
    }

    // MARK: - Computed

    private var calendar: Calendar { context.calendar }

    private var yearEntries: [any Entry] {
        let tasks = spreadDataModel.tasks.filter { $0.period == .year }
        let notes = spreadDataModel.notes.filter { $0.period == .year }
        return tasks + notes
    }

    private var configurationMap: EntryRowView.ConfigurationMap {
        [
            DataModel.Task.configurationKey: .standardTaskConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            ),
            DataModel.Note.configurationKey: .standardNoteConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            )
        ]
    }

    private var monthDates: [Date] {
        let year = calendar.component(.year, from: spread.date)
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                topYearSection

                ForEach(monthDates, id: \.self) { date in
                    monthCard(date)
                }
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.top, Layout.contentPadding)
            .padding(.bottom, Layout.sectionSpacing)
        }
    }

    // MARK: - Top Year Section

    @ViewBuilder
    private var topYearSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year")
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            if yearEntries.isEmpty {
                Text("No year-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.medium)
            } else {
                EntryListView(
                    sections: [EntryList.Section(
                        id: "year-entries",
                        title: "",
                        date: spread.date,
                        entries: yearEntries,
                        creationPeriod: .year,
                        creationDate: spread.date
                    )],
                    configurationMap: configurationMap
                )
            }
        }
    }

    // MARK: - Month Card

    @ViewBuilder
    private func monthCard(_ date: Date) -> some View {
        let normalizedDate = Period.month.normalizeDate(date, calendar: calendar)
        let monthSpreadDataModel = context.journalManager.spreadDataModel(for: date, period: .month)
        let monthSpread = monthSpreadDataModel?.spread
        let visualState = MultidayDayCardSupport.visualState(
            isToday: calendar.isDate(normalizedDate, equalTo: context.journalManager.today, toGranularity: .month),
            isCreated: monthSpread != nil
        )

        if let monthSpread {
            let openTaskCount = monthSpreadDataModel?.tasks.filter { $0.status == .open }.count ?? 0
            let peekAction: (() -> Void)? = monthSpreadDataModel.map { dm in
                {
                    context.coordinator.showSpreadPeek(.init(
                        spread: monthSpread,
                        spreadDataModel: dm,
                        calendarEvents: nil
                    ))
                }
            }

            MonthCardView(
                monthDate: normalizedDate,
                calendar: calendar,
                visualState: visualState,
                style: .count(taskCount: openTaskCount),
                onPeek: peekAction,
                onViewSpread: { context.coordinator.selectSpread(monthSpread) }
            )
        } else {
            let entries = Self.entriesForMonth(normalizedDate, from: spreadDataModel, calendar: calendar)
            let sections: [EntryList.Section] = entries.isEmpty ? [] : [
                EntryList.Section(
                    id: "month-entries-\(normalizedDate.timeIntervalSinceReferenceDate)",
                    title: "",
                    date: normalizedDate,
                    entries: entries,
                    creationPeriod: .month,
                    creationDate: normalizedDate
                )
            ]

            MonthCardView(
                monthDate: normalizedDate,
                calendar: calendar,
                visualState: visualState,
                style: .list(sections: sections, configurationMap: configurationMap),
                onCreateSpread: {
                    context.coordinator.activeSheet = .spreadCreation(.init(period: .month, date: normalizedDate))
                }
            )
        }
    }

    // MARK: - Static Helpers

    static func entriesForMonth(
        _ monthDate: Date,
        from spreadDataModel: SpreadDataModel,
        calendar: Calendar
    ) -> [any Entry] {
        let normalizedMonth = Period.month.normalizeDate(monthDate, calendar: calendar)
        var allEntries: [any Entry] = []
        allEntries.append(contentsOf: spreadDataModel.tasks)
        allEntries.append(contentsOf: spreadDataModel.notes)
        return allEntries
            .filter { entry in
                guard let candidateMonth = monthCardMonthDate(for: entry, calendar: calendar) else { return false }
                return candidateMonth == normalizedMonth
            }
            .sorted { lhs, rhs in
                sortKey(for: lhs, calendar: calendar) < sortKey(for: rhs, calendar: calendar)
            }
    }

    private static func monthCardMonthDate(for entry: any Entry, calendar: Calendar) -> Date? {
        if let task = entry as? DataModel.Task,
           task.period == .month || task.period == .day {
            return Period.month.normalizeDate(task.date, calendar: calendar)
        }
        if let note = entry as? DataModel.Note,
           note.period == .month || note.period == .day {
            return Period.month.normalizeDate(note.date, calendar: calendar)
        }
        return nil
    }

    private static func sortKey(for entry: any Entry, calendar: Calendar) -> (Date, Int, Date, UUID) {
        if let task = entry as? DataModel.Task {
            return (
                task.period.normalizeDate(task.date, calendar: calendar),
                entryTypeSortOrder(task.entryType),
                task.createdDate,
                task.id
            )
        }
        if let note = entry as? DataModel.Note {
            return (
                note.period.normalizeDate(note.date, calendar: calendar),
                entryTypeSortOrder(note.entryType),
                note.createdDate,
                note.id
            )
        }
        return (.distantFuture, entryTypeSortOrder(entry.entryType), entry.createdDate, entry.id)
    }

    private static func entryTypeSortOrder(_ type: EntryType) -> Int {
        switch type {
        case .task: return 0
        case .note: return 1
        case .event: return 2
        }
    }
}
