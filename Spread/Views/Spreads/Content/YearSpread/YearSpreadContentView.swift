import SwiftUI
import JohnnyOFoundationUI

/// Renders the dedicated year surface: one top year-entry section plus month cards.
struct YearSpreadContentView: View {

    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let syncEngine: SyncEngine?

    @Environment(JournalManager.self) private var journalManager
    @Environment(SpreadsCoordinator.self) private var coordinator

    @State private var vm = ViewModel()

    // MARK: - Layout

    private enum Layout {
        static let sectionSpacing: CGFloat = 20
        static let contentPadding: CGFloat = 16
    }

    // MARK: - Computed

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var yearEntries: [any Entry] {
        let tasks = spreadDataModel.tasks.filter { $0.period == .year }
        let notes = spreadDataModel.notes.filter { $0.period == .year }
        return tasks + notes
    }

    private var configurationMap: [EntryType: EntryRowView.Configuration] {
        [
            .task: .standardTaskConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator),
            .note: .standardNoteConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator)
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
        .task(id: spread.id) {
            vm.configure(spread: spread, spreadDataModel: spreadDataModel, journalManager: journalManager)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            vm.refreshYearEntries(spread: spread, spreadDataModel: spreadDataModel, journalManager: journalManager)
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
                    configurationMap: configurationMap,
                    style: .inline
                )
            }
        }
    }

    // MARK: - Month Card

    @ViewBuilder
    private func monthCard(_ date: Date) -> some View {
        let normalizedDate = Period.month.normalizeDate(date, calendar: calendar)
        let monthSpreadDataModel = journalManager.spreadDataModel(for: date, period: .month)
        let monthSpread = monthSpreadDataModel?.spread
        let visualState = MultidayDayCardSupport.visualState(
            isToday: calendar.isDate(normalizedDate, equalTo: journalManager.today, toGranularity: .month),
            isCreated: monthSpread != nil
        )

        if let monthSpread {
            let openTaskCount = monthSpreadDataModel?.tasks.filter { $0.status == .open }.count ?? 0
            let peekAction: (() -> Void)? = monthSpreadDataModel.map { dm in
                {
                    coordinator.showSpreadPeek(.init(
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
                onViewSpread: { coordinator.selectSpread(monthSpread) }
            )
        } else {
            let entries = ViewModel.entriesForMonth(normalizedDate, from: spreadDataModel, calendar: calendar)
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
                onCreateSpread: { coordinator.showSpreadCreation(prefill: .init(period: .month, date: normalizedDate)) }
            )
        }
    }
}
