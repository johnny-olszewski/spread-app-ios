import SwiftUI

/// Renders a multiday spread as a responsive grid of day cards.
///
/// Each day card shows either a summary tile (when an explicit day spread exists)
/// or the full entry list for that day. Multiday-assigned tasks appear in a full-width
/// assignment section above the day cards.
struct MultidaySpreadContentView: View {

    @State private var viewModel: ViewModel

    /// Stored for `Equatable` comparison without accessing `@State`.
    /// See `MultidaySpreadContentView+Equatable.swift`.
    let spreadID: UUID

    /// Incremented by `SpreadsCoordinator` when a navigate-to-today request targets this view.
    /// Triggers a scroll to today's day section whenever it changes or on first appear.
    let scrollToTodayToken: Int

    @AppStorage("entryGrouping.multiday") private var groupingOption: EntryGroupingOption = .none
    @AppStorage("entrySorting.multiday") private var sortingOption: EntrySortOption = .dueDate

    init(
        spread: DataModel.Spread,
        spreadDataModel: SpreadDataModel,
        context: SpreadPageContext,
        scrollToTodayToken: Int
    ) {
        spreadID = spread.id
        self.scrollToTodayToken = scrollToTodayToken
        _viewModel = State(wrappedValue: ViewModel(
            spread: spread,
            spreadDataModel: spreadDataModel,
            context: context
        ))
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: SpreadTheme.Spacing.large) {
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
                    .padding(.horizontal, SpreadTheme.Spacing.large)
                }

                let sections = viewModel.sections(groupedBy: groupingOption, orderedBy: sortingOption)
                if sections.allSatisfy({ $0.entries.isEmpty }) {
                    EntryListEmptyStateView(
                        message: "Nothing planned for these days yet. Add a task or note with the + button."
                    )
                }
                LazyVStack(alignment: .leading, spacing: SpreadTheme.Spacing.large) {
                    ForEach(sections) { section in
                        if section.creationPeriod == .multiday {
                            multidayEntrySection(section)
                        } else {
                            daySection(section)
                                .id(section.date)
                        }
                    }
                }
            }
            .padding(.horizontal, SpreadTheme.Spacing.large)
            .padding(.bottom, SpreadTheme.Spacing.large)
            .task(id: scrollToTodayToken) {
                guard scrollToTodayToken > 0 else { return }
                let today = viewModel.context.journalManager.today
                let calendar = viewModel.context.calendar
                let sections = viewModel.sections(groupedBy: groupingOption, orderedBy: sortingOption)
                guard let todaySection = sections.first(where: {
                    $0.creationPeriod != .multiday &&
                    calendar.isDate($0.date, equalTo: today, toGranularity: .day)
                }) else { return }
                proxy.scrollTo(todaySection.date, anchor: .center)
            }
        }
        .conditionalScrollView()
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid)
        .task(id: viewModel.spread.id) {
            await viewModel.fetchCalendarEvents()
        }
    }

    // MARK: - Sections

    private func multidayEntrySection(_ section: EntryList.Section) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.entries, id: \.id) { entry in
                    entryRow(entry: entry)
                }

                QuickAddButton(
                    coordinator: viewModel.context.coordinator,
                    anchorID: section.id,
                    date: section.creationDate,
                    period: section.creationPeriod,
                    onAddTask: viewModel.onAddTask
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func daySection(_ section: EntryList.Section) -> some View {
        
        let explicitDaySpread = viewModel.explicitDaySpread(for: section.date)
        let calendar = viewModel.context.calendar
        
        let dateID = Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: section.date, calendar: calendar)
        let cardStyle = SpreadCardStyle(
            for: section.date,
            today: viewModel.context.journalManager.today,
            explicitDaySpread: explicitDaySpread,
            calendar: calendar
        )
        let shortMonthText = section.date.shortMonthText(calendar: calendar)
        let weekdayText = section.date.weekdayText(calendar: calendar)
        let dayNumberText = section.date.dayNumberText(calendar: calendar)
        let onFooterTap: () -> Void = {
            if let explicitDaySpread {
                viewModel.context.coordinator.navigateViaPeek(to: explicitDaySpread, from: viewModel.spread)
            } else {
                viewModel.context.coordinator.showSpreadCreation(prefill: .init(period: .day, date: section.date))
            }
        }
        let onPeek: (() -> Void)? = explicitDaySpread.map { daySpread in
            {
                if let data = viewModel.peekData(for: daySpread) {
                    viewModel.context.coordinator.showSpreadPeek(data)
                }
            }
        }

        if let explicitDaySpread {
            let openTaskCount = viewModel.openTaskCount(for: explicitDaySpread)
            let eventCount = section.entries.filter { $0.entryType == .event }.count
            MultidayDayCardView(
                dateID: dateID,
                cardStyle: cardStyle,
                overdueCount: 0,
                shortMonthText: shortMonthText,
                weekdayText: weekdayText,
                dayNumberText: dayNumberText,
                isContentCentered: true,
                onPeek: onPeek,
                onFooterTap: onFooterTap
            ) {
                summaryContent(taskCount: openTaskCount, eventCount: eventCount)
            }
        } else {
            MultidayDayCardView(
                dateID: dateID,
                cardStyle: cardStyle,
                overdueCount: viewModel.overdueCount(for: section),
                shortMonthText: shortMonthText,
                weekdayText: weekdayText,
                dayNumberText: dayNumberText,
                onFooterTap: onFooterTap
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(section.entries, id: \.id) { entry in
                        entryRow(entry: entry)
                            .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                    }
                    QuickAddButton(
                        coordinator: viewModel.context.coordinator,
                        anchorID: section.id,
                        date: section.creationDate,
                        period: section.creationPeriod,
                        availableLists: viewModel.context.journalManager.lists,
                        availableTags: viewModel.context.journalManager.tags,
                        accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayAddTaskButton(dateID),
                        onAddTask: viewModel.onAddTask
                    )
                    .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                }
            }
        }
    }

    private func summaryContent(taskCount: Int, eventCount: Int) -> some View {
        HStack(spacing: 24) {
            Label {
                Text("\(taskCount)")
                    .font(SpreadTheme.Typography.title3)
                    .fontWeight(.medium)
            } icon: {
                SpreadTheme.Icon.circle.sized(15)
                    .iconTint(taskCount > 0 ? Color.primary : Color.secondary)
            }
            .foregroundStyle(taskCount > 0 ? Color.primary : Color.secondary)

            Label {
                Text("\(eventCount)")
                    .font(SpreadTheme.Typography.title3)
                    .fontWeight(.medium)
            } icon: {
                SpreadTheme.Icon.calendar.sized(15)
                    .iconTint(eventCount > 0 ? Color.primary : Color.secondary)
            }
            .foregroundStyle(eventCount > 0 ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(taskCount) open tasks, \(eventCount) events")
    }

    @ViewBuilder
    private func entryRow(entry: any Entry) -> some View {
        if let config = viewModel.configurationMap[ObjectIdentifier(type(of: entry))] {
            EntryRowView(entry: entry, configuration: config)
        }
    }
}
