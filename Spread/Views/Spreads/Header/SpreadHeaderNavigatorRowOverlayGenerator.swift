import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

struct SpreadHeaderNavigatorRowOverlayPayload: Sendable, Equatable {
    let spreadID: UUID
    let label: String
    let isCurrent: Bool
}

struct SpreadHeaderNavigatorRowOverlayGenerator: MonthCalendarRowOverlayGenerator {
    enum ContinuationEdgeTreatment: Equatable {
        case none
        case marker
        case fade
    }

    static let defaultVisibleLaneCount = 2
    private static let laneHeight: CGFloat = 3
    private static let laneHorizontalPadding: CGFloat = 4
    private static let laneBottomPadding: CGFloat = 6
    private static let continuationMarkerWidth: CGFloat = 2
    private static let continuationMarkerVerticalPadding: CGFloat = 0.5

    static func overflowLabel(hiddenSegmentCount: Int) -> String {
        "+\(hiddenSegmentCount)"
    }

    let overlays: [MonthCalendarLogicalRowOverlay<UUID, SpreadHeaderNavigatorRowOverlayPayload>]
    let maximumVisibleLaneCount: Int
    let displayedMonth: Date
    let calendar: Calendar

    init(
        model: SpreadHeaderNavigatorModel,
        monthRow: SpreadHeaderNavigatorModel.MonthRow,
        currentSpread: DataModel.Spread,
        maximumVisibleLaneCount: Int = Self.defaultVisibleLaneCount
    ) {
        self.overlays = Self.makeOverlays(
            model: model,
            monthRow: monthRow,
            currentSpread: currentSpread
        )
        self.maximumVisibleLaneCount = maximumVisibleLaneCount
        self.displayedMonth = monthRow.date
        self.calendar = model.calendar
    }

    static func makeOverlays(
        model: SpreadHeaderNavigatorModel,
        monthRow: SpreadHeaderNavigatorModel.MonthRow,
        currentSpread: DataModel.Spread
    ) -> [MonthCalendarLogicalRowOverlay<UUID, SpreadHeaderNavigatorRowOverlayPayload>] {
        guard model.mode == .conventional else { return [] }

        let monthInterval = model.calendar.dateInterval(of: .month, for: monthRow.date)!
        return model.spreads
            .filter { spread in
                guard spread.period == .multiday else { return false }
                let startDate = Period.day.normalizeDate(spread.startDate ?? spread.date, calendar: model.calendar)
                let endDate = Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: model.calendar)
                return startDate < monthInterval.end && endDate >= monthInterval.start
            }
            .sorted { lhs, rhs in
                let lhsStart = Period.day.normalizeDate(lhs.startDate ?? lhs.date, calendar: model.calendar)
                let rhsStart = Period.day.normalizeDate(rhs.startDate ?? rhs.date, calendar: model.calendar)
                if lhsStart != rhsStart {
                    return lhsStart < rhsStart
                }

                let lhsEnd = Period.day.normalizeDate(lhs.endDate ?? lhs.date, calendar: model.calendar)
                let rhsEnd = Period.day.normalizeDate(rhs.endDate ?? rhs.date, calendar: model.calendar)
                if lhsEnd != rhsEnd {
                    return lhsEnd < rhsEnd
                }

                return lhs.createdDate < rhs.createdDate
            }
            .map { spread in
                MonthCalendarLogicalRowOverlay(
                    id: spread.id,
                    startDate: Period.day.normalizeDate(spread.startDate ?? spread.date, calendar: model.calendar),
                    endDate: Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: model.calendar),
                    payload: SpreadHeaderNavigatorRowOverlayPayload(
                        spreadID: spread.id,
                        label: spread.displayLabel(calendar: model.calendar),
                        isCurrent: currentSpread.period == .multiday && currentSpread.id == spread.id
                    )
                )
            }
    }

    func rowOverlayView(
        context: MonthCalendarPackedRowOverlayRenderContext<UUID, SpreadHeaderNavigatorRowOverlayPayload>
    ) -> some View {
        let isCurrent = context.overlay.payload.isCurrent
        let leadingTreatment = Self.leadingEdgeTreatment(
            context: context,
            displayedMonth: displayedMonth,
            calendar: calendar
        )
        let trailingTreatment = Self.trailingEdgeTreatment(
            context: context,
            displayedMonth: displayedMonth,
            calendar: calendar
        )

        return ZStack(alignment: .leading) {
            Capsule(style: .circular)
                .fill(overlayFill(isCurrent: isCurrent))
                .overlay {
                    Capsule(style: .circular)
                        .strokeBorder(overlayBorder(isCurrent: isCurrent), lineWidth: isCurrent ? 1.0 : 0.8)
                }
                .frame(height: Self.laneHeight)

            if leadingTreatment == .marker {
                continuationMarker(isCurrent: isCurrent)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }

            if trailingTreatment == .marker {
                continuationMarker(isCurrent: isCurrent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .mask(
            edgeFadeMask(
                leadingFade: leadingTreatment == .fade,
                trailingFade: trailingTreatment == .fade
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, Self.laneHorizontalPadding)
        .padding(.bottom, Self.laneBottomPadding)
        .accessibilityHidden(true)
    }

    func overflowView(
        context: MonthCalendarRowOverlayOverflowRenderContext<UUID, SpreadHeaderNavigatorRowOverlayPayload>
    ) -> some View {
        let isCurrent = overflowContainsCurrentOverlay(context)
        Text(Self.overflowLabel(hiddenSegmentCount: context.hiddenSegmentCount))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(overflowForeground(isCurrent: isCurrent))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .circular)
                    .fill(overflowFill(isCurrent: isCurrent))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }

    private func overlayFill(isCurrent: Bool) -> Color {
        isCurrent
            ? SpreadSelectionVisualStyle.overlayFill
            : SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.14)
    }

    private func overlayBorder(isCurrent: Bool) -> Color {
        isCurrent
            ? SpreadSelectionVisualStyle.overlayBorder
            : SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.28)
    }

    private func continuationMarker(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                isCurrent
                    ? SpreadSelectionVisualStyle.overlayMarker
                    : SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.42)
            )
            .frame(width: Self.continuationMarkerWidth, height: Self.laneHeight + 1)
            .padding(.vertical, Self.continuationMarkerVerticalPadding)
    }

    private func overflowContainsCurrentOverlay(
        _ context: MonthCalendarRowOverlayOverflowRenderContext<UUID, SpreadHeaderNavigatorRowOverlayPayload>
    ) -> Bool {
        context.hiddenSegments.contains(where: { $0.overlay.payload.isCurrent })
    }

    private func overflowFill(isCurrent: Bool) -> Color {
        isCurrent
            ? SpreadSelectionVisualStyle.overflowFill
            : SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.72)
    }

    private func overflowForeground(isCurrent: Bool) -> Color {
        isCurrent
            ? SpreadSelectionVisualStyle.overflowForeground
            : .white
    }

    private func edgeFadeMask(
        leadingFade: Bool,
        trailingFade: Bool
    ) -> some View {
        let fadeFraction = 0.12
        return LinearGradient(
            stops: [
                .init(color: .white.opacity(leadingFade ? 0 : 1), location: 0),
                .init(color: .white, location: leadingFade ? fadeFraction : 0),
                .init(color: .white, location: trailingFade ? 1 - fadeFraction : 1),
                .init(color: .white.opacity(trailingFade ? 0 : 1), location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func leadingEdgeTreatment(
        context: MonthCalendarPackedRowOverlayRenderContext<UUID, SpreadHeaderNavigatorRowOverlayPayload>,
        displayedMonth: Date,
        calendar: Calendar
    ) -> ContinuationEdgeTreatment {
        guard context.continuesBeforeWeek else { return .none }
        if context.startColumn > 0 {
            return .fade
        }
        return .marker
    }

    static func trailingEdgeTreatment(
        context: MonthCalendarPackedRowOverlayRenderContext<UUID, SpreadHeaderNavigatorRowOverlayPayload>,
        displayedMonth: Date,
        calendar: Calendar
    ) -> ContinuationEdgeTreatment {
        guard context.continuesAfterWeek else { return .none }
        if context.endColumn < 6 {
            return .fade
        }
        return .marker
    }
}
