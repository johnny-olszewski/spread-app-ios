//
//  FolderTabShape.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// A custom shape that draws a folder tab with smooth curved edges.
///
/// The shape creates a tab that:
/// - Has a flat bottom edge that connects seamlessly to content below
/// - Curves up smoothly on the leading edge (exponential ease-out)
/// - Has a flat top edge for the label
/// - Curves down on the trailing edge (mirror of leading)
///
/// ```
///        _______________
///       /               \
///      |                 |
///   __/                   \__
/// ```
struct FolderTabShape: Shape {

    /// The radius of the curve where the tab rises from the baseline
    var curveRadius: CGFloat

    /// How much the tab extends below neighboring tabs (the "lip" that shows it's selected)
    var baseExtension: CGFloat

    init(curveRadius: CGFloat = 12, baseExtension: CGFloat = 0) {
        self.curveRadius = curveRadius
        self.baseExtension = baseExtension
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Key points
        let curveWidth = curveRadius * 2  // Width of the curved section

        // Start at bottom-left corner
        path.move(to: CGPoint(x: 0, y: height))

        // Leading curve: bottom-left rising up
        // Using a quadratic curve for smooth exponential-like rise
        path.addQuadCurve(
            to: CGPoint(x: curveWidth, y: 0),
            control: CGPoint(x: 0, y: 0)
        )

        // Top edge (flat)
        path.addLine(to: CGPoint(x: width - curveWidth, y: 0))

        // Trailing curve: top-right descending down (mirror of leading)
        path.addQuadCurve(
            to: CGPoint(x: width, y: height),
            control: CGPoint(x: width, y: 0)
        )

        // Close the path along bottom
        path.closeSubpath()

        return path
    }
}

/// A tab shape with smooth concave curves on the sides.
///
/// The shape creates a tab with bezier curves that flare out at the bottom:
/// ```
///      _______________
///     /               \
///    (                 )    ← concave curves
///   /                   \
/// ```
struct TabShape: Shape {
    /// The width factor for the concave curves on the bottom corners (0.0 to 0.5)
    /// A value of 0.4 means 40% of the width is used for each curve
    var curveWidthFactor: CGFloat = 0.4

    func path(in rect: CGRect) -> Path {
        let height = rect.height
        let width = rect.width
        let curveWidth = width * curveWidthFactor

        var path = Path()

        // Start at bottom-left
        path.move(to: CGPoint(x: 0, y: height))

        // Left concave curve (curving inward from bottom-left to top-left)
        path.addCurve(
            to: CGPoint(x: curveWidth, y: 0),
            control1: CGPoint(x: curveWidth, y: height),
            control2: CGPoint(x: 0, y: 0)
        )

        // Top edge
        path.addLine(to: CGPoint(x: width - curveWidth, y: 0))

        // Right concave curve (curving inward from top-right to bottom-right)
        path.addCurve(
            to: CGPoint(x: width, y: height),
            control1: CGPoint(x: width, y: 0),
            control2: CGPoint(x: width - curveWidth, y: height)
        )

        // Bottom edge (back to start)
        path.addLine(to: CGPoint(x: 0, y: height))

        path.closeSubpath()
        return path
    }
}

/// Shape for unselected folder tabs - simpler rectangular with slight rounding
struct InactiveFolderTabShape: InsettableShape {

    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    init(cornerRadius: CGFloat = 6) {
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        // Simple rounded rectangle, but only round the top corners
        var path = Path()

        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let width = insetRect.width
        let height = insetRect.height
        let radius = min(cornerRadius, min(width, height) / 2)
        let originX = insetRect.minX
        let originY = insetRect.minY

        // Start at bottom-left
        path.move(to: CGPoint(x: originX, y: originY + height))

        // Left edge up
        path.addLine(to: CGPoint(x: originX, y: originY + radius))

        // Top-left corner
        path.addQuadCurve(
            to: CGPoint(x: originX + radius, y: originY),
            control: CGPoint(x: originX, y: originY)
        )

        // Top edge
        path.addLine(to: CGPoint(x: originX + width - radius, y: originY))

        // Top-right corner
        path.addQuadCurve(
            to: CGPoint(x: originX + width, y: originY + radius),
            control: CGPoint(x: originX + width, y: originY)
        )

        // Right edge down
        path.addLine(to: CGPoint(x: originX + width, y: originY + height))

        // Close
        path.closeSubpath()

        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

// MARK: - Previews

#Preview("Tab Shapes") {
    VStack(spacing: 40) {
        // TabShape with default curve
        VStack(spacing: 0) {
            Text("TabShape (default 0.4)")
                .font(.caption)

            TabShape()
                .fill(Color.blue)
                .frame(width: 100, height: 36)
        }

        // TabShape with less curve
        VStack(spacing: 0) {
            Text("TabShape (0.25)")
                .font(.caption)

            TabShape(curveWidthFactor: 0.25)
                .fill(Color.green)
                .frame(width: 100, height: 36)
        }

        // TabShape with more curve
        VStack(spacing: 0) {
            Text("TabShape (0.5)")
                .font(.caption)

            TabShape(curveWidthFactor: 0.5)
                .fill(Color.orange)
                .frame(width: 120, height: 36)
        }

        // Comparison with content
        VStack(spacing: 0) {
            Text("Selected Tab + Content")
                .font(.caption)
                .padding(.bottom, 8)

            ZStack(alignment: .bottom) {
                // Content area
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 100)

                // Tab
                HStack(spacing: 4) {
                    // Inactive tab
                    Text("2025")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    // Active tab
                    Text("Jan 26")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            TabShape(curveWidthFactor: 0.35)
                                .fill(Color.blue.opacity(0.2))
                        )

                    // Inactive tab
                    Text("Feb 26")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -100 + 36)  // Position tabs at top of content
            }
            .frame(height: 136)
        }
    }
    .padding()
}
