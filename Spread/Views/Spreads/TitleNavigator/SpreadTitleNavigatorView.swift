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
            navigatorTrigger
            titleRegion
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .secondaryPaperBackground()
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

    private var navigatorTrigger: some View {
        Button {
            isShowingNavigator = true
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(minWidth: 32, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .accessibilityLabel("Open Spread Navigator")
        .accessibilityHint("Shows all spreads in the rooted navigator.")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.selectSpreadButton)
    }

    private var titleRegion: some View {
        Button {
            isShowingNavigator = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator)
        .accessibilityLabel(
            barLabel.secondary.map { "\(barLabel.primary), \($0)" } ?? barLabel.primary
        )
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
