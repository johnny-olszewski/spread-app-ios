import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

/// Renders the entry list for a day spread, with optional inline spread creation and navigation.
///
/// In compact width the layout is a single scrollable entry list. Calendar events appear
/// in a dedicated section within the list.
///
/// In regular width the layout is horizontal when events are present:
/// - Leading: a full-height card containing a `ScrollView` with a full-day `DayTimelineView`.
///   All-day events are pinned at the top of the card (outside the scroll). The timed grid
///   scrolls independently so the first event is visible on load.
/// - Trailing: `EntryListView` with its own independent scroll. Calendar events are omitted
///   from the list because the timeline card already surfaces them.
struct DaySpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let journalManager: JournalManager
    let viewModel: SpreadsViewModel
    let syncEngine: SyncEngine?
    var entryListConfiguration: EntryListConfiguration = .init()
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil
    var onSelectSpread: ((DataModel.Spread) -> Void)? = nil
    var onCreateSpread: ((Date) -> Void)? = nil

    @Environment(\.eventKitService) private var eventKitService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var entryListViewModel = EntryListViewModel()

    /// Tracks the scroll position of the timeline card so we can programmatically
    /// jump to the first event on load.
    @State private var timelineScrollPosition = ScrollPosition()

    // MARK: - Layout constants

    /// Scrollable content height for the wide timeline card (full 24-hour day).
    ///
    /// At 1000pt for 24 hours (~42 pt/hour) this always exceeds the available card
    /// height, so the card is always scrollable.
    private let wideTimelineHeight: CGFloat = 1000

    /// `.containerRelativeFrame` parameters for the wide timeline card width.
    ///
    /// Divides the available container width into `wideTimelineColumnCount` equal parts
    /// and sizes the card to `wideTimelineColumnSpan` of them.
    private let wideTimelineColumnCount: Int = 10
    private let wideTimelineColumnSpan: Int = 4

    // MARK: - Derived

    private var autoMigrationFeedback: SpreadAutoMigrationFeedback? {
        guard let feedback = viewModel.autoMigrationFeedback,
              feedback.surfaceSpreadID == spread.id,
              feedback.anchor == .spreadHeader else {
            return nil
        }
        return feedback
    }

    private var showsTimelineCard: Bool {
        horizontalSizeClass.isRegular && !calendarEvents.isEmpty
    }

    private var allDayEvents: [CalendarEvent] {
        calendarEvents.filter { $0.isAllDay }
    }

    private var timedEvents: [CalendarEvent] {
        calendarEvents.filter { !$0.isAllDay }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let dataModel = spreadDataModel {
                if showsTimelineCard {
                    wideLayout(dataModel: dataModel)
                } else {
                    compactLayout(dataModel: dataModel)
                }
            } else {
                ContentUnavailableView {
                    Label("No Data", systemImage: "tray")
                } description: {
                    Text("Unable to load spread data.")
                }
            }
        }
        .task(id: spread.id) {
            if let dataModel = spreadDataModel {
                configureEntryListViewModel(dataModel: dataModel)
                setupConfigurationMap()
            }
            await fetchCalendarEvents()
        }
        .onChange(of: calendarEvents) { _, _ in
            if let dataModel = spreadDataModel { configureEntryListSections(dataModel: dataModel) }
        }
        .onChange(of: showsTimelineCard) { _, _ in
            if let dataModel = spreadDataModel { configureEntryListSections(dataModel: dataModel) }
        }
        .onChange(of: spreadDataModel?.tasks.count ?? 0) { _, _ in
            if let dataModel = spreadDataModel { configureEntryListSections(dataModel: dataModel) }
        }
        .onChange(of: spreadDataModel?.notes.count ?? 0) { _, _ in
            if let dataModel = spreadDataModel { configureEntryListSections(dataModel: dataModel) }
        }
    }

    // MARK: - Layout variants

    /// Regular-width: full-height side-by-side layout with independent scrolls.
    ///
    /// Calendar events are surfaced in the timeline card only; the entry list
    /// receives an empty events array so it does not duplicate them.
    private func wideLayout(dataModel: SpreadDataModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            HStack(alignment: .top, spacing: 0) {
                timelineCard
                EntryListView(viewModel: entryListViewModel)
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// Compact-width: a single scrollable entry list with calendar events in a dedicated section.
    private func compactLayout(dataModel: SpreadDataModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = autoMigrationFeedback?.message {
                SpreadAutoMigrationCueView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            EntryListView(viewModel: entryListViewModel)
        }
    }

    // MARK: - Timeline card

    /// Full-height card for the wide layout.
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
                    height: wideTimelineHeight,
                    calendar: journalManager.calendar
                )
                .scrollIndicators(.hidden)
                .padding(8)
            }
            .scrollPosition($timelineScrollPosition)
            .task(id: calendarEvents.count) {
                scrollToFirstEvent()
            }
        }
        .containerRelativeFrame(.horizontal, count: wideTimelineColumnCount, span: wideTimelineColumnSpan, spacing: 0)
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

    // MARK: - ViewModel configuration

    private func allEntries(dataModel: SpreadDataModel, calendar: Calendar) -> [any Entry] {
        let base = EntryListDisplaySupport.displayedEntries(for: dataModel, calendar: calendar)
        let eventEntries: [DataModel.Event] = showsTimelineCard ? [] : calendarEvents.map { DataModel.Event(calendarEvent: $0) }
        return base + eventEntries
    }

    private func configureEntryListViewModel(dataModel: SpreadDataModel) {
        let cal = journalManager.calendar
        let grouper = EntryListGrouper(
            configuration: entryListConfiguration,
            period: dataModel.spread.period,
            spreadDate: dataModel.spread.date,
            spreadStartDate: dataModel.spread.startDate,
            spreadEndDate: dataModel.spread.endDate,
            calendar: cal
        )
        entryListViewModel.sections = grouper.group(allEntries(dataModel: dataModel, calendar: cal))
        entryListViewModel.calendar = cal
        entryListViewModel.today = journalManager.today
    }

    private func configureEntryListSections(dataModel: SpreadDataModel) {
        let cal = journalManager.calendar
        let grouper = EntryListGrouper(
            configuration: entryListConfiguration,
            period: dataModel.spread.period,
            spreadDate: dataModel.spread.date,
            spreadStartDate: dataModel.spread.startDate,
            spreadEndDate: dataModel.spread.endDate,
            calendar: cal
        )
        entryListViewModel.sections = grouper.group(allEntries(dataModel: dataModel, calendar: cal))
    }

    private func setupConfigurationMap() {
        let calendar = journalManager.calendar
        let today = journalManager.today

        func effectiveStatus(for entry: any Entry) -> DataModel.Task.Status? {
            guard let task = entry as? DataModel.Task else { return nil }
            return task.status
        }

        let taskConfig = EntryRowView.Configuration(
            effectiveTaskStatus: { effectiveStatus(for: $0) },
            isGreyedOut: { entry in
                guard let s = effectiveStatus(for: entry) else { return false }
                return s == .complete || s == .migrated || s == .cancelled
            },
            hasStrikethrough: { entry in effectiveStatus(for: entry) == .cancelled },
            dueDateLabel: { entry in (entry as? DataModel.Task)?.dueDateLabel(calendar: calendar) },
            isDueDateHighlighted: { entry in
                (entry as? DataModel.Task)?.isDueDateHighlighted(today: today, calendar: calendar) ?? false
            },
            onComplete: { entry in
                guard let task = entry as? DataModel.Task else { return }
                Task { @MainActor in
                    let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                    try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                    await syncEngine?.syncNow()
                }
            },
            onEdit: { entry in
                if let task = entry as? DataModel.Task { viewModel.showTaskDetail(task) }
                else if let note = entry as? DataModel.Note { viewModel.showNoteDetail(note) }
            },
            onDelete: { entry in
                guard let task = entry as? DataModel.Task else { return }
                Task { @MainActor in
                    try? await journalManager.deleteTask(task)
                    await syncEngine?.syncNow()
                }
            },
            onTitleCommit: { @MainActor entry, newTitle in
                guard let task = entry as? DataModel.Task else { return }
                try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
                Task { @MainActor in await syncEngine?.syncNow() }
            },
            inlineActionConfiguration: { entry in
                guard let task = entry as? DataModel.Task, task.status == .open else { return nil }
                let options = EntryRowInlineEditSupport.migrationOptions(for: task, today: today, calendar: calendar)
                return EntryRowInlineActionConfiguration(
                    migrationOptions: options,
                    onEditSheet: { viewModel.showTaskDetail(task) },
                    onMigrationSelected: { option in
                        try? await journalManager.updateTaskDateAndPeriod(task, newDate: option.date, newPeriod: option.period)
                        await syncEngine?.syncNow()
                    }
                )
            }
        )

        let noteConfig = EntryRowView.Configuration(
            isGreyedOut: { entry in (entry as? DataModel.Note)?.status == .migrated },
            onEdit: { entry in
                if let note = entry as? DataModel.Note { viewModel.showNoteDetail(note) }
            },
            onDelete: { entry in
                guard let note = entry as? DataModel.Note else { return }
                Task { @MainActor in
                    try? await journalManager.deleteNote(note)
                    await syncEngine?.syncNow()
                }
            }
        )

        let eventConfig = EntryRowView.Configuration(
            isGreyedOut: { entry in
                guard let event = entry as? DataModel.Event else { return false }
                return (event.calendarEvent?.endDate ?? event.endDate) < today
            },
            isEventPast: { entry in
                guard let event = entry as? DataModel.Event else { return false }
                return (event.calendarEvent?.endDate ?? event.endDate) < today
            },
            subtitle: { entry in
                guard let event = entry as? DataModel.Event,
                      let calEvent = event.calendarEvent else { return nil }
                if calEvent.isAllDay {
                    return "All Day · \(calEvent.calendarTitle)"
                } else {
                    let fmt = DateFormatter()
                    fmt.calendar = calendar
                    fmt.timeZone = calendar.timeZone
                    fmt.timeStyle = .short
                    fmt.dateStyle = .none
                    return "\(fmt.string(from: calEvent.startDate))–\(fmt.string(from: calEvent.endDate)) · \(calEvent.calendarTitle)"
                }
            }
        )

        entryListViewModel.configurationMap = [.task: taskConfig, .note: noteConfig, .event: eventConfig]

        entryListViewModel.onAddTask = { @MainActor title, date, period in
            _ = try await journalManager.addTask(title: title, date: date, period: period)
            Task { @MainActor in await syncEngine?.syncNow() }
        }
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
            totalHeight: wideTimelineHeight
        )
        // +8 for the padding around the DayTimelineView inside the ScrollView
        let targetY = coordinateSpace.yOffset(for: firstEvent.startDate) + 8
        timelineScrollPosition = ScrollPosition(y: targetY)
    }
}

// MARK: - UserInterfaceSizeClass

private extension Optional where Wrapped == UserInterfaceSizeClass {
    /// `true` when the size class is `.regular` (wider layout context).
    var isRegular: Bool { self == .regular }
}
