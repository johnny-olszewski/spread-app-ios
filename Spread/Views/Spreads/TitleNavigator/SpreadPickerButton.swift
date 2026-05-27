import SwiftUI

/// Title-bar button that displays the current spread name and opens a spread picker on tap.
///
/// Reads the current selection and picker model from the environment and calls
/// `coordinator.navigate(to:)` when the user picks a new spread, so
/// convenience-navigation state is automatically cleared on user-driven selection changes.
struct SpreadPickerButton: View {
    @Environment(JournalManager.self) private var journalManager
    @Environment(SpreadsCoordinator.self) private var coordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingNavigator = false

    private let recommendationProvider: any SpreadPickerRecommendationProviding =
        TodayMissingSpreadCreationRecommendationProvider()

    private var pickerModel: SpreadPickerModel {
        journalManager.titleNavigatorModel
    }

    private var currentSelection: DataModel.Spread {
        coordinator.selectedSelection ?? journalManager.defaultNavigationSelection
    }

    private var barLabel: SpreadCompactBarLabel {
        pickerModel.compactBarLabel(for: currentSelection)
    }

    private var recommendations: [SpreadPickerRecommendation] {
        recommendationProvider.recommendations(for: pickerModel.headerModel)
    }

    var body: some View {
        HStack(spacing: 0) {
            titleButton
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.container)
        .spreadNavigatorPresentation(
            isPresented: $isShowingNavigator,
            presentsAsPopover: SpreadPickerPresentationSupport.presentsAsPopover(
                horizontalSizeClass: horizontalSizeClass
            ),
            model: pickerModel.headerModel,
            currentSpread: currentSelection,
            recommendations: recommendations,
            onSelect: { coordinator.navigate(to: $0) },
            onRecommendationTapped: { recommendation in
                coordinator.showSpreadCreation(
                    prefill: .init(period: recommendation.period, date: recommendation.date)
                )
            }
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
        .accessibilityHint("Opens spread picker")
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator)
    }
}

#Preview {
    let journalManager = JournalManager.previewInstance
    let coordinator = SpreadsCoordinator()
    SpreadPickerButton()
        .environment(journalManager)
        .environment(coordinator)
}
