import SwiftUI

/// A circular progress ring that communicates sync state and triggers a manual sync on tap.
///
/// Visual states:
/// - **Syncing (push phase)**: arc fills proportionally as outbox mutations are confirmed.
/// - **Syncing (pull phase)**: indeterminate spinning arc once all local changes are pushed.
/// - **Synced / idle (clean)**: full ring in accent color.
/// - **Error**: full ring in warning orange.
/// - **Offline**: dashed muted ring.
/// - **Local only**: hidden.
///
/// Progress during the push phase is derived from a session peak captured when sync begins.
/// Pull progress is indeterminate by design — the server-side row count is unknown upfront.
struct SyncRingView: View {
    let status: SyncStatus
    let outboxCount: Int
    /// Called when the user taps the ring. Ignored when sync is already in progress.
    var onSyncNow: (() -> Void)? = nil

    @State private var sessionPeak: Int = 0
    @State private var rotationAngle: Double = 0
    @State private var isSpinning: Bool = false

    private let ringSize: CGFloat = 26
    private let lineWidth: CGFloat = 2.5

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                trackRing
                progressArc
            }
            .frame(width: ringSize, height: ringSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(status.shouldTriggerSync ? "Tap to sync now" : "")
        .onChange(of: status) { _, newStatus in
            handleStatusChange(newStatus)
        }
        .onAppear {
            syncSpinningState()
        }
    }

    // MARK: - Ring layers

    private var trackRing: some View {
        Circle()
            .strokeBorder(trackColor, style: trackStrokeStyle)
    }

    @ViewBuilder
    private var progressArc: some View {
        if isIndeterminate {
            // Pull phase or initial syncing with no known peak — spinning arc.
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(arcColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotationAngle - 90))
        } else {
            // Determinate — filled arc from top.
            Circle()
                .trim(from: 0, to: arcProgress)
                .stroke(arcColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: arcProgress)
        }
    }

    // MARK: - Progress calculation

    /// Whether the ring should animate as indeterminate.
    private var isIndeterminate: Bool {
        if case .syncing = status {
            // Show determinate only while there are outbox items and a valid peak.
            return outboxCount == 0 || sessionPeak == 0
        }
        return false
    }

    private var arcProgress: Double {
        switch status {
        case .synced:
            return 1.0
        case .idle:
            return outboxCount == 0 ? 1.0 : max(0.08, 1.0 - Double(outboxCount) / Double(max(sessionPeak, 1)))
        case .syncing:
            guard sessionPeak > 0, outboxCount > 0 else { return 0 }
            return max(0.08, 1.0 - Double(outboxCount) / Double(sessionPeak))
        case .error:
            return 1.0
        case .offline:
            return 0.5
        case .localOnly:
            return 1.0
        }
    }

    // MARK: - Colors

    private var arcColor: Color {
        switch status {
        case .idle where outboxCount > 0:
            return .secondary.opacity(0.6)
        case .idle, .synced, .syncing:
            return SpreadTheme.Accent.primary
        case .error:
            return .orange
        case .offline:
            return .secondary.opacity(0.4)
        case .localOnly:
            return .secondary.opacity(0.3)
        }
    }

    private var trackColor: Color {
        switch status {
        case .localOnly:
            return Color.secondary.opacity(0.15)
        default:
            return Color.secondary.opacity(0.2)
        }
    }

    private var trackStrokeStyle: StrokeStyle {
        if case .offline = status {
            return StrokeStyle(lineWidth: lineWidth, dash: [3, 3])
        }
        return StrokeStyle(lineWidth: lineWidth)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch status {
        case .idle where outboxCount > 0:
            return "\(outboxCount) changes pending sync"
        case .idle:
            return "Not yet synced"
        case .syncing:
            return outboxCount > 0 ? "Syncing, \(outboxCount) changes remaining" : "Syncing"
        case .synced(let date):
            return "Synced \(date.formatted(.relative(presentation: .named)))"
        case .error(let message):
            return "Sync error: \(message)"
        case .offline:
            return "Offline, sync paused"
        case .localOnly:
            return "Local only"
        }
    }

    // MARK: - Spin animation

    private func syncSpinningState() {
        if case .syncing = status, isIndeterminate {
            startSpinning()
        } else {
            stopSpinning()
        }
    }

    private func startSpinning() {
        guard !isSpinning else { return }
        isSpinning = true
        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func stopSpinning() {
        isSpinning = false
        withAnimation(.easeOut(duration: 0.2)) {
            rotationAngle = 0
        }
    }

    private func handleStatusChange(_ newStatus: SyncStatus) {
        if case .syncing = newStatus {
            // Capture the peak at the start of a push session.
            if outboxCount > 0 {
                sessionPeak = max(sessionPeak, outboxCount)
            }
            if isIndeterminate { startSpinning() }
        } else {
            if case .synced = newStatus { sessionPeak = 0 }
            stopSpinning()
        }
    }

    // MARK: - Tap

    private func handleTap() {
        guard status.shouldTriggerSync else { return }
        onSyncNow?()
    }
}

// MARK: - Preview

#Preview("Synced") {
    SyncRingView(status: .synced(Date()), outboxCount: 0)
        .padding()
}

#Preview("Idle clean") {
    SyncRingView(status: .idle, outboxCount: 0)
        .padding()
}

#Preview("Pending changes") {
    SyncRingView(status: .idle, outboxCount: 3)
        .padding()
}

#Preview("Syncing push") {
    SyncRingView(status: .syncing, outboxCount: 2)
        .padding()
}

#Preview("Syncing pull") {
    SyncRingView(status: .syncing, outboxCount: 0)
        .padding()
}

#Preview("Error") {
    SyncRingView(status: .error("Server unreachable"), outboxCount: 0)
        .padding()
}

#Preview("Offline") {
    SyncRingView(status: .offline, outboxCount: 0)
        .padding()
}
