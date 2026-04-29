import Foundation

public struct MonthCalendarLogicalRowOverlay<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>: Identifiable, Sendable {
    public let id: OverlayID
    public let startDate: Date
    public let endDate: Date
    public let payload: OverlayPayload

    public init(
        id: OverlayID,
        startDate: Date,
        endDate: Date,
        payload: OverlayPayload
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.payload = payload
    }
}

public struct MonthCalendarRowOverlayFrame: Sendable {
    public let leadingFraction: Double
    public let widthFraction: Double
    public let topFraction: Double
    public let heightFraction: Double

    public init(
        leadingFraction: Double,
        widthFraction: Double,
        topFraction: Double,
        heightFraction: Double
    ) {
        self.leadingFraction = leadingFraction
        self.widthFraction = widthFraction
        self.topFraction = topFraction
        self.heightFraction = heightFraction
    }
}

public struct MonthCalendarPackedRowOverlayRenderContext<
    OverlayID: Hashable & Sendable,
    OverlayPayload: Sendable
>: Identifiable, Sendable {
    public let overlay: MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>
    public let week: MonthCalendarWeekContext
    public let visibleStartDate: Date
    public let visibleEndDate: Date
    public let startColumn: Int
    public let endColumn: Int
    public let laneIndex: Int
    public let visibleSegmentLaneCount: Int
    public let displayLaneCount: Int
    public let continuesBeforeWeek: Bool
    public let continuesAfterWeek: Bool
    public let frame: MonthCalendarRowOverlayFrame

    public var id: String {
        "week-\(week.id)-lane-\(laneIndex)-overlay-\(overlay.id)"
    }

    public init(
        overlay: MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>,
        week: MonthCalendarWeekContext,
        visibleStartDate: Date,
        visibleEndDate: Date,
        startColumn: Int,
        endColumn: Int,
        laneIndex: Int,
        visibleSegmentLaneCount: Int,
        displayLaneCount: Int,
        continuesBeforeWeek: Bool,
        continuesAfterWeek: Bool,
        frame: MonthCalendarRowOverlayFrame
    ) {
        self.overlay = overlay
        self.week = week
        self.visibleStartDate = visibleStartDate
        self.visibleEndDate = visibleEndDate
        self.startColumn = startColumn
        self.endColumn = endColumn
        self.laneIndex = laneIndex
        self.visibleSegmentLaneCount = visibleSegmentLaneCount
        self.displayLaneCount = displayLaneCount
        self.continuesBeforeWeek = continuesBeforeWeek
        self.continuesAfterWeek = continuesAfterWeek
        self.frame = frame
    }
}

public struct MonthCalendarOverflowedRowOverlaySegment<
    OverlayID: Hashable & Sendable,
    OverlayPayload: Sendable
>: Identifiable, Sendable {
    public let overlay: MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>
    public let week: MonthCalendarWeekContext
    public let visibleStartDate: Date
    public let visibleEndDate: Date
    public let startColumn: Int
    public let endColumn: Int
    public let packedLaneIndex: Int
    public let continuesBeforeWeek: Bool
    public let continuesAfterWeek: Bool
    public let frame: MonthCalendarRowOverlayFrame

    public var id: String {
        "week-\(week.id)-overflow-\(packedLaneIndex)-overlay-\(overlay.id)"
    }

    public init(
        overlay: MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>,
        week: MonthCalendarWeekContext,
        visibleStartDate: Date,
        visibleEndDate: Date,
        startColumn: Int,
        endColumn: Int,
        packedLaneIndex: Int,
        continuesBeforeWeek: Bool,
        continuesAfterWeek: Bool,
        frame: MonthCalendarRowOverlayFrame
    ) {
        self.overlay = overlay
        self.week = week
        self.visibleStartDate = visibleStartDate
        self.visibleEndDate = visibleEndDate
        self.startColumn = startColumn
        self.endColumn = endColumn
        self.packedLaneIndex = packedLaneIndex
        self.continuesBeforeWeek = continuesBeforeWeek
        self.continuesAfterWeek = continuesAfterWeek
        self.frame = frame
    }
}

public struct MonthCalendarRowOverlayOverflowRenderContext<
    OverlayID: Hashable & Sendable,
    OverlayPayload: Sendable
>: Identifiable, Sendable {
    public let week: MonthCalendarWeekContext
    public let visibleSegmentLaneCount: Int
    public let displayLaneCount: Int
    public let hiddenPackedLaneCount: Int
    public let hiddenSegments: [MonthCalendarOverflowedRowOverlaySegment<OverlayID, OverlayPayload>]
    public let frame: MonthCalendarRowOverlayFrame

    public var id: String {
        "week-\(week.id)-overflow"
    }

    public var hiddenSegmentCount: Int {
        hiddenSegments.count
    }

    public init(
        week: MonthCalendarWeekContext,
        visibleSegmentLaneCount: Int,
        displayLaneCount: Int,
        hiddenPackedLaneCount: Int,
        hiddenSegments: [MonthCalendarOverflowedRowOverlaySegment<OverlayID, OverlayPayload>],
        frame: MonthCalendarRowOverlayFrame
    ) {
        self.week = week
        self.visibleSegmentLaneCount = visibleSegmentLaneCount
        self.displayLaneCount = displayLaneCount
        self.hiddenPackedLaneCount = hiddenPackedLaneCount
        self.hiddenSegments = hiddenSegments
        self.frame = frame
    }
}

public struct MonthCalendarPackedRowOverlayWeekLayout<
    OverlayID: Hashable & Sendable,
    OverlayPayload: Sendable
>: Identifiable, Sendable {
    public let week: MonthCalendarWeekContext
    public let visibleSegments: [MonthCalendarPackedRowOverlayRenderContext<OverlayID, OverlayPayload>]
    public let overflow: MonthCalendarRowOverlayOverflowRenderContext<OverlayID, OverlayPayload>?
    public let totalPackedLaneCount: Int
    public let visibleSegmentLaneCount: Int
    public let displayLaneCount: Int

    public var id: Int {
        week.id
    }

    public init(
        week: MonthCalendarWeekContext,
        visibleSegments: [MonthCalendarPackedRowOverlayRenderContext<OverlayID, OverlayPayload>],
        overflow: MonthCalendarRowOverlayOverflowRenderContext<OverlayID, OverlayPayload>?,
        totalPackedLaneCount: Int,
        visibleSegmentLaneCount: Int,
        displayLaneCount: Int
    ) {
        self.week = week
        self.visibleSegments = visibleSegments
        self.overflow = overflow
        self.totalPackedLaneCount = totalPackedLaneCount
        self.visibleSegmentLaneCount = visibleSegmentLaneCount
        self.displayLaneCount = displayLaneCount
    }
}
