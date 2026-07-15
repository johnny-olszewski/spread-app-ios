import SwiftUI
import Testing
@testable import Spread

struct EntryStatusPresentationTests {

    @Test func userEditableTaskStatusesExcludeMigrated() {
        #expect(EntryStatus.userEditableTaskStatuses == [.open, .inFlight, .complete, .cancelled])
    }

    /// Conditions: `.inFlight` is a new task-only status (SPRD-316) rendered as a
    /// standalone icon rather than the base-shape-plus-overlay composite.
    /// Expected: `.inFlight.overlayShape` is nil (no overlay drawn), `.inFlight.iconOverride`
    /// resolves to `.airplaneTilt`, and every other status has a nil `iconOverride`.
    @Test func inFlightRendersAsIconOverrideWithNoOverlay() {
        #expect(EntryStatus.inFlight.overlayShape == nil)
        #expect(EntryStatus.inFlight.iconOverride == .airplaneTilt)
        for status in EntryStatus.allCases where status != .inFlight {
            #expect(status.iconOverride == nil)
        }
    }

    /// Conditions: `.inFlight` is grouped with the non-terminal statuses for icon tinting.
    /// Expected: `.inFlight.iconColor` resolves to `Color.primary`, matching `.open`/`.active`/`.upcoming`.
    @Test func inFlightIconColorIsPrimary() {
        #expect(EntryStatus.inFlight.iconColor == Color.primary)
    }

    /// Conditions: `.inFlight` keeps its title editable (unlike terminal statuses) and its
    /// display name, and its raw value is the exact wire format the server sync layer expects.
    /// Expected: `inlineChangesAreLocked` is false, `displayName` is "In Flight", and
    /// `rawValue` is "in_flight".
    @Test func inFlightDisplayAndWireFormat() {
        #expect(EntryStatus.inFlight.inlineChangesAreLocked == false)
        #expect(EntryStatus.inFlight.displayName == "In Flight")
        #expect(EntryStatus.inFlight.rawValue == "in_flight")
    }

    @Test func cancelledTaskDisablesAssignmentEditingInTaskSheet() {
        #expect(EntryStatus.cancelled.allowsAssignmentEditingInTaskSheet == false)
        #expect(EntryStatus.complete.allowsAssignmentEditingInTaskSheet == false)
        #expect(EntryStatus.open.allowsAssignmentEditingInTaskSheet == true)
    }

    @Test func taskLifecycleActionsMatchTaskSheetBehavior() {
        #expect(EntryStatus.open.lifecycleActionTitleInTaskSheet == "Cancel Task")
        #expect(EntryStatus.complete.lifecycleActionTitleInTaskSheet == "Cancel Task")
        #expect(EntryStatus.cancelled.lifecycleActionTitleInTaskSheet == "Restore Task")
        #expect(EntryStatus.migrated.lifecycleActionTitleInTaskSheet == nil)
    }
}
