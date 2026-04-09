import SwiftUI
import UIKit

struct SpreadTitleNavigatorView: View {
    private static let itemSpacing: CGFloat = 12
    private static let recommendationFadeWidth: CGFloat = 50
    private static let recommendationCornerRadius: CGFloat = 10

    let stripModel: SpreadTitleNavigatorModel
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
    @Namespace private var selectionIndicatorNamespace

    private var items: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: selection)
    }

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
            ScrollView(.horizontal, showsIndicators: false) {
                itemRow
            }
            .mask(mainStripMask)
            .frame(maxWidth: .infinity)
            if !recommendations.isEmpty {
                recommendationInset
                    .padding(.leading, 12)
            }
        }
        .coordinateSpace(name: "SpreadTitleNavigatorScroll")
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $stripCenteredTargetID, anchor: .center)
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
        .frame(maxWidth: .infinity)
        .task(id: items.map(\.id)) {
            requestCenter(on: selectedSemanticID, animated: false)
        }
        .onChange(of: recenterToken) { _, _ in
            requestCenter(on: selectedSemanticID, animated: true)
        }
        .onChange(of: widthChangeCenterToken) { _, _ in
            requestCenter(on: selectedSemanticID, animated: false)
        }
        .secondaryPaperBackground()
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.container)
    }

    private var itemRow: some View {
        HStack(spacing: Self.itemSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                itemView(for: item, index: index)
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

    private func itemView(for item: SpreadTitleNavigatorModel.Item, index: Int) -> some View {
        let itemIdentifier = item.id == selectedSemanticID
            ? Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
            : identifier(for: item)
        return SpreadTitleNavigatorItemView(
            semanticID: item.id,
            style: item.style,
            display: item.display,
            overdueCount: item.overdueCount,
            isSelected: item.id == selectedSemanticID,
            accessibilityIdentifier: itemIdentifier,
            overdueBadgeAccessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadStrip.overdueBadge(itemIdentifier),
            selectionIndicatorNamespace: selectionIndicatorNamespace,
            showsSelectionIndicator: true,
            borderColor: nil,
            emphasisColor: SpreadTheme.Accent.todayEmphasis,
            selectedEmphasisColor: SpreadTheme.Accent.todaySelectedEmphasis,
            horizontalPadding: 16,
            action: {
                handleItemTap(item)
            },
            isTodayEmphasized: item.id == todaySemanticID
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
            overdueCount: 0,
            isSelected: false,
            accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadStrip.recommendation(
                recommendation.period.rawValue
            ),
            overdueBadgeAccessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadStrip.overdueBadge(
                Definitions.AccessibilityIdentifiers.SpreadStrip.recommendation(recommendation.period.rawValue)
            ),
            selectionIndicatorNamespace: selectionIndicatorNamespace,
            showsSelectionIndicator: false,
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

    private func handleItemTap(_ item: SpreadTitleNavigatorModel.Item) {
        let isSelected = item.id == selectedSemanticID
        if !isSelected {
            requestCenter(on: item.id, animated: true)
            selection = item.selection
        }
    }

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
            return .preferredFont(forTextStyle: .subheadline)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .caption2)
        }
    }

    private func footerUIFont(for style: SpreadTitleNavigatorItemStyle) -> UIFont {
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
