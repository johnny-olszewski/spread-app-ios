import SwiftUI

struct SpreadTitleNavigatorGroupView: View {
    static let controlWidth: CGFloat = 32

    let group: SpreadTitleNavigatorGroup
    let isExpanded: Bool
    let containsSelection: Bool
    let selectionIndicatorAnchorID: String?
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
                .foregroundStyle(Color.secondary)
                .padding(.top, 6)

            selectionIndicatorAnchor
        }
        .frame(minWidth: Self.controlWidth, minHeight: 48)
    }

    private var collapseLabel: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.secondary)
                .padding(.top, 6)

            Color.clear.frame(height: 8)
        }
        .frame(minWidth: Self.controlWidth, minHeight: 48)
    }

    private var selectionIndicatorAnchor: some View {
        Circle()
            .fill(Color.clear)
            .frame(width: 6, height: 6)
            .anchorPreference(
                key: SpreadTitleNavigatorSelectionIndicatorAnchorPreferenceKey.self,
                value: .bounds
            ) { anchor in
                guard containsSelection, let selectionIndicatorAnchorID else { return [:] }
                return [selectionIndicatorAnchorID: anchor]
            }
            .frame(height: 8)
    }
}
