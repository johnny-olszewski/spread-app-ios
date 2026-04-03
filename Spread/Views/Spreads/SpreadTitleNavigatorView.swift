import SwiftUI

/// Horizontal spread title navigator strip.
///
/// Displays a scrollable sequence of spread items. The selected item is centered
/// and shown with a capsule background. Tapping a non-selected item selects it
/// and centers it in the strip. Tapping the selected capsule opens the rooted
/// navigator surface (popover on iPad, sheet on iPhone).
///
/// When the selected item is scrolled fully out of view, a liquid-glass return
/// button appears at the nearer edge. Tapping it re-centers the strip on the
/// selected item without changing selection or affecting the content pager.
struct SpreadTitleNavigatorView: View {

    // MARK: - Constants

    private static let selectionAnimation = Animation.easeInOut(duration: 0.38)
    private static let itemSpacing: CGFloat = 12
    private static let edgeFadeWidth: CGFloat = 64
    private static let itemVerticalPadding: CGFloat = 10

    // MARK: - Properties

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
    @State private var scrollPosition = ScrollPosition()
    @State private var visibleItemIDs: Set<String> = []

    // MARK: - Derived

    private var items: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: currentSelection)
    }

    private var selectedItemID: String {
        currentSelection.stableID(calendar: stripModel.calendar)
    }

    private var isSelectedItemVisible: Bool {
        visibleItemIDs.contains(stripScrollID(selectedItemID))
    }

    private var returnButtonEdge: ReturnButtonEdge? {
        guard !isSelectedItemVisible else { return nil }
        guard let selectedIndex = items.firstIndex(where: { $0.id == selectedItemID }) else { return nil }
        let visibleIndices = items.indices.filter { visibleItemIDs.contains(stripScrollID(items[$0].id)) }
        guard let minVisible = visibleIndices.min() else { return nil }
        return selectedIndex < minVisible ? .leading : .trailing
    }

    private var showsLeadingFade: Bool {
        guard let first = items.first else { return false }
        return !visibleItemIDs.contains(stripScrollID(first.id))
    }

    private var showsTrailingFade: Bool {
        guard let last = items.last else { return false }
        return !visibleItemIDs.contains(stripScrollID(last.id))
    }

    private var showsCreateButton: Bool {
        onCreateSpreadTapped != nil || onCreateTaskTapped != nil || onCreateNoteTapped != nil
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .trailing) {
            stripScrollView
            edgeFadeOverlays
            if let edge = returnButtonEdge {
                returnToSelectedButton(edge: edge)
            }
            if showsCreateButton {
                createButton.padding(.trailing, 12)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
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
                            onSelect: { onSelect($0) },
                            onDismiss: { isShowingNavigatorSurface = false }
                        )
                    )
                }
            )
        )
    }

    // MARK: - Strip

    private var stripScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.itemSpacing) {
                centeringspacer
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    itemButton(for: item)
                        .id(stripScrollID(item.id))
                        .padding(.leading, extraLeadingSpacing(for: item, at: index))
                }
                centeringspacer
            }
            .padding(.vertical, Self.itemVerticalPadding)
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        .scrollTargetBehavior(.viewAligned)
        .contentShape(Rectangle())
        .onScrollTargetVisibilityChange(idType: String.self) { visibleItemIDs = Set($0) }
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { _, _ in
            centerOnSelected(animated: false)
        }
        .task(id: items.map(\.id)) {
            centerOnSelected(animated: false)
            #if DEBUG
            print("[SpreadTitleNavigatorView] task recenter target=\(selectedItemID) items=\(items.map(\.label))")
            #endif
        }
        .onChange(of: selectedItemID) { _, _ in
            centerOnSelected(animated: true)
        }
        .onChange(of: recenterToken) { _, _ in
            centerOnSelected(animated: true)
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.container)
    }

    /// A spacer occupying half the scroll view's visible width so the first and
    /// last items can be scrolled to the center of the strip.
    private var centeringspacer: some View {
        Color.clear
            .containerRelativeFrame(.horizontal) { w, _ in w / 2 }
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private func centerOnSelected(animated: Bool) {
        let id = stripScrollID(selectedItemID)
        if animated {
            withAnimation(Self.selectionAnimation) {
                scrollPosition.scrollTo(id: id, anchor: .center)
            }
        } else {
            scrollPosition.scrollTo(id: id, anchor: .center)
        }
    }

    /// Prefixes a strip item's scroll ID to decouple it from the pager's
    /// `scrollPosition(id:)`, preventing strip scroll events from leaking
    /// into the pager.
    private func stripScrollID(_ id: String) -> String {
        "strip.\(id)"
    }

    // MARK: - Item Button

    private func itemButton(for item: SpreadTitleNavigatorModel.Item) -> some View {
        let isSelected = item.id == selectedItemID
        return Button {
            if isSelected {
                isShowingNavigatorSurface = true
            } else {
                #if DEBUG
                print("[Strip] item tapped → onSelect: \(item.id)")
                #endif
                withAnimation(Self.selectionAnimation) {
                    scrollPosition.scrollTo(id: stripScrollID(item.id), anchor: .center)
                }
                onSelect(item.selection)
            }
        } label: {
            itemLabel(for: item, selected: isSelected)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.16))
                    }
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
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

    // MARK: - Return Button

    private enum ReturnButtonEdge {
        case leading
        case trailing
    }

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
            #if DEBUG
            print("[Strip] return button tapped (edge=\(edge)) selectedItemID=\(selectedItemID)")
            #endif
            centerOnSelected(animated: true)
        } label: {
            Image(systemName: edge == .leading ? "arrow.left" : "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .glassEffect(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("spreads.strip.returnToSelected")
    }

    // MARK: - Edge Fades

    private enum FadeEdge {
        case leading
        case trailing
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

    @ViewBuilder
    private func edgeFadeView(edge: FadeEdge) -> some View {
        let isVisible = edge == .leading ? showsLeadingFade : showsTrailingFade
        LinearGradient(
            colors: [SpreadTheme.Paper.secondary, SpreadTheme.Paper.secondary.opacity(0)],
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .frame(width: Self.edgeFadeWidth)
        .opacity(isVisible ? 1 : 0)
    }

    // MARK: - Create Button

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

    // MARK: - Helpers

    private func extraLeadingSpacing(for item: SpreadTitleNavigatorModel.Item, at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        switch item.style {
        case .month: return 10
        case .year, .day, .multiday: return 0
        }
    }

    private func identifier(for item: SpreadTitleNavigatorModel.Item) -> String {
        switch item.style {
        case .year:   return "spreads.strip.year.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        case .month:  return "spreads.strip.month.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        case .day:    return "spreads.strip.day.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        case .multiday: return "spreads.strip.multiday.\(Definitions.AccessibilityIdentifiers.token(item.label))"
        }
    }
}

// MARK: - Preview

#Preview {
    ConventionalSpreadsView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil
    )
}
