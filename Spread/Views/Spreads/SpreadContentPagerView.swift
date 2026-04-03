import SwiftUI

struct SpreadContentPagerView<Page: View>: View {
    private let liveRadius = 2

    let model: SpreadTitleNavigatorModel
    let items: [SpreadTitleNavigatorModel.Item]
    let selectedID: String
    let recenterToken: Int
    let onSettledSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    @ViewBuilder let page: (SpreadTitleNavigatorModel.Item) -> Page

    @State private var visiblePageID: String?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastSequenceSignature: [String] = []

    private var sequenceSignature: [String] {
        items.map(\.id)
    }

    private func pagerID(for semanticID: String) -> String {
        "pager.\(semanticID)"
    }

    private func semanticID(from pagerID: String?) -> String? {
        guard let pagerID else { return nil }
        return pagerID.replacingOccurrences(of: "pager.", with: "")
    }

    private var liveAnchorID: String {
        guard let visibleSemanticID = semanticID(from: visiblePageID),
              items.contains(where: { $0.id == visibleSemanticID }) else {
            return selectedID
        }
        if visibleSemanticID != selectedID && scrollPhase == .idle {
            return selectedID
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
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(pagerID(for: item.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visiblePageID)
        .onAppear {
            visiblePageID = pagerID(for: selectedID)
            lastSequenceSignature = sequenceSignature
        }
        .task(id: sequenceSignature) {
            let isSameSequence = lastSequenceSignature == sequenceSignature
            lastSequenceSignature = sequenceSignature
            center(on: selectedID, animated: isSameSequence)
        }
        .onChange(of: selectedID) { _, newValue in
            guard pagerID(for: newValue) != visiblePageID else { return }
            let shouldAnimate = lastSequenceSignature == sequenceSignature
            center(on: newValue, animated: shouldAnimate)
        }
        .onChange(of: recenterToken) { _, _ in
            center(on: selectedID, animated: true)
        }
        .onChange(of: visiblePageID) { _, newValue in
            guard scrollPhase == .idle,
                  let semanticID = semanticID(from: newValue),
                  semanticID != selectedID else { return }
            guard let item = items.first(where: { $0.id == semanticID }) else { return }
            onSettledSelect(item.selection)
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            guard newPhase == .idle,
                  let currentVisibleID = semanticID(from: visiblePageID),
                  currentVisibleID != selectedID else {
                return
            }
            guard let item = items.first(where: { $0.id == currentVisibleID }) else { return }
            onSettledSelect(item.selection)
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.pager)
    }

    private func center(on id: String, animated: Bool) {
        if animated {
            withAnimation(.easeInOut(duration: 0.38)) {
                visiblePageID = pagerID(for: id)
            }
        } else {
            visiblePageID = pagerID(for: id)
        }
    }
}
