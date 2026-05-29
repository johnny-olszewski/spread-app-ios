import SwiftUI
import JohnnyOFoundationUI

/// A reusable icon component for displaying an entry's status.
///
/// Renders a custom-drawn SwiftUI icon based on the provided `BaseShape` and optional
/// `Overlay`: the base shape (filled circle, empty circle, or dash) with an optional
/// animated overlay (xmark, arrow, or slash) indicating the current status.
///
/// Example usage:
/// ```swift
/// EntryStatusIcon(baseShape: .filledCircle(.green, 12), overlay: .xmark(.green, 12))
/// EntryStatusIcon(baseShape: .emptyCircle(nil, nil), overlay: nil)
/// EntryStatusIcon(baseShape: .dash(.primary, 17), overlay: .arrowRight(.orange, 17))
/// ```
struct EntryStatusIcon: View {

    // MARK: - Supporting Enums

    /// The base icon shape drawn for an entry status.
    enum BaseShape {
        case filledCircle(Color?, CGFloat?)
        case emptyCircle(Color?, CGFloat?)
        case dash(Color?, CGFloat?)
    }

    /// The overlay indicator drawn on top of the base icon.
    enum OverlayShape {
        case xmark(Color?, CGFloat?)
        case arrowRight(Color?, CGFloat?)
        case slash(Color?, CGFloat?)
    }

    enum Constants {
        static let defaultBaseShapeColor: Color = .primary
        static let defaultBaseShapeSize: CGFloat = 12
    }

    // MARK: - Properties

    let baseShape: BaseShape
    let overlay: OverlayShape?

    // MARK: - Body

    var body: some View {
        baseShapeView
            .overlay(alignment: overlayAlignment) {
                overlayView
            }
    }

    // MARK: - Base Shape

    @ViewBuilder
    private var baseShapeView: some View {
        switch baseShape {
        case .filledCircle(let color, let size):
            CircleIcon(color: color ?? Constants.defaultBaseShapeColor, iconSize: size ?? Constants.defaultBaseShapeSize)
        case .emptyCircle(let color, let size):
            RingIcon(color: color ?? Constants.defaultBaseShapeColor, iconSize: size ?? Constants.defaultBaseShapeSize)
        case .dash(let color, let size):
            DashIcon(color: color ?? Constants.defaultBaseShapeColor, iconSize: size ?? Constants.defaultBaseShapeSize)
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var overlayView: some View {
        if let overlay {
            switch overlay {
            case .xmark(let color, let size):
                let s = size ?? Constants.defaultBaseShapeSize
                let decoratorSize = s * (1 + 2 * 0.35)
                AnimatedOverlayView(
                    shape: XMarkShape(armLength: decoratorSize * 0.6),
                    color: color ?? Constants.defaultBaseShapeColor,
                    frameSize: CGSize(width: decoratorSize, height: decoratorSize),
                    strokeStyle: StrokeStyle(lineWidth: max(2.0, s * 0.22), lineCap: .round),
                    animationDuration: 0.22
                )
            case .arrowRight(let color, let size):
                let s = size ?? Constants.defaultBaseShapeSize
                AnimatedOverlayView(
                    shape: ArrowShape(),
                    color: color ?? Constants.defaultBaseShapeColor,
                    frameSize: CGSize(width: s * 2, height: s),
                    strokeStyle: StrokeStyle(lineWidth: max(1.5, s * 0.13), lineCap: .round, lineJoin: .round),
                    animationDuration: 0.22
                )
            case .slash(let color, let size):
                let s = size ?? Constants.defaultBaseShapeSize
                AnimatedOverlayView(
                    shape: SlashShape(),
                    color: color ?? Constants.defaultBaseShapeColor,
                    frameSize: CGSize(width: s * 1.1, height: s * 1.1),
                    strokeStyle: StrokeStyle(lineWidth: max(1.5, s * 0.13), lineCap: .round),
                    animationDuration: 0.18
                )
            }
        }
    }

    private var overlayAlignment: Alignment {
        if case .arrowRight = overlay { return .leading }
        return .center
    }
}

// MARK: - AnimatedOverlayView

private struct AnimatedOverlayView<S: Shape>: View {

    let shape: S
    let color: Color
    let frameSize: CGSize
    let strokeStyle: StrokeStyle
    let animationDuration: TimeInterval

    @State private var drawProgress: CGFloat = 0

    var body: some View {
        shape
            .trim(from: 0, to: drawProgress)
            .stroke(color, style: strokeStyle)
            .frame(width: frameSize.width, height: frameSize.height)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: animationDuration)) {
                    drawProgress = 1
                }
            }
    }
}

// MARK: - Previews

#Preview("Task Statuses") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(nil, nil), overlay: nil)
            Text("Open")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(.green, 12), overlay: .xmark(.green, 12))
            Text("Complete")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(.orange, 12), overlay: .arrowRight(.orange, 12))
            Text("Migrated")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(.secondary, 12), overlay: .slash(.secondary, 12))
            Text("Cancelled")
        }
    }
    .padding()
}

#Preview("Note Statuses") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .dash(nil, nil), overlay: nil)
            Text("Active")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .dash(.orange, 12), overlay: .arrowRight(.orange, 12))
            Text("Migrated")
        }
    }
    .padding()
}

#Preview("Event Status") {
    HStack(spacing: 12) {
        EntryStatusIcon(baseShape: .emptyCircle(nil, nil), overlay: nil)
        Text("Upcoming")
    }
    .padding()
}

#Preview("Sizes") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(.green, 12), overlay: .xmark(.green, 12))
            Text("Caption (12)")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(.green, 17), overlay: .xmark(.green, 17))
            Text("Body (17)")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(.green, 28), overlay: .xmark(.green, 28))
            Text("Title (28)")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .filledCircle(.green, 34), overlay: .xmark(.green, 34))
            Text("Large Title (34)")
        }
    }
    .padding()
}

#Preview("Animated Toggle") {
    @Previewable @State var showOverlay = false

    VStack(spacing: 24) {
        if showOverlay {
            EntryStatusIcon(baseShape: .filledCircle(.green, 28), overlay: .xmark(.green, 28))
        } else {
            EntryStatusIcon(baseShape: .filledCircle(nil, 28), overlay: nil)
        }

        Button("Toggle overlay") {
            showOverlay.toggle()
        }
        .buttonStyle(.bordered)
    }
    .padding()
}
