//
//  SpreadTabBar.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Horizontal scrolling tab bar displaying all spreads as stacked folder tabs.
///
/// The selected tab appears as the "front" folder with a custom curved shape
/// that seamlessly connects to the content area below. Unselected tabs appear
/// as folder tabs stacked behind the selected one.
///
/// Visual hierarchy:
/// - Selected tab: Full folder shape, matches content background, slight shadow
/// - Inactive tabs: Smaller, recessed appearance with secondary background
/// - Creatable tabs: Dashed outline, ghosted appearance
struct SpreadTabBar: View {
    @Environment(JournalManager.self) private var journalManager
    let spreads: [DataModel.Spread]
    @Binding var selectedSpread: DataModel.Spread?
    let creatableSpreads: [SpreadSuggestion]
    let onCreateSpread: () -> Void
    let onCreateSuggestedSpread: (SpreadSuggestion) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            tabBarContent
                .onChange(of: selectedSpread?.id) { _, newValue in
                    if let id = newValue {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
        }
    }

    private var tabBarContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: FolderTabDesign.tabSpacing) {
                spreadTabs
                creatableTabs
                addButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 0) // No bottom padding - tabs connect to content
        }
        .background(tabBarBackground)
    }

    private var tabBarBackground: some View {
        // Chrome background - continuous from nav bar through tab bar
        // The selected tab "pops forward" by having a different (content) background
        FolderTabDesign.chromeBackground
    }

    private var spreadTabs: some View {
        ForEach(spreads, id: \.id) { spread in
            SpreadTab(
                spread: spread,
                isSelected: selectedSpread?.id == spread.id,
                onTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSpread = spread
                    }
                }
            )
            .id(spread.id)
            .zIndex(selectedSpread?.id == spread.id ? 1 : 0)
        }
    }

    private var creatableTabs: some View {
        ForEach(creatableSpreads, id: \.id) { suggestion in
            CreatableSpreadTab(
                period: suggestion.period,
                date: suggestion.date,
                onTap: {
                    onCreateSuggestedSpread(suggestion)
                }
            )
        }
    }

    private var addButton: some View {
        Button(action: onCreateSpread) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
        .padding(.bottom, 6)
    }
}

/// Represents a suggested spread that can be created
struct SpreadSuggestion: Identifiable, Hashable {
    let id = UUID()
    let period: DataModel.Spread.Period
    let date: Date
}

// MARK: - Preview

#Preview("Folder Tab Bar") {
    struct PreviewWrapper: View {
        @State private var selectedSpread: DataModel.Spread?
        let calendar = Calendar.current

        var spreads: [DataModel.Spread] {
            [
                DataModel.Spread(period: .year, date: calendar.date(from: DateComponents(year: 2026))!),
                DataModel.Spread(period: .month, date: calendar.date(from: DateComponents(year: 2026, month: 1))!),
                DataModel.Spread(period: .month, date: calendar.date(from: DateComponents(year: 2026, month: 2))!),
                DataModel.Spread(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!),
                DataModel.Spread(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!),
                DataModel.Spread(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!)
            ]
        }

        var creatableSpreads: [SpreadSuggestion] {
            [
                SpreadSuggestion(period: .month, date: calendar.date(from: DateComponents(year: 2026, month: 3))!)
            ]
        }

        var body: some View {
            VStack(spacing: 0) {
                SpreadTabBar(
                    spreads: spreads,
                    selectedSpread: $selectedSpread,
                    creatableSpreads: creatableSpreads,
                    onCreateSpread: {},
                    onCreateSuggestedSpread: { _ in }
                )

                // Content area with dot grid (same base color as selected tab)
                VStack {
                    if let selected = selectedSpread {
                        Text("Selected: \(selected.period.name)")
                            .font(.headline)
                        Text("Content area has dot grid background")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No selection")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DotGridView(configuration: FolderTabDesign.dotGridConfig))
            }
            .environment(JournalManager(
                calendar: calendar,
                today: Date(),
                bujoMode: .convential,
                spreadRepository: mock_SpreadRepository(calendar: calendar, today: Date()),
                taskRepository: mock_TaskRepository(calendar: calendar, today: Date())
            ))
            .onAppear {
                selectedSpread = spreads[2] // Select Feb month
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Many Tabs Scrolling") {
    struct PreviewWrapper: View {
        @State private var selectedSpread: DataModel.Spread?
        let calendar = Calendar.current

        var spreads: [DataModel.Spread] {
            var result: [DataModel.Spread] = []
            // Year
            result.append(DataModel.Spread(period: .year, date: calendar.date(from: DateComponents(year: 2026))!))
            // Many months
            for month in 1...12 {
                result.append(DataModel.Spread(period: .month, date: calendar.date(from: DateComponents(year: 2026, month: month))!))
            }
            return result
        }

        var body: some View {
            VStack(spacing: 0) {
                SpreadTabBar(
                    spreads: spreads,
                    selectedSpread: $selectedSpread,
                    creatableSpreads: [],
                    onCreateSpread: {},
                    onCreateSuggestedSpread: { _ in }
                )

                DotGridView(configuration: FolderTabDesign.dotGridConfig)
                    .frame(height: 300)
            }
            .environment(JournalManager(
                calendar: calendar,
                today: Date(),
                bujoMode: .convential,
                spreadRepository: mock_SpreadRepository(calendar: calendar, today: Date()),
                taskRepository: mock_TaskRepository(calendar: calendar, today: Date())
            ))
            .onAppear {
                selectedSpread = spreads[6] // Select June
            }
        }
    }

    return PreviewWrapper()
}
