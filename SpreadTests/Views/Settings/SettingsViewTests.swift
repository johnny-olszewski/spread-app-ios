import Foundation
import Testing
@testable import Spread

@MainActor
struct SettingsViewTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static var testToday: Date {
        testCalendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
    }

    private static var testAppClock: AppClock {
        AppClock.fixed(
            now: testToday,
            calendar: testCalendar,
            timeZone: testCalendar.timeZone,
            locale: testCalendar.locale ?? Locale(identifier: "en_US_POSIX")
        )
    }

    // MARK: - Mode Toggle Tests

    /// Conditions: JournalManager created with conventional mode.
    /// Expected: bujoMode should be .conventional.
    @Test func testInitialModeIsConventional() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.testCalendar,
            today: Self.testToday,
            bujoMode: .conventional
        )

        #expect(manager.bujoMode == .conventional)
    }

    /// Conditions: JournalManager created with traditional mode.
    /// Expected: bujoMode should be .traditional.
    @Test func testInitialModeIsTraditional() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.testCalendar,
            today: Self.testToday,
            bujoMode: .traditional
        )

        #expect(manager.bujoMode == .traditional)
    }

    /// Conditions: JournalManager starts in conventional mode, then mode is changed to traditional.
    /// Expected: bujoMode should reflect the new value.
    @Test func testModeToggleReflectsChange() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.testCalendar,
            today: Self.testToday,
            bujoMode: .conventional
        )

        manager.bujoMode = .traditional
        #expect(manager.bujoMode == .traditional)

        manager.bujoMode = .conventional
        #expect(manager.bujoMode == .conventional)
    }

    // MARK: - First Weekday Tests

    /// Conditions: JournalManager created with default firstWeekday.
    /// Expected: firstWeekday should be .systemDefault.
    @Test func testDefaultFirstWeekdayIsSystemDefault() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.testCalendar,
            today: Self.testToday
        )

        #expect(manager.firstWeekday == .systemDefault)
    }

    /// Conditions: JournalManager created with .monday firstWeekday.
    /// Expected: firstWeekday should be .monday.
    @Test func testFirstWeekdayMonday() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.testCalendar,
            today: Self.testToday,
            firstWeekday: .monday
        )

        #expect(manager.firstWeekday == .monday)
    }

    /// Conditions: JournalManager starts with .sunday, then changed to .monday.
    /// Expected: firstWeekday should reflect the new value.
    @Test func testFirstWeekdayToggleReflectsChange() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.testCalendar,
            today: Self.testToday,
            firstWeekday: .sunday
        )

        manager.firstWeekday = .monday
        #expect(manager.firstWeekday == .monday)
    }

    // MARK: - FirstWeekday Reverse Mapping Tests

    /// Conditions: Map weekday value 1 to FirstWeekday.
    /// Expected: Should return .sunday.
    @Test func testFromWeekdayValueSunday() {
        #expect(FirstWeekday.from(weekdayValue: 1) == .sunday)
    }

    /// Conditions: Map weekday value 2 to FirstWeekday.
    /// Expected: Should return .monday.
    @Test func testFromWeekdayValueMonday() {
        #expect(FirstWeekday.from(weekdayValue: 2) == .monday)
    }

    /// Conditions: Map unknown weekday value 3 to FirstWeekday.
    /// Expected: Should return nil.
    @Test func testFromWeekdayValueUnknown() {
        #expect(FirstWeekday.from(weekdayValue: 3) == nil)
    }

    /// Conditions: Map weekday value 0 (out of range) to FirstWeekday.
    /// Expected: Should return nil.
    @Test func testFromWeekdayValueOutOfRange() {
        #expect(FirstWeekday.from(weekdayValue: 0) == nil)
    }

    // MARK: - Settings Persistence Integration Tests

    /// Conditions: Create settings with conventional mode and firstWeekday 1.
    /// Expected: Settings round-trips correctly through DataModel.Settings.
    @Test func testSettingsRoundTripConventional() {
        let settings = DataModel.Settings(
            bujoMode: .conventional,
            firstWeekday: 1
        )

        #expect(settings.bujoMode == .conventional)
        #expect(settings.firstWeekday == 1)
    }

    /// Conditions: Create settings with traditional mode and firstWeekday 2.
    /// Expected: Settings round-trips correctly through DataModel.Settings.
    @Test func testSettingsRoundTripTraditional() {
        let settings = DataModel.Settings(
            bujoMode: .traditional,
            firstWeekday: 2
        )

        #expect(settings.bujoMode == .traditional)
        #expect(settings.firstWeekday == 2)
    }

    // MARK: - Local Title Strip Preference Tests

    /// Conditions: The local title-strip preference has no stored value or has an invalid stored value.
    /// Expected: It defaults to Relevant Past Only without touching synced Settings.
    @Test func testTitleStripDisplayPreferenceDefaultsToRelevantPastOnly() {
        #expect(TitleStripDisplayPreference.defaultValue == .relevantPastOnly)
        #expect(TitleStripDisplayPreference(storedRawValue: "unknown") == .relevantPastOnly)
    }

    /// Conditions: The local title-strip preference stores the Show All Spreads raw value.
    /// Expected: It restores the matching enum value from UserDefaults-compatible storage.
    @Test func testTitleStripDisplayPreferenceRestoresShowAllSpreads() {
        #expect(TitleStripDisplayPreference(storedRawValue: TitleStripDisplayPreference.showAllSpreads.rawValue) == .showAllSpreads)
    }

    // MARK: - FirstWeekday Affects Multiday Preset Tests

    /// Conditions: Create SpreadCreationConfiguration with .sunday firstWeekday.
    /// Expected: This week preset should start on Sunday.
    @Test func testFirstWeekdayAffectsThisWeekPresetSunday() {
        let config = SpreadCreationConfiguration(
            calendar: Self.testCalendar,
            today: Self.testToday,
            firstWeekday: .sunday,
            existingSpreads: []
        )

        let range = config.dateRange(for: .thisWeek)
        #expect(range != nil)

        if let range {
            let startWeekday = Self.testCalendar.component(.weekday, from: range.startDate)
            // Sunday = 1
            #expect(startWeekday == 1)
        }
    }

    /// Conditions: Create SpreadCreationConfiguration with .monday firstWeekday.
    /// Expected: This week preset should start on Monday.
    @Test func testFirstWeekdayAffectsThisWeekPresetMonday() {
        let config = SpreadCreationConfiguration(
            calendar: Self.testCalendar,
            today: Self.testToday,
            firstWeekday: .monday,
            existingSpreads: []
        )

        let range = config.dateRange(for: .thisWeek)
        #expect(range != nil)

        if let range {
            let startWeekday = Self.testCalendar.component(.weekday, from: range.startDate)
            // Monday = 2
            #expect(startWeekday == 2)
        }
    }

    // MARK: - Settings Loading Tests

    /// Conditions: AppDependencies creates JournalManager with specified bujoMode and firstWeekday.
    /// Expected: JournalManager should reflect the configured values.
    @Test func testAppDependenciesPassesModeAndWeekday() async throws {
        let dependencies = try AppDependencies.make(
            makeNetworkMonitor: { MockNetworkMonitor() }
        )

        let manager = try await dependencies.makeJournalManager(
            appClock: Self.testAppClock,
            bujoMode: .traditional,
            firstWeekday: .monday
        )

        #expect(manager.bujoMode == .traditional)
        #expect(manager.firstWeekday == .monday)
    }
}
