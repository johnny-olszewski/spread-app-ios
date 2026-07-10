import Foundation

/// Validation errors shared across all entry creation and editing flows.
enum EntryCreationError: Equatable {
    /// The title is empty or whitespace-only.
    case emptyTitle

    /// The selected date is in the past.
    case pastDate

    /// Multiday assignment requires choosing an existing multiday spread.
    case missingMultidaySpread

    /// User-facing error message.
    var message: String {
        switch self {
        case .emptyTitle:
            return "Title is required"
        case .pastDate:
            return "You can only use present or future dates"
        case .missingMultidaySpread:
            return "Select an existing multiday spread"
        }
    }
}

/// Result of entry creation or editing validation.
struct EntryCreationResult {
    /// Whether the operation is valid.
    let isValid: Bool

    /// The error if the operation is not valid.
    let error: EntryCreationError?

    /// Creates a valid result.
    static var valid: EntryCreationResult {
        EntryCreationResult(isValid: true, error: nil)
    }

    /// Creates an invalid result with the given error.
    static func invalid(_ error: EntryCreationError) -> EntryCreationResult {
        EntryCreationResult(isValid: false, error: error)
    }
}
