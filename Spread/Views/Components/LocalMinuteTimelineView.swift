import SwiftUI

/// View-local minute rendering context for future live calendar surfaces.
///
/// Use this seam for display-only minute updates such as a current-time line.
/// Do not route minute-sensitive UI through `AppClock`; app-wide semantics stay coarse.
struct LocalMinuteTimelineContext: Equatable {
    let now: Date
    let minuteStart: Date
    let nextMinuteStart: Date
    let calendar: Calendar
}

enum LocalMinuteTimelineSupport {
    static func context(
        for date: Date,
        calendar: Calendar
    ) -> LocalMinuteTimelineContext {
        let minuteInterval = calendar.dateInterval(of: .minute, for: date)
        let minuteStart = minuteInterval?.start ?? date
        let nextMinuteStart = minuteInterval?.end
            ?? calendar.date(byAdding: .minute, value: 1, to: minuteStart)
            ?? date.addingTimeInterval(60)

        return LocalMinuteTimelineContext(
            now: date,
            minuteStart: minuteStart,
            nextMinuteStart: nextMinuteStart,
            calendar: calendar
        )
    }
}

/// Local minute schedule wrapper for display-only rendering.
///
/// This is the preferred boundary for future day-calendar live-time elements.
struct LocalMinuteTimelineView<Content: View>: View {
    let calendar: Calendar
    let content: (LocalMinuteTimelineContext) -> Content

    init(
        calendar: Calendar,
        @ViewBuilder content: @escaping (LocalMinuteTimelineContext) -> Content
    ) {
        self.calendar = calendar
        self.content = content
    }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            content(
                LocalMinuteTimelineSupport.context(
                    for: timeline.date,
                    calendar: calendar
                )
            )
        }
    }
}
