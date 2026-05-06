import SwiftUI
import UIKit

private enum StripRenderElement: Identifiable {
    case item(SpreadTitleNavigatorModel.Item, index: Int)
    case groupHeader(SpreadTitleNavigatorGroup)
    case expandedItem(SpreadTitleNavigatorModel.Item, index: Int)

    var id: String {
        switch self {
        case .item(let item, _): return "render.item.\(item.id)"
        case .groupHeader(let group): return "render.group.\(group.id)"
        case .expandedItem(let item, _): return "render.expanded.\(item.id)"
        }
    }
}

struct SpreadTitleNavigatorView: View {
    private static let itemSpacing: CGFloat = 12
    private static let recommendationFadeWidth: CGFloat = 50
    private static let recommendationCornerRadius: CGFloat = 10

    let stripModel: SpreadTitleNavigatorModel
    let fullItems: [SpreadTitleNavigatorModel.Item]
    let items: [SpreadTitleNavigatorModel.Item]
    let recenterToken: Int
    let onRecommendedSpreadTapped: ((SpreadTitleNavigatorRecommendation) -> Void)?
    let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding
    @Binding var selection: SpreadHeaderNavigatorModel.Selection

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var recommendationHeights: [String: CGFloat] = [:]
    @State private var recommendationWidths: [String: CGFloat] = [:]
    @State private var scrollContainerFrame: CGRect = .zero
    @State private var scrollViewportWidth: CGFloat = 0
    @State private var stripCenteredTargetID: String?
    @State private var widthChangeCenterToken = 0
    @State private var isShowingNavigator = false
    @State private var expandedGroupID: String?
    @State private var cachedStripElements: [SpreadTitleNavigatorStripElement] = []

    private var selectedSemanticID: String {
        selection.stableID(calendar: stripModel.calendar)
    }

    private var todaySemanticID: String? {
        stripModel.todaySemanticID(for: selection)
    }

    private var recommendations: [SpreadTitleNavigatorRecommendation] {
        recommendationProvider.recommendations(for: stripModel.headerModel)
    }

    private var selectedFrame: CGRect? {
        itemFrames[selectedSemanticID]
    }

    private var renderElements: [StripRenderElement] {
        var result: [StripRenderElement] = []
        var itemIndex = 0

        for element in cachedStripElements {
            switch element {
            case .item(let item):
                result.append(.item(item, index: itemIndex))
                itemIndex += 1
            case .group(let group):
                result.append(.groupHeader(group))
                if expandedGroupID == group.id {
                    for (idx, item) in group.items.enumerated() {
                        result.append(.expandedItem(item, index: idx))
                    }
                }
            }
        }

        return result
    }

    private var currentNavigatorSpread: DataModel.Spread {
        switch selection {
        case .conventional(let spread):
            return spread
        case .traditionalYear(let date):
            return DataModel.Spread(period: .year, date: date, calendar: stripModel.calendar)
        case .traditionalMonth(let date):
            return DataModel.Spread(period: .month, date: date, calendar: stripModel.calendar)
        case .traditionalDay(let date):
            return DataModel.Spread(period: .day, date: date, calendar: stripModel.calendar)
        }
    }

    private var recommendationCardSize: CGSize? {
        SpreadTitleNavigatorRecommendationLayout.cardSize(
            widths: Array(recommendationWidths.values),
            heights: Array(recommendationHeights.values)
        )
    }

    private var collapsesRecommendationsToMenu: Bool {
        SpreadTitleNavigatorRecommendationLayout.collapsesToMenu(
            horizontalSizeClass: horizontalSizeClass,
            recommendationCount: recommendations.count
        )
    }

    private var isSelectedCentered: Bool {
        guard scrollContainerFrame.width > 0, let selectedFrame else { return false }
        let tolerance = max(selectedFrame.width / 2, 24)
        return abs(selectedFrame.midX - scrollContainerFrame.midX) <= tolerance
    }

    var body: some View {
        HStack(spacing: 0) {
            navigatorTrigger
                .padding(.leading, 12)
                .padding(.trailing, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                itemRow
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $stripCenteredTargetID, anchor: .center)
            .mask(mainStripMask)
            .frame(maxWidth: .infinity)
            if !recommendations.isEmpty {
                recommendationInset
                    .padding(.leading, 12)
            }
        }
        .coordinateSpace(name: "SpreadTitleNavigatorScroll")
        .contentShape(Rectangle())
        .overlay {
            recommendationMeasurementRow
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        scrollContainerFrame = geometry.frame(in: .global)
                        handleWidthChange(to: geometry.size.width)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _, newValue in
                        scrollContainerFrame = newValue
                    }
                    .onChange(of: geometry.size.width) { _, newValue in
                        handleWidthChange(to: newValue)
                    }
            }
        )
        .overlay(alignment: .topLeading) {
            selectionIndicatorOverlay
        }
        .frame(maxWidth: .infinity)
        .task(id: fullItems.map(\.id) + items.map(\.id)) {
            cachedStripElements = SpreadTitleNavigatorStripElementBuilder.elements(
                fullItems: fullItems,
                filteredItems: items
            )
            cleanupExpandedGroupIfNeeded()
            requestCenterIfVisible(on: selectedSemanticID, animated: false)
        }
        .onChange(of: selectedSemanticID) { _, newValue in
            autoCollapseGroupIfNeeded(for: newValue)
            requestCenterIfVisible(on: newValue, animated: true)
        }
        .onChange(of: recenterToken) { _, _ in
            requestCenterIfVisible(on: selectedSemanticID, animated: true)
        }
        .onChange(of: widthChangeCenterToken) { _, _ in
            requestCenterIfVisible(on: selectedSemanticID, animated: false)
        }
        .secondaryPaperBackground()
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.container)
    }

    private var navigatorTrigger: some View {
        Button {
            isShowingNavigator = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 32, height: 38)

                Color.clear.frame(height: 8)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Spread Navigator")
        .accessibilityHint("Shows all spreads in the rooted navigator.")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.selectSpreadButton)
        .spreadNavigatorPresentation(
            isPresented: $isShowingNavigator,
            presentsAsPopover: SpreadNavigatorPresentationSupport.presentsAsPopover(horizontalSizeClass: horizontalSizeClass),
            model: stripModel.headerModel,
            currentSpread: currentNavigatorSpread,
            onSelect: handleNavigatorSelection
        )
    }

    private var itemRow: some View {
        HStack(spacing: Self.itemSpacing) {
            ForEach(renderElements) { element in
                renderElement(element)
            }
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

    @ViewBuilder
    private func renderElement(_ element: StripRenderElement) -> some View {
        switch element {
        case .item(let item, let index):
            itemView(for: item, index: index, isHidden: false)
        case .groupHeader(let group):
            let isExpanded = expandedGroupID == group.id
            let containsSelection = group.containsItem(withID: selectedSemanticID)
            SpreadTitleNavigatorGroupView(
                group: group,
                isExpanded: isExpanded,
                containsSelection: containsSelection,
                selectedItemSemanticID: containsSelection && !isExpanded ? selectedSemanticID : nil,
                onExpand: { expandGroup(group) },
                onCollapse: { collapseCurrentGroup() }
            )
        case .expandedItem(let item, let index):
            itemView(for: item, index: index, isHidden: true)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    private func itemView(for item: SpreadTitleNavigatorModel.Item, index: Int, isHidden: Bool) -> some View {
        let itemIdentifier = item.id == selectedSemanticID
            ? Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
            : identifier(for: item)
        return SpreadTitleNavigatorItemView(
            semanticID: item.id,
            style: item.style,
            display: item.display,
            badge: item.badge,
            isSelected: item.id == selectedSemanticID,
            accessibilityIdentifier: itemIdentifier,
            badgeAccessibilityIdentifier: item.badge?.accessibilityIdentifier(
                for: item.selection,
                calendar: stripModel.calendar
            ),
            borderColor: nil,
            emphasisColor: SpreadTheme.Accent.todayEmphasis,
            selectedEmphasisColor: SpreadTheme.Accent.todaySelectedEmphasis,
            horizontalPadding: 16,
            action: {
                handleItemTap(item)
            },
            isTodayEmphasized: item.id == todaySemanticID,
            isHidden: isHidden
        )
        .id(stripID(for: item.id))
        .padding(.leading, extraLeadingSpacing(for: item, at: index))
    }

    private var recommendationInset: some View {
        HStack(spacing: Self.itemSpacing) {
            if collapsesRecommendationsToMenu {
                recommendationMenuTrigger
            } else {
                ForEach(recommendations) { recommendation in
                    recommendationCard(for: recommendation)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .padding(.trailing, 12)
    }

    @ViewBuilder
    private var mainStripMask: some View {
        if recommendations.isEmpty {
            Rectangle()
        } else {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black)
                LinearGradient(
                    colors: [
                        .black,
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: Self.recommendationFadeWidth)
            }
        }
    }

    @ViewBuilder
    private var recommendationMeasurementRow: some View {
        HStack(spacing: Self.itemSpacing) {
            ForEach(recommendations) { recommendation in
                recommendationMeasurementCard(for: recommendation)
            }
        }
        .hidden()
        .allowsHitTesting(false)
        .onPreferenceChange(SpreadTitleNavigatorRecommendationHeightPreferenceKey.self) { newValue in
            recommendationHeights = newValue
        }
        .onPreferenceChange(SpreadTitleNavigatorRecommendationWidthPreferenceKey.self) { newValue in
            recommendationWidths = newValue
        }
    }

    private func recommendationCard(for recommendation: SpreadTitleNavigatorRecommendation) -> some View {
        Button {
            onRecommendedSpreadTapped?(recommendation)
        } label: {
            recommendationBaseCard(for: recommendation)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            // Keep the recommendation tap from being swallowed by the surrounding scroll gesture arena.
        })
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.recommendation(
            recommendation.period.rawValue
        ))
    }

    private func recommendationMeasurementCard(for recommendation: SpreadTitleNavigatorRecommendation) -> some View {
        recommendationBaseCard(for: recommendation)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: SpreadTitleNavigatorRecommendationHeightPreferenceKey.self,
                            value: [recommendation.id: geometry.size.height]
                        )
                        .preference(
                            key: SpreadTitleNavigatorRecommendationWidthPreferenceKey.self,
                            value: [recommendation.id: geometry.size.width]
                        )
                }
            )
    }

    private func recommendationBaseCard(for recommendation: SpreadTitleNavigatorRecommendation) -> some View {
        let item = stripModel.item(for: recommendation)
        let content = SpreadTitleNavigatorItemView(
            semanticID: item.id,
            style: item.style,
            display: item.display,
            badge: nil,
            isSelected: false,
            accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadStrip.recommendation(
                recommendation.period.rawValue
            ),
            badgeAccessibilityIdentifier: nil,
            borderColor: nil,
            emphasisColor: SpreadTheme.Accent.todayEmphasis,
            selectedEmphasisColor: SpreadTheme.Accent.todaySelectedEmphasis,
            horizontalPadding: 0,
            action: {},
            isInteractive: false,
            isTodayEmphasized: item.id == todaySemanticID
        )

        return Group {
            if let recommendationCardSize {
                content
                    .frame(width: recommendationCardSize.width, height: recommendationCardSize.height)
            } else {
                content
            }
        }
        .glowingShimmer(
            cornerRadius: Self.recommendationCornerRadius,
            speed: 2.4,
            borderWidth: 2.2,
            blurRadius: 3.5
        )
    }

    private var recommendationMenuTrigger: some View {
        Menu {
            ForEach(recommendations) { recommendation in
                Button(recommendation.fullTitle) {
                    onRecommendedSpreadTapped?(recommendation)
                }
            }
        } label: {
            Group {
                if let recommendationCardSize {
                    recommendationMenuLabel
                        .frame(width: recommendationCardSize.width, height: recommendationCardSize.height)
                } else {
                    recommendationMenuLabel
                }
            }
        }
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadStrip.recommendation("menu")
        )
    }

    private var recommendationMenuLabel: some View {
        VStack {
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.secondary)
            Spacer(minLength: 0)
        }
        .frame(minWidth: 28, minHeight: 48)
        .contentShape(Rectangle())
        .glowingShimmer(
            cornerRadius: Self.recommendationCornerRadius,
            speed: 2.4,
            borderWidth: 2.2,
            blurRadius: 3.5
        )
    }

    // MARK: - Selection Indicator

    /// Single dot drawn as a strip overlay at a fixed vertical position, tracking the selected
    /// item's horizontal location via `itemFrames`. Using an overlay avoids the vertical
    /// animation artefacts that `matchedGeometryEffect` produces when items have different heights.
    @ViewBuilder
    private var selectionIndicatorOverlay: some View {
        if let frame = itemFrames[selectedSemanticID], scrollContainerFrame.width > 0 {
            let dotCenterX = frame.midX - scrollContainerFrame.minX
            let dotCenterY = scrollContainerFrame.height - 6
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .offset(x: dotCenterX - 3, y: dotCenterY - 3)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Group Expansion

    private func expandGroup(_ group: SpreadTitleNavigatorGroup) {
        withAnimation(.easeInOut(duration: 0.28)) {
            expandedGroupID = group.id
        }
        let semanticID = selectedSemanticID
        if group.containsItem(withID: semanticID) {
            requestCenter(on: semanticID, animated: true)
        }
    }

    private func collapseCurrentGroup() {
        withAnimation(.easeInOut(duration: 0.28)) {
            expandedGroupID = nil
        }
    }

    private func autoCollapseGroupIfNeeded(for newSemanticID: String) {
        guard let expandedID = expandedGroupID else { return }
        let isInsideGroup = cachedStripElements.contains { element in
            if case .group(let group) = element, group.id == expandedID {
                return group.containsItem(withID: newSemanticID)
            }
            return false
        }
        if !isInsideGroup {
            withAnimation(.easeInOut(duration: 0.28)) {
                expandedGroupID = nil
            }
        }
    }

    private func cleanupExpandedGroupIfNeeded() {
        guard let expandedID = expandedGroupID else { return }
        let groupExists = cachedStripElements.contains { element in
            if case .group(let group) = element { return group.id == expandedID }
            return false
        }
        if !groupExists {
            expandedGroupID = nil
        }
    }

    // MARK: - Item Actions

    private func handleItemTap(_ item: SpreadTitleNavigatorModel.Item) {
        guard let nextSelection = SpreadTitleNavigatorTapSupport.selectionChange(
            for: item,
            selectedSemanticID: selectedSemanticID
        ) else {
            return
        }
        selection = nextSelection
        requestCenter(on: item.id, animated: true)
    }

    private func handleNavigatorSelection(_ nextSelection: SpreadHeaderNavigatorModel.Selection) {
        selection = nextSelection
        let nextID = nextSelection.stableID(calendar: stripModel.calendar)
        if items.contains(where: { $0.id == nextID }) {
            requestCenter(on: nextID, animated: true)
        }
    }

    // MARK: - Layout Helpers

    private func uiFont(for style: SpreadTitleNavigatorItemStyle) -> UIFont {
        switch style {
        case .year:
            return .preferredFont(forTextStyle: .title3)
        case .month:
            return .preferredFont(forTextStyle: .subheadline)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .body)
        }
    }

    private func topUIFont(for style: SpreadTitleNavigatorItemStyle) -> UIFont {
        switch style {
        case .year:
            return .preferredFont(forTextStyle: .title3)
        case .month:
            return .preferredFont(forTextStyle: .caption2)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .caption2)
        }
    }

    private func footerUIFont(for style: SpreadTitleNavigatorItemStyle) -> UIFont {
        switch style {
        case .year, .month:
            return .preferredFont(forTextStyle: .caption2)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .caption2)
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
        let firstWidth = items.first.map(itemWidth(for:)) ?? 0
        return max((visibleWidth - firstWidth) / 2, 0)
    }

    private func trailingInset(for visibleWidth: CGFloat) -> CGFloat {
        guard visibleWidth > 0 else { return 0 }
        let lastWidth = items.last.map(itemWidth(for:)) ?? 0
        return max((visibleWidth - lastWidth) / 2, 0)
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

    // MARK: - Scroll Centering

    private func requestCenter(on semanticID: String, animated: Bool) {
        let targetID = stripID(for: semanticID)
        if animated {
            withAnimation(.easeInOut(duration: 0.38)) {
                stripCenteredTargetID = targetID
            }
        } else {
            stripCenteredTargetID = targetID
        }
    }

    private func requestCenterIfVisible(on semanticID: String, animated: Bool) {
        let isInVisibleItems = items.contains(where: { $0.id == semanticID })
        let isInExpandedGroup = isItemInExpandedGroup(semanticID: semanticID)
        guard isInVisibleItems || isInExpandedGroup else { return }
        requestCenter(on: semanticID, animated: animated)
    }

    private func isItemInExpandedGroup(semanticID: String) -> Bool {
        guard let expandedID = expandedGroupID else { return false }
        return cachedStripElements.first {
            if case .group(let g) = $0 { return g.id == expandedID }
            return false
        }.flatMap { element -> SpreadTitleNavigatorGroup? in
            if case .group(let g) = element { return g }
            return nil
        }?.containsItem(withID: semanticID) ?? false
    }
}

struct SpreadTitleNavigatorRecommendationHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct SpreadTitleNavigatorRecommendationWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
