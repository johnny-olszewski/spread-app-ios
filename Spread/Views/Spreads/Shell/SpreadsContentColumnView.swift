import SwiftUI
import JohnnyOFoundationUI
import JohnnyOFoundationCore

/// Content column view for the Spreads destination in the NavigationSplitView.
///
/// Renders a vertically scrolling `CalendarView` covering all months in `selectedYear`.
/// Day cells are styled solid yellow (today), solid blue (has a day/multiday spread), or
/// plain (no relevant spread). Multiday spreads also render a continuous bar overlay across
/// week rows. Month and year spreads are intentionally excluded from all visual state and
/// tap handling — the user cannot navigate to them directly from this view. Tapping a date
/// with a single day/multiday spread navigates immediately; tapping a date with multiple
/// spreads presents a disambiguation popover.
struct SpreadsContentColumnView: View {

    let spreads: [DataModel.Spread]
    let selectedYear: Int
    let today: Date
    let calendar: Calendar

    /// Bound to the root-level column selection that drives NavigationSplitView navigation.
    @Binding var selectedSpread: DataModel.Spread?

    @State private var disambiguationContext: DisambiguationContext?

    var body: some View {
        CalendarView(
            startDate: yearStart,
            endDate: yearEnd,
            calendar: calendar,
            today: today,
            contentGenerator: CalendarGenerator(
                spreads: spreads,
                calendar: calendar
            ),
            rowOverlayGenerator: RowOverlayGenerator(
                spreads: spreads,
                calendar: calendar
            ),
            initialScrollTarget: today,
            onDateTapped: handleDateTap
        )
        .listStyle(.sidebar)
        .navigationTitle("Spreads")
        .popover(item: $disambiguationContext) { context in
            disambiguationPopover(for: context)
        }
    }

    // MARK: - Year Date Range

    private var yearStart: Date {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = 1
        comps.day = 1
        return calendar.date(from: comps) ?? today
    }

    private var yearEnd: Date {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = 12
        comps.day = 31
        return calendar.date(from: comps) ?? today
    }

    // MARK: - Date Tap Handling

    private func handleDateTap(_ date: Date) {
        let matches = spreads.filter {
            ($0.period == .day || $0.period == .multiday) &&
            $0.contains(date: date, calendar: calendar)
        }
        switch matches.count {
        case 0:
            break
        case 1:
            selectedSpread = matches[0]
        default:
            disambiguationContext = DisambiguationContext(date: date, spreads: matches)
        }
    }

    // MARK: - Disambiguation Popover

    @ViewBuilder
    private func disambiguationPopover(for context: DisambiguationContext) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(context.formattedDate(calendar: calendar))
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ForEach(context.spreads) { spread in
                Button {
                    // Dismiss the popover first, then write the selection on the next
                    // run loop so the binding update isn't dropped during teardown.
                    disambiguationContext = nil
                    let target = spread
                    DispatchQueue.main.async {
                        selectedSpread = target
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spread.displayLabel(calendar: calendar))
                            .font(.body)
                        Text(spread.period.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if spread.id != context.spreads.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .presentationCompactAdaptation(.popover)
        .frame(minWidth: 240)
    }
}

// MARK: - Disambiguation Context

private struct DisambiguationContext: Identifiable {
    let id = UUID()
    let date: Date
    let spreads: [DataModel.Spread]

    func formattedDate(calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Spreads content column") {
    let journalManager = JournalManager.previewInstance
    let today = journalManager.today
    let calendar = journalManager.calendar
    let year = calendar.component(.year, from: today)

    NavigationSplitView {
        Text("Sidebar")
    } content: {
        SpreadsContentColumnView(
            spreads: journalManager.spreads,
            selectedYear: year,
            today: today,
            calendar: calendar,
            selectedSpread: .constant(nil)
        )
    } detail: {
        Text("Detail")
    }
}
