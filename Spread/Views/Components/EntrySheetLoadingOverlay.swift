import SwiftUI

/// A full-screen dimming overlay with a centered progress spinner, shown while an entry sheet is saving or creating.
struct EntrySheetLoadingOverlay: View {

    var body: some View {
        ZStack {
            SpreadTheme.Overlay.dim
            ProgressView()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        Color.white
        EntrySheetLoadingOverlay()
    }
}
