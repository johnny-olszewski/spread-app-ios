import SwiftUI

/// Sheet for reviewing and confirming task migration into a destination spread.
struct MigrationSelectionSheet: View {

    let destinationSpread: DataModel.Spread
    let eligibleCandidates: [MigrationCandidate]
    let calendar: Calendar
    let onMigrate: ([MigrationCandidate]) async -> MigrationSelectionOutcome

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var isSubmitting = false
    @State private var statusMessage: String?

    private var sections: [MigrationReviewSection] {
        MigrationReviewGrouper(calendar: calendar).sections(
            for: eligibleCandidates,
            destination: destinationSpread
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color(.systemYellow).opacity(0.12))
                }

                List {
                    ForEach(sections) { section in
                        Section(section.sourceTitle) {
                            ForEach(section.candidates, id: \.task.id) { candidate in
                                TaskSelectionRow(
                                    task: candidate.task,
                                    isSelected: selectedTaskIDs.contains(candidate.task.id),
                                    sourceDisplayName: section.sourceDisplayName,
                                    destinationDisplayName: section.destinationDisplayName
                                ) {
                                    toggleSelection(for: candidate.task.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Migrate Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Migrate Selected") {
                        submitMigration()
                    }
                    .disabled(selectedTaskIDs.isEmpty || isSubmitting)
                }
            }
            .onAppear {
                resetSelection()
            }
            .onChange(of: eligibleCandidates.map(\.task.id)) { _, _ in
                if eligibleCandidates.isEmpty {
                    dismiss()
                } else {
                    resetSelection()
                }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Move selected tasks into \(destinationDisplayName)")
                .font(.headline)

            Text("Eligible tasks stay grouped by where they currently live so migration remains explicit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Select All") {
                    selectedTaskIDs = Set(eligibleCandidates.map(\.task.id))
                }
                .font(.caption)
                .disabled(isSubmitting || eligibleCandidates.isEmpty)

                Button("Deselect All") {
                    selectedTaskIDs = []
                }
                .font(.caption)
                .disabled(isSubmitting || eligibleCandidates.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
    }

    private var destinationDisplayName: String {
        MigrationReviewGrouper(calendar: calendar)
            .sections(for: eligibleCandidates, destination: destinationSpread)
            .first?
            .destinationDisplayName ?? fallbackSpreadLabel(for: destinationSpread)
    }

    private func toggleSelection(for taskID: UUID) {
        if selectedTaskIDs.contains(taskID) {
            selectedTaskIDs.remove(taskID)
        } else {
            selectedTaskIDs.insert(taskID)
        }
    }

    private func resetSelection() {
        selectedTaskIDs = Set(eligibleCandidates.map(\.task.id))
        statusMessage = nil
    }

    private func submitMigration() {
        let selected = eligibleCandidates.filter { selectedTaskIDs.contains($0.task.id) }
        guard !selected.isEmpty else { return }

        isSubmitting = true
        Task {
            let outcome = await onMigrate(selected)
            await MainActor.run {
                isSubmitting = false

                if outcome.remainingCount == 0 {
                    dismiss()
                    return
                }

                statusMessage = statusMessage(for: outcome)
            }
        }
    }

    private func statusMessage(for outcome: MigrationSelectionOutcome) -> String? {
        switch (outcome.migratedCount, outcome.skippedCount) {
        case (_, 0):
            return nil
        case (0, let skipped):
            return "\(skipped) task\(skipped == 1 ? "" : "s") changed and were skipped."
        case (let migrated, let skipped):
            return "\(migrated) task\(migrated == 1 ? "" : "s") migrated. \(skipped) task\(skipped == 1 ? "" : "s") changed and were skipped."
        }
    }

    private func fallbackSpreadLabel(for spread: DataModel.Spread) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch spread.period {
        case .year:
            return "\(calendar.component(.year, from: spread.date))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: spread.date)
        case .day:
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: spread.date)
        case .multiday:
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: spread.date) + "+"
        }
    }
}

private struct TaskSelectionRow: View {

    let task: DataModel.Task
    let isSelected: Bool
    let sourceDisplayName: String
    let destinationDisplayName: String
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text("Currently on: \(sourceDisplayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Move to: \(destinationDisplayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
