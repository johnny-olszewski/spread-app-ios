import Foundation

/// Stores per-user migration decisions for local data.
enum LocalDataMigrationStore {
    private static let keyPrefix = "local_data_migrated."

    static func hasMigrated(userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: userId))
    }

    static func markMigrated(userId: UUID) {
        UserDefaults.standard.set(true, forKey: key(for: userId))
    }

    private static func key(for userId: UUID) -> String {
        "\(keyPrefix)\(userId.uuidString)"
    }
}
