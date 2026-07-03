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

    /// Coordinator used by the context navigation buttons to navigate and recenter the pager.
    let coordinator: SpreadsCoordinator

    // MARK: - Today Context Spreads

    /// Today's year spread, pre-computed by the parent. Nil when no such spread exists.
    let todayYearSpread: DataModel.Spread?
    /// Today's month spread, pre-computed by the parent. Nil when no such spread exists.
    let todayMonthSpread: DataModel.Spread?
    /// The multiday spread containing today, pre-computed by the parent. Nil when none exists.
    let todayMultidaySpread: DataModel.Spread?
    /// Display label for `todayMultidaySpread` (custom name → dynamic → canonical date range).
    let todayMultidayLabel: String?
    /// Today's day spread, pre-computed by the parent. Nil when no such spread exists.
    let todayDaySpread: DataModel.Spread?

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
    
    // MARK: - Bottom Inset Controls

    /// Bottom-inset overlay hosting the year-selection control, mirroring the
    /// `bottomInsetControls` convention used elsewhere (e.g. `SpreadsTabView`).
    private var bottomInsetControls: some View {
        Picker(selection: $selectedYear) {
            ForEach(availableYears, id: \.self) { year in
                Button {
                    selectedYear = year
                } label: {
                    if year == selectedYear {
                        Label {
                            Text("\(year)")
                        } icon: {
                            SpreadTheme.Icon.checkmark.chromeImage(size: SpreadTheme.IconSize.small)
                        }
                    } else {
                        Text("\(year)")
                    }
                }
            }
        } label: {
            Label {
                Text("\(selectedYear)")
            } icon: {
                SpreadTheme.Icon.arrowsUpDown.chromeImage(size: SpreadTheme.IconSize.small)
            }
        }
        .pickerStyle(.menu)
        .padding(SpreadTheme.Spacing.medium)
        .glassEffect(.clear, in: Capsule())
    }

    /// All calendar years that have at least one spread, plus the current year,
    /// in descending order.
    private var availableYears: [Int] {
        let currentYear = calendar.component(.year, from: today)
        return Array(Set(calendarModels.keys).union([currentYear])).sorted(by: >)
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
        .overlay(alignment: .top) {
            topInsetControls
        }
        .overlay(alignment: .bottom) {
            bottomInsetControls
        }
    }

    // MARK: - Top Inset Controls

    @ViewBuilder
    private var topInsetControls: some View {
        let selectedPeriod = selectedSpread?.period
        let hasAny = todayYearSpread != nil || todayMonthSpread != nil || todayMultidaySpread != nil || todayDaySpread != nil
        if hasAny {
            HStack(spacing: SpreadTheme.Spacing.small) {
                if let spread = todayYearSpread {
                    SpreadButton("This year", style: selectedPeriod == .year ? .tonal : .plain, size: .small) {
                        coordinator.navigate(to: spread, shouldRecenter: true)
                    }
                }
                if let spread = todayMonthSpread {
                    SpreadButton("This Month", style: selectedPeriod == .month ? .tonal : .plain, size: .small) {
                        coordinator.navigate(to: spread, shouldRecenter: true)
                    }
                }
                if let spread = todayMultidaySpread {
                    SpreadButton(todayMultidayLabel ?? "Multiday", style: selectedPeriod == .multiday ? .tonal : .plain, size: .small) {
                        coordinator.navigate(to: spread, shouldRecenter: true)
                    }
                }
                if let spread = todayDaySpread {
                    SpreadButton("Today", style: selectedPeriod == .day ? .tonal : .plain, size: .small) {
                        coordinator.navigate(to: spread, shouldRecenter: true)
                    }
                }
            }
            .padding(SpreadTheme.Spacing.medium)
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
