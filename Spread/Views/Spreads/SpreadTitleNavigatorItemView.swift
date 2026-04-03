import SwiftUI

struct SpreadTitleNavigatorItemView: View {
    let semanticID: String
    let style: SpreadTitleNavigatorModel.Item.Style
    let display: SpreadTitleNavigatorModel.Item.Display
    let isSelected: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            itemLabel
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.16))
                    }
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SpreadTitleNavigatorItemFramePreferenceKey.self,
                            value: [semanticID: geometry.frame(in: .global)]
                        )
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
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
