//
//  TaskCreationView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Sheet for creating a new task.
/// Defaults to the current spread's date and period.
struct TaskCreationView: View {
    @Environment(\.dismiss) private var dismiss

    let defaultDate: Date
    let defaultPeriod: DataModel.Spread.Period
    let onTaskCreated: (String, Date, DataModel.Spread.Period) -> Void

    @State private var title: String = ""
    @State private var preferredDate: Date
    @State private var preferredPeriod: DataModel.Spread.Period

    @FocusState private var titleFieldFocused: Bool

    init(
        defaultDate: Date,
        defaultPeriod: DataModel.Spread.Period,
        onTaskCreated: @escaping (String, Date, DataModel.Spread.Period) -> Void
    ) {
        self.defaultDate = defaultDate
        self.defaultPeriod = defaultPeriod
        self.onTaskCreated = onTaskCreated
        self._preferredDate = State(initialValue: defaultDate)
        self._preferredPeriod = State(initialValue: defaultPeriod)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title
                Section("Task") {
                    TextField("What needs to be done?", text: $title)
                        .focused($titleFieldFocused)
                }

                // Assignment
                Section("Assignment") {
                    Picker("Period", selection: $preferredPeriod) {
                        ForEach(assignablePeriods, id: \.self) { period in
                            Text(period.name).tag(period)
                        }
                    }

                    DatePicker(
                        "Date",
                        selection: $preferredDate,
                        displayedComponents: [.date]
                    )
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                titleFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Computed Properties

    private var assignablePeriods: [DataModel.Spread.Period] {
        DataModel.Spread.Period.allCases.filter { $0.canHaveTasksAssigned }
    }

    // MARK: - Actions

    private func createTask() {
        onTaskCreated(title, preferredDate, preferredPeriod)
    }
}

#Preview {
    let calendar = Calendar.current

    return TaskCreationView(
        defaultDate: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!,
        defaultPeriod: .month,
        onTaskCreated: { title, date, period in
            print("Created task: \(title) on \(date) for \(period.name)")
        }
    )
}
