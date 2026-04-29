import SwiftUI
import JohnnyOFoundationCore

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
