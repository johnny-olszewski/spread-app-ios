import SwiftUI

/// A fully generic model for presenting a SwiftUI alert.
///
/// Carry the alert title, optional body message, and an ordered list of buttons.
/// Use the static presets for the app's standard alert scenarios.
struct AlertModel: Identifiable {

    /// Unique identifier — used by `.alert(item:)` to detect presentation changes.
    let id: String

    let title: String
    let message: String?
    let buttons: [Button]

    // MARK: - Button

    struct Button: Identifiable {
        let id: String
        let label: String

        /// `.destructive`, `.cancel`, or `nil` (default).
        let role: ButtonRole?

        /// `nil` for passive buttons (e.g. Cancel with no side effect).
        let action: (@MainActor () async -> Void)?

        init(label: String, role: ButtonRole? = nil, action: (@MainActor () async -> Void)? = nil) {
            self.id = label
            self.label = label
            self.role = role
            self.action = action
        }
    }
}

// MARK: - View Modifier

/// Renders an `AlertModel` using SwiftUI's `alert(_:isPresented:presenting:actions:message:)`.
///
/// Extracted into a `ViewModifier` so the type-checker is not asked to infer the full alert
/// expression inline inside a complex `body` property.
struct AlertModelModifier: ViewModifier {
    let model: AlertModel?
    let isPresented: Binding<Bool>

    func body(content: Content) -> some View {
        content.alert(
            model?.title ?? "",
            isPresented: isPresented,
            presenting: model
        ) { alertModel in
            ForEach(alertModel.buttons) { button in
                Button(button.label, role: button.role) {
                    if let action = button.action {
                        Task { @MainActor in await action() }
                    }
                }
            }
        } message: { alertModel in
            if let message = alertModel.message {
                Text(message)
            }
        }
    }
}

// MARK: - Standard Presets

extension AlertModel {

    /// Confirmation alert before deleting a spread.
    static func deleteSpreadConfirmation(
        spread: DataModel.Spread,
        onDelete: @escaping @MainActor () async -> Void
    ) -> AlertModel {
        AlertModel(
            id: "deleteSpreadConfirmation-\(spread.id)",
            title: "Delete Spread",
            message: "Only this spread will be deleted. Tasks and notes are preserved and moved to " +
                     "the nearest parent spread or Inbox. This action cannot be undone.",
            buttons: [
                Button(label: "Delete Spread", role: .destructive, action: onDelete),
                Button(label: "Cancel", role: .cancel)
            ]
        )
    }

    /// Error alert shown when spread deletion fails.
    static func deleteSpreadFailed(message: String, onDismiss: @escaping @MainActor () -> Void) -> AlertModel {
        AlertModel(
            id: "deleteSpreadFailed",
            title: "Couldn't Delete Spread",
            message: message,
            buttons: [
                Button(label: "OK", action: { onDismiss() })
            ]
        )
    }

    /// Prompt asking whether to save or discard an in-progress title edit.
    static func discardChanges(
        onSave: @escaping @MainActor () async -> Void,
        onDiscard: @escaping @MainActor () async -> Void
    ) -> AlertModel {
        AlertModel(
            id: "discardChanges",
            title: "Unsaved Changes",
            message: "Save your title changes before continuing?",
            buttons: [
                Button(label: "Save", action: onSave),
                Button(label: "Discard", role: .destructive, action: onDiscard)
            ]
        )
    }

    /// Confirmation alert before deleting an entry.
    static func deleteEntryConfirmation(
        confirmAction: @escaping @MainActor () async -> Void
    ) -> AlertModel {
        AlertModel(
            id: "deleteEntryConfirmation",
            title: "Confirm Delete",
            message: "Are you sure you want to delete this entry?",
            buttons: [
                Button(label: "Delete", role: .destructive, action: confirmAction),
                Button(label: "Cancel", role: .cancel)
            ]
        )
    }

    /// Shown when the user taps the status icon on a read-only overdue-card row. Confirms
    /// before navigating away, since tapping the icon looks like a status toggle elsewhere
    /// in the app — this surface can't make that change directly.
    static func overdueCardNavigateConfirmation(
        destinationLabel: String,
        onNavigate: @escaping @MainActor () async -> Void
    ) -> AlertModel {
        AlertModel(
            id: "overdueCardNavigateConfirmation",
            title: "Can't Modify From Here",
            message: "Navigate to \(destinationLabel) to make changes to this task?",
            buttons: [
                Button(label: "Navigate", action: onNavigate),
                Button(label: "Cancel", role: .cancel)
            ]
        )
    }

    /// Shown for an overdue-card row whose task lives in the Inbox — there's no spread to
    /// navigate to, so this is informational only.
    static var overdueCardInboxNotice: AlertModel {
        AlertModel(
            id: "overdueCardInboxNotice",
            title: "Task in Inbox",
            message: "This task can't be modified from here. Open the Search tab to view and edit it.",
            buttons: [Button(label: "OK")]
        )
    }
}
