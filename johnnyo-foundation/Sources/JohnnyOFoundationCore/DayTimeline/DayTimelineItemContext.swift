import Foundation

/// Layout and identity context passed to a `DayTimelineContentProvider` for rendering one timeline item.
///
/// The package computes all positional values — Y-offset, height, and column placement —
/// so the conformer only needs to render appearance.
///
/// For side-by-side layout of concurrent events, use `columnIndex` and `columnCount` to
/// compute the item's horizontal position and width fraction within the event zone:
///
/// ```swift
/// let columnWidth = availableWidth / CGFloat(context.columnCount)
/// let xOffset = CGFloat(context.columnIndex) * columnWidth
/// ```
public struct DayTimelineItemContext<Item: Identifiable>: Identifiable {

    // MARK: - Properties

    /// The data item being rendered.
    public let item: Item

    /// Y-offset from the top of the timeline view, in points.
    public let yOffset: CGFloat

    /// Rendered height for the item, in points. Guaranteed to be at least the minimum floor
    /// enforced by the package (44pt for events shorter than 30 minutes).
    public let height: CGFloat

    /// Zero-based index of the column this item occupies within its collision cluster.
    ///
    /// When no other events overlap this item, `columnIndex` is `0` and `columnCount` is `1`.
    public let columnIndex: Int

    /// Total number of columns in this item's collision cluster.
    ///
    /// Divide the available event-zone width by `columnCount` to get each column's width,
    /// then multiply by `columnIndex` to get the leading x-offset.
    public let columnCount: Int

    /// The coordinate space that produced this context; available for custom math.
    public let coordinateSpace: DayTimeCoordinateSpace

    // MARK: - Identifiable

    public var id: Item.ID { item.id }

    // MARK: - Init

    public init(
        item: Item,
        yOffset: CGFloat,
        height: CGFloat,
        columnIndex: Int,
        columnCount: Int,
        coordinateSpace: DayTimeCoordinateSpace
    ) {
        self.item = item
        self.yOffset = yOffset
        self.height = height
        self.columnIndex = columnIndex
        self.columnCount = columnCount
        self.coordinateSpace = coordinateSpace
    }
}
