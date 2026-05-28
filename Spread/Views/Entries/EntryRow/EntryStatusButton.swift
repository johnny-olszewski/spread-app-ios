import SwiftUI

/// A button that renders an entry's status icon and optionally responds to taps.
///
/// Pass `onTap` to make the button interactive (e.g. toggling open ↔ complete for tasks).
/// When `onTap` is nil the button is visual-only and does not absorb taps.
struct EntryStatusButton: View {

    // MARK: - Properties

    let status: any EntryStatusButtonRepresentable
    var color: Color = .primary
    var onTap: (() -> Void)?

    // MARK: - Body

    var body: some View {
        Button {
            onTap?()
        } label: {
            EntryStatusIcon(status: status, color: color)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(status.accessibilityLabel)
        .allowsHitTesting(onTap != nil)
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 12) {
        EntryStatusButton(status: DataModel.Task.Status.open, onTap: {})
        EntryStatusButton(status: DataModel.Task.Status.complete, color: .secondary)
        EntryStatusButton(status: DataModel.Task.Status.cancelled, color: .secondary)
        EntryStatusButton(status: DataModel.Event.Status.upcoming)
        EntryStatusButton(status: DataModel.Note.Status.active)
    }
    .padding()
}
