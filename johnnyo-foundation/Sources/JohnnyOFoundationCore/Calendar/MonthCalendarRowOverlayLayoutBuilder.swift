import Foundation

public enum MonthCalendarRowOverlayLayoutBuilder {
    /// Memoizes `makeWeekLayouts` results per `(overlays, model, calendar, maximumVisibleLaneCount)`
    /// combination, mirroring `MonthCalendarModelBuilder`'s cache — `MonthCalendarView.init` calls
    /// this synchronously on every re-render of an already-visible month, and the inputs are fully
    /// deterministic. `OverlayPayload: Hashable` (tightened in a prior increment) lets the key
    /// include the actual overlay values, so a payload change for the same id/date-range is never
    /// served stale.
    ///
    /// Swift does not support static stored properties directly inside a generic type, so storage
    /// is type-erased behind one non-generic singleton, keyed by the `(OverlayID, OverlayPayload)`
    /// type pair plus the typed `CacheKey`. Each generic call site casts back to its own concrete
    /// dictionary type, which is always safe here since the cast target is derived from the same
    /// `OverlayID`/`OverlayPayload` used to build the type-pair key.
    private final class Cache: @unchecked Sendable {
        static let shared = Cache()

        private struct TypePairKey: Hashable {
            let overlayID: ObjectIdentifier
            let overlayPayload: ObjectIdentifier
        }

        private let lock = NSLock()
        private var storages: [TypePairKey: Any] = [:]
        private var missCounts: [TypePairKey: Int] = [:]

        private func typePairKey<OverlayID, OverlayPayload>(
            overlayID: OverlayID.Type,
            overlayPayload: OverlayPayload.Type
        ) -> TypePairKey {
            TypePairKey(overlayID: ObjectIdentifier(overlayID), overlayPayload: ObjectIdentifier(overlayPayload))
        }

        func layouts<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
            for key: CacheKey<OverlayID, OverlayPayload>,
            build: () -> [MonthCalendarPackedRowOverlayWeekLayout<OverlayID, OverlayPayload>]
        ) -> [MonthCalendarPackedRowOverlayWeekLayout<OverlayID, OverlayPayload>] {
            lock.lock()
            defer { lock.unlock() }

            let typeKey = typePairKey(overlayID: OverlayID.self, overlayPayload: OverlayPayload.self)
            var typedStorage = (storages[typeKey] as? [CacheKey<OverlayID, OverlayPayload>: [MonthCalendarPackedRowOverlayWeekLayout<OverlayID, OverlayPayload>]]) ?? [:]

            if let cached = typedStorage[key] {
                return cached
            }

            let layouts = build()
            typedStorage[key] = layouts
            storages[typeKey] = typedStorage
            missCounts[typeKey, default: 0] += 1
            return layouts
        }

        func missCountForTesting<OverlayID, OverlayPayload>(
            overlayID: OverlayID.Type,
            overlayPayload: OverlayPayload.Type
        ) -> Int {
            lock.lock()
            defer { lock.unlock() }
            return missCounts[typePairKey(overlayID: overlayID, overlayPayload: overlayPayload)] ?? 0
        }

        func removeAllForTesting<OverlayID, OverlayPayload>(
            overlayID: OverlayID.Type,
            overlayPayload: OverlayPayload.Type
        ) {
            lock.lock()
            defer { lock.unlock() }
            let typeKey = typePairKey(overlayID: overlayID, overlayPayload: overlayPayload)
            storages[typeKey] = nil
            missCounts[typeKey] = nil
        }
    }

    private struct CacheKey<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>: Hashable {
        let overlays: [MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>]
        let model: MonthCalendarModel
        let calendar: Calendar
        let maximumVisibleLaneCount: Int
    }

    /// Number of times `makeWeekLayouts` has actually recomputed layouts (cache misses) for the
    /// given `(OverlayID, OverlayPayload)` specialization, since the last `resetCacheForTesting()`
    /// for that specialization. Internal — reachable only via `@testable import`.
    static func buildCountForTesting<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
        overlayID: OverlayID.Type,
        overlayPayload: OverlayPayload.Type
    ) -> Int {
        Cache.shared.missCountForTesting(overlayID: overlayID, overlayPayload: overlayPayload)
    }

    /// Clears the memoization cache for the given `(OverlayID, OverlayPayload)` specialization
    /// and resets its `buildCountForTesting`. Test-only.
    static func resetCacheForTesting<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
        overlayID: OverlayID.Type,
        overlayPayload: OverlayPayload.Type
    ) {
        Cache.shared.removeAllForTesting(overlayID: overlayID, overlayPayload: overlayPayload)
    }

    /// Builds packed week-row layouts for logical overlays in a month shell.
    ///
    /// Foundation owns row segmentation, same-row lane packing, visible-lane limiting,
    /// and overflow metadata derivation. Visible peripheral dates participate when they
    /// are rendered as day cells; hidden placeholder slots do not.
    public static func makeWeekLayouts<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
        overlays: [MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>],
        model: MonthCalendarModel,
        calendar: Calendar,
        maximumVisibleLaneCount: Int
    ) -> [MonthCalendarPackedRowOverlayWeekLayout<OverlayID, OverlayPayload>] {
        let key = CacheKey(
            overlays: overlays,
            model: model,
            calendar: calendar,
            maximumVisibleLaneCount: maximumVisibleLaneCount
        )

        return Cache.shared.layouts(for: key) {
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
    }

    private static func makeWeekLayout<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
        for week: MonthCalendarWeek,
        overlays: [NormalizedOverlay<OverlayID, OverlayPayload>],
        visibleLaneCount: Int
    ) -> MonthCalendarPackedRowOverlayWeekLayout<OverlayID, OverlayPayload> {
        let visibleDays = week.slots.enumerated().compactMap { column, slot -> VisibleDay? in
            guard case .day(let date, _, _) = slot else { return nil }
            return VisibleDay(date: date, column: column)
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
                        slotIndexFromBottom: overflowedSegments.isEmpty
                            ? segment.packedLaneIndex
                            : segment.packedLaneIndex + 1,
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

    private static func makeRowSegment<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
        for overlay: NormalizedOverlay<OverlayID, OverlayPayload>,
        week: MonthCalendarWeek,
        visibleDays: [VisibleDay]
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

    private static func rowSegmentSortOrder<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
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

    private static func pack<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
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

    private static func overflowContext<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>(
        week: MonthCalendarWeek,
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
                    slotIndexFromBottom: 0,
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
        slotIndexFromBottom: Int,
        displayLaneCount: Int
    ) -> MonthCalendarRowOverlayFrame {
        MonthCalendarRowOverlayFrame(
            leadingFraction: Double(startColumn) / 7,
            widthFraction: Double(endColumn - startColumn + 1) / 7,
            topFraction: displayLaneCount > 0
                ? Double(displayLaneCount - slotIndexFromBottom - 1) / Double(displayLaneCount)
                : 0,
            heightFraction: displayLaneCount > 0 ? 1 / Double(displayLaneCount) : 0
        )
    }
}

private struct NormalizedOverlay<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>: Sendable {
    let overlay: MonthCalendarLogicalRowOverlay<OverlayID, OverlayPayload>
    let sourceIndex: Int
    let startDate: Date
    let endDate: Date
}

private struct RowSegment<OverlayID: Hashable & Sendable, OverlayPayload: Hashable & Sendable>: Sendable {
    let overlay: NormalizedOverlay<OverlayID, OverlayPayload>
    let week: MonthCalendarWeek
    let visibleStartDate: Date
    let visibleEndDate: Date
    let startColumn: Int
    let endColumn: Int
    let continuesBeforeWeek: Bool
    let continuesAfterWeek: Bool
    var packedLaneIndex: Int
}

private struct VisibleDay: Sendable {
    let date: Date
    let column: Int
}
