import Foundation

public enum MonthCalendarRowOverlayLayoutBuilder {
    public static func makeWeekLayouts<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>(
        overlays: [MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>],
        model: MonthCalendarModel,
        calendar: Calendar,
        maximumVisibleLaneCount: Int
    ) -> [MonthCalendarPackedRowOverlayWeekLayout<OverlayID, OverlayPayload>] {
        let normalizedOverlays = overlays.enumerated().map { sourceIndex, overlay in
            NormalizedOverlay(
                overlay: overlay,
                sourceIndex: sourceIndex,
                startDate: calendar.startOfDay(for: min(overlay.startDate, overlay.endDate)),
                endDate: calendar.startOfDay(for: max(overlay.startDate, overlay.endDate))
            )
        }
        let clampedVisibleLaneCount = max(0, maximumVisibleLaneCount)

        return model.weeks.map { week in
            makeWeekLayout(
                for: week,
                overlays: normalizedOverlays,
                visibleLaneCount: clampedVisibleLaneCount
            )
        }
    }

    private static func makeWeekLayout<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>(
        for week: MonthCalendarWeekContext,
        overlays: [NormalizedOverlay<OverlayID, OverlayPayload>],
        visibleLaneCount: Int
    ) -> MonthCalendarPackedRowOverlayWeekLayout<OverlayID, OverlayPayload> {
        let visibleDays = week.slots.compactMap { slot -> MonthCalendarDayContext? in
            guard case .day(let context) = slot else { return nil }
            return context
        }

        guard !visibleDays.isEmpty else {
            return MonthCalendarPackedRowOverlayWeekLayout(
                week: week,
                visibleSegments: [],
                overflow: nil,
                totalPackedLaneCount: 0,
                visibleSegmentLaneCount: 0,
                displayLaneCount: 0
            )
        }

        let rowSegments = overlays.compactMap { overlay in
            makeRowSegment(for: overlay, week: week, visibleDays: visibleDays)
        }
        .sorted(by: rowSegmentSortOrder)

        let packedSegments = pack(rowSegments)
        let totalPackedLaneCount = packedSegments.map(\.packedLaneIndex).max().map { $0 + 1 } ?? 0
        let visibleSegmentLaneCount = min(totalPackedLaneCount, visibleLaneCount)
        let overflowedSegments = packedSegments.filter { $0.packedLaneIndex >= visibleSegmentLaneCount }
        let displayLaneCount = visibleSegmentLaneCount + (overflowedSegments.isEmpty ? 0 : 1)

        let visibleSegments = packedSegments
            .filter { $0.packedLaneIndex < visibleSegmentLaneCount }
            .map { segment in
                MonthCalendarPackedRowOverlayRenderContext(
                    overlay: segment.overlay.overlay,
                    week: week,
                    visibleStartDate: segment.visibleStartDate,
                    visibleEndDate: segment.visibleEndDate,
                    startColumn: segment.startColumn,
                    endColumn: segment.endColumn,
                    laneIndex: segment.packedLaneIndex,
                    visibleSegmentLaneCount: visibleSegmentLaneCount,
                    displayLaneCount: displayLaneCount,
                    continuesBeforeWeek: segment.continuesBeforeWeek,
                    continuesAfterWeek: segment.continuesAfterWeek,
                    frame: frame(
                        startColumn: segment.startColumn,
                        endColumn: segment.endColumn,
                        laneIndex: segment.packedLaneIndex,
                        displayLaneCount: displayLaneCount
                    )
                )
            }

        let overflow = overflowContext(
            week: week,
            overflowedSegments: overflowedSegments,
            visibleSegmentLaneCount: visibleSegmentLaneCount,
            displayLaneCount: displayLaneCount
        )

        return MonthCalendarPackedRowOverlayWeekLayout(
            week: week,
            visibleSegments: visibleSegments,
            overflow: overflow,
            totalPackedLaneCount: totalPackedLaneCount,
            visibleSegmentLaneCount: visibleSegmentLaneCount,
            displayLaneCount: displayLaneCount
        )
    }

    private static func makeRowSegment<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>(
        for overlay: NormalizedOverlay<OverlayID, OverlayPayload>,
        week: MonthCalendarWeekContext,
        visibleDays: [MonthCalendarDayContext]
    ) -> RowSegment<OverlayID, OverlayPayload>? {
        let coveredDays = visibleDays.filter { day in
            day.date >= overlay.startDate && day.date <= overlay.endDate
        }

        guard let firstDay = coveredDays.first, let lastDay = coveredDays.last else {
            return nil
        }

        return RowSegment(
            overlay: overlay,
            week: week,
            visibleStartDate: firstDay.date,
            visibleEndDate: lastDay.date,
            startColumn: firstDay.column,
            endColumn: lastDay.column,
            continuesBeforeWeek: overlay.startDate < firstDay.date,
            continuesAfterWeek: overlay.endDate > lastDay.date,
            packedLaneIndex: 0
        )
    }

    private static func rowSegmentSortOrder<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>(
        _ lhs: RowSegment<OverlayID, OverlayPayload>,
        _ rhs: RowSegment<OverlayID, OverlayPayload>
    ) -> Bool {
        if lhs.startColumn != rhs.startColumn {
            return lhs.startColumn < rhs.startColumn
        }
        if lhs.endColumn != rhs.endColumn {
            return lhs.endColumn > rhs.endColumn
        }
        return lhs.overlay.sourceIndex < rhs.overlay.sourceIndex
    }

    private static func pack<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>(
        _ segments: [RowSegment<OverlayID, OverlayPayload>]
    ) -> [RowSegment<OverlayID, OverlayPayload>] {
        var laneEndColumns: [Int] = []

        return segments.map { segment in
            let laneIndex = laneEndColumns.firstIndex(where: { segment.startColumn > $0 }) ?? laneEndColumns.count

            if laneIndex == laneEndColumns.count {
                laneEndColumns.append(segment.endColumn)
            } else {
                laneEndColumns[laneIndex] = segment.endColumn
            }

            var packedSegment = segment
            packedSegment.packedLaneIndex = laneIndex
            return packedSegment
        }
    }

    private static func overflowContext<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>(
        week: MonthCalendarWeekContext,
        overflowedSegments: [RowSegment<OverlayID, OverlayPayload>],
        visibleSegmentLaneCount: Int,
        displayLaneCount: Int
    ) -> MonthCalendarRowOverlayOverflowRenderContext<OverlayID, OverlayPayload>? {
        guard !overflowedSegments.isEmpty else { return nil }

        let hiddenSegments = overflowedSegments.map { segment in
            MonthCalendarOverflowedRowOverlaySegment(
                overlay: segment.overlay.overlay,
                week: week,
                visibleStartDate: segment.visibleStartDate,
                visibleEndDate: segment.visibleEndDate,
                startColumn: segment.startColumn,
                endColumn: segment.endColumn,
                packedLaneIndex: segment.packedLaneIndex,
                continuesBeforeWeek: segment.continuesBeforeWeek,
                continuesAfterWeek: segment.continuesAfterWeek,
                frame: frame(
                    startColumn: segment.startColumn,
                    endColumn: segment.endColumn,
                    laneIndex: segment.packedLaneIndex,
                    displayLaneCount: max(displayLaneCount, 1)
                )
            )
        }

        return MonthCalendarRowOverlayOverflowRenderContext(
            week: week,
            visibleSegmentLaneCount: visibleSegmentLaneCount,
            displayLaneCount: displayLaneCount,
            hiddenPackedLaneCount: Set(hiddenSegments.map(\.packedLaneIndex)).count,
            hiddenSegments: hiddenSegments,
            frame: MonthCalendarRowOverlayFrame(
                leadingFraction: 0,
                widthFraction: 1,
                topFraction: displayLaneCount > 0 ? Double(visibleSegmentLaneCount) / Double(displayLaneCount) : 0,
                heightFraction: displayLaneCount > 0 ? 1 / Double(displayLaneCount) : 0
            )
        )
    }

    private static func frame(
        startColumn: Int,
        endColumn: Int,
        laneIndex: Int,
        displayLaneCount: Int
    ) -> MonthCalendarRowOverlayFrame {
        MonthCalendarRowOverlayFrame(
            leadingFraction: Double(startColumn) / 7,
            widthFraction: Double(endColumn - startColumn + 1) / 7,
            topFraction: displayLaneCount > 0 ? Double(laneIndex) / Double(displayLaneCount) : 0,
            heightFraction: displayLaneCount > 0 ? 1 / Double(displayLaneCount) : 0
        )
    }
}

private struct NormalizedOverlay<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>: Sendable {
    let overlay: MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>
    let sourceIndex: Int
    let startDate: Date
    let endDate: Date
}

private struct RowSegment<OverlayID: Hashable & Sendable, OverlayPayload: Sendable>: Sendable {
    let overlay: NormalizedOverlay<OverlayID, OverlayPayload>
    let week: MonthCalendarWeekContext
    let visibleStartDate: Date
    let visibleEndDate: Date
    let startColumn: Int
    let endColumn: Int
    let continuesBeforeWeek: Bool
    let continuesAfterWeek: Bool
    var packedLaneIndex: Int
}
