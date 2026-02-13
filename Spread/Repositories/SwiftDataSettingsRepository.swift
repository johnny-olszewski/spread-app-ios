import Foundation
import SwiftData

/// SwiftData implementation of SettingsRepository.
///
/// Provides singleton-row persistence for user settings.
/// Enqueues sync mutations on save for push to the server.
@MainActor
final class SwiftDataSettingsRepository: SettingsRepository {

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
    /// - Parameters:
    ///   - modelContainer: The SwiftData container for persistence.
    ///   - deviceId: The unique device identifier for sync.
    ///   - nowProvider: Provider for the current date (injectable for testing).
    init(
        modelContainer: ModelContainer,
        deviceId: UUID = DeviceIdManager.getOrCreateDeviceId(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.modelContainer = modelContainer
        self.deviceId = deviceId
        self.nowProvider = nowProvider
    }

    // MARK: - SettingsRepository

    func getSettings() async -> DataModel.Settings? {
        var descriptor = FetchDescriptor<DataModel.Settings>()
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    func save(_ settings: DataModel.Settings) async throws {
        let operation: SyncOperation = hasStoredSettings(id: settings.id) ? .update : .create
        enqueueSettingsMutation(settings, operation: operation)
        modelContext.insert(settings)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["bujo_mode", "first_weekday"]
    }

    private func enqueueSettingsMutation(_ settings: DataModel.Settings, operation: SyncOperation) {
        let timestamp = nowProvider()
        guard let recordData = SyncSerializer.serializeSettings(
            settings,
            deviceId: deviceId,
            timestamp: timestamp
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.settings.rawValue,
            entityId: settings.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    private func hasStoredSettings(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Settings>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
