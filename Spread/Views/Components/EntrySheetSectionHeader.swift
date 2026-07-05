import SwiftUI

/// A section header label used in entry editing sheets.
///
/// Uses the Mulish `title3` heading style, matching content-surface section headers
/// ("Year", "Month") per the EntryEditingSheets.md visual redesign.
struct EntrySheetSectionHeader: View {

    let title: String

    var body: some View {
        Text(title)
            .font(SpreadTheme.Typography.title3)
            .foregroundStyle(.primary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        EntrySheetSectionHeader(title: "Title")
        EntrySheetSectionHeader(title: "Metadata")
        EntrySheetSectionHeader(title: "Assignment History")
    }
    .padding()
}
