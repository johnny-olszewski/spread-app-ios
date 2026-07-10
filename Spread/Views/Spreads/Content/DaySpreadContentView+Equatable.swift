import SwiftUI

/// `Equatable` conformance for `DaySpreadContentView`.
///
/// SwiftUI uses `==` before calling `body` — if equal, body is skipped and the previous
/// render result is reused. The comparison is intentionally limited to `spreadID` and
/// `storedHorizontalSizeClass`:
///
/// - **spreadID**: Identifies which spread is displayed. Different spread → must re-render.
/// - **storedHorizontalSizeClass**: Drives the compact/regular layout split. Size class
///   change → must re-render to show/hide the timeline card.
///
/// Entry data changes (tasks added/removed) are NOT gated by this check — they propagate
/// via the `@Observable` dependency on `journalManager` tracked inside `sections(groupedBy:orderedBy:)`,
/// triggering body independently of the struct-level comparison.
extension DaySpreadContentView: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.spreadID == rhs.spreadID
            && lhs.storedHorizontalSizeClass == rhs.storedHorizontalSizeClass
    }
}
