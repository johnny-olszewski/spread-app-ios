import SwiftUI

struct SpreadTitleNavigatorItemView: View {
    private static let selectionIndicatorID = "spread-title-selection-indicator"

    let semanticID: String
    let style: SpreadTitleNavigatorItemStyle
    let display: SpreadTitleNavigatorModel.Item.Display
    let overdueCount: Int
    let isSelected: Bool
    let accessibilityIdentifier: String
    let overdueBadgeAccessibilityIdentifier: String
    let selectionIndicatorNamespace: Namespace.ID
    let showsSelectionIndicator: Bool
    let borderColor: Color?
    let emphasisColor: Color
    let selectedEmphasisColor: Color
    let horizontalPadding: CGFloat
    let action: () -> Void
    var isInteractive: Bool = true
    var isTodayEmphasized: Bool = false

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

            if showsSelectionIndicator {
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)

                    if isSelected {
                        Circle()
                            .fill(selectionIndicatorColor)
                            .frame(width: 6, height: 6)
                            .matchedGeometryEffect(
                                id: Self.selectionIndicatorID,
                                in: selectionIndicatorNamespace
                            )
                    }
                }
                .frame(height: 8)
            } else {
                Spacer(minLength: 0)
                    .frame(height: 8)
            }
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
            overdueBadge
        }
    }

    @ViewBuilder
    private var overdueBadge: some View {
        if overdueCount > 0 {
            if overdueCount > 9 {
                Text("\(overdueCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red, in: Capsule())
                    .accessibilityLabel("\(overdueCount) overdue tasks")
                    .accessibilityIdentifier(overdueBadgeAccessibilityIdentifier)
            } else {
                Text("\(overdueCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(.red, in: Circle())
                    .accessibilityLabel("\(overdueCount) overdue tasks")
                    .accessibilityIdentifier(overdueBadgeAccessibilityIdentifier)
            }
        }
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
        switch style {
        case .year:
            VStack(spacing: -2) {
                if let top = display.top {
                    Text(top)
                        .font(.title3.weight(yearWeight(selected: isSelected, emphasized: isTodayEmphasized)))
                        .foregroundStyle(foregroundColor(selected: isSelected))
                }
                Text(display.bottom)
                    .font(.title3.weight(yearWeight(selected: isSelected, emphasized: isTodayEmphasized)))
                    .foregroundStyle(foregroundColor(selected: isSelected))
            }
        case .month:
            Text(display.bottom)
                .font(.subheadline.weight(monthWeight(selected: isSelected, emphasized: isTodayEmphasized)))
                .textCase(.uppercase)
                .foregroundStyle(foregroundColor(selected: isSelected))
                .lineLimit(1)
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
                    .font(.body.weight(dayWeight(selected: isSelected, emphasized: isTodayEmphasized)))
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

    private func foregroundColor(selected: Bool) -> Color {
        if isTodayEmphasized {
            return selected ? selectedEmphasisColor : emphasisColor
        }
        return selected ? .primary : .secondary
    }

    private var footerColor: Color {
        if isTodayEmphasized {
            return isSelected ? selectedEmphasisColor.opacity(0.95) : emphasisColor.opacity(0.9)
        }
        return isSelected ? .primary : .secondary.opacity(0.85)
    }

    private var selectionIndicatorColor: Color {
        if isTodayEmphasized {
            return selectedEmphasisColor
        }
        return .accentColor
    }

    private func yearWeight(selected: Bool, emphasized: Bool) -> Font.Weight {
        if selected || emphasized { return .bold }
        return .semibold
    }

    private func monthWeight(selected: Bool, emphasized: Bool) -> Font.Weight {
        if selected || emphasized { return .semibold }
        return .medium
    }

    private func dayWeight(selected: Bool, emphasized: Bool) -> Font.Weight {
        if selected || emphasized { return .semibold }
        return .regular
    }

    private func captionWeight(emphasized: Bool) -> Font.Weight {
        emphasized ? .bold : .semibold
    }

    private func footerWeight(emphasized: Bool) -> Font.Weight {
        emphasized ? .semibold : .medium
    }
}

struct SpreadTitleNavigatorItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
