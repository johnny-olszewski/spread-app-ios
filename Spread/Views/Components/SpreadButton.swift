import SwiftUI

// MARK: - SpreadButton

/// The single button primitive for Spread. Pick a `kind` + `size`; the style
/// pulls every color, radius, font, and metric from `SpreadTheme`.
///
///     SpreadButton("Create", kind: .prominent) { submit() }
///     SpreadButton("Clear", kind: .plain, role: .destructive) { clear() }
///     SpreadButton(icon: .editCompose, kind: .glass) { edit() }
struct SpreadButton: View {

    // MARK: Kind

    /// Visual treatment for the button.
    enum Kind {
        /// Filled accent background, white label — one primary action per surface.
        case prominent
        /// Accent at 12% fill with accent label — secondary actions and chips.
        case tonal
        /// Hairline outline, foreground label — toggles and bordered states.
        case bordered
        /// Borderless accent text/icon — inline actions, Done/Cancel.
        case plain
        /// Capsule + `.glassEffect` — floating nav and toolbar glyphs.
        case glass
    }

    /// Size tier. Each tier defines padding, font size, and icon size.
    enum Size { case small, medium, large }

    // MARK: Config

    private let title: String?
    private let icon: SpreadTheme.Icon?
    private let kind: Kind
    private let size: Size
    private let role: ButtonRole?
    private let fillsWidth: Bool
    private let accessibilityIdentifier: String?
    private let action: () -> Void

    init(
        _ title: String? = nil,
        icon: SpreadTheme.Icon? = nil,
        kind: Kind = .tonal,
        size: Size = .medium,
        role: ButtonRole? = nil,
        fillsWidth: Bool = false,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.size = size
        self.role = role
        self.fillsWidth = fillsWidth
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    // MARK: Body

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: SpreadTheme.Spacing.small) {
                if let icon {
                    icon.sized(iconSize)
                        .iconTint(foregroundColor)
                }
                if let title {
                    Text(title)
                }
            }
        }
        .buttonStyle(
            SpreadButtonStyle(
                kind: kind,
                size: size,
                foregroundColor: foregroundColor,
                fillsWidth: fillsWidth
            )
        )
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    // MARK: Foreground

    /// Resolved label color — shared with `SpreadButtonStyle` so icon and text always agree.
    var foregroundColor: Color {
        Self.foregroundColor(kind: kind, role: role)
    }

    static func foregroundColor(kind: Kind, role: ButtonRole?) -> Color {
        let accent: Color = role == .destructive ? SpreadTheme.Status.error : SpreadTheme.Accent.primary
        switch kind {
        case .prominent: return .white
        case .tonal, .bordered, .plain, .glass: return accent
        }
    }

    // MARK: Metrics

    private var iconSize: CGFloat {
        switch size {
        case .small:  return SpreadTheme.IconSize.small
        case .medium: return SpreadTheme.IconSize.medium
        case .large:  return SpreadTheme.IconSize.large
        }
    }
}

// MARK: - ViewModel

extension SpreadButton {

    /// Value type for passing button configuration through view hierarchies (e.g. section headers).
    struct ViewModel: Identifiable {
        let id = UUID()
        var title: String?
        var icon: SpreadTheme.Icon?
        var kind: Kind
        var size: Size
        var role: ButtonRole?
        var accessibilityIdentifier: String?
        var action: @MainActor () -> Void

        init(
            title: String? = nil,
            icon: SpreadTheme.Icon? = nil,
            kind: Kind = .plain,
            size: Size = .small,
            role: ButtonRole? = nil,
            accessibilityIdentifier: String? = nil,
            action: @escaping @MainActor () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.kind = kind
            self.size = size
            self.role = role
            self.accessibilityIdentifier = accessibilityIdentifier
            self.action = action
        }
    }

    /// Build a button from a view model — use in section headers and list rows.
    init(_ viewModel: ViewModel) {
        self.init(
            viewModel.title,
            icon: viewModel.icon,
            kind: viewModel.kind,
            size: viewModel.size,
            role: viewModel.role,
            accessibilityIdentifier: viewModel.accessibilityIdentifier,
            action: viewModel.action
        )
    }
}

// MARK: - SpreadButtonStyle

struct SpreadButtonStyle: ButtonStyle {
    let kind: SpreadButton.Kind
    let size: SpreadButton.Size
    let foregroundColor: Color
    var fillsWidth: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(background)
            .overlay(border)
            .clipShape(shape)
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(SpreadTheme.Motion.quick, value: configuration.isPressed)
    }

    // MARK: Metrics

    private var font: Font {
        switch size {
        case .small:  return SpreadTheme.Typography.subheadline.weight(.medium)
        case .medium: return SpreadTheme.Typography.body.weight(.medium)
        case .large:  return SpreadTheme.Typography.body.weight(.semibold)
        }
    }

    private var hPadding: CGFloat {
        switch size {
        case .small:  return SpreadTheme.Spacing.medium         // 8
        case .medium: return 14
        case .large:  return SpreadTheme.Spacing.large + 4      // 20
        }
    }

    private var vPadding: CGFloat {
        switch size {
        case .small:  return 6
        case .medium: return SpreadTheme.Spacing.medium         // 8
        case .large:  return SpreadTheme.Spacing.standard       // 12
        }
    }

    private var shape: AnyShape {
        kind == .glass
            ? AnyShape(Capsule())
            : AnyShape(RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.standard, style: .continuous))
    }

    // MARK: Background

    @ViewBuilder private var background: some View {
        switch kind {
        case .prominent:
            foregroundColor == .white ? SpreadTheme.Accent.primary : foregroundColor
        case .tonal:
            foregroundColor.opacity(0.12)
        case .glass:
            Color.clear.glassEffect(in: Capsule())
        case .bordered, .plain:
            Color.clear
        }
    }

    @ViewBuilder private var border: some View {
        if kind == .bordered {
            shape.stroke(SpreadTheme.Separator.strong, lineWidth: 1)
        }
    }
}

// MARK: - Previews

#Preview("Kinds") {
    VStack(spacing: 12) {
        SpreadButton("Prominent", kind: .prominent) {}
        SpreadButton("Tonal", kind: .tonal) {}
        SpreadButton("Bordered", kind: .bordered) {}
        SpreadButton("Plain", kind: .plain) {}
        SpreadButton("Glass", kind: .glass) {}
        SpreadButton("Destructive", kind: .tonal, role: .destructive) {}
        Divider()
        SpreadButton("Icon + label", icon: .pencil, kind: .tonal) {}
        SpreadButton(icon: .editCompose, kind: .glass) {}
        SpreadButton("Disabled", kind: .prominent) {}.disabled(true)
    }
    .padding()
}

#Preview("Sizes") {
    VStack(spacing: 12) {
        SpreadButton("Small", kind: .tonal, size: .small) {}
        SpreadButton("Medium", kind: .tonal, size: .medium) {}
        SpreadButton("Large", kind: .tonal, size: .large) {}
        SpreadButton("Fill width", kind: .prominent, fillsWidth: true) {}
    }
    .padding()
}
