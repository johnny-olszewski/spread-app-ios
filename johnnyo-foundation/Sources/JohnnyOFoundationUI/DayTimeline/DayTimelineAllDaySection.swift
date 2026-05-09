import SwiftUI

/// A non-scrolling section that renders all-day timeline items in a compact list.
///
/// Intended to be placed above a `DayTimelineView` (typically outside its parent
/// `ScrollView`) so all-day events remain pinned at the top of the card while
/// timed events scroll independently beneath them.
///
/// Usage:
/// ```swift
/// VStack(spacing: 0) {
///     DayTimelineAllDaySection(items: allDayEvents) { event in
///         AllDayEventChip(event: event)
///     }
///     Divider()
///     ScrollView {
///         DayTimelineView(provider: ..., items: timedEvents, ...)
///     }
/// }
/// ```
public struct DayTimelineAllDaySection<Item: Identifiable, Content: View>: View {

    // MARK: - Properties

    public let items: [Item]
    public let content: (Item) -> Content

    // MARK: - Init

    public init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.id) { item in
                content(item)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
