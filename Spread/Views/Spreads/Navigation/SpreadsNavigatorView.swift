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

    /// The calendar year displayed. Owned by the caller so it persists across pane
    /// show/hide and size class transitions; this view supplies the picker UI.
    @Binding var selectedYear: Int

    /// Bound to the shared spread selection that drives the detail pager.
    @Binding var selectedSpread: DataModel.Spread?

    let today: Date
    let calendar: Calendar

    // MARK: - Derived from Model

    /// Unique spreads for the selected year, used by `RowOverlayGenerator` to draw
    /// multiday span bars. Extracted from the model rather than from a raw spreads array.
    private var selectedYearSpreads: [DataModel.Spread] {
        guard let model = calendarModels[selectedYear] else { return [] }
        var seen = Set<UUID>()
        return model.values.flatMap { $0 }.filter { seen.insert($0.id).inserted }
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
                        Label("\(year)", systemImage: "checkmark")
                    } else {
                        Text("\(year)")
                    }
                }
            }
        } label: {
            Label("\(selectedYear)", systemImage: "chevron.up.chevron.down")
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
        .overlay(alignment: .bottom) {
            bottomInsetControls
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
