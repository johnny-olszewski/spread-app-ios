import Foundation
import SwiftData

/// SwiftData implementation of SpreadRepository.
///
/// Provides CRUD operations for spreads using SwiftData persistence.
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataSpreadRepository: SpreadRepository {

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private let deviceId: UUID
    private let nowProvider: () -> Date

    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    /// Creates a repository with the specified model container.
    ///
    /// - Parameter modelContainer: The SwiftData container for persistence.
    init(
        modelContainer: ModelContainer,
        deviceId: UUID = DeviceIdManager.getOrCreateDeviceId(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.modelContainer = modelContainer
        self.deviceId = deviceId
        self.nowProvider = nowProvider
    }

    // MARK: - SpreadRepository

    func getSpreads() async -> [DataModel.Spread] {
        // Fetch all spreads, then sort by period (year > month > day > multiday), then date descending
        // SwiftData doesn't support sorting by enum directly, so we sort in memory
        let descriptor = FetchDescriptor<DataModel.Spread>()

        do {
            let spreads = try modelContext.fetch(descriptor)
            return spreads.sorted { lhs, rhs in
                if lhs.period != rhs.period {
                    return periodSortOrder(lhs.period) < periodSortOrder(rhs.period)
                }
                return lhs.date > rhs.date
            }
        } catch {
            return []
        }
    }

    private func periodSortOrder(_ period: Period) -> Int {
        switch period {
        case .year: return 0
        case .month: return 1
        case .day: return 2
        case .multiday: return 3
        }
    }

    func save(_ spread: DataModel.Spread) async throws {
        let operation: SyncOperation = hasStoredSpread(id: spread.id) ? .update : .create
        enqueueSpreadMutation(spread, operation: operation)
        modelContext.insert(spread)
        try modelContext.save()
    }

    func delete(_ spread: DataModel.Spread) async throws {
        enqueueSpreadMutation(spread, operation: .delete)
        modelContext.delete(spread)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["period", "date", "start_date", "end_date"]
    }

    private func enqueueSpreadMutation(_ spread: DataModel.Spread, operation: SyncOperation) {
        let timestamp = nowProvider()
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeSpread(
            spread,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.spread.rawValue,
            entityId: spread.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    private func hasStoredSpread(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Spread>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
