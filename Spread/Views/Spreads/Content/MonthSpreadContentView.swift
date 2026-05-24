import SwiftUI

/// Renders a month spread as a calendar, month-level section, and day-section list.
struct MonthSpreadContentView: View {
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
        static let sectionRowSpacing: CGFloat = 8
    }

    // MARK: - Computed

    private var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }

    private var configurationMap: [EntryType: EntryRowView.Configuration] {
        [
            .task: .standardTaskConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator),
            .note: .standardNoteConfig(journalManager: journalManager, syncEngine: syncEngine, coordinator: coordinator)
        ]
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let contentModel = vm.contentModel {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                            SpreadMonthCalendarView(
                                monthDate: spread.date,
                                mode: journalManager.bujoMode == .conventional ? .conventional : .traditional,
                                journalManager: journalManager,
                                calendarActionsByDate: contentModel.calendarActionsByDate,
                                onViewDaySpread: { explicitDaySpread in
                                    coordinator.selectSpread(explicitDaySpread)
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
                        .padding(.horizontal, Layout.contentPadding)
                        .padding(.bottom, Layout.sectionSpacing)
                    }
                }
            }
        }
        .task(id: spread.id) {
            vm.configure(
                spread: spread,
                spreadDataModel: spreadDataModel,
                journalManager: journalManager
            )
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            vm.refreshContentModel(
                spread: spread,
                spreadDataModel: spreadDataModel,
                journalManager: journalManager
            )
        }
    }

    @ViewBuilder
    private func monthSection(entries: [any Entry]) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionRowSpacing) {
            Text("Month")
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            if entries.isEmpty {
                Text("No month-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.medium)
            } else {
                EntryListView(
                    sections: [EntryList.Section(
                        id: "month-entries",
                        title: "",
                        date: spread.date,
                        entries: entries,
                        creationPeriod: .month,
                        creationDate: spread.date
                    )],
                    configurationMap: configurationMap,
                    style: .inline
                )
            }
        }
    }

    @ViewBuilder
    private func daySection(_ section: MonthSpreadDaySectionModel) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionRowSpacing) {
            daySectionHeader(section)

            if section.entries.isEmpty {
                Text("No day-level entries.")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, SpreadTheme.Spacing.small)
            } else {
                EntryListView(
                    sections: [EntryList.Section(
                        id: section.date.timeIntervalSinceReferenceDate.description,
                        title: "",
                        date: section.date,
                        entries: section.entries,
                        creationPeriod: .day,
                        creationDate: section.date
                    )],
                    configurationMap: configurationMap,
                    style: .inline
                )
            }
        }
    }

    @ViewBuilder
    private func daySectionHeader(_ section: MonthSpreadDaySectionModel) -> some View {
        Text(daySectionTitle(for: section.date))
            .font(SpreadTheme.Typography.title3)
            .foregroundStyle(.primary)
    }

    private func daySectionTitle(for date: Date) -> String {
        date.formatted(
            .dateTime
                .weekday(.wide)
                .day()
        )
    }
}
