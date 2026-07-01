import SwiftUI

/// `Equatable` conformance for `MonthSpreadContentView`.
///
/// SwiftUI uses `==` before calling `body` — if equal, body is skipped and the previous
/// render result is reused. The comparison is limited to `spread.id`:
///
/// - **spread.id**: Identifies which spread is displayed. Different spread → must re-render.
///
/// Entry data changes propagate via the `@Observable` dependency on `journalManager`
/// tracked inside the body, triggering re-render independently of this comparison.
extension MonthSpreadContentView: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.spread.id == rhs.spread.id
    }
}
