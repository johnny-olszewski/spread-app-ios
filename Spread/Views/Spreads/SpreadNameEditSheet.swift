import SwiftUI

struct SpreadNameEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var journalManager: JournalManager
    let spread: DataModel.Spread
    let onSaved: () -> Void

    @State private var customName: String
    @State private var usesDynamicName: Bool
    @State private var isSaving = false
    @State private var isShowingError = false
    @State private var errorMessage = ""

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Custom name", text: $customName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.customNameField)

                    Toggle("Use dynamic name when custom name is empty", isOn: $usesDynamicName)
                        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.dynamicNameToggle)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.cancelButton)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNameEditSheet.saveButton)
                }
            }
            .alert("Error", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

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
                    isShowingError = true
                    isSaving = false
                }
            }
        }
    }
}
