import Foundation

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

    // MARK: - Icon

    /// The tint style applied to the toolbar sync icon.
    enum IconTint {
        /// White / primary — sync is available and healthy.
        case primary
        /// Grey / secondary — sync is unavailable or disabled.
        case secondary
        /// Yellow — an error has occurred.
        case warning
    }

    /// The SF Symbol name for the toolbar sync icon.
    var iconName: String {
        switch self {
        case .idle, .syncing, .synced, .offline, .localOnly:
            "arrow.trianglehead.2.clockwise.rotate.90"
        case .error:
            "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }

    /// The tint to apply to the toolbar icon.
    var iconTint: IconTint {
        switch self {
        case .idle, .syncing, .synced:
            .primary
        case .offline, .localOnly:
            .secondary
        case .error:
            .warning
        }
    }

    /// Whether the toolbar icon should rotate continuously counterclockwise.
    var isRotating: Bool {
        if case .syncing = self { return true }
        return false
    }

    // MARK: - Pull-to-refresh

    /// Short message shown in the pull-to-refresh indicator while the user is pulling.
    var pullIndicatorTitle: String {
        switch self {
        case .idle:
            "Not yet synced"
        case .syncing:
            "Syncing\u{2026}"
        case .synced(let date):
            "Last synced \(date.formatted(.relative(presentation: .named)))"
        case .error:
            "Last sync failed"
        case .offline:
            "Offline"
        case .localOnly:
            "Local only"
        }
    }

    // MARK: - Tooltip

    /// Short message shown in the tooltip when the icon is tapped.
    var tooltipMessage: String {
        switch self {
        case .idle:
            "Not yet synced"
        case .syncing:
            "Syncing\u{2026}"
        case .synced(let date):
            "Last synced \(date.formatted(.relative(presentation: .named)))"
        case .error(let message):
            message
        case .offline:
            "Offline"
        case .localOnly:
            "Local only"
        }
    }

    /// Whether tapping the icon should trigger `syncNow`.
    var shouldTriggerSync: Bool {
        switch self {
        case .idle, .synced, .error:
            true
        case .syncing, .offline, .localOnly:
            false
        }
    }

    // MARK: - Legacy

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

    /// The SF Symbol name for the current status (legacy — prefer `iconName`).
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
