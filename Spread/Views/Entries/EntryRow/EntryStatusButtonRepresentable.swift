import SwiftUI

// MARK: - Protocol

/// A type that provides all information needed to render an `EntryStatusButton`.
///
/// Conforming to this protocol lets status enums carry their own icon shape, overlay,
/// display color, and accessibility label — eliminating the need for `entryType` branching
/// in any component that renders an entry status.
protocol EntryStatusButtonRepresentable {
    var iconBaseShape: EntryStatusIcon.BaseShape { get }
    var iconOverlay: EntryStatusIcon.OverlayShape? { get }
    var accessibilityLabel: String { get }
    var isInteractive: Bool { get }
}

// MARK: - DataModel.Task.Status

extension DataModel.Task.Status: EntryStatusButtonRepresentable {
    
    var iconBaseShape: EntryStatusIcon.BaseShape {
        switch self {
        case .open:         .filledCircle(nil, nil)
        default:            .filledCircle(.secondary, nil)
        }
    }
    
    var iconOverlay: EntryStatusIcon.OverlayShape? {
        switch self {
        case .open:         nil
        case .complete:     .xmark(.secondary, nil)
        case .migrated:     .arrowRight(.secondary, nil)
        case .cancelled:    .slash(.secondary, nil)
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
    
    var iconBaseShape: EntryStatusIcon.BaseShape { .dash(.primary, nil) }
    
    var iconOverlay: EntryStatusIcon.OverlayShape? {
        switch self {
        case .active:   nil
        case .migrated: .arrowRight(.secondary, nil)
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
    
    var iconBaseShape: EntryStatusIcon.BaseShape { .emptyCircle(.primary, nil) }
    var iconOverlay: EntryStatusIcon.OverlayShape? { nil }
    var accessibilityLabel: String { "Event" }
    var isInteractive: Bool { false }
}
