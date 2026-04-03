import SwiftUI
import UIKit

struct SpreadTitleNavigatorView: View {
    private static let selectionAnimation = Animation.easeInOut(duration: 0.38)
    private static let itemSpacing: CGFloat = 12
    private static let minimumHeight: CGFloat = 84

    private struct EdgeFadeConfiguration {
        let width: CGFloat = 64
        let maxOpacity: Double = 1
    }

    private struct CenterRequest: Equatable {
        let semanticID: String
        let animated: Bool
        let token: Int
    }

    #if DEBUG
    private static let debugHideCreateButton = true
    #endif

    let stripModel: SpreadTitleNavigatorModel
    let headerNavigatorModel: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    let currentSelection: SpreadHeaderNavigatorModel.Selection
    let recenterToken: Int
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onCreateSpreadTapped: (() -> Void)?
    let onCreateTaskTapped: (() -> Void)?
    let onCreateNoteTapped: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingNavigatorSurface = false
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var scrollContainerFrame: CGRect = .zero
    @State private var scrollViewportWidth: CGFloat = 0
    @State private var centerRequest: CenterRequest?
    @State private var centerRequestToken = 0
    @State private var widthChangeCenterToken = 0

    private let edgeFade = EdgeFadeConfiguration()

    private var items: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    private var selectedItemID: String {
        currentSelection.stableID(calendar: stripModel.calendar)
    }

    private var sharedItemWidth: CGFloat {
        let measuredWidths = items.map(itemWidth(for:))
        return measuredWidths.max() ?? 56
    }

    private var showsRecenterButton: Bool {
        selectedFrame != nil && !isSelectedCentered
    }

    private var selectedFrame: CGRect? {
        itemFrames[selectedItemID]
    }

    private var isSelectedCentered: Bool {
        guard scrollContainerFrame.width > 0, let selectedFrame else { return false }
        let tolerance = max(selectedFrame.width / 2, 24)
        return abs(selectedFrame.midX - scrollContainerFrame.midX) <= tolerance
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            scrollStripContainer(visibleWidth: scrollViewportWidth)
            edgeFadeOverlays
            overlayButtons
            if showsCreateButton {
                createButton
                    .padding(.trailing, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: Self.minimumHeight)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        handleWidthChange(to: geometry.size.width)
                    }
                    .onChange(of: geometry.size.width) { _, newValue in
                        handleWidthChange(to: newValue)
                    }
            }
        )
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
                                requestCenter(on: selection.stableID(calendar: stripModel.calendar), animated: true)
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
                            .id(stripID(for: item.id))
                            .padding(.leading, extraLeadingSpacing(for: item, at: index))
                    }

                    Color.clear
                        .frame(width: trailingInset(for: visibleWidth), height: 1)
                        .accessibilityHidden(true)
                }
                .scrollTargetLayout()
                .backgroundPreferenceValue(SpreadTitleNavigatorItemFramePreferenceKey.self) { frames in
                    Color.clear
                        .onAppear { itemFrames = frames }
                        .onChange(of: frames) { _, newValue in
                            itemFrames = newValue
                        }
                }
            }
            .coordinateSpace(name: "SpreadTitleNavigatorScroll")
            .scrollTargetBehavior(.viewAligned)
            .task(id: items.map(\.id)) {
                requestCenter(on: selectedItemID, animated: false)
            }
            .onChange(of: recenterToken) { _, _ in
                requestCenter(on: selectedItemID, animated: true)
            }
            .onChange(of: widthChangeCenterToken) { _, _ in
                requestCenter(on: selectedItemID, animated: false)
            }
            .onChange(of: centerRequest) { _, newValue in
                guard let newValue else { return }
                centerItem(semanticID: newValue.semanticID, with: proxy, animated: newValue.animated)
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

    @ViewBuilder
    private var overlayButtons: some View {
        HStack {
            selectSpreadButton
            Spacer(minLength: 0)
            if showsRecenterButton {
                recenterButton
            }
        }
        .padding(.horizontal, 8)
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var edgeFadeOverlays: some View {
        HStack(spacing: 0) {
            edgeFadeView(edge: .leading)
            Spacer(minLength: 0)
            edgeFadeView(edge: .trailing)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var selectSpreadButton: some View {
        Button {
            isShowingNavigatorSurface = true
        } label: {
            HStack(spacing: 6) {
                Text("Select Spread")
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.selectSpreadButton)
    }

    private var recenterButton: some View {
        Button {
            requestCenter(on: selectedItemID, animated: true)
        } label: {
            Text("Recenter")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.recenterButton)
    }

    private func itemButton(for item: SpreadTitleNavigatorModel.Item) -> some View {
        let isSelected = item.id == selectedItemID

        return Button {
            if isSelected {
                if !isSelectedCentered {
                    requestCenter(on: item.id, animated: true)
                }
            } else {
                requestCenter(on: item.id, animated: true)
                onSelect(item.selection)
            }
        } label: {
            itemLabel(for: item, selected: isSelected)
                .padding(.vertical, 6)
                .frame(width: sharedItemWidth)
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
                            value: [item.id: geometry.frame(in: .global)]
                        )
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            isSelected
                ? Definitions.AccessibilityIdentifiers.SpreadStrip.selectedCapsule
                : identifier(for: item)
        )
    }

    @ViewBuilder
    private func itemLabel(for item: SpreadTitleNavigatorModel.Item, selected: Bool) -> some View {
        switch item.style {
        case .year:
            VStack(spacing: -2) {
                if let top = item.display.top {
                    Text(top)
                        .font(.title3.weight(selected ? .bold : .semibold))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                }
                Text(item.display.bottom)
                    .font(.title3.weight(selected ? .bold : .semibold))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
            }
        case .month:
            Text(item.display.bottom)
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .textCase(.uppercase)
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
                if let footer = item.display.footer {
                    Text(footer)
                        .font(.caption2.smallCaps())
                        .fontWeight(.medium)
                        .foregroundStyle(selected ? Color.primary : Color.secondary.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
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

    @ViewBuilder
    private func edgeFadeView(edge: FadeEdge) -> some View {
        LinearGradient(
            colors: gradientColors(for: edge),
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .frame(width: edgeFade.width)
        .opacity(showsFade(edge: edge) ? edgeFade.maxOpacity : 0)
    }

    private var showsCreateButton: Bool {
        #if DEBUG
        if Self.debugHideCreateButton {
            return false
        }
        #endif
        return onCreateSpreadTapped != nil || onCreateTaskTapped != nil || onCreateNoteTapped != nil
    }

    private enum FadeEdge {
        case leading
        case trailing
    }

    private func uiFont(for style: SpreadTitleNavigatorModel.Item.Style) -> UIFont {
        switch style {
        case .year:
            return .preferredFont(forTextStyle: .title3)
        case .month:
            return .preferredFont(forTextStyle: .subheadline)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .body)
        }
    }

    private func topUIFont(for style: SpreadTitleNavigatorModel.Item.Style) -> UIFont {
        switch style {
        case .year:
            return .preferredFont(forTextStyle: .title3)
        case .month:
            return .preferredFont(forTextStyle: .subheadline)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .caption2)
        }
    }

    private func footerUIFont(for style: SpreadTitleNavigatorModel.Item.Style) -> UIFont {
        switch style {
        case .day, .multiday:
            return .preferredFont(forTextStyle: .caption2)
        case .year, .month:
            return .preferredFont(forTextStyle: .body)
        }
    }

    private func itemWidth(for item: SpreadTitleNavigatorModel.Item) -> CGFloat {
        let bottomWidth = item.display.bottom.size(withAttributes: [
            .font: uiFont(for: item.style)
        ]).width
        let topWidth = (item.display.top ?? "").size(withAttributes: [
            .font: topUIFont(for: item.style)
        ]).width
        let footerWidth = (item.display.footer ?? "").size(withAttributes: [
            .font: footerUIFont(for: item.style)
        ]).width
        return ceil(max(bottomWidth, topWidth, footerWidth) + 32)
    }

    private func leadingInset(for visibleWidth: CGFloat) -> CGFloat {
        guard visibleWidth > 0 else { return 0 }
        return max((visibleWidth - sharedItemWidth) / 2, 0)
    }

    private func trailingInset(for visibleWidth: CGFloat) -> CGFloat {
        guard visibleWidth > 0 else { return 0 }
        return max((visibleWidth - sharedItemWidth) / 2, 0)
    }

    private func stripID(for semanticID: String) -> String {
        "strip.\(semanticID)"
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

    private func showsFade(edge: FadeEdge) -> Bool {
        guard scrollContainerFrame.width > 0 else { return false }

        let fadeRegion: CGRect
        switch edge {
        case .leading:
            fadeRegion = CGRect(
                x: scrollContainerFrame.minX,
                y: scrollContainerFrame.minY,
                width: edgeFade.width,
                height: scrollContainerFrame.height
            )
        case .trailing:
            fadeRegion = CGRect(
                x: scrollContainerFrame.maxX - edgeFade.width,
                y: scrollContainerFrame.minY,
                width: edgeFade.width,
                height: scrollContainerFrame.height
            )
        }

        return itemFrames.values.contains { $0.intersects(fadeRegion) }
    }

    private func gradientColors(for edge: FadeEdge) -> [Color] {
        let base = SpreadTheme.Paper.secondary
        return [
            base.opacity(edgeFade.maxOpacity),
            base.opacity(0)
        ]
    }

    private func handleWidthChange(to newWidth: CGFloat) {
        let previousWidth = scrollViewportWidth
        let shouldMaintainSelectionCenter = isSelectedCentered
        scrollViewportWidth = max(newWidth, 0)

        guard previousWidth > 0,
              abs(previousWidth - newWidth) > 1,
              shouldMaintainSelectionCenter else {
            return
        }
        widthChangeCenterToken += 1
    }

    private func requestCenter(on semanticID: String, animated: Bool) {
        centerRequestToken += 1
        centerRequest = CenterRequest(
            semanticID: semanticID,
            animated: animated,
            token: centerRequestToken
        )
    }

    private func centerItem(semanticID: String, with proxy: ScrollViewProxy, animated: Bool) {
        let targetID = stripID(for: semanticID)
        DispatchQueue.main.async {
            if animated {
                withAnimation(Self.selectionAnimation) {
                    proxy.scrollTo(targetID, anchor: .center)
                }
            } else {
                proxy.scrollTo(targetID, anchor: .center)
            }
        }
    }
}

private struct SpreadTitleNavigatorItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
