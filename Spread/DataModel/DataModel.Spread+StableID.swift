import Foundation

extension DataModel.Spread {
    /// A stable string identifier for use in scroll positions and pager targeting.
    ///
    /// Derived directly from the spread's UUID — no calendar or JournalManager needed.
    func stableID(calendar: Calendar) -> String {
        "spread.\(id.uuidString.lowercased())"
    }
}
