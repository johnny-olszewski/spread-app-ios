import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// Renders a month spread as a calendar, month-level section, and day-section list.
struct MonthSpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let context: SpreadPageContext

    @AppStorage("entryGrouping.month") private var groupingOption: EntryGroupingOption = .list
    @AppStorage("entrySorting.month") private var sortingOption: EntrySortOption = .default

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

                // Pinned, non-scrolling top inset — kept outside the ScrollView below so the
                // calendar grid stays visible while the entry content beneath it scrolls.
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
                .padding(.horizontal, Layout.contentPadding)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                        if hasNoEntries {
                            EntryListEmptyStateView(
                                message: "Nothing planned for this month yet. Add a task or note with the + button, or migrate tasks here."
                            )
                        } else {
                            monthSection(entries: contentModel.monthEntries)

                            ForEach(contentModel.daySections) { section in
                                daySection(section)
                                    .id(section.id)
                            }
                        }
                    }
                    .padding(.horizontal, Layout.contentPadding)
                    .padding(.bottom, Layout.sectionSpacing)
                }
            }
        }
    }

    /// Whether the month spread has no entries at any level — the whole-spread
    /// empty-state condition (SPRD-304).
    private var hasNoEntries: Bool {
        contentModel.monthEntries.isEmpty && contentModel.daySections.allSatisfy { $0.entries.isEmpty }
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
                    entries: entries,
                    groupedBy: groupingOption.grouping(date: spread.date, creationPeriod: .month, creationDate: spread.date),
                    orderedBy: sortingOption.areInOrder,
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
                    entries: section.entries,
                    groupedBy: groupingOption.grouping(date: section.date, creationPeriod: .day, creationDate: section.date),
                    orderedBy: sortingOption.areInOrder,
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
