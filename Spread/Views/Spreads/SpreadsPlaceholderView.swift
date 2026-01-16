import SwiftUI

/// Placeholder view for the conventional spreads content area.
///
/// Will be replaced with the spread hierarchy in SPRD-25.
struct SpreadsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Spreads", systemImage: "book")
        } description: {
            Text("Journal spreads will appear here.")
        }
    }
}

#Preview {
    SpreadsPlaceholderView()
}
