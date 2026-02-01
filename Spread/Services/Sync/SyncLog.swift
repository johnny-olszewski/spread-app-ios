import struct Foundation.Date
import struct Foundation.UUID

/// A single entry in the sync log.
struct SyncLogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: Level
    let message: String

    /// Log severity levels.
    enum Level: String, Sendable {
        case info
        case warning
        case error
    }

    init(id: UUID = UUID(), timestamp: Date = .now, level: Level, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

/// A capped in-memory log of sync events.
///
/// Maintains a fixed-size buffer of recent sync log entries for debugging.
/// Entries beyond the cap are discarded (oldest first). The log does not
/// persist across app launches.
@MainActor
final class SyncLog {

    /// Maximum number of log entries to retain.
    private let maxEntries: Int

    /// The log entries, newest last.
    private(set) var entries: [SyncLogEntry] = []

    init(maxEntries: Int = 50) {
        self.maxEntries = maxEntries
    }

    /// Appends an info-level entry.
    func info(_ message: String) {
        append(SyncLogEntry(level: .info, message: message))
    }

    /// Appends a warning-level entry.
    func warning(_ message: String) {
        append(SyncLogEntry(level: .warning, message: message))
    }

    /// Appends an error-level entry.
    func error(_ message: String) {
        append(SyncLogEntry(level: .error, message: message))
    }

    /// Removes all log entries.
    func clear() {
        entries.removeAll()
    }

    // MARK: - Private

    private func append(_ entry: SyncLogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
