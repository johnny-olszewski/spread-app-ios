import SwiftUI

/// A card view representing a single month within a year spread.
///
/// Displays a mini month grid alongside entry content, adapting its layout
/// to the horizontal size class. The card's visual style is driven by
/// `SpreadCardStyle`, which encodes whether the month is current and whether
/// a spread exists for it.
struct MonthCardView: View {

    // MARK: - Style

    /// Drives the content area of the card.
    enum Style {
        /// Displays a task-count summary with optional peek and view-spread actions.
        case count(taskCount: Int)
        /// Displays an optional entry list with an optional create-spread action.
        case list(
            sections: [EntryList.Section],
            configurationMap: [EntryType: EntryRowView.Configuration]
        )
    }

    // MARK: - Properties

    let monthDate: Date
    let calendar: Calendar
    let visualState: SpreadCardStyle
    let style: Style

    var onPeek: (() -> Void)? = nil
    var onViewSpread: (() -> Void)? = nil
    var onCreateSpread: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Layout

    private enum Layout {
        static let cardCornerRadius: CGFloat = 18
        static let cardPadding: CGFloat = 14
        static let cardSpacing: CGFloat = 12
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            header

            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .padding(Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .strokeBorder(visualState.borderColor, style: visualState.borderStyle)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthDate.formatted(.dateTime.month(.wide)))
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(visualState.primaryHeaderColor)

            Spacer(minLength: 8)

            if visualState.isToday {
                Text("This Month")
                    .font(SpreadTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(SpreadTheme.Accent.todayEmphasis)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(SpreadTheme.Accent.todayEmphasis.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - Layout Variants

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: Layout.cardSpacing) {
            MiniMonthGridView(monthDate: monthDate, calendar: calendar, visualState: visualState)
                .containerRelativeFrame(.horizontal, count: 10, span: 3, spacing: 0)
                .frame(maxHeight: .infinity)

            contentArea
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            MiniMonthGridView(monthDate: monthDate, calendar: calendar, visualState: visualState)
            contentArea
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch style {
        case .count(let taskCount):
            VStack(alignment: .center) {
                taskSummaryRow(openTaskCount: taskCount)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Spacer()
                    if let onPeek {
                        Button(action: onPeek) {
                            Image(systemName: "eye")
                                .font(.system(size: SpreadTheme.IconSize.small, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Preview month spread")
                    }

                    if let onViewSpread {
                        Button(action: onViewSpread) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: SpreadTheme.IconSize.small, weight: .semibold))
                                .foregroundStyle(SpreadTheme.Accent.todaySelectedEmphasis)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(.white.opacity(0.94)))
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("View month spread")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .list(let sections, let configurationMap):
            VStack(alignment: .leading, spacing: Layout.cardSpacing) {
                EntryListView(sections: sections, configurationMap: configurationMap, style: .inline)
                if let onCreateSpread {
                    Button("Create Spread") {
                        onCreateSpread()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Task Summary

    private func taskSummaryRow(openTaskCount: Int) -> some View {
        HStack(spacing: 24) {
            Label {
                Text("\(openTaskCount)")
                    .font(SpreadTheme.Typography.title3)
                    .fontWeight(.medium)
            } icon: {
                Image(systemName: "circle")
                    .font(.system(size: 15))
            }
            .foregroundStyle(openTaskCount > 0 ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(openTaskCount) open tasks")
    }

    // MARK: - Background

    private var backgroundFill: Color {
        if visualState.isToday { return visualState.fill }
        if visualState.isCreated { return SpreadTheme.Paper.secondary.opacity(0.45) }
        return SpreadTheme.Paper.primary.opacity(0.65)
    }
}

// MARK: - Mini Month Grid

private struct MiniMonthGridView: View {
    private let monthDate: Date
    private let calendar: Calendar
    private let visualState: SpreadCardStyle

    private enum Layout {
        static let cellHeight: CGFloat = 24
        static let gridSpacing: CGFloat = 4
    }

    init(
        monthDate: Date,
        calendar: Calendar,
        visualState: SpreadCardStyle
    ) {
        self.monthDate = monthDate
        self.calendar = calendar
        self.visualState = visualState
    }

    private var headers: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        return formatter.shortStandaloneWeekdaySymbols
            .reorderedByFirstWeekday(calendar.firstWeekday)
            .map { String($0.prefix(1)).uppercased() }
    }

    private var cells: [MiniMonthCell] {
        let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let firstWeekdayOfMonth = calendar.component(.weekday, from: monthStart)
        let leadingPlaceholders = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7

        var cells = Array(repeating: MiniMonthCell(dayNumber: nil), count: leadingPlaceholders)
        cells.append(contentsOf: dayRange.map { MiniMonthCell(dayNumber: $0) })

        let trailingPlaceholders = (7 - (cells.count % 7)) % 7
        if trailingPlaceholders > 0 {
            cells.append(contentsOf: Array(repeating: MiniMonthCell(dayNumber: nil), count: trailingPlaceholders))
        }

        return cells
    }

    var body: some View {
        VStack(spacing: Layout.gridSpacing) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    Group {
                        if let dayNumber = cell.dayNumber {
                            Text("\(dayNumber)")
                                .font(.system(size: 10, weight: visualState.headerWeight))
                                .foregroundStyle(visualState.primaryHeaderColor)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: Layout.cellHeight)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private struct MiniMonthCell {
        let dayNumber: Int?
    }
}

private extension Array where Element == String {
    func reorderedByFirstWeekday(_ firstWeekday: Int) -> [String] {
        guard !isEmpty else { return self }
        let normalizedIndex = Swift.max(0, Swift.min(count - 1, firstWeekday - 1))
        return Array(self[normalizedIndex...]) + Array(self[..<normalizedIndex])
    }
}
