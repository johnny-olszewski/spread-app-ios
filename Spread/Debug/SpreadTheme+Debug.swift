#if DEBUG
import SwiftUI

extension SpreadTheme.DotGrid {
    /// Returns the dot color using the active palette accent at the debug-overridable opacity.
    static var debugDots: Color {
        let settings = DebugAppearanceSettings.shared
        return SpreadTheme.Accent.primary.opacity(settings.dotOpacity)
    }
}

extension SpreadTheme.Typography {
    /// Returns the heading font, using debug overrides when available.
    static func debugHeading(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        DebugAppearanceSettings.shared.headingFont.font(size: size, weight: weight)
    }
}

extension DotGridConfiguration {
    /// Paper preset that respects debug appearance overrides.
    static var debugPaper: DotGridConfiguration {
        let settings = DebugAppearanceSettings.shared
        guard settings.isDotGridVisible else {
            // Return a config with zero-opacity dots (invisible)
            return DotGridConfiguration(
                dotColor: .clear,
                dotSize: 0,
                dotSpacing: 20,
                backgroundColor: SpreadTheme.Paper.primary
            )
        }
        return DotGridConfiguration(
            dotColor: SpreadTheme.DotGrid.debugDots,
            dotSize: settings.dotGridConfiguration.dotSize,
            dotSpacing: settings.dotGridConfiguration.dotSpacing,
            backgroundColor: SpreadTheme.Paper.primary
        )
    }
}
#endif
