import SwiftUI

/// A single-select row of `SpreadButton`s used in entry editing sheets.
///
/// All options are visible inline: the selected option renders `.tonal`, unselected options
/// render `.plain`. Options may carry a Phosphor icon with a custom tint (e.g. priority
/// colors) and can be individually disabled (e.g. invalid status transitions), which dims
/// the option rather than hiding it.
struct EntrySheetChoiceRow<Value: Hashable>: View {

    /// One selectable option in the row.
    struct Option {
        let value: Value
        let title: String
        let icon: SpreadTheme.Icon?
        let iconTint: Color?
        let isDisabled: Bool
        let accessibilityIdentifier: String?

        init(
            value: Value,
            title: String,
            icon: SpreadTheme.Icon? = nil,
            iconTint: Color? = nil,
            isDisabled: Bool = false,
            accessibilityIdentifier: String? = nil
        ) {
            self.value = value
            self.title = title
            self.icon = icon
            self.iconTint = iconTint
            self.isDisabled = isDisabled
            self.accessibilityIdentifier = accessibilityIdentifier
        }
    }

    let options: [Option]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: SpreadTheme.Spacing.small) {
            ForEach(options, id: \.value) { option in
                SpreadButton(
                    option.title,
                    icon: option.icon,
                    iconTint: option.iconTint,
                    style: option.value == selection ? .tonal : .plain,
                    size: .small,
                    accessibilityIdentifier: option.accessibilityIdentifier
                ) {
                    onSelect(option.value)
                }
                .disabled(option.isDisabled)
            }
        }
    }
}

// MARK: - Previews

#Preview("Priority") {
    @Previewable @State var priority: DataModel.Task.Priority = .medium
    EntrySheetChoiceRow(
        options: DataModel.Task.Priority.allCases.map { level in
            .init(
                value: level,
                title: level.displayName,
                icon: level.icon,
                iconTint: level.iconColor
            )
        },
        selection: priority,
        onSelect: { priority = $0 }
    )
    .padding()
}

#Preview("Period") {
    @Previewable @State var period: Period = .day
    EntrySheetChoiceRow(
        options: Period.allCases.map { .init(value: $0, title: $0.displayName) },
        selection: period,
        onSelect: { period = $0 }
    )
    .padding()
}

#Preview("Disabled option") {
    EntrySheetChoiceRow(
        options: [
            .init(value: "open", title: "Open"),
            .init(value: "complete", title: "Complete"),
            .init(value: "cancelled", title: "Cancelled", isDisabled: true)
        ],
        selection: "open",
        onSelect: { _ in }
    )
    .padding()
}
