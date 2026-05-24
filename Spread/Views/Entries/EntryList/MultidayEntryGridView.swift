import SwiftUI

/// Renders a multiday spread as a responsive grid of day cards.
///
/// Each day card shows either a summary tile (when an explicit day spread exists)
/// or the full entry list for that day. Multiday-assigned tasks appear in a full-width
/// assignment section above the day cards.
///
/// Callers compute `[EntryList.Section]` via `MultidaySpreadContentView.ViewModel.makeSections`
/// and inject entry row rendering via `rowContent`.
struct MultidayEntryGridView<RowContent: View>: View {

    // MARK: - Properties

    let sections: [EntryList.Section]
    let calendar: Calendar
    let today: Date
    var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?

    /// The multiday spread being displayed. Used for overdue calculations.
    let spread: DataModel.Spread

    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil
    var onSelectSpread: ((DataModel.Spread) -> Void)? = nil
    var onCreateSpread: ((Date) -> Void)? = nil
    var openTaskCountForDaySpread: ((DataModel.Spread) -> Int)? = nil
    var peekDataForDaySpread: ((DataModel.Spread) -> SpreadPeekPanelView.Data?)? = nil
    var onPeekTaskTap: ((DataModel.Spread, DataModel.Task) -> Void)? = nil

    @ViewBuilder var rowContent: (any Entry) -> RowContent

    // MARK: - View-owned state

    @State private var activePeekData: SpreadPeekPanelView.Data?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columnCount: Int {
        MultidaySectionLayout.columnCount(for: horizontalSizeClass)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                    count: columnCount
                ),
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(sections) { section in
                    if section.creationPeriod == .multiday {
                        assignmentSection(section)
                            .gridCellColumns(columnCount)
                    } else {
                        daySection(section)
                    }
                }
            }
            .padding(16)
        }
        .sheet(item: $activePeekData) { data in
            SpreadPeekPanelView(
                data: data,
                calendar: calendar,
                today: today,
                onClose: { activePeekData = nil },
                onNavigate: { spread in
                    activePeekData = nil
                    onSelectSpread?(spread)
                },
                onTaskTap: onPeekTaskTap != nil ? { task in
                    activePeekData = nil
                    onPeekTaskTap?(data.spread, task)
                } : nil
            )
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid)
    }

    // MARK: - Sections

    @ViewBuilder
    private func daySection(_ section: EntryList.Section) -> some View {
        let explicitDaySpread = explicitDaySpreadForDate?(section.date)
        MultidayDaySectionView(
            section: section,
            parentSpread: spread,
            explicitDaySpread: explicitDaySpread,
            openTaskCount: explicitDaySpread.flatMap { openTaskCountForDaySpread?($0) } ?? 0,
            calendar: calendar,
            today: today,
            onAddTask: onAddTask,
            onFooterTap: {
                if let daySpread = explicitDaySpread {
                    onSelectSpread?(daySpread)
                } else {
                    onCreateSpread?(section.date)
                }
            },
            onPeek: peekDataForDaySpread != nil ? {
                guard let daySpread = explicitDaySpread,
                      let data = peekDataForDaySpread?(daySpread) else { return }
                activePeekData = data
            } : nil
        ) { entry in
            rowContent(entry)
        }
    }

    private func assignmentSection(_ section: EntryList.Section) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.entries, id: \.id) { entry in
                    rowContent(entry)
                }

                if let onAddTask {
                    AddTaskButton(date: section.creationDate, period: section.creationPeriod, onAddTask: onAddTask)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

}

// MARK: - Column Count

enum MultidaySectionLayout {
    static func columnCount(for horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        horizontalSizeClass == .regular ? 2 : 1
    }
}
