import SwiftUI

struct SpreadHeaderNavigatorPopoverView: View {
    let model: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onDismiss: () -> Void

    @State private var settledYear: Int?
    @State private var visibleYear: Int?
    @State private var expandedMonthsByYear: [Int: Date] = [:]

    private var yearPages: [SpreadHeaderNavigatorModel.YearPage] {
        model.yearPages()
    }

    private var initialYear: Int {
        model.initialYear(for: currentSpread)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(yearPages) { page in
                        SpreadHeaderNavigatorYearPageView(
                            page: page,
                            model: model,
                            currentSpread: currentSpread,
                            expandedMonth: expandedMonthBinding(for: page.year),
                            onSelect: onSelect,
                            onDismiss: onDismiss
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(page.year)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $visibleYear)
            .onAppear {
                visibleYear = initialYear
                settledYear = initialYear

                if let initialExpandedMonth = model.initialExpandedMonth(for: currentSpread) {
                    expandedMonthsByYear[initialYear] = initialExpandedMonth
                }
            }
            .onScrollPhaseChange { _, newPhase in
                guard newPhase == .idle, let visibleYear else { return }
                settledYear = visibleYear
            }
            .navigationTitle(String(settledYear ?? initialYear))
            .navigationBarTitleDisplayMode(.inline)
            .frame(minWidth: 360, idealWidth: 420, maxWidth: 480, minHeight: 420, idealHeight: 560, maxHeight: 680)
            .background(SpreadTheme.Paper.primary)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNavigator.popover)
        }
    }

    private func expandedMonthBinding(for year: Int) -> Binding<Date?> {
        Binding(
            get: { expandedMonthsByYear[year] },
            set: { newValue in
                expandedMonthsByYear[year] = newValue
            }
        )
    }
}
