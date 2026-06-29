import SwiftUI

/// A toolbar button for accessing authentication features.
///
/// Shows a person icon that changes based on auth state:
/// - Logged out: `SpreadTheme.Icon.userCircle` (outline)
/// - Logged in: `SpreadTheme.Icon.userCircleFilled` (filled)
struct AuthButton: View {

    // MARK: - Properties

    /// Whether the user is currently signed in.
    let isSignedIn: Bool

    /// Action to perform when the button is tapped.
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            icon.sized(SpreadTheme.IconSize.large)
                .iconTint(.primary)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Computed Properties

    private var icon: SpreadTheme.Icon {
        isSignedIn ? .userCircleFilled : .userCircle
    }

    private var accessibilityLabel: String {
        isSignedIn ? "View profile" : "Sign in"
    }
}

// MARK: - Previews

#Preview("Signed Out") {
    AuthButton(isSignedIn: false) {}
        .padding()
}

#Preview("Signed In") {
    AuthButton(isSignedIn: true) {}
        .padding()
}

#Preview("Comparison") {
    HStack(spacing: 32) {
        VStack {
            AuthButton(isSignedIn: false) {}
            Text("Signed Out")
                .font(SpreadTheme.Typography.caption)
        }
        VStack {
            AuthButton(isSignedIn: true) {}
            Text("Signed In")
                .font(SpreadTheme.Typography.caption)
        }
    }
    .padding()
}
