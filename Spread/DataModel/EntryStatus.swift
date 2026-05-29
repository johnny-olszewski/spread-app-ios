import Foundation

/// The status of a journal entry.
///
/// A single unified type covers all entry kinds. Not all cases apply to every type:
/// - Tasks: `open`, `complete`, `migrated`, `cancelled`
/// - Notes: `active`, `migrated`
/// - Events: `upcoming` (computed — not stored)
enum EntryStatus: String, CaseIterable, Codable, Sendable {
    case open
    case active
    case complete
    case migrated
    case cancelled
    case upcoming
}
