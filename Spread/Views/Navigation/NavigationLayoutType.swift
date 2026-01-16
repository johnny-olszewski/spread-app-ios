import SwiftUI

/// The type of navigation layout to use based on device/size class.
///
/// Determines whether to show sidebar navigation (iPad) or tab-based
/// navigation (iPhone) based on the horizontal size class.
enum NavigationLayoutType: Sendable {
    /// Sidebar navigation for iPad (regular width).
    case sidebar

    /// Tab bar navigation for iPhone (compact width).
    case tabBar

    /// Determines the appropriate layout type for the given horizontal size class.
    ///
    /// - Parameter sizeClass: The horizontal size class from the environment.
    /// - Returns: The appropriate navigation layout type.
    static func forSizeClass(_ sizeClass: UserInterfaceSizeClass?) -> NavigationLayoutType {
        switch sizeClass {
        case .regular:
            return .sidebar
        case .compact, .none:
            return .tabBar
        @unknown default:
            return .tabBar
        }
    }
}
