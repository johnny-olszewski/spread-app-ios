import SwiftUI

// MARK: - Supporting Enums

/// The base icon shape drawn for an entry status.
enum EntryIconBaseShape {
    case filledCircle
    case emptyCircle
    case dash
}

/// The overlay indicator drawn on top of the base icon.
enum EntryIconOverlay {
    case xmark
    case arrowRight
    case slash
}

// MARK: - Protocol

/// A type that provides all information needed to render an `EntryStatusButton`.
///
/// Conforming to this protocol lets status enums carry their own icon shape, overlay,
/// display color, and accessibility label — eliminating the need for `entryType` branching
/// in any component that renders an entry status.
protocol EntryStatusButtonRepresentable {
    var iconBaseShape: EntryIconBaseShape { get }
    var iconOverlay: EntryIconOverlay? { get }
    var statusColor: Color { get }
    var accessibilityLabel: String { get }
    var isInteractive: Bool { get }
}

// MARK: - DataModel.Event.Status

extension DataModel.Event.Status: EntryStatusButtonRepresentable {
    var iconBaseShape: EntryIconBaseShape { .emptyCircle }
    var iconOverlay: EntryIconOverlay? { nil }
    var statusColor: Color { .primary }
    var accessibilityLabel: String { "Event" }
    var isInteractive: Bool { false }
}
