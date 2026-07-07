import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// Content column view for the Spreads destination — the left pane of `SpreadsTabView`.
///
/// A fixed top area stacks the context button strip over a horizontally scrolling year
/// strip of `SpreadButton`s (`selectedYear` is owned by the caller so it survives pane
/// show/hide); below it a vertically scrolling `CalendarView` covers all months in
/// `selectedYear`. Day cells are styled solid yellow (today), solid blue (has a
/// day/multiday spread), or plain. Multiday spreads render as continuous low-opacity
/// accent bands behind the covered cells. Month headers are `SpreadCardStyle` chips
/// showing created status, with a "View month" button navigating to existing month
/// spreads (SPRD-295); year spreads remain non-navigable from this view. Tapping a date
/// navigates directly when exactly one spread (day or multiday) covers it; when several
/// cover it, a coordinator-driven popover anchored on the cell (small detent sheet on
/// compact) lets the user choose. Tapping an uncovered date is a no-op.
struct SpreadsNavigatorView: View {

    /// Pre-built `CalendarGenerator.Model` keyed by year, injected by `SpreadsTabView`.
    /// The navigator does no per-render iteration — it looks up the model for `selectedYear`
    /// and passes it directly to `CalendarGenerator`.
    let calendarModels: [Int: CalendarGenerator.Model]

    /// Pre-built, deduped `.day`/`.multiday` spreads keyed by year, injected by `SpreadsTabView`
    /// alongside `calendarModels` (same lifecycle, same build pass). Looked up directly for
    /// `selectedYear` rather than derived by flat-mapping and deduping `calendarModels` on every
    /// render.
    let yearSpreads: [Int: [DataModel.Spread]]

    /// The calendar year displayed. Owned by the caller so it persists across pane
    /// show/hide and size class transitions; this view supplies the picker UI.
    @Binding var selectedYear: Int

    /// Bound to the shared spread selection that drives the detail pager.
    @Binding var selectedSpread: DataModel.Spread?

    /// Presents the day-tap disambiguation popover (`activePopover`), per the app's
    /// coordinator-driven popover convention. Navigation itself still flows through
    /// `selectedSpread` so the pager binding remains the single selection path.
    let coordinator: SpreadsCoordinator

    let today: Date
    let calendar: Calendar

    /// Pre-built button view models for the top inset control strip, injected by `SpreadsTabView`.
    /// Selection style (`.tonal` vs `.plain`) and navigation actions are computed by the parent.
    let topInsetButtons: [SpreadButton.ViewModel]

    /// Explicit month spreads keyed by year, then normalized month start date. Pre-built by
    /// `SpreadsTabView` in the same pass as `calendarModels`; drives the card-style month
    /// headers and their "View month" buttons.
    let monthSpreads: [Int: [Date: DataModel.Spread]]

    /// Explicit year spreads keyed by year — drives the "View year" chip above January.
    let explicitYearSpreads: [Int: DataModel.Spread]

    /// Pre-built disambiguation rows (year → date → options) for dates covered by 2+
    /// spreads. Built by `SpreadsTabView` so day taps do no label/formatter work.
    let dayDisambiguationOptions: [Int: [Date: [NavigatorDaySelectionPopoverContent.Option]]]

    // MARK: - Derived from Model

    /// Unique spreads for the selected year, used by `RowOverlayGenerator` to draw multiday
    /// span bars. A direct lookup into `yearSpreads` (pre-built and deduped by `SpreadsTabView`)
    /// rather than a per-render flat-map/dedup walk over `calendarModels`.
    private var selectedYearSpreads: [DataModel.Spread] {
        yearSpreads[selectedYear] ?? []
    }

    // MARK: - Year Date Range

    private var selectedYearStartDate: Date {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = 1
        comps.day = 1
        return calendar.date(from: comps) ?? today
    }

    private var selectedYearEndDate: Date {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = 12
        comps.day = 31
        return calendar.date(from: comps) ?? today
    }
    
    /// All calendar years that have at least one spread, plus the current year,
    /// in ascending (chronological) order for the horizontal year strip.
    private var availableYears: [Int] {
        let currentYear = calendar.component(.year, from: today)
        return Array(Set(calendarModels.keys).union([currentYear])).sorted()
    }

    var body: some View {
        CalendarView(
            startDate: selectedYearStartDate,
            endDate: selectedYearEndDate,
            calendar: calendar,
            today: today,
            configuration: .init(showsPeripheralDates: false),
            contentGenerator: CalendarGenerator(
                model: calendarModels[selectedYear] ?? CalendarGenerator.Model(),
                monthSpreads: monthSpreads[selectedYear] ?? [:],
                yearSpread: explicitYearSpreads[selectedYear],
                calendar: calendar,
                today: today,
                onViewSpread: navigate(to:)
            ),
            rowOverlayGenerator: RowOverlayGenerator(
                spreads: selectedYearSpreads,
                calendar: calendar
            ),
            initialScrollTarget: today,
            onDateTapped: handleDateTap
        )
        .overlayPreferenceValue(DateCellAnchorKey.self) { anchors in
            daySelectionPopoverHost(anchors: anchors)
        }
        // Day-cell chips carry their own 2pt inset, so 6pt of calendar padding lands their
        // visible edge on the same 8pt margin as the top controls and month header chips.
        .padding(.horizontal, SpreadTheme.Spacing.medium - 2)
        .safeAreaInset(edge: .top, spacing: 0) {
            topInsetControls
        }
    }

    // MARK: - Top Inset Controls

    /// Fixed (non-scrolling) top area: the context button strip over the year strip, on a
    /// material backdrop so the strips stay legible while calendar content scrolls beneath.
    private var topInsetControls: some View {
        VStack(alignment: .leading, spacing: SpreadTheme.Spacing.medium) {
            if !topInsetButtons.isEmpty {
                HStack(alignment: .top, spacing: SpreadTheme.Spacing.small) {
                    ForEach(topInsetButtons) { viewModel in
                        SpreadButton(viewModel)
                    }
                }
                .padding(.horizontal, SpreadTheme.Spacing.medium)
            }

            yearStrip
        }
        .padding(.vertical, SpreadTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
    }

    /// Horizontally scrolling year selector — one small `SpreadButton` per available year,
    /// `.tonal` for the selected year. Auto-scrolls to the selection on appear.
    private var yearStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpreadTheme.Spacing.small) {
                    ForEach(availableYears, id: \.self) { year in
                        SpreadButton(
                            String(year),
                            style: year == selectedYear ? .tonal : .plain,
                            size: .small
                        ) {
                            selectedYear = year
                        }
                        .id(year)
                    }
                }
                .padding(.horizontal, SpreadTheme.Spacing.medium)
            }
            .onAppear {
                proxy.scrollTo(selectedYear, anchor: .center)
            }
        }
    }

    // MARK: - Date Tap Handling

    /// Navigates directly when exactly one spread covers the tapped date (day or multiday);
    /// with several covering spreads, presents the pre-built disambiguation popover on the
    /// tapped cell. No labels or formatters are computed here.
    private func handleDateTap(_ date: Date) {
        let dayStart = date.startOfDay(calendar: calendar)

        if let options = dayDisambiguationOptions[selectedYear]?[dayStart] {
            coordinator.showNavigatorDaySelection(NavigatorDaySelectionPopoverContent(
                date: dayStart,
                options: options,
                onSelect: { navigate(to: $0) }
            ))
            return
        }

        guard let spread = calendarModels[selectedYear]?[dayStart]?.first else { return }
        navigate(to: spread)
    }

    /// Invisible, permanently-mounted anchor hosting the disambiguation popover — a popover
    /// with its arrow on the tapped day cell (regular width) or a small detent sheet
    /// (compact). Kept mounted so presentation animates immediately from the correct anchor
    /// instead of waiting for a conditional view insertion.
    private func daySelectionPopoverHost(anchors: [Date: Anchor<CGRect>]) -> some View {
        GeometryReader { proxy in
            let rect: CGRect = {
                if case .navigatorDaySelection(let content) = coordinator.activePopover,
                   let anchor = anchors[content.date] {
                    return proxy[anchor]
                }
                return CGRect(x: 0, y: 0, width: 1, height: 1)
            }()

            Color.clear
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .popover(
                    item: Binding<NavigatorDaySelectionPopoverContent?>(
                        get: {
                            guard case .navigatorDaySelection(let c) = coordinator.activePopover else { return nil }
                            return c
                        },
                        set: { if $0 == nil { coordinator.dismissPopover() } }
                    ),
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .top
                ) { presented in
                    presented.body
                        .presentationDetents([.height(220)])
                }
        }
        .allowsHitTesting(false)
    }

    private func navigate(to spread: DataModel.Spread) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedSpread = spread
        }
    }
}
