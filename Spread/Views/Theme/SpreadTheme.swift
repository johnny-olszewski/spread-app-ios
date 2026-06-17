import SwiftUI
import Foundation

/// Theme definitions for the Spread app.
///
/// Provides consistent colors, typography, and styling across the app.
/// Spread content surfaces use dot grid on paper tone; navigation chrome
/// uses flat paper tone without dots. Supports both light and dark modes.
enum SpreadTheme {

    // MARK: - Colors

    /// Paper tone colors for spread content and navigation chrome backgrounds.
    /// Light: warm off-white. Dark: warm dark tone for content, system background for chrome.
    enum Paper {
        /// Primary paper color for spread content backgrounds.
        /// Light: #F7F3EA  Dark: #1C1A18
        static let primary = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 28/255, green: 26/255, blue: 24/255, alpha: 1)
                : UIColor(red: 247/255, green: 243/255, blue: 234/255, alpha: 1)
        })

        /// Secondary paper tone for navigation chrome.
        /// Light: #F0ECE3  Dark: system secondary background.
        static let secondary = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? .secondarySystemBackground
                : UIColor(red: 240/255, green: 236/255, blue: 227/255, alpha: 1)
        })

        /// System background fallback when paper tone isn't appropriate.
        static let system = Color(.systemBackground)
    }

    /// Accent colors for interactive elements, emphasis, and highlights.
    enum Accent {
        /// Muted blue for controls and highlights.
        /// Light/Dark: #5B7A99
        static let primary = Color(red: 91/255, green: 122/255, blue: 153/255)

        /// Vibrant blue for "today" emphasis across spread surfaces.
        /// Light: SpreadPalette.blue500  Dark: SpreadPalette.blue300
        static let today = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color.SpreadPalette.blue300)
                : UIColor(Color.SpreadPalette.blue500)
        })

        /// Warm yellow surface for the currently selected spread.
        /// Light: SpreadPalette.yellow100  Dark: SpreadPalette.yellow300
        static let selectionSurface = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color.SpreadPalette.yellow300)
                : UIColor(Color.SpreadPalette.yellow100)
        })

        /// Stronger border tint paired with `selectionSurface`.
        /// Light: SpreadPalette.yellow500  Dark: SpreadPalette.yellow200
        static let selectionBorder = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color.SpreadPalette.yellow200)
                : UIColor(Color.SpreadPalette.yellow500)
        })
    }

    /// Dot grid color for spread content surfaces.
    enum DotGrid {
        /// Muted blue dot at 35% opacity.
        static let defaultDots = Accent.primary.opacity(0.35)
    }

    // MARK: - Typography

    /// Typography definitions for headings and body text.
    enum Typography {
        /// Heading font — distinct sans family for titles.
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
        /// Uses `Color(.label)` at 20% so it is visible in both light and dark mode.
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
        /// 16pt — day spread content, section backgrounds, and spread card surfaces.
        static let section: CGFloat = 16
        /// 20pt — large containers such as the entry list rounded rectangle.
        static let large: CGFloat = 20
        /// 48pt — xxl containers like the pager top corner radius.
        static let xxlarge: CGFloat = 48
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
