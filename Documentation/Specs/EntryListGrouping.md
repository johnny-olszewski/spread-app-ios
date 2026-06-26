# EntryList Generic Grouping & Sorting

> **Status**: Draft
> **SPRD tasks**: SPRD-257, SPRD-258, SPRD-259, SPRD-260, SPRD-261, SPRD-262, SPRD-263, SPRD-264, SPRD-265, SPRD-266
> **Session**: SESH-25

## Overview

`EntryListView` and its supporting types (`EntryList.Section`, `EntryRowView`, `EntryRowView.Configuration`) are the shared rendering layer used by Day, Month, Year, and Year→MonthCard spreads to display tasks/notes/events. `EntryListView` only ever accepts pre-computed `[EntryList.Section]` — every spread's view model hand-rolls its own grouping logic (Day groups tasks by assigned list with a special "Untitled" bucket; Month builds one section per day in a loop; Year/MonthCard build single or per-month sections). This duplicates "bucket entries by some key, sort the buckets, order entries within each bucket" logic across call sites and locks the grouping/ordering choice in at the view-model level with no way for the user to change it at runtime.

This feature adds a generic flat-entries + group-by + order-by capability to the `EntryList` namespace, then a user-facing picker — shared across Day, Month, Year, and Multiday — that lets the user pick "group by: List / Tag / Status / None" and independently "order by: Priority / Due Date / Title", persisted per spread type via `@AppStorage`. A secondary set of independent cleanup items (dead code, misfiled utilities, action-rendering seam, downcast boilerplate, magic numbers) accompanies the feature work, since they were identified analyzing the same files.

`EntryListView` stays a pure renderer throughout (existing rule, unchanged) — it only ever receives `[EntryList.Section]`, computed by a small, reusable, caller-supplied grouping+sorting recipe. It gains no knowledge of `JournalManager`, `SyncEngine`, or `SpreadsCoordinator`.

---

## Requirements

- A reusable, closure-based grouping primitive partitions a flat `[any Entry]` list into `[EntryList.Section]`, independent of any specific spread type. [SPRD-257]
- Within-group ordering is an orthogonal parameter to grouping — "group by list, order by priority" must be expressible directly. [SPRD-257]
- `EntryListView` gains an additive initializer accepting `entries:`/`groupedBy:`/`orderedBy:` alongside its existing `sections:` initializer (unchanged, still used by callers needing hybrid composition like Day's pinned overdue section). [SPRD-257]
- A shared `EntryGroupingOption` enum (`.none`, `.list`, `.tag`, `.status`) and `EntrySortOption` enum (`.manual`, `.priority`, `.dueDate`, `.title`) are usable by any spread — not bespoke per-spread enums, since these are universal entry attributes. [SPRD-258]
- A single reusable `EntryListOptionsPicker` component exposes both group-by and order-by selection in one UI control. [SPRD-258]
- Grouping/sorting selection persists per spread type (Day/Month/Year/Multiday each remember their own choice independently) via `@AppStorage`. [SPRD-258]
- Day, Month, Year, MonthCard, and Multiday spreads all adopt the picker. Day's hand-rolled "group by assigned list" logic is replaced by the new primitive; Day's overdue section stays pinned/ungrouped/unsorted regardless of picker choice. [SPRD-259, SPRD-260]
- Misfiled/dead code identified while analyzing these files is cleaned up: unused `SectionTitleStyle`, namespace-enum-style `EntryListDisplaySupport`/`EntryListMultidaySupport`, repeated downcasts in `standard*Config` factories, `Action`'s switch statement living in `EntryRowView` instead of on `Action` itself, day-granularity-only migration option logic misplaced in a UI configuration file, and scattered spacing/opacity magic numbers. [SPRD-261–SPRD-266]

---

## Design Decisions

### Decision: Closure-based grouping key, not KeyPath or a closed enum baked into `EntryListView`

- **Context**: Day's existing grouping (by assigned list, with an "Untitled" bucket for unassigned tasks) requires a runtime lookup through `JournalManager` state, not just a static `Entry` property. A `KeyPath<any Entry, V>` can only express values already exposed as `Entry` protocol properties.
- **Decision**: `EntryList.Grouping<Key: Hashable>` holds a closure `key: (any Entry) -> Key`, plus `sortedKeys: ([Key]) -> [Key]` and `section: (Key, [any Entry]) -> EntryList.Section`.
- **Rationale**: Closures support derived/external-state keys (list/tag lookups) that KeyPath cannot, while keeping `EntryListView` itself ignorant of what a "list" or "tag" even is — it only ever consumes the resulting `[EntryList.Section]`.
- **SPRD reference**: SPRD-257

### Decision: Grouping options are one shared enum, not per-spread bespoke types

- **Context**: An earlier draft of this design considered letting each spread (Day, Month, …) define its own `CaseIterable` grouping-option enum scoped to its own context. But list/tag/status are universal `Entry`/`Task`/`Note` attributes, not spread-specific concepts, and the user wants the same picker available in every spread.
- **Decision**: A single shared `EntryGroupingOption` enum (`.none`, `.list`, `.tag`, `.status`) and `EntrySortOption` enum (`.manual`, `.priority`, `.dueDate`, `.title`) live in the `EntryList` area and are reused by every spread's content view.
- **Rationale**: Avoids duplicating near-identical option enums per spread; keeps the picker UI consistent across the app.
- **SPRD reference**: SPRD-258

### Decision: Tag grouping uses "first tag, else Untitled" (no fan-out)

- **Context**: An entry can have zero or more tags (`tags: [DataModel.Tag]` on `Task`/`Note`). Grouping by tag is ambiguous when an entry has multiple tags — it could appear in one bucket or be fanned out into every tag's bucket.
- **Decision**: V1 buckets by the entry's first tag (or "Untitled" if none). No fan-out into multiple sections.
- **Rationale**: Fan-out is a materially larger change (an entry could need to render once per matching section, breaking the 1:1 entry→row assumption elsewhere) and wasn't part of the requested scope. Revisit only if multi-tag fan-out is explicitly requested.
- **SPRD reference**: SPRD-258

### Decision: Persistence is per spread type, not global

- **Decision**: Each spread type (Day/Month/Year/Multiday) stores its own `@AppStorage`-backed grouping/sorting preference under a distinct key (e.g. `"entryGrouping.day"`, `"entrySorting.day"`, etc.), not one global setting shared across all spreads.
- **Rationale**: A user may reasonably want Day grouped by list but Year grouped by status; spreads differ enough in purpose that a shared global preference would surprise users switching between them.
- **SPRD reference**: SPRD-258

### Decision: `Action` keeps its enum shape; only the rendering switch moves

- **Context**: `EntryRowView.toolbarItem(for:labelStyle:)` has a 3-way switch over `Action` (`.openEdit`, `.migrate`, `.delete`) that will need a 4th/5th case eventually for drag/swipe-adjacent menu items.
- **Decision**: `Action` stays a closed, app-internal enum (not promoted to a protocol). The switch body moves onto `Action` itself as a `@ViewBuilder` method; `EntryRowView` calls it instead of switching.
- **Rationale**: A protocol would add existential overhead with no real extensibility win for a closed, single-consumer set. Moving the switch onto `Action` means future cases are added by editing `Action` alone, without touching `EntryRowView`.
- **SPRD reference**: SPRD-263

### Decision: Drag-to-migrate and swipe actions are explicitly deferred, not designed for yet

- **Context**: No drag/drop, `swipeActions`, or other row gestures exist anywhere in `Entries`/`Spreads` views today — only `.contextMenu`. The user confirmed both drag-to-migrate and swipe actions are possible "eventually," with no concrete priority yet.
- **Decision**: Do not add speculative closures (e.g. a `dragPayload` property) to `Configuration` now. Document in its doc comment that this is a deliberately deferred, separate extension point (container-view gestures, not menu items — can't be folded into `Action`).
- **Rationale**: The right shape depends on whether `Entry`/concrete types eventually adopt `Transferable` (needed for drag), which isn't decided. Premature to commit to a shape today; CLAUDE.md's anti-overengineering stance favors building this when it's actually scoped.
- **SPRD reference**: SPRD-263

---

## Open Questions

- Tag grouping with multiple tags per entry: confirmed "first tag, else Untitled" for v1 (see Design Decisions) — revisit if multi-tag fan-out is explicitly requested.
- Exact picker placement in Month/Year/MonthCard: Day's placement is concrete (next to the existing capsule decoration in its toolbar row, alongside the favorite/edit buttons — see [DaySpreadContentView.swift](../../Spread/Views/Spreads/Content/DaySpreadContentView.swift)). Month/Year don't have an equivalent toolbar row today; proposed placement is next to their existing "Month"/"Year" header text — confirm during SPRD-260 implementation or adjust if it reads awkwardly in practice.
