import SwiftUI

/// A small, secondary-tinted section header label used in entry editing sheets.
struct EntrySheetSectionHeader: View {

    let title: String

    var body: some View {
        Text(title)
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.secondary)
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
