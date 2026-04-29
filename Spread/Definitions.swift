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
            static let addTaskButton = "spreads.content.addtask.button"
            static let inlineTaskCreationField = "spreads.content.addtask.field"

            static func taskRow(_ title: String) -> String {
                "spreads.content.task.\(token(title))"
            }

            static func taskTitleField(_ title: String) -> String {
                "spreads.content.task.\(token(title)).titleField"
            }

            static func taskStatusToggle(_ title: String) -> String {
                "spreads.content.task.\(token(title)).statusToggle"
            }

            static func taskTitleDiscardButton(_ title: String) -> String {
                "spreads.content.task.\(token(title)).titleField.discard"
            }

            static func taskInlineEditButton(_ title: String) -> String {
                "spreads.content.task.\(token(title)).inline.edit"
            }

            static func taskInlineMigrationMenu(_ title: String) -> String {
                "spreads.content.task.\(token(title)).inline.migrate"
            }

            static func taskInlineMigrationOption(
                _ title: String,
                option: String
            ) -> String {
                "spreads.content.task.\(token(title)).inline.migrate.\(token(option))"
            }

            static func taskContextLabel(_ title: String) -> String {
                "spreads.content.task.\(token(title)).context"
            }

            static func multidaySection(_ dateID: String) -> String {
                "spreads.content.multiday.section.\(dateID)"
            }

            static func multidayEmptyState(_ dateID: String) -> String {
                "spreads.content.multiday.section.\(dateID).empty"
            }

            static func multidayAddTaskButton(_ dateID: String) -> String {
                "spreads.content.multiday.section.\(dateID).addtask"
            }

            static func multidayTodayLabel(_ dateID: String) -> String {
                "spreads.content.multiday.section.\(dateID).today"
            }

            static func multidayFooterButton(_ dateID: String) -> String {
                "spreads.content.multiday.section.\(dateID).footer"
            }
        }

        struct SpreadNavigator {
            static let titleButton = "spreads.navigator.titleButton"
            static let popover = "spreads.navigator.popover"

            static func yearPage(_ year: Int) -> String {
                "spreads.navigator.yearPage.\(year)"
            }

            static func yearRow(_ year: Int) -> String {
                "spreads.navigator.year.\(year)"
            }

            static func yearDisclosure(_ year: Int) -> String {
                "spreads.navigator.year.\(year).disclosure"
            }

            static func monthRow(year: Int, month: Int) -> String {
                String(format: "spreads.navigator.month.%04d-%02d", year, month)
            }

            static func viewMonthButton(year: Int, month: Int) -> String {
                String(format: "spreads.navigator.month.%04d-%02d.viewMonth", year, month)
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
            static let selectedIndicator = "spreads.strip.selected"
            static let selectSpreadButton = "spreads.strip.selectSpread"
            static let recenterButton = "spreads.strip.recenter"

            static func recommendation(_ periodRawValue: String) -> String {
                "spreads.strip.recommendation.\(periodRawValue)"
            }

            static func overdueBadge(_ itemIdentifier: String) -> String {
                "\(itemIdentifier).overdueBadge"
            }
        }

        struct SpreadToolbar {
            static let todayButton = "spreads.toolbar.today"
            static let favoritesMenu = "spreads.toolbar.favorites"
            static let favoriteToggle = "spreads.toolbar.favoriteToggle"
            static let spreadActionsMenu = "spreads.toolbar.spreadActions"
            static let editDatesButton = "spreads.toolbar.editDates"
            static let deleteSpreadButton = "spreads.toolbar.deleteSpread"
        }

        struct SpreadCreationSheet {
            static let periodPicker = "spreads.create.period"
            static let createButton = "spreads.create.create"
            static let saveButton = "spreads.create.save"
            static let cancelButton = "spreads.create.cancel"
            static let customNameField = "spreads.create.name.custom"
            static let dynamicNameToggle = "spreads.create.name.dynamic"
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

        struct SpreadNameEditSheet {
            static let customNameField = "spreads.nameEdit.custom"
            static let dynamicNameToggle = "spreads.nameEdit.dynamic"
            static let saveButton = "spreads.nameEdit.save"
            static let cancelButton = "spreads.nameEdit.cancel"
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
            static let assignmentToggle = "tasks.create.assignment.toggle"
            static let bodyField = "tasks.create.body"
            static let priorityPicker = "tasks.create.priority"
            static let dueDateToggle = "tasks.create.dueDate.toggle"
            static let dueDatePicker = "tasks.create.dueDate"

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
            static let statusToggle = "tasks.detail.status.toggle"
            static let periodPicker = "tasks.detail.period"
            static let saveButton = "tasks.detail.save"
            static let cancelButton = "tasks.detail.cancel"
            static let deleteButton = "tasks.detail.delete"
            static let cancelTaskButton = "tasks.detail.cancelTask"
            static let restoreTaskButton = "tasks.detail.restoreTask"
            static let datePicker = "tasks.detail.date"
            static let dateSummary = "tasks.detail.date.summary"
            static let yearPicker = "tasks.detail.year"
            static let monthPicker = "tasks.detail.month"
            static let monthYearPicker = "tasks.detail.month.year"
            static let spreadPickerButton = "tasks.detail.spreadpicker"
            static let assignmentToggle = "tasks.detail.assignment.toggle"
            static let bodyField = "tasks.detail.body"
            static let priorityPicker = "tasks.detail.priority"
            static let dueDateToggle = "tasks.detail.dueDate.toggle"
            static let dueDatePicker = "tasks.detail.dueDate"
            static let assignmentHistory = "tasks.detail.assignmentHistory"

            static func assignmentHistoryRow(_ index: Int) -> String {
                "tasks.detail.assignmentHistory.\(index)"
            }

            static func periodSegment(_ periodRawValue: String) -> String {
                "tasks.detail.period.\(periodRawValue)"
            }
        }

        struct SyncError {
            static let banner = "syncError.banner"
        }

        struct Migration {
            static let destinationSectionHeader = "migration.destination.header"
            static let destinationMigrateAllButton = "migration.destination.migrateAll"

            static func sourceButton(_ taskTitle: String) -> String {
                "migration.source.\(token(taskTitle)).button"
            }

            static func destinationRow(_ taskTitle: String) -> String {
                "migration.destination.\(token(taskTitle)).row"
            }
        }

        struct Search {
            static let screen = "search.tasks.screen"
            static let field = "search.tasks.field"

            static func section(_ tokenValue: String) -> String {
                "search.tasks.section.\(tokenValue)"
            }

            static func row(_ taskID: UUID) -> String {
                "search.tasks.row.\(taskID.uuidString.lowercased())"
            }
        }

        struct Settings {
            static func modeOption(_ rawValue: String) -> String {
                "settings.mode.\(rawValue)"
            }

            static let titleStripDisplayPicker = "settings.titleStripDisplay.picker"
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

        struct Debug {
            static let temporalHarness = "debug.temporal.harness"
            static let temporalNow = "debug.temporal.now"
            static let temporalToday = "debug.temporal.today"
            static let temporalTimeZone = "debug.temporal.timeZone"
            static let temporalLocale = "debug.temporal.locale"
            static let temporalCalendar = "debug.temporal.calendar"
            static let temporalOverride = "debug.temporal.override"
            static let temporalAdvanceHour = "debug.temporal.advanceHour"
            static let temporalAdvanceDay = "debug.temporal.advanceDay"
            static let temporalSetUTC = "debug.temporal.timeZone.utc"
            static let temporalSetNewYork = "debug.temporal.timeZone.newYork"
            static let temporalSetFrenchLocale = "debug.temporal.locale.frFR"
            static let temporalSetEnglishLocale = "debug.temporal.locale.enUSPOSIX"
            static let temporalSetGregorianCalendar = "debug.temporal.calendar.gregorian"
            static let temporalSetBuddhistCalendar = "debug.temporal.calendar.buddhist"
            static let temporalResumeLive = "debug.temporal.resumeLive"
            static let temporalSelectedSpreadID = "debug.temporal.selectedSpread.id"
            static let temporalPresentedToday = "debug.temporal.presented.today"
        }
    }
}
