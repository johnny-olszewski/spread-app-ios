import SwiftUI

struct SpreadTitleNavigatorItemView: View {
    private static let selectionIndicatorID = "spread-title-selection-indicator"

    let semanticID: String
    let style: SpreadTitleNavigatorItemStyle
    let display: SpreadTitleNavigatorModel.Item.Display
    let isSelected: Bool
    let accessibilityIdentifier: String
    let selectionIndicatorNamespace: Namespace.ID
    let showsSelectionIndicator: Bool
    let borderColor: Color?
    let horizontalPadding: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                                .fill(Color.accentColor)
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
        }
        .padding(.vertical, 2)
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.28), value: isSelected)
        .accessibilityIdentifier(accessibilityIdentifier)
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
                        .font(.title3.weight(isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                }
                Text(display.bottom)
                    .font(.title3.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
        case .month:
            Text(display.bottom)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .textCase(.uppercase)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
        case .day, .multiday:
            VStack(spacing: 0) {
                if let top = display.top {
                    Text(top)
                        .font(.caption2.smallCaps())
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                }
                Text(display.bottom)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                if let footer = display.footer {
                    Text(footer)
                        .font(.caption2.smallCaps())
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
    }
}

struct SpreadTitleNavigatorItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
