import SwiftUI

/// One day card within a multiday spread grid.
///
/// Two branches:
/// - When an explicit day spread exists for this date: renders a summary tile (task count, event count, peek button).
/// - Otherwise: renders the full entry list, calendar events, and inline creation affordance.
struct MultidayDaySectionView<RowContent: View>: View {

    @Bindable var viewModel: EntryListViewModel
    let section: EntryListSection
    let parentSpread: DataModel.Spread
    let explicitDaySpread: DataModel.Spread?
    let openTaskCount: Int
    let onFooterTap: () -> Void
    let onPeek: (() -> Void)?
    @ViewBuilder var rowContent: (any Entry, String?) -> RowContent

    private var dateID: String {
        Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: section.date, calendar: viewModel.calendar)
    }

    private var visualState: MultidayDayCardVisualState {
        MultidayDayCardSupport.visualState(
            for: section.date,
            today: viewModel.today,
            explicitDaySpread: explicitDaySpread,
            calendar: viewModel.calendar
        )
    }

    private var footerAction: MultidayDayCardAction {
        MultidayDayCardSupport.footerAction(for: section.date, explicitDaySpread: explicitDaySpread)
    }

    private var footerAccessibilityLabel: String {
        switch footerAction {
        case .navigate: return "Open day spread"
        case .createDay: return "Create day spread"
        }
    }

    var body: some View {
        if explicitDaySpread != nil {
            summaryCard
        } else {
            fullCard
        }
    }

    // MARK: - Summary Card (explicit day spread exists)

    private var summaryCard: some View {
        let eventCount = section.entries.filter { $0.entryType == .event }.count
        return MultidayDayCardView(
            dateID: dateID,
            visualState: visualState,
            footerAction: footerAction,
            overdueCount: 0,
            shortMonthText: EntryListMultidaySupport.shortMonthText(for: section.date, calendar: viewModel.calendar),
            weekdayText: EntryListMultidaySupport.weekdayText(for: section.date, calendar: viewModel.calendar),
            dayNumberText: EntryListMultidaySupport.dayNumberText(for: section.date, calendar: viewModel.calendar),
            footerAccessibilityLabel: footerAccessibilityLabel,
            isContentCentered: true,
            onPeek: onPeek,
            onFooterTap: onFooterTap
        ) {
            summaryContent(taskCount: openTaskCount, eventCount: eventCount)
        }
    }

    private func summaryContent(taskCount: Int, eventCount: Int) -> some View {
        HStack(spacing: 24) {
            Label {
                Text("\(taskCount)")
                    .font(SpreadTheme.Typography.title3)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "circle")
                    .font(.system(size: 15))
            }
            .foregroundStyle(taskCount > 0 ? Color.primary : Color.secondary)

            Label {
                Text("\(eventCount)")
                    .font(SpreadTheme.Typography.title3)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 15))
            }
            .foregroundStyle(eventCount > 0 ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(taskCount) open tasks, \(eventCount) events")
    }

    // MARK: - Full Card (no day spread)

    private var fullCard: some View {
        let isDayActive = viewModel.activeInlineCreationTarget?.sectionID == section.id
        let target = viewModel.creationTarget(for: section)
        return MultidayDayCardView(
            dateID: dateID,
            visualState: visualState,
            footerAction: footerAction,
            overdueCount: overdueCount,
            shortMonthText: EntryListMultidaySupport.shortMonthText(for: section.date, calendar: viewModel.calendar),
            weekdayText: EntryListMultidaySupport.weekdayText(for: section.date, calendar: viewModel.calendar),
            dayNumberText: EntryListMultidaySupport.dayNumberText(for: section.date, calendar: viewModel.calendar),
            footerAccessibilityLabel: footerAccessibilityLabel,
            onFooterTap: onFooterTap
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(section.entries, id: \.id) { entry in
                    rowContent(entry, section.contextualLabel(for: entry))
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                }

                if isDayActive {
                    InlineCreationRowView(viewModel: viewModel, target: target)
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                } else if viewModel.onAddTask != nil {
                    AddTaskRowView(viewModel: viewModel, target: target)
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.multidayAddTaskButton(dateID)
                        )
                } else if section.entries.isEmpty {
                    Text("No entries for this day.")
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.multidayEmptyState(dateID)
                        )
                }
            }
        }
    }

    // MARK: - Helpers

    private var overdueCount: Int {
        guard let endDate = parentSpread.endDate else { return 0 }
        let todayStart = viewModel.today.startOfDay(calendar: viewModel.calendar)
        guard todayStart > endDate.startOfDay(calendar: viewModel.calendar) else { return 0 }

        return section.entries.reduce(into: 0) { count, entry in
            guard let task = entry as? DataModel.Task, task.status == .open else { return }
            let isAssigned = task.assignments.contains { assignment in
                assignment.status == .open &&
                assignment.matches(spread: parentSpread, calendar: viewModel.calendar)
            }
            if isAssigned { count += 1 }
        }
    }
}
