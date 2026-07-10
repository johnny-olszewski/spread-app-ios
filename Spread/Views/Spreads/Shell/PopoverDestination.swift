import SwiftUI

/// Protocol describing the data and view associated with a coordinator-driven popover.
///
/// Each `PopoverDestination` case carries a concrete conforming value.
/// The anchor view reads `arrowEdge` and `attachmentAnchor` when applying
/// `.popover(item:attachmentAnchor:arrowEdge:content:)`.
protocol PopoverContent: Identifiable {
    associatedtype Body: View

    /// The edge of the popover on which the arrow appears.
    var arrowEdge: Edge { get }

    /// Where on the anchor view the popover arrow originates.
    var attachmentAnchor: PopoverAttachmentAnchor { get }

    /// The popover's content view.
    @ViewBuilder var body: Body { get }
}

/// All possible popover presentations managed by `SpreadsCoordinator`.
///
/// Each case carries a concrete value conforming to `PopoverContent`.
/// Anchor views apply `.popover(item:)` on themselves by extracting
/// the relevant case from `coordinator.activePopover`.
enum PopoverDestination: Identifiable {
    case quickAdd(QuickAddPopoverContent)
    case navigatorDaySelection(NavigatorDaySelectionPopoverContent)

    var id: String {
        switch self {
        case .quickAdd(let content): return "quickAdd-\(content.id)"
        case .navigatorDaySelection(let content): return content.id
        }
    }
}
