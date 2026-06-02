# Spread Navigation

> Source: Documentation/spec.md

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
