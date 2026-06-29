import SwiftUI

/// A styled icon or text button used across spread cards and headers.
///
/// `Style` standardizes the recurring button treatments (foreground color,
/// background, sizing) so new card affordances can reuse an existing look
/// rather than re-implementing button chrome. `Content` standardizes what is
/// rendered inside the button — a system symbol, a custom image, or text.
struct SpreadButton: View {

    /// What is rendered inside the button.
    enum Content {
        /// A semantic icon token.
        case icon(SpreadTheme.Icon)
        /// A custom image.
        case image(Image)
        /// A text label.
        case text(String)
    }

    /// Visual treatment for a `SpreadButton`.
    enum Style {
        /// Accent-colored content on a circular white background — primary
        /// card navigation actions (e.g. "go to day/month spread").
        case primary
        /// Content in the secondary foreground color, no background —
        /// auxiliary actions like previewing a spread.
        case secondary
        /// Content in the view's tint color, no background — standard
        /// toolbar-style actions (e.g. "Add Task").
        case tertiary
    }

    struct ViewModel {
        let title: String
        let content: Content
        var style: Style = .tertiary
        let accessibilityIdentifier: String?
        let action: @MainActor () -> Void

        init(
            title: String,
            content: Content,
            style: Style = .tertiary,
            accessibilityIdentifier: String? = nil,
            action: @escaping @MainActor () -> Void
        ) {
            self.title = title
            self.content = content
            self.style = style
            self.accessibilityIdentifier = accessibilityIdentifier
            self.action = action
        }

        /// Convenience initializer for the common case of an icon.
        init(
            title: String,
            icon: SpreadTheme.Icon,
            style: Style = .tertiary,
            accessibilityIdentifier: String? = nil,
            action: @escaping @MainActor () -> Void
        ) {
            self.init(
                title: title,
                content: .icon(icon),
                style: style,
                accessibilityIdentifier: accessibilityIdentifier,
                action: action
            )
        }
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button(action: viewModel.action) {
            styledContent
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(viewModel.title)
        .accessibilityIdentifier(viewModel.accessibilityIdentifier ?? "")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .icon(let icon):
            icon.sized(SpreadTheme.IconSize.small)
        case .image(let image):
            image
        case .text(let text):
            Text(text).font(.system(size: SpreadTheme.IconSize.small, weight: .semibold))
        }
    }

    @ViewBuilder
    private var styledContent: some View {
        switch viewModel.style {
        case .primary:
            tinted(content, SpreadTheme.Accent.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white.opacity(0.94)))
        case .secondary:
            tinted(content, .secondary)
        case .tertiary:
            content
        }
    }

    /// Applies the right tint for whichever `Content` case is being rendered — `SpreadTheme.Icon`
    /// needs `.iconTint(_:)` since it's a plain image with no ambient color propagation, while
    /// `Text`/`Image` content tint correctly via `.foregroundStyle(_:)`.
    @ViewBuilder
    private func tinted(_ view: some View, _ color: Color) -> some View {
        switch viewModel.content {
        case .icon:
            view.iconTint(color)
        case .image, .text:
            view.foregroundStyle(color)
        }
    }
}
