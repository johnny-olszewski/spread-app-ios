import SwiftUI
import JohnnyOFoundationUI

/// Renders the dedicated year surface: one top year-entry section plus month cards.
struct YearSpreadContentView: View {

    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let context: SpreadPageContext
    /// Incremented by `SpreadsCoordinator` when a navigate-to-today request targets this view.
    /// Triggers a scroll to today's month card whenever it changes or on first appear.
    let scrollToTodayToken: Int

    @AppStorage("entryGrouping.year") private var groupingOption: EntryGroupingOption = .list
    @AppStorage("entrySorting.year") private var sortingOption: EntrySortOption = .dueDate

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

    /// Whether the year spread has no entries at any level (year, month, or day) —
    /// the whole-spread empty-state condition (SPRD-304).
    private var hasNoEntries: Bool {
        spreadDataModel.tasks.isEmpty && spreadDataModel.notes.isEmpty
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
        VStack(spacing: 0) {
            HStack {
                Capsule()
                    .stroke(SpreadTheme.DotGrid.defaultDots)
                    .frame(height: SpreadTheme.CornerRadius.xxlarge)
                    .padding(.vertical, SpreadTheme.Spacing.large)
                    .padding(.trailing, SpreadTheme.Spacing.medium)
                EntryListOptionsPicker(
                    grouping: groupingOption,
                    sorting: sortingOption,
                    onGroupingSelected: { groupingOption = $0 },
                    onSortingSelected: { sortingOption = $0 }
                )
                .padding(.horizontal, Layout.contentPadding)
            }
            .padding(.horizontal, Layout.contentPadding)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {

                        if hasNoEntries {
                            EntryListEmptyStateView(
                                message: "Nothing logged in this year yet. Add long-horizon tasks and notes with the + button."
                            )
                        } else {
                            topYearSection
                        }

                        ForEach(monthDates, id: \.self) { date in
                            monthCard(date)
                        }
                    }
                    .padding(.horizontal, Layout.contentPadding)
                    .padding(.top, Layout.contentPadding)
                    .padding(.bottom, Layout.sectionSpacing)
                }
                .task(id: scrollToTodayToken) {
                    guard scrollToTodayToken > 0 else { return }
                    let today = context.journalManager.today
                    guard let todayMonthDate = monthDates.first(where: {
                        calendar.isDate($0, equalTo: today, toGranularity: .month)
                    }) else { return }
                    proxy.scrollTo(todayMonthDate, anchor: .center)
                }
            }
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
                    entries: yearEntries,
                    groupedBy: groupingOption.grouping(date: spread.date, creationPeriod: .year, creationDate: spread.date),
                    orderedBy: sortingOption.areInOrder,
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
        let cardStyle = SpreadCardStyle(
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
                cardStyle: cardStyle,
                style: .count(taskCount: openTaskCount),
                onPeek: peekAction,
                onViewSpread: { context.coordinator.selectSpread(monthSpread) }
            )
        } else {
            let entries = Self.entriesForMonth(normalizedDate, from: spreadDataModel, calendar: calendar)
            let sections = EntryList.Section.grouped(
                from: entries,
                by: groupingOption.grouping(date: normalizedDate, creationPeriod: .month, creationDate: normalizedDate),
                orderedBy: sortingOption.areInOrder
            )

            MonthCardView(
                monthDate: normalizedDate,
                calendar: calendar,
                cardStyle: cardStyle,
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
                lhs.conventionalSortKey(calendar: calendar) < rhs.conventionalSortKey(calendar: calendar)
            }
    }

    private static func monthCardMonthDate(for entry: any Entry, calendar: Calendar) -> Date? {
        if let task = entry as? DataModel.Task,
           task.period == .month || task.period == .day,
           let taskDate = task.date {
            return Period.month.normalizeDate(taskDate, calendar: calendar)
        }
        if let note = entry as? DataModel.Note,
           note.period == .month || note.period == .day,
           let noteDate = note.date {
            return Period.month.normalizeDate(noteDate, calendar: calendar)
        }
        return nil
    }
}
