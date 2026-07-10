import SwiftUI

/// Generic modal sheet shell for entry creation and editing flows.
///
/// Provides mode-driven chrome (custom header, auto-focus behavior, loading overlay, error
/// alert, delete confirmation, optional history section) while keeping all
/// entry-type-specific content in the injected `content` view builder.
///
/// - `content`: All entry-type body sections, including any internal dividers between them.
///   The shell appends dividers + history/delete sections automatically.
/// - `historySection`: Optional view rendered after content in `.edit` mode (e.g. assignment history).
/// - `deleteAction`: Non-nil enables the delete button section in `.edit` mode.
struct EntrySheet<Content: View>: View {

    // MARK: - Configuration

    let navigationTitle: String
    let mode: EntrySheetMode
    let isBusy: Bool

    // MARK: - Toolbar

    /// Accessibility identifier for the cancel toolbar button.
    let cancelIdentifier: String
    /// Accessibility identifier for the primary action toolbar button (Create or Save).
    let primaryIdentifier: String
    let onCancel: () -> Void
    let onPrimary: () -> Void

    // MARK: - Create-mode props

    /// Whether the primary Create button is visible (hidden-until-edited rule).
    var isPrimaryVisible: Bool = true

    // MARK: - Edit-mode props

    /// Whether the primary Save button is enabled.
    var isSaveEnabled: Bool = true

    // MARK: - Edit-mode optional sections

    /// Optional view rendered after content, before the delete section.
    var historySection: AnyView? = nil

    // MARK: - Delete

    var deleteAction: (() -> Void)? = nil
    var deleteAlertTitle: String = "Delete"
    var deleteAlertMessage: String = "This action cannot be undone."
    var deleteButtonIdentifier: String = ""

    // MARK: - Error alert (create mode)

    var errorMessage: Binding<String?>? = nil

    // MARK: - Content

    @ViewBuilder let content: Content

    // MARK: - Private state

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteConfirmation = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content

                    if let historySection {
                        EntrySheetDivider()
                        historySection
                    }

                    if deleteAction != nil {
                        EntrySheetDivider()
                        deleteSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .alert(deleteAlertTitle, isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) { deleteAction?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteAlertMessage)
        }
        .applyIf(errorMessage != nil) { view in
            view.alert("Error", isPresented: Binding(
                get: { errorMessage?.wrappedValue != nil },
                set: { if !$0 { errorMessage?.wrappedValue = nil } }
            )) {
                Button("OK") { errorMessage?.wrappedValue = nil }
            } message: {
                Text(errorMessage?.wrappedValue ?? "")
            }
        }
        .overlay {
            if isBusy {
                EntrySheetLoadingOverlay()
            }
        }
        .applyIf(mode == .create) { view in
            view.interactiveDismissDisabled(isPrimaryVisible)
        }
    }

    // MARK: - Header

    /// Custom in-sheet chrome replacing the nav bar (see EntryEditingSheets.md — Visual
    /// Redesign): Fuzzy Bubbles title leading, plain Cancel and prominent Create/Save trailing.
    private var header: some View {
        HStack(alignment: .center, spacing: SpreadTheme.Spacing.medium) {
            Text(navigationTitle)
                .font(SpreadTheme.Typography.largeTitle(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            SpreadButton(
                "Cancel",
                style: .plain,
                size: .small,
                accessibilityIdentifier: cancelIdentifier
            ) {
                onCancel()
            }

            switch mode {
            case .create:
                if isPrimaryVisible {
                    SpreadButton(
                        "Create",
                        style: .prominent,
                        size: .small,
                        accessibilityIdentifier: primaryIdentifier
                    ) {
                        onPrimary()
                    }
                    .disabled(isBusy)
                }
            case .edit:
                SpreadButton(
                    "Save",
                    style: .prominent,
                    size: .small,
                    accessibilityIdentifier: primaryIdentifier
                ) {
                    onPrimary()
                }
                .disabled(!isSaveEnabled || isBusy)
            }
        }
        .padding(.horizontal, SpreadTheme.Spacing.large)
        .padding(.top, SpreadTheme.Spacing.large)
        .padding(.bottom, SpreadTheme.Spacing.medium)
    }

    // MARK: - Delete section

    private var deleteSection: some View {
        SpreadButton(
            deleteAlertTitle,
            icon: .trash,
            style: .plain,
            role: .destructive,
            accessibilityIdentifier: deleteButtonIdentifier
        ) {
            isShowingDeleteConfirmation = true
        }
    }
}

// MARK: - View+applyIf

private extension View {
    @ViewBuilder
    func applyIf<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
