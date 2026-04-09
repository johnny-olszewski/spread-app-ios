import SwiftUI

/// Theme definitions for the Spread app.
///
/// Provides consistent colors, typography, and styling across the app.
/// Spread content surfaces use dot grid on paper tone; navigation chrome
/// uses flat paper tone without dots. Supports both light and dark modes.
enum SpreadTheme {

    // MARK: - Colors

    /// Paper tone colors for backgrounds.
    /// Light mode: warm off-white tones.
    /// Dark mode: warm dark tones for content, system backgrounds for chrome.
    enum Paper {
        /// Default primary paper color for spread content backgrounds.
        /// Light: warm off-white (#F7F3EA)
        /// Dark: warm dark variant (#1C1A18)
        static let defaultPrimary = Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 28/255, green: 26/255, blue: 24/255, alpha: 1)
                    : UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
            }
        )

        /// Primary paper color, using debug overrides when available.
        static var primary: Color {
            #if DEBUG
            return debugPrimary
            #else
            return defaultPrimary
            #endif
        }

        /// Secondary paper tone for navigation chrome.
        /// Light: slightly darker warm tone
        /// Dark: system secondary background
        static let secondary = Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? .secondarySystemBackground
                    : UIColor(red: 240/255, green: 236/255, blue: 227/255, alpha: 1)
            }
        )

        /// System background fallback when paper tone isn't appropriate.
        static let system = Color(.systemBackground)
    }

    /// Accent color for interactive elements.
    enum Accent {
        /// Default muted blue accent color for controls and highlights.
        /// Hex: #5B7A99
        static let defaultPrimary = Color(red: 91/255, green: 122/255, blue: 153/255)

        /// Primary accent color, using debug overrides when available.
        static var primary: Color {
            #if DEBUG
            return debugPrimary
            #else
            return defaultPrimary
            #endif
        }

        /// More vibrant blue used for passive today emphasis.
        static let defaultTodayEmphasis = Color(red: 69/255, green: 120/255, blue: 184/255)

        /// Passive today emphasis color for unselected contextual highlighting.
        static var todayEmphasis: Color {
            #if DEBUG
            return debugPrimary.opacity(0.95)
            #else
            return defaultTodayEmphasis.opacity(0.95)
            #endif
        }

        /// Stronger today emphasis color when the today item is also selected.
        static var todaySelectedEmphasis: Color {
            #if DEBUG
            return debugPrimary
            #else
            return defaultTodayEmphasis
            #endif
        }

        /// Border tint for today emphasis on passive surfaces.
        static var todayEmphasisBorder: Color {
            todaySelectedEmphasis.opacity(0.34)
        }

        /// Passive grey used to indicate a multiday day without an explicit day spread.
        static let uncreatedDayText = Color.secondary.opacity(0.72)

        /// Background tint for uncreated multiday day cards.
        static let uncreatedDayFill = Color.secondary.opacity(0.07)

        /// Border tint for uncreated multiday day cards.
        static let uncreatedDayBorder = Color.secondary.opacity(0.2)
    }

    /// Dot grid colors.
    enum DotGrid {
        /// Default muted blue dot color at ~35% opacity.
        /// Same color in both light and dark modes for consistency.
        static let defaultDots = Color(red: 91/255, green: 122/255, blue: 153/255).opacity(0.35)

        /// Dot color, using debug overrides when available.
        static var dots: Color {
            #if DEBUG
            return debugDots
            #else
            return defaultDots
            #endif
        }
    }

    // MARK: - Typography

    /// Typography definitions for headings and body text.
    enum Typography {
        /// Heading font - distinct sans family for titles.
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
        static var body: Font {
            .body
        }

        /// Subheadline text.
        static var subheadline: Font {
            .subheadline
        }

        /// Caption text.
        static var caption: Font {
            .caption
        }
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

        /// Horizontal gap between the status icon and entry title.
        static let entryIconSpacing: CGFloat = 8
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
