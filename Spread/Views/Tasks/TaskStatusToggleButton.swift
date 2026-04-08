import SwiftUI

struct TaskStatusToggleButton: View {

    @Binding var status: DataModel.Task.Status
    let accessibilityIdentifier: String
    var size: Font.TextStyle = .caption
    var color: Color? = nil

    var body: some View {
        Button {
            status = status.toggledCompletionStatusInTaskSheet
        } label: {
            StatusIcon(
                configuration: StatusIconConfiguration(
                    entryType: .task,
                    taskStatus: status,
                    size: size
                ),
                color: color ?? status.statusIconColor
            )
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(!status.canToggleCompletionInTaskSheet)
        .accessibilityRepresentation {
            Button(accessibilityLabel) {}
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityValue(status.displayName)
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case .open:
            return "Mark task complete"
        case .complete:
            return "Mark task open"
        case .migrated:
            return "Migrated task"
        case .cancelled:
            return "Cancelled task"
        }
    }
}

#Preview {
    @Previewable @State var status: DataModel.Task.Status = .open

    return HStack {
        TaskStatusToggleButton(
            status: $status,
            accessibilityIdentifier: "preview.status"
        )
        Text("Preview task")
    }
    .padding()
}
