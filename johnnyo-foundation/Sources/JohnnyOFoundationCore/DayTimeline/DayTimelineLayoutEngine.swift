import Foundation

/// Computes `DayTimelineItemContext` values for a set of timeline items.
///
/// Encapsulates the column-partitioning and minimum-height logic so it can be
/// unit-tested independently of SwiftUI views.
///
/// Usage from `DayTimelineView`:
/// ```swift
/// let contexts = DayTimelineLayoutEngine.layoutContexts(
///     items: timedItems,
///     startDate: provider.startDate,
///     endDate: provider.endDate,
///     isAllDay: provider.isAllDay,
///     coordinateSpace: coordinateSpace,
///     minimumEventHeight: 44,
///     minimumHeightThresholdSeconds: 30 * 60
/// )
/// ```
public enum DayTimelineLayoutEngine {

    /// Computes layout contexts for a list of items using greedy column partitioning.
    ///
    /// - Parameters:
    ///   - items: All items (all-day and timed). All-day items are filtered out automatically.
    ///   - startDate: Closure that returns the start date for an item.
    ///   - endDate: Closure that returns the end date for an item.
    ///   - isAllDay: Closure that returns `true` for all-day items to exclude from the grid.
    ///   - coordinateSpace: The time→Y coordinate mapping for the visible window.
    ///   - minimumEventHeight: Floor height applied to events shorter than the threshold.
    ///   - minimumHeightThresholdSeconds: Duration (in seconds) below which the floor applies.
    /// - Returns: One `DayTimelineItemContext` per timed item, with column assignments and clamped heights.
    public static func layoutContexts<Item: Identifiable>(
        items: [Item],
        startDate: (Item) -> Date,
        endDate: (Item) -> Date,
        isAllDay: (Item) -> Bool,
        coordinateSpace: DayTimeCoordinateSpace,
        minimumEventHeight: CGFloat,
        minimumHeightThresholdSeconds: TimeInterval
    ) -> [DayTimelineItemContext<Item>] {
        let timedItems = items.filter { !isAllDay($0) }
        let sorted = timedItems.sorted { startDate($0) < startDate($1) }
        guard !sorted.isEmpty else { return [] }

        // Build collision clusters: contiguous groups of overlapping events.
        var clusters: [[Item]] = []
        var currentCluster: [Item] = []
        var clusterEnd: Date = .distantPast

        for item in sorted {
            let start = startDate(item)
            let end = endDate(item)
            if start < clusterEnd {
                currentCluster.append(item)
                clusterEnd = max(clusterEnd, end)
            } else {
                if !currentCluster.isEmpty { clusters.append(currentCluster) }
                currentCluster = [item]
                clusterEnd = end
            }
        }
        if !currentCluster.isEmpty { clusters.append(currentCluster) }

        // Assign columns within each cluster and build contexts.
        var contexts: [DayTimelineItemContext<Item>] = []
        for cluster in clusters {
            let assignments = assignColumns(cluster, startDate: startDate, endDate: endDate)
            let totalColumns = (assignments.values.max() ?? 0) + 1

            for item in cluster {
                let col = assignments[item.id] ?? 0
                let start = startDate(item)
                let end = endDate(item)
                let yOff = coordinateSpace.yOffset(for: start)
                let rawHeight = coordinateSpace.height(from: start, to: end)
                let duration = end.timeIntervalSince(start)
                let clampedHeight = duration < minimumHeightThresholdSeconds
                    ? max(rawHeight, minimumEventHeight)
                    : rawHeight

                contexts.append(DayTimelineItemContext(
                    item: item,
                    yOffset: yOff,
                    height: clampedHeight,
                    columnIndex: col,
                    columnCount: totalColumns,
                    coordinateSpace: coordinateSpace
                ))
            }
        }
        return contexts
    }

    // MARK: - Private

    /// Assigns a column index to each item in a collision cluster using greedy scheduling.
    ///
    /// Places each event (sorted by start time) into the leftmost column whose latest
    /// end time is at or before the event's start. Returns a dictionary of `Item.ID → columnIndex`.
    private static func assignColumns<Item: Identifiable>(
        _ cluster: [Item],
        startDate: (Item) -> Date,
        endDate: (Item) -> Date
    ) -> [Item.ID: Int] {
        var assignments: [Item.ID: Int] = [:]
        var columnEnds: [Int: Date] = [:]

        let sorted = cluster.sorted { startDate($0) < startDate($1) }
        for item in sorted {
            let start = startDate(item)
            let col = (0...).first { (columnEnds[$0] ?? .distantPast) <= start } ?? 0
            assignments[item.id] = col
            columnEnds[col] = endDate(item)
        }
        return assignments
    }
}
