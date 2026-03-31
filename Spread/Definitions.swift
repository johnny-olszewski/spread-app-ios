import Foundation

struct Definitions {
    struct AccessibilityIdentifiers {
        static func token(_ value: String) -> String {
            let lowercased = value.lowercased()
            let scalars = lowercased.unicodeScalars.map { scalar -> Character in
                if CharacterSet.alphanumerics.contains(scalar) {
                    return Character(scalar)
                }
                return "."
            }
            let collapsed = String(scalars)
                .split(separator: ".", omittingEmptySubsequences: true)
                .joined(separator: ".")
            return collapsed.isEmpty ? "item" : collapsed
        }

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
            static let list = "spreads.content.list"
            static let pager = "spreads.content.pager"
            static let multidayGrid = "spreads.content.multiday.grid"
            static let migratedSectionHeader = "spreads.content.migrated.section"

            static func taskRow(_ title: String) -> String {
                "spreads.content.task.\(token(title))"
            }

            static func multidaySection(_ dateID: String) -> String {
                "spreads.content.multiday.section.\(dateID)"
            }

            static func multidayEmptyState(_ dateID: String) -> String {
                "spreads.content.multiday.section.\(dateID).empty"
            }
        }

        struct SpreadNavigator {
            static let titleButton = "spreads.navigator.titleButton"
            static let popover = "spreads.navigator.popover"

            static func yearRow(_ year: Int) -> String {
                "spreads.navigator.year.\(year)"
            }

            static func yearDisclosure(_ year: Int) -> String {
                "spreads.navigator.year.\(year).disclosure"
            }

            static func monthRow(year: Int, month: Int) -> String {
                String(format: "spreads.navigator.month.%04d-%02d", year, month)
            }

            static func monthDisclosure(year: Int, month: Int) -> String {
                String(format: "spreads.navigator.month.%04d-%02d.disclosure", year, month)
            }

            static func grid(year: Int, month: Int) -> String {
                String(format: "spreads.navigator.grid.%04d-%02d", year, month)
            }

            static func dayTile(date: Date, calendar: Calendar) -> String {
                "spreads.navigator.day.\(SpreadHierarchyTabBar.ymd(from: date, calendar: calendar))"
            }

            static func multidayTile(startDate: Date, endDate: Date, calendar: Calendar) -> String {
                "spreads.navigator.multiday.\(SpreadHierarchyTabBar.ymd(from: startDate, calendar: calendar))_to_\(SpreadHierarchyTabBar.ymd(from: endDate, calendar: calendar))"
            }
        }

        struct SpreadStrip {
            static let container = "spreads.strip.container"
            static let selectedCapsule = "spreads.strip.selected"
        }

        struct SpreadToolbar {
            static let todayButton = "spreads.toolbar.today"
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

        struct NoteCreationSheet {
            static let titleField = "notes.create.title"
            static let contentField = "notes.create.content"
            static let periodPicker = "notes.create.period"
            static let createButton = "notes.create.create"
            static let cancelButton = "notes.create.cancel"
            static let datePicker = "notes.create.date"
            static let yearPicker = "notes.create.year"
            static let monthPicker = "notes.create.month"
            static let monthYearPicker = "notes.create.month.year"
            static let spreadPickerButton = "notes.create.spreadpicker"

            static func periodSegment(_ periodRawValue: String) -> String {
                "notes.create.period.\(periodRawValue)"
            }
        }

        struct NoteDetailSheet {
            static let titleField = "notes.detail.title"
            static let contentField = "notes.detail.content"
            static let periodPicker = "notes.detail.period"
            static let saveButton = "notes.detail.save"
            static let cancelButton = "notes.detail.cancel"
            static let deleteButton = "notes.detail.delete"
        }

        struct TaskDetailSheet {
            static let titleField = "tasks.detail.title"
            static let statusPicker = "tasks.detail.status"
            static let periodPicker = "tasks.detail.period"
            static let saveButton = "tasks.detail.save"
            static let cancelButton = "tasks.detail.cancel"
            static let deleteButton = "tasks.detail.delete"
            static let datePicker = "tasks.detail.date"
            static let yearPicker = "tasks.detail.year"
            static let monthPicker = "tasks.detail.month"
            static let monthYearPicker = "tasks.detail.month.year"
            static let assignmentHistory = "tasks.detail.assignmentHistory"

            static func assignmentHistoryRow(_ index: Int) -> String {
                "tasks.detail.assignmentHistory.\(index)"
            }
        }

        struct Migration {
            static let banner = "migration.banner"
            static let reviewButton = "migration.banner.review"
            static let sheet = "migration.sheet"
            static let header = "migration.sheet.header"
            static let selectAllButton = "migration.sheet.selectAll"
            static let deselectAllButton = "migration.sheet.deselectAll"
            static let submitButton = "migration.sheet.submit"
            static let cancelButton = "migration.sheet.cancel"
            static let statusMessage = "migration.sheet.status"

            static func section(_ sourceID: String) -> String {
                "migration.sheet.section.\(token(sourceID))"
            }

            static func row(_ taskTitle: String) -> String {
                "migration.sheet.row.\(token(taskTitle))"
            }

            static func selection(_ taskTitle: String) -> String {
                "migration.sheet.row.\(token(taskTitle)).selection"
            }

            static func sourceLabel(_ taskTitle: String) -> String {
                "migration.sheet.row.\(token(taskTitle)).source"
            }

            static func destinationLabel(_ taskTitle: String) -> String {
                "migration.sheet.row.\(token(taskTitle)).destination"
            }
        }

        struct Overdue {
            static let button = "overdue.toolbar.button"
            static let sheet = "overdue.sheet"
            static let doneButton = "overdue.sheet.done"

            static func section(_ sourceID: String) -> String {
                "overdue.sheet.section.\(token(sourceID))"
            }

            static func row(_ taskTitle: String) -> String {
                "overdue.sheet.row.\(token(taskTitle))"
            }

            static func rowTitle(_ taskTitle: String) -> String {
                "overdue.sheet.row.\(token(taskTitle)).title"
            }
        }

        struct Inbox {
            static let button = "inbox.toolbar.button"
            static let sheet = "inbox.sheet"
            static let doneButton = "inbox.sheet.done"
        }

        struct Settings {
            static func modeOption(_ rawValue: String) -> String {
                "settings.mode.\(rawValue)"
            }
        }

        struct Navigation {
            static func sidebarItem(_ rawValue: String) -> String {
                "navigation.sidebar.\(rawValue)"
            }
        }

        struct CreateMenu {
            static let button = "spreads.tabbar.create.menu"
            static let createSpread = "spreads.tabbar.create.menu.spread"
            static let createTask = "spreads.tabbar.create.menu.task"
            static let createNote = "spreads.tabbar.create.menu.note"
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
