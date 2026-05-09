import SwiftUI
import JohnnyOFoundationUI

/// A reusable icon component for displaying entry type and status.
///
/// Renders a custom-drawn SwiftUI icon based on entry type:
/// - Task: filled circle (●)
/// - Event: stroked circle (○)
/// - Note: dash (—)
///
/// For tasks, a decorator overlaid on the base indicates status:
/// - Open: base circle only
/// - Complete: X mark extending beyond the circle frame (animated draw-in)
/// - Migrated: right arrow extending beyond the circle (animated draw-in)
/// - Cancelled: diagonal slash through the circle (animated draw-in)
///
/// Example usage:
/// ```swift
/// StatusIcon(entryType: .task, taskStatus: .complete)
/// StatusIcon(entryType: .event)
/// StatusIcon(entryType: .note, size: .title, color: .secondary)
/// ```
struct StatusIcon: View {

    // MARK: - Properties

    /// The configuration for this status icon.
    private let configuration: StatusIconConfiguration

    /// The color for the icon.
    private let color: Color

    // MARK: - Initialization

    /// Creates a status icon from a configuration.
    ///
    /// - Parameters:
    ///   - configuration: The icon configuration.
    ///   - color: The icon color (defaults to primary).
    init(configuration: StatusIconConfiguration, color: Color = .primary) {
        self.configuration = configuration
        self.color = color
    }

    /// Creates a status icon for an entry type.
    ///
    /// - Parameters:
    ///   - entryType: The type of entry.
    ///   - taskStatus: The task status (only used for tasks).
    ///   - noteStatus: The note status (only used for notes).
    ///   - isEventPast: Whether the event is past (only used for events).
    ///   - size: The text style size (defaults to `.caption`).
    ///   - color: The icon color (defaults to primary).
    init(
        entryType: EntryType,
        taskStatus: DataModel.Task.Status? = nil,
        noteStatus: DataModel.Note.Status? = nil,
        isEventPast: Bool = false,
        size: Font.TextStyle = .caption,
        color: Color = .primary
    ) {
        self.configuration = StatusIconConfiguration(
            entryType: entryType,
            taskStatus: taskStatus,
            noteStatus: noteStatus,
            isEventPast: isEventPast,
            size: size
        )
        self.color = color
    }

    // MARK: - Body

    var body: some View {
        EntryIconFactory.icon(
            entryType: configuration.entryType,
            taskStatus: configuration.taskStatus,
            noteStatus: configuration.noteStatus,
            isEventPast: configuration.isEventPast,
            size: EntryIconSize(configuration.size).points,
            color: color
        )
    }
}

// MARK: - Previews

#Preview("Task Statuses") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .open)
            Text("Open")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete)
            Text("Complete")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .migrated)
            Text("Migrated")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .cancelled)
            Text("Cancelled")
        }
    }
    .padding()
}

#Preview("Note Statuses") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            StatusIcon(configuration: StatusIconConfiguration(
                entryType: .note,
                noteStatus: .active
            ))
            Text("Active")
        }
        HStack(spacing: 12) {
            StatusIcon(configuration: StatusIconConfiguration(
                entryType: .note,
                noteStatus: .migrated
            ))
            Text("Migrated")
        }
    }
    .padding()
}

#Preview("Event States") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            StatusIcon(configuration: StatusIconConfiguration(
                entryType: .event,
                isEventPast: false
            ))
            Text("Current")
        }
        HStack(spacing: 12) {
            StatusIcon(configuration: StatusIconConfiguration(
                entryType: .event,
                isEventPast: true
            ))
            Text("Past")
        }
    }
    .padding()
}

#Preview("Entry Types") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            StatusIcon(entryType: .task)
            Text("Task")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .event)
            Text("Event")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .note)
            Text("Note")
        }
    }
    .padding()
}

#Preview("Sizes") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, size: .caption)
            Text("Caption")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, size: .body)
            Text("Body")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, size: .title)
            Text("Title")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, size: .largeTitle)
            Text("Large Title")
        }
    }
    .padding()
}

#Preview("Colors") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, color: .primary)
            Text("Primary")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, color: .secondary)
            Text("Secondary")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, color: .blue)
            Text("Blue")
        }
        HStack(spacing: 12) {
            StatusIcon(entryType: .task, taskStatus: .complete, color: .red)
            Text("Red")
        }
    }
    .padding()
}

#Preview("Animated Toggle") {
    @Previewable @State var status: DataModel.Task.Status = .open

    VStack(spacing: 24) {
        StatusIcon(entryType: .task, taskStatus: status, size: .title, color: status.statusIconColor)
            .animation(.easeInOut(duration: 0.18), value: status)

        Button("Cycle status") {
            withAnimation {
                switch status {
                case .open:      status = .complete
                case .complete:  status = .migrated
                case .migrated:  status = .cancelled
                case .cancelled: status = .open
                }
            }
        }
        .buttonStyle(.bordered)

        Text(status.displayName)
            .foregroundStyle(.secondary)
    }
    .padding()
}
