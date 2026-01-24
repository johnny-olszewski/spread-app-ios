import SwiftUI

/// Header view displaying spread title and entry counts.
///
/// Shows the spread's period-appropriate title (e.g., "2026", "January 2026",
/// "January 5, 2026") along with entry counts by type.
struct SpreadHeaderView: View {

    // MARK: - Properties

    /// The configuration containing spread and count information.
    let configuration: SpreadHeaderConfiguration

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(configuration.title)
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.title)

            Text(configuration.countSummaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.entryCounts)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 12)
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
    ///   - eventCount: The number of events.
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
        eventCount: 8,
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
        eventCount: 2,
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
        eventCount: 1,
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
        eventCount: 3,
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
        eventCount: 1,
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
        eventCount: 0,
        noteCount: 0
    )
}
