/// Errors specific to sync operations.
enum SyncError: Error {
    /// User is not authenticated.
    case notAuthenticated

    /// Server returned an error.
    case serverError(String)

    /// Failed to serialize mutation data.
    case serializationFailed

    /// A batch merge RPC's result array length didn't match the number of rows sent.
    case batchResultCountMismatch

    /// A user-friendly message for the error.
    var userMessage: String {
        switch self {
        case .notAuthenticated:
            "Sign in to sync."
        case .serverError(let message):
            "Server error: \(message)"
        case .serializationFailed:
            "Sync data error."
        case .batchResultCountMismatch:
            "Sync failed. Will retry."
        }
    }
}
