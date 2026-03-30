import SwiftUI

/// Main spreads view for conventional mode.
///
/// Combines the spread hierarchy tab bar with the spread content area.
/// The tab bar provides navigation between spreads, and the content area
/// shows the selected spread's entries.
///
/// On iPad (regular width), the inbox button appears in this view's toolbar.
struct ConventionalSpreadsView: View {

    // MARK: - Properties

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The journal manager providing spread data.
    @Bindable var journalManager: JournalManager

    /// The auth manager for handling authentication.
    let authManager: AuthManager

    /// The sync engine for data synchronization.
    let syncEngine: SyncEngine?

    /// Coordinates sheet presentation for this view.
    @State private var coordinator = SpreadsCoordinator()

    /// The currently selected spread.
    @State private var selectedSpread: DataModel.Spread?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Hierarchy tab bar
            SpreadHierarchyTabBar(
                spreads: journalManager.spreads,
                selectedSpread: $selectedSpread,
                calendar: journalManager.calendar,
                today: journalManager.today,
                onCreateSpreadTapped: { coordinator.showSpreadCreation() },
                onCreateTaskTapped: { coordinator.showTaskCreation() },
                onCreateNoteTapped: { coordinator.showNoteCreation() }
            )

            Divider()

            // Sync status banner
            if let syncEngine {
                SyncStatusBanner(syncEngine: syncEngine)
            }

            // Content area
            spreadContent

        }
        .toolbar {
            // Inbox and auth buttons for iPad (regular width)
            if horizontalSizeClass == .regular {
                if let syncEngine {
                    ToolbarItem(placement: .navigationBarLeading) {
                        SyncStatusView(syncEngine: syncEngine)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        OverdueButton(overdueCount: journalManager.overdueTaskCount) {
                            coordinator.showOverdueReview()
                        }
                        InboxButton(inboxCount: journalManager.inboxCount) {
                            coordinator.showInbox()
                        }
                        AuthButton(isSignedIn: authManager.state.isSignedIn) {
                            coordinator.showAuth()
                        }
                    }
                }
            }
        }
        .sheet(item: $coordinator.activeSheet) { destination in
            sheetContent(for: destination)
        }
        .onChange(of: journalManager.dataVersion) { _, _ in
            resetSelectionIfNeeded()
        }
    }

    // MARK: - Content

    /// Eligible tasks for migration to the selected spread.
    private var eligibleMigrationCandidates: [MigrationCandidate] {
        guard let spread = selectedSpread else { return [] }
        return journalManager.migrationCandidates(to: spread)
    }

    @ViewBuilder
    private var spreadContent: some View {
        if let spread = selectedSpread {
            SpreadContentView(
                spread: spread,
                spreadDataModel: spreadDataModel(for: spread),
                availableSpreads: journalManager.spreads,
                calendar: journalManager.calendar,
                today: journalManager.today,
                onShowCompactNavigator: { coordinator.showHeaderNavigator(for: spread) },
                onEditTask: { coordinator.showTaskDetail($0) },
                onEditNote: { coordinator.showNoteDetail($0) },
                onSelectSpread: { selectedSpread = $0 },
                onDeleteTask: { task in
                    Task {
                        try? await journalManager.deleteTask(task)
                        await syncEngine?.syncNow()
                    }
                },
                onDeleteNote: { note in
                    Task {
                        try? await journalManager.deleteNote(note)
                        await syncEngine?.syncNow()
                    }
                },
                onCompleteTask: { task in
                    Task {
                        let newStatus: DataModel.Task.Status = task.status == .complete ? .open : .complete
                        try? await journalManager.updateTaskStatus(task, newStatus: newStatus)
                        await syncEngine?.syncNow()
                    }
                },
                eligibleTaskCount: eligibleMigrationCandidates.count,
                onReviewMigration: { coordinator.showMigrationSelection() }
            )
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above or create a new one.")
            }
        }
    }

    /// Returns the spread data model for the given spread.
    private func spreadDataModel(for spread: DataModel.Spread) -> SpreadDataModel? {
        let normalizedDate = spread.period.normalizeDate(spread.date, calendar: journalManager.calendar)
        return journalManager.dataModel[spread.period]?[normalizedDate]
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(
        for destination: SpreadsCoordinator.SheetDestination
    ) -> some View {
        switch destination {
        case .spreadCreation:
            SpreadCreationSheet(
                journalManager: journalManager,
                firstWeekday: journalManager.firstWeekday,
                onSpreadCreated: { spread in
                    selectedSpread = spread
                    Task { await syncEngine?.syncNow() }
                }
            )
        case .taskCreation:
            TaskCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpread,
                onTaskCreated: { _ in
                    Task { await syncEngine?.syncNow() }
                }
            )
        case .noteCreation:
            NoteCreationSheet(
                journalManager: journalManager,
                selectedSpread: selectedSpread,
                onNoteCreated: { _ in
                    Task { await syncEngine?.syncNow() }
                }
            )
        case .taskDetail(let task):
            TaskDetailSheet(
                task: task,
                journalManager: journalManager,
                onDelete: {
                    Task { await syncEngine?.syncNow() }
                }
            )
        case .noteDetail(let note):
            NoteDetailSheet(
                note: note,
                journalManager: journalManager,
                onDelete: {
                    Task { await syncEngine?.syncNow() }
                }
            )
        case .inbox:
            InboxSheetView(journalManager: journalManager)
        case .auth:
            AuthEntrySheet(authManager: authManager, isBlocking: false)
        case .migrationSelection:
            if let spread = selectedSpread {
                MigrationSelectionSheet(
                    destinationSpread: spread,
                    eligibleCandidates: eligibleMigrationCandidates,
                    calendar: journalManager.calendar,
                    onMigrate: { candidates in
                        await migrateSelectedCandidates(candidates)
                    }
                )
            }
        case .overdueReview:
            OverdueReviewSheet(
                journalManager: journalManager,
                syncEngine: syncEngine
            )
        case .headerNavigator(let spread):
            SpreadHeaderNavigatorPopoverView(
                model: SpreadHeaderNavigatorModel(
                    mode: .conventional,
                    calendar: journalManager.calendar,
                    today: journalManager.today,
                    spreads: journalManager.spreads,
                    tasks: [],
                    notes: [],
                    events: []
                ),
                currentSpread: spread,
                onSelect: { selection in
                    guard case .conventional(let destination) = selection else { return }
                    selectedSpread = destination
                    coordinator.dismiss()
                },
                onDismiss: { coordinator.dismiss() }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Migration

    private func migrateSelectedCandidates(
        _ selectedCandidates: [MigrationCandidate]
    ) async -> MigrationSelectionOutcome {
        guard let destination = selectedSpread else {
            return MigrationSelectionOutcome(
                migratedCount: 0,
                skippedCount: selectedCandidates.count,
                remainingCount: 0
            )
        }
        let latestCandidates = journalManager.migrationCandidates(to: destination)
        let revalidation = MigrationSelectionRevalidator()
        let result = revalidation.revalidate(selected: selectedCandidates, against: latestCandidates)

        var migratedCount = 0
        for candidate in result.valid {
            do {
                try await journalManager.moveTask(
                    candidate.task,
                    from: candidate.sourceKey,
                    to: destination
                )
                migratedCount += 1
            } catch {
                continue
            }
        }

        if migratedCount > 0 {
            await syncEngine?.syncNow()
        }

        let remainingCount = journalManager.migrationCandidates(to: destination).count
        return MigrationSelectionOutcome(
            migratedCount: migratedCount,
            skippedCount: result.skippedCount,
            remainingCount: remainingCount
        )
    }

    private func resetSelectionIfNeeded() {
        if let selectedSpread, journalManager.spreads.contains(where: { $0.id == selectedSpread.id }) {
            return
        }

        let organizer = SpreadHierarchyOrganizer(
            spreads: journalManager.spreads,
            calendar: journalManager.calendar
        )
        selectedSpread = organizer.initialSelection(for: journalManager.today)
    }
}

/// Spread content view displaying header and entry list.
///
/// Shows the spread header with title and entry counts, followed by
/// the entry list grouped by period. Uses dot grid paper background
/// per visual design spec.
private struct SpreadContentView: View {
    let spread: DataModel.Spread
    let spreadDataModel: SpreadDataModel?
    let availableSpreads: [DataModel.Spread]
    let calendar: Calendar
    let today: Date
    @State private var isShowingHeaderNavigator = false
    var onShowCompactNavigator: (() -> Void)?

    /// Callback when a task is tapped for editing.
    var onEditTask: ((DataModel.Task) -> Void)?

    /// Callback when a note is tapped for editing.
    var onEditNote: ((DataModel.Note) -> Void)?

    /// Callback when the selected spread changes from header navigator.
    var onSelectSpread: ((DataModel.Spread) -> Void)?

    /// Callback when a task is deleted via swipe.
    var onDeleteTask: ((DataModel.Task) -> Void)?

    /// Callback when a note is deleted via swipe.
    var onDeleteNote: ((DataModel.Note) -> Void)?

    /// Callback when a task is marked complete via swipe.
    var onCompleteTask: ((DataModel.Task) -> Void)?

    /// Number of tasks eligible for migration (0 hides the banner).
    var eligibleTaskCount: Int = 0

    /// Callback to open migration review sheet.
    var onReviewMigration: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and counts
            SpreadHeaderView(
                configuration: SpreadHeaderConfiguration(
                    spread: spread,
                    calendar: calendar,
                    taskCount: spreadDataModel?.tasks.count ?? 0,
                    noteCount: spreadDataModel?.notes.count ?? 0
                ),
                onTitleTapped: {
                    if horizontalSizeClass == .regular {
                        isShowingHeaderNavigator = true
                    } else {
                        onShowCompactNavigator?()
                    }
                },
                isShowingPopover: horizontalSizeClass == .regular ? $isShowingHeaderNavigator : nil,
                popoverContent: horizontalSizeClass == .regular ? { AnyView(headerNavigatorView) } : nil,
                navigatorPresentationStyle: horizontalSizeClass == .regular ? .popover : nil
            )

            Divider()

            // Migration banner (only shows when eligible tasks exist)
            if eligibleTaskCount > 0 {
                MigrationBannerView(
                    eligibleTaskCount: eligibleTaskCount,
                    onReview: { onReviewMigration?() }
                )
            }

            // Entry list grouped by period
            entryList
        }
        .dotGridBackground(.paper)
    }

    @ViewBuilder
    private var entryList: some View {
        if let dataModel = spreadDataModel {
            EntryListView(
                spreadDataModel: dataModel,
                calendar: calendar,
                today: today,
                onEdit: { entry in
                    if let task = entry as? DataModel.Task {
                        onEditTask?(task)
                    } else if let note = entry as? DataModel.Note {
                        onEditNote?(note)
                    }
                },
                onDelete: { entry in
                    if let task = entry as? DataModel.Task {
                        onDeleteTask?(task)
                    } else if let note = entry as? DataModel.Note {
                        onDeleteNote?(note)
                    }
                },
                onComplete: { task in
                    onCompleteTask?(task)
                }
            )
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Unable to load spread data.")
            }
        }
    }

    private var headerNavigatorView: some View {
        SpreadHeaderNavigatorPopoverView(
            model: SpreadHeaderNavigatorModel(
                mode: .conventional,
                calendar: calendar,
                today: today,
                spreads: availableSpreads,
                tasks: [],
                notes: [],
                events: []
            ),
            currentSpread: spread,
            onSelect: { selection in
                guard case .conventional(let destination) = selection else { return }
                onSelectSpread?(destination)
            },
            onDismiss: { isShowingHeaderNavigator = false }
        )
    }
}

// MARK: - Preview

#Preview {
    ConventionalSpreadsView(
        journalManager: .previewInstance,
        authManager: .makeForPreview(),
        syncEngine: nil
    )
}
