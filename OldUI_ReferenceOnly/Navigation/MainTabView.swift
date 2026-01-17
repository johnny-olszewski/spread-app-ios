//
//  MainTabView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// The root view of the new bullet journal UI.
/// Contains a horizontal tab bar at the top and spread content below.
struct MainTabView: View {
    @Environment(JournalManager.self) private var journalManager
    @State private var selectedSpread: DataModel.Spread?
    @State private var showingSpreadCreation = false
    @State private var showingSettings = false
    @State private var showingTaskDetail: DataModel.Task?
    @State private var showingTaskCreation = false
    @State private var showingMigrationSelection = false

    var body: some View {
        // Access dataVersion to trigger refresh when data changes
        let _ = journalManager.dataVersion

        VStack(spacing: 0) {
            // Hierarchical tab bar with progressive disclosure
            HierarchicalSpreadTabBar(
                spreads: spreadsInCreationOrder,
                selectedSpread: $selectedSpread,
                creatableSpreads: nextCreatableSpreads,
                onCreateSpread: {
                    showingSpreadCreation = true
                },
                onCreateSuggestedSpread: { suggestion in
                    createSpread(period: suggestion.period, date: suggestion.date)
                }
            )

            // Content area
            if let selectedSpread {
                SpreadContentView(
                    spread: selectedSpread,
                    onTaskTap: { task in
                        showingTaskDetail = task
                    },
                    onAddTask: {
                        showingTaskCreation = true
                    },
                    onMigrateTask: { task in
                        migrateTask(task, to: selectedSpread)
                    }
                )
            } else {
                emptyStateView
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSpreadCreation) {
            SpreadCreationSheet(
                onSpreadCreated: { period, date in
                    createSpread(period: period, date: date)
                    showingSpreadCreation = false
                }
            )
        }
        .sheet(item: $showingTaskDetail) { task in
            TaskEditView(
                task: task,
                currentSpread: selectedSpread,
                onSave: { updatedTask in
                    // Save handled by the view
                    showingTaskDetail = nil
                },
                onDelete: {
                    deleteTask(task)
                    showingTaskDetail = nil
                }
            )
        }
        .sheet(isPresented: $showingTaskCreation) {
            if let spread = selectedSpread {
                TaskCreationView(
                    defaultDate: spread.date,
                    defaultPeriod: spread.period,
                    onTaskCreated: { title, date, period in
                        createTask(title: title, date: date, period: period)
                        showingTaskCreation = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        // Hide nav bar background entirely for seamless continuity with tab bar
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .onAppear {
            // Select first spread if none selected
            if selectedSpread == nil {
                selectedSpread = spreadsInCreationOrder.first
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Spreads Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create your first spread to get started")
                .foregroundStyle(.secondary)

            Button {
                showingSpreadCreation = true
            } label: {
                Label("Create Spread", systemImage: "plus")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DotGridView(configuration: FolderTabDesign.dotGridConfig))
    }

    // MARK: - Computed Properties

    /// Returns spreads in creation order (order they were added to allSpreadAssignments)
    private var spreadsInCreationOrder: [DataModel.Spread] {
        journalManager.getSpreadAssignments().compactMap { assignment in
            if let model = journalManager.dataModel(for: assignment.period, on: assignment.date) {
                return model.spread
            }
            return nil
        }
    }

    /// Returns the next logical creatable spreads (only the immediate next instance of each period)
    private var nextCreatableSpreads: [SpreadSuggestion] {
        var suggestions: [SpreadSuggestion] = []
        let calendar = journalManager.calendar
        let today = journalManager.today

        // Check if current year spread exists
        let currentYear = calendar.component(.year, from: today)
        if let currentYearDate = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) {
            if !journalManager.spreadExists(for: .year, on: currentYearDate) {
                suggestions.append(SpreadSuggestion(period: .year, date: currentYearDate))
            }
        }

        // Check if current month spread exists
        let currentMonth = calendar.component(.month, from: today)
        if let currentMonthDate = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)) {
            if !journalManager.spreadExists(for: .month, on: currentMonthDate) {
                suggestions.append(SpreadSuggestion(period: .month, date: currentMonthDate))
            }
        }

        // Check if today's day spread exists
        let todayNormalized = DataModel.Spread.Period.day.normalizeDate(today, calendar: calendar)
        if !journalManager.spreadExists(for: .day, on: todayNormalized) {
            suggestions.append(SpreadSuggestion(period: .day, date: todayNormalized))
        }

        return suggestions
    }

    // MARK: - Actions

    private func createSpread(period: DataModel.Spread.Period, date: Date) {
        journalManager.createSpread(period: period, date: date)
        // Select the newly created spread
        if let model = journalManager.dataModel(for: period, on: date) {
            selectedSpread = model.spread
        }
    }

    private func createTask(title: String, date: Date, period: DataModel.Spread.Period) {
        let task = DataModel.Task(title: title, date: date, period: period, status: .open)
        journalManager.addTask(task)
    }

    private func deleteTask(_ task: DataModel.Task) {
        // TODO: Implement task deletion in JournalManager
    }

    private func migrateTask(_ task: DataModel.Task, to spread: DataModel.Spread) {
        // Find the source spread (where task currently has open assignment)
        if let sourceAssignment = task.assignments.first(where: { $0.status == .open }) {
            journalManager.migrateTask(
                task,
                from: sourceAssignment.period,
                sourceDate: sourceAssignment.date,
                to: spread.period,
                destDate: spread.date
            )
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()

    return NavigationStack {
        MainTabView()
    }
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
