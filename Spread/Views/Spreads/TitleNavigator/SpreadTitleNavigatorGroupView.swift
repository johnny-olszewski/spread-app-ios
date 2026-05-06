import SwiftUI

struct SpreadTitleNavigatorGroupView: View {
    private static let selectionIndicatorID = "spread-title-selection-indicator"
    private static let cornerRadius: CGFloat = 6

    let group: SpreadTitleNavigatorGroup
    let isExpanded: Bool
    let containsSelection: Bool
    let selectionIndicatorNamespace: Namespace.ID
    let onExpand: () -> Void
    let onCollapse: () -> Void

    var body: some View {
        Button {
            if isExpanded { onCollapse() } else { onExpand() }
        } label: {
            if isExpanded {
                collapseLabel
            } else {
                expandLabel
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.28), value: isExpanded)
        .accessibilityLabel(isExpanded ? "Collapse group" : "Expand hidden spreads: \(group.dateRangeLabel)")
        .accessibilityHint(isExpanded ? "Hides the revealed spreads" : "Shows spreads hidden from the title strip")
    }

    private var expandLabel: some View {
        VStack(spacing: 4) {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.medium))
                .foregroundStyle(containsSelection ? Color.primary : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 6)

            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)

                if containsSelection {
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
        }
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .stroke(
                    Color.secondary.opacity(containsSelection ? 0.45 : 0.2),
                    lineWidth: 1
                )
        )
    }

    private var collapseLabel: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.secondary)
                .padding(.top, 6)

            Color.clear
                .frame(width: 6, height: 6)
                .frame(height: 8)
        }
        .frame(minWidth: 28, minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
