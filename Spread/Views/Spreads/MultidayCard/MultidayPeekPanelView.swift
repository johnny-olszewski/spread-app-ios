import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

// MARK: - Data

/// Data bundle for the multiday peek overlay.
struct MultidayPeekData: Identifiable, Equatable {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let calendarEvents: [CalendarEvent]

    var id: UUID { spread.id }

    static func == (lhs: MultidayPeekData, rhs: MultidayPeekData) -> Bool {
        lhs.spread.id == rhs.spread.id
    }
}

// MARK: - Panel

/// Read-only overlay panel that lets the user peek at a day spread from a multiday view.
///
/// Shows the day's events in a timeline and open tasks in a list. No editing is allowed.
///
/// Layout adapts to size class:
/// - Regular (iPad): timeline card on the leading side, task list on the trailing side.
/// - Compact (iPhone): fixed-height timeline on top, scrollable task list below.
struct MultidayPeekPanelView: View {
    let data: MultidayPeekData
    let calendar: Calendar
    let today: Date
    let onClose: () -> Void
    let onNavigate: (DataModel.Spread) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var timelineScrollPosition = ScrollPosition()

    private let wideTimelineHeight: CGFloat = 800
    private let compactTimelineHeight: CGFloat = 190

    private let provider = SpreadDayTimelineProvider()

    private var allDayEvents: [CalendarEvent] { data.calendarEvents.filter(\.isAllDay) }
    private var timedEvents: [CalendarEvent] { data.calendarEvents.filter { !$0.isAllDay } }

    private var openTasks: [DataModel.Task] {
        data.spreadDataModel.tasks.filter { $0.status == .open }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            if horizontalSizeClass == .regular {
                wideContent
            } else {
                compactContent
            }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 10)
        .task(id: data.calendarEvents.count) {
            scrollToFirstEvent()
        }
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: 12) {
            Text(panelTitle)
                .font(SpreadTheme.Typography.title3)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer()

            Button(action: { onNavigate(data.spread) }) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(SpreadTheme.Accent.todaySelectedEmphasis)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open spread")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close preview")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Wide layout (iPad)

    private var wideContent: some View {
        HStack(alignment: .top, spacing: 0) {
            timelineContent(height: wideTimelineHeight)
                .frame(maxWidth: 240)
                .overlay(alignment: .trailing) { Divider() }
            taskListContent
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Compact layout (iPhone)

    private var compactContent: some View {
        VStack(spacing: 0) {
            timelineContent(height: compactTimelineHeight)
                .frame(height: compactTimelineHeight)
            Divider()
            taskListContent
        }
    }

    // MARK: - Timeline

    private func timelineContent(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            if !allDayEvents.isEmpty {
                DayTimelineAllDaySection(items: allDayEvents) { event in
                    provider.allDayItemView(item: event)
                }
                Divider()
            }
            ScrollView {
                DayTimelineView(
                    provider: provider,
                    items: data.calendarEvents,
                    date: data.spread.date,
                    visibleStartHour: 0,
                    visibleEndHour: 24,
                    height: height,
                    calendar: calendar
                )
                .padding(8)
            }
            .scrollPosition($timelineScrollPosition)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Task list

    private var taskListContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if openTasks.isEmpty && data.calendarEvents.isEmpty {
                    Text("Nothing scheduled for this day.")
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else if openTasks.isEmpty {
                    Text("No open tasks")
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else {
                    ForEach(openTasks, id: \.id) { task in
                        peekTaskRow(task)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func peekTaskRow(_ task: DataModel.Task) -> some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(entryType: .task, taskStatus: .open, color: .primary)
                .frame(width: 24, height: 24)
            Text(task.title)
                .font(SpreadTheme.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, SpreadTheme.Spacing.entryRowVertical)
    }

    // MARK: - Private

    private var panelTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: data.spread.date)
    }

    private func scrollToFirstEvent() {
        guard let first = timedEvents.min(by: { $0.startDate < $1.startDate }) else { return }
        let startOfDay = data.spread.date.startOfDay(calendar: calendar)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        let space = DayTimeCoordinateSpace(
            visibleStart: startOfDay,
            visibleEnd: endOfDay,
            totalHeight: wideTimelineHeight
        )
        timelineScrollPosition = ScrollPosition(y: space.yOffset(for: first.startDate) + 8)
    }
}
