import SwiftUI

/// The public interface for `EntryListView`.
///
/// Callers create and own this ViewModel, configure it with pre-computed sections and a
/// `configurationMap`, then pass it to `EntryListView`. The view is a pure renderer.
@Observable @MainActor final class EntryListViewModel {

    // MARK: - Data (set by caller)

    /// Pre-computed sections to render. Callers use `EntryListGrouper` to produce these.
    var sections: [EntryList.Section] = []

    /// Type-level rendering configurations. Callers build one `EntryRowView.Configuration` per entry
    /// type and inject it here. `EntryListView` looks up the configuration by `entry.entryType`.
    var configurationMap: [EntryType: EntryRowView.Configuration] = [:]

    /// Calendar used for date formatting in multiday views.
    var calendar: Calendar = .current

    /// Today's date, used for overdue calculations in multiday views.
    var today: Date = Date()

    // MARK: - Callbacks (set by caller)

    var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?

    // MARK: - Computed

    var hasAnyEntries: Bool {
        !sections.allSatisfy { $0.entries.isEmpty }
    }
}
