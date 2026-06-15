import SwiftUI

/// Applies a rounded card appearance: secondary system background fill with a
/// subtle separator border.
struct SpreadCardModifier: ViewModifier {
    var cornerRadius: CGFloat = SpreadTheme.CornerRadius.section

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
            )
    }
}

extension View {
    func spreadCard(cornerRadius: CGFloat = SpreadTheme.CornerRadius.section) -> some View {
        modifier(SpreadCardModifier(cornerRadius: cornerRadius))
    }

    /// Applies a card background fill with a `SpreadCardStyle`-driven border.
    ///
    /// Used by card views (e.g. `MultidayDayCardView`, `MonthCardView`) whose fill
    /// color may vary independently of `style`, but whose border should reflect
    /// the shared created/today visual states.
    func spreadCardStyle(cornerRadius: CGFloat, fill: Color, style: SpreadCardStyle) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(style.borderColor, style: style.borderStyle)
        )
    }
}
