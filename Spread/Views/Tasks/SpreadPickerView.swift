import SwiftUI

/// A view for selecting an assignment destination for a task or note.
///
/// The picker exposes:
/// - implicit or explicit year/month/day destinations for the current focus date
/// - existing multiday spreads only for direct multiday assignment
/// - a path back to the form's manual date controls
struct SpreadPickerView: View {

    @Environment(\.dismiss) private var dismiss

    let spreads: [DataModel.Spread]
    let calendar: Calendar
    let today: Date
    let focusDate: Date
    let onSpreadSelected: (SpreadPickerSelection) -> Void
    let onChooseCustomDate: () -> Void

    private var configuration: SpreadPickerConfiguration {
        SpreadPickerConfiguration(
            spreads: spreads,
            calendar: calendar,
            today: today
        )
    }

    private var directOptions: [SpreadPickerOption] {
        configuration.directDestinationOptions(for: focusDate)
    }

    private var multidayOptions: [SpreadPickerOption] {
        configuration.multidayOptions()
    }

    var body: some View {
        NavigationStack {
            List {
                focusDateSection
                customDateRow

                Section("Direct Destinations") {
                    ForEach(directOptions) { option in
                        destinationRow(for: option)
                    }
                }

                if !multidayOptions.isEmpty {
                    Section("Existing Multiday Spreads") {
                        ForEach(multidayOptions) { option in
                            destinationRow(for: option)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Spread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var focusDateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assignment date context")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formattedFocusDate)
                    .font(.body.weight(.semibold))
            }
            .padding(.vertical, 2)
        }
    }

    private var customDateRow: some View {
        Button {
            onChooseCustomDate()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose another date")
                    Text("Use the form controls for a different year, month, or day destination")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadPicker.chooseCustomDate)
    }

    private func destinationRow(for option: SpreadPickerOption) -> some View {
        Button {
            onSpreadSelected(option.selection)
            dismiss()
        } label: {
            HStack {
                periodIcon(for: option.period)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(option.availability == .existing ? .secondary : .tertiary)
                }
                Spacer()
            }
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier(accessibilityIdentifier(for: option))
    }

    private func accessibilityIdentifier(for option: SpreadPickerOption) -> String {
        if option.period == .multiday, let spreadID = option.selection.spreadID {
            return Definitions.AccessibilityIdentifiers.SpreadPicker.multidayRow(spreadID.uuidString)
        }

        return Definitions.AccessibilityIdentifiers.SpreadPicker.spreadRow(option.id)
    }

    private func periodIcon(for period: Period) -> some View {
        let systemName: String
        switch period {
        case .year:
            systemName = "calendar"
        case .month:
            systemName = "calendar.badge.clock"
        case .day:
            systemName = "sun.max"
        case .multiday:
            systemName = "calendar.day.timeline.left"
        }

        return Image(systemName: systemName)
            .foregroundStyle(.accent)
            .frame(width: 24)
    }

    private var formattedFocusDate: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long
        return formatter.string(from: focusDate)
    }
}

#Preview("With Spreads") {
    let calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }()
    let today = Date()

    let spreads = [
        DataModel.Spread(period: .year, date: today, calendar: calendar),
        DataModel.Spread(period: .month, date: today, calendar: calendar),
        DataModel.Spread(period: .day, date: today, calendar: calendar),
        DataModel.Spread(
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 6, to: today)!,
            calendar: calendar
        )
    ]

    return SpreadPickerView(
        spreads: spreads,
        calendar: calendar,
        today: today,
        focusDate: today,
        onSpreadSelected: { selection in
            print("Selected: \(selection.period.displayName) - \(selection.date)")
        },
        onChooseCustomDate: {
            print("Choose custom date")
        }
    )
}

