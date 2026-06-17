import SwiftUI

extension Color {
    /// Named color scale for the Spread app.
    ///
    /// Values follow a 100–700 scale where 100 is lightest and 700 is darkest.
    /// These are raw static colors — not adaptive. Adaptive combinations are
    /// built at the usage site (e.g., `SpreadTheme.Accent` or `SpreadCardStyle`).
    enum SpreadPalette {

        // MARK: - Yellow (Selection Surface)

        /// `#FFF8D0` — lightest warm yellow; today card fill in light mode
        static let yellow100 = Color(red: 255/255, green: 248/255, blue: 208/255)
        /// `#FFF3BE` — light warm yellow; today border in dark mode
        static let yellow200 = Color(red: 255/255, green: 243/255, blue: 190/255)
        /// `#F7EAA4` — medium-light warm yellow; today card fill in dark mode
        static let yellow300 = Color(red: 247/255, green: 234/255, blue: 164/255)
        /// `#E6D481` — medium warm yellow
        static let yellow400 = Color(red: 230/255, green: 212/255, blue: 129/255)
        /// `#D4BD5E` — golden yellow; today border in light mode
        static let yellow500 = Color(red: 212/255, green: 189/255, blue: 94/255)
        /// `#B8A040` — dark gold
        static let yellow600 = Color(red: 184/255, green: 160/255, blue: 64/255)
        /// `#9C862C` — deep gold
        static let yellow700 = Color(red: 156/255, green: 134/255, blue: 44/255)

        // MARK: - Blue (Today Accent)

        /// `#6B9FD4` — today accent in dark mode
        static let blue300 = Color(red: 107/255, green: 159/255, blue: 212/255)
        /// `#588CC6` — medium-light blue
        static let blue400 = Color(red: 88/255, green: 140/255, blue: 198/255)
        /// `#4578B8` — today accent in light mode
        static let blue500 = Color(red: 69/255, green: 120/255, blue: 184/255)
        /// `#3664A0` — medium-dark blue
        static let blue600 = Color(red: 54/255, green: 100/255, blue: 160/255)
        /// `#2A548C` — dark blue
        static let blue700 = Color(red: 42/255, green: 84/255, blue: 140/255)
    }
}
