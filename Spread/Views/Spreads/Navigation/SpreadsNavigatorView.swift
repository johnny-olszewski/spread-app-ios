import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// Content column view for the Spreads destination — the left pane of `SpreadsTabView`.
///
/// Renders a vertically scrolling `CalendarView` covering all months in `selectedYear`,
/// with a self-contained year-selection control presented as a bottom-inset overlay
/// (no longer dependent on sidebar `.spreadsYear` subitems — `selectedYear` is owned by
/// the caller and bound here purely so the value survives pane show/hide). Day cells are
/// styled solid yellow (today),
/// solid blue (has a day/multiday spread), or plain (no relevant spread). Multiday spreads
/// also render a continuous bar overlay across week rows. Month and year spreads are
/// intentionally excluded from all visual state and tap handling — the user cannot navigate
/// to them directly from this view. Tapping a date navigates immediately to its day spread
/// if one exists; tapping a date with no day spread is a no-op.
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

    let today: Date
    let calendar: Calendar

    /// Pre-built button view models for the top inset control strip, injected by `SpreadsTabView`.
    /// Selection style (`.tonal` vs `.plain`) and navigation actions are computed by the parent.
    let topInsetButtons: [SpreadButton.ViewModel]

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
                calendar: calendar,
                today: today
            ),
            rowOverlayGenerator: RowOverlayGenerator(
                spreads: selectedYearSpreads,
                calendar: calendar
            ),
            initialScrollTarget: today,
            onDateTapped: handleDateTap
        )
        .safeAreaInset(edge: .top) {
            topInsetControls
        }
    }

    // MARK: - Top Inset Controls

    /// Fixed (non-scrolling) top area: the context button strip over the year strip.
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

    private func handleDateTap(_ date: Date) {
        let dayStart = date.startOfDay(calendar: calendar)
        guard let spread = calendarModels[selectedYear]?[dayStart]?.first(where: { $0.period == .day }) else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedSpread = spread
        }
    }
}
