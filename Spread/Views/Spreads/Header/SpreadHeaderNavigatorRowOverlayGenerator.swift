import SwiftUI
import JohnnyOFoundationCore
import JohnnyOFoundationUI

struct SpreadHeaderNavigatorRowOverlayPayload: Sendable, Equatable {
    let spreadID: UUID
    let label: String
    let isCurrent: Bool
}

struct SpreadHeaderNavigatorRowOverlayGenerator: MonthCalendarRowOverlayGenerator {
    static let defaultVisibleLaneCount = 2

    let overlays: [MonthCalendarLogicalRowOverlay<UUID, SpreadHeaderNavigatorRowOverlayPayload>]
    let maximumVisibleLaneCount: Int

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

        return ZStack(alignment: .leading) {
            Capsule(style: .circular)
                .fill(overlayFill(isCurrent: isCurrent))
                .overlay {
                    Capsule(style: .circular)
                        .strokeBorder(overlayBorder(isCurrent: isCurrent), lineWidth: isCurrent ? 1.0 : 0.8)
                }

            if context.continuesBeforeWeek {
                continuationMarker
                    .frame(maxHeight: .infinity, alignment: .center)
            }

            if context.continuesAfterWeek {
                continuationMarker
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, 2)
        .padding(.top, 3)
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }

    func overflowView(
        context: MonthCalendarRowOverlayOverflowRenderContext<UUID, SpreadHeaderNavigatorRowOverlayPayload>
    ) -> some View {
        Text("+\(context.hiddenSegmentCount)")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .circular)
                    .fill(SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.72))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }

    private func overlayFill(isCurrent: Bool) -> Color {
        SpreadTheme.Accent.todaySelectedEmphasis.opacity(isCurrent ? 0.24 : 0.14)
    }

    private func overlayBorder(isCurrent: Bool) -> Color {
        SpreadTheme.Accent.todaySelectedEmphasis.opacity(isCurrent ? 0.48 : 0.28)
    }

    private var continuationMarker: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(SpreadTheme.Accent.todaySelectedEmphasis.opacity(0.42))
            .frame(width: 3)
            .padding(.vertical, 1)
    }
}
