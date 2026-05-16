import SwiftUI

/// One day card within a multiday spread grid.
///
/// Two branches:
/// - When an explicit day spread exists for this date: renders a summary tile (task count, event count, peek button).
/// - Otherwise: renders the full entry list, calendar events, and inline creation affordance.
struct MultidayDaySectionView<RowContent: View>: View {

    let section: EntryListSection
    let parentSpread: DataModel.Spread
    let calendar: Calendar
    let today: Date
    let dayEvents: [CalendarEvent]
    let explicitDaySpread: DataModel.Spread?
    let openTaskCount: Int
    let activeInlineCreationTarget: EntryListViewModel.InlineCreationTarget?
    let showAddTask: Bool
    let onFooterTap: () -> Void
    let onPeek: (() -> Void)?
    let onAddTaskTap: () -> Void
    let onEventTap: (CalendarEvent) -> Void
    @Binding var inlineTitle: String
    let inlineCreationID: UUID
    var inlineFocus: FocusState<Bool>.Binding
    let onInlineSubmit: () -> Void
    @ViewBuilder var rowContent: (any Entry, String?) -> RowContent

    private var dateID: String {
        Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: section.date, calendar: calendar)
    }

    private var visualState: MultidayDayCardVisualState {
        MultidayDayCardSupport.visualState(
            for: section.date,
            today: today,
            explicitDaySpread: explicitDaySpread,
            calendar: calendar
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
        let eventCount = dayEvents.count
        return MultidayDayCardView(
            dateID: dateID,
            visualState: visualState,
            footerAction: footerAction,
            overdueCount: 0,
            shortMonthText: EntryListMultidaySupport.shortMonthText(for: section.date, calendar: calendar),
            weekdayText: EntryListMultidaySupport.weekdayText(for: section.date, calendar: calendar),
            dayNumberText: EntryListMultidaySupport.dayNumberText(for: section.date, calendar: calendar),
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
        let isDayActive = activeInlineCreationTarget?.sectionID == section.id
        return MultidayDayCardView(
            dateID: dateID,
            visualState: visualState,
            footerAction: footerAction,
            overdueCount: overdueCount,
            shortMonthText: EntryListMultidaySupport.shortMonthText(for: section.date, calendar: calendar),
            weekdayText: EntryListMultidaySupport.weekdayText(for: section.date, calendar: calendar),
            dayNumberText: EntryListMultidaySupport.dayNumberText(for: section.date, calendar: calendar),
            footerAccessibilityLabel: footerAccessibilityLabel,
            onFooterTap: onFooterTap
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(section.entries, id: \.id) { entry in
                    rowContent(entry, section.contextualLabel(for: entry))
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                }

                ForEach(dayEvents) { event in
                    CalendarEventRow(event: event, calendar: calendar)
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                        .contentShape(Rectangle())
                        .onTapGesture { onEventTap(event) }
                }

                if isDayActive {
                    inlineCreationRow
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                } else if showAddTask {
                    addTaskButton
                        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.multidayAddTaskButton(dateID)
                        )
                } else if section.entries.isEmpty, dayEvents.isEmpty {
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

    // MARK: - Inline Creation

    private var inlineCreationRow: some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(entryType: .task, taskStatus: .open, color: .primary)
                .frame(width: 24, height: 24)

            TextField("New task", text: $inlineTitle)
                .id(inlineCreationID)
                .textFieldStyle(.plain)
                .font(SpreadTheme.Typography.body)
                .focused(inlineFocus)
                .submitLabel(.done)
                .onSubmit { onInlineSubmit() }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        inlineFocus.wrappedValue = true
                    }
                }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadContent.inlineTaskCreationField
                )

            Spacer()
        }
    }

    private var addTaskButton: some View {
        Button {
            onAddTaskTap()
        } label: {
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                Text("Add Task")
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var overdueCount: Int {
        guard let endDate = parentSpread.endDate else { return 0 }
        let todayStart = today.startOfDay(calendar: calendar)
        guard todayStart > endDate.startOfDay(calendar: calendar) else { return 0 }

        return section.entries.reduce(into: 0) { count, entry in
            guard let task = entry as? DataModel.Task, task.status == .open else { return }
            let isAssigned = task.assignments.contains { assignment in
                assignment.status == .open &&
                assignment.matches(spread: parentSpread, calendar: calendar)
            }
            if isAssigned { count += 1 }
        }
    }
}
