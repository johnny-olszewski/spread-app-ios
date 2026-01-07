import SwiftUI

@main
struct SpreadApp: App {
    private let container: DependencyContainer

    init() {
        do {
            container = try DependencyContainer.make(for: .current)
        } catch {
            fatalError("Failed to create DependencyContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
