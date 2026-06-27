# Design System

> Source: Documentation/spec.md

### Visual Design
- Minimal, clean, paper-like presentation optimized for readability.
- Spread content surfaces use a dot grid background; navigation chrome, settings, and sheets use a flat paper tone without dots. [SPRD-62]
- Light mode paper tone: warm off-white (approx #F7F3EA). [SPRD-62]
- Dark mode paper tone: warm dark variant (approx #1C1A18); navigation chrome uses system secondary background. [SPRD-62]
- Dot grid defaults: 1.5pt dots, 20pt spacing, muted blue color at ~20-25% opacity (same color in both modes); first dot inset equals spacing; configurable via Debug overrides. [SPRD-62, SPRD-63]
- Typography: sans-first; headings use a distinct sans family (e.g., Avenir Next), body uses system sans for legibility; heading font is swappable in Debug for testing. [SPRD-62, SPRD-63]
- Accent color: muted blue (e.g., #5B7A99) for interactive controls and highlights. [SPRD-62]
- Card/list styling stays light: hairline dividers or subtle borders, minimal shadows, and consistent spacing. [SPRD-62]

---

## UI Polish and Design System Foundation (WKFLW-20)

### Design System

`SpreadTheme` is the single source of truth for all visual tokens. WKFLW-20 expands it beyond its original colors, typography, and spacing to include: [SPRD-213]

- **Palette system**: three named palettes (`ocean`, `forest`, `ink`) each defining adaptive light/dark paper tones, accent colors, and today emphasis colors. The active palette is resolved from the `-SpreadPalette` launch argument (UserDefaults key `SpreadPalette`), defaulting to `ocean`. All three options are pre-configured as disabled launch arguments in every Xcode scheme for one-click switching.
- **Corner radius tokens** (`SpreadTheme.CornerRadius`): named constants from `hairline` (1.5 pt) to `large` (20 pt) replacing scattered magic numbers.
- **Motion tokens** (`SpreadTheme.Motion`): `quick`, `standard`, and `spring` animation constants.
- **Opacity tokens** (`SpreadTheme.Opacity`): `hint`, `subtle`, `muted`, `todayBorder`, and `strong` levels.
- **Icon size tokens** (`SpreadTheme.IconSize`): `small` through `extraLarge` SF Symbol sizing constants.

### Dark Mode

All app surfaces must render correctly in both light and dark mode using `SpreadTheme` color tokens. Hardcoded `Color` literals and raw hex values in view files must be replaced with theme tokens or semantic system colors. The dot grid, paper backgrounds, accent surfaces, entry row icons, and badge colors are the highest-priority areas. [SPRD-214]

### Launch Experience

The app startup loading screen must show the app name or wordmark rather than a generic `ProgressView("Loading...")`. The loading state should clearly communicate that the app is initializing, not broken. [SPRD-215]

### Sheet Presentation Consistency

All modal sheets (task creation, note creation, spread creation, auth sheets, profile) must follow a consistent pattern: [SPRD-216]
- Navigation title and toolbar action placement (leading Cancel / trailing primary action).
- Primary action button disabled during loading.
- Error feedback via `.alert` or inline text — no silent failures.
- `interactiveDismissDisabled` applied where user data would be lost on accidental dismissal.

### Toolbar and Action Button Standards

All toolbar buttons must meet minimum 44 pt tap-target requirements. Icon choices must be consistent across spread types for the same action (e.g., create, migrate, favorite). [SPRD-217]

### Accessibility Labels

Entry rows and icon-only action buttons are the highest-priority accessibility surfaces for TestFlight: [SPRD-218]

- **Entry rows** (`EntryRowView`): `.accessibilityLabel` must combine title, type (task/note), and status (open, complete, migrated, cancelled). `.accessibilityValue` exposes priority (if non-none) and due date (if set).
- **Icon-only buttons**: Status toggle, create, migrate, delete, and favorite buttons must have `.accessibilityLabel` values that clearly identify the action. Button role (`.destructive` for delete) must be set where appropriate.

### Large Title / "h1" Font (SPRD-267)

`SpreadTheme.Typography.largeTitle(size:weight:)` uses the bundled **Fuzzy Bubbles** font (Google Fonts, OFL-licensed; files + license at `Spread/Resources/Fonts/`, registered via `Info.plist`'s `UIAppFonts`) instead of Avenir Next, for a more playful large-title/"h1" treatment. Scoped to `largeTitle` only — `title`/`title2`/`title3` stay Avenir Next via the existing `heading(size:weight:)` function.

- **Decision**: `largeTitle` changed from a fixed `static var` to a `static func largeTitle(size: CGFloat = 28, weight: Font.Weight = .bold) -> Font`, so callers can request any size instead of being locked to 28pt.
- **Rationale**: Fuzzy Bubbles ships as two static font files (`FuzzyBubbles-Regular`/`FuzzyBubbles-Bold`), not a variable font — there's no continuous weight axis for `.weight()` to dial, so the function selects between the two bundled PostScript names directly. Any `weight` other than `.bold` falls back to Regular.
- **Body/supporting text**: `Typography.body`/`subheadline`/`caption` (existing) plus newly added `callout`/`footnote`/`caption2` all use SwiftUI's system Dynamic Type styles (`.callout`, `.footnote`, `.caption2`), not fixed point sizes — preserves automatic scaling with the user's text-size accessibility setting.

### Spread Header Toolbar Integration

The dedicated spread action row in `SpreadHeaderView` (sync ring + favorite button + ellipsis menu) is eliminated in favour of native nav bar toolbar placement: [SPRD-220]

- **Sync icon** (`.topBarLeading`): An SF Symbol button replacing the custom `SyncRingView` ring. Uses `arrow.triangle.2.circlepath` for idle and syncing states; `exclamationmark.arrow.triangle.2.circlepath` for error. The icon rotates continuously during active sync and is static at all other times. Hidden when sync is local-only. Color follows the same semantic conventions as the existing sync ring (accent for syncing, orange for error, muted secondary for idle/offline).
- **Spread actions menu** (`.topBarTrailing`): The `ellipsis.circle` menu button moves to the nav bar trailing slot. Favorite is no longer a standalone button — it is the first item in the menu. "Add to Favorites" (star symbol) appears when the spread is not favorited; "Remove from Favorites" (star.fill symbol) appears when it is. The remaining actions (Edit Name, Edit Dates, Delete Spread) follow in the existing order.
- **Go Back button**: The inline "Go Back" affordance used during peek-initiated navigation remains in the content area of `SpreadHeaderView` and is unaffected by this change.
