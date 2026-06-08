import SwiftUI

/// In-content header for a spread surface.
///
/// Renders a convenience navigation button when `state` is non-nil. Empty otherwise.
/// The button label and icon adapt to the current `ConvenienceNavigationButtonState`.
struct SpreadHeaderView: View {

    // MARK: - Properties

    /// When non-nil, a navigation button is shown centered in the header.
    var state: ConvenienceNavigationButtonState? = nil

    /// Called when the user taps the navigation button.
    var onTap: (() -> Void)? = nil

    // MARK: - Body

    var body: some View {
        if let state, let onTap {
            Button(action: onTap) {
                Label(state.buttonLabel, systemImage: state.systemImage)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glassEffect(in: Capsule())
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.88).combined(with: .opacity))
            .accessibilityLabel(state.accessibilityLabel)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: state)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.title)
        }
    }
}

// MARK: - Preview

#Preview("Go Back button visible") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)
    return VStack(spacing: 0) {
        SpreadHeaderView(state: .goBack(source: spread), onTap: {})
        Divider()
        Spacer()
    }
}

#Preview("Migration offer button") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)
    return VStack(spacing: 0) {
        SpreadHeaderView(
            state: .offer(label: "3 tasks moved automatically", destination: spread, source: spread),
            onTap: {}
        )
        Divider()
        Spacer()
    }
}

#Preview("Empty (no state)") {
    VStack(spacing: 0) {
        SpreadHeaderView()
        Divider()
        Spacer()
    }
}
