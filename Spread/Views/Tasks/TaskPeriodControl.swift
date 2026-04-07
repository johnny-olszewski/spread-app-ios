import SwiftUI

struct TaskPeriodControl: View {

    let selection: Binding<Period>
    let pickerIdentifier: String
    let segmentIdentifier: (Period) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TaskCreationConfiguration.assignablePeriods, id: \.self) { period in
                Button {
                    selection.wrappedValue = period
                } label: {
                    Text(period.displayName)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .foregroundStyle(isSelected(period) ? Color.white : Color.primary)
                .background {
                    if isSelected(period) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(period.displayName)
                .accessibilityValue(isSelected(period) ? "Selected" : "")
                .accessibilityIdentifier(segmentIdentifier(period))
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill))
        )
        .accessibilityIdentifier(pickerIdentifier)
    }

    private func isSelected(_ period: Period) -> Bool {
        selection.wrappedValue == period
    }
}
