import SwiftUI

struct SpreadTitleNavigatorView: View {
    let stripModel: SpreadTitleNavigatorModel
    let onRecommendedSpreadTapped: ((SpreadTitleNavigatorRecommendation) -> Void)?
    let recommendationProvider: any SpreadTitleNavigatorRecommendationProviding
    @Binding var selection: SpreadHeaderNavigatorModel.Selection

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingNavigator = false

    private var barLabel: SpreadCompactBarLabel {
        stripModel.compactBarLabel(for: selection)
    }

    private var recommendations: [SpreadTitleNavigatorRecommendation] {
        recommendationProvider.recommendations(for: stripModel.headerModel)
    }

    private var currentNavigatorSpread: DataModel.Spread {
        switch selection {
        case .conventional(let spread):
            return spread
        case .traditionalYear(let date):
            return DataModel.Spread(period: .year, date: date, calendar: stripModel.calendar)
        case .traditionalMonth(let date):
            return DataModel.Spread(period: .month, date: date, calendar: stripModel.calendar)
        case .traditionalDay(let date):
            return DataModel.Spread(period: .day, date: date, calendar: stripModel.calendar)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            titleButton
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.container)
        .spreadNavigatorPresentation(
            isPresented: $isShowingNavigator,
            presentsAsPopover: SpreadNavigatorPresentationSupport.presentsAsPopover(
                horizontalSizeClass: horizontalSizeClass
            ),
            model: stripModel.headerModel,
            currentSpread: currentNavigatorSpread,
            recommendations: recommendations,
            onSelect: { selection = $0 },
            onRecommendationTapped: onRecommendedSpreadTapped
        )
    }

    private var titleButton: some View {
        Button {
            isShowingNavigator = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(barLabel.primary)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let secondary = barLabel.secondary {
                    Text(secondary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            barLabel.secondary.map { "\(barLabel.primary), \($0)" } ?? barLabel.primary
        )
        .accessibilityHint("Opens spread navigator")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator)
    }
}

#Preview {
    let journalManager = JournalManager.previewInstance
    SpreadTitleNavigatorView(
        stripModel: journalManager.titleNavigatorModel,
        onRecommendedSpreadTapped: nil,
        recommendationProvider: TodayMissingSpreadRecommendationProvider(),
        selection: .constant(.conventional(
            DataModel.Spread(period: .day, date: .now, calendar: .current)
        ))
    )
}
