import SwiftUI

/// A protocol for composable entry status icon views.
///
/// Conforming types represent a single visual layer in a status icon stack.
/// Primitive views (e.g., `TaskCircleIcon`) provide the base shape; decorator
/// views (e.g., `XMarkDecorator`) wrap a base and add an overlay.
///
/// The `iconSize` property propagates unchanged through the decorator chain so
/// every layer shares a consistent layout footprint regardless of how many
/// decorators are composed.
@MainActor
public protocol EntryIconView: View, Sendable {

    /// The natural size of the icon in points.
    ///
    /// Decorators use this to compute overlay canvas size, stroke proportions,
    /// and overhang. All conforming types must expose the same value their base
    /// reports — do not shrink or enlarge it in a decorator.
    var iconSize: CGFloat { get }
}
