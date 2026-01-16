import SwiftUI

/// Placeholder view for the inbox sheet.
///
/// Will be replaced with actual inbox view in SPRD-31.
struct InboxPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Inbox", systemImage: "tray")
            } description: {
                Text("Unassigned entries will appear here.")
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    InboxPlaceholderView()
}
