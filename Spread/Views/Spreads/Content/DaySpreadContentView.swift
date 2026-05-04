import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// Renders the entry list for a day spread, with optional inline spread creation and navigation.
///
/// On iPhone (compact width) the layout is vertical: an optional fixed-height timeline card
/// appears above the scrollable entry list when events are present.
///
/// On iPad (regular width) the layout is horizontal when events are present:
/// - Leading: a full-height card containing a `ScrollView` with a full-day `DayTimelineView`.
///   All-day events are pinned at the top of the card (outside the scroll). The timed grid
///   scrolls independently so the first event is visible on load.
/// - Trailing: `EntryListView` with its own independent scroll.
struct DaySpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let journalManager: JournalManager
    let viewModel: SpreadsViewModel
    let syncEngine: SyncEngine?
    var entryListConfiguration: EntryListConfiguration = .init(showsMigrationHistory: false)
    var migrationConfiguration: EntryListMigrationConfiguration? = nil
    var onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil
    var onSelectSpread: ((DataModel.Spread) -> Void)? = nil
    var onCreateSpread: ((Date) -> Void)? = nil

    @Environment(\.eventKitService) private var eventKitService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var calendarEvents: [CalendarEvent] = []

    /// Tracks the scroll position of the timeline card so we can programmatically
    /// jump to the first event on load.
    @State private var timelineScrollPosition = ScrollPosition()

    // MARK: - Layout constants

    /// Height of the timeline card on iPhone (compressed smart window).
    private let iPhoneTimelineHeight: CGFloat = 240

    /// Scrollable content height for the iPad timeline card (full 24-hour day).
    ///
    /// At 1000pt for 24 hours (~42 pt/hour) this always exceeds the available card
    /// height on any iPad, so the card is always scrollable.
    private let iPadTimelineHeight: CGFloat = 1000

    /// Fixed width of the timeline card in the iPad horizontal layout.
    private let iPadTimelineWidth: CGFloat = 200

    // MARK: - Derived

    private var autoMigrationFeedback: SpreadAutoMigrationFeedback? {
        guard let feedback = viewModel.autoMigrationFeedback,
              feedback.surfaceSpreadID == spread.id,
              feedback.anchor == .spreadHeader else {
            return nil
        }
        return feedback
    }

    private var useHorizontalLayout: Bool {
        horizontalSizeClass == .regular && !calendarEvents.isEmpty
    }

    private var allDayEvents: [CalendarEvent] {
        calendarEvents.filter { $0.isAllDay }
    }

    private var timedEvents: [CalendarEvent] {
        calendarEvents.filter { !$0.isAllDay }
    }

    // MARK: - Body

    var body: some View {
        if let dataModel = spreadDataModel {
            if useHorizontalLayout {
                iPadLayout(dataModel: dataModel)
            } else {
                iPhoneLayout(dataModel: dataModel)
            }
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }

    // MARK: - Layout variants

    /// iPad: full-height side-by-side layout with independent scrolls.
    private func iPadLayout(dataModel: SpreadDataModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            HStack(alignment: .top, spacing: 0) {
                timelineCard
                entryListView(dataModel: dataModel)
            }
            .frame(maxHeight: .infinity)
        }
        .task(id: spread.id) {
            await fetchCalendarEvents()
        }
    }

    /// iPhone: a vertical stack with an optional timeline card above the entry list.
    private func iPhoneLayout(dataModel: SpreadDataModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            if !calendarEvents.isEmpty {
                DayTimelineView(
                    provider: SpreadDayTimelineProvider(),
                    items: calendarEvents,
                    date: spread.date,
                    height: iPhoneTimelineHeight,
                    calendar: journalManager.calendar
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }

            entryListView(dataModel: dataModel)
        }
        .task(id: spread.id) {
            await fetchCalendarEvents()
        }
    }

    // MARK: - Timeline card

    /// Full-height card for the iPad layout.
    ///
    /// Structure (top to bottom):
    /// 1. All-day events header — non-scrolling, pinned above the timed grid.
    /// 2. Divider — only present when all-day events exist.
    /// 3. Timed event grid — full-day `DayTimelineView` inside a `ScrollView`.
    ///    On load the scroll position jumps to the start of the first timed event.
    private var timelineCard: some View {
        let provider = SpreadDayTimelineProvider()

        return VStack(spacing: 0) {
            if !allDayEvents.isEmpty {
                DayTimelineAllDaySection(items: allDayEvents) { event in
                    provider.allDayItemView(item: event)
                }
                Divider()
            }

            ScrollView {
                DayTimelineView(
                    provider: provider,
                    items: calendarEvents,
                    date: spread.date,
                    visibleStartHour: 0,
                    visibleEndHour: 24,
                    height: iPadTimelineHeight,
                    calendar: journalManager.calendar
                )
                .padding(8)
            }
            .scrollPosition($timelineScrollPosition)
            .task(id: calendarEvents.count) {
                scrollToFirstEvent()
            }
        }
        .frame(width: iPadTimelineWidth)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
        )
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
    }

    // MARK: - Shared subviews

    /// Builds the `EntryListView` with all current callbacks wired up.
    private func entryListView(dataModel: SpreadDataModel) -> some View {
        EntryListView(
            spreadDataModel: dataModel,
            calendar: journalManager.calendar,
            today: journalManager.today,
            configuration: entryListConfiguration,
            calendarEvents: calendarEvents,
            onEdit: { entry in
                if let task = entry as? DataModel.Task { viewModel.showTaskDetail(task) }
                else if let note = entry as? DataModel.Note { viewModel.showNoteDetail(note) }
            },
            onOpenMigratedTask: onOpenMigratedTask,
            onDelete: { entry in
                if let task = entry as? DataModel.Task {
                    Task { @MainActor in
                        try? await journalManager.deleteTask(task)
                        await syncEngine?.syncNow()
                    }
                } else if let note = entry as? DataModel.Note {
                    Task { @MainActor in
                        try? await journalManager.deleteNote(note)
                        await syncEngine?.syncNow()
                    }
                }
            },
            onComplete: { task in
                Task { @MainActor in
                    let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                    try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                    await syncEngine?.syncNow()
                }
            },
            migrationConfiguration: migrationConfiguration,
            onTitleCommit: { @MainActor task, newTitle in
                try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                Task { @MainActor in await syncEngine?.syncNow() }
            },
            onReassignTask: { @MainActor task, date, period in
                try? await journalManager.updateTaskDateAndPeriod(task, newDate: date, newPeriod: period)
                await syncEngine?.syncNow()
            },
            onAddTask: { @MainActor title, date, period in
                _ = try await journalManager.addTask(title: title, date: date, period: period)
                Task { @MainActor in await syncEngine?.syncNow() }
            },
            explicitDaySpreadForDate: explicitDaySpreadForDate,
            onSelectSpread: onSelectSpread,
            onCreateSpread: onCreateSpread,
            onRefresh: {
                guard let engine = syncEngine, engine.status.shouldTriggerSync else { return }
                await engine.syncNow()
            },
            syncStatus: syncEngine?.status
        )
    }

    // MARK: - Private

    private func fetchCalendarEvents() async {
        guard let service = eventKitService else { return }
        if service.authorizationStatus == .notDetermined {
            _ = await service.requestAuthorization()
        }
        guard service.authorizationStatus == .authorized else {
            calendarEvents = []
            return
        }
        let dayStart = spread.date.startOfDay(calendar: journalManager.calendar)
        guard let dayEnd = journalManager.calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
        calendarEvents = service.fetchEvents(from: dayStart, to: dayEnd)
    }

    /// Scrolls the timeline card so the first timed event's start time is near the
    /// top of the visible area. No-ops when there are no timed events.
    private func scrollToFirstEvent() {
        guard let firstEvent = timedEvents.min(by: { $0.startDate < $1.startDate }) else { return }

        let startOfDay = spread.date.startOfDay(calendar: journalManager.calendar)
        guard let endOfDay = journalManager.calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let coordinateSpace = DayTimeCoordinateSpace(
            visibleStart: startOfDay,
            visibleEnd: endOfDay,
            totalHeight: iPadTimelineHeight
        )
        // +8 for the padding around the DayTimelineView inside the ScrollView
        let targetY = coordinateSpace.yOffset(for: firstEvent.startDate) + 8
        timelineScrollPosition = ScrollPosition(y: targetY)
    }
}
