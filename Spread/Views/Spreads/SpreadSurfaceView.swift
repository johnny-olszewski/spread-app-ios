import SwiftUI

struct SpreadSurfaceView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let calendar: Calendar
    let today: Date
    let headerNavigatorModel: SpreadHeaderNavigatorModel
    var entryListConfiguration: EntryListConfiguration = .init()

    var onEditTask: ((DataModel.Task) -> Void)?
    var onEditNote: ((DataModel.Note) -> Void)?
    var onDeleteTask: ((DataModel.Task) -> Void)?
    var onDeleteNote: ((DataModel.Note) -> Void)?
    var onCompleteTask: ((DataModel.Task) -> Void)?
    var onUpdateTaskTitle: (@MainActor (DataModel.Task, String) async -> Void)?
    var onReassignTask: (@MainActor (DataModel.Task, Date, Period) async -> Void)?
    var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?
    var onOpenMigratedTask: ((DataModel.Task) -> Void)? = nil
    var onRefresh: (() async -> Void)?
    var syncStatus: SyncStatus?
    var migrationConfiguration: EntryListMigrationConfiguration?
    var onSelectSpread: ((SpreadHeaderNavigatorModel.Selection) -> Void)?
    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)?
    var onCreateSpread: ((Date) -> Void)?

    @State private var isShowingNavigator = false

    var body: some View {
        VStack(spacing: 0) {
            SpreadHeaderView(
                configuration: SpreadHeaderConfiguration(
                    spread: spread,
                    calendar: calendar,
                    taskCount: spreadDataModel?.tasks.count ?? 0,
                    noteCount: spreadDataModel?.notes.count ?? 0
                ),
                isShowingNavigator: $isShowingNavigator,
                navigatorModel: headerNavigatorModel,
                currentSpread: spread,
                onNavigatorSelect: onSelectSpread
            )

            entryList
        }
    }

    @ViewBuilder
    private var entryList: some View {
        if let dataModel = spreadDataModel {
            EntryListView(
                spreadDataModel: dataModel,
                calendar: calendar,
                today: today,
                configuration: entryListConfiguration,
                onEdit: { entry in
                    if let task = entry as? DataModel.Task {
                        onEditTask?(task)
                    } else if let note = entry as? DataModel.Note {
                        onEditNote?(note)
                    }
                },
                onOpenMigratedTask: { task in
                    onOpenMigratedTask?(task)
                },
                onDelete: { entry in
                    if let task = entry as? DataModel.Task {
                        onDeleteTask?(task)
                    } else if let note = entry as? DataModel.Note {
                        onDeleteNote?(note)
                    }
                },
                onComplete: { task in
                    onCompleteTask?(task)
                },
                onMigrate: nil,
                migrationConfiguration: migrationConfiguration,
                onTitleCommit: { @MainActor task, newTitle in
                    await onUpdateTaskTitle?(task, newTitle)
                },
                onReassignTask: { @MainActor task, date, period in
                    await onReassignTask?(task, date, period)
                },
                onAddTask: { @MainActor title, date, period in
                    try await onAddTask?(title, date, period)
                },
                explicitDaySpreadForDate: explicitDaySpreadForDate,
                onSelectSpread: { spread in
                    onSelectSpread?(.conventional(spread))
                },
                onCreateSpread: onCreateSpread,
                onRefresh: onRefresh,
                syncStatus: syncStatus
            )
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }
}
