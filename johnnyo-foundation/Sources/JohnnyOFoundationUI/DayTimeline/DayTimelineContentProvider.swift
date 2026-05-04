import SwiftUI
import JohnnyOFoundationCore

/// Supplies item rendering and ruler labels to `DayTimelineView`.
///
/// Conformers provide:
/// - time-range accessors so the package can compute layout for each item
/// - an `isAllDay` predicate so the view can exclude all-day items from the timed grid
/// - a view-builder for the item's visual content (position is handled by the package)
/// - a view-builder for the hour labels shown in the time ruler
///
/// This protocol mirrors the `CalendarContentGenerator` pattern: the package owns
/// structural math and layout; the conformer owns appearance.
public protocol DayTimelineContentProvider {
    associatedtype Item: Identifiable
    associatedtype ItemContent: View
    associatedtype TimeRulerLabel: View

    /// Returns the start date of the given item.
    func startDate(for item: Item) -> Date

    /// Returns the end date of the given item.
    func endDate(for item: Item) -> Date

    /// Returns `true` when the item spans the entire day and should be excluded
    /// from the proportional time grid.
    ///
    /// All-day items are typically shown in a sticky header above the timed grid
    /// (e.g. via `DayTimelineAllDaySection`) rather than positioned on the ruler.
    /// The default implementation returns `false`.
    func isAllDay(item: Item) -> Bool

    /// Returns a view representing the item's visual content.
    ///
    /// The package positions the returned view using `context.yOffset`,
    /// `context.height`, and `context.overlapOffset`; the conformer need only
    /// render the appearance (background, text, borders, etc.).
    @ViewBuilder func itemView(context: DayTimelineItemContext<Item>) -> ItemContent

    /// Returns a label view for the given hour (0–23) in the time ruler.
    @ViewBuilder func timeRulerLabel(hour: Int) -> TimeRulerLabel
}

// MARK: - Default implementations

extension DayTimelineContentProvider {
    /// All-day is opt-in; the default treats every item as a timed event.
    public func isAllDay(item: Item) -> Bool { false }
}
