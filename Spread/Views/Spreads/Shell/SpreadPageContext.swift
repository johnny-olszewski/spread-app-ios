import Foundation

/// Dependencies and helpers bundled for a single spread page.
///
/// Constructed once at the page-assembly boundary (`SpreadPageContentView`) and passed
/// explicitly into period-specific content views, removing their need to read
/// `JournalManager`, `SpreadsCoordinator`, `SyncEngine`, and `EventKitService` from
/// the SwiftUI environment.
@MainActor
struct SpreadPageContext {
    let journalManager: JournalManager
    let coordinator: SpreadsCoordinator
    let syncEngine: SyncEngine?
    let eventKitService: (any EventKitService)?
    let calendarEventService: any CalendarEventService

    /// Calendar derived from the journal manager's locale and first-weekday settings.
    var calendar: Calendar {
        journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
    }
}
