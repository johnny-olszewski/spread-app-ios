import SwiftUI

/// Header view displaying spread title and entry counts.
///
/// Shows the spread's period-appropriate title (e.g., "2026", "January 2026",
/// "January 5, 2026") along with entry counts by type.
struct SpreadHeaderView: View {

    // MARK: - Properties

    /// The configuration containing spread and count information.
    let configuration: SpreadHeaderConfiguration

    /// Whether the header popover is presented.
    var isShowingNavigator: Binding<Bool>? = nil

    /// The navigator model used to build the rooted selector surface.
    var navigatorModel: SpreadHeaderNavigatorModel? = nil

    /// The current spread represented by this header.
    var currentSpread: DataModel.Spread? = nil

    /// Callback when a navigator selection is made.
    var onNavigatorSelect: ((SpreadHeaderNavigatorModel.Selection) -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Body

    var body: some View {
        ZStack {
            HStack {
                Text(configuration.countSummaryText)
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.entryCounts)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let isShowingNavigator, let navigatorModel, let currentSpread, let onNavigatorSelect {
                navigatorTitleButton(isShowingNavigator: isShowingNavigator)
                    .spreadNavigatorPresentation(
                        isPresented: isShowingNavigator,
                        presentsAsPopover: horizontalSizeClass == .regular,
                        model: navigatorModel,
                        currentSpread: currentSpread,
                        onSelect: onNavigatorSelect
                    )
            } else {
                Text(configuration.title)
                    .font(SpreadTheme.Typography.title2)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func navigatorTitleButton(isShowingNavigator: Binding<Bool>) -> some View {
        Button {
            isShowingNavigator.wrappedValue = true
        } label: {
            HStack(spacing: 6) {
                Text(configuration.title)
                    .font(SpreadTheme.Typography.title2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNavigator.titleButton)
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
        noteCount: Int = 0
    ) {
        self.configuration = SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar,
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
    init(spreadDataModel: SpreadDataModel, calendar: Calendar) {
        self.configuration = SpreadHeaderConfiguration(
            spreadDataModel: spreadDataModel,
            calendar: calendar
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
