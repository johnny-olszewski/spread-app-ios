import SwiftUI

/// Design constants for the spread hierarchy tab bar.
///
/// Provides consistent sizing, spacing, and styling values for the
/// hierarchical spread navigation component.
enum SpreadHierarchyDesign {

    // MARK: - Layout

    /// Height of the hierarchy tab bar.
    static let barHeight: CGFloat = 44

    /// Horizontal padding at the edges of the bar.
    static let horizontalPadding: CGFloat = 16

    /// Spacing between tab items.
    static let itemSpacing: CGFloat = 8

    /// Minimum width for a tab item.
    static let minimumItemWidth: CGFloat = 40

    /// Corner radius for tab item backgrounds.
    static let itemCornerRadius: CGFloat = 8

    /// Padding inside each tab item.
    static let itemPadding: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)

    // MARK: - Create Button

    /// Size of the create button.
    static let createButtonSize: CGFloat = 32

    /// Symbol for the create button.
    static let createButtonSymbol: String = "plus"

    // MARK: - Typography

    /// Font for year tab items.
    static let yearFont: Font = .headline

    /// Font for month tab items.
    static let monthFont: Font = .subheadline

    /// Font for day and multiday tab items.
    static let dayFont: Font = .subheadline

    // MARK: - Colors

    /// Background color for selected tab items.
    static let selectedBackground: Color = .accentColor.opacity(0.15)

    /// Background color for unselected tab items.
    static let unselectedBackground: Color = .clear

    /// Foreground color for selected tab items.
    static let selectedForeground: Color = .accentColor

    /// Foreground color for unselected tab items.
    static let unselectedForeground: Color = .secondary

    /// Separator color between hierarchy levels.
    static let separatorColor: Color = .secondary.opacity(0.3)

    // MARK: - Animation

    /// Animation for selection changes.
    static let selectionAnimation: Animation = .easeInOut(duration: 0.2)

    /// Animation for hierarchy expansion.
    static let expansionAnimation: Animation = .easeInOut(duration: 0.25)
}
