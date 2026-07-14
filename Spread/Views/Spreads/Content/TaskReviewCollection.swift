import SwiftUI

/// One of the review panel's task collections, describing where a `TaskReviewCardView`'s
/// items come from and how its card is titled and colored.
///
/// - TODO: [SPRD-317] Gains `inFlight` and `inbox` cases when the segmented review panel lands.
enum TaskReviewCollection: String, CaseIterable, Identifiable {
    /// Open tasks whose assignment period has fully passed (SPRD-289 behavior, unchanged).
    case overdue

    var id: String { rawValue }

    /// Stable `EntryList.Section` identifier for this collection's card.
    var sectionID: String { rawValue }

    /// The card's section title.
    var title: String {
        switch self {
        case .overdue: return "Overdue"
        }
    }

    /// The card's background accent color.
    var cardColor: Color {
        switch self {
        case .overdue: return .yellow
        }
    }

    /// Resolves the collection's live items from the journal.
    @MainActor
    func items(in journalManager: JournalManager) -> [TaskReviewItem] {
        switch self {
        case .overdue: return journalManager.overdueTaskItems
        }
    }
}
