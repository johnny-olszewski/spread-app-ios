import SwiftUI
import JohnnyOFoundationUI

/// A reusable icon component for displaying an entry's status.
///
/// Renders a custom-drawn SwiftUI icon based on the status's `EntryStatusButtonRepresentable`
/// conformance: the base shape (filled circle, empty circle, or dash) with an optional overlay
/// (xmark, arrow, or slash) indicating the current status.
///
/// Example usage:
/// ```swift
/// EntryStatusIcon(status: DataModel.Task.Status.complete)
/// EntryStatusIcon(status: DataModel.Event.Status.upcoming)
/// EntryStatusIcon(status: DataModel.Note.Status.active, size: .title, color: .secondary)
/// ```
struct EntryStatusIcon: View {

    // MARK: - Properties

    let status: any EntryStatusButtonRepresentable
    var color: Color = .primary
    var size: Font.TextStyle = .caption

    // MARK: - Body

    var body: some View {
        EntryIconFactory.icon(status: status, size: EntryIconSize(size).points, color: color)
    }
}

// MARK: - Previews

#Preview("Task Statuses") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.open)
            Text("Open")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.complete)
            Text("Complete")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.migrated)
            Text("Migrated")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.cancelled)
            Text("Cancelled")
        }
    }
    .padding()
}

#Preview("Note Statuses") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Note.Status.active)
            Text("Active")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Note.Status.migrated)
            Text("Migrated")
        }
    }
    .padding()
}

#Preview("Event Status") {
    HStack(spacing: 12) {
        EntryStatusIcon(status: DataModel.Event.Status.upcoming)
        Text("Upcoming")
    }
    .padding()
}

#Preview("Sizes") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.complete, size: .caption)
            Text("Caption")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.complete, size: .body)
            Text("Body")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.complete, size: .title)
            Text("Title")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(status: DataModel.Task.Status.complete, size: .largeTitle)
            Text("Large Title")
        }
    }
    .padding()
}

#Preview("Animated Toggle") {
    @Previewable @State var status: DataModel.Task.Status = .open

    VStack(spacing: 24) {
        EntryStatusIcon(status: status, color: status.statusIconColor, size: .title)
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
