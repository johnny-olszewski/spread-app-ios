import Foundation

struct SpreadTitleNavigatorRecommendation: Identifiable, Equatable {
    let period: Period
    let date: Date
    let calendar: Calendar

    var id: String {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        return "recommendation.\(period.rawValue).\(Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: normalizedDate, calendar: calendar))"
    }
}

protocol SpreadTitleNavigatorRecommendationProviding {
    func recommendations(for model: SpreadHeaderNavigatorModel) -> [SpreadTitleNavigatorRecommendation]
}

struct TodayMissingSpreadRecommendationProvider: SpreadTitleNavigatorRecommendationProviding {
    func recommendations(for model: SpreadHeaderNavigatorModel) -> [SpreadTitleNavigatorRecommendation] {
        guard model.mode == .conventional else { return [] }

        let calendar = model.calendar
        let today = model.today
        let yearDate = Period.year.normalizeDate(today, calendar: calendar)
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        let explicitSpreads = model.spreads.filter { $0.period != .multiday }

        var recommendations: [SpreadTitleNavigatorRecommendation] = []

        if !containsExplicitSpread(period: .year, date: yearDate, in: explicitSpreads, calendar: calendar) {
            recommendations.append(
                SpreadTitleNavigatorRecommendation(period: .year, date: yearDate, calendar: calendar)
            )
        }

        if !containsExplicitSpread(period: .month, date: monthDate, in: explicitSpreads, calendar: calendar) {
            recommendations.append(
                SpreadTitleNavigatorRecommendation(period: .month, date: monthDate, calendar: calendar)
            )
        }

        if !containsExplicitSpread(period: .day, date: dayDate, in: explicitSpreads, calendar: calendar) {
            recommendations.append(
                SpreadTitleNavigatorRecommendation(period: .day, date: dayDate, calendar: calendar)
            )
        }

        return recommendations
    }

    private func containsExplicitSpread(
        period: Period,
        date: Date,
        in spreads: [DataModel.Spread],
        calendar: Calendar
    ) -> Bool {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        return spreads.contains { spread in
            spread.period == period &&
            period.normalizeDate(spread.date, calendar: calendar) == normalizedDate
        }
    }
}
