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
/// EntryStatusIcon(
///     baseShape: .filledCircle,
///     bseeShapeConfig: .init(color: .green, iconSize: 12),
///     overlay: .xmark,
///     overlayConfig: .init(color: .green, iconSize: 12)
/// )
/// EntryStatusIcon(baseShape: .emptyCircle, overlay: nil)
/// ```
struct EntryStatusIcon: View {

    // MARK: - Supporting Enums

    /// The base icon shape drawn for an entry status.
    enum BaseShape {
        case filledCircle
        case emptyCircle
        case dash
    }

    /// The overlay indicator drawn on top of the base icon.
    enum OverlayShape {
        case xmark
        case arrowRight
        case slash
    }
    
    struct Config {
        let color: Color?
        let iconSize: CGFloat?
    }

    enum Constants {
        static let defaultBaseShapeColor: Color = .primary
        static let defaultBaseShapeSize: CGFloat = 12
    }

    // MARK: - Properties

    let baseShape: BaseShape
    let bseeShapeConfig: Config?
    let overlay: OverlayShape?
    let overlayConfig: Config?

    init(
        baseShape: BaseShape,
        bseeShapeConfig: Config? = nil,
        overlay: OverlayShape?,
        overlayConfig: Config? = nil
    ) {
        self.baseShape = baseShape
        self.bseeShapeConfig = bseeShapeConfig
        self.overlay = overlay
        self.overlayConfig = overlayConfig
    }

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
        case .filledCircle:
            CircleIcon(
                color: bseeShapeConfig?.color ?? Constants.defaultBaseShapeColor,
                iconSize: bseeShapeConfig?.iconSize ?? Constants.defaultBaseShapeSize
            )
        case .emptyCircle:
            RingIcon(
                color: bseeShapeConfig?.color ?? Constants.defaultBaseShapeColor,
                iconSize: bseeShapeConfig?.iconSize ?? Constants.defaultBaseShapeSize
            )
        case .dash:
            DashIcon(
                color: bseeShapeConfig?.color ?? Constants.defaultBaseShapeColor,
                iconSize: bseeShapeConfig?.iconSize ?? Constants.defaultBaseShapeSize
            )
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var overlayView: some View {
        if let overlay {
            switch overlay {
            case .xmark:
                let s = overlayConfig?.iconSize ?? Constants.defaultBaseShapeSize
                let decoratorSize = s * (1 + 2 * 0.35)
                AnimatedOverlayView(
                    shape: XMarkShape(armLength: decoratorSize * 0.6),
                    color: overlayConfig?.color ?? Constants.defaultBaseShapeColor,
                    frameSize: CGSize(width: decoratorSize, height: decoratorSize),
                    strokeStyle: StrokeStyle(lineWidth: max(2.0, s * 0.22), lineCap: .round),
                    animationDuration: 0.22
                )
            case .arrowRight:
                let s = overlayConfig?.iconSize ?? Constants.defaultBaseShapeSize
                AnimatedOverlayView(
                    shape: ArrowShape(),
                    color: overlayConfig?.color ?? Constants.defaultBaseShapeColor,
                    frameSize: CGSize(width: s * 2, height: s),
                    strokeStyle: StrokeStyle(lineWidth: max(1.5, s * 0.13), lineCap: .round, lineJoin: .round),
                    animationDuration: 0.22
                )
            case .slash:
                let s = overlayConfig?.iconSize ?? Constants.defaultBaseShapeSize
                AnimatedOverlayView(
                    shape: SlashShape(),
                    color: overlayConfig?.color ?? Constants.defaultBaseShapeColor,
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
            EntryStatusIcon(baseShape: .filledCircle, bseeShapeConfig: nil, overlay: nil, overlayConfig: nil)
            Text("Open")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .green, iconSize: 12),
                overlay: .xmark,
                overlayConfig: .init(color: .green, iconSize: 12)
            )
            Text("Complete")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .orange, iconSize: 12),
                overlay: .arrowRight,
                overlayConfig: .init(color: .orange, iconSize: 12)
            )
            Text("Migrated")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .secondary, iconSize: 12),
                overlay: .slash,
                overlayConfig: .init(color: .secondary, iconSize: 12)
            )
            Text("Cancelled")
        }
    }
    .padding()
}

#Preview("Note Statuses") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(baseShape: .dash, bseeShapeConfig: nil, overlay: nil, overlayConfig: nil)
            Text("Active")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .dash,
                bseeShapeConfig: .init(color: .orange, iconSize: 12),
                overlay: .arrowRight,
                overlayConfig: .init(color: .orange, iconSize: 12)
            )
            Text("Migrated")
        }
    }
    .padding()
}

#Preview("Event Status") {
    HStack(spacing: 12) {
        EntryStatusIcon(baseShape: .emptyCircle, bseeShapeConfig: nil, overlay: nil, overlayConfig: nil)
        Text("Upcoming")
    }
    .padding()
}

#Preview("Sizes") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .green, iconSize: 12),
                overlay: .xmark,
                overlayConfig: .init(color: .green, iconSize: 12)
            )
            Text("Caption (12)")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .green, iconSize: 17),
                overlay: .xmark,
                overlayConfig: .init(color: .green, iconSize: 17)
            )
            Text("Body (17)")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .green, iconSize: 28),
                overlay: .xmark,
                overlayConfig: .init(color: .green, iconSize: 28)
            )
            Text("Title (28)")
        }
        HStack(spacing: 12) {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .green, iconSize: 34),
                overlay: .xmark,
                overlayConfig: .init(color: .green, iconSize: 34)
            )
            Text("Large Title (34)")
        }
    }
    .padding()
}

#Preview("Animated Toggle") {
    @Previewable @State var showOverlay = false

    VStack(spacing: 24) {
        if showOverlay {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: .green, iconSize: 28),
                overlay: .xmark,
                overlayConfig: .init(color: .green, iconSize: 28)
            )
        } else {
            EntryStatusIcon(
                baseShape: .filledCircle,
                bseeShapeConfig: .init(color: nil, iconSize: 28),
                overlay: nil,
                overlayConfig: nil
            )
        }

        Button("Toggle overlay") {
            showOverlay.toggle()
        }
        .buttonStyle(.bordered)
    }
    .padding()
}
