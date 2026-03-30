import SwiftUI
import UIKit

struct SpreadTitleNavigatorView: View {
    private static let selectionAnimation = Animation.easeInOut(duration: 0.38)

    let stripModel: SpreadTitleNavigatorModel
    let headerNavigatorModel: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    let currentSelection: SpreadHeaderNavigatorModel.Selection
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onCreateSpreadTapped: (() -> Void)?
    let onCreateTaskTapped: (() -> Void)?
    let onCreateNoteTapped: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var scrollTargetItemID: String?
    @State private var isShowingNavigatorSurface = false
    @State private var scrollOffsetX: CGFloat = 0
    @State private var isScrollInteractionActive = false

    private var items: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    private var selectedItem: SpreadTitleNavigatorModel.Item? {
        let currentID = currentSelection.stableID(calendar: stripModel.calendar)
        return items.first(where: { $0.id == currentID })
    }

    var body: some View {
        GeometryReader { geometry in
            let scrollAreaWidth = max(geometry.size.width, 0)
            let metrics = stripModel.metrics(for: scrollAreaWidth)

            ZStack(alignment: .trailing) {
                scrollStripContainer(metrics: metrics, visibleWidth: scrollAreaWidth)
                if showsCreateButton {
                    createButton
                        .padding(.trailing, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 56)
        .secondaryPaperBackground()
        .onAppear {
            scrollTargetItemID = currentSelection.stableID(calendar: stripModel.calendar)
        }
        .onChange(of: currentSelection.stableID(calendar: stripModel.calendar)) { _, newValue in
            withAnimation(Self.selectionAnimation) {
                scrollTargetItemID = newValue
            }
        }
    }

    private func scrollStrip(
        metrics: SpreadTitleNavigatorModel.LayoutMetrics,
        visibleWidth: CGFloat
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: metrics.itemSpacing) {
                Color.clear
                    .frame(width: metrics.horizontalInset, height: 1)
                    .accessibilityHidden(true)

                ForEach(items) { item in
                    itemButton(for: item, slotWidth: metrics.slotWidth)
                        .id(item.id)
                }

                Color.clear
                    .frame(width: metrics.horizontalInset, height: 1)
                    .accessibilityHidden(true)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollTargetItemID, anchor: .center)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x
        } action: { _, newValue in
            scrollOffsetX = newValue
        }
        .onScrollPhaseChange { _, newPhase in
            switch newPhase {
            case .tracking, .interacting, .decelerating, .animating:
                isScrollInteractionActive = true
            case .idle:
                guard isScrollInteractionActive else { return }
                isScrollInteractionActive = false
                settleSelection(metrics: metrics, visibleWidth: visibleWidth)
            }
        }
    }

    private func scrollStripContainer(
        metrics: SpreadTitleNavigatorModel.LayoutMetrics,
        visibleWidth: CGFloat
    ) -> some View {
        ZStack {
            scrollStrip(metrics: metrics, visibleWidth: visibleWidth)
            selectedCapsuleOverlay
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                handleAdjacentDragEnded(value)
            }
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.container)
    }

    private func itemButton(for item: SpreadTitleNavigatorModel.Item, slotWidth: CGFloat) -> some View {
        let isSelected = item.id == currentSelection.stableID(calendar: stripModel.calendar)

        return Button {
            guard !isSelected else { return }
            withAnimation(Self.selectionAnimation) {
                scrollTargetItemID = item.id
            }
        } label: {
            HStack(spacing: 0) {
                Text(item.label)
                    .font(font(for: item.style, selected: isSelected))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
            .frame(width: slotWidth)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isSelected)
        .accessibilityIdentifier(isSelected ? Definitions.AccessibilityIdentifiers.SpreadStrip.selectedCapsule : identifier(for: item))
    }

    @ViewBuilder
    private var selectedCapsuleOverlay: some View {
        if let selectedItem {
            Capsule()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: selectedCapsuleWidth(for: selectedItem), height: 36)
                .animation(Self.selectionAnimation, value: selectedItem.id)
                .overlay {
                    Button {
                        isShowingNavigatorSurface = true
                    } label: {
                        Color.clear
                            .frame(width: selectedCapsuleWidth(for: selectedItem), height: 36)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
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
                .allowsHitTesting(true)
                .accessibilityHidden(true)
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

    private var trailingAccessoryWidth: CGFloat {
        (onCreateSpreadTapped != nil || onCreateTaskTapped != nil || onCreateNoteTapped != nil) ? 44 : 0
    }

    private var showsCreateButton: Bool {
        onCreateSpreadTapped != nil || onCreateTaskTapped != nil || onCreateNoteTapped != nil
    }

    private func font(for style: SpreadTitleNavigatorModel.Item.Style, selected: Bool) -> Font {
        switch style {
        case .year:
            return .headline.weight(selected ? .semibold : .regular)
        case .month:
            return .subheadline.weight(selected ? .semibold : .regular)
        case .day, .multiday:
            return .body.weight(selected ? .semibold : .regular)
        }
    }

    private func selectedCapsuleWidth(for item: SpreadTitleNavigatorModel.Item) -> CGFloat {
        let labelWidth = item.label.size(withAttributes: [
            .font: uiFont(for: item.style, selected: true)
        ]).width
        return ceil(labelWidth + 32)
    }

    private func uiFont(for style: SpreadTitleNavigatorModel.Item.Style, selected: Bool) -> UIFont {
        switch style {
        case .year:
            return .preferredFont(forTextStyle: .headline)
        case .month:
            return .preferredFont(forTextStyle: .subheadline)
        case .day, .multiday:
            return .preferredFont(forTextStyle: .body)
        }
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

    private func settleSelection(
        metrics: SpreadTitleNavigatorModel.LayoutMetrics,
        visibleWidth: CGFloat
    ) {
        guard !items.isEmpty else { return }

        let viewportCenterX = scrollOffsetX + (visibleWidth / 2)
        let stride = metrics.slotWidth + metrics.itemSpacing
        let nearestItem = items.enumerated().min { lhs, rhs in
            let lhsCenter = metrics.horizontalInset + (metrics.slotWidth / 2) + (CGFloat(lhs.offset) * stride)
            let rhsCenter = metrics.horizontalInset + (metrics.slotWidth / 2) + (CGFloat(rhs.offset) * stride)
            return abs(lhsCenter - viewportCenterX) < abs(rhsCenter - viewportCenterX)
        }?.element

        guard let nearestItem else { return }
        withAnimation(Self.selectionAnimation) {
            scrollTargetItemID = nearestItem.id
        }
        if nearestItem.id != currentSelection.stableID(calendar: stripModel.calendar) {
            onSelect(nearestItem.selection)
        }
    }

    private func handleAdjacentDragEnded(_ value: DragGesture.Value) {
        let threshold: CGFloat = 40
        guard abs(value.translation.width) > threshold,
              let currentIndex = items.firstIndex(where: {
                  $0.id == currentSelection.stableID(calendar: stripModel.calendar)
              }) else {
            return
        }

        let delta = value.translation.width < 0 ? 1 : -1
        let candidateIndex = currentIndex + delta
        guard items.indices.contains(candidateIndex) else { return }

        withAnimation(Self.selectionAnimation) {
            scrollTargetItemID = items[candidateIndex].id
        }
    }
}
