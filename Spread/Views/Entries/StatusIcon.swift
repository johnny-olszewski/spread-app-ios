import SwiftUI

/// A reusable icon component for displaying entry type and status.
///
/// Renders the appropriate SF Symbol based on entry type:
/// - Task: solid circle (●)
/// - Event: empty circle (○)
/// - Note: dash (—)
///
/// For tasks, an overlay indicates status:
/// - Open: base circle only
/// - Complete: xmark overlay
/// - Migrated: arrow.right overlay
/// - Cancelled: slash overlay
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
    ///   - size: The text style size (defaults to `.body`).
    ///   - color: The icon color (defaults to primary).
    init(
        entryType: EntryType,
        taskStatus: DataModel.Task.Status? = nil,
        size: Font.TextStyle = .body,
        color: Color = .primary
    ) {
        self.configuration = StatusIconConfiguration(
            entryType: entryType,
            taskStatus: taskStatus,
            size: size
        )
        self.color = color
    }

    // MARK: - Body

    var body: some View {
        Image(systemName: configuration.baseSymbol)
            .font(.system(configuration.size))
            .foregroundStyle(color)
            .overlay {
                overlayImage
            }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var overlayImage: some View {
        if let overlaySymbol = configuration.overlaySymbol {
            Image(systemName: overlaySymbol)
                .font(.system(configuration.size))
                .scaleEffect(configuration.overlayScale)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
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
