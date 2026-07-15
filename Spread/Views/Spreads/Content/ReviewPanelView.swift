import SwiftUI

/// The pull-down review surface revealed when the pager slides down: a segmented control
/// choosing between the Inbox, In Flight, and Overdue collections, with the selected
/// collection rendered as a `TaskReviewCardView` beneath it.
///
/// Segment selection is session-scoped `@State`: the panel lives (opacity-hidden) in the
/// pager shell for the whole session, so the last-viewed segment survives panel close/open
/// and spread switches, but is not persisted across launches.
struct ReviewPanelView: View {

    let context: SpreadPageContext

    @State private var selectedCollection: TaskReviewCollection = .inbox

    var body: some View {
        VStack(spacing: SpreadTheme.Spacing.medium) {
            HStack {
                Spacer(minLength: 0)
                EntrySheetChoiceRow(
                    options: TaskReviewCollection.allCases.map { collection in
                        .init(
                            value: collection,
                            title: collection.segmentTitle(in: context.journalManager),
                            icon: collection.icon
                        )
                    },
                    selection: selectedCollection,
                    onSelect: { collection in
                        withAnimation(SpreadTheme.Motion.spring) { selectedCollection = collection }
                    }
                )
                Spacer(minLength: 0)
            }

            TaskReviewCardView(context: context, collection: selectedCollection)
                // Fresh identity per segment so one collection's 5-second grace-period rows
                // can't bleed into another's card when the user switches segments mid-grace.
                // The id swap animates as a cross-fade because selection changes inside
                // `withAnimation` above.
                .id(selectedCollection)
                .transition(.opacity)
        }
    }
}
