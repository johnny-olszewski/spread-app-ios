#if DEBUG
import SwiftUI

/// Debug-only appearance overrides for visual tuning.
///
/// Stores overrides in `@AppStorage` so they persist across app launches.
/// Views read these overrides to apply live appearance changes.
/// Use `resetToDefaults()` to revert all settings to spec defaults.
@Observable
@MainActor
final class DebugAppearanceSettings {

    /// Shared instance for debug builds.
    static let shared = DebugAppearanceSettings()

    // MARK: - Paper Tone

    /// Available paper tone presets.
    enum PaperTonePreset: String, CaseIterable, Identifiable {
        case warmOffWhite = "warmOffWhite"
        case cleanWhite = "cleanWhite"
        case coolGray = "coolGray"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .warmOffWhite: "Warm Off-White (Default)"
            case .cleanWhite: "Clean White"
            case .coolGray: "Cool Gray"
            }
        }

        /// Light mode color for this preset.
        var lightColor: UIColor {
            switch self {
            case .warmOffWhite:
                UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
            case .cleanWhite:
                UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
            case .coolGray:
                UIColor(red: 240/255, green: 242/255, blue: 245/255, alpha: 1)
            }
        }

        /// Dark mode color for this preset.
        var darkColor: UIColor {
            switch self {
            case .warmOffWhite:
                UIColor(red: 28/255, green: 26/255, blue: 24/255, alpha: 1)
            case .cleanWhite:
                UIColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 1)
            case .coolGray:
                UIColor(red: 22/255, green: 24/255, blue: 28/255, alpha: 1)
            }
        }

        /// SwiftUI color that adapts to light/dark mode.
        var color: Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? self.darkColor : self.lightColor
            })
        }
    }

    /// The active paper tone preset.
    var paperTone: PaperTonePreset {
        get {
            access(keyPath: \.paperTone)
            let raw = UserDefaults.standard.string(forKey: "debug.appearance.paperTone") ?? PaperTonePreset.warmOffWhite.rawValue
            return PaperTonePreset(rawValue: raw) ?? .warmOffWhite
        }
        set {
            withMutation(keyPath: \.paperTone) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "debug.appearance.paperTone")
            }
        }
    }

    // MARK: - Dot Grid

    /// Whether the dot grid is visible.
    var isDotGridVisible: Bool {
        get {
            access(keyPath: \.isDotGridVisible)
            return UserDefaults.standard.object(forKey: "debug.appearance.dotGridVisible") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.isDotGridVisible) {
                UserDefaults.standard.set(newValue, forKey: "debug.appearance.dotGridVisible")
            }
        }
    }

    /// Dot size in points (0.5 - 4.0).
    var dotSize: CGFloat {
        get {
            access(keyPath: \.dotSize)
            let val = UserDefaults.standard.object(forKey: "debug.appearance.dotSize") as? Double
            return val.map { CGFloat($0) } ?? 1.5
        }
        set {
            withMutation(keyPath: \.dotSize) {
                UserDefaults.standard.set(Double(newValue), forKey: "debug.appearance.dotSize")
            }
        }
    }

    /// Dot spacing in points (8 - 40).
    var dotSpacing: CGFloat {
        get {
            access(keyPath: \.dotSpacing)
            let val = UserDefaults.standard.object(forKey: "debug.appearance.dotSpacing") as? Double
            return val.map { CGFloat($0) } ?? 20
        }
        set {
            withMutation(keyPath: \.dotSpacing) {
                UserDefaults.standard.set(Double(newValue), forKey: "debug.appearance.dotSpacing")
            }
        }
    }

    /// Dot opacity (0.0 - 1.0).
    var dotOpacity: CGFloat {
        get {
            access(keyPath: \.dotOpacity)
            let val = UserDefaults.standard.object(forKey: "debug.appearance.dotOpacity") as? Double
            return val.map { CGFloat($0) } ?? 0.22
        }
        set {
            withMutation(keyPath: \.dotOpacity) {
                UserDefaults.standard.set(Double(newValue), forKey: "debug.appearance.dotOpacity")
            }
        }
    }

    // MARK: - Typography

    /// Available heading font presets.
    enum HeadingFont: String, CaseIterable, Identifiable {
        case avenirNext = "Avenir Next"
        case system = "System"
        case georgia = "Georgia"
        case palatino = "Palatino"

        var id: String { rawValue }

        var displayName: String { rawValue }

        /// Returns the font for a given size and weight.
        func font(size: CGFloat, weight: Font.Weight) -> Font {
            switch self {
            case .avenirNext:
                .custom("Avenir Next", size: size).weight(weight)
            case .system:
                .system(size: size, weight: weight)
            case .georgia:
                .custom("Georgia", size: size).weight(weight)
            case .palatino:
                .custom("Palatino", size: size).weight(weight)
            }
        }
    }

    /// The active heading font.
    var headingFont: HeadingFont {
        get {
            access(keyPath: \.headingFont)
            let raw = UserDefaults.standard.string(forKey: "debug.appearance.headingFont") ?? HeadingFont.avenirNext.rawValue
            return HeadingFont(rawValue: raw) ?? .avenirNext
        }
        set {
            withMutation(keyPath: \.headingFont) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "debug.appearance.headingFont")
            }
        }
    }

    // MARK: - Accent Color

    /// Available accent color presets.
    enum AccentColorPreset: String, CaseIterable, Identifiable {
        case mutedBlue = "mutedBlue"
        case teal = "teal"
        case indigo = "indigo"
        case brown = "brown"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .mutedBlue: "Muted Blue (Default)"
            case .teal: "Teal"
            case .indigo: "Indigo"
            case .brown: "Brown"
            }
        }

        var color: Color {
            switch self {
            case .mutedBlue:
                Color(red: 91/255, green: 122/255, blue: 153/255)
            case .teal:
                Color(red: 75/255, green: 140/255, blue: 140/255)
            case .indigo:
                Color(red: 88/255, green: 86/255, blue: 160/255)
            case .brown:
                Color(red: 139/255, green: 109/255, blue: 80/255)
            }
        }
    }

    /// The active accent color preset.
    var accentColor: AccentColorPreset {
        get {
            access(keyPath: \.accentColor)
            let raw = UserDefaults.standard.string(forKey: "debug.appearance.accentColor") ?? AccentColorPreset.mutedBlue.rawValue
            return AccentColorPreset(rawValue: raw) ?? .mutedBlue
        }
        set {
            withMutation(keyPath: \.accentColor) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "debug.appearance.accentColor")
            }
        }
    }

    // MARK: - Computed Properties

    /// The current paper color based on the active preset.
    var paperColor: Color {
        paperTone.color
    }

    /// The current accent color based on the active preset.
    var activeAccentColor: Color {
        accentColor.color
    }

    /// The current dot grid configuration based on overrides.
    var dotGridConfiguration: DotGridConfiguration {
        DotGridConfiguration(
            dotColor: accentColor.color.opacity(dotOpacity),
            dotSize: dotSize,
            dotSpacing: dotSpacing,
            backgroundColor: paperColor
        )
    }

    // MARK: - Reset

    /// Resets all appearance settings to spec defaults.
    func resetToDefaults() {
        paperTone = .warmOffWhite
        isDotGridVisible = true
        dotSize = 1.5
        dotSpacing = 20
        dotOpacity = 0.22
        headingFont = .avenirNext
        accentColor = .mutedBlue
    }
}
#endif
