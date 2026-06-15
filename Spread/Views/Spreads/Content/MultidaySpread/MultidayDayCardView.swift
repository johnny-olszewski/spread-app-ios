import SwiftUI

struct MultidayDayCardView<Content: View>: View {
    let dateID: String
    let visualState: SpreadCardStyle
    let footerAction: MultidayDayCardAction
    let overdueCount: Int
    let shortMonthText: String
    let weekdayText: String
    let dayNumberText: String
    let footerAccessibilityLabel: String
    /// When `true`, the content is centered vertically between the header and footer
    /// rather than top-aligned. Used for summary-only cards (e.g. days with an existing
    /// day spread) where a compact HStack replaces the full entry list.
    let isContentCentered: Bool
    /// When non-nil, a peek (eye) button appears on the leading edge of the footer.
    let onPeek: (() -> Void)?
    let onFooterTap: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        dateID: String,
        visualState: SpreadCardStyle,
        footerAction: MultidayDayCardAction,
        overdueCount: Int,
        shortMonthText: String,
        weekdayText: String,
        dayNumberText: String,
        footerAccessibilityLabel: String,
        isContentCentered: Bool = false,
        onPeek: (() -> Void)? = nil,
        onFooterTap: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.dateID = dateID
        self.visualState = visualState
        self.footerAction = footerAction
        self.overdueCount = overdueCount
        self.shortMonthText = shortMonthText
        self.weekdayText = weekdayText
        self.dayNumberText = dayNumberText
        self.footerAccessibilityLabel = footerAccessibilityLabel
        self.isContentCentered = isContentCentered
        self.onPeek = onPeek
        self.onFooterTap = onFooterTap
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isContentCentered {
                Spacer(minLength: 0)
                content()
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                content()
                Spacer(minLength: 0)
            }

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .spreadCardStyle(cornerRadius: 16, fill: visualState.fill, style: visualState)
        .overlay(alignment: .topTrailing) {
            overdueBadge
                .offset(x: 8, y: -8)
        }
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadContent.multidaySection(dateID)
        )
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                if visualState.isToday {
                    Text("Today")
                        .font(SpreadTheme.Typography.caption.smallCaps())
                        .fontWeight(.semibold)
                        .foregroundStyle(SpreadTheme.Accent.todayEmphasis.opacity(0.9))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Today")
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadContent.multidayTodayLabel(dateID)
                        )
                } else {
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 16)

                Text(shortMonthText)
                    .font(SpreadTheme.Typography.caption.smallCaps())
                    .fontWeight(headerWeight)
                    .foregroundStyle(secondaryHeaderColor)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(weekdayText)
                    .font(SpreadTheme.Typography.title3)
                    .fontWeight(headerWeight)
                    .foregroundStyle(primaryHeaderColor)

                Spacer(minLength: 16)

                Text(dayNumberText)
                    .font(SpreadTheme.Typography.title3)
                    .fontWeight(headerWeight)
                    .foregroundStyle(primaryHeaderColor)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let onPeek {
                SpreadButton(viewModel: .init(
                    title: "Preview day spread",
                    systemImage: "eye",
                    style: .secondary,
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayPeekButton(dateID),
                    action: onPeek
                ))
            }

            Spacer()

            SpreadButton(viewModel: .init(
                title: footerAccessibilityLabel,
                systemImage: footerAction.iconName,
                style: .primary,
                accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayFooterButton(dateID),
                action: onFooterTap
            ))
        }
    }

    @ViewBuilder
    private var overdueBadge: some View {
        if overdueCount > 0 {
            if overdueCount > 9 {
                Text("\(overdueCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red, in: Capsule())
                    .accessibilityLabel("\(overdueCount) overdue tasks")
            } else {
                Text("\(overdueCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.red, in: Circle())
                    .accessibilityLabel("\(overdueCount) overdue tasks")
            }
        }
    }

    private var primaryHeaderColor: Color { visualState.primaryHeaderColor }
    private var secondaryHeaderColor: Color { visualState.secondaryHeaderColor }
    private var headerWeight: Font.Weight { visualState.headerWeight }
}
