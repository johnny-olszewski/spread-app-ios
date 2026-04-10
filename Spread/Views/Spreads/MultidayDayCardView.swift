import SwiftUI

struct MultidayDayCardView<Content: View>: View {
    let dateID: String
    let visualState: MultidayDayCardVisualState
    let footerAction: MultidayDayCardAction
    let overdueCount: Int
    let shortMonthText: String
    let weekdayText: String
    let dayNumberText: String
    let footerAccessibilityLabel: String
    let onFooterTap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            content()

            Spacer(minLength: 0)

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    cardBorder,
                    style: cardBorderStyle
                )
        )
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
                if visualState == .today {
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
            Spacer()

            Button(action: onFooterTap) {
                Image(systemName: footerAction.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SpreadTheme.Accent.todaySelectedEmphasis)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.94))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(footerAccessibilityLabel)
            .accessibilityIdentifier(
                Definitions.AccessibilityIdentifiers.SpreadContent.multidayFooterButton(dateID)
            )
        }
    }

    @ViewBuilder
    private var overdueBadge: some View {
        if overdueCount > 0 {
            Text("\(overdueCount)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, overdueCount > 9 ? 8 : 7)
                .padding(.vertical, 3)
                .background(.red, in: Capsule())
                .accessibilityLabel("\(overdueCount) overdue tasks")
        }
    }

    private var cardFill: Color {
        switch visualState {
        case .today:
            return SpreadTheme.Accent.todayEmphasis.opacity(0.08)
        case .uncreated, .created:
            return SpreadTheme.Paper.primary.opacity(0.55)
        }
    }

    private var cardBorder: Color {
        switch visualState {
        case .today:
            return SpreadTheme.Accent.todayEmphasisBorder
        case .uncreated:
            return Color.secondary.opacity(0.28)
        case .created:
            return Color.secondary.opacity(0.12)
        }
    }

    private var cardBorderStyle: StrokeStyle {
        switch visualState {
        case .today:
            return StrokeStyle(lineWidth: 1.5)
        case .uncreated:
            return StrokeStyle(lineWidth: 1, dash: [6, 4])
        case .created:
            return StrokeStyle(lineWidth: 1)
        }
    }

    private var primaryHeaderColor: Color {
        switch visualState {
        case .today:
            return SpreadTheme.Accent.todayEmphasis
        case .uncreated, .created:
            return .primary
        }
    }

    private var secondaryHeaderColor: Color {
        switch visualState {
        case .today:
            return SpreadTheme.Accent.todayEmphasis.opacity(0.9)
        case .uncreated, .created:
            return .secondary
        }
    }

    private var headerWeight: Font.Weight {
        visualState == .today ? .semibold : .regular
    }
}
