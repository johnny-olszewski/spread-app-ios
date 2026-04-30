import SwiftUI
import JohnnyOFoundationCore

/// Decorative-only overlay seam for `MonthCalendarView`.
///
/// `CalendarContentGenerator` continues to own headers, week backgrounds, and day cells.
/// This separate protocol owns only row-bounded overlay visuals plus any app-owned overflow UI.
public protocol MonthCalendarRowOverlayGenerator {
    associatedtype OverlayID: Hashable & Sendable
    associatedtype OverlayPayload: Sendable
    associatedtype RowOverlayContent: View
    associatedtype OverflowContent: View

    var overlays: [MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>] { get }
    var maximumVisibleLaneCount: Int { get }

    @ViewBuilder
    func rowOverlayView(
        context: MonthCalendarPackedRowOverlayRenderContext<OverlayID, OverlayPayload>
    ) -> RowOverlayContent

    @ViewBuilder
    func overflowView(
        context: MonthCalendarRowOverlayOverflowRenderContext<OverlayID, OverlayPayload>
    ) -> OverflowContent
}

public struct MonthCalendarEmptyRowOverlayPayload: Sendable {
    public init() {}
}

/// Default no-op overlay generator used when a month shell has no row overlays.
public struct EmptyMonthCalendarRowOverlayGenerator: MonthCalendarRowOverlayGenerator {
    public init() {}

    public var overlays: [MonthCalendarLogicalRowOverlay<Int, MonthCalendarEmptyRowOverlayPayload>] {
        []
    }

    public var maximumVisibleLaneCount: Int {
        0
    }

    public func rowOverlayView(
        context: MonthCalendarPackedRowOverlayRenderContext<Int, MonthCalendarEmptyRowOverlayPayload>
    ) -> some View {
        EmptyView()
    }

    public func overflowView(
        context: MonthCalendarRowOverlayOverflowRenderContext<Int, MonthCalendarEmptyRowOverlayPayload>
    ) -> some View {
        EmptyView()
    }
}
