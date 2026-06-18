import SwiftUI

/// A `SpreadButton` that owns the quick-add popover binding.
///
/// Encapsulates the pattern of tapping a button to trigger the quick-add task popover,
/// including the `.popover` modifier and the discriminated `Binding` that ensures only this
/// specific button presents the popover — even when multiple `QuickAddButton` instances
/// share the same `date` and `period` on screen simultaneously.
///
/// Pass `content` to customise the button label. All other quick-add parameters are
/// forwarded to `SpreadsCoordinator.showQuickAdd`.
struct QuickAddButton: View {

    let coordinator: SpreadsCoordinator

    /// Uniquely identifies this button among others on screen.
    ///
    /// Used to discriminate the popover binding so only the button that was tapped
    /// presents the popover. Pass a stable, per-instance value — e.g. a section `id`.
    let anchorID: String

    let date: Date
    let period: Period
    let availableLists: [DataModel.List]
    let availableTags: [DataModel.Tag]
    /// List pre-selected when the popover opens. `nil` leaves the picker blank.
    let preselectedList: DataModel.List?
    let onAddTask: @MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void

    var content: SpreadButton.Content
    var accessibilityIdentifier: String?
    var arrowEdge: Edge

    init(
        coordinator: SpreadsCoordinator,
        anchorID: String,
        date: Date,
        period: Period,
        content: SpreadButton.Content = .text("+ Add Task"),
        availableLists: [DataModel.List] = [],
        availableTags: [DataModel.Tag] = [],
        preselectedList: DataModel.List? = nil,
        accessibilityIdentifier: String? = nil,
        arrowEdge: Edge = .top,
        onAddTask: @escaping @MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void
    ) {
        self.coordinator = coordinator
        self.anchorID = anchorID
        self.date = date
        self.period = period
        self.content = content
        self.availableLists = availableLists
        self.availableTags = availableTags
        self.preselectedList = preselectedList
        self.accessibilityIdentifier = accessibilityIdentifier
        self.arrowEdge = arrowEdge
        self.onAddTask = onAddTask
    }

    var body: some View {
        SpreadButton(viewModel: .init(
            title: "Add Task",
            content: content,
            accessibilityIdentifier: accessibilityIdentifier
        ) {
            coordinator.showQuickAdd(
                anchorID: anchorID,
                date: date,
                period: period,
                availableLists: availableLists,
                availableTags: availableTags,
                preselectedList: preselectedList,
                onAddTask: onAddTask
            )
        })
        .popover(
            item: Binding<QuickAddPopoverContent?>(
                get: {
                    guard case .quickAdd(let c) = coordinator.activePopover,
                          c.anchorID == anchorID
                    else { return nil }
                    return c
                },
                set: { if $0 == nil { coordinator.dismissPopover() } }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: arrowEdge
        ) { popoverContent in
            popoverContent.body
                .presentationDetents([.height(200)])
        }
    }
}
