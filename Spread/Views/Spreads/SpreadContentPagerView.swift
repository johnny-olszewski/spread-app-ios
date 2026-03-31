import SwiftUI

struct SpreadContentPagerView<Page: View>: View {
    private let liveRadius = 2

    let model: SpreadTitleNavigatorModel
    let items: [SpreadTitleNavigatorModel.Item]
    let selectedID: String
    let onSettledSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    @ViewBuilder let page: (SpreadTitleNavigatorModel.Item) -> Page

    @State private var visiblePageID: String?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastSequenceSignature: [String] = []

    private var sequenceSignature: [String] {
        items.map(\.id)
    }

    private var liveAnchorID: String {
        guard let visiblePageID, items.contains(where: { $0.id == visiblePageID }) else {
            return selectedID
        }
        if visiblePageID != selectedID && scrollPhase == .idle {
            return selectedID
        }
        return visiblePageID
    }

    private var liveWindowIDs: Set<String> {
        model.liveWindowIDs(items: items, anchorID: liveAnchorID, radius: liveRadius)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
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
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $visiblePageID)
                .onAppear {
                    visiblePageID = selectedID
                    lastSequenceSignature = sequenceSignature
                }
                .task(id: sequenceSignature) {
                    let isSameSequence = lastSequenceSignature == sequenceSignature
                    lastSequenceSignature = sequenceSignature
                    center(on: selectedID, with: proxy, animated: isSameSequence)
                }
                .onChange(of: selectedID) { _, newValue in
                    guard newValue != visiblePageID else { return }
                    let shouldAnimate = lastSequenceSignature == sequenceSignature
                    center(on: newValue, with: proxy, animated: shouldAnimate)
                }
                .onChange(of: visiblePageID) { _, newValue in
                    guard scrollPhase == .idle, let newValue, newValue != selectedID else { return }
                    guard let item = items.first(where: { $0.id == newValue }) else { return }
                    onSettledSelect(item.selection)
                }
                .onScrollPhaseChange { _, newPhase in
                    scrollPhase = newPhase
                    guard newPhase == .idle, let currentVisibleID = visiblePageID, currentVisibleID != selectedID else {
                        return
                    }
                    guard let item = items.first(where: { $0.id == currentVisibleID }) else { return }
                    onSettledSelect(item.selection)
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.pager)
            }
        }
    }

    private func center(
        on id: String,
        with proxy: ScrollViewProxy,
        animated: Bool
    ) {
        let request = {
            proxy.scrollTo(id, anchor: .center)
            visiblePageID = id
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.38)) {
                request()
            }
        } else {
            request()
        }
    }
}
