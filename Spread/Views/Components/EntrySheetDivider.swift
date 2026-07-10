import SwiftUI

/// A compact divider with reduced vertical padding used between sections in entry editing sheets.
struct EntrySheetDivider: View {

    var body: some View {
        Divider()
            .padding(.vertical, 2)
    }
}

#Preview {
    VStack(spacing: 0) {
        Text("Section A")
        EntrySheetDivider()
        Text("Section B")
        EntrySheetDivider()
        Text("Section C")
    }
    .padding()
}
