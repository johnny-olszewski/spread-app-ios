import SwiftUI

/// Header view displaying spread title and entry counts.
///
/// Shows the spread's period-appropriate title (e.g., "2026", "January 2026",
/// "January 5, 2026") along with entry counts by type.
struct SpreadHeaderView: View {

    // MARK: - Properties

    /// The configuration containing spread and count information.
    let configuration: SpreadHeaderConfiguration

    /// Callback for toggling the current explicit spread favorite state.
    var onFavoriteToggle: (() -> Void)? = nil

    /// Callback for presenting the current explicit spread naming editor.
    var onEditName: (() -> Void)? = nil

    /// Callback for presenting the current explicit multiday spread date editor.
    var onEditDates: (() -> Void)? = nil

    /// Callback for presenting the current explicit spread deletion confirmation.
    var onDeleteSpread: (() -> Void)? = nil

    // MARK: - Body

    var body: some View {
        headerContainer {
            titleLabel
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.title)
        }
    }

    private func headerContainer<Content: View>(
        @ViewBuilder titleContent: () -> Content
    ) -> some View {
        ZStack {
            HStack {
                entryCountLabel
                Spacer(minLength: 0)
                headerActions
            }

            titleContent()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            if let onFavoriteToggle {
                Button(action: onFavoriteToggle) {
                    Image(systemName: configuration.spread.isFavorite ? "star.fill" : "star")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(configuration.spread.isFavorite ? Color.yellow : Color.secondary)
                        .frame(width: 32, height: 32)
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
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Spread Actions")
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadToolbar.spreadActionsMenu)
            }
        }
    }

    private var titleLabel: some View {
        centeredTitleStack
    }

    private var entryCountLabel: some View {
        Text(configuration.countSummaryText)
            .font(SpreadTheme.Typography.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.entryCounts)
    }

    private var centeredTitleStack: some View {
        VStack(spacing: 2) {
            Text(configuration.spread.period.displayName)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)

            Text(configuration.title)
                .font(SpreadTheme.Typography.title2)

            subtitleLabel
        }
        .fixedSize()
    }

    @ViewBuilder
    private var subtitleLabel: some View {
        if let subtitle = configuration.subtitle {
            Text(subtitle)
                .font(.footnote.smallCaps())
                .foregroundStyle(.secondary)
        } else {
            Text(" ")
                .font(.footnote.smallCaps())
                .hidden()
        }
    }

}

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
        onSelect: @escaping (SpreadHeaderNavigatorModel.Selection) -> Void
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
                            onSelect: onSelect,
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
    /// Creates a header view from a spread and calendar with explicit counts.
    ///
    /// - Parameters:
    ///   - spread: The spread to display.
    ///   - calendar: The calendar for date formatting.
    ///   - taskCount: The number of tasks.
    ///   - eventCount: The number of events (ignored in v1 UI).
    ///   - noteCount: The number of notes.
    init(
        spread: DataModel.Spread,
        calendar: Calendar,
        taskCount: Int = 0,
        eventCount: Int = 0,
        noteCount: Int = 0,
        today: Date = .now,
        firstWeekday: FirstWeekday = .systemDefault,
        allowsPersonalization: Bool = false
    ) {
        self.configuration = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
            today: today,
            firstWeekday: firstWeekday,
            allowsPersonalization: allowsPersonalization,
            taskCount: taskCount,
            eventCount: eventCount,
            noteCount: noteCount
        )
    }

    /// Creates a header view from a SpreadDataModel.
    ///
    /// - Parameters:
    ///   - spreadDataModel: The spread data model containing entries.
    ///   - calendar: The calendar for date formatting.
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

#Preview("Year Spread") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 1))!
    let spread = DataModel.Spread(period: .year, date: date, calendar: calendar)

    return SpreadHeaderView(
        spread: spread,
        calendar: calendar,
        taskCount: 15,
        noteCount: 3
    )
}

#Preview("Month Spread") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 1))!
    let spread = DataModel.Spread(period: .month, date: date, calendar: calendar)

    return SpreadHeaderView(
        spread: spread,
        calendar: calendar,
        taskCount: 5,
        noteCount: 0
    )
}

#Preview("Day Spread") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

    return SpreadHeaderView(
        spread: spread,
        calendar: calendar,
        taskCount: 3,
        noteCount: 1
    )
}

#Preview("Multiday Spread") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 6))!
    let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 12))!
    let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

    return SpreadHeaderView(
        spread: spread,
        calendar: calendar,
        taskCount: 8,
        noteCount: 2
    )
}

#Preview("Multiday Spanning Months") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 28))!
    let endDate = calendar.date(from: .init(year: 2026, month: 2, day: 3))!
    let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

    return SpreadHeaderView(
        spread: spread,
        calendar: calendar,
        taskCount: 4,
        noteCount: 0
    )
}

#Preview("Empty Spread") {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .init(identifier: "UTC")!
    let date = calendar.date(from: .init(year: 2026, month: 1, day: 15))!
    let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

    return SpreadHeaderView(
        spread: spread,
        calendar: calendar,
        taskCount: 0,
        noteCount: 0
    )
}
