import SwiftUI

/// An inline validation error row shown below a field in entry editing sheets.
///
/// Displays a warning icon alongside the error message in caption text.
struct EntrySheetValidationErrorRow: View {

    let message: String

    var body: some View {
        HStack {
            SpreadTheme.Icon.warning.sized(SpreadTheme.IconSize.medium)
                .iconTint(.orange)
            Text(message)
                .font(SpreadTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        EntrySheetValidationErrorRow(message: "Title is required")
        EntrySheetValidationErrorRow(message: "Please select a multiday spread")
    }
    .padding()
}
