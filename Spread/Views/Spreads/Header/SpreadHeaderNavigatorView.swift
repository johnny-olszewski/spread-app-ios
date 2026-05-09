import SwiftUI

struct SpreadHeaderNavigatorPopoverView: View {
    let model: SpreadHeaderNavigatorModel
    let currentSpread: DataModel.Spread
    let recommendations: [SpreadTitleNavigatorRecommendation]
    let onSelect: (SpreadHeaderNavigatorModel.Selection) -> Void
    let onRecommendationTapped: ((SpreadTitleNavigatorRecommendation) -> Void)?
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
            .safeAreaInset(edge: .bottom) {
                if !recommendations.isEmpty {
                    recommendationsSection
                }
            }
            .frame(minWidth: 360, idealWidth: 420, maxWidth: 480, minHeight: 420, idealHeight: 560, maxHeight: 680)
            .background(SpreadTheme.Paper.primary)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadNavigator.popover)
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested today")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recommendations) { recommendation in
                        Button {
                            onRecommendationTapped?(recommendation)
                            onDismiss()
                        } label: {
                            Text(recommendation.fullTitle)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glowingShimmer(cornerRadius: 10, speed: 2.4, borderWidth: 2.2, blurRadius: 3.5)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.SpreadStrip.recommendation(
                                recommendation.period.rawValue
                            )
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        .background(.bar)
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
