import SwiftUI

/// Renders the entry list for a multiday spread.
struct MultidaySpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let context: SpreadPageContext
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil

    @State private var calendarEvents: [CalendarEvent] = []

    // MARK: - Computed

    private var sections: [EntryList.Section] {
        let cal = context.calendar
        let base = EntryListDisplaySupport.displayedEntries(for: spreadDataModel, calendar: cal)
        let eventEntries: [DataModel.Event] = calendarEvents.map { DataModel.Event(calendarEvent: $0) }
        return Self.makeSections(
            from: base + eventEntries,
            spreadDate: spreadDataModel.spread.date,
            startDate: spreadDataModel.spread.startDate ?? spreadDataModel.spread.date,
            endDate: spreadDataModel.spread.endDate ?? spreadDataModel.spread.date,
            calendar: cal
        )
    }

    private var configurationMap: [EntryType: EntryRowView.Configuration] {
        [
            .task: .standardTaskConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            ),
            .note: .standardNoteConfig(
                journalManager: context.journalManager,
                syncEngine: context.syncEngine,
                coordinator: context.coordinator
            ),
            .event: .standardEventConfig(journalManager: context.journalManager)
        ]
    }

    private var onAddTask: (@MainActor (String, Date, Period) async throws -> Void) {
        let jm = context.journalManager
        let se = context.syncEngine
        return { @MainActor title, date, period in
            _ = try await jm.addTask(title: title, date: date, period: period)
            Task { @MainActor in await se?.syncNow() }
        }
    }

    // MARK: - Body

    var body: some View {
        grid
            .task(id: spread.id) {
                calendarEvents = await context.calendarEventService.fetchEvents(
                    for: spread,
                    calendar: context.journalManager.calendar
                )
            }
    }

    private var grid: some View {
        MultidayEntryGridView(
            sections: sections,
            calendar: context.journalManager.calendar,
            today: context.journalManager.today,
            onAddTask: onAddTask,
            spread: spread,
            explicitDaySpreadForDate: explicitDaySpreadForDate,
            onSelectSpread: { daySpread in
                context.coordinator.navigateViaPeek(to: daySpread, from: spread)
            },
            onCreateSpread: { date in
                context.coordinator.showSpreadCreation(prefill: .init(period: .day, date: date))
            },
            openTaskCountForDaySpread: { daySpread in
                let key = SpreadDataModelKey(spread: daySpread, calendar: context.journalManager.calendar)
                return context.journalManager.dataModel[key: key]?.tasks.filter { $0.status == .open }.count ?? 0
            },
            peekDataForDaySpread: { daySpread in
                let key = SpreadDataModelKey(spread: daySpread, calendar: context.journalManager.calendar)
                guard let dm = context.journalManager.dataModel[key: key] else { return nil }
                let dayStart = daySpread.date.startOfDay(calendar: context.journalManager.calendar)
                guard let dayEnd = context.journalManager.calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                    return nil
                }
                let dayEvents = calendarEvents.filter {
                    $0.startDate < dayEnd && $0.endDate > dayStart
                }
                return SpreadPeekPanelView.Data(spread: daySpread, spreadDataModel: dm, calendarEvents: dayEvents)
            },
            onPeekTaskTap: { daySpread, task in
                context.coordinator.navigateViaPeek(to: daySpread, from: spread)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    context.coordinator.showTaskDetail(task)
                }
            }
        ) { entry in
            entryRow(entry: entry)
        }
    }

    @ViewBuilder
    private func entryRow(entry: any Entry) -> some View {
        if let config = configurationMap[entry.entryType] {
            EntryRowView(entry: entry, configuration: config)
        }
    }
}
