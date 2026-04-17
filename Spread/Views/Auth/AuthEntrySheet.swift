import SwiftUI

/// Shared auth entry sheet used both for blocking launch auth and toolbar entry.
struct AuthEntrySheet: View {
    let authManager: AuthManager
    let isBlocking: Bool

    var body: some View {
        Group {
            if authManager.state.isSignedIn {
                ProfileSheet(authManager: authManager)
            } else {
                LoginSheet(
                    authManager: authManager,
                    showsCancelButton: !isBlocking
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(isBlocking)
            }
        }
    }
}
