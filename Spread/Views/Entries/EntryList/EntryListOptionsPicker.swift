import SwiftUI

/// A single Menu-style control exposing both group-by (`EntryGroupingOption`) and
/// order-by (`EntrySortOption`) selection, reusable by any spread.
///
/// Takes the current selection as plain values and reports new selections via injected
/// closures rather than `@Binding`, so callers aren't required to back the selection with
/// a literal binding (e.g. `@AppStorage` callers can persist however they choose).
struct EntryListOptionsPicker: View {

    // MARK: - Properties

    let grouping: EntryGroupingOption
    let sorting: EntrySortOption
    var config: Config = .default

    let onGroupingSelected: (EntryGroupingOption) -> Void
    let onSortingSelected: (EntrySortOption) -> Void

    // MARK: - Body

    var body: some View {
        // Each option group is its own titled submenu ("Group By"/"Order By" are the
        // submenu's own label, shown as a row in the top-level menu), with one Button per
        // option rather than a Picker — lets the current selection be a plain value instead
        // of requiring a Binding, with the checkmark drawn explicitly per selected option.
        Menu {
            Menu("Group By") {
                ForEach(EntryGroupingOption.allCases) { option in
                    Button {
                        onGroupingSelected(option)
                    } label: {
                        optionLabel(option.displayName, isSelected: option == grouping)
                    }
                }
            }
            Menu("Order By") {
                ForEach(EntrySortOption.allCases) { option in
                    Button {
                        onSortingSelected(option)
                    } label: {
                        optionLabel(option.displayName, isSelected: option == sorting)
                    }
                }
            }
        } label: {
            config.icon.sized(SpreadTheme.IconSize.medium)
                .iconTint(.primary)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(config.accessibilityLabel)
    }

    @ViewBuilder
    private func optionLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label {
                Text(title)
            } icon: {
                SpreadTheme.Icon.checkmark.sized(SpreadTheme.IconSize.small)
            }
        } else {
            Text(title)
        }
    }
}

// MARK: - Config

extension EntryListOptionsPicker {

    /// Visual configuration for `EntryListOptionsPicker`, letting callers customize its
    /// icon/label without changing the menu's structure.
    struct Config {
        let icon: SpreadTheme.Icon
        let accessibilityLabel: String

        init(
            icon: SpreadTheme.Icon = .funnel,
            accessibilityLabel: String = "Group and Sort Options"
        ) {
            self.icon = icon
            self.accessibilityLabel = accessibilityLabel
        }

        static let `default` = Config()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var grouping: EntryGroupingOption = .list
    @Previewable @State var sorting: EntrySortOption = .default
    EntryListOptionsPicker(
        grouping: grouping,
        sorting: sorting,
        onGroupingSelected: { grouping = $0 },
        onSortingSelected: { sorting = $0 }
    )
}
