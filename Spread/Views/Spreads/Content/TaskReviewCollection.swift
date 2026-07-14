import SwiftUI

/// One of the review panel's task collections, describing where a `TaskReviewCardView`'s
/// items come from, how its card is titled and colored, and how its rows respond to taps.
///
/// Case declaration order is the panel's segment order: Inbox, In Flight, Overdue.
enum TaskReviewCollection: String, CaseIterable, Identifiable {
    /// Tasks with no spread assignment, excluding in-flight ones (which belong exclusively
    /// to `.inFlight` even when unassigned — the no-double-appearance rule).
    case inbox
    /// Tasks whose status is `.inFlight` (SPRD-316), regardless of assignment or dates.
    case inFlight
    /// Open tasks whose assignment period has fully passed (SPRD-289 behavior, unchanged).
    case overdue

    var id: String { rawValue }

    /// Stable `EntryList.Section` identifier for this collection's card.
    var sectionID: String { rawValue }

    /// The card's section title and the segment's base label.
    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .inFlight: return "In Flight"
        case .overdue: return "Overdue"
        }
    }

    /// The card's background accent color.
    var cardColor: Color {
        switch self {
        case .inbox: return .gray
        case .inFlight: return .blue
        case .overdue: return .yellow
        }
    }

    /// Message shown in the card area when the collection has no items.
    var emptyStateMessage: String {
        switch self {
        case .inbox: return "No inbox tasks"
        case .inFlight: return "No tasks in flight"
        case .overdue: return "Nothing overdue"
        }
    }

    /// Resolves the collection's live items from the journal.
    @MainActor
    func items(in journalManager: JournalManager) -> [TaskReviewItem] {
        switch self {
        case .inbox:
            return journalManager.reviewInboxTasks.map {
                TaskReviewItem(task: $0, sourceKey: .init(kind: .inbox))
            }
        case .inFlight:
            return journalManager.inFlightTaskItems
        case .overdue:
            return journalManager.overdueTaskItems
        }
    }

    /// The segment label including the collection's live count (e.g. "Inbox 3").
    @MainActor
    func segmentTitle(in journalManager: JournalManager) -> String {
        "\(title) \(items(in: journalManager).count)"
    }

    /// When non-nil, replaces the default row tap (navigate to the source spread, or the
    /// Inbox informational notice). The Inbox segment opens the task's edit sheet instead,
    /// so it can be assigned to a spread in place — inbox triage.
    @MainActor
    func rowTapOverride(context: SpreadPageContext) -> ((any Entry) -> Void)? {
        switch self {
        case .inbox:
            return { entry in
                guard let task = entry as? DataModel.Task else { return }
                context.coordinator.showTaskDetail(task)
            }
        case .inFlight, .overdue:
            return nil
        }
    }
}
