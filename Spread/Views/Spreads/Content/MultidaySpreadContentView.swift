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
                entryRow(entry, contextualLabel: contextualLabel)
            }
            .task(id: spread.id) {
                configureEntryListViewModel(dataModel: dataModel)
                setupEntryListCallbacks()
                await fetchCalendarEvents()
            }
            .onChange(of: calendarEvents) { _, events in
                entryListViewModel.calendarEvents = events
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

    // MARK: - Row Rendering

    @ViewBuilder
    private func entryRow(_ entry: any Entry, contextualLabel: String?) -> some View {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                taskRow(task, contextualLabel: contextualLabel)
            }
        case .note:
            if let note = entry as? DataModel.Note {
                noteRow(note, contextualLabel: contextualLabel)
            }
        case .event:
            EmptyView()
        }
    }

    private func taskRow(_ task: DataModel.Task, contextualLabel: String?) -> some View {
        let rowStatus = entryListViewModel.rowStatus(for: task)
        return EntryRowView(
            configuration: EntryRowConfiguration(
                entryType: .task,
                taskStatus: rowStatus,
                title: task.title,
                contextualLabel: contextualLabel,
                taskBodyPreview: task.bodyPreview,
                taskPriority: task.priority,
                taskDueDateLabel: task.dueDateLabel(calendar: journalManager.calendar),
                isTaskDueDateHighlighted: task.isDueDateHighlighted(
                    today: journalManager.today,
                    calendar: journalManager.calendar
                ),
                tagChips: task.tags.sorted { $0.name < $1.name }.map { (title: $0.name, color: $0.chipColor) }
            ),
            iconConfiguration: StatusIconConfiguration(entryType: .task, taskStatus: rowStatus),
            onComplete: rowStatus == .open ? { entryListViewModel.onComplete?(task) } : nil,
            onEdit: { entryListViewModel.onEdit?(task) },
            onDelete: { entryListViewModel.onDelete?(task) },
            inlineActionConfiguration: rowStatus == .open
                ? entryListViewModel.inlineActionConfiguration(for: task)
                : nil,
            isInlineActive: entryListViewModel.activeInlineTaskID == task.id,
            onBeginInlineEditing: { entryListViewModel.activeInlineTaskID = task.id },
            onEndInlineEditing: {
                if entryListViewModel.activeInlineTaskID == task.id {
                    entryListViewModel.activeInlineTaskID = nil
                }
            }
        )
    }

    private func noteRow(_ note: DataModel.Note, contextualLabel: String?) -> some View {
        EntryRowView(
            note: note,
            contextualLabel: contextualLabel,
            onEdit: { entryListViewModel.onEdit?(note) },
            onDelete: { entryListViewModel.onDelete?(note) }
        )
    }

    // MARK: - ViewModel Configuration

    private func configureEntryListViewModel(dataModel: SpreadDataModel) {
        let cal = journalManager.calendar
        let entries = EntryListDisplaySupport.displayedEntries(
            for: dataModel,
            configuration: entryListConfiguration,
            calendar: cal
        )
        let grouper = EntryListGrouper(
            configuration: entryListConfiguration,
            period: dataModel.spread.period,
            spreadDate: dataModel.spread.date,
            spreadStartDate: dataModel.spread.startDate,
            spreadEndDate: dataModel.spread.endDate,
            calendar: cal
        )
        entryListViewModel.sections = grouper.group(entries)
        entryListViewModel.calendar = cal
        entryListViewModel.today = journalManager.today
        entryListViewModel.spread = dataModel.spread
        entryListViewModel.calendarEvents = calendarEvents
        entryListViewModel.syncStatus = syncEngine?.status
    }

    private func configureEntryListSections(dataModel: SpreadDataModel) {
        let cal = journalManager.calendar
        let entries = EntryListDisplaySupport.displayedEntries(
            for: dataModel,
            configuration: entryListConfiguration,
            calendar: cal
        )
        let grouper = EntryListGrouper(
            configuration: entryListConfiguration,
            period: dataModel.spread.period,
            spreadDate: dataModel.spread.date,
            spreadStartDate: dataModel.spread.startDate,
            spreadEndDate: dataModel.spread.endDate,
            calendar: cal
        )
        entryListViewModel.sections = grouper.group(entries)
    }

    private func setupEntryListCallbacks() {
        entryListViewModel.onEdit = { entry in
            if let task = entry as? DataModel.Task { viewModel.showTaskDetail(task) }
            else if let note = entry as? DataModel.Note { viewModel.showNoteDetail(note) }
        }
        entryListViewModel.onDelete = { entry in
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
        }
        entryListViewModel.onComplete = { task in
            Task { @MainActor in
                let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                await syncEngine?.syncNow()
            }
        }
        entryListViewModel.onTitleCommit = { @MainActor task, newTitle in
            try? await journalManager.updateTaskTitle(task, newTitle: newTitle)
            Task { @MainActor in await syncEngine?.syncNow() }
        }
        entryListViewModel.onReassignTask = { @MainActor task, date, period in
            try? await journalManager.updateTaskDateAndPeriod(task, newDate: date, newPeriod: period)
            await syncEngine?.syncNow()
        }
        entryListViewModel.onAddTask = { @MainActor title, date, period in
            _ = try await journalManager.addTask(title: title, date: date, period: period)
            Task { @MainActor in await syncEngine?.syncNow() }
        }
        entryListViewModel.onRefresh = {
            guard let engine = syncEngine, engine.status.shouldTriggerSync else { return }
            await engine.syncNow()
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
