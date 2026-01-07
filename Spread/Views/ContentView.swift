import SwiftUI

/// Placeholder root view for the Spread app.
struct ContentView: View {
    var body: some View {
        Text("Spread")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if DEBUG
            .debugEnvironmentOverlay()
            #endif
    }
}

#Preview {
    ContentView()
}
