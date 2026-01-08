import SwiftUI

/// Placeholder root view for the Spread app.
struct ContentView: View {
    let container: DependencyContainer

    var body: some View {
        Text("Spread")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if DEBUG
            .debugEnvironmentOverlay(container: container)
            #endif
    }
}

#Preview {
    ContentView(container: try! .makeForPreview())
}
