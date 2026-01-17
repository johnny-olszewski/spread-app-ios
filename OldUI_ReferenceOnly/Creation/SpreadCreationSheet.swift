//
//  SpreadCreationSheet.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Modal sheet for creating a new spread.
/// Only allows creation of future dates and prevents duplicates.
struct SpreadCreationSheet: View {
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.dismiss) private var dismiss

    let onSpreadCreated: (DataModel.Spread.Period, Date) -> Void

    @State private var selectedPeriod: DataModel.Spread.Period = .month
    @State private var selectedDate: Date = Date()
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                // Period selection
                Section("Spread Type") {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(creatablePeriods, id: \.self) { period in
                            Text(period.name).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(periodDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Date selection
                Section("Date") {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: dateRange,
                        displayedComponents: datePickerComponents
                    )
                    .datePickerStyle(.graphical)
                }

                // Validation message
                if !canCreate {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Spread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSpread()
                    }
                    .disabled(!canCreate)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPeriod) { _, _ in
                // Adjust date when period changes
                adjustDateForPeriod()
            }
        }
    }

    // MARK: - Computed Properties

    private var creatablePeriods: [DataModel.Spread.Period] {
        // Only periods that make sense for spreads (excluding week for now)
        [.year, .month, .day]
    }

    private var periodDescription: String {
        switch selectedPeriod {
        case .year:
            return "A year spread covers all 12 months"
        case .month:
            return "A month spread covers all days in that month"
        case .multiday:
            return "A multi-day spread covers a custom date range (future feature)"
        case .week:
            return "A week spread covers 7 days"
        case .day:
            return "A day spread covers a single day"
        }
    }

    private var dateRange: ClosedRange<Date> {
        let calendar = journalManager.calendar
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: journalManager.today)!
        let farFuture = calendar.date(byAdding: .year, value: 10, to: journalManager.today)!
        return tomorrow...farFuture
    }

    private var datePickerComponents: DatePicker.Components {
        switch selectedPeriod {
        case .year:
            return [.date] // Need at least date for year selection context
        case .month:
            return [.date]
        case .multiday:
            return [.date]
        case .week:
            return [.date]
        case .day:
            return [.date]
        }
    }

    private var canCreate: Bool {
        // Check if spread already exists
        let normalizedDate = selectedPeriod.normalizeDate(selectedDate, calendar: journalManager.calendar)
        let exists = journalManager.spreadExists(for: selectedPeriod, on: normalizedDate)

        // Check if date is in the future
        let isInFuture = selectedDate > journalManager.today

        return !exists && isInFuture
    }

    private var validationMessage: String {
        let normalizedDate = selectedPeriod.normalizeDate(selectedDate, calendar: journalManager.calendar)
        if journalManager.spreadExists(for: selectedPeriod, on: normalizedDate) {
            return "A spread for this \(selectedPeriod.name.lowercased()) already exists"
        }
        if selectedDate <= journalManager.today {
            return "You can only create spreads for future dates"
        }
        return ""
    }

    // MARK: - Actions

    private func adjustDateForPeriod() {
        let calendar = journalManager.calendar
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: journalManager.today)!

        // Ensure the date is in the future
        if selectedDate <= journalManager.today {
            selectedDate = tomorrow
        }
    }

    private func createSpread() {
        guard canCreate else {
            showingError = true
            errorMessage = validationMessage
            return
        }

        onSpreadCreated(selectedPeriod, selectedDate)
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()

    return SpreadCreationSheet(
        onSpreadCreated: { period, date in
            print("Created \(period.name) spread for \(date)")
        }
    )
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
