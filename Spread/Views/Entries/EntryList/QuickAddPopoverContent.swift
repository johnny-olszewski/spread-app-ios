import SwiftUI

/// Popover content for the quick-add task entry affordance.
///
/// Carries the context needed to create a task: target date, period,
/// available lists and tags, and the add-task action.
struct QuickAddPopoverContent: PopoverContent {

    /// Identifies which anchor triggered this popover, used to discriminate `.popover` bindings
    /// when multiple buttons on screen share the same date and period (e.g. multi-section day spread).
    let anchorID: String
    let date: Date
    let period: Period
    let availableLists: [DataModel.List]
    let availableTags: [DataModel.Tag]
    /// Pre-selected list shown when the popover opens. `nil` leaves the picker blank.
    let preselectedList: DataModel.List?
    let onAddTask: @MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void

    var id: String { "\(anchorID)-\(date.timeIntervalSinceReferenceDate)-\(period.rawValue)" }
    var arrowEdge: Edge { .leading }
    var attachmentAnchor: PopoverAttachmentAnchor { .rect(.bounds) }

    var body: QuickAddPopoverBodyView {
        QuickAddPopoverBodyView(content: self)
    }
}

// MARK: - Body View

/// The popover view for the quick-add task entry affordance.
///
/// Owns mutable form state (title, list and tag selection) and submits via `content.onAddTask`.
struct QuickAddPopoverBodyView: View {

    let content: QuickAddPopoverContent

    @State private var title = ""
    @State private var selectedList: DataModel.List?
    @State private var selectedTag: DataModel.Tag?
    @FocusState private var isTitleFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(content: QuickAddPopoverContent) {
        self.content = content
        _selectedList = State(wrappedValue: content.preselectedList)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New Task")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            TextField("Task title", text: $title)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit { submitTask() }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if !content.availableLists.isEmpty || !content.availableTags.isEmpty {
                HStack(spacing: 8) {
                    if !content.availableLists.isEmpty { listPickerButton }
                    if !content.availableTags.isEmpty { tagPickerButton }
                    Spacer()
                    addButton
                }
            } else {
                HStack {
                    Spacer()
                    addButton
                }
            }
        }
        .padding(16)
        .frame(minWidth: 320)
        .task { isTitleFocused = true }
        .onDisappear { clearState() }
    }

    // MARK: - Subviews

    private var addButton: some View {
        Button("Add") { submitTask() }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var listPickerButton: some View {
        Menu {
            if selectedList != nil {
                Button("Clear List", role: .destructive) { selectedList = nil }
            }
            ForEach(content.availableLists) { list in
                Button {
                    selectedList = list
                } label: {
                    if selectedList?.id == list.id {
                        Label(list.name, systemImage: "checkmark")
                    } else {
                        Text(list.name)
                    }
                }
            }
        } label: {
            Label(
                selectedList?.name ?? "List",
                systemImage: selectedList != nil ? "folder.fill" : "folder"
            )
            .foregroundStyle(selectedList != nil ? SpreadTheme.Accent.primary : .secondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var tagPickerButton: some View {
        Menu {
            if selectedTag != nil {
                Button("Clear Tag", role: .destructive) { selectedTag = nil }
            }
            ForEach(content.availableTags) { tag in
                Button {
                    selectedTag = tag
                } label: {
                    if selectedTag?.id == tag.id {
                        Label(tag.name, systemImage: "checkmark")
                    } else {
                        Text(tag.name)
                    }
                }
            }
        } label: {
            Label(
                selectedTag?.name ?? "Tag",
                systemImage: selectedTag != nil ? "tag.fill" : "tag"
            )
            .foregroundStyle(selectedTag != nil ? SpreadTheme.Accent.primary : .secondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Helpers

    private func submitTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let list = selectedList
        let tag = selectedTag
        dismiss()
        Task { @MainActor in try? await content.onAddTask(trimmed, content.date, content.period, list, tag) }
    }

    private func clearState() {
        title = ""
        selectedList = nil
        selectedTag = nil
    }
}
