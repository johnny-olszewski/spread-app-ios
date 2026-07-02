import SwiftUI

/// `Equatable` conformance for `MultidaySpreadContentView`.
///
/// SwiftUI uses `==` before calling `body` — if equal, body is skipped and the previous
/// render result is reused. The comparison is limited to `spreadID`:
///
/// - **spreadID**: Identifies which spread is displayed. Different spread → must re-render.
///
/// Entry data changes (tasks added/removed) propagate via the `@Observable` dependency
/// on `journalManager` tracked inside `sections(groupedBy:orderedBy:)`, triggering body
/// independently of the struct-level comparison.
extension MultidaySpreadContentView: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.spreadID == rhs.spreadID
    }
}
