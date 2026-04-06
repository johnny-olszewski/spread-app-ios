import SwiftUI

struct InlineTaskMigrationSection: View {
    let items: [EntryListMigrationConfiguration.DestinationItem]
    let calendar: Calendar
    var onMigrate: (EntryListMigrationConfiguration.DestinationItem) -> Void
    var onMigrateAll: () -> Void

    @State private var isExpanded = false

    var body: some View {
        if !items.isEmpty {
            Section {
                if isExpanded {
                    ForEach(items) { item in
                        migrationRow(item)
                    }
                }
            } header: {
                header
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.secondary)

                    Text("Migrate tasks")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    if items.count > 0 {
                        Text("(\(items.count))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader)

            Spacer()

            Button("Migrate All", action: onMigrateAll)
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Migration.destinationMigrateAllButton)
        }
    }

    private func migrationRow(_ item: EntryListMigrationConfiguration.DestinationItem) -> some View {
        EntryRowView(
            task: item.task,
            contextualLabel: sourceTitle(for: item.source)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onMigrate(item)
        }
        .listRowInsets(
            EdgeInsets(
                top: SpreadTheme.Spacing.entryRowVertical,
                leading: 16,
                bottom: SpreadTheme.Spacing.entryRowVertical,
                trailing: 16
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Migration.destinationRow(item.task.title))
    }

    private func sourceTitle(for spread: DataModel.Spread) -> String {
        SpreadHeaderConfiguration(
            spread: spread,
            calendar: calendar
        ).title
    }
}
