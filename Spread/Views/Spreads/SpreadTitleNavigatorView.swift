import SwiftUI
import UIKit

struct SpreadTitleNavigatorView: View {
    private static let selectionAnimation = Animation.easeInOut(duration: 0.38)
    private static let itemSpacing: CGFloat = 12

    private struct CenterRequest: Equatable {
        let id: String
        let token: Int
    }

    #if DEBUG
    private static let debugHideCreateButton = true
    #endif

    let stripModel: SpreadTitleNavigatorModel
    let headerNavigatorModel: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    let currentSelection: SpreadHeaderNavigatorModel.Selection
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onCreateSpreadTapped: (() -> Void)?
    let onCreateTaskTapped: (() -> Void)?
    let onCreateNoteTapped: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingNavigatorSurface = false
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var centerRequest: CenterRequest?
    @State private var centerRequestToken = 0
    @State private var pendingTapSelectionItemID: String?
    @State private var scrollViewportWidth: CGFloat = 0
    @State private var scrollContainerFrame: CGRect = .zero

    private var items: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    private var selectedItem: SpreadTitleNavigatorModel.Item? {
        let currentID = currentSelection.stableID(calendar: stripModel.calendar)
        return items.first(where: { $0.id == currentID })
    }

    private var selectedItemID: String {
        currentSelection.stableID(calendar: stripModel.calendar)
    }

    var body: some View {
        GeometryReader { geometry in
            let scrollAreaWidth = max(geometry.size.width, 0)

            ZStack(alignment: .trailing) {
                scrollStripContainer(visibleWidth: scrollAreaWidth)
                if let returnButtonEdge = returnButtonEdge(for: scrollAreaWidth) {
                    returnToSelectedButton(edge: returnButtonEdge)
                }
                if showsCreateButton {
                    createButton
                        .padding(.trailing, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                scrollViewportWidth = scrollAreaWidth
            }
            .onChange(of: scrollAreaWidth) { _, newValue in
                scrollViewportWidth = newValue
            }
        }
        .frame(height: 68)
        .secondaryPaperBackground()
        .modifier(
            SpreadNavigatorPresentationModifier(
                isPresented: $isShowingNavigatorSurface,
                style: horizontalSizeClass == .regular ? .popover : .sheet,
                navigatorContent: {
                    AnyView(
                        SpreadHeaderNavigatorPopoverView(
                            model: headerNavigatorModel,
                            currentSpread: currentSpread,
                            onSelect: { selection in
                                onSelect(selection)
                            },
                            onDismiss: { isShowingNavigatorSurface = false }
                        )
                    )
                }
            )
        )
    }

    private func scrollStrip(visibleWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.itemSpacing) {
                    Color.clear
                        .frame(width: leadingInset(for: visibleWidth), height: 1)
                        .accessibilityHidden(true)

                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        itemButton(for: item)
                            .id(item.id)
                            .padding(.leading, extraLeadingSpacing(for: item, at: index))
                    }

                    Color.clear
                        .frame(width: trailingInset(for: visibleWidth), height: 1)
                        .accessibilityHidden(true)
                }
                .scrollTargetLayout()
                .backgroundPreferenceValue(SpreadTitleNavigatorItemFramePreferenceKey.self) { frames in
                    Color.clear
                        .onAppear {
                            itemFrames = frames
                        }
                        .onChange(of: frames) { _, newValue in
                            itemFrames = newValue
                        }
                }
            }
            .coordinateSpace(name: "SpreadTitleNavigatorScroll")
            .scrollTargetBehavior(.viewAligned)
            .task(id: items.map(\.id)) {
                recenterStrip(proxy: proxy, animated: false)
                #if DEBUG
                print("[SpreadTitleNavigatorView] task recenter target=\(currentSelection.stableID(calendar: stripModel.calendar)) items=\(items.map(\.label))")
                #endif
            }
            .onChange(of: currentSelection.stableID(calendar: stripModel.calendar)) { _, _ in
                if pendingTapSelectionItemID == selectedItemID {
                    pendingTapSelectionItemID = nil
                    return
                }
                recenterStrip(proxy: proxy, animated: true)
                #if DEBUG
                print("[SpreadTitleNavigatorView] selectionChanged target=\(currentSelection.stableID(calendar: stripModel.calendar))")
                #endif
            }
            .onChange(of: centerRequest) { _, newValue in
                guard let newValue else { return }
                centerItem(id: newValue.id, with: proxy, animated: true)
            }
        }
    }

    private func scrollStripContainer(visibleWidth: CGFloat) -> some View {
        scrollStrip(visibleWidth: visibleWidth)
            .contentShape(Rectangle())
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            scrollContainerFrame = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) { _, newValue in
                            scrollContainerFrame = newValue
                        }
                }
            )
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.container)
    }

    private func itemButton(for item: SpreadTitleNavigatorModel.Item) -> some View {
        let isSelected = item.id == currentSelection.stableID(calendar: stripModel.calendar)
        let showsSelectedCapsule = isSelected

        return Button {
            if isSelected {
                if showsSelectedCapsule {
                    isShowingNavigatorSurface = true
                } else {
                    requestCenter(on: item.id)
                }
            } else {
                pendingTapSelectionItemID = item.id
                requestCenter(on: item.id)
                onSelect(item.selection)
            }
        } label: {
            itemLabel(for: item, selected: isSelected)
                .frame(width: itemWidth(for: item))
            .background {
                if showsSelectedCapsule {
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
                        value: [item.id: geometry.frame(in: .global)]
                    )
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isSelected ? Definitions.AccessibilityIdentifiers.SpreadStrip.selectedCapsule : identifier(for: item))
    }

    @ViewBuilder
    private func itemLabel(for item: SpreadTitleNavigatorModel.Item, selected: Bool) -> some View {
        switch item.style {
        case .year:
            VStack(spacing: -2) {
                if let top = item.display.top {
                    Text(top)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                }
                Text(item.display.bottom)
                    .font(.title3.weight(selected ? .bold : .semibold))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
        case .month:
            Text(item.display.bottom)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .italic()
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .lineLimit(1)
        case .day, .multiday:
            VStack(spacing: 0) {
                if let top = item.display.top {
                    Text(top)
                        .font(.caption2.smallCaps())
                        .fontWeight(.semibold)
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                }
                Text(item.display.bottom)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
        }
    }

    private enum ReturnButtonEdge {
        case leading
        case trailing
    }

    @ViewBuilder
    private func returnToSelectedButton(edge: ReturnButtonEdge) -> some View {
        HStack {
            if edge == .leading {
                returnButton(edge: edge)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                returnButton(edge: edge)
            }
        }
        .padding(.horizontal, 8)
    }

    private func returnButton(edge: ReturnButtonEdge) -> some View {
        Button {
            requestCenter(on: selectedItemID)
        } label: {
            Image(systemName: edge == .leading ? "arrow.left" : "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .glassEffect(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("spreads.strip.returnToSelected")
    }

    @ViewBuilder
    private var createButton: some View {
        if onCreateSpreadTapped != nil || onCreateTaskTapped != nil || onCreateNoteTapped != nil {
            Menu {
                if let onCreateSpreadTapped {
                    Button(action: onCreateSpreadTapped) {
                        Label("Create Spread", systemImage: "book")
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)
                }
                if let onCreateTaskTapped {
                    Button(action: onCreateTaskTapped) {
                        Label("Create Task", systemImage: "circle.fill")
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)
                }
                if let onCreateNoteTapped {
                    Button(action: onCreateNoteTapped) {
                        Label("Create Note", systemImage: "minus")
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createNote)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.button)
        }
    }

    private var trailingAccessoryWidth: CGFloat {
        (onCreateSpreadTapped != nil || onCreateTaskTapped != nil || onCreateNoteTapped != nil) ? 44 : 0
    }

    private var showsCreateButton: Bool {
        #if DEBUG
        if Self.debugHideCreateButton {
            return false
        }
        #endif
        return onCreateSpreadTapped != nil || onCreateTaskTapped != nil || onCreateNoteTapped != nil
    }

    private func uiFont(for style: SpreadTitleNavigatorModel.Item.Style, selected: Bool) -> UIFont {
        switch style {
        case .year:
            return .preferredFont(forTextStyle: .title3)
        case .month:
            return .preferredFont(forTextStyle: .subheadline)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .body)
        }
    }

    private func itemWidth(for item: SpreadTitleNavigatorModel.Item) -> CGFloat {
        let bottomWidth = item.display.bottom.size(withAttributes: [
            .font: uiFont(for: item.style, selected: true)
        ]).width
        let topWidth = (item.display.top ?? "").size(withAttributes: [
            .font: topUIFont(for: item.style)
        ]).width
        return ceil(max(bottomWidth, topWidth) + 32)
    }

    private func topUIFont(for style: SpreadTitleNavigatorModel.Item.Style) -> UIFont {
        switch style {
        case .year:
            return .preferredFont(forTextStyle: .caption2)
        case .month:
            return .preferredFont(forTextStyle: .subheadline)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .caption2)
        }
    }

    private func leadingInset(for visibleWidth: CGFloat) -> CGFloat {
        guard let firstItem = items.first else { return max(visibleWidth / 2, 0) }
        return max((visibleWidth - itemWidth(for: firstItem)) / 2, 0)
    }

    private func trailingInset(for visibleWidth: CGFloat) -> CGFloat {
        guard let lastItem = items.last else { return max(visibleWidth / 2, 0) }
        return max((visibleWidth - itemWidth(for: lastItem)) / 2, 0)
    }

    private func identifier(for item: SpreadTitleNavigatorModel.Item) -> String {
        switch item.style {
        case .year:
            return "spreads.strip.year.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        case .month:
            return "spreads.strip.month.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        case .day:
            return "spreads.strip.day.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        case .multiday:
            return "spreads.strip.multiday.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        }
    }

    private func extraLeadingSpacing(for item: SpreadTitleNavigatorModel.Item, at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        switch item.style {
        case .month:
            return 10
        case .year, .day, .multiday:
            return 0
        }
    }

    private func returnButtonEdge(for visibleWidth: CGFloat) -> ReturnButtonEdge? {
        guard !isItemCentered(selectedItemID, visibleWidth: visibleWidth),
              let selectedFrame = itemFrames[selectedItemID] else {
            return nil
        }

        if selectedFrame.maxX < scrollContainerFrame.minX {
            return .leading
        }
        if selectedFrame.minX > scrollContainerFrame.maxX {
            return .trailing
        }
        return nil
    }

    private func recenterStrip(proxy: ScrollViewProxy, animated: Bool) {
        centerItem(id: selectedItemID, with: proxy, animated: animated)
    }

    private func requestCenter(on id: String) {
        centerRequestToken += 1
        centerRequest = CenterRequest(id: id, token: centerRequestToken)
    }

    private func centerItem(id: String, with proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(Self.selectionAnimation) {
                    proxy.scrollTo(id, anchor: .center)
                }
            } else {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    private func isItemCentered(_ id: String, visibleWidth: CGFloat) -> Bool {
        guard visibleWidth > 0,
              scrollContainerFrame.width > 0,
              let frame = itemFrames[id] else { return false }
        let viewportCenterX = scrollContainerFrame.midX
        let tolerance = max(frame.width / 2, 24)
        return abs(frame.midX - viewportCenterX) <= tolerance
    }
}

private struct SpreadTitleNavigatorItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
