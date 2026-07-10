import SwiftUI

extension UserInterfaceSizeClass {

    /// The number of day columns to display in a multiday spread.
    ///
    /// Compact width shows one column; regular (iPad or split-view) shows two.
    var multidayColumnCount: Int {
        switch self {
        case .compact: return 1
        case .regular: return 2
        @unknown default: return 1
        }
    }
}
