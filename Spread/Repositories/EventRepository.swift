import Foundation

/// Protocol defining persistence operations for events.
///
/// Implementations handle CRUD operations for `DataModel.Event` entities.
/// SwiftData implementation provided in SPRD-57.
@MainActor
protocol EventRepository: Sendable {
    /// Retrieves all events from storage.
    func getEvents() async -> [DataModel.Event]

    /// Retrieves events within a date range.
    ///
    /// - Parameters:
    ///   - startDate: The start of the date range (inclusive).
    ///   - endDate: The end of the date range (inclusive).
    /// - Returns: Events that overlap with the specified date range.
    func getEvents(from startDate: Date, to endDate: Date) async -> [DataModel.Event]

    /// Saves an event to storage.
    ///
    /// - Parameter event: The event to save.
    /// - Throws: An error if the save operation fails.
    func save(_ event: DataModel.Event) async throws

    /// Deletes an event from storage.
    ///
    /// - Parameter event: The event to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ event: DataModel.Event) async throws
}
