import SwiftUI

/// Add/remove chip pair for optional fields in entry editing sheets (e.g. due date).
///
/// Renders two distinct elements rather than one conditional element (per the design
/// system's two-elements rule): a `.bordered` "add" chip when the field is unset, and a
/// `.tonal` value chip with a trailing remove button when set. Tapping the value chip
/// invokes `onValueTapped` (e.g. to toggle an inline picker).
struct EntrySheetOptionalFieldChip: View {

    let addTitle: String
    /// The formatted value when the field is set; `nil` renders the add chip.
    let valueTitle: String?
    var addAccessibilityIdentifier: String? = nil
    var valueAccessibilityIdentifier: String? = nil
    let onAdd: () -> Void
    let onRemove: () -> Void
    var onValueTapped: (() -> Void)? = nil

    var body: some View {
        if let valueTitle {
            HStack(spacing: SpreadTheme.Spacing.small) {
                SpreadButton(
                    valueTitle,
                    style: .tonal,
                    size: .small,
                    accessibilityIdentifier: valueAccessibilityIdentifier
                ) {
                    onValueTapped?()
                }
                SpreadButton(icon: .xmarkCircle, style: .plain, size: .small) {
                    onRemove()
                }
            }
        } else {
            SpreadButton(
                addTitle,
                icon: .plus,
                style: .bordered,
                size: .small,
                accessibilityIdentifier: addAccessibilityIdentifier
            ) {
                onAdd()
            }
        }
    }
}

// MARK: - Previews

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        EntrySheetOptionalFieldChip(
            addTitle: "Add due date",
            valueTitle: nil,
            onAdd: {},
            onRemove: {}
        )
        EntrySheetOptionalFieldChip(
            addTitle: "Add due date",
            valueTitle: "Jul 12, 2026",
            onAdd: {},
            onRemove: {}
        )
    }
    .padding()
}
