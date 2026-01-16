import SwiftUI

/// Placeholder view for the collections content area.
///
/// Will be replaced with actual collections list in SPRD-40.
struct CollectionsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Collections", systemImage: "folder")
        } description: {
            Text("Plain text pages will appear here.")
        }
    }
}

#Preview {
    CollectionsPlaceholderView()
}
