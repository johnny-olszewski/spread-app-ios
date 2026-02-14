import Foundation

/// Protocol defining persistence operations for settings.
///
/// Settings is a singleton row per user — only one row exists.
/// No delete operation; settings are only created or updated.
@MainActor
protocol SettingsRepository: Sendable {
    /// Retrieves the user's settings, if they exist.
    func getSettings() async -> DataModel.Settings?

    /// Saves settings to storage.
    ///
    /// - Parameter settings: The settings to save.
    /// - Throws: An error if the save operation fails.
    func save(_ settings: DataModel.Settings) async throws
}
