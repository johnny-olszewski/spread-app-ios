import SwiftUI

struct MultidayDayCardView<Content: View>: View {
    let dateID: String
    let cardStyle: SpreadCardStyle
    let overdueCount: Int
    let shortMonthText: String
    let weekdayText: String
    let dayNumberText: String
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
        cardStyle: SpreadCardStyle,
        overdueCount: Int,
        shortMonthText: String,
        weekdayText: String,
        dayNumberText: String,
        isContentCentered: Bool = false,
        onPeek: (() -> Void)? = nil,
        onFooterTap: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.dateID = dateID
        self.cardStyle = cardStyle
        self.overdueCount = overdueCount
        self.shortMonthText = shortMonthText
        self.weekdayText = weekdayText
        self.dayNumberText = dayNumberText
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
        .spreadCardStyle(cornerRadius: 16, fill: cardStyle.fill, style: cardStyle)
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
                if cardStyle.isToday {
                    Text("Today")
                        .font(SpreadTheme.Typography.caption.smallCaps())
                        .fontWeight(.semibold)
                        .foregroundStyle(SpreadTheme.Accent.primary)
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
                SpreadButton(.init(
                    title: "Preview day spread",
                    icon: .eye,
                    kind: .plain,
                    size: .small,
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayPeekButton(dateID),
                    action: onPeek
                ))
            }

            Spacer()

            if cardStyle.isCreated {
                SpreadButton(.init(
                    title: "Open day spread",
                    icon: .arrowRight,
                    kind: .glass,
                    size: .small,
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayFooterButton(dateID),
                    action: onFooterTap
                ))
            } else {
                SpreadButton(.init(
                    title: "Create day spread",
                    icon: .calendarPlus,
                    kind: .glass,
                    size: .small,
                    accessibilityIdentifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayFooterButton(dateID),
                    action: onFooterTap
                ))
            }
        }
    }

    @ViewBuilder
    private var overdueBadge: some View {
        if overdueCount > 0 {
            if overdueCount > 9 {
                Text("\(overdueCount)")
                    .font(SpreadTheme.Typography.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red, in: Capsule())
                    .accessibilityLabel("\(overdueCount) overdue tasks")
            } else {
                Text("\(overdueCount)")
                    .font(SpreadTheme.Typography.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.red, in: Circle())
                    .accessibilityLabel("\(overdueCount) overdue tasks")
            }
        }
    }

    private var primaryHeaderColor: Color { cardStyle.primaryHeaderColor }
    private var secondaryHeaderColor: Color { cardStyle.secondaryHeaderColor }
    private var headerWeight: Font.Weight { cardStyle.headerWeight }
}
