import SwiftUI

/// Placeholder view for the traditional navigation content area.
///
/// Will be replaced with traditional mode views in SPRD-35+.
struct TraditionalSpreadsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Traditional", systemImage: "calendar")
        } description: {
            Text("Calendar navigation will appear here.")
        }
    }
}

#Preview {
    TraditionalSpreadsPlaceholderView()
}
