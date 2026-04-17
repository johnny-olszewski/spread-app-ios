import SwiftUI

struct GlowingShimmerModifier<S: Shape>: ViewModifier {
    @State private var rotation: Double = 0

    let padding: CGFloat
    let shape: S
    let gradient: Gradient
    let speed: Double
    let borderWidth: CGFloat
    let blurRadius: CGFloat

    init(
        padding: CGFloat = 0,
        shape: S,
        gradient: Gradient? = nil,
        speed: Double = 2.0,
        borderWidth: CGFloat = 3,
        blurRadius: CGFloat = 4
    ) {
        self.padding = padding
        self.shape = shape
        self.gradient = gradient ?? Gradient(colors: [
            .blue,
            .purple,
            .pink,
            .orange,
            .yellow,
            .green,
            .blue
        ])
        self.speed = speed
        self.borderWidth = borderWidth
        self.blurRadius = blurRadius
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .overlay {
                shape
                    .stroke(
                        AngularGradient(
                            gradient: gradient,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: borderWidth
                    )
                    .blur(radius: blurRadius)
            }
            .overlay {
                shape
                    .stroke(
                        AngularGradient(
                            gradient: gradient,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: borderWidth * 0.5
                    )
            }
            .onAppear {
                guard rotation == 0 else { return }
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func glowingShimmer<S: Shape>(
        shape: S,
        gradient: Gradient? = nil,
        speed: Double = 2.0,
        borderWidth: CGFloat = 3,
        blurRadius: CGFloat = 4
    ) -> some View {
        modifier(
            GlowingShimmerModifier(
                shape: shape,
                gradient: gradient,
                speed: speed,
                borderWidth: borderWidth,
                blurRadius: blurRadius
            )
        )
    }

    func glowingShimmer(
        padding: CGFloat = 0,
        cornerRadius: CGFloat = 12,
        gradient: Gradient? = nil,
        speed: Double = 2.0,
        borderWidth: CGFloat = 3,
        blurRadius: CGFloat = 4
    ) -> some View {
        modifier(
            GlowingShimmerModifier(
                padding: padding,
                shape: RoundedRectangle(cornerRadius: cornerRadius),
                gradient: gradient,
                speed: speed,
                borderWidth: borderWidth,
                blurRadius: blurRadius
            )
        )
    }
}
