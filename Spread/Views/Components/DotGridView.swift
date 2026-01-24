//
//  DotGridView.swift
//  Bulleted
//
//  Created by Claude on 12/30/25.
//

import SwiftUI

/// Configuration for the dot grid appearance.
/// Mirrors the look of physical bullet journal dot grid paper.
struct DotGridConfiguration: Equatable {
    /// Color of the dots
    var dotColor: Color = .secondary.opacity(0.2)

    /// Diameter of each dot in points
    var dotSize: CGFloat = 1.5

    /// Distance between dot centers in points
    var dotSpacing: CGFloat = 20

    /// Offset from the origin to start the grid (for alignment)
    var gridOffset: CGPoint = .zero

    /// Inset from edges so first row/column isn't bisected
    /// Defaults to dotSpacing so first dot appears at (spacing, spacing)
    var edgeInset: CGFloat?

    /// Background color behind the dots
    var backgroundColor: Color = Color(.systemBackground)

    /// Computed edge inset - defaults to spacing if not set
    var effectiveEdgeInset: CGFloat {
        edgeInset ?? dotSpacing
    }

    // MARK: - Presets

    /// Standard dot grid like Leuchtturm1917
    static let standard = DotGridConfiguration()

    /// Paper preset for spread content surfaces.
    /// Uses warm off-white paper background with neutral gray dots.
    /// Per spec: 1.5pt dots, 20pt spacing, ~15-20% opacity.
    static let paper = DotGridConfiguration(
        dotColor: SpreadTheme.DotGrid.dots,
        dotSize: 1.5,
        dotSpacing: 20,
        backgroundColor: SpreadTheme.Paper.primary
    )

    /// Subtle, barely visible grid
    static let subtle = DotGridConfiguration(
        dotColor: .secondary.opacity(0.1),
        dotSize: 1.0,
        dotSpacing: 24
    )

    /// Dense grid with more dots
    static let dense = DotGridConfiguration(
        dotColor: .secondary.opacity(0.15),
        dotSize: 1.5,
        dotSpacing: 14
    )

    /// Prominent grid for high visibility
    static let prominent = DotGridConfiguration(
        dotColor: .secondary.opacity(0.35),
        dotSize: 2.0,
        dotSpacing: 18
    )
}

/// A view that efficiently draws a dot grid pattern using Canvas.
/// Optimized for performance with large grids by only drawing visible dots.
struct DotGridView: View {
    var configuration: DotGridConfiguration

    init(configuration: DotGridConfiguration = .standard) {
        self.configuration = configuration
    }

    var body: some View {
        Canvas { context, size in
            drawDotGrid(context: context, size: size)
        }
        .background(configuration.backgroundColor)
    }

    private func drawDotGrid(context: GraphicsContext, size: CGSize) {
        let spacing = configuration.dotSpacing
        let dotRadius = configuration.dotSize / 2
        let offset = configuration.gridOffset
        let inset = configuration.effectiveEdgeInset

        // Calculate grid bounds - start from inset position
        let startX = inset + offset.x
        let startY = inset + offset.y

        let endCol = Int(ceil((size.width - startX) / spacing))
        let endRow = Int(ceil((size.height - startY) / spacing))

        // Use resolved shading for efficient drawing
        let shading = GraphicsContext.Shading.color(configuration.dotColor)

        for row in 0...max(0, endRow) {
            for col in 0...max(0, endCol) {
                let x = startX + CGFloat(col) * spacing
                let y = startY + CGFloat(row) * spacing

                // Skip dots outside visible bounds
                guard x >= -dotRadius && x <= size.width + dotRadius &&
                      y >= -dotRadius && y <= size.height + dotRadius else {
                    continue
                }

                let dotRect = CGRect(
                    x: x - dotRadius,
                    y: y - dotRadius,
                    width: configuration.dotSize,
                    height: configuration.dotSize
                )

                context.fill(
                    Path(ellipseIn: dotRect),
                    with: shading
                )
            }
        }
    }
}

/// A view modifier that adds a dot grid background to any view.
struct DotGridBackgroundModifier: ViewModifier {
    var configuration: DotGridConfiguration

    func body(content: Content) -> some View {
        content
            .background(DotGridView(configuration: configuration))
    }
}

extension View {
    /// Adds a dot grid background to the view.
    func dotGridBackground(_ configuration: DotGridConfiguration = .standard) -> some View {
        modifier(DotGridBackgroundModifier(configuration: configuration))
    }
}

// MARK: - Previews

#Preview("Dot Grid Configurations") {
    VStack(spacing: 20) {
        VStack {
            Text("Paper (Default for Spreads)")
                .font(.caption)
            DotGridView(configuration: .paper)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        VStack {
            Text("Standard")
                .font(.caption)
            DotGridView(configuration: .standard)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        VStack {
            Text("Subtle")
                .font(.caption)
            DotGridView(configuration: .subtle)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        VStack {
            Text("Dense")
                .font(.caption)
            DotGridView(configuration: .dense)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        VStack {
            Text("Prominent")
                .font(.caption)
            DotGridView(configuration: .prominent)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    .padding()
}

#Preview("Dot Grid with Content") {
    VStack(spacing: 0) {
        // Simulated tab bar area (paper background, no dots)
        HStack {
            Text("Tab 1")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Text("Tab 2")
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(SpreadTheme.Paper.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("Tab 3")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(SpreadTheme.Paper.secondary)

        // Content with paper dot grid
        VStack(alignment: .leading, spacing: 12) {
            Text("February 2026")
                .font(SpreadTheme.Typography.title2)

            Text("3 tasks")
                .font(SpreadTheme.Typography.subheadline)
                .foregroundStyle(.secondary)

            ForEach(0..<3, id: \.self) { i in
                HStack {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 6, height: 6)
                    Text("Task \(i + 1)")
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dotGridBackground(.paper)
    }
}

#Preview("Custom Configuration") {
    let customConfig = DotGridConfiguration(
        dotColor: .blue.opacity(0.3),
        dotSize: 3,
        dotSpacing: 25,
        backgroundColor: Color(.systemBackground)
    )

    return DotGridView(configuration: customConfig)
        .frame(width: 300, height: 300)
}
