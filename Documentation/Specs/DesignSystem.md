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

### Typography System Standardization (SPRD-268)

Formalizes `SpreadTheme.Typography` around Apple's own 11-step Dynamic Type scale (the same one SwiftUI models natively via `Font.TextStyle`, and what Dynamic Type/VoiceOver text-size scaling is built on) as the permanent foundation, replaces the heading font family, and migrates every direct/ad hoc font usage in the app onto it. Builds directly on SPRD-267's Fuzzy Bubbles `largeTitle` work, which is retained unchanged and folded into this task's acceptance criteria.

- **Complete the 11-style scale**: `largeTitle`, `title`, `title2`, `title3`, `headline`, `body`, `callout`, `subheadline`, `footnote`, `caption`, `caption2`. `headline` is the one style currently missing from `SpreadTheme.Typography` despite already being used directly (and inconsistently) in at least 4 files (`EventDetailPopoverView`, `QuickAddPopoverContent`, `SpreadsNavigatorView+CalendarGenerator`, `CollectionsListView`).
- **Heading font family changes to Mulish**: `title`/`title2`/`title3` and the `heading(size:weight:)` function move from Avenir Next to a newly-bundled **Mulish** (Google Fonts, OFL-licensed — same sourcing pattern as SPRD-267's Fuzzy Bubbles). Chosen specifically because it's an embeddable, OFL-licensed font (works identically on every platform) rather than an Apple-only system font — directly serves the "scalable, portable design system" goal, instead of a font choice tied to one platform's font catalog.
- **`largeTitle` is unchanged**: stays on Fuzzy Bubbles per SPRD-267 — a deliberate exception, not an oversight. Two distinct non-system fonts in the scale (Fuzzy Bubbles for the one hero moment, Mulish for the rest of the heading hierarchy) is intentional, not a consistency gap to close.
- **Body/supporting text is unchanged**: `body`/`callout`/`subheadline`/`footnote`/`caption`/`caption2` stay on SwiftUI's system Dynamic Type styles (not fixed point sizes, not Mulish) — preserves automatic accessibility text-size scaling, per the decision already made in SPRD-267.
- **App-wide migration**: every existing direct/raw font usage that bypasses `SpreadTheme.Typography` (e.g. `.font(.body)`, `.font(.headline)`, `.font(.title2.weight(.semibold))`) is migrated to the equivalent `SpreadTheme.Typography.*` member, across all ~24 affected files. This is the part that actually delivers "standardized" rather than just "available."
- **Enforcement**: documentation + code review only for this task — no SwiftLint custom rule. The convention ("always use `SpreadTheme.Typography`, never a raw system text style") is documented in `CLAUDE.md`'s Code Style Guide (Patterns section) and here; automated enforcement is an explicitly deferred follow-up, not part of this task's scope.
- **Migration complete**: every direct/raw font usage that bypassed `SpreadTheme.Typography` (`.font(.body)`, `.font(.headline)`, `.font(.title2.weight(.semibold))`, `.font(.title2.bold())`, weight-modified variants, etc.) across 36 files — including `Spread/Debug/*` — was migrated to the equivalent `SpreadTheme.Typography.*` member. `.font(.system(size:))` usages for fixed-pixel, non-hierarchy UI (calendar grid digits, etc.) were intentionally left as-is — they're not part of the Dynamic Type scale this task standardizes.

### Decision: Map Mulish weights to explicit named-instance PostScript names, not `.weight()` chaining

- **Context**: The existing `heading(size:weight:)` did `Font.custom("Avenir Next", size: size).weight(weight)` — works because Avenir Next is system-installed and iOS resolves the weight within one family at render time. Checked the actual `google/fonts` source for Mulish before assuming an implementation: unlike SPRD-267's Fuzzy Bubbles (two separate static files), Mulish ships as a **single variable font** (`Mulish[wght].ttf`, continuous `wght` axis 200–1000) with named instances at standard weight stops (Regular/Medium/SemiBold/Bold/etc.) — so in principle `.weight()` chaining might work here in a way it provably doesn't for separate static files.
- **Decision**: Bundled the one variable font file (`Mulish-Variable.ttf`), but still mapped each requested `Font.Weight` to an explicit named-instance PostScript name (e.g. `MulishRoman-SemiBold`) rather than chaining `.weight()` onto `Font.custom("Mulish", size:)`. The exact instance names were confirmed empirically via a temporary diagnostic test (`UIFont.fontNames(forFamilyName: "Mulish")`) rather than guessed — CoreText resolves this font's instances as `MulishRoman-{Weight}`, not `Mulish-{Weight}`, which would not have been a safe assumption.
- **Rationale**: `.weight()` chaining on a *third-party* variable font's reliability varies across iOS/SwiftUI versions in ways that are harder to verify than an explicit, tested name lookup; explicit PostScript-name mapping is the already-proven pattern from SPRD-267's `largeTitle`, and is now empirically verified to work for Mulish's specific instance naming too (`SpreadThemeTests.swift` asserts each instance registers and that `heading(size:weight:)` resolves the right one).
- **SPRD reference**: SPRD-268

### Icon System: SF Symbols → Phosphor (SPRD-269)

Replaces every SF Symbol icon in the app (`Image(systemName:)`, `Label(_:systemImage:)`, `Tab(_:systemImage:value:)`, and every type exposing a `String` SF Symbol name as a computed property) with the bundled-font **Phosphor** icon set, behind a new `SpreadTheme.Icon` namespace — the same "single source of truth" pattern `SpreadTheme.Typography` established for fonts in SPRD-267/268.

- **Dependency**: [`phosphor-icons/swift`](https://github.com/phosphor-icons/swift) (official Phosphor SwiftUI port, MIT-licensed, product name `PhosphorSwift`), added as a remote SPM package directly in `Spread.xcodeproj/project.pbxproj` (`XCRemoteSwiftPackageReference`/`XCSwiftPackageProductDependency` — same mechanism already used for `supabase-swift`; there is no `Package.swift` in this repo). Pinned to `upToNextMajorVersion` from `2.0.0`.
- **API shape**: Phosphor exposes a `Ph` enum where each icon is a computed `Image` per weight, e.g. `Ph.star.regular`, `Ph.star.fill`. Color is applied via `.color(_: Color)` (a color-mask `ViewModifier`), not `.foregroundStyle`/`.tint`. Images are already `.resizable()`.
- **Scope**: All ~99 SF Symbol call sites across ~41 files, including `Spread/Debug/*` (DebugMenuView, DebugRepositoryListView) — full consistency, no carve-out for dev-only tooling.

### Decision: `SpreadTheme.Icon` namespace, not inline 1:1 replacement

- **Context**: SF Symbol identity is scattered across the app as raw `String`s — some inline (`Image(systemName: "star")`), some as computed properties on existing types (`SyncStatus.systemImage`, `ConvenienceNavigationButtonState.systemImage`, `RootNavigationView+Content`'s tab icons, `Action`'s menu-label icons, `EntryListOptionsPicker.Config`, `DebugRepositoryListView`'s per-entity-type icon helpers). A literal find/replace would just substitute one scattered string format for another.
- **Decision**: Add `SpreadTheme.Icon`, a semantic enum (e.g. `.star`, `.starFilled`, `.delete`, `.calendar`, `.checkmark`, ...) where each case resolves to a Phosphor `Image` at a default weight. Every file/type currently exposing a raw SF Symbol `String` is migrated to return/use `SpreadTheme.Icon` (or its resolved `Image`) instead.
- **Rationale**: Matches the established `SpreadTheme.Typography` precedent exactly — one place to see/change the full icon set, rather than icon choice staying scattered (just in a different vocabulary).
- **SPRD reference**: SPRD-269

### Decision: Weight mapping from SF Symbol variants

- **Context**: SF Symbols here are used in two weight-like states: a plain outline (`star`, `circle`, `checkmark`) and an explicit `.fill` variant (`star.fill`, `circle.fill`, `arrow.right.circle.fill`) for filled/active states. Phosphor offers six weights (`thin`, `light`, `regular`, `bold`, `fill`, `duotone`).
- **Decision**: SF Symbol outlines map to Phosphor `.regular`; existing `*.fill` SF Symbols map to Phosphor `.fill`. No use of `.thin`/`.light`/`.bold`/`.duotone` in this task.
- **Rationale**: Closest visual/semantic match to the current two-state (outline vs. filled) convention already used throughout the app (favorite star, status circles, etc.) — doesn't introduce a third weight axis that nothing in the app currently models.
- **SPRD reference**: SPRD-269

### Decision: `Tab`/`Label` SF-Symbol-only initializers

- **Context**: SwiftUI's `Tab(_:systemImage:value:)` (used in `RootNavigationView`'s `TabView`) and `Label(_:systemImage:)` (used in `SpreadHeaderView`, `Action`'s menu labels, `DebugRepositoryListView`) take a symbol-name `String`, not an arbitrary `Image` — incompatible with Phosphor's `Image`-returning API.
- **Decision**: These call sites switch to the `Image`-based label-closure forms (`Tab(_:value:) { }` / `Label { Text(...) } icon: { SpreadTheme.Icon.x.image }`) so the tab bar and labeled rows can use Phosphor too, for full consistency rather than carving out an SF-Symbol-only exception.
- **SPRD reference**: SPRD-269

### Decision: Explicit sizing/tinting on `SpreadTheme.Icon` (`.sized(_:)`/`.iconTint(_:)`)

- **Context**: Discovered mid-implementation that Phosphor icons (`Ph.<name>.<weight>`) are plain resizable `Image`s — unlike SF Symbols, they have no ambient relationship to surrounding `.font()` size and don't respond to `.foregroundStyle()`/`.tint()`. Most existing call sites relied on exactly this implicit behavior (an `Image(systemName:)` with no explicit size inside a `Label`/`HStack` next to `Text` just matched the ambient text size automatically).
- **Decision**: Added `SpreadTheme.Icon.sized(_:)` (explicit square frame, defaulting to `SpreadTheme.IconSize.medium`) and a local `.iconTint(_:)` view modifier — a from-scratch re-implementation of PhosphorSwift's own `.color(_:)` color-mask blend, kept inside `SpreadTheme+Icon.swift` rather than re-exposing PhosphorSwift's modifier — so call sites depend only on `SpreadTheme.Icon` and never need to `import PhosphorSwift` directly.
- **Also discovered**: SwiftUI's `.symbolEffect(.rotate:)` (used by `SyncIconButton`'s spinning sync icon) is SF-Symbol-only and has no Phosphor equivalent. Replaced with a manual `.rotationEffect` driven by a `repeatForever` linear animation toggled on/off via `.onChange(of: isSpinning)`.
- **Rationale**: Every migrated call site now makes an explicit sizing/coloring decision instead of silently losing implicit behavior that doesn't carry over from SF Symbols. This is also why "no visual regression" is the one AC left unchecked — it requires manual visual QA per call site, which an LLM can't substitute for.
- **SPRD reference**: SPRD-269

### Spread Header Toolbar Integration

The dedicated spread action row in `SpreadHeaderView` (sync ring + favorite button + ellipsis menu) is eliminated in favour of native nav bar toolbar placement: [SPRD-220]

- **Sync icon** (`.topBarLeading`): An SF Symbol button replacing the custom `SyncRingView` ring. Uses `arrow.triangle.2.circlepath` for idle and syncing states; `exclamationmark.arrow.triangle.2.circlepath` for error. The icon rotates continuously during active sync and is static at all other times. Hidden when sync is local-only. Color follows the same semantic conventions as the existing sync ring (accent for syncing, orange for error, muted secondary for idle/offline).
- **Spread actions menu** (`.topBarTrailing`): The `ellipsis.circle` menu button moves to the nav bar trailing slot. Favorite is no longer a standalone button — it is the first item in the menu. "Add to Favorites" (star symbol) appears when the spread is not favorited; "Remove from Favorites" (star.fill symbol) appears when it is. The remaining actions (Edit Name, Edit Dates, Delete Spread) follow in the existing order.
- **Go Back button**: The inline "Go Back" affordance used during peek-initiated navigation remains in the content area of `SpreadHeaderView` and is unaffected by this change.
