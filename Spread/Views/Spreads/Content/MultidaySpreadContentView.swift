import SwiftUI

/// Renders the entry list for a multiday spread.
struct MultidaySpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let journalManager: JournalManager
    let viewModel: SpreadsViewModel
    let syncEngine: SyncEngine?
    var entryListConfiguration: EntryListConfiguration = .init(showsMigrationHistory: false)
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil

    @Environment(\.eventKitService) private var eventKitService
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var entryListViewModel = EntryListViewModel()

    var body: some View {
        if let dataModel = spreadDataModel {
            grid
                .task(id: spread.id) {
                    configureEntryListViewModel(dataModel: dataModel)
                    setupConfigurationMap()
                    await fetchCalendarEvents()
                }
                .onChange(of: calendarEvents) { _, _ in
                    if let dataModel = spreadDataModel { configureEntryListSections(dataModel: dataModel) }
                }
                .onChange(of: spreadDataModel?.tasks.count ?? 0) { _, _ in
                    if let dataModel = spreadDataModel { configureEntryListSections(dataModel: dataModel) }
                }
                .onChange(of: spreadDataModel?.notes.count ?? 0) { _, _ in
                    if let dataModel = spreadDataModel { configureEntryListSections(dataModel: dataModel) }
                }
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }

    private var grid: some View {
        MultidayEntryGridView(
            viewModel: entryListViewModel,
            spread: spread,
            explicitDaySpreadForDate: explicitDaySpreadForDate,
            onSelectSpread: { daySpread in
                viewModel.navigateViaPeek(to: daySpread, from: spread)
            },
            onCreateSpread: { date in
                viewModel.showSpreadCreation(prefill: .init(period: .day, date: date))
            },
            openTaskCountForDaySpread: { daySpread in
                let key = SpreadDataModelKey(spread: daySpread, calendar: journalManager.calendar)
                return journalManager.dataModel[key: key]?.tasks.filter { $0.status == .open }.count ?? 0
            },
            peekDataForDaySpread: { daySpread in
                let key = SpreadDataModelKey(spread: daySpread, calendar: journalManager.calendar)
                guard let dm = journalManager.dataModel[key: key] else { return nil }
                let dayStart = daySpread.date.startOfDay(calendar: journalManager.calendar)
                guard let dayEnd = journalManager.calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                    return nil
                }
                let dayEvents = calendarEvents.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
                return MultidayPeekData(spread: daySpread, spreadDataModel: dm, calendarEvents: dayEvents)
            },
            onPeekTaskTap: { daySpread, task in
                viewModel.navigateViaPeek(to: daySpread, from: spread)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    viewModel.showTaskDetail(task)
                }
            }
        ) { entry, contextualLabel in
            entryRow(entry: entry, contextualLabel: contextualLabel)
        }
    }

    @ViewBuilder
    private func entryRow(entry: any Entry, contextualLabel: String?) -> some View {
        if let config = entryListViewModel.configurationMap[entry.entryType] {
            EntryRowView(entry: entry, configuration: config, contextualLabel: contextualLabel)
        }
    }

    // MARK: - ViewModel Configuration

    private func allEntries(dataModel: SpreadDataModel, calendar: Calendar) -> [any Entry] {
        let base = EntryListDisplaySupport.displayedEntries(
            for: dataModel,
            configuration: entryListConfiguration,
            calendar: calendar
        )
        let eventEntries: [DataModel.Event] = calendarEvents.map { DataModel.Event(calendarEvent: $0) }
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
        let spread = spread

        let formatter = MigrationDestinationFormatter(calendar: calendar)

        let taskConfig = EntryRowConfiguration(
            effectiveTaskStatus: { $0.displayTaskStatus },
            isGreyedOut: { entry in
                guard let s = entry.displayTaskStatus else { return false }
                return s == .complete || s == .migrated || s == .cancelled
            },
            hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
            migrationDestination: { entry in
                guard let task = entry as? DataModel.Task else { return nil }
                return formatter.destination(for: task, from: spread)
            },
            showsMigrationBadge: { entry in
                guard let task = entry as? DataModel.Task,
                      entry.displayTaskStatus == .migrated else { return false }
                return formatter.destination(for: task, from: spread) != nil
            },
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

        let noteConfig = EntryRowConfiguration(
            isGreyedOut: { entry in (entry as? DataModel.Note)?.status == .migrated },
            migrationDestination: { entry in
                guard let note = entry as? DataModel.Note else { return nil }
                return formatter.destination(for: note, from: spread)
            },
            showsMigrationBadge: { entry in
                guard let note = entry as? DataModel.Note, note.status == .migrated else { return false }
                return formatter.destination(for: note, from: spread) != nil
            },
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

        let eventConfig = EntryRowConfiguration(
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
        guard let service = eventKitService,
              let startDate = spread.startDate,
              let endDate = spread.endDate else { return }
        if service.authorizationStatus == .notDetermined {
            _ = await service.requestAuthorization()
        }
        guard service.authorizationStatus == .authorized else {
            calendarEvents = []
            return
        }
        let cal = journalManager.calendar
        let start = startDate.startOfDay(calendar: cal)
        guard let end = cal.date(byAdding: .day, value: 1, to: endDate.startOfDay(calendar: cal)) else { return }
        calendarEvents = service.fetchEvents(from: start, to: end)
    }
}
