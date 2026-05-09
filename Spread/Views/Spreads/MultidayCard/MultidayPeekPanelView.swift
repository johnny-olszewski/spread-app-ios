import SwiftUI
import JohnnyOFoundationUI

// MARK: - Data

/// Data bundle for the multiday peek sheet.
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

/// Read-only sheet that lets the user peek at a day spread from a multiday view.
///
/// Shows open tasks followed by calendar events. No editing is allowed.
struct MultidayPeekPanelView: View {
    let data: MultidayPeekData
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

    private var allDayEvents: [CalendarEvent] { data.calendarEvents.filter(\.isAllDay) }
    private var timedEvents: [CalendarEvent] { data.calendarEvents.filter { !$0.isAllDay } }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if openTasks.isEmpty && data.calendarEvents.isEmpty {
                    Text("Nothing scheduled for this day.")
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
                                    .listRowInsets(EdgeInsets(top: SpreadTheme.Spacing.entryRowVertical, leading: 16, bottom: SpreadTheme.Spacing.entryRowVertical, trailing: 16))
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
                                CalendarEventRow(event: event, calendar: calendar)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: SpreadTheme.Spacing.entryRowVertical, leading: 16, bottom: SpreadTheme.Spacing.entryRowVertical, trailing: 16))
                            }
                            ForEach(timedEvents) { event in
                                CalendarEventRow(event: event, calendar: calendar)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: SpreadTheme.Spacing.entryRowVertical, leading: 16, bottom: SpreadTheme.Spacing.entryRowVertical, trailing: 16))
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
    }

    // MARK: - Helpers

    private var panelTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: data.spread.date)
    }
}
