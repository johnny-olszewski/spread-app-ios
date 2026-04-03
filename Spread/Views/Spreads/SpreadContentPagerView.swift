import SwiftUI

struct SpreadContentPagerView<Page: View>: View {
    private let liveRadius = 2

    let model: SpreadTitleNavigatorModel
    let items: [SpreadTitleNavigatorModel.Item]
    let recenterToken: Int
    @Binding var selection: SpreadHeaderNavigatorModel.Selection
    @ViewBuilder let page: (SpreadTitleNavigatorModel.Item) -> Page

    @State private var pagerSettledTargetID: String?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastSequenceSignature: [String] = []

    private var sequenceSignature: [String] {
        items.map(\.id)
    }

    private var selectedSemanticID: String {
        selection.stableID(calendar: model.calendar)
    }

    private func pagerID(for semanticID: String) -> String {
        "pager.\(semanticID)"
    }

    private func semanticID(from pagerID: String?) -> String? {
        guard let pagerID else { return nil }
        return pagerID.replacingOccurrences(of: "pager.", with: "")
    }

    private var liveAnchorID: String {
        guard let visibleSemanticID = semanticID(from: pagerSettledTargetID),
              items.contains(where: { $0.id == visibleSemanticID }) else {
            return selectedSemanticID
        }
        if visibleSemanticID != selectedSemanticID && scrollPhase == .idle {
            return selectedSemanticID
        }
        return visibleSemanticID
    }

    private var liveWindowIDs: Set<String> {
        model.liveWindowIDs(items: items, anchorID: liveAnchorID, radius: liveRadius)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(items) { item in
                    Group {
                        if liveWindowIDs.contains(item.id) {
                            page(item)
                        } else {
                            Color.clear
                                .accessibilityHidden(true)
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(pagerID(for: item.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pagerSettledTargetID)
        .onAppear {
            pagerSettledTargetID = pagerID(for: selectedSemanticID)
            lastSequenceSignature = sequenceSignature
        }
        .task(id: sequenceSignature) {
            let isSameSequence = lastSequenceSignature == sequenceSignature
            lastSequenceSignature = sequenceSignature
            center(on: selectedSemanticID, animated: isSameSequence)
        }
        .onChange(of: selectedSemanticID) { _, newValue in
            guard pagerID(for: newValue) != pagerSettledTargetID else { return }
            center(on: newValue, animated: false)
        }
        .onChange(of: recenterToken) { _, _ in
            center(on: selectedSemanticID, animated: false)
        }
        .onChange(of: pagerSettledTargetID) { _, newValue in
            guard scrollPhase == .idle,
                  let semanticID = semanticID(from: newValue),
                  semanticID != selectedSemanticID else { return }
            guard let item = items.first(where: { $0.id == semanticID }) else { return }
            selection = item.selection
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            guard newPhase == .idle,
                  let currentVisibleID = semanticID(from: pagerSettledTargetID),
                  currentVisibleID != selectedSemanticID else {
                return
            }
            guard let item = items.first(where: { $0.id == currentVisibleID }) else { return }
            selection = item.selection
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.pager)
    }

    private func center(on id: String, animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 0.38)) {
                pagerSettledTargetID = pagerID(for: id)
            }
        } else {
            pagerSettledTargetID = pagerID(for: id)
        }
    }
}
