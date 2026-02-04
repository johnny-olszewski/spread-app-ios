/// Errors specific to sync operations.
enum SyncError: Error {
    /// User is not authenticated.
    case notAuthenticated

    /// Server returned an error.
    case serverError(String)

    /// Failed to serialize mutation data.
    case serializationFailed

    /// A user-friendly message for the error.
    var userMessage: String {
        switch self {
        case .notAuthenticated:
            "Sign in to sync."
        case .serverError(let message):
            "Server error: \(message)"
        case .serializationFailed:
            "Sync data error."
        }
    }
}
