import SwiftUI

/// In-content header for a spread surface.
///
/// Renders a "Go Back" capsule button when peek navigation is active. Empty otherwise.
/// Sync indicator and spread action menu have moved to the navigation bar toolbar.
struct SpreadHeaderView: View {

    // MARK: - Properties

    /// When non-nil, a "Go Back" button is shown centered in the header.
    var backDestination: DataModel.Spread? = nil

    /// Called when the user taps the "Go Back" button.
    var onGoBack: (() -> Void)? = nil

    // MARK: - Body

    var body: some View {
        if backDestination != nil, let onGoBack {
            Button(action: onGoBack) {
                Label("Go Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glassEffect(in: Capsule())
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.88).combined(with: .opacity))
            .accessibilityLabel("Go back to previous spread")
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .animation(.spring(response: 0.32, dampingFraction: 0.8), value: backDestination?.id)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.title)
        }
    }
}

struct SpreadNavigatorPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let presentsAsPopover: Bool
    let navigatorContent: () -> AnyView

    func body(content: Content) -> some View {
        if presentsAsPopover {
            content.popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                navigatorContent()
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                navigatorContent()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

extension View {
    func spreadNavigatorPresentation(
        isPresented: Binding<Bool>,
        presentsAsPopover: Bool,
        model: SpreadHeaderNavigatorModel,
        currentSpread: DataModel.Spread,
        recommendations: [SpreadTitleNavigatorRecommendation] = [],
        onSelect: @escaping (SpreadHeaderNavigatorModel.Selection) -> Void,
        onRecommendationTapped: ((SpreadTitleNavigatorRecommendation) -> Void)? = nil
    ) -> some View {
        modifier(
            SpreadNavigatorPresentationModifier(
                isPresented: isPresented,
                presentsAsPopover: presentsAsPopover,
                navigatorContent: {
                    AnyView(
                        SpreadHeaderNavigatorPopoverView(
                            model: model,
                            currentSpread: currentSpread,
                            recommendations: recommendations,
                            onSelect: onSelect,
                            onRecommendationTapped: onRecommendationTapped,
                            onDismiss: { isPresented.wrappedValue = false }
                        )
                    )
                }
            )
        )
    }
}

// MARK: - Preview

#Preview("Go Back button visible") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)
    return VStack(spacing: 0) {
        SpreadHeaderView(backDestination: spread, onGoBack: {})
        Divider()
        Spacer()
    }
}

#Preview("Empty (no back destination)") {
    VStack(spacing: 0) {
        SpreadHeaderView()
        Divider()
        Spacer()
    }
}
