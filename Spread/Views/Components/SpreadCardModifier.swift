import SwiftUI

/// Applies a rounded card appearance: secondary system background fill with a
/// subtle separator border.
struct SpreadCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
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
    func spreadCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(SpreadCardModifier(cornerRadius: cornerRadius))
    }
}
