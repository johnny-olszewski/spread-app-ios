import SwiftUI

/// Global toolbar button for overdue task review.
struct OverdueButton: View {

    private let configuration: OverdueButtonConfiguration
    private let action: () -> Void

    init(overdueCount: Int, action: @escaping () -> Void) {
        self.configuration = OverdueButtonConfiguration(overdueCount: overdueCount)
        self.action = action
    }

    init(configuration: OverdueButtonConfiguration, action: @escaping () -> Void) {
        self.configuration = configuration
        self.action = action
    }

    var body: some View {
        if configuration.isVisible {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: configuration.iconName)
                    Text("\(configuration.overdueCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.yellow)
            }
            .accessibilityLabel(configuration.accessibilityLabel)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Overdue.button)
        }
    }
}
