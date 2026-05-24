import SwiftUI

/// Renders the entry list for a multiday spread.
struct MultidaySpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel
    let syncEngine: SyncEngine?
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil

    @Environment(JournalManager.self) private var journalManager
    @Environment(SpreadsCoordinator.self) private var coordinator
    @Environment(\.eventKitService) private var eventKitService
    @State private var vm = ViewModel()

    var body: some View {
        grid
            .task(id: spread.id) {
                vm.configure(
                    spread: spread,
                    dataModel: spreadDataModel,
                    journalManager: journalManager,
                    syncEngine: syncEngine,
                    coordinator: coordinator
                )
                await vm.fetchCalendarEvents(for: spread, service: eventKitService, journalManager: journalManager)
            }
            .onChange(of: journalManager.dataVersion) { _, _ in
                vm.refreshSections(spread: spread, dataModel: spreadDataModel, journalManager: journalManager)
            }
            .onChange(of: vm.calendarEvents) { _, _ in
                vm.refreshSections(spread: spread, dataModel: spreadDataModel, journalManager: journalManager)
            }
    }

    private var grid: some View {
        MultidayEntryGridView(
            sections: vm.sections,
            calendar: journalManager.calendar,
            today: journalManager.today,
            onAddTask: vm.onAddTask,
            spread: spread,
            explicitDaySpreadForDate: explicitDaySpreadForDate,
            onSelectSpread: { daySpread in
                coordinator.navigateViaPeek(to: daySpread, from: spread)
            },
            onCreateSpread: { date in
                coordinator.showSpreadCreation(prefill: .init(period: .day, date: date))
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
                let dayEvents = vm.calendarEvents.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
                return SpreadPeekPanelView.Data(spread: daySpread, spreadDataModel: dm, calendarEvents: dayEvents)
            },
            onPeekTaskTap: { daySpread, task in
                coordinator.navigateViaPeek(to: daySpread, from: spread)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    coordinator.showTaskDetail(task)
                }
            }
        ) { entry in
            entryRow(entry: entry)
        }
    }

    @ViewBuilder
    private func entryRow(entry: any Entry) -> some View {
        if let config = vm.configurationMap[entry.entryType] {
            EntryRowView(entry: entry, configuration: config)
        }
    }
}
