# Spread Navigation

> Source: Documentation/spec.md  
> **SPRD tasks**: SPRD-125, SPRD-126, SPRD-143, SPRD-148, SPRD-199, SPRD-229, SPRD-230, SPRD-232, SPRD-236, SPRD-238, SPRD-244, SPRD-275, SPRD-283, SPRD-284

### Spread View Architecture
- The spread shell should converge on a single top-level `SpreadsView` rather than separate conventional and traditional root view trees. [SPRD-163, SPRD-164, SPRD-165]
- `SpreadsView` should assemble:
  - `SpreadTitleNavigatorView`
  - `SpreadContentPagerView`
  - shared sheet presentation
  - shared bottom controls [SPRD-163]
- Any legacy `ConventionalSpreadsView` and `TraditionalSpreadsView` split views should be removed. [SPRD-163, SPRD-165]
- A `SpreadsViewModel` should own spread-shell UI state only, such as:
  - current selection
  - recenter token
  - active sheet
  - shell-level control state [SPRD-163]
- `SpreadsViewModel` should not become a replacement business-logic owner. Journal mutations and journal-derived data remain sourced from `JournalManager`. [SPRD-163, SPRD-164, SPRD-165]
- `SpreadTitleNavigatorView` should depend on a new `SpreadTitleNavigatorProviding` protocol rather than mode-specific root-view wiring. [SPRD-164]
- `JournalManager` should conform to `SpreadTitleNavigatorProviding`, with the conformance placed in `JournalManager+SpreadTitleNavigatorProviding.swift`. [SPRD-164]
- `JournalManager` should provide the title navigator model and items for conventional mode. [SPRD-164]
- `SpreadContentPagerView` should own page assembly for the shared spread shell. [SPRD-165]
- `SpreadContentPagerView` should assemble, inside the horizontal pager, one page per spread item consisting of:
  - `SpreadHeaderView`
  - one spread-type content view matching the spread period [SPRD-165]
- Spread-type content views should be:
  - `YearSpreadContentView`
  - `MonthSpreadContentView`
  - `DaySpreadContentView`
  - `MultidaySpreadContentView` [SPRD-165]
- Those spread-type content views are content renderers, not full pages. The header remains outside them and is assembled by `SpreadContentPagerView`. [SPRD-165]
- Spread-type content views should receive fully prepared display models. They should not derive mode-specific journal inclusion rules by querying `JournalManager` directly. [SPRD-165]
- Actions may still be passed to lower-level components as closures, but the same closure should not be threaded through multiple layers redundantly. If a deeply nested component needs shared shell/journal behavior, it should prefer access through `SpreadsViewModel` and/or `JournalManager`. [SPRD-163, SPRD-165]
- `SpreadSurfaceView` should be removed if its responsibilities are fully absorbed by `SpreadContentPagerView` and the new spread-type content views. [SPRD-165]
- This refactor is intended as an initial shell/content consolidation pass. It should preserve current user-visible spread behavior, then be reevaluated for follow-up scope once the shared shell is in place. [SPRD-163, SPRD-164, SPRD-165]

---

### Navigation and UI
- Spread navigation uses an in-view hierarchical tab bar on both iPad and iPhone; it handles navigation between spreads only. [SPRD-19, SPRD-25]
- The app includes a top-level search-role tab that presents a global task browser. [SPRD-148]
- The search tab is tasks-only in v1; notes and other result types are deferred. [SPRD-148]
- The search screen includes a real search field from day one. [SPRD-148]
- Entering the search tab should require only one press before the user can type: selecting the `Search` tab presents the search field ready for text entry. [SPRD-148]
- The search field should remain visibly present at the top of the search screen rather than requiring a second toolbar/search affordance press to reveal it. [SPRD-148]
- Search results are grouped into hidden-when-empty sections:
  - `Inbox` first.
  - Remaining sections follow the spread ordering model from `SpreadTitleNavigatorView`. [SPRD-148]
- The global task browser uses the complete spread ordering model. There is no compact-bar-specific filtering layer that can hide or reorder search sections. [SPRD-176]
- Each task appears exactly once in search, under the spread where it is currently shown. Migrated historical entries are excluded. [SPRD-148]
- Tapping a search result navigates to the task's current spread and then opens the task edit sheet there. [SPRD-148]
- Spread context bar behavior: [SPRD-126, SPRD-177]
  - Periods shown remain year → month → (day, multiday); no week period. [SPRD-8, SPRD-126]
  - The context bar replaces both the old top spread selection bar and the exploratory inline scrolling title strip. It becomes the primary persistent spread-navigation chrome on both iPhone and iPad. [SPRD-126]
  - The context bar is not a horizontal browse surface. It renders only the current selection's compact identity and delegates full chronological browsing to the rooted navigator surface. [SPRD-125, SPRD-126, SPRD-177]
  - A fixed leading chevron affordance opens the rooted spread navigator. The affordance remains visible at all times and does not scroll independently from the rest of the bar. [SPRD-177]
  - The context area shows the current spread only:
    - a primary label for the current display title
    - compact secondary canonical date context when needed, especially for personalized spread names
    - no duplicate large header title elsewhere in the spread content surface [SPRD-126, SPRD-129, SPRD-172]
  - The bar must remain compact and stable across modes and widths. It should not reserve centered timeline slots, introduce broad empty gutters, or grow into a tall band when the selected spread changes. [SPRD-126]
  - The bar does not support drag browsing, collapsed hidden groups, recenter buttons, or offscreen-selected proxies because the persistent surface no longer represents the full selected-year sequence inline. [SPRD-127, SPRD-136, SPRD-176, SPRD-198]
  - Today emphasis applies only to the current selected spread shown in the compact bar. Broader passive cross-spread emphasis belongs in the rooted navigator surface. [SPRD-144]
  - A trailing "+" button remains always visible and opens a creation menu (spread or task). [SPRD-23, SPRD-26, SPRD-126]
  - Navigator label refinements: [SPRD-129]
    - The spread content surface removes the duplicate `Spreads` title, while higher-level container navigation titles may remain when needed. [SPRD-129]
    - Personalized labels remain primary when present; canonical date context is shown as secondary support text where space allows. [SPRD-169, SPRD-172]
  - The context bar height is content-driven with a compact visual floor; it must not be hardcoded or allowed to expand to absorb unrelated vertical space from surrounding layout. [SPRD-136]

### Spread Surface Architecture
- The app operates in conventional mode only. There is no mode-switching or mode-branching in the spread surface. [SPRD-226]
- Shell responsibilities: [SPRD-151]
  - render `SpreadTitleNavigatorView`
  - render `SpreadContentPagerView`
  - accept injected shell-control configuration for controls such as `Today`, create actions, and auth actions
- Spread-surface responsibilities: [SPRD-151]
  - render `SpreadHeaderView`
  - render one or more sections
  - render one or more `EntryListView` instances inside those sections
- `EntryListView` responsibilities: [SPRD-151]
  - remain a reusable renderer driven by injected data and configuration
  - support different use cases through configuration, including inline-action configuration
  - avoid direct `JournalManager` reads in the reusable view layer
- Multiday responsibilities: [SPRD-151]
  - a multiday spread is composed from repeated multiday-section components
  - each multiday-section component hosts its own `EntryListView`
- Builders and dependency injection: [SPRD-151]
  - shared UI components should prefer injected data, config, and action closures over direct manager/service access
  - `SpreadDataModel` remains the core domain input
- Conventional spread content is driven by current live assignment only. Spread content does not retain migrated-history rows or source-history sections after an entry has been reassigned elsewhere. [SPRD-186]
- Parent spreads may still organize currently assigned entries into calendar-derived presentation sections. For example, year spreads may organize year-assigned entries under month cards, and month spreads may organize month-assigned day-period entries under day sections, without changing the underlying current assignment. [SPRD-186]

---

### Spread Content Presentation and Interaction
- Main spread task lists use a solid list-container backing while each task row remains visually transparent, so the spread-content dot-grid background remains visible behind the task list. [SPRD-124]
- This transparent-row treatment applies only to the main spread task lists. Auxiliary review sheets such as migration and overdue keep their existing list styling. [SPRD-124]
- In the main spread task lists, tapping the title of a task row activates inline title editing in place. [SPRD-124, SPRD-132]
- While inline editing is active, a "×" cancel button appears in the row. Tapping "×" discards changes and restores the original title. [SPRD-132]
- Tapping outside the row, pressing Return, or the row losing focus commits the edited title. [SPRD-132]
- If the edited title is empty on commit, the change is silently discarded and the original title is restored. [SPRD-132]
- Swipe actions are disabled on a task row while its inline editor is active. [SPRD-132]
- The full task edit sheet (for editing date, period, status, and other fields) remains accessible via the swipe-action Edit button. Tapping the task row no longer opens the full sheet. [SPRD-132]
- Inline title editing applies to tasks in both the standard entry list and the multiday grid. [SPRD-132]
- Note tap behavior is unchanged; inline title editing applies to tasks only in v1. [SPRD-124]
- An "+ Add Task" button appears at the bottom of the task list on every spread. When tapped, it presents a native system alert with a title text field, a Save button, and a Cancel button. [SPRD-133]
- On multiday spreads, each day section has its own "+ Add Task" button at the bottom of that day's task list. [SPRD-133]
- The `+ Add Task` row aligns to the same icon/title columns as standard entry rows: the `+` shares the status-icon column and `Add Task` shares the title column. [SPRD-144]
- Tapping Save in the quick-add alert commits the title if non-empty; an empty title is silently discarded. [SPRD-133]
- Tapping Cancel discards the input. [SPRD-133]
- Tasks created via quick add are assigned to the spread's own period and date — identical to the defaults the full `TaskCreationSheet` applies when that spread is pre-selected. [SPRD-133]
- Quick add applies to tasks only in v1. [SPRD-133]
- For multiday spreads, every calendar day in the spread's covered date range renders a visible day section even when that day has no tasks. [SPRD-124]
- Empty multiday day sections show the day header plus an explicit empty-state message rather than collapsing away. [SPRD-124]
- Multiday day sections show tasks only in v1. Expanding those sections to include notes is deferred to a later version. [SPRD-124]
- On regular-width layouts such as iPad, multiday day sections render in two columns using normal reading-order flow. On compact layouts, they render in a single column. [SPRD-124]
- On multiday spreads, only the section for today's date receives passive today emphasis. Its header text, outline, and card background use the shared configurable today-emphasis color family; other day sections remain unchanged. [SPRD-144]

### Header Spread Navigator
- The fixed leading chevron affordance in the compact spread context bar presents the same rooted spread navigator on both platforms: as a popover on iPad and as a large sheet on iPhone. The current title area may also open the same surface, but it does not expose inline scrolling or alternate navigation behavior. [SPRD-125, SPRD-126, SPRD-177]
- The navigator always presents a single rooted hierarchy view with no push navigation in v1. Current context is revealed by expanded sections inside that rooted view rather than by drilling into another screen. [SPRD-125]
- Years and months are presented as collapsible table rows; month contents are presented as grid tiles within the expanded month section. [SPRD-125]
- Year and month rows use split interaction: row-body tap navigates when the row is a valid destination, while a trailing disclosure expands or collapses that section. Derived conventional rows use disclosure-only behavior. [SPRD-125]
- The hierarchy uses accordion behavior: only one year is expanded at a time, and only one month is expanded within that year. [SPRD-125]
- The month grid always shows calendar day cells. Explicit multiday spreads are shown as decorative row-bounded overlay lanes rather than as separate tiles. [SPRD-125]
- The current spread opens with its year/month context already expanded and is highlighted with a light shape background. [SPRD-125]
- Root years and month rows are derived when child spreads make them navigable, but explicit day spread existence alone controls whether a day cell appears created; multiday coverage is decorative and does not make a day cell appear created by itself. [SPRD-125]
- Keyboard/trackpad-specific navigation enhancements are deferred from the initial implementation. [SPRD-125]
- The rooted navigator surface should be implemented with a separable model/support layer so hierarchy derivation, expansion state, and current-context opening rules can be unit tested independently from the popover/sheet view. [SPRD-125]
- The compact spread context bar should use a separable support/model layer so current-selection title derivation, personalized/canonical secondary context, compact sizing rules, and rooted-navigator trigger behavior can be unit tested independently from the SwiftUI view. [SPRD-126]
- Required coverage includes iPhone and iPad UI tests plus lower-level unit tests for navigator state/data derivation, compact-bar sizing behavior, rooted-navigator opening, recommendations, and pager synchronization. [SPRD-125, SPRD-126, SPRD-137]

---

## Compact Spread Context Bar and Rooted Navigator [SPRD-199]

**Status**: Draft
**Date**: 2026-05-06

### Overview
Replace the persistent horizontal title strip with a compact spread context bar that shows only the current spread and opens a richer rooted navigator surface for all chronological browsing.

### Problem Statement
The inline title strip is trying to serve too many responsibilities at once: current-context display, chronological browsing, filtered visibility, recommendation surfacing, and hidden-range recovery. That produces excessive chrome height, brittle centering behavior, and high implementation complexity without a clear UX payoff.

### Goals
- Keep the persistent spread-navigation chrome compact, stable, and easy to scan
- Preserve fast access to full chronological browsing through the rooted navigator surface
- Move recommendations and passive cross-spread cues into the richer navigator surface where they have room to breathe
- Reduce coupling between current-selection display and timeline-browsing behavior

### Non-Goals
- Reintroducing any inline horizontally scrolling title timeline
- Preserving hidden-group proxy behavior from the old filtered strip design
- Adding a second persistent row of chips, breadcrumbs, or segmented controls in v1

### Functional Requirements
1. The persistent top spread-navigation chrome is a compact context bar, not a horizontally scrolling strip. [SPRD-199]
2. The bar always shows the current selected spread only, with primary title and compact secondary date context as needed. [SPRD-199]
3. The fixed leading chevron opens the rooted navigator surface on both platforms; tapping the current title area may also open the same surface. [SPRD-199]
4. The rooted navigator remains the only full chronological browsing surface in v1. [SPRD-199]
5. Recommended missing explicit year/month/day spreads for today are shown inside the rooted navigator surface in conventional mode rather than beside the persistent bar. [SPRD-199]
6. Pager swipes continue to change the current spread after settle, and the compact bar updates directly to the new selection with no inline recenter behavior. [SPRD-199]
7. The old local title-strip visibility preference is removed because the persistent bar no longer renders a filterable spread sequence. [SPRD-199]

### Technical Design

#### Architecture
- `SpreadTitleNavigatorView.swift` should be simplified into a compact bar view that renders:
  - a fixed rooted-navigator trigger
  - a tappable current-selection title/context region
  - the existing trailing create affordance
- `SpreadTitleNavigatorSupport.swift` should shift from strip-centering and hidden-group support toward compact-label derivation and bar sizing support.
- Recommendation rendering should move into the rooted navigator presentation layer and reuse the existing recommendation provider protocol.

#### State & Data Flow
- The compact bar derives its content from the same current `selection` and `SpreadTitleNavigatorModel`.
- The rooted navigator remains the owner of full-sequence browsing and explicit destination selection.
- The pager remains synchronized by current selection only; there is no separate inline browse position state.

#### Animation
- The compact bar should animate only lightweight current-context transitions, such as text/content swaps and navigator presentation.
- There is no persistent inline horizontal scroll animation path.

#### Edge Cases
- Personalized spread names still show canonical context when needed to avoid ambiguity.
- Long labels should compress gracefully without increasing the bar into a second large chrome band.
- Recommendations can adapt layout by size class inside the rooted navigator without affecting persistent bar height.

#### Security Considerations
None — purely local UI composition and interaction behavior.

#### Testing Strategy
- Unit tests for current-selection title/context derivation and compact sizing rules.
- Unit tests for recommendation derivation remaining independent of the persistent bar implementation.
- UI tests for rooted navigator opening from the chevron and title area, pager-to-bar synchronization, and compact-height behavior on iPhone and iPad.

### Acceptance Criteria
- [ ] The persistent spread-navigation UI no longer renders a horizontally scrolling title timeline.
- [ ] The compact bar remains visually short and does not absorb excess vertical space.
- [ ] The current spread identity remains clear through primary title plus compact secondary context where needed.
- [ ] The rooted navigator remains the complete browsing surface on both iPhone and iPad.
- [ ] Recommendations are visible in the rooted navigator in conventional mode and are no longer rendered as persistent trailing inset cards.
- [ ] Pager swipes keep the compact bar synchronized without any inline recenter or hidden-group behavior.
- [ ] The old local title-strip display preference is removed from settings and supporting state.

---

## Adaptive Navigation Shell [SPRD-229, SPRD-230]

**Status**: Draft
**Date**: 2026-05-31

### Overview

Replace the current `TabView`-wrapping-`NavigationStack` pattern with a `NavigationSplitView` 3-column shell throughout: sidebar (destinations), content column (spread navigator list), detail column (spread pager). SwiftUI handles compact collapse automatically — no explicit size class branching. This eliminates the double-chrome problem on iPad, flattens the nesting hierarchy, and promotes the spread navigator from a hidden popover to a persistent column.

### Problem Statement

`RootNavigationView` uses `TabView` with `.tabViewStyle(.automatic)` wrapping one `NavigationStack` per tab. On iPad (regular horizontal size class) this produces stacked chrome layers — the adaptive tab bar, the `NavigationStack` toolbar, and the `SpreadTitleNavigatorView` context bar — consuming vertical space and making toolbar placement, coordinator wiring, and inspector placement hard to follow. The spread navigator is also hidden behind a chevron tap rather than being persistently available.

### Goals

- Eliminate double-chrome on iPad by switching to `NavigationSplitView`
- Use a single navigation structure for all size classes — let SwiftUI collapse columns naturally on compact
- Promote the spread navigator to a persistent content column on iPad
- Support a full-detail-only mode where both sidebar and content column are hidden
- Bidirectionally sync the horizontal spread pager (detail column) with the spread selection in the content column on iPad
- Ensure the `.inspector()` entry panel renders as a side panel on iPad and a sheet on iPhone

### Non-Goals

- Explicit `TabView` branch for compact size class (removed — NavigationSplitView collapses to stack on iPhone)
- Collapsible sidebar toggle beyond the supported full-detail-only mode
- Changing entry row tap interactions (inline title editing stays per SPRD-132)
- Changing which destinations exist or their icons

### Functional Requirements

1. A single `NavigationSplitView` is used throughout — no explicit size class branching between `TabView` and `NavigationSplitView`. SwiftUI's built-in column collapse handles iPhone. [SPRD-229]
2. The sidebar lists Spreads, Entries, Collections, Settings — and Debug when `BuildInfo.allowsDebugUI` is true. [SPRD-229]
3. The content column (second column) shows the spread picker list (driven by `SpreadPickerModel.items(for:)`) when Spreads is selected. `SpreadPickerButton` is removed from `SpreadsView` — the content column is the only spread picker surface. For other destinations the content column shows that destination's content. [SPRD-229]
4. The detail column (third column) shows `SpreadContentPagerView` for the currently selected spread. [SPRD-229]
5. **Content column selection behavior:** tapping a spread row in the content column (1) sets `selectedSpread`, (2) positions the pager instantly with no scroll animation, (3) always collapses to `columnVisibility = .detailOnly` — even if the tapped spread was already selected. [SPRD-229]
6. **Pager → content column sync:** swiping the pager past a settle threshold updates `selectedSpread`. The content column list reflects the new selection when it is visible. [SPRD-229]
7. **iPhone behavior:** on compact, columns collapse to a navigation stack. The spread picker list is a pushed screen; the spread pager is the next pushed screen. The pager still scrolls horizontally as before. [SPRD-229]
8. **Full-detail-only mode:** tapping a row in the content column automatically collapses to `.detailOnly`. A toolbar button in the detail column restores the content column when the user wants to pick a different spread. [SPRD-229]
9. `spreadsCoordinator`, `spreadsNavigationState`, `selectedSpread`, and `columnVisibility` remain at `RootNavigationView` level and are shared across all column states and size class changes. [SPRD-229]
10. Cross-destination navigation (`openTaskFromSearch` switching to Spreads) works correctly. [SPRD-229]
11. The auth button appears in the detail column toolbar, visible across all destinations. [SPRD-229]
12. The `.inspector()` modifier is removed entirely. `TaskDetailSheet` and `NoteDetailSheet` are presented as `.popover(item:arrowEdge:.trailing)` anchored to the Edit swipe-action button on each entry row. [SPRD-230]
13. All other `SpreadsCoordinator.SheetDestination` cases (spread creation, task creation, note creation, spread name edit, spread date edit, peek data, auth) remain as `.sheet`. [SPRD-230]
14. On compact (iPhone), SwiftUI collapses the `.popover` to a sheet automatically — no manual size-class branching. [SPRD-230]

### Technical Design

#### Architecture

```
RootNavigationView
└── NavigationSplitView (3-column)
    ├── sidebar: List<RootNavigationView.Content> → destination labels
    ├── content: SpreadNavigatorColumn (spread list) | destination content
    └── detail: SpreadContentPagerView (horizontal pager)
        └── .inspector() panel attached here
```

- No `@Environment(\.horizontalSizeClass)` branching at the root level.
- On iPad (regular), all three columns are visible. The content column shows the spread list. The detail column shows the pager.
- On iPhone (compact), SwiftUI collapses the split view: sidebar → content → detail renders as a navigation stack. The spread list is a pushed screen, the pager is the next screen.
- `selectedSpread` is owned at `RootNavigationView` level. The content column's list and the detail pager both bind to it — changes from either side propagate to the other.
- `columnVisibility: NavigationSplitViewVisibility` is owned at `RootNavigationView` level. Full-detail-only mode sets it to `.detailOnly`.

#### Pager ↔ Content Column Sync

- `selectedSpread` is the single source of truth for both the content column list selection and the pager position.
- When the user swipes the pager past a settle threshold, `selectedSpread` is updated to the new visible spread. The content column's `List` selection updates automatically.
- When the user taps a spread row in the content column, `selectedSpread` is updated and the pager jumps (with or without animation) to the matching page.
- On iPhone, only one view is visible at a time so no sync is needed, but the same `selectedSpread` state drives the pager when it's on screen.

#### Full-Detail-Only Mode

- The detail column toolbar has a button (e.g. `sidebar.left` SF Symbol) that sets `columnVisibility = .detailOnly`.
- In `.detailOnly`, both sidebar and content column are hidden. The pager has full screen width — important for day spreads with timeline and entry list side by side.
- The same button (or a `chevron.left` affordance) restores the default visibility.

#### Entry Edit Popover

The `.inspector()` modifier is removed. Task and note detail editing uses `.popover(item:arrowEdge:.trailing)` placed on the entry row's Edit swipe-action button. The popover is anchored directly to the button so the trailing arrow points toward it. On compact (iPhone), SwiftUI automatically collapses the popover to a sheet — no explicit branching. All other sheet destinations remain presented via `.sheet` on `RootNavigationView`.

#### SpreadTitleNavigatorView

The compact spread context bar (`SpreadTitleNavigatorView`) served two roles: showing the current spread identity and opening the rooted navigator. With the content column now being the persistent navigator, this bar's role on iPad reduces to showing current spread identity only. The chevron affordance that opened the navigator popover can be removed on iPad (the content column IS the navigator). On iPhone the bar and its chevron remain as-is since the content column is off-screen.

### Design Decisions

#### Decision: Single NavigationSplitView vs. explicit size-class branch

- **Context**: The previous spec branched between `TabView` (compact) and `NavigationSplitView` (regular) to preserve the iPhone tab bar. The tab bar is an intentional affordance.
- **Decision**: Use a single `NavigationSplitView` throughout. The iPhone tab bar is not preserved in this design — the sidebar collapses into a navigation stack on compact.
- **Rationale**: Prototype testing confirmed the 3-column structure works well and the complexity of maintaining two parallel navigation structures outweighs the loss of the bottom tab bar on iPhone. SwiftUI's collapsed split view provides a coherent navigation stack on iPhone. The sidebar-as-navigation-stack on iPhone is a well-established pattern (Apple Notes, Apple Mail, Craft).
- **SPRD reference**: [SPRD-229]

#### Decision: State ownership during size class transitions

- **Context**: When the device moves between compact and regular (e.g., iPad entering multitasking split view), SwiftUI may not preserve the identity of views deep inside the split view. Child-owned `@State` (e.g., pager position) would reset.
- **Decision**: All navigation state that must survive a size class transition — selected destination, selected spread, pager position, active sheet destination, column visibility — must be owned at `RootNavigationView` level. Child views receive this as bindings or via injected coordinators.
- **Rationale**: This is the only reliable way to guarantee continuity across column collapse/expand. Child `@State` cannot survive view recreation caused by size class changes.
- **SPRD reference**: [SPRD-229]

#### Decision: Select-and-always-collapse content column behavior

- **Context**: The content column is the spread picker. After picking a spread, the user wants to see the spread content — not remain in picker mode. There's also a question of whether re-tapping the current spread should do anything.
- **Decision**: Tapping any row in the content column always sets `columnVisibility = .detailOnly`, regardless of whether the tapped spread is already selected. The pager teleports to the selected spread instantly (no scroll animation).
- **Rationale**: "Always hide on select" makes the content column a deliberate picker — you open it, pick, and it gets out of the way. Re-tapping the current spread is a reasonable "go to this spread" action even when already there. Consistent behavior is simpler than a conditional that sometimes collapses and sometimes doesn't.
- **SPRD reference**: [SPRD-229]

#### Decision: .popover for entry edit, not .inspector

- **Context**: The existing `.inspector()` modifier covers all sheet destinations and renders as a persistent side panel on iPad. The user wants entry editing to feel lighter and directly anchored to the row's Edit button.
- **Decision**: Remove `.inspector()`. Present `TaskDetailSheet` and `NoteDetailSheet` as `.popover(item:arrowEdge:.trailing)` anchored to the Edit swipe-action button. All other sheet destinations remain as `.sheet`.
- **Rationale**: A popover anchored to the Edit button makes the spatial relationship between action and result explicit. On iPhone it collapses to a sheet automatically — no branching needed. Limiting the popover to detail/edit only (not creation flows) keeps creation workflows at full-sheet scale where they belong.
- **SPRD reference**: [SPRD-230]

### Open Questions

- Does `SpreadTitleNavigatorView` need to be removed entirely on iPad (replaced by the content column), or simplified to show spread identity only (no chevron, no navigator trigger)? — Resolve during SPRD-229 implementation.
- On iPhone, does the back button from the spread pager read "Spreads" (the content column title) or something more descriptive? — Resolve during SPRD-229 implementation.

---

## Calendar Content Column [SPRD-231, SPRD-232]

### Overview

The Spreads content column is refactored from a flat indented list (`SpreadsContentColumnView` backed by `[SpreadPickerModel.Item]`) to a calendar-based view backed by `CalendarView` from `johnnyo-foundation`. The sidebar gains year subitems under the Spreads destination. Selecting a year populates the content column with a full-year calendar grid. Spreads are visualized within the grid; tapping a date cell navigates to the spread(s) on that date.

### Functional Requirements

1. The sidebar lists navigation destinations (Spreads, Entries, Collections, Settings, Debug). Under the Spreads item, year subitems are always visible and indented — no expand/collapse toggle. Only years that have at least one spread are shown, derived from the passed-in spread list. [SPRD-232]
2. Selecting a year subitem sets the content column to show a `CalendarView` spanning January 1 – December 31 of that year. [SPRD-232]
3. `SpreadsContentColumnView` accepts `[DataModel.Spread]` and a `selectedSpread: Binding<DataModel.Spread?>`. It no longer accepts `[SpreadPickerModel.Item]`. [SPRD-232]
4. `SpreadsContentColumnView` uses `CalendarView` from `johnnyo-foundation` internally, providing a generator defined in a nested extension (`SpreadsContentColumnView+CalendarGenerator.swift` or equivalent). [SPRD-232]
5. The generator highlights date cells that have one or more spreads (visual treatment TBD at implementation — e.g. filled background, dot indicator, or border). [SPRD-232]
6. Tapping a date cell with exactly one spread navigates to that spread — sets `selectedSpread` and collapses the content column. [SPRD-232]
7. Tapping a date cell with more than one spread shows an app-owned popover listing each spread's description/label. The user taps a spread in the popover to select it. Foundation does not own this disambiguation UI. [SPRD-232]
8. Tapping a date cell with no spreads is a no-op. [SPRD-232]
9. The sidebar selection type must accommodate both destination items (`.spreads`, `.entries`, etc.) and year subitems in a single `List(selection:)` binding. A new `SidebarItem` enum (or equivalent) wraps both. [SPRD-232]

### Design Decisions

#### Decision: SpreadsContentColumnView accepts spreads, not picker items

- **Context**: The previous implementation passed `[SpreadPickerModel.Item]` — a pre-computed model coupling label, style, badge, and display fields specific to the flat-list row rendering. `CalendarView` needs raw dates to position spreads in the grid, and `SpreadPickerModel.Item` does not expose dates directly.
- **Decision**: `SpreadsContentColumnView` accepts `[DataModel.Spread]` directly. The generator extension maps spread dates to calendar cells.
- **Rationale**: `DataModel.Spread` carries the period and date needed for calendar positioning. Passing spreads directly removes the dependency on `SpreadPickerModel` from the content column and makes the view useful in other contexts without a picker model.
- **SPRD reference**: [SPRD-232]

#### Decision: App-owned disambiguation popover for multi-spread dates

- **Context**: When multiple spreads cover the same date (e.g., a year spread, a month spread, and a day spread all include January 15), tapping that cell needs to resolve which spread to navigate to.
- **Decision**: `CalendarView` fires `onDateTapped: (Date) -> Void`. The `SpreadsContentColumnView` generator (or the view itself) maps the date to the overlapping spreads and presents a SwiftUI `.popover` listing them. Foundation owns no disambiguation UI.
- **Rationale**: Foundation stays structural. The app owns the visual disambiguation treatment and can tailor it (spread labels, periods, badges) without requiring a foundation API change.
- **SPRD reference**: [SPRD-232]

#### Decision: SidebarItem enum for mixed sidebar selection

- **Context**: The sidebar `List(selection:)` currently binds to `RootNavigationView.Content?`. Adding year subitems requires the selection to represent either a destination or a specific year-under-spreads. Two types cannot share one binding without a wrapper.
- **Decision**: Introduce a `RootNavigationView.SidebarItem` enum with cases `.destination(Content)` and `.spreadsYear(Int)`. The sidebar list binds to `SidebarItem?`. `RootNavigationView` derives `selectedContent` and `selectedSpreadsYear` from this single selection.
- **Rationale**: A single selection binding on `List` is the SwiftUI-idiomatic approach. A typed enum keeps the two concerns distinct without maintaining separate state variables that can drift out of sync.
- **SPRD reference**: [SPRD-232]

---

## Leading Toolbar: Column Toggle and Parent Spread Navigation [SPRD-236]

**Status**: Draft
**Date**: 2026-06-05

### Overview

Add a leading toolbar button group to the spread detail column that lets the user toggle the content column and jump directly to any ancestor spread of the currently selected spread. The group is split across two views: `RootNavigationView` owns the column toggle button (it owns `columnVisibility`), and `SpreadContentPagerView` owns the parent spread buttons (it owns the current spread context).

### Functional Requirements

1. A calendar icon button appears at the leading edge of the detail column navigation bar. When the content column is visible, the icon changes to a left chevron (`chevron.left`). [SPRD-236]
2. Tapping the calendar icon shows the content column. Tapping the chevron hides it. This is a direct toggle of `columnVisibility` in `RootNavigationView`. [SPRD-236]
3. The calendar/chevron button is implemented in `RootNavigationView` as a `ToolbarItem(placement: .topBarLeading)` inside the `spreadsDetailContent` toolbar, since `columnVisibility` is owned there. [SPRD-236]
4. Parent spread buttons appear to the trailing side of the calendar/chevron button, from broadest period to narrowest. They are implemented in `SpreadContentPagerView` as a `ToolbarItemGroup(placement: .topBarLeading)`. SwiftUI merges the two leading toolbar contributions in hierarchy order. [SPRD-236]
5. Parent periods shown per current spread period: [SPRD-236]
   - `.day` → year button, then month button
   - `.month` → year button only
   - `.year` → no parent buttons
   - `.multiday` → year button, then month button (multiday is day-scope for hierarchy purposes)
6. Each parent button label uses a fixed format, not the spread's custom name: [SPRD-236]
   - Year spread button: `"YYYY"` (e.g. `"2026"`)
   - Month spread button: `"MMM"` (e.g. `"Jun"`)
   - Multiday spread button: `"DD MMM – DD MMM"` (e.g. `"3 Jun – 9 Jun"`)
7. A parent button is **enabled** when a spread of that period covering the current spread's date exists in `JournalManager`. It is **disabled** (but still visible) when no such spread exists. [SPRD-236]
8. Tapping an enabled parent button sets `selectedSpread` directly with no pager scroll animation. Column visibility is unchanged. [SPRD-236]
9. Parent spread lookup is performed via a new `JournalManager` method `parentSpreads(for:)` rather than filtering `journalManager.spreads` inline in the view, keeping the lookup logic testable. [SPRD-236]

### Technical Design

#### `JournalManager.parentSpreads(for:)`

Returns one entry per parent period, ordered broadest → narrowest, each carrying the period and the matching spread if one exists:

```swift
func parentSpreads(for spread: DataModel.Spread) -> [(period: Period, spread: DataModel.Spread?)]
```

- `.day` spread on 2026-06-05 → `[(.year, yearSpread?), (.month, juneSpread?)]`
- `.month` spread on 2026-06 → `[(.year, yearSpread?)]`
- `.year` spread → `[]`
- `.multiday` spread starting 2026-06-03 → `[(.year, yearSpread?), (.month, juneSpread?)]` — uses start date to find the containing month

A spread matches a parent period if its period equals the target period and its date range contains the child spread's reference date (start date for multiday, `date` for all others).

#### Toolbar Split

```
RootNavigationView  (.topBarLeading)
└── ToolbarItem: calendar / chevron.left toggle   ← owns columnVisibility

SpreadContentPagerView  (.topBarLeading)
└── ToolbarItemGroup: [year button?] [month button?]   ← calls journalManager.parentSpreads(for:)
```

`SpreadContentPagerView` receives a `Binding<DataModel.Spread?>` for `selectedSpread` so tapping a parent button sets it directly without animation.

#### Label Formatting

Label formatting lives in a new extension method on `DataModel.Spread` (e.g., `Spread/Additions/Spread+ParentNavigation.swift`) rather than inline in the toolbar:

```swift
func parentNavigationLabel(calendar: Calendar) -> String
```

- `.year` spread: `"YYYY"`
- `.month` spread: `"MMM"`
- `.multiday` spread: `"DD MMM – DD MMM"` using start/end dates

### Design Decisions

#### Decision: Toolbar split between RootNavigationView and SpreadContentPagerView

- **Context**: The column toggle needs `columnVisibility` (owned at `RootNavigationView`). The parent spread buttons need the current spread and `JournalManager` (available in `SpreadContentPagerView`). Passing one set of state to the other adds coupling with no benefit.
- **Decision**: Each view contributes its own toolbar items at `.topBarLeading`. SwiftUI merges them in hierarchy order.
- **Rationale**: Each view owns only what it renders. No new bindings or coordinator state required. Hierarchy order guarantees the calendar/chevron appears first since `RootNavigationView` is the ancestor.
- **SPRD reference**: [SPRD-236]

#### Decision: Parent buttons disabled (not hidden) when spread doesn't exist

- **Context**: If a parent spread hasn't been created yet, the button could be hidden entirely or shown as disabled.
- **Decision**: Always show the button; disable it when no matching spread exists.
- **Rationale**: Consistent presence helps the user understand the hierarchy at a glance. A disabled button communicates "this period exists conceptually but hasn't been created" rather than silently omitting the affordance.
- **SPRD reference**: [SPRD-236]

#### Decision: Fixed-format labels (not custom spread names)

- **Context**: Spreads can have custom names. Using a custom name could make the button label long or ambiguous (e.g., "Summer" for a month spread).
- **Decision**: Labels use fixed date formats: `"YYYY"` for year, `"MMM"` for month, `"DD MMM – DD MMM"` for multiday.
- **Rationale**: These buttons are navigation affordances, not spread identity displays. Compact canonical labels scan faster and never overflow the toolbar.
- **SPRD reference**: [SPRD-236]

#### Decision: JournalManager helper for parent spread lookup

- **Context**: Parent spread lookup could be done inline in `SpreadContentPagerView` by filtering `journalManager.spreads`. But the lookup has non-trivial rules (date containment per period, multiday start-date logic) that belong in a testable model layer.
- **Decision**: Add `parentSpreads(for:)` to `JournalManager`.
- **Rationale**: Keeps view code thin and makes the lookup rules unit-testable without UI scaffolding.
- **SPRD reference**: [SPRD-236]

---

## TabView Shell Redesign [SPRD-238]

**Status**: Draft
**Date**: 2026-06-07

### Overview

Replace the `NavigationSplitView` 3-column shell (introduced in the Adaptive Navigation Shell section, SPRD-229) with a `TabView`-based shell. `RootNavigationView` becomes a plain `TabView` with one tab per top-level destination (Spreads, Entries, Collections, Settings, and Debug when enabled). The Spreads tab's content is extracted into a new self-contained view, `SpreadsTabView`, which lays out the calendar content column and the spread detail content side-by-side in an `HStack`, with the content column togglable via a leading toolbar button. This supersedes the sidebar/content/detail-column architecture — the sidebar list of destinations is replaced by tabs, and the persistent content column becomes a togglable left pane scoped entirely to the Spreads tab.

### Problem Statement

The `NavigationSplitView` shell couples Spreads-specific navigation state (`selectedColumnSpread`, `spreadsCoordinator`, `pagerSettledTargetID`, year selection via `selectedSidebarItem`) to `RootNavigationView`, because column-collapse transitions require that state to survive at the root. This makes `RootNavigationView` a long file tightly coupled to Spreads-tab internals it shouldn't need to know about, and forces fragile state-mirroring (`selectedColumnSpread` ↔ `spreadsCoordinator.selectedSelection`). A `TabView` shell scopes each destination's state to its own tab — `SpreadsTabView` can own its state directly, `RootNavigationView` shrinks to cross-tab routing only, and content-column visibility becomes a simple local `Bool` rather than a `columnVisibility` enum synced across the hierarchy.

### Goals

- Replace `NavigationSplitView` with a plain `TabView` (`.tabViewStyle(.automatic)`), one tab per top-level destination.
- Extract the Spreads destination's content into a self-contained `SpreadsTabView` that owns its own navigation state.
- Lay out `SpreadsTabView` as an `HStack`: calendar content column (left pane) + spread detail content (right pane).
- Make the left pane togglable: a leading toolbar button (calendar icon) shows/hides it on regular width; on compact width the same button presents it as a `fullScreenCover`.
- Simplify state ownership — remove state that existed solely to survive `NavigationSplitView` column-collapse transitions.
- Preserve cross-tab navigation (`openTaskFromSearch`) via a shared, lightweight pending-navigation mechanism.

### Non-Goals

- Changing which destinations exist or their icons.
- Changing the calendar content column's internal rendering (`SpreadsContentColumnView` + `CalendarView`) beyond adding self-contained year selection.
- Changing entry row tap interactions, task/note detail presentation, or sheet destinations — these remain as specced in the Adaptive Navigation Shell section (SPRD-230).
- Adapting the `TabView` to a sidebar style on iPad (e.g. `.sidebarAdaptable`) — out of scope; can be revisited later.

### Functional Requirements

1. `RootNavigationView` uses a plain `TabView` with `.tabViewStyle(.automatic)` — a standard tab bar on both iPhone and iPad. One tab per `Content` case (Spreads, Entries, Collections, Settings, Debug when `BuildInfo.allowsDebugUI`). [SPRD-238]
2. Each tab wraps its destination content in its own `NavigationStack`, giving each tab independent navigation history. [SPRD-238]
3. The Spreads tab's content is `SpreadsTabView` — a new view extracted from the current `spreadsDetailContent`. [SPRD-238]
4. `SpreadsTabView`'s top-level structure is an `HStack`: [SPRD-238]
   - **Left pane**: `SpreadsContentColumnView` (the calendar content column), gaining its own year-selection control so it is fully self-contained (no longer dependent on sidebar year subitems).
   - **Right pane**: the current `spreadsDetailContent` implementation (title header, sync banner, `SpreadContentPagerView`, bottom inset controls, toolbar).
5. A single leading toolbar button (calendar icon) controls a local `Bool` binding owned by `SpreadsTabView` (`isContentColumnVisible`): [SPRD-238]
   - **Regular width**: tapping the button toggles `isContentColumnVisible`. The left pane is shown — with a leading-edge slide + fade transition — only when `isContentColumnVisible == true` AND the horizontal size class is `.regular`. The button's icon swaps between `calendar` (pane hidden) and `chevron.left` (pane visible), replacing the SPRD-236 chevron button entirely.
   - **Compact width**: tapping the button presents the left pane as a `.fullScreenCover`. The right pane is always full-width on compact.
6. Selecting a spread in the left pane (calendar cell tap) sets the shared spread selection and hides the left pane — on regular width by setting `isContentColumnVisible = false`, on compact width by dismissing the full-screen cover. [SPRD-238]
7. `SpreadsTabView` owns its own Spreads-specific navigation state — `spreadsCoordinator`, the selected spread, `pagerSettledTargetID`, and year selection — directly as `@State`/`@Observable`, rather than receiving it from `RootNavigationView`. State that existed solely to survive `NavigationSplitView` column-collapse transitions (`columnVisibility`, the `selectedColumnSpread`/`spreadsCoordinator.selectedSelection` mirror, `selectedSidebarItem`) is removed. [SPRD-238]
8. Cross-tab navigation (`openTaskFromSearch`, triggered from the Entries tab) continues to work: `RootNavigationView` switches `selectedTab` to `.spreads` and populates a shared `spreadsNavigationState.pendingRequest`; `SpreadsTabView` observes that state and reacts (selects the spread, opens the task detail) — the same pending-request pattern as today, relocated. [SPRD-238]
9. The detail content's toolbar (today button, sync icon, auth button) remains, attached to the right pane / `SpreadContentPagerView` as before. The SPRD-236 parent-spread navigation buttons (`SpreadContentPagerView.parentSpreadEntries`/`parentButtonLabel`, `JournalManager.parentSpreads(for:)`, `Spread+ParentNavigation.swift`, and their tests) are removed entirely — the content-column toggle supersedes them as the primary way to jump across periods. [SPRD-238]
10. Project builds with no errors or warnings; existing Spreads navigation behaviors (spread selection, pager sync, today button, cross-tab task open) continue to function. [SPRD-238]

### Technical Design

#### Architecture

```
RootNavigationView
└── TabView (.automatic)
    ├── Tab "Spreads"     → NavigationStack { SpreadsTabView }
    ├── Tab "Entries"     → NavigationStack { EntriesBrowserView }
    ├── Tab "Collections" → NavigationStack { CollectionsListView }
    ├── Tab "Settings"    → NavigationStack { SettingsView }
    └── Tab "Debug"       → NavigationStack { debugMenuView }   (when allowsDebugUI)

SpreadsTabView
├── @State isContentColumnVisible: Bool
├── @State isContentColumnCoverPresented: Bool   (compact-width fullScreenCover trigger)
├── @State spreadsCoordinator, selectedSpread, pagerSettledTargetID, selectedYear, ...
├── HStack
│   ├── SpreadsContentColumnView   (left pane; shown when isContentColumnVisible && .regular)
│   └── spreadsDetailContent       (right pane; always shown)
├── .toolbar { calendar / chevron.left toggle button }
└── .fullScreenCover(isPresented:) { SpreadsContentColumnView }   (compact only)
```

#### Toggle Behavior — Reference Pattern

Mirrors the `ContentView` example provided during speccing:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@State private var isContentColumnVisible = false
@State private var isContentColumnCoverPresented = false

var body: some View {
    Group {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                if isContentColumnVisible {
                    SpreadsContentColumnView(...)
                        .frame(width: 320)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                spreadsDetailContent
            }
        } else {
            spreadsDetailContent
        }
    }
    .toolbar {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                if horizontalSizeClass == .regular {
                    withAnimation { isContentColumnVisible.toggle() }
                } else {
                    isContentColumnCoverPresented = true
                }
            } label: {
                Image(systemName: isContentColumnVisible ? "chevron.left" : "calendar")
            }
        }
    }
    .fullScreenCover(isPresented: $isContentColumnCoverPresented) {
        NavigationStack {
            SpreadsContentColumnView(...)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { isContentColumnCoverPresented = false }
                    }
                }
        }
    }
}
```

#### Year Selection in the Content Column

`SpreadsContentColumnView` gains its own year-selection control (e.g. header chevrons or a `Menu`), making it self-sufficient now that the sidebar's `.spreadsYear(Int)` subitems are gone. Whether `selectedYear` lives as internal `@State` or a binding owned by `SpreadsTabView` is an implementation detail to resolve during SPRD-238 (see Open Questions).

#### Cross-Tab Navigation

`RootNavigationView` keeps:
- `@State private var selectedTab: Content`
- `@State private var spreadsNavigationState = SpreadsNavigationState()` (existing `@Observable`, holding `pendingRequest`)

`openTaskFromSearch` sets `selectedTab = .spreads` and `spreadsNavigationState.pendingRequest = SpreadsNavigationRequest(...)`. `SpreadsTabView` receives `spreadsNavigationState` (via init injection or environment) and reacts to `pendingRequest` changes exactly as `RootNavigationView` does today (`handlePendingNavigationRequest`), relocated into `SpreadsTabView`.

### Design Decisions

#### Decision: TabView replaces NavigationSplitView

- **Context**: The `NavigationSplitView` 3-column shell (SPRD-229) was adopted to eliminate double-chrome and promote the spread navigator to a persistent column. In practice it concentrated Spreads-specific state at the root and made content-column visibility (`columnVisibility`) a fragile, externally-mutable enum that required explicit syncing (`isContentColumnVisible` mirroring `columnVisibility`).
- **Decision**: Replace it with a plain `TabView` (`.tabViewStyle(.automatic)`) — one tab per destination — with the Spreads tab internally laying out a togglable calendar pane beside the detail content via a simple `HStack` + local `Bool` binding.
- **Rationale**: A `TabView` is simpler to reason about, scopes state naturally to each tab, and removes the column-collapse-survival constraints that forced state up to `RootNavigationView`. The togglable `HStack` pane inside `SpreadsTabView` preserves the "persistent calendar picker beside the content" capability on iPad without `NavigationSplitView`'s coupling.
- **SPRD reference**: [SPRD-238]

#### Decision: Single calendar/chevron toggle button replaces the SPRD-236 chevron button

- **Context**: SPRD-236 added a `chevron.left` button to the detail column's toolbar to collapse the content column (`columnVisibility = .detailOnly`). With `columnVisibility` removed, that mechanism no longer applies.
- **Decision**: A single leading toolbar button in `SpreadsTabView` — icon swapping between `calendar` (pane hidden) and `chevron.left` (pane visible) — replaces the SPRD-236 button entirely and drives `isContentColumnVisible` directly.
- **Rationale**: One button with a state-reflecting icon is simpler than maintaining two separate toggle affordances targeting the same concern. The icon swap communicates the action ("tap to reveal the calendar" vs. "tap to hide it") more directly than a static icon.
- **SPRD reference**: [SPRD-238]

#### Decision: fullScreenCover for compact-width pane presentation

- **Context**: On compact width (iPhone), there isn't room for a side-by-side `HStack`. The calendar content column needs a presentation mechanism that doesn't depend on `NavigationSplitView` column collapse, which no longer exists in this shell.
- **Decision**: Present the content column as a `.fullScreenCover` on compact width, driven by the same toggle button (via a derived presentation flag, `isContentColumnCoverPresented`). Selecting a spread inside the cover dismisses it.
- **Rationale**: `fullScreenCover` is the standard SwiftUI mechanism for presenting a full-screen picker-like flow on compact width, matches the reference `ContentView` example, and keeps the interaction model consistent with the regular-width toggle — same button, same underlying intent ("show me the calendar picker").
- **SPRD reference**: [SPRD-238]

#### Decision: Spreads-tab state moves into SpreadsTabView; root state is minimized

- **Context**: `spreadsCoordinator`, `spreadsNavigationState`, `selectedColumnSpread`, `pagerSettledTargetID`, and `selectedSidebarItem` lived at `RootNavigationView` because `NavigationSplitView` column-collapse transitions could otherwise reset child `@State`. None of that constraint applies to a `TabView` tab, which persists for the app's lifetime.
- **Decision**: Move `spreadsCoordinator`, the selected spread (replacing the `selectedColumnSpread`/`spreadsCoordinator.selectedSelection` duality with a single source of truth), `pagerSettledTargetID`, and year selection into `SpreadsTabView`'s own state. `RootNavigationView` retains only `selectedTab` and `spreadsNavigationState` (needed for cross-tab routing). `columnVisibility` and `selectedSidebarItem` are removed entirely.
- **Rationale**: Scoping state to the tab that uses it reduces `RootNavigationView` to a thin cross-tab router, eliminates a class of state-sync bugs (the `selectedColumnSpread` ↔ `spreadsCoordinator.selectedSelection` mirroring this redesign removes), and makes `SpreadsTabView` independently testable and reusable.
- **SPRD reference**: [SPRD-238]

#### Decision: Year picker added to SpreadsContentColumnView

- **Context**: Year selection previously lived in the sidebar as `.spreadsYear(Int)` subitems, feeding the content column via `SidebarItem`. Removing the sidebar removes that mechanism, but the calendar content column still needs to know which year to display.
- **Decision**: `SpreadsContentColumnView` gains its own year-selection control (e.g. header chevrons or a `Menu`) so it is self-sufficient.
- **Rationale**: Keeps the content column independently usable and avoids re-introducing a cross-view selection wrapper type (`SidebarItem`) solely to carry a year value. The control's exact visual form is an implementation detail to resolve during SPRD-238.
- **SPRD reference**: [SPRD-238]

### Open Questions

- Should `selectedYear` live as `@State` inside `SpreadsContentColumnView`, or be owned by `SpreadsTabView` and passed as a binding (needed if other parts of `SpreadsTabView` ever need to know the displayed year)? — Resolve during SPRD-238 implementation.
- Exact visual form of the year picker control (chevron stepper vs. menu vs. segmented control) — resolve during SPRD-238 implementation, consistent with `SpreadTheme`.
- Left pane fixed width vs. proportional sizing on iPad — resolve during SPRD-238 implementation; the reference example uses a fixed `280`–`320`pt width.

---

## Coordinator-Driven Popovers [SPRD-244]

### Requirements

- `SpreadsCoordinator` owns `activePopover: PopoverDestination?`, parallel to `activeSheet` and `activeAlert`. [SPRD-244]
- `PopoverDestination` is a separate `Identifiable` enum — it must not be merged into `SheetDestination`. [SPRD-244]
- Each `PopoverDestination` case carries a concrete associated value conforming to the `PopoverContent` protocol. [SPRD-244]
- The `PopoverContent` protocol requires: [SPRD-244]
  - `associatedtype Body: View`
  - `var arrowEdge: Edge { get }`
  - `var attachmentAnchor: PopoverAttachmentAnchor { get }`
  - `@ViewBuilder var body: Body { get }`
  - Conformance to `Identifiable`
- Anchor views (not `SpreadsView`) apply `.popover(item:attachmentAnchor:arrowEdge:content:)` on themselves, binding to a derived `Binding` that extracts the relevant case from `coordinator.activePopover`. The coordinator owns the "what"; the anchor view owns the "where." [SPRD-244]
- `AnyView` must not be used in the protocol or its conformances. [SPRD-244]
- The initial `PopoverDestination` case is `.quickAdd(QuickAddPopoverContent)`, migrating `AddTaskButton`'s self-managed `@State private var isPresented` to coordinator-driven state. [SPRD-244]
- `QuickAddPopoverContent` carries: the target `date: Date`, `period: Period`, `availableLists: [DataModel.List]`, `availableTags: [DataModel.Tag]`, and `onAddTask` closure. [SPRD-244]
- `AddTaskButton` calls `coordinator.showQuickAdd(...)` on tap rather than setting its own `isPresented`. It applies `.popover` on itself, extracting the `.quickAdd` case from `coordinator.activePopover`. [SPRD-244]
- `EventDetailPopoverView` (in `SpreadDayTimelineContentGenerator`) remains self-managed and is not migrated to coordinator-driven. [SPRD-244]

### Design Decisions

#### Decision: `PopoverDestination` is a separate enum, not a `SheetDestination` case

- **Context**: Sheets and popovers share presentation intent (show some UI above the current content) but use different SwiftUI modifiers with different anchor requirements. Popovers require `attachmentAnchor` and `arrowEdge`; sheets do not. Mixing them into one enum would either bloat `SheetDestination` with popover-only fields or require awkward optionals.
- **Decision**: Introduce a dedicated `PopoverDestination` enum alongside `SheetDestination` and `AlertDestination`.
- **Rationale**: Consistent with the existing parallel between `activeSheet` and `activeAlert`. Clear separation of concerns; each enum maps to exactly one SwiftUI modifier family.
- **SPRD reference**: [SPRD-244]

#### Decision: `PopoverContent` uses an associated type for `Body`, not `AnyView`

- **Context**: The content view returned by each popover case can be any `View`. Two options: erase to `AnyView`, or use `associatedtype Body: View` on the protocol.
- **Decision**: Use `associatedtype Body: View` with a `@ViewBuilder var body: Body { get }` requirement.
- **Rationale**: Avoids `AnyView` heap allocation and type erasure. Each `PopoverDestination` case wraps a concrete conforming type, so the associated type is always resolvable at the switch site. The protocol is used as a constraint, not an existential.
- **SPRD reference**: [SPRD-244]

#### Decision: Anchor view applies the `.popover` modifier, not the coordinator root

- **Context**: SwiftUI's `.popover` modifier anchors visually to the view it is applied to. Applying it once on `SpreadsView` would make every popover appear anchored to the root view bounds, breaking arrow placement.
- **Decision**: Each anchor view (e.g., `AddTaskButton`) applies `.popover` on itself. It binds to a derived `Binding<ConcreteContent?>` that maps `coordinator.activePopover` to/from the specific case it owns. The coordinator still owns all presentation state — the anchor view only reads and clears it.
- **Rationale**: Correct visual behavior (arrow points at the button) without duplicating state. The coordinator remains the single source of truth; the anchor view is just a passthrough for the SwiftUI modifier.
- **SPRD reference**: [SPRD-244]

---

## Spread Content Pager Render Performance [SPRD-275]

**Status**: Draft
**Date**: 2026-06-29

### Overview

Reduce unnecessary recomputation in `SpreadContentPagerView` during active scrolling. SPRD-272/SPRD-273 already addressed forced multi-month layout and `selectedYearSpreads` recomputation. This task closes two remaining sources of per-frame work surfaced during a follow-up lag investigation: `spreadDetailTitle` still reads `journalManager.calendar`/`.today`/`.firstWeekday` directly from `body`-reachable code despite its doc comment claiming otherwise, and `spreadDataModel(for:)` is computed for every spread in the pager's `ForEach` rather than only the pages near the settled selection.

### Problem Statement

`SpreadContentPagerView`'s `spreadDetailTitle` computed property is documented as receiving its dependencies pre-computed from the parent so the view does not observe `JournalManager` during scrolling, but it still reads `journalManager.calendar`, `.today`, and `.firstWeekday` directly via the environment-injected manager — meaning any unrelated `JournalManager` state change (new spread creation, background sync, coordinator updates) can re-trigger this body read and its title derivation work. Separately, the pager's `ForEach(spreads)` calls `spreadDataModel(for:)` for every spread in the array on each render, not just the page(s) actually visible near `settledSpreadID`, performing O(n) lookup work when only O(1) is needed.

### Goals

- Make `spreadDetailTitle` depend only on plain, parent-injected values — no direct `JournalManager` environment reads.
- Restrict `spreadDataModel(for:)` computation to the settled page and its immediate neighbors, with the neighbor radius defined as an easily adjustable constant.
- Correct the existing doc comment on `SpreadContentPagerView` that incorrectly claims `journalManager` is not accessed in `body`.

### Non-Goals

- `selectedYearSpreads` memoization — already done in [SPRD-273].
- Caching `SpreadsTabView`'s uncached `yearSpreads` filter/sort property — tracked separately, not part of this task.
- Any change to pager paging/animation behavior, page transition visuals, or `SpreadDataModel` contents.

### Functional Requirements

1. `SpreadContentPagerView` receives `calendar: Calendar`, `today: Date`, and `firstWeekday: Int` (or equivalent plain values) as init-injected properties from the parent, rather than reading them from `journalManager` inside `spreadDetailTitle`. [SPRD-275]
2. `spreadDataModel(for:)` is computed only for the spread matching `settledSpreadID` and spreads within a fixed neighbor radius of it in the `spreads` array. [SPRD-275]
3. The neighbor radius is a named constant (e.g. `Constants.spreadDataModelWindowRadius`), defaulted to `1`, so it can be changed in one place without touching the windowing logic. [SPRD-275]
4. Spreads outside the window render without a computed `SpreadDataModel` (e.g. an empty/placeholder content state) until they enter the window as the pager settles. [SPRD-275]
5. The doc comment on `SpreadContentPagerView` (and/or `spreadDetailTitle`) is corrected to accurately describe which values are observed vs. pre-computed. [SPRD-275]

### Technical Design

#### Title Derivation

`spreadDetailTitle` stops reading `journalManager.calendar`/`.today`/`.firstWeekday`. These three are added as plain stored properties on `SpreadContentPagerView`, injected once from the parent at construction (the parent already reads them from `journalManager` itself elsewhere, so no new `JournalManager` call site is introduced — just relocated to the parent's init-time read instead of the child's per-render read).

#### Windowing

```swift
private enum Constants {
    static let spreadDataModelWindowRadius = 1
}

private func isWithinDataModelWindow(_ spread: DataModel.Spread) -> Bool {
    guard let settledIndex = spreads.firstIndex(where: { $0.id == settledSpreadID }),
          let index = spreads.firstIndex(where: { $0.id == spread.id }) else { return false }
    return abs(index - settledIndex) <= Constants.spreadDataModelWindowRadius
}
```

`contentView(for:)` checks `isWithinDataModelWindow(spread)` before calling `spreadDataModel(for:)`; outside the window it renders a lightweight placeholder.

#### Edge Cases

- First render before any page has settled: `settledSpreadID` defaults to the initially selected spread, so the window is centered there from the start — no flash of empty content on initial load.
- Fast multi-page flicks: pages more than `±1` away briefly show the placeholder until the settle event updates `settledSpreadID` and brings them into the window.

#### Testing Strategy

- Unit tests on the windowing predicate (`isWithinDataModelWindow` or equivalent extracted support function): verify the settled page and ±1 neighbors are included, and pages at ±2 are excluded, for a representative `spreads` array.
- Unit tests on title derivation confirming it produces the same output as before when given the same plain `calendar`/`today`/`firstWeekday` inputs, without requiring a `JournalManager` instance.
- Manual scroll-performance check: scroll through a year of populated day/multiday spreads and confirm no perceptible lag regression introduction and a qualitative improvement versus pre-fix behavior.

### Design Decisions

#### Decision: Fixed-radius window constant instead of dynamic/adaptive radius

- **Context**: The radius around `settledSpreadID` that gets a computed `SpreadDataModel` could be fixed or tuned dynamically (e.g. based on scroll velocity).
- **Decision**: Use a single fixed constant, defaulted to `1`, defined in one place for easy adjustment.
- **Rationale**: A dynamic/velocity-based radius adds complexity with no demonstrated need; a simple constant is trivially tunable if `±1` proves insufficient in practice, per explicit request to keep this easy to change.
- **SPRD reference**: [SPRD-275]

#### Decision: Three separate commits for one SPRD task

- **Context**: The three fixes (title-derivation hoist, doc comment correction, data-model windowing) are independently verifiable but were diagnosed together as one investigation.
- **Decision**: Track all three under a single SPRD-275 task, but land them as three separate, independently buildable commits.
- **Rationale**: Keeps the spec/plan surface small (one task) while preserving small, reviewable, independently revertible commits per CLAUDE.md's git conventions.
- **SPRD reference**: [SPRD-275]

### Open Questions

- None.

---

## Pager Re-Render: Environment Service Churn [SPRD-283]

**Status**: Draft
**Date**: 2026-07-01

### Overview

`SpreadContentPagerView` re-renders multiple times on app launch and on every scene-activation event — even with no user interaction — because the `eventKitService` and `calendarEventService` environment values appear "changed" to SwiftUI on every `ContentView.body` re-run. This fires even when the underlying service instances are identical.

### Problem Statement

`ContentView.body` re-runs whenever any observed state in its scope changes (e.g. `scenePhase` becoming active, `AuthManager.state` updating during launch). Each re-run calls `.environment(\.eventKitService, ...)` and `.environment(\.calendarEventService, ...)` with the same service instances that were injected before. However, both environment keys store their values as `any Protocol` existentials (`any EventKitService` and `any CalendarEventService`). Existential types in Swift are not `Equatable` — SwiftUI has no way to compare old vs. new to determine whether the value actually changed, so it always propagates a "changed" signal down the tree.

`SpreadContentPagerView` reads both values via `@Environment`, so every propagation causes its `body` to re-evaluate. Confirmed via `Self._printChanges()` output:

```
SpreadContentPagerView: _eventKitService, _calendarEventService changed.
SpreadContentPagerView: _eventKitService, _calendarEventService changed.
SpreadContentPagerView: _eventKitService, _calendarEventService changed.
```

This fires ~10+ times on a cold launch before any scrolling, and again on every scene-activation (`sceneDidBecomeActive`). Each re-render evaluates `contentView(for:)` for every windowed spread page, doing redundant `JournalManager.dataModel` lookups and re-constructing `SpreadPageContext`.

### Goals

- Eliminate `SpreadContentPagerView` re-renders triggered solely by `_eventKitService` or `_calendarEventService` changing when the underlying service instances have not actually changed.

### Non-Goals

- Changing how `EventKitService` or `CalendarEventService` is used by content views (fetch logic, `openEvent`, etc.).
- Removing the environment key pattern in favour of direct init injection — the environment approach is intentional for deep pass-through.

### Functional Requirements

1. `SpreadContentPagerView` does not re-render due to `_eventKitService` or `_calendarEventService` environment changes when the same service instances are re-injected by `ContentView`. [SPRD-283]
2. Both environment keys use a stable identity comparison so SwiftUI can short-circuit propagation when the value has not changed. [SPRD-283]

### Technical Design

#### Root Cause

The environment keys are typed as `any Protocol` existentials:

```swift
// EventKitService+Environment.swift
var eventKitService: (any EventKitService)?

// CalendarEventService+Environment.swift  
var calendarEventService: any CalendarEventService
```

SwiftUI's environment change detection requires the value type to be comparable. For existentials, there is no `==` available, so SwiftUI conservatively treats every assignment as a change.

#### Fix

Change `LiveCalendarEventService` from `struct` to `final class`. It has no value semantics (it holds a service reference and is never copied for mutation), and making it a class enables identity-based comparison alongside `LiveEventKitService` (already a `final class`).

Wrap both environment values in an identity-based `Equatable` box at the key level:

```swift
struct ServiceBox<S: AnyObject>: Equatable {
    let service: S
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.service === rhs.service
    }
}
```

The environment key stores `ServiceBox<ConcreteType>` internally; the public `get`/`set` accessors unwrap/wrap transparently so all existing call sites (`@Environment(\.eventKitService)`, `.environment(\.eventKitService, ...)`) are unchanged.

Since `AppDependencies` creates both services once and holds them as `let` properties, the same instance is always re-injected — the identity check will always return `true` in production, preventing propagation entirely.

### Design Decisions

#### Decision: Class over `@Observable` injection for these services

- **Context**: An alternative is to make both services `@Observable` classes and inject them via `.environment(service)` (not a custom key). SwiftUI tracks `@Observable` by identity automatically.
- **Decision**: Keep the custom environment key pattern; fix identity comparison at the key level by changing `LiveCalendarEventService` to a class.
- **Rationale**: `@Observable` requires adding `import Observation` and the macro to service types that have no need for observation (they hold no `@Observable` published state). The identity-box fix is local to the two environment key files and doesn't change any other type's shape or conformances. Call sites are unaffected.
- **SPRD reference**: [SPRD-283]

### Open Questions

- None.

---

## Pager Re-Render: Scroll-Settle Chain [SPRD-284]

**Status**: Draft
**Date**: 2026-07-01

### Overview

Every time the pager settles on a new spread after a swipe, a re-render cascade propagates from `SpreadsTabView` down through `SpreadContentPagerView` to `DaySpreadContentView` — even when the settled spread is in the same year and nothing in the display data has changed. This is the primary source of lag on repeated scrolling.

### Problem Statement

When the pager settles on a new page, `SpreadContentPagerView.syncSelectionFromSettledID()` sets `coordinator.selectedSpread`. `SpreadsTabView.body` observes `spreadsCoordinator.selectedSpread` (via the `currentSelection` computed property), so it re-renders. The re-render recomputes `yearSpreads` — a `filter` + `sorted` pass over `journalManager.spreads` — producing a new `[DataModel.Spread]` array. Even though the contents are identical (same spreads, same year), it is a newly allocated array value. This new array is passed to `SpreadContentPagerView` as `spreads:`, causing SwiftUI to see `@self changed` on the pager struct. The pager body re-evaluates and propagates `@self` changes to each visible content view.

Confirmed via `Self._printChanges()`:

```
SpreadContentPagerView: _settledSpreadID changed.           ← scroll settled
SpreadsTabView: \SpreadsCoordinator.<computed> (Optional<Spread>) changed.  ← coordinator updated
SpreadContentPagerView: @self changed.                      ← new yearSpreads array passed in
DaySpreadContentView: @self, @identity, _viewModel changed. ← content view reconstructed
```

This fires on every single page swipe. The re-render is wasted work: if the new settled spread is in the same calendar year as the previous one, `yearSpreads` is identical in content to what was just computed. The cascade to `DaySpreadContentView` is the most expensive part — the view model is reconstructed.

### Goals

- Eliminate the `SpreadsTabView` → `SpreadContentPagerView` → `DaySpreadContentView` re-render cascade that fires on every intra-year scroll settle.

### Non-Goals

- Preventing re-renders when the user navigates to a spread in a different calendar year (the `yearSpreads` array genuinely changes there).
- Changing pager scroll mechanics, settle behavior, or how `coordinator.selectedSpread` is updated.
- Eliminating all `DaySpreadContentView` re-renders — only the ones triggered by identical `yearSpreads` being re-passed.

### Functional Requirements

1. Scrolling within the same calendar year does not cause `SpreadsTabView` to pass a new `yearSpreads` array to `SpreadContentPagerView`. [SPRD-284]
2. Navigating to a spread in a different calendar year (via the navigator or convenience nav) does update `yearSpreads` correctly. [SPRD-284]
3. `DaySpreadContentView` does not show `@self, @identity, _viewModel changed` in `_printChanges()` output during intra-year scroll settling. [SPRD-284]

### Technical Design

#### Root Cause

`yearSpreads` is a computed property on `SpreadsTabView`:

```swift
private var yearSpreads: [DataModel.Spread] {
    let year = spreadsCalendar.component(.year, from: currentSelection.startDate ?? currentSelection.date)
    return journalManager.spreads
        .filter { ... }
        .sorted { ... }
}
```

It is re-executed on every `SpreadsTabView.body` evaluation. The result changes identity (new array allocation) even when content is unchanged.

#### Fix

Cache `yearSpreads` as a `@State` value. Track the current year as a `@State<Int>` derived from `currentSelection`. In `.onChange(of: currentSelectionYear)`, recompute `yearSpreads` and update the cached state. Because `@State` updates trigger a body re-run only when the value actually changes (and only for the views that depend on it), a same-year scroll settle will not update the cached array and therefore will not pass a new `spreads:` value to `SpreadContentPagerView`.

The initial value is computed once in `SpreadsTabView.init` (same pattern as `navigatorCalendarModels` and `navigatorYearSpreads` today).

Also recompute `yearSpreads` when `journalManager.spreads` changes (e.g. a new spread is created) — wire this via `onChange(of: journalManager.spreads.count)` or a stable hash, so new spreads appear in the pager without a navigator-triggered year change.

### Design Decisions

#### Decision: Cache via `@State` rather than extracting a child view

- **Context**: An alternative is to extract the pager and its `yearSpreads`/`currentSelection` inputs into a dedicated child view that only observes the coordinator's `selectedYear` (not `selectedSpread`), so scroll-settle changes don't reach it. This is a larger structural refactor.
- **Decision**: Cache `yearSpreads` as `@State` on `SpreadsTabView`, updated only on year change. No child view extraction.
- **Rationale**: The `@State` cache is a local, contained change — it touches only `SpreadsTabView` and is easy to verify by re-running `_printChanges()`. The child-view extraction would require understanding which parts of `SpreadsTabView.body` should move, risking unintended behavioral changes. Prefer the minimal targeted fix; if further re-render issues surface in `SpreadsTabView`, a structural refactor can follow.
- **SPRD reference**: [SPRD-284]

### Open Questions

- None.
