import SwiftUI

/// A labeled selection row used in entry editing sheets for menu-driven fields (e.g. period, list).
///
/// Shows a secondary-tinted title on the left, a primary-tinted value on the right, and an
/// optional caret-down chevron indicating the row opens a menu. The `isEnabled` flag dims the
/// row when the field is not currently editable (e.g. period/date locked for cancelled tasks).
struct EntrySheetSelectionSummaryRow: View {

    let title: String
    let value: String
    let isEnabled: Bool
    var showsChevron: Bool = true

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
            if showsChevron {
                SpreadTheme.Icon.caretDown.sized(SpreadTheme.IconSize.small)
                    .iconTint(.secondary)
            }
        }
        .font(SpreadTheme.Typography.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill))
        )
        .opacity(isEnabled ? 1 : 0.7)
    }
}

#Preview {
    VStack(spacing: 8) {
        EntrySheetSelectionSummaryRow(title: "Period", value: "Month", isEnabled: true)
        EntrySheetSelectionSummaryRow(title: "List", value: "Work", isEnabled: true)
        EntrySheetSelectionSummaryRow(title: "Date", value: "June 2026", isEnabled: false, showsChevron: false)
        EntrySheetSelectionSummaryRow(title: "List", value: "None", isEnabled: true, showsChevron: true)
    }
    .padding()
}
