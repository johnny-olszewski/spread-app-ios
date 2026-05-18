import SwiftUI

/// Renders a multiday spread as a responsive grid of day cards.
///
/// Each day card shows either a summary tile (when an explicit day spread exists)
/// or the full entry list for that day. Multiday-assigned tasks appear in a full-width
/// assignment section above the day cards.
///
/// Callers compute `[EntryListSection]` using `EntryListGrouper` with the multiday
/// period, then pass the ViewModel for inline creation state and inject entry row
/// rendering via `rowContent`.
struct MultidayEntryGridView<RowContent: View>: View {

    // MARK: - Properties

    @Bindable var viewModel: EntryListViewModel

    /// The multiday spread being displayed. Used for overdue calculations.
    let spread: DataModel.Spread

    var explicitDaySpreadForDate: ((Date) -> DataModel.Spread?)? = nil
    var onSelectSpread: ((DataModel.Spread) -> Void)? = nil
    var onCreateSpread: ((Date) -> Void)? = nil
    var openTaskCountForDaySpread: ((DataModel.Spread) -> Int)? = nil
    var peekDataForDaySpread: ((DataModel.Spread) -> MultidayPeekData?)? = nil
    var onPeekTaskTap: ((DataModel.Spread, DataModel.Task) -> Void)? = nil

    @ViewBuilder var rowContent: (any Entry, String?) -> RowContent

    // MARK: - View-owned state

    @State private var activePeekData: MultidayPeekData?

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
                ForEach(viewModel.sections) { section in
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
            MultidayPeekPanelView(
                data: data,
                calendar: viewModel.calendar,
                today: viewModel.today,
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
    private func daySection(_ section: EntryListSection) -> some View {
        let explicitDaySpread = explicitDaySpreadForDate?(section.date)
        MultidayDaySectionView(
            viewModel: viewModel,
            section: section,
            parentSpread: spread,
            explicitDaySpread: explicitDaySpread,
            openTaskCount: explicitDaySpread.flatMap { openTaskCountForDaySpread?($0) } ?? 0,
            onFooterTap: {
                viewModel.dismissActiveInlineEditing()
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
        ) { entry, contextualLabel in
            rowContent(entry, contextualLabel)
        }
    }

    private func assignmentSection(_ section: EntryListSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.entries, id: \.id) { entry in
                    rowContent(entry, section.contextualLabel(for: entry))
                }

                if let onAddTask = viewModel.onAddTask {
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

