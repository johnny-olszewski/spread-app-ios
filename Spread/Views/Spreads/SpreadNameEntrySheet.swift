import SwiftUI

/// Edit-mode sheet for renaming an existing spread, built on the generic `EntrySheet` shell.
///
/// Replaces `SpreadNameEditSheet` (which used a native `Form` layout). Supports:
/// - Custom name text field
/// - Dynamic-name toggle
/// - Save-error alert (surfaced via `EntrySheet`'s error binding)
struct SpreadNameEntrySheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties

    @Bindable var journalManager: JournalManager
    let spread: DataModel.Spread
    let onSaved: () -> Void

    // MARK: - State

    @State private var customName: String
    @State private var usesDynamicName: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        journalManager: JournalManager,
        spread: DataModel.Spread,
        onSaved: @escaping () -> Void
    ) {
        self.journalManager = journalManager
        self.spread = spread
        self.onSaved = onSaved
        _customName = State(initialValue: spread.customName ?? "")
        _usesDynamicName = State(initialValue: spread.usesDynamicName)
    }

    // MARK: - Body

    var body: some View {
        EntrySheet(
            navigationTitle: "Edit Name",
            mode: .edit,
            isBusy: isSaving,
            cancelIdentifier: Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.cancelButton,
            primaryIdentifier: Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.saveButton,
            onCancel: { dismiss() },
            onPrimary: { save() },
            errorMessage: Binding(
                get: { errorMessage },
                set: { errorMessage = $0 }
            )
        ) {
            nameSection
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EntrySheetSectionHeader(title: "Name")

            TextField("Custom name", text: $customName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.customNameField)

            Toggle("Use dynamic name when custom name is empty", isOn: $usesDynamicName)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.dynamicNameToggle)
        }
    }

    // MARK: - Actions

    private func save() {
        isSaving = true
        Task {
            do {
                try await journalManager.updateSpreadName(
                    spread,
                    customName: customName,
                    usesDynamicName: usesDynamicName
                )
                await MainActor.run {
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update spread name: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }()
    let spread = DataModel.Spread(period: .month, date: Date(), calendar: calendar)
    SpreadNameEntrySheet(
        journalManager: .previewInstance,
        spread: spread,
        onSaved: {}
    )
}
