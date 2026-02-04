import class Foundation.UserDefaults
import struct Foundation.UUID

/// Abstraction for per-user migration state storage.
///
/// Enables dependency injection for testing the auth lifecycle coordinator.
protocol MigrationStoreProtocol: Sendable {
    func hasMigrated(userId: UUID) -> Bool
    func markMigrated(userId: UUID)
}

/// Stores per-user migration decisions for local data in UserDefaults.
struct LocalDataMigrationStore: MigrationStoreProtocol {
    private let keyPrefix = "local_data_migrated."

    func hasMigrated(userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: userId))
    }

    func markMigrated(userId: UUID) {
        UserDefaults.standard.set(true, forKey: key(for: userId))
    }

    private func key(for userId: UUID) -> String {
        "\(keyPrefix)\(userId.uuidString)"
    }
}
