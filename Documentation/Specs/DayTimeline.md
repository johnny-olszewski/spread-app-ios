# Day Timeline Visual Overhaul

> **Status**: Draft  
> **SPRD tasks**: SPRD-237  
> **Session**: SESH-##

## Overview

`DayTimelineView` (in `johnnyo-foundation`) currently renders overlapping events as cascading offset blocks and has no current-time indicator. `SpreadDayTimelineContentGenerator` shows only an event title. This spec covers a ground-up visual and layout overhaul: side-by-side column layout for concurrent events, a live current-time red line, richer event block content (title + time + location), scroll-to-current-time on open, a minimum event height floor, and all-day chip polish — bringing the timeline in line with Apple Calendar's visual standard.

---

## Requirements

### Column Layout for Concurrent Events

- When two or more events overlap in time, they are partitioned into side-by-side columns rather than cascading offsets. [SPRD-237]
- `DayTimelineView` computes collision clusters: groups of events where at least one pair overlaps. Within each cluster, events are assigned to columns using a greedy interval-scheduling algorithm (earliest start first, placed in the leftmost column that has no conflict). [SPRD-237]
- `DayTimelineItemContext` gains two new fields: `columnIndex: Int` (0-based) and `columnCount: Int` (total columns in the cluster). The provider uses these to compute the rendered width and x-offset of the event block. [SPRD-237]
- The `overlapOffset` field on `DayTimelineItemContext` is removed; it is replaced by `columnIndex`/`columnCount`. [SPRD-237]
- `SpreadDayTimelineContentGenerator.itemView(context:)` uses `columnIndex` and `columnCount` to position each block at `x = columnIndex * (availableWidth / columnCount)` and render it at `width = availableWidth / columnCount`. [SPRD-237]
- Single events (no overlap) occupy the full available width as before. [SPRD-237]

### Current Time Indicator

- `DayTimelineView` renders a live current-time indicator using `TimelineView(.everyMinute)` internally — no app-side timer or binding required. [SPRD-237]
- The indicator is only visible when the displayed `date` is today (calendar comparison) and the current time falls within the visible window (`visibleStartHour`–`visibleEndHour`). [SPRD-237]
- The indicator consists of: a small filled red circle on the leading edge of the event zone (touching the ruler boundary) and a full-width red horizontal line at the same Y position. [SPRD-237]
- The indicator renders above all event blocks (highest Z order in the event zone). [SPRD-237]
- Color: `Color.red` (system red), matching Apple Calendar's convention. [SPRD-237]

### Scroll-to-Current-Time

- `DayTimelineScrollView` currently auto-scrolls to the first timed event on appear. When the displayed `date` is today, it scrolls to the current time's Y position instead (so the red line is visible near the top of the scroll view). [SPRD-237]
- When the date is not today, existing behavior is preserved: scroll to the first event (or no-op if no events). [SPRD-237]
- The scroll offset targets the current time minus a small top margin (e.g., 60pt above the current time line) so the indicator isn't flush against the top edge. [SPRD-237]

### Event Block Content

- `SpreadDayTimelineContentGenerator` renders each timed event block with: [SPRD-237]
  - **Title** — top-leading, `.caption.weight(.semibold)`, 1–2 lines, truncated with `lineLimit`
  - **Time range** — below the title, `.caption2`, respects device locale 12h/24h via `DateFormatter` with `timeStyle: .short`; shows "start – end" (e.g., `2:00 PM – 3:30 PM`)
  - **Location** — below the time range, `.caption2`, `.secondary` foreground, 1 line, omitted entirely when `CalendarEvent.location` is nil or empty
- When the block height is too short to show time and/or location, lower rows are hidden gracefully (title always visible as the floor). [SPRD-237]
- The colored left bar (3pt wide, calendar color) and tinted background are retained from the current design. [SPRD-237]

### Minimum Event Block Height

- Events shorter than 30 minutes receive a minimum rendered height of `44pt` so the title remains readable. [SPRD-237]
- The `DayTimelineView` enforces this floor when computing `DayTimelineItemContext.height` — if the proportional height for the event's duration is less than `44`, the height is clamped to `44`. [SPRD-237]
- Enforcing the floor at the foundation layer means providers do not need to handle this case themselves. [SPRD-237]

### CalendarEvent Location Field

- `CalendarEvent` gains `var location: String?`. [SPRD-237]
- `LiveEventKitService` (or the mapping site where `EKEvent` → `CalendarEvent` conversion occurs) maps `EKEvent.location` to `CalendarEvent.location`. `EKEvent.location` is already `String?`. [SPRD-237]
- `MockCalendarEventService` and any test builders that construct `CalendarEvent` values must be updated to accept the new optional field (defaults to `nil`). [SPRD-237]

### All-Day Section Polish

- All-day chips in `DayTimelineAllDaySection` are rendered as pill-shaped capsules with the calendar color at low opacity as the background fill and the event title in the calendar color as the foreground. [SPRD-237]
- Layout is compact: chips wrap horizontally using `FlowLayout` or a wrapping `HStack` arrangement when multiple all-day events exist. [SPRD-237]
- Each chip shows only the event title (no calendar name, no color bar). [SPRD-237]

---

## Design Decisions

### Decision: Column partitioning in `johnnyo-foundation` via `DayTimelineItemContext`

- **Context**: Side-by-side columns require knowing how many concurrent events share a time slot and which column a given event occupies. The foundation could either own this math entirely (exposing it via context) or leave it to the provider.
- **Decision**: Foundation owns the column partition algorithm. `DayTimelineItemContext` carries `columnIndex` and `columnCount`. The provider uses these values to compute its rendered position and width.
- **Rationale**: Layout math (interval scheduling, cluster detection) belongs in the foundation alongside the existing Y-position math. Providers remain appearance-only. The context fields are purely additive data — the provider is free to ignore them for single-column cases.
- **SPRD reference**: SPRD-237

### Decision: `TimelineView(.everyMinute)` for current time — foundation-owned

- **Context**: The current time indicator needs to update live. Options were a SwiftUI `TimelineView` inside the foundation view, or a `Date` binding driven by the app.
- **Decision**: `TimelineView(.everyMinute)` is embedded directly in `DayTimelineView`. The app provides no timer.
- **Rationale**: Zero app-side wiring. Minute-level precision matches Apple Calendar. `TimelineView` re-renders are scoped to the timeline view itself — no upstream performance impact.
- **SPRD reference**: SPRD-237

### Decision: Minimum height floor enforced at the foundation layer

- **Context**: Very short events (< 30 min) produce small blocks where text is unreadable. The floor could be enforced by the provider (in `itemView`) or by the foundation (in `DayTimelineItemContext.height`).
- **Decision**: Foundation enforces the 44pt minimum in `DayTimelineItemContext.height`. Providers receive the already-clamped value.
- **Rationale**: Providers should not need to duplicate minimum-height logic. Enforcing at the foundation ensures all providers benefit and keeps the rendering contract simple.
- **SPRD reference**: SPRD-237

### Decision: Scroll to current time (today) vs. first event (other days)

- **Context**: `DayTimelineScrollView` currently scrolls to the first event regardless of date.
- **Decision**: Scroll target is the current time (minus a 60pt top margin) when `date` is today; first event otherwise.
- **Rationale**: On today's view, the current time line is the most relevant anchor. On past or future days, the first event is still the best default since there is no meaningful "now."
- **SPRD reference**: SPRD-237

---

## Open Questions

- Should `DayTimelineScrollView` re-scroll to the current time on every minute tick, or only on first appear? (e.g., if the user manually scrolled elsewhere mid-day, should the view pull them back?) — Resolve during SPRD-237 implementation; default to scroll-on-appear only.
- FlowLayout for all-day chips: use a third-party layout or implement a simple wrapping `HStack`? — Resolve during implementation; prefer a simple custom `Layout` if wrapping chips are needed.
