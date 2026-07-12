import SwiftUI

/// Shared empty-state presentation for spread content views (SPRD-304).
///
/// Informational only — it points the user at the existing global "+" create
/// affordance rather than offering a create action of its own. Callers supply
/// spread-type-specific guidance via `message`.
struct EntryListEmptyStateView: View {

    /// Spread-type-specific guidance shown under the title.
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("No Entries")
            } icon: {
                SpreadTheme.Icon.tray.sized(SpreadTheme.IconSize.large)
            }
        } description: {
            Text(message)
        }
    }
}

// MARK: - Preview

#Preview("Day") {
    EntryListEmptyStateView(message: "Nothing planned for this day yet. Add a task or note with the + button.")
}

#Preview("Year") {
    EntryListEmptyStateView(message: "Nothing logged in this year yet. Add long-horizon tasks and notes with the + button.")
}
