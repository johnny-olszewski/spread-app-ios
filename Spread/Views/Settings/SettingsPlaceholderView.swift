import SwiftUI

/// Placeholder view for the settings content area.
///
/// Will be replaced with actual settings view in SPRD-20.
struct SettingsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Settings")
            } icon: {
                SpreadTheme.Icon.gear.sized(SpreadTheme.IconSize.large)
            }
        } description: {
            Text("App preferences will appear here.")
        }
    }
}

#Preview {
    SettingsPlaceholderView()
}
