import Foundation

/// A lightweight closure-based adapter that bridges coordinator logging to `OSLog`.
///
/// Coordinators accept a `LoggerAdapter` rather than a direct `Logger` reference to keep
/// them decoupled from the specific subsystem/category configuration used by their owner.
/// `JournalManager` injects an adapter backed by its own `Logger` instance.
struct LoggerAdapter {
    /// Called with a formatted message string to emit an info-level log entry.
    let info: (String) -> Void
}
