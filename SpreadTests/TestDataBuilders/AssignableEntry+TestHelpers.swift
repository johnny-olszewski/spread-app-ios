import Foundation
@testable import Spread

extension AssignableEntry {
    /// Test-only convenience reconstructing the pre-SPRD-254 single `assignments` array's
    /// shape — `migrationHistory` (older entries, in the order they migrated) followed by
    /// `currentAssignments` (live entries, including any newly-appended destination).
    ///
    /// Many existing tests assert on count/first/last against that flat shape; this lets
    /// them keep doing so without having to track which collection each assignment landed
    /// in after the split.
    var allAssignmentsForTesting: [Assignment] {
        migrationHistory + currentAssignments
    }
}
