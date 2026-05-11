import SwiftUI

/// Toolbar-style header for a spread surface.
///
/// Shows the sync ring on the leading edge and spread actions (favorite, contextual menu)
/// on the trailing edge. The spread title is intentionally omitted here because the title
/// navigator strip directly above already provides full spread identity. The entry count is
/// also omitted — that space is reserved for future features.
struct SpreadHeaderView: View {

    // MARK: - Properties

    let configuration: SpreadHeaderConfiguration

    /// Sync engine observed for ring state. `nil` hides the ring.
    var syncEngine: SyncEngine? = nil

    /// Called when the user taps the sync ring to force a sync.
    var onSyncNow: (() -> Void)? = nil

    /// Callback for toggling the current explicit spread favorite state.
    var onFavoriteToggle: (() -> Void)? = nil

    /// Callback for presenting the current explicit spread naming editor.
    var onEditName: (() -> Void)? = nil

    /// Callback for presenting the current explicit multiday spread date editor.
    var onEditDates: (() -> Void)? = nil

    /// Callback for presenting the current explicit spread deletion confirmation.
    var onDeleteSpread: (() -> Void)? = nil

    /// When non-nil, a "Go Back" button is shown centered in the header.
    var backDestination: DataModel.Spread? = nil

    /// Called when the user taps the "Go Back" button.
    var onGoBack: (() -> Void)? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                syncRing
                Spacer(minLength: 0)
                headerActions
            }

            if backDestination != nil, let onGoBack {
                Button(action: onGoBack) {
                    Label("Go Back", systemImage: "chevron.left")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .glassEffect(in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
                .accessibilityLabel("Go back to previous spread")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: backDestination?.id)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.title)
    }

    // MARK: - Sync ring

    @ViewBuilder
    private var syncRing: some View {
        if let engine = syncEngine, engine.status != .localOnly {
            SyncRingView(
                status: engine.status,
                outboxCount: engine.outboxCount,
                onSyncNow: onSyncNow
            )
            .frame(width: 32, height: 32)
        }
    }

    // MARK: - Actions

    private var headerActions: some View {
        HStack(spacing: 8) {
            if let onFavoriteToggle {
                Button(action: onFavoriteToggle) {
                    Image(systemName: configuration.spread.isFavorite ? "star.fill" : "star")
                        .font(.system(size: SpreadTheme.IconSize.large, weight: .semibold))
                        .foregroundStyle(configuration.spread.isFavorite ? Color.yellow : Color.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(configuration.spread.isFavorite ? "Unfavorite Spread" : "Favorite Spread")
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.favoriteToggle)
            }

            let actions = SpreadHeaderActionSupport.actions(
                allowsNameEditing: onEditName != nil,
                allowsDateEditing: onEditDates != nil,
                allowsDeletion: onDeleteSpread != nil
            )

            if !actions.isEmpty {
                Menu {
                    if actions.contains(.editName), let onEditName {
                        Button {
                            onEditName()
                        } label: {
                            Label("Edit Name", systemImage: "pencil")
                        }
                    }

                    if actions.contains(.editDates), let onEditDates {
                        Button {
                            onEditDates()
                        } label: {
                            Label("Edit Dates", systemImage: "calendar")
                        }
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.editDatesButton)
                    }

                    if actions.contains(.deleteSpread), let onDeleteSpread {
                        Button(role: .destructive) {
                            onDeleteSpread()
                        } label: {
                            Label("Delete Spread", systemImage: "trash")
                        }
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.deleteSpreadButton)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: SpreadTheme.IconSize.large, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Spread Actions")
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.spreadActionsMenu)
            }
        }
    }
}

// MARK: - Supporting types

enum SpreadHeaderAction: Equatable {
    case editName
    case editDates
    case deleteSpread
}

enum SpreadHeaderActionSupport {
    static func actions(
        allowsNameEditing: Bool,
        allowsDateEditing: Bool = false,
        allowsDeletion: Bool
    ) -> [SpreadHeaderAction] {
        var actions: [SpreadHeaderAction] = []
        if allowsNameEditing {
            actions.append(.editName)
        }
        if allowsDateEditing {
            actions.append(.editDates)
        }
        if allowsDeletion {
            actions.append(.deleteSpread)
        }
        return actions
    }
}

struct SpreadNavigatorPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let presentsAsPopover: Bool
    let navigatorContent: () -> AnyView

    func body(content: Content) -> some View {
        if presentsAsPopover {
            content.popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                navigatorContent()
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                navigatorContent()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

extension View {
    func spreadNavigatorPresentation(
        isPresented: Binding<Bool>,
        presentsAsPopover: Bool,
        model: SpreadHeaderNavigatorModel,
        currentSpread: DataModel.Spread,
        recommendations: [SpreadTitleNavigatorRecommendation] = [],
        onSelect: @escaping (SpreadHeaderNavigatorModel.Selection) -> Void,
        onRecommendationTapped: ((SpreadTitleNavigatorRecommendation) -> Void)? = nil
    ) -> some View {
        modifier(
            SpreadNavigatorPresentationModifier(
                isPresented: isPresented,
                presentsAsPopover: presentsAsPopover,
                navigatorContent: {
                    AnyView(
                        SpreadHeaderNavigatorPopoverView(
                            model: model,
                            currentSpread: currentSpread,
                            recommendations: recommendations,
                            onSelect: onSelect,
                            onRecommendationTapped: onRecommendationTapped,
                            onDismiss: { isPresented.wrappedValue = false }
                        )
                    )
                }
            )
        )
    }
}

// MARK: - Convenience Initializers

extension SpreadHeaderView {
    init(
        spread: DataModel.Spread,
        calendar: Calendar,
        today: Date = .now,
        firstWeekday: FirstWeekday = .systemDefault,
        allowsPersonalization: Bool = false
    ) {
        self.configuration = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            today: today,
            firstWeekday: firstWeekday,
            allowsPersonalization: allowsPersonalization
        )
    }

    init(
        spreadDataModel: SpreadDataModel,
        calendar: Calendar,
        today: Date = .now,
        firstWeekday: FirstWeekday = .systemDefault,
        allowsPersonalization: Bool = false
    ) {
        self.configuration = SpreadHeaderConfiguration(
            spreadDataModel: spreadDataModel,
            calendar: calendar,
            today: today,
            firstWeekday: firstWeekday,
            allowsPersonalization: allowsPersonalization
        )
    }
}

// MARK: - Preview

#Preview("With sync ring — synced") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)
    return VStack(spacing: 0) {
        SpreadHeaderView(
            spread: spread,
            calendar: calendar,
            allowsPersonalization: true
        )
        Divider()
    }
}

#Preview("No sync engine") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)
    return SpreadHeaderView(
        spread: spread,
        calendar: calendar
    )
}
