import Foundation
import SwiftUI

struct SpreadTitleNavigatorRecommendation: Identifiable, Equatable {
    let period: Period
    let date: Date
    let calendar: Calendar

    var id: String {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        return "recommendation.\(period.rawValue).\(Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: normalizedDate, calendar: calendar))"
    }

    var fullTitle: String {
        switch period {
        case .year:
            return String(calendar.component(.year, from: date))
        case .month:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        case .day:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = .long
            return formatter.string(from: date)
        case .multiday:
            return DataModel.Spread(period: period, date: date, calendar: calendar).displayLabel(calendar: calendar)
        }
    }
}

enum SpreadTitleNavigatorRecommendationLayout {
    static let aspectRatio: CGFloat = 3.0 / 5.0

    static func cardSize(widths: [CGFloat], heights: [CGFloat]) -> CGSize? {
        let widestWidth = widths.max() ?? 0
        let tallestHeight = heights.max() ?? 0
        guard widestWidth > 0, tallestHeight > 0 else { return nil }

        let width = max(widestWidth, tallestHeight * aspectRatio)
        let height = width / aspectRatio
        return CGSize(width: ceil(width), height: ceil(height))
    }

    static func collapsesToMenu(
        horizontalSizeClass: UserInterfaceSizeClass?,
        recommendationCount: Int
    ) -> Bool {
        horizontalSizeClass == .compact && recommendationCount > 1
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
