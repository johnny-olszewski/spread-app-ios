import Foundation

/// Captures temporal inputs at sheet presentation time so editable defaults stay stable
/// even if the shared app clock refreshes while the sheet remains open.
struct PresentedTemporalContext {
    let calendar: Calendar
    let today: Date

    @MainActor
    init(journalManager: JournalManager) {
        calendar = journalManager.calendar
        today = journalManager.today
    }
}
