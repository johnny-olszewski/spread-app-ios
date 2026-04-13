import Foundation

struct EntryListMigrationConfiguration {
    struct DestinationItem: Identifiable {
        let task: DataModel.Task
        let source: DataModel.Spread

        var id: UUID { task.id }
    }

    let sourceDestinations: [UUID: DataModel.Spread]
    let destinationItems: [DestinationItem]
    let onSourceMigrationConfirmed: (DataModel.Task, DataModel.Spread) -> Void
    let onDestinationMigration: (DestinationItem) -> Void
    let onDestinationMigrationAll: () -> Void
}
