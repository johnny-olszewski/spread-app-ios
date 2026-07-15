# Day Spread Composition

> **Status**: Draft  
> **SPRD tasks**: SPRD-308, SPRD-309  
> **Session**: SESH-32

## Overview

The day spread is the daily working surface, but its entry list shows a partial picture: calendar events sit in a fixed trailing "Events" section (compact width) or are omitted from the list entirely (regular width, where the timeline card shows them), and tasks assigned to the containing multiday/month/year spreads are invisible unless the user navigates away. This feature makes the day list the complete view of the day — events integrate with tasks and notes as ordinary entries so timed work lines up chronologically, and open tasks from the containing broader-period spreads appear below the day's own entries in visually distinct per-period cards, so wider-horizon work stays in mind while planning the day.

---

## Requirements

### Events integrated into the day entry list [SPRD-308]

- Calendar events appear in the day spread's entry list in **both** size classes. The regular-width timeline card is unchanged and continues to render alongside the list — events now appear in both places. [SPRD-308]
- Events flow through the same grouping/sorting pipeline as tasks and notes with no special casing: under list/tag grouping they land in the "No list"/"No tag" bucket; under status/type grouping they occupy their own bucket; under `.none` grouping with Default sort they interleave chronologically with timed tasks. [SPRD-308]
- The fixed trailing "Events" section in `DaySpreadContentView.ViewModel.makeSections` is deleted, along with the `shouldShowTimelineCard`-conditional `eventConfigurationMap` that suppressed event rows in regular width. [SPRD-308]
- Event rows render **no subtitle** — only the title, with the event's times in the leading time block (the SPRD-300 block between the status icon and the title: start above end). All-day events have no `scheduledStart`, so they sort with untimed entries and show no time block. [SPRD-308]

### Containing-period open tasks on the day spread [SPRD-309]

- Below the day's own entry list, the day spread shows the **open tasks** of each containing broader-period spread that exists: every multiday spread whose date range contains the day, the containing month spread, and the containing year spread. [SPRD-309]
- Ordering of the period sections: multiday spread(s) first (nearest horizon), then month, then year. Multiple containing multiday spreads each get their own section. [SPRD-309]
- Only tasks with an **open** assignment on that spread appear — no completed/migrated/cancelled tasks, no notes, no events. [SPRD-309]
- A period section is omitted entirely when its spread does not exist **or** has no open tasks; when no containing spread has open tasks, the area renders nothing (no headers, no empty cards). [SPRD-309]
- Each period section is visually distinct from the day's entries, rendered as a card via the existing `EntryList.SectionStyle.card`, titled with the containing spread's display name (e.g. "July 2026", "2026", the multiday spread's name). [SPRD-309]
- Within each card, tasks are ordered by the user's currently selected day-spread sort option (SPRD-307 semantics). The grouping option does **not** apply inside the cards — each card is a single flat list (the card itself is the group). [SPRD-309]
- Rows use the standard task configuration — complete, edit, and migrate work in place, exactly as on the owning spread. [SPRD-309]
- Lookups are cheap and index-backed: the month and year spreads resolve through the O(1) dictionary-keyed `JournalManager.spreadDataModel(for:period:)`; containing multiday spreads resolve by a linear scan of `spreads` filtered to `.multiday` with date-range containment (small N, no per-task work until a spread matches). Open-task filtering uses each `SpreadDataModel`'s already-indexed task set. [SPRD-309]

---

## Design Decisions

### Decision: Events are fully integrated — the fixed "Events" section is deleted

- **Context**: Events were kept outside the user-selectable grouping (fixed trailing section) because they have no list/tag assignment, and were dropped from the list in regular width because the timeline card already showed them.
- **Decision**: Events become ordinary entries in the pipeline in both size classes: nil-bucket under list/tag grouping, own bucket under status/type, chronological interleave under Default. No conditional configuration maps.
- **Rationale**: The point of scheduled times (SPRD-296–301) is seeing how the day lines up; that requires events in the same flow as timed tasks, and the timeline card is a visual complement, not a substitute row list. One code path replaces two special cases (fixed section + regular-width suppression).
- **SPRD reference**: SPRD-308

### Decision: Event rows carry no subtitle

- **Context**: Event rows currently render display details (calendar/date info) as a subtitle, which duplicates what the leading time block and day context already convey inside a day spread.
- **Decision**: In the day entry list, event rows show only the title plus the leading time block (start over end).
- **Rationale**: Times are the only event metadata that matters when scanning a day; a subtitle adds row height and noise without information.
- **SPRD reference**: SPRD-308

### Decision: Multiday spreads are the "week" tier

- **Context**: The requested hierarchy was "week, month, year," but Spread has no week period — supported periods are year/month/day/multiday, and week is explicitly unsupported.
- **Decision**: Any multiday spread whose range contains the day serves as the week-equivalent tier. No new period is introduced.
- **Rationale**: Multiday spreads are how users model week-like ranges in Spread; adding a real week period would ripple through the data model, sync, and navigation for no additional expressive power.
- **SPRD reference**: SPRD-309

### Decision: A second `EntryListView` below the day list, not extra sections inside it

- **Context**: The period cards could be sections appended to the day list's `[EntryList.Section]`, or a separate `EntryListView` stacked below. (`EntryListView` renders `SectionStyle.card` sections inline in section order — a stale doc comment on `SectionStyle` claiming card sections are extracted above the list does not match the implementation — so either shape renders correctly.)
- **Decision**: A second `EntryListView` instance below the day's list, containing one card-styled section per containing period. Both lists share the pager-provided scroll (neither owns a `ScrollView`, per the existing rule).
- **Rationale**: The two lists have genuinely independent inputs and behavior: the day list is built from the day's own entries with the user's grouping applied, a quick-add per section, and an empty-state message; the period-card list is built from other spreads' data models, ignores grouping, and disappears entirely when empty. Appending its sections into the day list would couple `makeSections` to parent-spread lookups for no rendering benefit.
- **SPRD reference**: SPRD-309

### Decision: Open tasks only

- **Context**: The containing spread itself shows all its entries; the day spread could mirror that or filter.
- **Decision**: Only tasks with an open assignment on the containing spread appear.
- **Rationale**: The purpose is "what's still outstanding at a broader horizon while I plan today" — completed and migrated work is noise here, and notes/events belong to their own surfaces.
- **SPRD reference**: SPRD-309

---

## Open Questions

- Per-period card accent colors (the `SectionStyle.card(Color)` parameter) — pick during implementation; must read correctly in light and dark mode.
- Tapping a period card's header to navigate to that spread — not in scope for v1; revisit if the cards create a "how do I get there" itch.
- Quick-add affordance inside period cards (create a task directly on the month/year spread from the day view) — deferred; the day list's existing quick-add is unchanged.
