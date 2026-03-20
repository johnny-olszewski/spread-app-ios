#if DEBUG
import SwiftUI

extension SpreadTheme.Paper {
    /// Returns the paper color, using debug overrides when available.
    static var debugPrimary: Color {
        DebugAppearanceSettings.shared.paperColor
    }
}

extension SpreadTheme.Accent {
    /// Returns the accent color, using debug overrides when available.
    static var debugPrimary: Color {
        DebugAppearanceSettings.shared.activeAccentColor
    }
}

extension SpreadTheme.DotGrid {
    /// Returns the dot color, using debug overrides when available.
    static var debugDots: Color {
        let settings = DebugAppearanceSettings.shared
        return settings.accentColor.color.opacity(settings.dotOpacity)
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
                backgroundColor: settings.paperColor
            )
        }
        return settings.dotGridConfiguration
    }
}
#endif
