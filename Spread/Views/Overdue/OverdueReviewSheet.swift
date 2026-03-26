import SwiftUI

/// Global read-only review surface for overdue tasks.
struct OverdueReviewSheet: View {

    @Bindable var journalManager: JournalManager
    let syncEngine: SyncEngine?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTask: DataModel.Task?

    private var sections: [OverdueReviewSection] {
        OverdueReviewGrouper(calendar: journalManager.calendar).sections(
            for: journalManager.overdueTaskItems
        )
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            Button {
                                selectedTask = item.task
                            } label: {
                                OverdueTaskRow(
                                    task: item.task,
                                    calendar: journalManager.calendar
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                Definitions.AccessibilityIdentifiers.Overdue.row(item.task.title)
                            )
                        }
                    }
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.Overdue.section(section.id)
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Overdue Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Overdue.doneButton)
                }
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailSheet(
                    task: task,
                    journalManager: journalManager,
                    onDelete: {
                        Task { await syncEngine?.syncNow() }
                    }
                )
            }
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Overdue.sheet)
    }
}

private struct OverdueTaskRow: View {

    let task: DataModel.Task
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .foregroundStyle(.primary)

            Text(detailText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Overdue.row(task.title))
    }

    private var detailText: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch task.period {
        case .year:
            return "Preferred period: \(calendar.component(.year, from: task.date))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return "Preferred period: \(formatter.string(from: task.date))"
        case .day:
            formatter.dateFormat = "MMMM d, yyyy"
            return "Preferred date: \(formatter.string(from: task.date))"
        case .multiday:
            formatter.dateFormat = "MMMM d"
            return "Preferred period: \(formatter.string(from: task.date))+"
        }
    }
}
