import SwiftUI

/// `Equatable` conformance for `YearSpreadContentView`.
///
/// SwiftUI uses `==` before calling `body` — if equal, body is skipped and the previous
/// render result is reused. The comparison covers:
///
/// - **spread.id**: Identifies which spread is displayed. Different spread → must re-render.
/// - **scrollToTodayToken**: Incremented when the user triggers a navigate-to-today action.
///   Including it here ensures the body re-runs (and the `.task(id:)` scroll fires) even when
///   the spread hasn't changed but a scroll-to-today was requested.
///
/// Entry data changes propagate via the `@Observable` dependency on `journalManager`
/// tracked inside the body, triggering re-render independently of this comparison.
extension YearSpreadContentView: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.spread.id == rhs.spread.id &&
        lhs.scrollToTodayToken == rhs.scrollToTodayToken
    }
}
