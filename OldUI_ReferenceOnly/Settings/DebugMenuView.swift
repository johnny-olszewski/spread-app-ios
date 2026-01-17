//
//  DebugMenuView.swift
//  Bulleted
//
//  Created by Johnny O on 12/31/25.
//

import SwiftUI

#if DEBUG
/// Debug menu for browsing raw task and spread data
struct DebugMenuView: View {
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                SpreadBrowserView()
                    .tabItem {
                        Label("Spreads", systemImage: "rectangle.stack")
                    }
                    .tag(0)

                TaskBrowserView()
                    .tabItem {
                        Label("Tasks", systemImage: "checklist")
                    }
                    .tag(1)

                DebugActionsView()
                    .tabItem {
                        Label("Actions", systemImage: "bolt.fill")
                    }
                    .tag(2)

                EnvironmentInfoView()
                    .tabItem {
                        Label("Environment", systemImage: "info.circle")
                    }
                    .tag(3)
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Spread Browser

private struct SpreadBrowserView: View {
    @Environment(JournalManager.self) private var journalManager

    var body: some View {
        // Access dataVersion to trigger refresh when data changes
        let _ = journalManager.dataVersion

        List {
            ForEach(DataModel.Spread.Period.allCases, id: \.self) { period in
                Section(period.name) {
                    let spreads = spreadsForPeriod(period)
                    if spreads.isEmpty {
                        Text("No spreads")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(spreads, id: \.id) { spread in
                            SpreadDetailRow(spread: spread)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        _ = journalManager.deleteSpread(spread, force: true)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func spreadsForPeriod(_ period: DataModel.Spread.Period) -> [DataModel.Spread] {
        journalManager.getSpreadAssignments()
            .filter { $0.period == period }
            .compactMap { assignment in
                journalManager.dataModel(for: assignment.period, on: assignment.date)?.spread
            }
            .sorted { $0.date < $1.date }
    }
}

private struct SpreadDetailRow: View {
    let spread: DataModel.Spread
    @Environment(JournalManager.self) private var journalManager

    var body: some View {
        NavigationLink {
            SpreadDetailView(spread: spread)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.headline)

                HStack {
                    Text("ID: \(spread.id.uuidString.prefix(8))...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    let taskCount = journalManager.tasksForSpread(period: spread.period, date: spread.date).count
                    Text("\(taskCount) tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var formattedDate: String {
        switch spread.period {
        case .day:
            return spread.date.formatted(date: .abbreviated, time: .omitted)
        case .week:
            return "Week of \(spread.date.formatted(date: .abbreviated, time: .omitted))"
        case .month:
            return spread.date.formatted(.dateTime.month(.wide).year())
        case .year:
            return spread.date.formatted(.dateTime.year())
        case .multiday:
            return spread.date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

private struct SpreadDetailView: View {
    let spread: DataModel.Spread
    @Environment(JournalManager.self) private var journalManager

    var body: some View {
        List {
            Section("Properties") {
                LabeledContent("ID", value: spread.id.uuidString)
                LabeledContent("Period", value: spread.period.name)
                LabeledContent("Date", value: spread.date.formatted(date: .complete, time: .omitted))
                LabeledContent("Normalized Date", value: spread.period.normalizeDate(spread.date, calendar: journalManager.calendar).formatted(date: .complete, time: .omitted))
            }

            Section("Tasks on this Spread") {
                let tasks = journalManager.tasksForSpread(period: spread.period, date: spread.date)
                if tasks.isEmpty {
                    Text("No tasks")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(tasks, id: \.id) { task in
                        NavigationLink {
                            TaskDetailDebugView(task: task)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(task.title)
                                    .font(.body)
                                if let status = journalManager.taskStatus(task, for: spread.period, date: spread.date) {
                                    Text(status.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Spread Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Task Browser

private struct TaskBrowserView: View {
    @Environment(JournalManager.self) private var journalManager

    var body: some View {
        // Access dataVersion to trigger refresh when data changes
        let _ = journalManager.dataVersion

        List {
            let allTasks = getAllTasks()

            if allTasks.isEmpty {
                ContentUnavailableView("No Tasks", systemImage: "checklist", description: Text("No tasks found in the data model"))
            } else {
                ForEach(allTasks, id: \.id) { task in
                    NavigationLink {
                        TaskDetailDebugView(task: task)
                    } label: {
                        TaskBrowserRow(task: task)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            journalManager.deleteTask(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func getAllTasks() -> [DataModel.Task] {
        var tasks: Set<UUID> = []
        var result: [DataModel.Task] = []

        for period in DataModel.Spread.Period.allCases {
            for assignment in journalManager.getSpreadAssignments() where assignment.period == period {
                for task in journalManager.tasksForSpread(period: period, date: assignment.date) {
                    if !tasks.contains(task.id) {
                        tasks.insert(task.id)
                        result.append(task)
                    }
                }
            }
        }

        return result.sorted { $0.title < $1.title }
    }
}

private struct TaskBrowserRow: View {
    let task: DataModel.Task

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.headline)

            HStack {
                Text(task.status.name)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())

                Text(task.period.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(task.assignments.count) assignments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch task.status {
        case .open: return .blue
        case .complete: return .green
        case .migrated: return .orange
        }
    }
}

private struct TaskDetailDebugView: View {
    let task: DataModel.Task
    @Environment(JournalManager.self) private var journalManager

    var body: some View {
        List {
            Section("Properties") {
                LabeledContent("ID", value: task.id.uuidString)
                LabeledContent("Title", value: task.title)
                LabeledContent("Status", value: task.status.name)
                LabeledContent("Period", value: task.period.name)
                LabeledContent("Date", value: task.date.formatted(date: .complete, time: .omitted))
            }

            Section("Assignments (\(task.assignments.count))") {
                if task.assignments.isEmpty {
                    Text("No assignments")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(Array(task.assignments.enumerated()), id: \.offset) { index, assignment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Assignment \(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            LabeledContent("Period", value: assignment.period.name)
                            LabeledContent("Date", value: assignment.date.formatted(date: .abbreviated, time: .omitted))
                            LabeledContent("Status", value: assignment.status.name)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Task Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Debug Actions

private struct DebugActionsView: View {
    @Environment(JournalManager.self) private var journalManager

    // Quick Add Spread state
    @State private var selectedPeriod: DataModel.Spread.Period = .day
    @State private var selectedDate: Date = Date()

    // Quick Add Task state
    @State private var taskTitle: String = ""
    @State private var taskPeriod: DataModel.Spread.Period = .day
    @State private var taskDate: Date = Date()
    @State private var taskStatus: DataModel.Task.Status = .open

    // Confirmation alerts
    @State private var showDeleteAllSpreadsAlert = false
    @State private var showDeleteAllTasksAlert = false

    var body: some View {
        List {
            // MARK: Quick Add Spread
            Section {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(DataModel.Spread.Period.allCases, id: \.self) { period in
                        Text(period.name).tag(period)
                    }
                }

                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)

                Button {
                    addSpread()
                } label: {
                    Label("Add Spread", systemImage: "plus.rectangle.on.rectangle")
                }
                .disabled(!journalManager.canCreateSpread(period: selectedPeriod, date: selectedDate))
            } header: {
                Text("Quick Add Spread")
            } footer: {
                if !journalManager.canCreateSpread(period: selectedPeriod, date: selectedDate) {
                    Text("Spread already exists or cannot be created for this period/date")
                }
            }

            // MARK: Quick Add Task
            Section {
                TextField("Title (optional)", text: $taskTitle)

                Picker("Period", selection: $taskPeriod) {
                    ForEach(DataModel.Spread.Period.allCases.filter { $0.canHaveTasksAssigned }, id: \.self) { period in
                        Text(period.name).tag(period)
                    }
                }

                DatePicker("Date", selection: $taskDate, displayedComponents: .date)

                Picker("Status", selection: $taskStatus) {
                    ForEach(DataModel.Task.Status.allCases, id: \.self) { status in
                        Text(status.name).tag(status)
                    }
                }

                Button {
                    addTask()
                } label: {
                    Label("Add Task", systemImage: "plus.circle")
                }
            } header: {
                Text("Quick Add Task")
            } footer: {
                Text("If title is empty, task will be named with period and date details")
            }

            // MARK: Destructive Actions
            Section {
                Button(role: .destructive) {
                    showDeleteAllSpreadsAlert = true
                } label: {
                    Label("Delete All Spreads", systemImage: "rectangle.stack.badge.minus")
                }

                Button(role: .destructive) {
                    showDeleteAllTasksAlert = true
                } label: {
                    Label("Delete All Tasks", systemImage: "trash")
                }
            } header: {
                Text("Destructive Actions")
            } footer: {
                Text("These actions cannot be undone")
            }
        }
        .listStyle(.insetGrouped)
        .alert("Delete All Spreads?", isPresented: $showDeleteAllSpreadsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllSpreads()
            }
        } message: {
            Text("This will delete all spreads and their associated task assignments. This cannot be undone.")
        }
        .alert("Delete All Tasks?", isPresented: $showDeleteAllTasksAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllTasks()
            }
        } message: {
            Text("This will delete all tasks from all spreads. This cannot be undone.")
        }
    }

    private func addSpread() {
        journalManager.createSpread(period: selectedPeriod, date: selectedDate)
    }

    private func addTask() {
        let title = taskTitle.isEmpty ? generateTaskTitle() : taskTitle
        let normalizedDate = taskPeriod.normalizeDate(taskDate, calendar: journalManager.calendar)

        let task = DataModel.Task(
            title: title,
            date: normalizedDate,
            period: taskPeriod,
            status: taskStatus
        )

        // Add assignment matching the task's period/date
        task.addAssignment(DataModel.TaskAssignment(
            period: taskPeriod,
            date: normalizedDate,
            status: taskStatus
        ))

        journalManager.addTask(task)

        // Clear the title for next entry
        taskTitle = ""
    }

    private func generateTaskTitle() -> String {
        let dateFormatter = DateFormatter()

        switch taskPeriod {
        case .day:
            dateFormatter.dateFormat = "MMM d, yyyy"
        case .multiday:
            dateFormatter.dateFormat = "MMM d, yyyy"
        case .week:
            dateFormatter.dateFormat = "'Week of' MMM d"
        case .month:
            dateFormatter.dateFormat = "MMMM yyyy"
        case .year:
            dateFormatter.dateFormat = "yyyy"
        }

        return "\(taskPeriod.name) Task - \(dateFormatter.string(from: taskDate))"
    }

    private func deleteAllSpreads() {
        let assignments = journalManager.getSpreadAssignments()

        // Collect all spreads to delete
        var spreadsToDelete: [DataModel.Spread] = []
        for assignment in assignments {
            if let spreadModel = journalManager.dataModel(for: assignment.period, on: assignment.date) {
                spreadsToDelete.append(spreadModel.spread)
            }
        }

        // Delete in reverse order (smaller periods first to avoid parent dependency issues)
        // Use force: true to allow deletion of year spreads
        let sortedSpreads = spreadsToDelete.sorted { $0.period.rawValue < $1.period.rawValue }
        for spread in sortedSpreads {
            _ = journalManager.deleteSpread(spread, force: true)
        }
    }

    private func deleteAllTasks() {
        var tasksToDelete: Set<UUID> = []
        var tasks: [DataModel.Task] = []

        for period in DataModel.Spread.Period.allCases {
            for assignment in journalManager.getSpreadAssignments() where assignment.period == period {
                for task in journalManager.tasksForSpread(period: period, date: assignment.date) {
                    if !tasksToDelete.contains(task.id) {
                        tasksToDelete.insert(task.id)
                        tasks.append(task)
                    }
                }
            }
        }

        for task in tasks {
            journalManager.deleteTask(task)
        }
    }
}

// MARK: - Environment Info

private struct EnvironmentInfoView: View {
    var body: some View {
        List {
            Section("App Environment") {
                LabeledContent("Current", value: AppEnvironment.current.rawValue)
                LabeledContent("In-Memory Only", value: AppEnvironment.current.isStoredInMemoryOnly ? "Yes" : "No")
                LabeledContent("Uses Mock Data", value: AppEnvironment.current.usesMockData ? "Yes" : "No")
                LabeledContent("Container Name", value: AppEnvironment.current.containerName)
            }

            Section("Build Info") {
                LabeledContent("Configuration", value: "DEBUG")
                LabeledContent("Date", value: Date.now.formatted(date: .complete, time: .standard))
            }

            Section("Launch Arguments") {
                let args = ProcessInfo.processInfo.arguments
                if args.count <= 1 {
                    Text("No custom arguments")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(args.dropFirst(), id: \.self) { arg in
                        Text(arg)
                            .font(.caption)
                            .monospaced()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()

    return DebugMenuView()
        .environment(JournalManager(
            calendar: calendar,
            today: today,
            bujoMode: .convential,
            spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
            taskRepository: mock_TaskRepository(calendar: calendar, today: today)
        ))
}
#endif
