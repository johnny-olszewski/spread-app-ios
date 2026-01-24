import SwiftUI

/// Theme definitions for the Spread app.
///
/// Provides consistent colors, typography, and styling across the app.
/// Spread content surfaces use dot grid on paper tone; navigation chrome
/// uses flat paper tone without dots.
enum SpreadTheme {

    // MARK: - Colors

    /// Paper tone colors for backgrounds.
    enum Paper {
        /// Warm off-white paper color for content backgrounds.
        /// Hex: #F7F3EA
        static let primary = Color(red: 247/255, green: 243/255, blue: 234/255)

        /// Slightly darker paper tone for secondary surfaces.
        static let secondary = Color(red: 240/255, green: 236/255, blue: 227/255)

        /// System background fallback when paper tone isn't appropriate.
        static let system = Color(.systemBackground)
    }

    /// Accent color for interactive elements.
    enum Accent {
        /// Muted blue accent color for controls and highlights.
        /// Hex: #5B7A99
        static let primary = Color(red: 91/255, green: 122/255, blue: 153/255)
    }

    /// Dot grid colors.
    enum DotGrid {
        /// Neutral gray dot color at ~15-20% opacity.
        static let dots = Color.gray.opacity(0.18)
    }

    // MARK: - Typography

    /// Typography definitions for headings and body text.
    enum Typography {
        /// Heading font - distinct sans family for titles.
        static func heading(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .custom("Avenir Next", size: size).weight(weight)
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
    func secondaryPaperBackground() -> some View {
        background(SpreadTheme.Paper.secondary)
    }
}
