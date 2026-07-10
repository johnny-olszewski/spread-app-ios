import SwiftUI

/// A wrapping cloud of selectable chips used in entry editing sheets (e.g. List, Tags).
///
/// Chips render as small `SpreadButton`s — `.tonal` when selected, `.bordered` when not.
/// When `creationPlaceholder`/`onCreate` are provided, a trailing "+ New" chip swaps in
/// place for an inline `TextField`: submitting a non-empty name calls `onCreate`; dismissing
/// with an empty draft cancels back to the chip. Selection semantics (single vs. multi,
/// limits) belong to the caller via `onChipTapped` and the `isSelected`/`isDisabled` flags.
struct EntrySheetChipCloud: View {

    /// One chip in the cloud.
    struct Chip: Identifiable {
        let id: UUID
        let title: String
        let isSelected: Bool
        let isDisabled: Bool

        init(id: UUID, title: String, isSelected: Bool, isDisabled: Bool = false) {
            self.id = id
            self.title = title
            self.isSelected = isSelected
            self.isDisabled = isDisabled
        }
    }

    let chips: [Chip]
    let onChipTapped: (UUID) -> Void
    var creationPlaceholder: String? = nil
    var onCreate: ((String) -> Void)? = nil

    @State private var isCreating = false
    @State private var draftName = ""
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        ChipFlowLayout(spacing: SpreadTheme.Spacing.medium) {
            ForEach(chips) { chip in
                SpreadButton(
                    chip.title,
                    style: chip.isSelected ? .tonal : .bordered,
                    size: .small
                ) {
                    onChipTapped(chip.id)
                }
                .disabled(chip.isDisabled)
            }

            if let creationPlaceholder, onCreate != nil {
                if isCreating {
                    creationField(placeholder: creationPlaceholder)
                } else {
                    SpreadButton("New", icon: .plus, style: .bordered, size: .small) {
                        isCreating = true
                        isDraftFocused = true
                    }
                }
            }
        }
    }

    /// Inline creation field styled to match the small bordered chip metrics.
    private func creationField(placeholder: String) -> some View {
        TextField(placeholder, text: $draftName)
            .font(SpreadTheme.Typography.subheadline.weight(.medium))
            .focused($isDraftFocused)
            .frame(width: 120)
            .padding(.horizontal, SpreadTheme.Spacing.medium)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.standard, style: .continuous)
                    .stroke(SpreadTheme.Separator.strong, lineWidth: 1)
            )
            .onSubmit { submitDraft() }
            .onChange(of: isDraftFocused) { _, isFocused in
                if !isFocused { submitDraft() }
            }
    }

    private func submitDraft() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        draftName = ""
        isCreating = false
        guard !name.isEmpty else { return }
        onCreate?(name)
    }
}

// MARK: - ChipFlowLayout

/// A leading-aligned wrapping layout for chips: rows fill left to right and wrap when the
/// next chip would exceed the proposed width. Private to the chip cloud — not a general
/// layout primitive.
private struct ChipFlowLayout: Layout {

    let spacing: CGFloat

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: .unspecified
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let projectedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && projectedWidth > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.indices.append(index)
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

// MARK: - Previews

#Preview("Multi-select with creation") {
    EntrySheetChipCloud(
        chips: [
            .init(id: UUID(), title: "errands", isSelected: true),
            .init(id: UUID(), title: "family", isSelected: false),
            .init(id: UUID(), title: "deep work", isSelected: true),
            .init(id: UUID(), title: "health", isSelected: false),
            .init(id: UUID(), title: "someday", isSelected: false, isDisabled: true)
        ],
        onChipTapped: { _ in },
        creationPlaceholder: "Tag name",
        onCreate: { _ in }
    )
    .padding()
}

#Preview("Single-select, no creation") {
    EntrySheetChipCloud(
        chips: [
            .init(id: UUID(), title: "Work", isSelected: false),
            .init(id: UUID(), title: "Personal", isSelected: true)
        ],
        onChipTapped: { _ in }
    )
    .padding()
}
