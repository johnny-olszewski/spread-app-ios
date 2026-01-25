import SwiftUI

/// A toolbar button for accessing the inbox.
///
/// Displays a tray icon that changes to yellow tint when the inbox
/// has entries. Uses `tray.full` icon when non-empty, `tray` when empty.
/// No badge count is shown (liquid glass compatibility).
struct InboxButton: View {

    // MARK: - Properties

    /// The configuration for the button appearance.
    private let configuration: InboxButtonConfiguration

    /// Action to perform when the button is tapped.
    private let action: () -> Void

    // MARK: - Initialization

    /// Creates an inbox button.
    ///
    /// - Parameters:
    ///   - inboxCount: The current inbox count.
    ///   - action: The action to perform when tapped.
    init(inboxCount: Int, action: @escaping () -> Void) {
        self.configuration = InboxButtonConfiguration(inboxCount: inboxCount)
        self.action = action
    }

    /// Creates an inbox button from a configuration.
    ///
    /// - Parameters:
    ///   - configuration: The button configuration.
    ///   - action: The action to perform when tapped.
    init(configuration: InboxButtonConfiguration, action: @escaping () -> Void) {
        self.configuration = configuration
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Image(systemName: configuration.iconName)
                .foregroundStyle(buttonColor)
        }
        .accessibilityLabel(configuration.accessibilityLabel)
    }

    // MARK: - Styling

    private var buttonColor: Color {
        configuration.usesYellowTint ? .yellow : .accentColor
    }
}

// MARK: - Previews

#Preview("Empty Inbox") {
    InboxButton(inboxCount: 0) {}
        .padding()
}

#Preview("Non-Empty Inbox") {
    InboxButton(inboxCount: 5) {}
        .padding()
}

#Preview("Single Entry") {
    InboxButton(inboxCount: 1) {}
        .padding()
}

#Preview("Comparison") {
    HStack(spacing: 32) {
        VStack {
            InboxButton(inboxCount: 0) {}
            Text("Empty")
                .font(.caption)
        }
        VStack {
            InboxButton(inboxCount: 3) {}
            Text("3 entries")
                .font(.caption)
        }
    }
    .padding()
}
