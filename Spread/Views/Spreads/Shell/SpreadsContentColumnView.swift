import SwiftUI

/// Content column view for the Spreads destination in the NavigationSplitView.
///
/// Renders the spread picker list for the currently selected year. Each row's
/// `.tag` value drives the `NavigationSplitView` detail column selection — on
/// compact this produces a push to the detail; on regular it updates the
/// highlighted row and the detail column renders the chosen spread.
struct SpreadsContentColumnView: View {

    let items: [SpreadPickerModel.Item]

    /// Bound to the root-level column selection that drives NavigationSplitView
    /// navigation and bidirectional sync with the spread pager.
    @Binding var selectedSpread: DataModel.Spread?

    var body: some View {
        List(selection: $selectedSpread) {
            ForEach(items) { item in
                SpreadNavigatorRowView(item: item)
                    .tag(item.selection as DataModel.Spread?)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Spreads")
    }
}

// MARK: - Row

private struct SpreadNavigatorRowView: View {

    let item: SpreadPickerModel.Item

    var body: some View {
        HStack(spacing: 8) {
            indentSpacer
            VStack(alignment: .leading, spacing: 1) {
                Text(item.label)
                    .font(rowFont)
                    .lineLimit(1)
                if let top = item.display.top {
                    Text(top)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            badgeView
        }
    }

    @ViewBuilder
    private var indentSpacer: some View {
        switch item.style {
        case .year:
            EmptyView()
        case .month:
            Spacer().frame(width: 12)
        case .day, .multiday:
            Spacer().frame(width: 24)
        }
    }

    private var rowFont: Font {
        switch item.style {
        case .year: return .headline
        case .month: return .body
        case .day, .multiday: return .subheadline
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        switch item.badge {
        case .overdue(let count):
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red, in: Capsule())
        case .favorite:
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
        case nil:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Spreads content column") {
    let journalManager = JournalManager.previewInstance
    let model = journalManager.titleNavigatorModel
    let currentSelection = journalManager.defaultNavigationSelection
    let items = model.items(for: currentSelection)

    NavigationSplitView {
        Text("Sidebar")
    } content: {
        SpreadsContentColumnView(
            items: items,
            selectedSpread: .constant(currentSelection)
        )
    } detail: {
        Text("Detail")
    }
}
