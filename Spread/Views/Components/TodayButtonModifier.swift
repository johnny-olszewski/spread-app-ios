import SwiftUI

/// Adds a "Today" navigation button to the spread view.
///
/// On iPhone (compact width), the button appears as a `.glassEffect` capsule
/// overlaid in the bottom-leading corner of the view. On iPad (regular width),
/// it appears as a toolbar button in the primary action slot.
struct TodayButtonModifier: ViewModifier {

    let action: () -> Void
    
    var position: Alignment {
        horizontalSizeClass == .regular ? .topTrailing : .bottomLeading
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .overlay(alignment: position) {
                Button("Today", action: action)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(in: Capsule())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .padding(.top, 8)
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton
                    )
        }
    }
}

extension View {
    /// Adds the adaptive Today navigation button to the view.
    func todayButton(action: @escaping () -> Void) -> some View {
        modifier(TodayButtonModifier(action: action))
    }
}
