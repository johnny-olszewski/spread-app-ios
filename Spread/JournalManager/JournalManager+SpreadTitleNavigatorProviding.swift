import Foundation

extension JournalManager: SpreadTitleNavigatorProviding {
    /// Returns the strip model for the current BuJo mode.
    ///
    /// - Conventional: header model carries explicit spreads and tasks so local
    ///   title-strip filtering can preserve past spreads with open work.
    /// - Traditional: header model carries all entries so the strip can reflect
    ///   virtual spread content across the full calendar.
    var titleNavigatorModel: SpreadTitleNavigatorModel {
        switch bujoMode {
        case .conventional:
            return SpreadTitleNavigatorModel(
                headerModel: SpreadHeaderNavigatorModel(
                    mode: .conventional,
                    calendar: calendar,
                    today: today,
                    firstWeekday: firstWeekday,
                    spreads: spreads,
                    tasks: tasks,
                    notes: [],
                    events: []
                ),
                overdueItems: overdueTaskItems
            )
        case .traditional:
            return SpreadTitleNavigatorModel(
                headerModel: SpreadHeaderNavigatorModel(
                    mode: .traditional,
                    calendar: calendar,
                    today: today,
                    firstWeekday: firstWeekday,
                    spreads: spreads,
                    tasks: tasks,
                    notes: notes,
                    events: FeatureFlags.eventsEnabled ? events : []
                ),
                overdueItems: overdueTaskItems
            )
        }
    }
}
