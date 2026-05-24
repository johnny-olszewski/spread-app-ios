import Foundation

/// State for the convenience navigation button rendered in `SpreadHeaderView`.
enum ConvenienceNavigationButtonState: Equatable {
    /// A transient offer to navigate to a newly created spread. Fades after a timeout if not tapped.
    case offer(label: String, destination: DataModel.Spread, source: DataModel.Spread)
    /// A persistent prompt to return to the spread the user navigated from.
    case goBack(source: DataModel.Spread)

    var buttonLabel: String {
        switch self {
        case .offer(let label, _, _): return label
        case .goBack: return "Go Back"
        }
    }

    var systemImage: String {
        switch self {
        case .offer: return "arrow.triangle.swap"
        case .goBack: return "chevron.left"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .offer(let label, _, _): return label
        case .goBack: return "Go back to previous spread"
        }
    }
}
