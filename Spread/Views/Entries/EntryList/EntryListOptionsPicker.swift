import SwiftUI

/// A single Menu-style control exposing both group-by (`EntryGroupingOption`) and
/// order-by (`EntrySortOption`) selection, reusable by any spread.
struct EntryListOptionsPicker: View {

    // MARK: - Properties

    @Binding var grouping: EntryGroupingOption
    @Binding var sorting: EntrySortOption

    // MARK: - Body

    var body: some View {
        Menu {
            Picker("Group By", selection: $grouping) {
                ForEach(EntryGroupingOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            Picker("Order By", selection: $sorting) {
                ForEach(EntrySortOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var grouping: EntryGroupingOption = .list
    @Previewable @State var sorting: EntrySortOption = .manual
    EntryListOptionsPicker(grouping: $grouping, sorting: $sorting)
}
