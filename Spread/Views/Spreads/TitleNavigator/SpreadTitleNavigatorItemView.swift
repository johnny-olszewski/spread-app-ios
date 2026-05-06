import SwiftUI

struct SpreadTitleNavigatorItemView: View {
    let semanticID: String
    let style: SpreadTitleNavigatorItemStyle
    let display: SpreadTitleNavigatorModel.Item.Display
    let badge: SpreadTitleNavigatorBadge?
    let isSelected: Bool
    let accessibilityIdentifier: String
    let badgeAccessibilityIdentifier: String?
    let borderColor: Color?
    let emphasisColor: Color
    let selectedEmphasisColor: Color
    let horizontalPadding: CGFloat
    let action: () -> Void
    var isInteractive: Bool = true
    var isTodayEmphasized: Bool = false
    /// True when this item is rendered inside an expanded hidden group (subdued appearance).
    var isHidden: Bool = false

    var body: some View {
        Group {
            if isInteractive {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.28), value: isSelected)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var content: some View {
        VStack(spacing: 4) {
            itemLabel
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 6)

            // Reserved space for the strip's shared selection indicator overlay.
            Color.clear.frame(height: 8)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .background(backgroundShape)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: SpreadTitleNavigatorItemFramePreferenceKey.self,
                    value: [semanticID: geometry.frame(in: .global)]
                )
            }
        )
        .overlay(alignment: .topTrailing) {
            titleBadge
        }
    }

    @ViewBuilder
    private var titleBadge: some View {
        switch badge {
        case .overdue(let count):
            overdueBadge(count: count)
        case .favorite:
            favoriteBadge
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func overdueBadge(count: Int) -> some View {
        if count > 9 {
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red, in: Capsule())
                .accessibilityLabel(badge?.accessibilityLabel(style: style) ?? "")
                .accessibilityIdentifier(badgeAccessibilityIdentifier ?? "")
        } else {
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(.red, in: Circle())
                .accessibilityLabel(badge?.accessibilityLabel(style: style) ?? "")
                .accessibilityIdentifier(badgeAccessibilityIdentifier ?? "")
        }
    }

    private var favoriteBadge: some View {
        Image(systemName: "star.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.yellow)
            .frame(width: 18, height: 18)
            .background(.regularMaterial, in: Circle())
            .accessibilityLabel(badge?.accessibilityLabel(style: style) ?? "")
            .accessibilityIdentifier(badgeAccessibilityIdentifier ?? "")
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if let borderColor {
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1.5)
        }
    }

    @ViewBuilder
    private var itemLabel: some View {
        if display.isPersonalized {
            personalizedLabel
        } else {
            switch style {
            case .year:
                VStack(spacing: -2) {
                    if let top = display.top {
                        Text(top)
                            .font(.title3.weight(yearWeight(emphasized: isTodayEmphasized)))
                            .foregroundStyle(foregroundColor(selected: isSelected))
                    }
                    Text(display.bottom)
                        .font(.title3.weight(yearWeight(emphasized: isTodayEmphasized)))
                        .foregroundStyle(foregroundColor(selected: isSelected))
                }
            case .month:
                if let top = display.top {
                    VStack(spacing: 0) {
                        Text(top)
                            .font(.caption2.smallCaps())
                            .fontWeight(captionWeight(emphasized: isTodayEmphasized))
                            .foregroundStyle(foregroundColor(selected: isSelected))
                            .lineLimit(1)
                        Text(display.bottom)
                            .font(.subheadline.weight(monthWeight(emphasized: isTodayEmphasized)))
                            .textCase(.uppercase)
                            .foregroundStyle(foregroundColor(selected: isSelected))
                            .lineLimit(1)
                    }
                } else {
                    Text(display.bottom)
                        .font(.subheadline.weight(monthWeight(emphasized: isTodayEmphasized)))
                        .textCase(.uppercase)
                        .foregroundStyle(foregroundColor(selected: isSelected))
                        .lineLimit(1)
                }
            case .day, .multiday:
                VStack(spacing: 0) {
                    if let top = display.top {
                        Text(top)
                            .font(.caption2.smallCaps())
                            .fontWeight(captionWeight(emphasized: isTodayEmphasized))
                            .foregroundStyle(foregroundColor(selected: isSelected))
                            .lineLimit(1)
                    }
                    Text(display.bottom)
                        .font(.body.weight(dayWeight(emphasized: isTodayEmphasized)))
                        .foregroundStyle(foregroundColor(selected: isSelected))
                        .lineLimit(1)
                    if let footer = display.footer {
                        Text(footer)
                            .font(.caption2.smallCaps())
                            .fontWeight(footerWeight(emphasized: isTodayEmphasized))
                            .foregroundStyle(footerColor)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var personalizedLabel: some View {
        VStack(spacing: 0) {
            if let top = display.top {
                Text(top)
                    .font(.caption2.smallCaps())
                    .fontWeight(captionWeight(emphasized: isTodayEmphasized))
                    .foregroundStyle(footerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Text(display.bottom)
                .font(.subheadline.weight(monthWeight(emphasized: isTodayEmphasized)))
                .foregroundStyle(foregroundColor(selected: isSelected))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            if let footer = display.footer {
                Text(footer)
                    .font(.caption2.smallCaps())
                    .fontWeight(footerWeight(emphasized: isTodayEmphasized))
                    .foregroundStyle(footerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private func foregroundColor(selected: Bool) -> Color {
        if isTodayEmphasized {
            return selected ? selectedEmphasisColor : emphasisColor
        }
        if selected { return .accentColor }
        return isHidden ? .secondary : .primary
    }

    private var footerColor: Color {
        if isTodayEmphasized {
            return isSelected ? selectedEmphasisColor.opacity(0.95) : emphasisColor.opacity(0.9)
        }
        if isSelected { return Color.accentColor.opacity(0.8) }
        return isHidden ? .secondary.opacity(0.85) : .primary
    }

    private func yearWeight(emphasized: Bool) -> Font.Weight {
        if emphasized { return .bold }
        if isHidden { return .semibold }
        return .bold
    }

    private func monthWeight(emphasized: Bool) -> Font.Weight {
        if emphasized { return .semibold }
        if isHidden { return .medium }
        return .semibold
    }

    private func dayWeight(emphasized: Bool) -> Font.Weight {
        if emphasized { return .semibold }
        if isHidden { return .regular }
        return .semibold
    }

    private func captionWeight(emphasized: Bool) -> Font.Weight {
        if emphasized { return .bold }
        if isHidden { return .semibold }
        return .bold
    }

    private func footerWeight(emphasized: Bool) -> Font.Weight {
        if emphasized { return .semibold }
        if isHidden { return .medium }
        return .semibold
    }
}

struct SpreadTitleNavigatorItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
