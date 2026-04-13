import SwiftUI

struct SharedSpreadsShellControlConfiguration {
    var showsTodayButton: Bool
    var onToday: () -> Void
    var onCreateSpread: (() -> Void)?
    var onCreateTask: (() -> Void)?
    var onCreateNote: (() -> Void)?
}

struct SharedSpreadsShellView: View {
    @Binding var selection: SpreadHeaderNavigatorModel.Selection

    let journalManager: JournalManager
    let viewModel: SpreadsViewModel
    let syncEngine: SyncEngine?
    let stripModel: SpreadTitleNavigatorModel
    let recenterToken: Int
    let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding
    let onRecommendedSpreadTapped: ((SpreadTitleNavigatorRecommendation) -> Void)?
    let authManager: AuthManager
    let onAuth: () -> Void
    let syncStatus: SyncStatus?
    let controls: SharedSpreadsShellControlConfiguration

    private var items: [SpreadTitleNavigatorModel.Item] {
        stripModel.items(for: selection)
    }

    var body: some View {
        VStack(spacing: 0) {
            SpreadTitleNavigatorView(
                stripModel: stripModel,
                recenterToken: recenterToken,
                onRecommendedSpreadTapped: onRecommendedSpreadTapped,
                recommendationProvider: recommendationProvider,
                selection: $selection
            )

            Divider()

            if case .error = syncStatus {
                SyncErrorBanner()
            }

            contentArea
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AuthButton(isSignedIn: authManager.state.isSignedIn, action: onAuth)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomInsetControls
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if !items.isEmpty {
            SpreadContentPagerView(
                journalManager: journalManager,
                viewModel: viewModel,
                syncEngine: syncEngine,
                model: stripModel,
                items: items,
                recenterToken: recenterToken,
                selection: $selection
            )
            .dotGridBackground(.paper, ignoresSafeAreaEdges: .bottom)
        } else {
            ContentUnavailableView {
                Label("No Spread Selected", systemImage: "book")
            } description: {
                Text("Select a spread from the bar above.")
            }
            .dotGridBackground(.paper, ignoresSafeAreaEdges: .bottom)
        }
    }

    @ViewBuilder
    private var bottomInsetControls: some View {
        HStack(spacing: 12) {
            if controls.showsTodayButton {
                Button(action: controls.onToday) {
                    Text("Today")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.clear, in: Capsule())
                }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton
                )
            }

            Spacer()

            if hasCreateActions {
                Menu {
                    if let action = controls.onCreateSpread {
                        Button(action: action) {
                            Label("Create Spread", systemImage: "book")
                        }
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createSpread)
                    }

                    if let action = controls.onCreateTask {
                        Button(action: action) {
                            Label("Create Task", systemImage: "circle.fill")
                        }
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createTask)
                    }

                    if let action = controls.onCreateNote {
                        Button(action: action) {
                            Label("Create Note", systemImage: "minus")
                        }
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.createNote)
                    }
                } label: {
                    Image(systemName: "plus")
                        .padding(8)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .glassEffect(.regular.tint(SpreadTheme.Accent.todaySelectedEmphasis), in: Circle())
                }
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.CreateMenu.button)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.clear)
    }

    private var hasCreateActions: Bool {
        controls.onCreateSpread != nil ||
        controls.onCreateTask != nil ||
        controls.onCreateNote != nil
    }
}
