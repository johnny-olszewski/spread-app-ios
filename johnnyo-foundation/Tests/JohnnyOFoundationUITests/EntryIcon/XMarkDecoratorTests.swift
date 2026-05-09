import Testing
import SwiftUI
@testable import JohnnyOFoundationUI

@MainActor
struct XMarkDecoratorTests {

    // MARK: - iconSize propagation

    /// Conditions: XMarkDecorator wraps a TaskCircleIcon with iconSize 12.
    /// Expected: The decorator's iconSize equals the base iconSize (12).
    @Test func decoratorPropagatesBaseIconSize() {
        let base = TaskCircleIcon(color: .primary, iconSize: 12)
        let decorated = XMarkDecorator(base: base, color: .primary)
        #expect(decorated.iconSize == 12)
    }

    /// Conditions: XMarkDecorator wraps an EventCircleIcon with iconSize 28.
    /// Expected: The decorator's iconSize equals the base iconSize (28).
    @Test func decoratorPropagatesLargerBaseIconSize() {
        let base = EventCircleIcon(color: .primary, iconSize: 28)
        let decorated = XMarkDecorator(base: base, color: .primary)
        #expect(decorated.iconSize == 28)
    }

    // MARK: - Overhang

    /// Conditions: Default overhangFraction (0.35) with iconSize 12.
    /// Expected: The overlay canvas (iconSize × (1 + 2 × overhangFraction)) is larger than iconSize.
    @Test func defaultOverhangExceedsIconSize() {
        let base = TaskCircleIcon(color: .primary, iconSize: 12)
        let decorated = XMarkDecorator(base: base, color: .primary)
        let canvasSize = decorated.iconSize * (1 + 2 * decorated.overhangFraction)
        #expect(canvasSize > decorated.iconSize)
    }

    /// Conditions: Injected configuration with overhangFraction of 0.5 and iconSize 20.
    /// Expected: Canvas is exactly iconSize × 2.0.
    @Test func customOverhangScalesCorrectly() {
        let base = TaskCircleIcon(color: .primary, iconSize: 20)
        let decorated = XMarkDecorator(
            base: base,
            color: .primary,
            configuration: .init(overhangFraction: 0.5)
        )
        let canvasSize = decorated.iconSize * (1 + 2 * decorated.overhangFraction)
        #expect(canvasSize == 40)
    }

    /// Conditions: Injected configuration with zero overhangFraction.
    /// Expected: Canvas size equals iconSize exactly (no overhang).
    @Test func zeroOverhangProducesNoExtension() {
        let base = TaskCircleIcon(color: .primary, iconSize: 16)
        let decorated = XMarkDecorator(
            base: base,
            color: .primary,
            configuration: .init(overhangFraction: 0)
        )
        let canvasSize = decorated.iconSize * (1 + 2 * decorated.overhangFraction)
        #expect(canvasSize == decorated.iconSize)
    }

    // MARK: - Configuration

    /// Conditions: XMarkDecorator created with default parameters.
    /// Expected: overhangFraction is 0.35.
    @Test func defaultOverhangFractionIsThirtyFivePercent() {
        let base = TaskCircleIcon(color: .primary, iconSize: 12)
        let decorated = XMarkDecorator(base: base, color: .primary)
        #expect(decorated.overhangFraction == 0.35)
    }

    /// Conditions: XMarkDecorator created with injected configuration.
    /// Expected: The decorator preserves the injected geometry values.
    @Test func injectedConfigurationIsPreserved() {
        let base = TaskCircleIcon(color: .primary, iconSize: 12)
        let configuration = XMarkDecorator<TaskCircleIcon>.Configuration(
            overhangFraction: 0.4,
            armLengthFraction: 0.7,
            strokeWidthFraction: 0.3,
            minimumStrokeWidth: 2.5,
            animationDuration: 0.12
        )
        let decorated = XMarkDecorator(
            base: base,
            color: .primary,
            configuration: configuration
        )

        #expect(decorated.configuration.overhangFraction == 0.4)
        #expect(decorated.configuration.armLengthFraction == 0.7)
        #expect(decorated.configuration.strokeWidthFraction == 0.3)
        #expect(decorated.configuration.minimumStrokeWidth == 2.5)
        #expect(decorated.configuration.animationDuration == 0.12)
    }
}
