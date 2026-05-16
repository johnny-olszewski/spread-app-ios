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
    @FocusState private var isInlineFocused: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.eventKitService) private var eventKitService

    private var columnCount: Int {
        MultidaySectionLayout.columnCount(for: horizontalSizeClass)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if let status = viewModel.syncStatus, status != .localOnly {
                Text(status.pullIndicatorTitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

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
        .modifier(RefreshableModifier(onRefresh: viewModel.onRefresh))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isInlineFocused {
                    Button("Cancel") {
                        viewModel.dismissInlineCreation()
                        isInlineFocused = false
                    }
                    .glassEffect(in: Capsule())

                    Spacer()

                    Button("Save") {
                        if let target = viewModel.activeInlineCreationTarget {
                            viewModel.commitInlineTask(target: target)
                        }
                    }
                    .glassEffect(in: Capsule())
                    .disabled(viewModel.inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onChange(of: isInlineFocused) { _, focused in
            if focused {
                viewModel.hasAcquiredInlineCreationFocus = true
                return
            }
            guard viewModel.hasAcquiredInlineCreationFocus,
                  viewModel.activeInlineCreationTarget != nil else { return }
            let trimmed = viewModel.inlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                viewModel.dismissInlineCreation()
                isInlineFocused = false
            } else if let target = viewModel.activeInlineCreationTarget {
                viewModel.commitInlineTask(target: target)
            }
        }
        .onChange(of: viewModel.activeInlineCreationTarget) { _, target in
            if target == nil {
                isInlineFocused = false
                return
            }
            viewModel.hasAcquiredInlineCreationFocus = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                isInlineFocused = true
            }
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
            section: section,
            parentSpread: spread,
            calendar: viewModel.calendar,
            today: viewModel.today,
            dayEvents: viewModel.calendarEventsForDay(section.date),
            explicitDaySpread: explicitDaySpread,
            openTaskCount: explicitDaySpread.flatMap { openTaskCountForDaySpread?($0) } ?? 0,
            activeInlineCreationTarget: viewModel.activeInlineCreationTarget,
            showAddTask: viewModel.onAddTask != nil,
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
            } : nil,
            onAddTaskTap: {
                viewModel.activateInlineCreation(for: viewModel.creationTarget(for: section))
            },
            onEventTap: { event in eventKitService?.openEvent(event) },
            inlineTitle: $viewModel.inlineTitle,
            inlineCreationID: viewModel.inlineCreationID,
            inlineFocus: $isInlineFocused,
            onInlineSubmit: {
                if let target = viewModel.activeInlineCreationTarget {
                    viewModel.commitInlineTask(target: target)
                }
            }
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

                if viewModel.onAddTask != nil {
                    let target = viewModel.creationTarget(for: section)
                    if viewModel.activeInlineCreationTarget?.sectionID == section.id {
                        assignmentInlineCreationRow(target: target)
                    } else {
                        assignmentAddTaskButton(target: target)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func assignmentInlineCreationRow(target: EntryListViewModel.InlineCreationTarget) -> some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(entryType: .task, taskStatus: .open, color: .primary)
                .frame(width: 24, height: 24)

            TextField("New task", text: $viewModel.inlineTitle)
                .id(viewModel.inlineCreationID)
                .textFieldStyle(.plain)
                .font(SpreadTheme.Typography.body)
                .focused($isInlineFocused)
                .submitLabel(.done)
                .onSubmit { viewModel.commitInlineTask(target: target) }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isInlineFocused = true
                    }
                }

            Spacer()
        }
    }

    private func assignmentAddTaskButton(target: EntryListViewModel.InlineCreationTarget) -> some View {
        Button {
            viewModel.activateInlineCreation(for: target)
        } label: {
            HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                Text("Add Task")
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Column Count

enum MultidaySectionLayout {
    static func columnCount(for horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        horizontalSizeClass == .regular ? 2 : 1
    }
}

// MARK: - Refresh Helper

private struct RefreshableModifier: ViewModifier {
    let onRefresh: (() async -> Void)?

    func body(content: Content) -> some View {
        if let onRefresh {
            content.refreshable { await onRefresh() }
        } else {
            content
        }
    }
}
