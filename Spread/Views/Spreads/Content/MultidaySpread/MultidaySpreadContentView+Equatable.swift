import SwiftUI

/// `Equatable` conformance for `MultidaySpreadContentView`.
///
/// SwiftUI uses `==` before calling `body` — if equal, body is skipped and the previous
/// render result is reused. The comparison covers:
///
/// - **spreadID**: Identifies which spread is displayed. Different spread → must re-render.
/// - **scrollToTodayToken**: Incremented when the user triggers a navigate-to-today action.
///   Including it here ensures the body re-runs (and the `.task(id:)` scroll fires) even when
///   the spread hasn't changed but a scroll-to-today was requested.
///
/// Entry data changes (tasks added/removed) propagate via the `@Observable` dependency
/// on `journalManager` tracked inside `sections(groupedBy:orderedBy:)`, triggering body
/// independently of the struct-level comparison.
extension MultidaySpreadContentView: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.spreadID == rhs.spreadID &&
        lhs.scrollToTodayToken == rhs.scrollToTodayToken
    }
}
