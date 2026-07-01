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
    let storedHorizontalSizeClass: UserInterfaceSizeClass?

    @AppStorage("entryGrouping.multiday") private var groupingOption: EntryGroupingOption = .none
    @AppStorage("entrySorting.multiday") private var sortingOption: EntrySortOption = .dueDate

    init(
        spread: DataModel.Spread,
        spreadDataModel: SpreadDataModel,
        context: SpreadPageContext,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) {
        spreadID = spread.id
        storedHorizontalSizeClass = horizontalSizeClass
        _viewModel = State(wrappedValue: ViewModel(
            spread: spread,
            spreadDataModel: spreadDataModel,
            context: context,
            horizontalSizeClass: horizontalSizeClass
        ))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: SpreadTheme.Spacing.large) {
            HStack {
                Spacer()
                EntryListOptionsPicker(
                    grouping: groupingOption,
                    sorting: sortingOption,
                    onGroupingSelected: { groupingOption = $0 },
                    onSortingSelected: { sortingOption = $0 }
                )
                .padding(.horizontal, SpreadTheme.Spacing.large)
            }

            OverdueCardView(spread: viewModel.spread, context: viewModel.context)

            LazyVGrid(
                columns: viewModel.columns,
                alignment: .leading,
                spacing: SpreadTheme.Spacing.large
            ) {
                ForEach(viewModel.sections(groupedBy: groupingOption, orderedBy: sortingOption)) { section in
                    if section.creationPeriod == .multiday {
                        multidayEntrySection(section)
                            .gridCellColumns(viewModel.columnCount)
                    } else {
                        daySection(section)
                    }
                }
            }
        }
        .padding(SpreadTheme.Spacing.large)
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

// MARK: - Column Count

extension UserInterfaceSizeClass {
    /// The number of day-card columns to use in a multiday spread grid.
    var multidayColumnCount: Int { self == .regular ? 2 : 1 }
}
