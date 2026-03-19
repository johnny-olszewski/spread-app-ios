import Foundation
import Testing
@testable import Spread

/// Tests for feature flag gating behavior.
///
/// Validates that feature flags correctly gate unreleased functionality.
@Suite("Feature Flags Tests")
struct FeatureFlagsTests {

    /// In v1, events are deferred to v2.
    /// The eventsEnabled flag must be false.
    @Test("Events feature flag is disabled for v1")
    func eventsFeatureFlagIsDisabledForV1() {
        #expect(FeatureFlags.eventsEnabled == false)
    }

    /// When events are disabled,
    /// the event repository in production should be empty.
    @Test("Empty event repository returns no events")
    @MainActor
    func emptyEventRepositoryReturnsNoEvents() async {
        let repo = EmptyEventRepository()

        let events = await repo.getEvents()

        #expect(events.isEmpty)
    }

    /// When events are disabled,
    /// SpreadHeaderConfiguration count summary excludes events.
    @Test("Header count summary excludes events even with event count")
    @MainActor
    func headerCountSummaryExcludesEvents() {
        let spread = DataModel.Spread(period: .day, date: Date(), calendar: .current)
        let config = SpreadHeaderConfiguration(
            spread: spread,
            calendar: .current,
            taskCount: 3,
            eventCount: 5,
            noteCount: 2
        )

        // totalCount should only include tasks + notes, not events
        #expect(config.totalCount == 5)
        #expect(config.countSummaryText == "3 tasks, 2 notes")
    }
}
