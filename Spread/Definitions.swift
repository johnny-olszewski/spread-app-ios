import Foundation

struct Definitions {
    struct AccessibilityIdentifiers {
        struct SpreadHierarchyTabBar {
            static let createButton = "spreads.tabbar.create"

            static func yearIdentifier(_ year: Int) -> String {
                "spreads.tabbar.year.\(year)"
            }

            static func monthIdentifier(year: Int, month: Int) -> String {
                String(format: "spreads.tabbar.month.%04d-%02d", year, month)
            }

            static func dayIdentifier(year: Int, month: Int, day: Int) -> String {
                String(format: "spreads.tabbar.day.%04d-%02d-%02d", year, month, day)
            }

            static func multidayIdentifier(
                startDate: Date,
                endDate: Date,
                calendar: Calendar
            ) -> String {
                "spreads.tabbar.multiday.\(ymd(from: startDate, calendar: calendar))_to_\(ymd(from: endDate, calendar: calendar))"
            }

            static func ymd(from date: Date, calendar: Calendar) -> String {
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                let year = components.year ?? 0
                let month = components.month ?? 0
                let day = components.day ?? 0
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
        }

        struct SpreadContent {
            static let title = "spreads.content.title"
        }

        struct SpreadCreationSheet {
            static let periodPicker = "spreads.create.period"
            static let createButton = "spreads.create.create"
            static let cancelButton = "spreads.create.cancel"

            static func periodSegment(_ periodRawValue: String) -> String {
                "spreads.create.period.\(periodRawValue)"
            }
        }
    }
}
