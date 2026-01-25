import Foundation

struct Definitions {
    struct AccessibilityIdentifiers {
        struct SpreadHierarchyTabBar {
            static let createButton = "spreads.tabbar.create"

            static func yearIdentifier(_ year: Int) -> String {
                "spreads.tabbar.year.\(year)"
            }

            static func yearMenuItem(_ year: Int) -> String {
                "spreads.tabbar.year.menu.\(year)"
            }

            static func monthIdentifier(year: Int, month: Int) -> String {
                String(format: "spreads.tabbar.month.%04d-%02d", year, month)
            }

            static func monthMenuItem(year: Int, month: Int) -> String {
                String(format: "spreads.tabbar.month.menu.%04d-%02d", year, month)
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
            static let entryCounts = "spreads.content.entryCounts"
        }

        struct SpreadCreationSheet {
            static let periodPicker = "spreads.create.period"
            static let createButton = "spreads.create.create"
            static let cancelButton = "spreads.create.cancel"
            static let standardDatePicker = "spreads.create.date.standard"
            static let yearPicker = "spreads.create.year"
            static let monthPicker = "spreads.create.month"
            static let monthYearPicker = "spreads.create.month.year"
            static let multidayStartDatePicker = "spreads.create.date.multiday.start"
            static let multidayEndDatePicker = "spreads.create.date.multiday.end"

            static func periodSegment(_ periodRawValue: String) -> String {
                "spreads.create.period.\(periodRawValue)"
            }

            static func multidayPreset(_ presetRawValue: String) -> String {
                "spreads.create.preset.\(presetRawValue)"
            }
        }

        struct TaskCreationSheet {
            static let titleField = "tasks.create.title"
            static let periodPicker = "tasks.create.period"
            static let createButton = "tasks.create.create"
            static let cancelButton = "tasks.create.cancel"
            static let datePicker = "tasks.create.date"
            static let yearPicker = "tasks.create.year"
            static let monthPicker = "tasks.create.month"
            static let monthYearPicker = "tasks.create.month.year"
            static let spreadPickerButton = "tasks.create.spreadpicker"

            static func periodSegment(_ periodRawValue: String) -> String {
                "tasks.create.period.\(periodRawValue)"
            }
        }

        struct CreateMenu {
            static let button = "spreads.tabbar.create.menu"
            static let createSpread = "spreads.tabbar.create.menu.spread"
            static let createTask = "spreads.tabbar.create.menu.task"
        }

        struct SpreadPicker {
            static let chooseCustomDate = "tasks.spreadpicker.customdate"
            static let selectAllFilters = "tasks.spreadpicker.filters.selectall"
            static let deselectAllFilters = "tasks.spreadpicker.filters.deselectall"

            static func filterToggle(_ periodRawValue: String) -> String {
                "tasks.spreadpicker.filter.\(periodRawValue)"
            }

            static func spreadRow(_ spreadId: String) -> String {
                "tasks.spreadpicker.spread.\(spreadId)"
            }

            static func multidayRow(_ spreadId: String) -> String {
                "tasks.spreadpicker.multiday.\(spreadId)"
            }

            static func multidayDate(spreadId: String, date: String) -> String {
                "tasks.spreadpicker.multiday.\(spreadId).date.\(date)"
            }
        }
    }
}
