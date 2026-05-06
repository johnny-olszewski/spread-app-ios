import SwiftUI

struct SpreadTitleNavigatorGroupView: View {
    let group: SpreadTitleNavigatorGroup
    let isExpanded: Bool
    let containsSelection: Bool
    /// The semantic ID of the selected item when this group is collapsed and contains the
    /// selection. Used to register the group header's frame under that ID so the strip's
    /// shared indicator overlay can position itself correctly.
    let selectedItemSemanticID: String?
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
        .background {
            if let id = selectedItemSemanticID {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: SpreadTitleNavigatorItemFramePreferenceKey.self,
                        value: [id: geometry.frame(in: .global)]
                    )
                }
            }
        }
    }

    private var expandLabel: some View {
        VStack(spacing: 4) {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 6)

            // Reserved space aligned with the strip's shared selection indicator overlay.
            Color.clear.frame(height: 8)
        }
        .frame(minHeight: 48)
    }

    private var collapseLabel: some View {
        VStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.secondary)
                .padding(.top, 6)

            Color.clear.frame(height: 8)
        }
        .frame(minWidth: 28, minHeight: 48)
    }
}
