import SwiftUI
import Foundation

/// Theme definitions for the Spread app.
///
/// Provides consistent colors, typography, and styling across the app.
/// Spread content surfaces use dot grid on paper tone; navigation chrome
/// uses flat paper tone without dots. Supports both light and dark modes.
///
/// ## Color Palettes
/// Three named palettes are available: ``Palette/ocean`` (default), ``Palette/forest``,
/// and ``Palette/ink``. Set ``activePalette`` to switch schemes — the change
/// persists across launches via UserDefaults.
enum SpreadTheme {

    // MARK: - Palette

    /// Named color schemes for the app.
    enum Palette: String, CaseIterable {
        /// Warm paper tones with muted blue accent. The default palette.
        case ocean
        /// Warm paper tones with sage green accent.
        case forest
        /// Neutral paper tones with near-black ink accent.
        case ink

        /// Display name for use in settings UI.
        var displayName: String {
            switch self {
            case .ocean: return "Ocean"
            case .forest: return "Forest"
            case .ink: return "Ink"
            }
        }

        /// Primary paper background color, adaptive for light/dark mode.
        var paperPrimary: Color {
            Color(uiColor: UIColor { traits in
                switch self {
                case .ocean:
                    return traits.userInterfaceStyle == .dark
                        ? UIColor(red: 28/255, green: 26/255, blue: 24/255, alpha: 1)
                        : UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
                case .forest:
                    return traits.userInterfaceStyle == .dark
                        ? UIColor(red: 26/255, green: 29/255, blue: 26/255, alpha: 1)
                        : UIColor(red: 244/255, green: 242/255, blue: 235/255, alpha: 1)
                case .ink:
                    return traits.userInterfaceStyle == .dark
                        ? UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
                        : UIColor(red: 245/255, green: 245/255, blue: 240/255, alpha: 1)
                }
            })
        }

        /// Secondary paper tone for navigation chrome, adaptive for light/dark mode.
        var paperSecondary: Color {
            Color(uiColor: UIColor { traits in
                guard traits.userInterfaceStyle != .dark else {
                    return .secondarySystemBackground
                }
                switch self {
                case .ocean: return UIColor(red: 240/255, green: 236/255, blue: 227/255, alpha: 1)
                case .forest: return UIColor(red: 234/255, green: 232/255, blue: 224/255, alpha: 1)
                case .ink: return UIColor(red: 235/255, green: 235/255, blue: 235/255, alpha: 1)
                }
            })
        }

        /// Primary accent color for controls and highlights.
        var accentPrimary: Color {
            switch self {
            case .ocean: return Color(red: 91/255, green: 122/255, blue: 153/255)
            case .forest: return Color(red: 90/255, green: 122/255, blue: 94/255)
            case .ink: return Color(red: 64/255, green: 64/255, blue: 64/255)
            }
        }

        /// More vibrant accent color used for passive today emphasis.
        var accentTodayEmphasis: Color {
            switch self {
            case .ocean: return Color(red: 69/255, green: 120/255, blue: 184/255)
            case .forest: return Color(red: 61/255, green: 122/255, blue: 78/255)
            case .ink: return Color(red: 34/255, green: 34/255, blue: 34/255)
            }
        }
    }

    /// The active color palette, resolved from the `-SpreadPalette` launch argument.
    ///
    /// Pass `-SpreadPalette forest` (or `ocean`, `ink`) as a launch argument in the
    /// scheme to switch palettes. Defaults to ``Palette/ocean`` when no argument is set.
    static var activePalette: Palette {
        let raw = UserDefaults.standard.string(forKey: "SpreadPalette") ?? ""
        return Palette(rawValue: raw) ?? .ocean
    }

    // MARK: - Colors

    /// Paper tone colors for backgrounds.
    /// Light mode: warm off-white tones.
    /// Dark mode: warm dark tones for content, system backgrounds for chrome.
    enum Paper {
        /// Default primary paper color for spread content backgrounds (Ocean palette).
        /// Light: warm off-white (#F7F3EA)
        /// Dark: warm dark variant (#1C1A18)
        static let defaultPrimary = Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 28/255, green: 26/255, blue: 24/255, alpha: 1)
                    : UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
            }
        )

        /// Primary paper color for spread content backgrounds.
        static var primary: Color {
            SpreadTheme.activePalette.paperPrimary
        }

        /// Secondary paper tone for navigation chrome.
        /// In dark mode, uses system secondary background.
        static var secondary: Color {
            SpreadTheme.activePalette.paperSecondary
        }

        /// System background fallback when paper tone isn't appropriate.
        static let system = Color(.systemBackground)
    }

    /// Accent color for interactive elements.
    enum Accent {
        /// Default muted blue accent color for controls and highlights (Ocean palette).
        /// Hex: #5B7A99
        static let defaultPrimary = Color(red: 91/255, green: 122/255, blue: 153/255)

        /// Primary accent color for the active palette.
        static var primary: Color {
            SpreadTheme.activePalette.accentPrimary
        }

        /// Default vibrant blue used for passive today emphasis (Ocean palette).
        static let defaultTodayEmphasis = Color(red: 69/255, green: 120/255, blue: 184/255)

        /// Passive today emphasis color for unselected contextual highlighting.
        static var todayEmphasis: Color {
            SpreadTheme.activePalette.accentTodayEmphasis.opacity(0.95)
        }

        /// Stronger today emphasis color when the today item is also selected.
        static var todaySelectedEmphasis: Color {
            SpreadTheme.activePalette.accentTodayEmphasis
        }

        /// Border tint for today emphasis on passive surfaces.
        static var todayEmphasisBorder: Color {
            todaySelectedEmphasis.opacity(0.34)
        }

        // MARK: Calendar Cell Surfaces

        /// Subtle fill for a day cell that has an explicit day spread.
        /// Uses the blue accent family so created days read as active and navigable.
        static var createdDaySurface: Color {
            todaySelectedEmphasis.opacity(0.08)
        }

        /// Border for a created day cell — intentionally more defined than the fill.
        static var createdDayBorder: Color {
            todaySelectedEmphasis.opacity(0.34)
        }

        /// Subtle fill for today's cell in calendar grids.
        /// Uses the warm yellow selection family to distinguish today from created days.
        static var todayCellSurface: Color {
            selectedSurface.opacity(0.7)
        }

        /// Border for today's cell — paired with `todayCellSurface`.
        static var todayCellBorder: Color {
            selectedSurfaceBorder.opacity(0.7)
        }

        /// Warm highlight used for current selection surfaces so they remain distinct from the today emphasis color.
        /// Intentionally the same across all palettes — warm yellow is the universal "current spread" signal.
        static let selectedSurface = Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 247/255, green: 234/255, blue: 164/255, alpha: 1)
                    : UIColor(red: 255/255, green: 248/255, blue: 208/255, alpha: 1)
            }
        )

        /// Stronger border tint paired with the warm current-selection surface.
        static let selectedSurfaceBorder = Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 255/255, green: 243/255, blue: 190/255, alpha: 1)
                    : UIColor(red: 212/255, green: 189/255, blue: 94/255, alpha: 1)
            }
        )
    }

    /// Dot grid colors.
    enum DotGrid {
        /// Default muted blue dot color at ~35% opacity (Ocean palette).
        static let defaultDots = Color(red: 91/255, green: 122/255, blue: 153/255).opacity(0.35)

        /// Dot color using the active palette's accent at reduced opacity.
        static var dots: Color {
            #if DEBUG
            return debugDots
            #else
            return SpreadTheme.activePalette.accentPrimary.opacity(0.35)
            #endif
        }
    }

    // MARK: - Typography

    /// Typography definitions for headings and body text.
    enum Typography {
        /// Heading font — distinct sans family for titles.
        static func heading(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            #if DEBUG
            return debugHeading(size: size, weight: weight)
            #else
            return .custom("Avenir Next", size: size).weight(weight)
            #endif
        }

        /// Large title heading.
        static var largeTitle: Font {
            heading(size: 28, weight: .bold)
        }

        /// Standard title heading.
        static var title: Font {
            heading(size: 22, weight: .semibold)
        }

        /// Secondary title heading.
        static var title2: Font {
            heading(size: 20, weight: .semibold)
        }

        /// Tertiary title heading.
        static var title3: Font {
            heading(size: 18, weight: .medium)
        }

        /// Body text uses system font for legibility.
        static var body: Font { .body }

        /// Subheadline text.
        static var subheadline: Font { .subheadline }

        /// Caption text.
        static var caption: Font { .caption }
    }

    // MARK: - Spacing

    /// Standard spacing values.
    enum Spacing {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let standard: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24

        /// Vertical padding for entry rows in spread lists.
        static let entryRowVertical: CGFloat = 8
    }

    // MARK: - Overlay

    /// Colors for modal and loading overlay surfaces.
    enum Overlay {
        /// Semi-transparent dim for loading overlays.
        /// Uses `Color(.label)` at 20% so it is visible in both light and dark mode:
        /// black in light mode, white in dark mode.
        static let dim = Color(.label).opacity(0.2)
    }

    // MARK: - Corner Radius

    /// Named corner radius values. Pair with `.continuous` style on `RoundedRectangle` for smooth curves.
    enum CornerRadius {
        /// 1.5pt — thin dividers and borders.
        static let hairline: CGFloat = 1.5
        /// 2pt — tight rounding for compact items like calendar event rows.
        static let tiny: CGFloat = 2
        /// 4pt — small badges and priority pills.
        static let badge: CGFloat = 4
        /// 8pt — buttons, form fields, and moderate-rounding elements.
        static let standard: CGFloat = 8
        /// 12pt — cards and shimmer placeholders.
        static let card: CGFloat = 12
        /// 16pt — day spread content and section backgrounds.
        static let section: CGFloat = 16
        /// 20pt — large containers such as the entry list rounded rectangle.
        static let large: CGFloat = 20
    }

    // MARK: - Motion

    /// Named animation constants. Named `Motion` to avoid shadowing SwiftUI's `Animation` type.
    enum Motion {
        /// Fast feedback animations (150ms ease-in-out).
        static let quick: Animation = .easeInOut(duration: 0.15)
        /// Default transition animations (250ms ease-in-out).
        static let standard: Animation = .easeInOut(duration: 0.25)
        /// Springy bounce for interactive elements.
        static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.7)
    }

    // MARK: - Opacity

    /// Named opacity levels for consistent translucency across the app.
    enum Opacity {
        /// 0.08 — very subtle highlights, e.g. migration destination backgrounds.
        static let hint: Double = 0.08
        /// 0.12 — light fills, e.g. calendar today background.
        static let subtle: Double = 0.12
        /// 0.35 — moderate fills, e.g. dot grid and disabled states.
        static let muted: Double = 0.35
        /// 0.34 — today emphasis border tint.
        static let todayBorder: Double = 0.34
        /// 0.95 — near-opaque fills, e.g. today emphasis surfaces.
        static let strong: Double = 0.95
    }

    // MARK: - Icon Size

    /// Standard icon sizes for SF Symbols and custom icons.
    enum IconSize {
        /// 14pt — compact icons in dense layouts.
        static let small: CGFloat = 14
        /// 18pt — standard inline icons.
        static let medium: CGFloat = 18
        /// 22pt — prominent icons in toolbars and actions.
        static let large: CGFloat = 22
        /// 28pt — display icons in headers and empty states.
        static let extraLarge: CGFloat = 28
    }
}

// MARK: - View Extensions

extension View {
    /// Applies the paper tone background without dot grid.
    /// Use for navigation chrome, settings, and sheets.
    func paperBackground() -> some View {
        background(SpreadTheme.Paper.primary)
    }

    /// Applies the secondary paper tone background.
    /// In dark mode, uses system secondary background.
    func secondaryPaperBackground() -> some View {
        background(SpreadTheme.Paper.secondary)
    }
}
