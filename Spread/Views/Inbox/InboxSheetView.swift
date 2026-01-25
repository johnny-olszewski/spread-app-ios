import SwiftUI
import struct Foundation.Calendar

/// Sheet view displaying inbox entries.
///
/// Shows unassigned tasks and notes grouped by entry type (tasks first, then notes).
/// Each entry row displays the entry symbol, title, and preferred date.
/// Swipe actions allow assigning entries to spreads.
struct InboxSheetView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    /// The journal manager providing inbox data.
    @Bindable var journalManager: JournalManager

    // MARK: - Computed Properties

    /// Grouped inbox entries.
    private var sections: [InboxEntrySection] {
        let grouper = InboxEntryGrouper(calendar: journalManager.calendar)
        return grouper.group(journalManager.inboxEntries)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Inbox")
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if sections.isEmpty {
            emptyState
        } else {
            entryList
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Inbox Empty", systemImage: "tray")
        } description: {
            Text("All entries have been assigned to spreads.")
        }
    }

    private var entryList: some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.entries, id: \.id) { entry in
                        entryRow(for: entry)
                            .swipeActions(edge: .trailing) {
                                // TODO: SPRD-31 - Add assign to spread action
                                Button {
                                    // Assign action will open spread picker
                                } label: {
                                    Label("Assign", systemImage: "tray.and.arrow.down")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Entry Row

    @ViewBuilder
    private func entryRow(for entry: any Entry) -> some View {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                InboxEntryRow(task: task, calendar: journalManager.calendar)
            }
        case .note:
            if let note = entry as? DataModel.Note {
                InboxEntryRow(note: note, calendar: journalManager.calendar)
            }
        case .event:
            // Events are not in inbox (they use computed visibility)
            EmptyView()
        }
    }
}

// MARK: - Previews

#Preview("With Entries") {
    InboxSheetView(journalManager: .previewInstance)
}

#Preview("Empty") {
    InboxSheetView(journalManager: .previewInstanceEmpty)
}
