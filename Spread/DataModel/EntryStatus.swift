import Foundation

/// The status of a journal entry.
///
/// A single unified type covers all entry kinds. Not all cases apply to every type:
/// - Tasks: `open`, `inFlight`, `complete`, `migrated`, `cancelled`
/// - Notes: `active`, `migrated`
/// - Events: `upcoming` (computed — not stored)
enum EntryStatus: String, CaseIterable, Codable, Sendable {
    case open
    case active
    case complete
    case migrated
    case cancelled
    /// Task-only status: the user's part is done and the task is waiting on an external
    /// process to complete it. Not yet reachable from any UI. [SPRD-316]
    case inFlight = "in_flight"
    case upcoming

    var displayName: String {
        switch self {
        case .open:      return "Open"
        case .active:    return "Active"
        case .complete:  return "Complete"
        case .migrated:  return "Migrated"
        case .cancelled: return "Cancelled"
        case .inFlight:  return "In Flight"
        case .upcoming:  return "Upcoming"
        }
    }
    
    func rotate(in options: [EntryStatus]) -> EntryStatus {
        
        guard !options.isEmpty else {
            return self
        }
        
        guard let indexOfSelf = options.firstIndex(of: self) else {
            return options[0]
        }
        
        guard (indexOfSelf + 1) != options.count else {
            return options[0]
        }
        
        return options[indexOfSelf + 1]
    }
    
    var inlineChangesAreLocked: Bool {
        switch self {
        case .open, .active, .inFlight: false
        default: true
        }
    }
}
