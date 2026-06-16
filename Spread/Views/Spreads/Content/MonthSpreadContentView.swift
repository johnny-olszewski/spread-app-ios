import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// Renders a month spread as a calendar, month-level section, and day-section list.
struct MonthSpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let context: SpreadPageContext

    // MARK: - Layout

    private enum Layout {
        static let sectionSpacing: CGFloat = 20
        static let contentPadding: CGFloat = 16
        static let sectionRowSpacing: CGFloat = 8
    }

    // MARK: - Computed

    private var calendar: Calendar { context.calendar }

    private var contentModel: MonthSpreadContentModel {
        MonthSpreadContentSupport.model(
            for: spread,
            spreadDataModel: spreadDataModel,
            spreads: context.journalManager.spreads,
            calendar: calendar
        )
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

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                SpreadMonthCalendarView(
                    monthDate: spread.date,
                    journalManager: context.journalManager,
                    calendarActionsByDate: contentModel.calendarActionsByDate,
                    onViewDaySpread: { context.coordinator.selectSpread($0) },
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

    // MARK: - Sections

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
                    configurationMap: configurationMap
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
                    configurationMap: configurationMap
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
        date.formatted(.dateTime.weekday(.wide).day())
    }
}
