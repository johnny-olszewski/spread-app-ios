import SwiftUI

/// A button that renders an entry's status icon and optionally responds to taps.
///
/// Pass `onTap` to make the button interactive (e.g. toggling open ↔ complete for tasks).
/// When `onTap` is nil the button is visual-only and does not absorb taps.
struct EntryStatusButton: View {

    // MARK: - Properties

    let status: EntryStatus
    let entryType: EntryType
    var onTap: (() -> Void)?

    // MARK: - Body

    var body: some View {
        Button {
            onTap?()
        } label: {
            EntryStatusIcon(baseShape: status.iconBaseShape(for: entryType), overlay: status.iconOverlay)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(status.accessibilityLabel(for: entryType))
        .allowsHitTesting(onTap != nil)
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 12) {
        EntryStatusButton(status: .open, entryType: .task, onTap: {})
        EntryStatusButton(status: .complete, entryType: .task)
        EntryStatusButton(status: .cancelled, entryType: .task)
        EntryStatusButton(status: .upcoming, entryType: .event)
        EntryStatusButton(status: .active, entryType: .note)
    }
    .padding()
}
