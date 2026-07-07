import SwiftUI

/// Popover content for disambiguating a navigator day tap when multiple spreads cover the
/// tapped date (a day spread plus one or more multiday spreads, or several multidays).
///
/// Presented through `SpreadsCoordinator.activePopover` like every coordinator-driven
/// popover, anchored on the tapped day cell: a popover on regular width, and a small
/// detent sheet on compact via the standard presentation adaptation at the call site.
struct NavigatorDaySelectionPopoverContent: PopoverContent {

    /// One selectable destination covering the tapped date.
    struct Option: Identifiable {
        let spread: DataModel.Spread
        let title: String
        let subtitle: String?
        let icon: SpreadTheme.Icon

        var id: UUID { spread.id }
    }

    let date: Date
    let options: [Option]
    let onSelect: @MainActor (DataModel.Spread) -> Void

    var id: String { "navigatorDaySelection-\(date.timeIntervalSinceReferenceDate)" }
    var arrowEdge: Edge { .top }
    var attachmentAnchor: PopoverAttachmentAnchor { .rect(.bounds) }

    var body: NavigatorDaySelectionPopoverBodyView {
        NavigatorDaySelectionPopoverBodyView(content: self)
    }
}

// MARK: - Body View

/// Compact destination list: one row per covering spread, dismissing on selection.
struct NavigatorDaySelectionPopoverBodyView: View {

    let content: NavigatorDaySelectionPopoverContent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: SpreadTheme.Spacing.medium) {
            Text("Open")
                .font(SpreadTheme.Typography.headline)
                .foregroundStyle(.primary)

            ForEach(content.options) { option in
                Button {
                    dismiss()
                    content.onSelect(option.spread)
                } label: {
                    HStack(spacing: SpreadTheme.Spacing.medium) {
                        option.icon.sized(SpreadTheme.IconSize.medium)
                            .iconTint(SpreadTheme.Accent.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(SpreadTheme.Typography.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(SpreadTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        SpreadTheme.Icon.caretRight.sized(SpreadTheme.IconSize.small)
                            .iconTint(.secondary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SpreadTheme.Spacing.large)
        .frame(minWidth: 260, alignment: .leading)
    }
}

// MARK: - Previews

#Preview {
    NavigatorDaySelectionPopoverBodyView(content: NavigatorDaySelectionPopoverContent(
        date: Date(),
        options: [
            .init(
                spread: DataModel.Spread(period: .day, date: Date(), calendar: .current),
                title: "Day spread",
                subtitle: "Jul 4, 2026",
                icon: .sun
            ),
            .init(
                spread: DataModel.Spread(
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(86400 * 4),
                    calendar: .current
                ),
                title: "Jul 3 – Jul 8, 2026",
                subtitle: "Multiday spread",
                icon: .rows
            )
        ],
        onSelect: { _ in }
    ))
}
