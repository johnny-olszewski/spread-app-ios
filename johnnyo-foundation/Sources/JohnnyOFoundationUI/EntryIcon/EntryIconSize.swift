import SwiftUI

/// Maps a `Font.TextStyle` to a concrete point size for use in entry icon rendering.
///
/// Icon primitives and decorators draw using `CGFloat` point sizes rather than
/// dynamic type tokens. This type centralizes the mapping so the conversion is
/// defined in one place.
public struct EntryIconSize: Sendable {

    /// The icon dimension in points.
    public let points: CGFloat

    /// Creates an icon size from a text style.
    ///
    /// - Parameter textStyle: The semantic text style to map to points.
    public init(_ textStyle: Font.TextStyle) {
        switch textStyle {
        case .largeTitle:  points = 34
        case .title:       points = 28
        case .title2:      points = 22
        case .title3:      points = 20
        case .headline:    points = 17
        case .subheadline: points = 15
        case .body:        points = 17
        case .callout:     points = 16
        case .footnote:    points = 13
        case .caption:     points = 12
        case .caption2:    points = 11
        @unknown default:  points = 12
        }
    }
}
