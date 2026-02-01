import struct Foundation.Date

/// The current state of the sync engine.
enum SyncStatus: Equatable, Sendable {
    /// No sync activity. Initial state or between syncs.
    case idle

    /// A sync operation is in progress.
    case syncing

    /// Last sync completed successfully.
    case synced(Date)

    /// Last sync failed with an error message.
    case error(String)

    /// Device is offline; sync is paused.
    case offline

    /// Sync is disabled for this environment (e.g., localhost mode).
    case localOnly

    /// A short display string for the current status.
    var displayText: String {
        switch self {
        case .idle:
            "Not synced"
        case .syncing:
            "Syncing..."
        case .synced(let date):
            "Synced \(date.formatted(.relative(presentation: .named)))"
        case .error(let message):
            message
        case .offline:
            "Offline"
        case .localOnly:
            "Local only"
        }
    }

    /// The SF Symbol name for the current status.
    var systemImage: String {
        switch self {
        case .idle:
            "arrow.triangle.2.circlepath"
        case .syncing:
            "arrow.triangle.2.circlepath"
        case .synced:
            "checkmark.icloud"
        case .error:
            "exclamationmark.icloud"
        case .offline:
            "icloud.slash"
        case .localOnly:
            "internaldrive"
        }
    }

    /// Whether the status represents an error state.
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
