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

// MARK: - DataModel.Task.Status

extension DataModel.Task.Status: EntryStatusButtonRepresentable {
    var iconBaseShape: EntryIconBaseShape { .filledCircle }
    var iconOverlay: EntryIconOverlay? {
        switch self {
        case .open:      return nil
        case .complete:  return .xmark
        case .migrated:  return .arrowRight
        case .cancelled: return .slash
        }
    }
    var statusColor: Color {
        switch self {
        case .open:                          return .primary
        case .complete, .migrated, .cancelled: return .secondary
        }
    }
    var accessibilityLabel: String {
        switch self {
        case .open:      return "Open task"
        case .complete:  return "Complete task"
        case .migrated:  return "Migrated task"
        case .cancelled: return "Cancelled task"
        }
    }
    var isInteractive: Bool {
        switch self {
        case .open, .complete:     return true
        case .migrated, .cancelled: return false
        }
    }
}

// MARK: - DataModel.Note.Status

extension DataModel.Note.Status: EntryStatusButtonRepresentable {
    var iconBaseShape: EntryIconBaseShape { .dash }
    var iconOverlay: EntryIconOverlay? {
        switch self {
        case .active:   return nil
        case .migrated: return .arrowRight
        }
    }
    var statusColor: Color {
        switch self {
        case .active:   return .primary
        case .migrated: return .secondary
        }
    }
    var accessibilityLabel: String {
        switch self {
        case .active:   return "Active note"
        case .migrated: return "Migrated note"
        }
    }
    var isInteractive: Bool { false }
}

// MARK: - DataModel.Event.Status

extension DataModel.Event.Status: EntryStatusButtonRepresentable {
    var iconBaseShape: EntryIconBaseShape { .emptyCircle }
    var iconOverlay: EntryIconOverlay? { nil }
    var statusColor: Color { .primary }
    var accessibilityLabel: String { "Event" }
    var isInteractive: Bool { false }
}
