import SwiftUI

struct EntryLeadingIconButton: View {

    struct Configuration {
        var entryType: EntryType
        var taskStatus: DataModel.Task.Status?
        var noteStatus: DataModel.Note.Status?
        var color: Color
        var isDisabled: Bool
    }

    let configuration: Configuration

    var body: some View {
        StatusIcon(
            configuration: StatusIconConfiguration(
                entryType: configuration.entryType,
                taskStatus: configuration.taskStatus,
                noteStatus: configuration.noteStatus
            ),
            color: configuration.color
        )
        .frame(width: 24, height: 24)
    }
}

#Preview {
    VStack(spacing: 12) {
        EntryLeadingIconButton(
            configuration: EntryLeadingIconButton.Configuration(
                entryType: .task,
                taskStatus: .open,
                color: .primary,
                isDisabled: false
            )
        )
        EntryLeadingIconButton(
            configuration: EntryLeadingIconButton.Configuration(
                entryType: .task,
                taskStatus: .complete,
                color: .green,
                isDisabled: false
            )
        )
        EntryLeadingIconButton(
            configuration: EntryLeadingIconButton.Configuration(
                entryType: .task,
                taskStatus: .migrated,
                color: .secondary,
                isDisabled: true
            )
        )
        EntryLeadingIconButton(
            configuration: EntryLeadingIconButton.Configuration(
                entryType: .event,
                color: .blue,
                isDisabled: true
            )
        )
        EntryLeadingIconButton(
            configuration: EntryLeadingIconButton.Configuration(
                entryType: .note,
                color: .primary,
                isDisabled: true
            )
        )
    }
    .padding()
}
