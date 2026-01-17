//
//  SpreadContentView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Container for spread content.
/// Shows header with spread info, task list, migrated tasks section, and add task button.
struct SpreadContentView: View {
    @Environment(JournalManager.self) private var journalManager
    let spread: DataModel.Spread
    let onTaskTap: (DataModel.Task) -> Void
    let onAddTask: () -> Void
    let onMigrateTask: (DataModel.Task) -> Void

    @State private var showingMigrationBanner = true
    
    // MARK: - Computed
    
    /// Tasks that can be migrated TO this spread from parent spreads
    private var eligibleTasksForMigration: [DataModel.Task] {
        // Find tasks from parent spreads that could be migrated here
        // A task is eligible if:
        // 1. Its preferred period is <= this spread's period
        // 2. Its preferred date falls within this spread
        // 3. It's currently assigned to a larger period spread

        var eligible: [DataModel.Task] = []
        let calendar = journalManager.calendar

        // Check parent periods
        var parentPeriod = spread.period
        while let nextParent = parentPeriodOf(parentPeriod) {
            parentPeriod = nextParent

            // Get tasks from parent spread
            let parentTasks = journalManager.tasksForSpread(period: parentPeriod, date: spread.date)
            for task in parentTasks {
                // Check if task's preferred date is within this spread
                if isDateWithinSpread(task.date) && task.period.rawValue <= spread.period.rawValue {
                    // Check if task has an open assignment on the parent
                    let parentStatus = journalManager.taskStatus(task, for: parentPeriod, date: spread.date)
                    if parentStatus == .open && !task.hasAssignment(for: spread.period, date: spread.date, calendar: calendar) {
                        eligible.append(task)
                    }
                }
            }
        }

        return eligible
    }

    /// Tasks that are active on this spread (open or complete, not migrated)
    private var activeTasks: [DataModel.Task] {
        let allTasks = journalManager.tasksForSpread(period: spread.period, date: spread.date)
        return allTasks.filter { task in
            let status = journalManager.taskStatus(task, for: spread.period, date: spread.date)
            return status == .open || status == .complete
        }
    }

    /// Tasks that were migrated OUT of this spread
    private var migratedTasks: [DataModel.Task] {
        let allTasks = journalManager.tasksForSpread(period: spread.period, date: spread.date)
        return allTasks.filter { task in
            let status = journalManager.taskStatus(task, for: spread.period, date: spread.date)
            return status == .migrated
        }
    }

    private func parentPeriodOf(_ period: DataModel.Spread.Period) -> DataModel.Spread.Period? {
        switch period {
        case .day: return .month
        case .multiday: return .month
        case .week: return .month
        case .month: return .year
        case .year: return nil
        }
    }

    private func isDateWithinSpread(_ date: Date) -> Bool {
        let calendar = journalManager.calendar
        guard let interval = calendar.dateInterval(of: spread.period.calendarComponent, for: spread.date) else {
            return false
        }
        return interval.contains(date)
    }
    
    
    // MARK: - Body

    var body: some View {
        // Access dataVersion to trigger refresh when data changes
        let _ = journalManager.dataVersion

        VStack(spacing: 0) {
            // Migration banner (if applicable)
            if showingMigrationBanner && !eligibleTasksForMigration.isEmpty {
                MigrationBannerView(
                    eligibleTaskCount: eligibleTasksForMigration.count,
                    onMigrateAll: migrateAllEligibleTasks,
                    onReview: {
                        // TODO: Show migration selection view
                    },
                    onDismiss: {
                        withAnimation {
                            showingMigrationBanner = false
                        }
                    }
                )
            }

            // Header
            spreadHeader

            // Task list
            TaskListView(
                spread: spread,
                tasks: activeTasks,
                onTaskTap: onTaskTap,
                onTaskComplete: { task in
                    completeTask(task)
                },
                onTaskMigrate: onMigrateTask
            )

            // Migrated tasks section
            MigratedTasksSection(
                spread: spread,
                migratedTasks: migratedTasks,
                onTaskTap: onTaskTap
            )
        }
        .background(DotGridView(configuration: FolderTabDesign.dotGridConfig))
        .safeAreaInset(edge: .bottom) {
            addTaskButton
        }
    }

    // MARK: - Header

    private var spreadHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(spreadTitle)
                .font(.title)
                .fontWeight(.bold)

            Text(spreadSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // No background - sits on dot grid like handwritten headers
    }

    private var spreadTitle: String {
        let calendar = journalManager.calendar
        switch spread.period {
        case .year:
            let year = calendar.component(.year, from: spread.date)
            return "\(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: spread.date)
        case .multiday:
            // Future feature: show date range title
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: spread.date) + "+"
        case .week:
            let week = calendar.component(.weekOfYear, from: spread.date)
            let year = calendar.component(.year, from: spread.date)
            return "Week \(week), \(year)"
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            return formatter.string(from: spread.date)
        }
    }

    private var spreadSubtitle: String {
        let taskCount = activeTasks.count
        let migratedCount = migratedTasks.count

        var parts: [String] = []
        parts.append("\(taskCount) task\(taskCount == 1 ? "" : "s")")

        if migratedCount > 0 {
            parts.append("\(migratedCount) migrated")
        }

        return parts.joined(separator: " • ")
    }

    // MARK: - Add Task Button

    private var addTaskButton: some View {
        Button(action: onAddTask) {
            Label("Add Task", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, FolderTabDesign.taskRowHorizontalPadding)
        .padding(.vertical, 8)
        // Transparent container - button itself is solid but area around shows dots
    }

    

    // MARK: - Actions

    private func completeTask(_ task: DataModel.Task) {
        if let index = task.assignments.firstIndex(where: {
            $0.matches(period: spread.period, date: spread.date, calendar: journalManager.calendar)
        }) {
            task.assignments[index].status = .complete
        }
        task.status = .complete
    }

    private func migrateAllEligibleTasks() {
        for task in eligibleTasksForMigration {
            onMigrateTask(task)
        }
        withAnimation {
            showingMigrationBanner = false
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let spreadDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

    return SpreadContentView(
        spread: DataModel.Spread(period: .month, date: spreadDate),
        onTaskTap: { _ in },
        onAddTask: {},
        onMigrateTask: { _ in }
    )
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
