import SwiftUI
import JohnnyOFoundationUI

// MARK: - View

/// Read-only sheet that lets the user peek at a spread from a parent view.
///
/// Shows open tasks and, when provided, calendar events. No editing is allowed.
struct SpreadPeekPanelView: View {

    // MARK: - Data

    struct Data: Identifiable, Equatable {
        let spread: DataModel.Spread
        let spreadDataModel: SpreadDataModel
        /// `nil` suppresses the Events section (e.g. month spread peek from year view).
        let calendarEvents: [CalendarEvent]?

        var id: UUID { spread.id }

        static func == (lhs: Data, rhs: Data) -> Bool {
            lhs.spread.id == rhs.spread.id
        }
    }

    // MARK: - Properties

    let data: Data
    let calendar: Calendar
    let today: Date
    let onClose: () -> Void
    let onNavigate: (DataModel.Spread) -> Void
    /// When non-nil, task rows become tappable and invoke this callback.
    let onTaskTap: ((DataModel.Task) -> Void)?

    @Environment(\.dismiss) private var dismiss

    private var openTasks: [DataModel.Task] {
        data.spreadDataModel.tasks.filter { $0.status == .open }
    }

    private var allDayEvents: [CalendarEvent] { data.calendarEvents?.filter(\.isAllDay) ?? [] }
    private var timedEvents: [CalendarEvent] { data.calendarEvents?.filter { !$0.isAllDay } ?? [] }
    private var hasEvents: Bool { !(data.calendarEvents?.isEmpty ?? true) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if openTasks.isEmpty && !hasEvents {
                    Text("Nothing scheduled.")
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    if !openTasks.isEmpty {
                        Section("Tasks") {
                            ForEach(openTasks, id: \.id) { task in
                                peekTaskRow(task)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(
                                        top: SpreadTheme.Spacing.entryRowVertical,
                                        leading: 16,
                                        bottom: SpreadTheme.Spacing.entryRowVertical,
                                        trailing: 16
                                    ))
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTaskTap?(task) }
                                    .overlay(alignment: .trailing) {
                                        if onTaskTap != nil {
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                                .padding(.trailing, 4)
                                        }
                                    }
                            }
                        }
                    }

                    if !timedEvents.isEmpty || !allDayEvents.isEmpty {
                        Section("Events") {
                            ForEach(allDayEvents) { event in
                                peekCalendarEventRow(event)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(
                                        top: SpreadTheme.Spacing.entryRowVertical,
                                        leading: 16,
                                        bottom: SpreadTheme.Spacing.entryRowVertical,
                                        trailing: 16
                                    ))
                            }
                            ForEach(timedEvents) { event in
                                peekCalendarEventRow(event)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(
                                        top: SpreadTheme.Spacing.entryRowVertical,
                                        leading: 16,
                                        bottom: SpreadTheme.Spacing.entryRowVertical,
                                        trailing: 16
                                    ))
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle(panelTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { onClose(); dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close preview")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { onNavigate(data.spread) }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(SpreadTheme.Accent.todaySelectedEmphasis)
                    }
                    .accessibilityLabel("Open spread")
                }
            }
        }
    }

    // MARK: - Rows

    private func peekCalendarEventRow(_ event: CalendarEvent) -> some View {
        let subtitle: String
        if event.isAllDay {
            subtitle = "All Day · \(event.calendarTitle)"
        } else {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            subtitle = "\(start)–\(end) · \(event.calendarTitle)"
        }
        let entry = DataModel.Event(calendarEvent: event)
        let config = EntryRowView.Configuration(
            subtitle: { _ in subtitle }
        )
        return EntryRowView(entry: entry, configuration: config)
    }

    private func peekTaskRow(_ task: DataModel.Task) -> some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            EntryStatusIcon(baseShape: EntryStatus.open.iconBaseShape(for: .task), overlay: EntryStatus.open.iconOverlay)
                .frame(width: 24, height: 24)
            Text(task.title)
                .font(SpreadTheme.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private var panelTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = data.spread.period == .month ? "MMMM yyyy" : "EEEE, MMM d"
        return formatter.string(from: data.spread.date)
    }
}
