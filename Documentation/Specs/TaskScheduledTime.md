# Task Scheduled Time

> **Status**: Draft  
> **SPRD tasks**: SPRD-296, SPRD-297, SPRD-298, SPRD-299, SPRD-300, SPRD-301  
> **Session**: SESH-29

## Overview

Tasks gain an optional scheduled time — the moment the user intends to do the task within its assigned day. Entry types declare whether they can carry a user-assigned time via a static capability flag (only Task can; Events carry their own times, Notes have none). On day spreads, a new "Time" sort option integrates timed tasks and calendar events into one chronological flow, with untimed entries listed beneath. The feature spans the SwiftData model, the Supabase `entries` schema and LWW sync, rule-engine migration behavior, the Task entry sheet, entry-row display, and the entry-list sort machinery.

A task's scheduled time is an instantaneous point — no duration and no end time in v1.

---

## Requirements

### Data model [SPRD-296]

- `DataModel.Task` gains `scheduledTime: Date?` — an absolute instant (see Design Decisions). `nil` means no time is assigned; there is no separate boolean flag. [SPRD-296]
- `DataModel.Task` gains `scheduledTimeUpdatedAt: Date?`, the LWW timestamp for the field, following the `dueDate`/`dueDateUpdatedAt` template. [SPRD-296]
- The `Entry` protocol gains `isTimeAssignable: Bool` — a static per-type capability constant following the `isInboxEligible`/`isMigratable`/`isOverdueEligible` pattern (default `false` in the protocol extension; Task `true`; Note and Event `false`). [SPRD-296]
- The `Entry` protocol gains display/sort accessors `scheduledStart: Date?` and `scheduledEnd: Date?` (default `nil`): Task returns `scheduledTime`/`nil`; Event returns `startTime`/`endTime` when `timing == .timed`, else `nil`; Note returns `nil`. All time-integrated sorting and row display dispatch through these — no per-type downcasting at call sites. [SPRD-296]

### Supabase schema and sync [SPRD-297]

- The `entries` table gains `scheduled_time timestamptz` (nullable) and `scheduled_time_updated_at timestamptz` LWW column, following the `due_date` template. [SPRD-297]
- `merge_entry`, the LWW touch trigger, and the batched apply function are extended for the new field pair. [SPRD-297]
- `SyncSerializer`/`SerializableData` round-trip the field for tasks; notes always sync `NULL`. [SPRD-297]
- No production users exist: the change is folded into the squashed `baseline_schema.sql` and applied to `spread-prod` (additive, non-destructive). [SPRD-297]

### Assignment gating and migration behavior [SPRD-298, SPRD-299]

- A time can only be assigned while the task's assignment period is `.day`. [SPRD-299]
- Migrating/reassigning a timed task **day → day** keeps the time: the instant is rebased by the whole-calendar-day delta between source and destination days (clock time preserved in the current timezone). [SPRD-298]
- Migrating/reassigning a timed task to **month, year, multiday, or the Inbox** clears `scheduledTime`. [SPRD-298]

### Entry sheet [SPRD-299]

- `TaskEntrySheet` gains a "Time" add/remove chip (`EntrySheetOptionalFieldChip`) revealing an inline `.hourAndMinute` time picker, visible only when the current assignment selection is day-period with a chosen date. [SPRD-299]
- On save, the stored instant is built from the assigned day + the picked clock time in the device's current timezone. Changing the assignment selection away from day-period hides the chip and discards any pending time. [SPRD-299]

### Entry row display [SPRD-300]

- When `scheduledStart` is non-nil, entry rows render a time block **between the status icon and the title/details column**: start time above end time (end only when `scheduledEnd` exists — events; tasks show a single time), stacked vertically. [SPRD-300]
- The block uses a small standard `SpreadTheme.Typography` style in a subdued (secondary) color and must not increase the current row height. [SPRD-300]

### Time sort integration [SPRD-301]

- `EntrySortOption` gains a `.time` case ordering by `scheduledStart`. [SPRD-301]
- Time sort applies to **day spreads only** and is **mutually exclusive with grouping**: selecting Time forces group-by to None and disables grouping options in `EntryListOptionsPicker` while Time is selected. [SPRD-301]
- Under Time sort, the fixed "Events" section dissolves: timed entries (tasks and events interleaved) render on top in chronological order, followed by a single section of untimed entries labeled "No time" with the `.unnamed` header style (consistent with the SPRD-287 nil-bucket naming). [SPRD-301]
- Timezone-invariant ordering: because every timed entry reduces to an absolute instant, a task scheduled between two events stays between them when the device timezone changes (regression-tested). [SPRD-301]

---

## Design Decisions

### Decision: Time lives on the Task, not the TaskAssignment

- **Context**: Assignments track per-spread status, so a per-spread time was conceivable. But a task has at most one open assignment at a time (`currentAssignments` never holds `.migrated` entries — SPRD-254), so per-spread times have no real use case.
- **Decision**: `scheduledTime` is a field on `DataModel.Task`, like `priority` and `dueDate`.
- **Rationale**: One field, one LWW column, one Supabase column; the time survives migration under explicit rules; avoids muddying the shared Task/Note assignment infrastructure with a task-only concept.
- **SPRD reference**: SPRD-296

### Decision: Absolute instant (`Date?`), not wall-clock time-of-day

- **Context**: A wall-clock representation (minutes since midnight) was considered — it avoids day/time drift and survives migration untouched. But the defining scenario is relational: a task scheduled *between two calendar events* so it gets done between them. Events are absolute instants that shift wall-clock display on timezone change; a wall-clock task time would stay pinned and fall out of position.
- **Decision**: `scheduledTime` is a full `Date` (an absolute instant), matching `Event.startTime` exactly.
- **Rationale**: Ordering against events is timezone-invariant by construction; Task and Event share one time representation, so sorting compares raw `Date`s with no combine-at-render step. A late-night task can display on a neighboring calendar day after a timezone change — the same behavior EventKit events already have.
- **SPRD reference**: SPRD-296

### Decision: Separate nullable field, not a time-carrying `date` plus a `timeAssigned` boolean

- **Context**: An alternative changed `entries.date` to `timestamptz` and added a `time_assigned boolean`, guaranteeing day and time can never disagree.
- **Decision**: Keep `date` day-level; add a separate nullable `scheduled_time` column. `scheduledTime != nil` is the sole "has a time" signal.
- **Rationale**: A parallel boolean next to a value is the exact coupling SPRD-247 removed (`hasPreferredAssignment`) — nothing structural stops flag/value drift. Changing `date`'s meaning would require auditing every consumer (spread matching, indexes, overdue, assignment repair) that assumes day-normalized values, and would coarsen LWW conflict granularity. `Event` already models this concept as `startDate` + optional `startTime`. Day/time coherence is instead guaranteed by three unit-tested write rules: build-from-assigned-day on set, rebase on day→day migration, clear on leaving day period.
- **SPRD reference**: SPRD-296, SPRD-297

### Decision: Time requires a day-period assignment; keep/rebase/clear migration rules

- **Context**: A time-of-day is only meaningful relative to a specific day; tasks can be assigned to month/year/multiday spreads or sit in the Inbox.
- **Decision**: The time chip only appears for day-period assignments. Day→day migration rebases the instant by whole calendar days; moving to any non-day period or the Inbox clears the time.
- **Rationale**: "This day, at this time" is always well-defined; a time on *July 2026* is meaningless and cannot sort against anything. Deferring a task to another day plausibly keeps the intended clock time.
- **SPRD reference**: SPRD-298, SPRD-299

### Decision: Time sort is mutually exclusive with grouping; untimed entries below

- **Context**: Grouping buckets by list/tag/status; a single chronological flow has no buckets, and events have no list/tag/status to group by.
- **Decision**: Selecting Time forces group-by = None and disables grouping in the picker. Timed entries render chronologically on top; untimed entries follow in one "No time" section. Day spreads only in v1.
- **Rationale**: A grouped chronology is self-contradictory; making the exclusivity explicit in the picker avoids a silently-ignored setting. Untimed-below keeps the actionable timed plan first.
- **SPRD reference**: SPRD-301

### Decision: `isTimeAssignable` capability flag on `Entry`

- **Context**: The user-facing rule is "types I declare time-assignable can get a time" — Task yes; Event no (its times come from its own model/EventKit); Note no.
- **Decision**: A static per-type `Bool` constant on the `Entry` protocol with a `false` default, exactly like `isInboxEligible`/`isMigratable`/`isOverdueEligible`.
- **Rationale**: Reuses the established "can this type ever do X" pattern; per-instance eligibility (day-period assignment) stays a separate check at the feature site, per the SPRD-247 decision separating type capability from instance state.
- **SPRD reference**: SPRD-296

---

## Open Questions

- Task durations / end times: explicitly deferred — a scheduled task is instantaneous in v1. Revisit if block-scheduling is requested.
- Multiday spread day-sections adopting the integrated time sort: deferred; day spreads only in v1.
- Quick time-set affordance (row context menu / swipe): deferred; the sheet chip is the only entry point in v1.
