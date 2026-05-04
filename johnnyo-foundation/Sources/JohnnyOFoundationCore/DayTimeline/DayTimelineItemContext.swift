import Foundation

/// Layout and identity context passed to a `DayTimelineContentProvider` for rendering one timeline item.
///
/// The package computes all positional values; the conformer uses them to place and size
/// its view content exactly as it wants.
public struct DayTimelineItemContext<Item: Identifiable>: Identifiable {

    // MARK: - Properties

    /// The data item being rendered.
    public let item: Item

    /// Y-offset from the top of the timeline view, in points.
    public let yOffset: CGFloat

    /// Rendered height for the item, in points.
    public let height: CGFloat

    /// Leading inset applied when this item overlaps an earlier item, in points.
    /// Zero when no overlap with any earlier event.
    public let overlapOffset: CGFloat

    /// The coordinate space that produced this context; available for custom math.
    public let coordinateSpace: DayTimeCoordinateSpace

    // MARK: - Identifiable

    public var id: Item.ID { item.id }

    // MARK: - Init

    public init(
        item: Item,
        yOffset: CGFloat,
        height: CGFloat,
        overlapOffset: CGFloat,
        coordinateSpace: DayTimeCoordinateSpace
    ) {
        self.item = item
        self.yOffset = yOffset
        self.height = height
        self.overlapOffset = overlapOffset
        self.coordinateSpace = coordinateSpace
    }
}
