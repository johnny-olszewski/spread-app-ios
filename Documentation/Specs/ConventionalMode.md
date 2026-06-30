# Conventional Mode

> Source: Documentation/spec.md

## Functional Requirements

### Spreads
- Create a spread for a given period/date with period-based date normalization. [SPRD-7, SPRD-8, SPRD-12]
- Creation rules: allow present or future dates only (no past). [SPRD-12, SPRD-50]
- Multiday creation can start in the past if it is within the current week. [SPRD-12, SPRD-50]
- Multiday presets follow user's first day of week setting; allow override in creation UI. [SPRD-8, SPRD-26, SPRD-49]
- Multiday spreads are creatable (range can be custom start/end or presets like "this week"/"next week"). [SPRD-8, SPRD-26]
- New multiday spreads must not overlap existing multiday spreads; create/edit validation blocks overlaps while grandfathering pre-existing legacy overlaps in synced data. [SPRD-193]
- Multiday spreads are directly assignable destinations. The app never recommends creating them, but once they exist they participate in conventional assignment resolution and migration as explicit optional tools. [SPRD-18, SPRD-13, SPRD-193]

### Spread Deletion
- Deleting a year/month/day spread reassigns all entries (open, completed, migrated) to the parent spread. [SPRD-15]
- If no parent spread exists, entries go to Inbox. [SPRD-14, SPRD-15]
- Entries are NEVER deleted when a spread is deleted; history is preserved. [SPRD-15]
- Deletion is blocked if it would orphan entries with no valid destination. [SPRD-15]
- Deleting a multiday spread reassigns its entries through the normal non-multiday fallback hierarchy based on each entry's preferred date and preferred period, or Inbox when no valid explicit destination exists. Entries are never deleted. [SPRD-18, SPRD-193]

### Entries (Tasks/Notes)
- Create entries with title, preferred date, preferred period, and type. [SPRD-9, SPRD-23]
- Tasks support status (open/complete/migrated/cancelled). [SPRD-9, SPRD-24]
- Notes support status (active/migrated). [SPRD-9]
- Tasks and notes can be assigned to year, month, multiday, or day spreads. [SPRD-13, SPRD-193]
- Notes are not suggested for batch migration but can be migrated explicitly. [SPRD-15, SPRD-34]
- Creating entries for past dates is not allowed in v1. [SPRD-23, SPRD-56]
- Task creation UI (v1): [SPRD-23, SPRD-71]
  - Task creation uses a sheet with title + period (year/month/multiday/day) + period-appropriate controls.
  - Defaults to the selected spread's period/date; if none selected, uses initial selection logic. [SPRD-25]
  - Date validation uses period-normalized comparison (current month/year allowed). [SPRD-23]
  - Inline validation with Create button shown after first edit; whitespace-only titles are invalid. [SPRD-23]
  - Optional picker to choose from existing spreads or select a custom date; choosing a date without a matching spread is allowed (Inbox fallback). [SPRD-71, SPRD-14]
  - A unified assignment picker replaces the old split between period/date pickers and `select from existing spread`:
    - `year`, `month`, and `day` show all valid assignment destinations for the chosen preference, with already-created explicit spreads visually distinguished from uncreated implicit destinations
    - `multiday` shows only already-created explicit multiday spreads
    - choosing an uncreated `year`, `month`, or `day` destination is allowed and follows the existing fallback behavior until that explicit spread is created [SPRD-71, SPRD-14, SPRD-193]
- Task edit UI (v1): [SPRD-24, SPRD-141]
  - Task edit uses the same shared period/date normalization path as task creation.
  - The edit sheet does not expose `migrated` as a selectable status.
  - Status is controlled by a reusable icon-only component that visually matches the entry-list status affordance.
  - The status icon toggles draft state `open <-> complete`; the title remains trailing, matching entry-row layout.
  - `Cancel Task` / `Restore Task` are bottom-sheet actions; `Delete Task` remains separate.
  - Period is selected with a menu-style picker.
  - Date uses a menu-style summary row plus the existing inline period-appropriate picker below it.
  - Draft edits do not persist until `Save` is tapped.
  - When draft status is `complete` or `cancelled`, period/date controls remain visible but are disabled; assignment history remains visible.
  - If draft status is returned to `open` before save, period/date controls become editable again immediately.
- Delete entries across all spreads. [SPRD-11, SPRD-5]
- EventKit events appear read-only on day and multiday spreads. [SPRD-194, SPRD-195]

### Task Status
- Statuses: open, complete, migrated, cancelled. [SPRD-10, SPRD-24]
- User-editable task statuses are `open`, `complete`, and `cancelled`; `migrated` remains assignment/history-only. [SPRD-141]
- Cancelled tasks are hidden in v1 (excluded from Inbox, migration, and default lists). [SPRD-16, SPRD-31]
- Shared status iconography for task rows and the task edit sheet must come from one source of truth so symbol/icon changes update both surfaces together. [SPRD-141]

### Overdue Tasks
- Overdue review is task-only and global across the journal. [SPRD-112]
- Only tasks whose current actionable state is `open` can be overdue. Completed, migrated-history-only, and cancelled tasks are not overdue. [SPRD-112]
- Overdue is determined by the task's current open assignment when one exists. [SPRD-112]
  - Day-assigned task: overdue after that assigned day has passed.
  - Multiday-assigned task: overdue after that assigned multiday spread's end date has passed.
  - Month-assigned task: overdue only after the assigned month has fully passed.
  - Year-assigned task: overdue only after the assigned year has fully passed.
- If a task is still in `Inbox`, overdue falls back to the task's desired assignment period/date. [SPRD-112]
- Overdue examples using absolute dates: [SPRD-112]
  - Assume today is `January 12, 2026`. A task open on `January 10, 2026` day is overdue.
  - Assume today is `January 12, 2026`. A task open on `January 2026` month is not overdue yet; it becomes overdue on `February 1, 2026`.
  - Assume today is `June 1, 2026`. A task open on `2026` year is not overdue yet; it becomes overdue on `January 1, 2027`.
  - Assume today is `February 1, 2026`. A task still in `Inbox` with desired assignment `January 2026` month is overdue.
  - Assume today is `January 11, 2026`. A task still in `Inbox` with desired assignment `January 10, 2026` day is overdue.
- Overdue remains based on the current open assignment until the user actually migrates the task; the existence of a finer valid destination does not change overdue status by itself. [SPRD-112]
- Overdue threshold table (absolute-date reference cases): [SPRD-113]

| Today | Current open assignment or Inbox desired assignment | Overdue? | Reason |
| --- | --- | --- | --- |
| `January 12, 2026` | `January 10, 2026` day assignment | Yes | Day tasks become overdue once that assigned day has passed. |
| `January 12, 2026` | `January 2026` month assignment | No | Month tasks are not overdue until the entire assigned month has passed. |
| `February 1, 2026` | `January 2026` month assignment | Yes | The entire assigned month has passed. |
| `June 1, 2026` | `2026` year assignment | No | Year tasks are not overdue until the assigned year has fully passed. |
| `January 1, 2027` | `2026` year assignment | Yes | The entire assigned year has passed. |
| `February 1, 2026` | `Inbox` task with desired assignment `January 2026` month | Yes | Inbox falls back to the desired assignment period/date when no open spread assignment exists. |
| `January 11, 2026` | `Inbox` task with desired assignment `January 10, 2026` day | Yes | Inbox day tasks become overdue after the desired day passes. |

### Overdue Card in Day Spread (SPRD-235)

- When the current spread is a day spread for today, an overdue card is shown above the entry list when `JournalManager.overdueTaskItems` is non-empty. [SPRD-235]
- The overdue card is rendered as a visually distinct card: `RoundedRectangle` background at low opacity with a solid stroke border. Color is caller-supplied via `EntryList.Section.Style.card(Color)`. [SPRD-235]
- The overdue card contains one `EntryList.Section` per distinct source spread (or Inbox) that has overdue tasks, grouped by `OverdueTaskItem.sourceKey`. [SPRD-235]
- Each section in the card renders tasks using the same `EntryRowView.Configuration` as the standard task rows (status toggle, migrate, delete, edit). No overdue-specific actions in v1. [SPRD-235]
- The card disappears automatically when all overdue tasks have been acted on (i.e., `overdueTaskItems` becomes empty). There is no manual dismiss. [SPRD-235]
- The card is scoped to `DaySpreadContentView` only in v1. The general mechanism (`Section.Style`) is designed for reuse but no other call site uses it yet. [SPRD-235] — **Superseded by SPRD-274**: the card is no longer Day-only; see below.

### Overdue Card on All Spread Content Views (SPRD-274)

- The overdue card is no longer scoped to `DaySpreadContentView`. It appears on **any** spread content view (Day, Month, Year, Multiday), but only on the *most granular* spread that contains today — not on every spread that merely contains today. A spread qualifies exactly when it is `[DataModel.Spread].bestSpread(for:calendar:)`'s result for today (the same priority cascade already used by the Today button and default navigation): day spread for today > narrowest multiday spread containing today > month spread containing today > year spread containing today. If today has both an explicit day spread and its parent month spread, only the day spread shows the card — the month spread shows nothing, even though it also "contains" today. [SPRD-274]
- The card-building logic (querying `JournalManager.overdueTaskItems`, checking the spread-is-most-granular-for-today condition, and grouping into one `EntryList.Section` per source spread/Inbox) is extracted into a standalone, reusable `OverdueCardView(spread:context:)` component. It takes the current spread plus the existing `SpreadPageContext` bundle (already carrying `JournalManager`/calendar) — no other injected dependency. It renders nothing (`EmptyView`) when the spread isn't `bestSpread(for: today)` or there are no overdue items. [SPRD-274]
- `OverdueCardView` renders via the same `EntryListView` + `EntryList.Section.Style.card` mechanism `DaySpreadContentView` already used — no new visual chrome, no new rendering path. [SPRD-274]
- Each content view places `OverdueCardView` as the first element of its *scrollable* content, before any of its own period-specific content: [SPRD-274]
  - Day: before the existing entry list (unchanged from current behavior).
  - Year: above the top year-entry section.
  - Multiday: above the day-card grid, full width (same width treatment as the existing multiday-assignment section).
  - Month: **requires a layout restructuring**. Today, `MonthSpreadContentView` puts everything — the calendar grid, the month section, and the day sections — inside one scrollable `LazyVStack`. Every other content view keeps a non-scrolling element pinned above its scrollable content (Day's favorite/edit header row; the pager's own header above Year/Multiday). Month is the outlier: it has no fixed top inset today. As part of this task, the month calendar grid moves out of the scrollable `LazyVStack` into a fixed top inset above the `ScrollView` (non-scrollable, always visible), and `OverdueCardView` becomes the first item inside the now-calendar-free `ScrollView`/`LazyVStack`, ahead of the month section and day sections. [SPRD-274]
- Source chips (the per-task label identifying which spread/Inbox an overdue task currently lives on) are preserved on every content view, not just Day — overdue tasks shown from a Month/Year/Multiday spread can originate from many different source spreads, so the chip remains useful everywhere. [SPRD-274]
- `DaySpreadContentView` is refactored to consume `OverdueCardView` instead of its own `ViewModel.overdueSections` computed property; this is a pure extraction with no visual or behavioral change to Day's existing overdue card. [SPRD-274]
- Multiday's existing per-day-card `overdueCount` badge (`MultidayDayCardView`) is a separate, unrelated mechanism (a count badge on each day card within a multiday grid) and is unaffected by this task. [SPRD-274]

#### Overdue Card Rows: Read-Only Except the Status Icon

- Overdue card rows are mostly a review/navigation surface, not an editing surface — but the status icon remains fully interactive (see below). This applies on every content view that shows the card (Day, Month, Year, Multiday). [SPRD-274]
- Tapping anywhere on an overdue row other than the status icon navigates immediately to that task's current source: [SPRD-274]
  - Source is a concrete spread (day/month/year/multiday): navigates directly to that spread via `SpreadsCoordinator.selectSpread`, no confirmation.
  - Source is Inbox (no spread assignment): shows an informational alert ("Task in Inbox" / "This task can't be modified from here. Open the Search tab to view and edit it.") since there is no spread to navigate to. Building cross-tab navigation from the Spreads tab to the Entries tab's Inbox section is out of scope for this task — no existing mechanism supports that direction (only Entries→Spreads exists, via `SpreadsNavigationState`).
- Inline title editing (tap-to-rename) and the long-press context menu (Edit/Migrate/Delete) are both disabled on overdue rows. [SPRD-274]
- Implemented as a new `EntryRowView.Configuration.onRowTap` field (a per-row tap target distinct from `onStatusIconTap`) and a new `EntryRowView.Configuration.readOnlyOverdueTaskConfig(...)` factory, used only by `OverdueCardView`. When `onRowTap` is set, `EntryRowView` disables its title `TextField` and replaces its long-press context menu with a plain tap gesture routed to `onRowTap` — this is a general mechanism on `EntryRowView` itself, not something bolted onto the overdue card specifically, so any future review-only surface can reuse it. [SPRD-274]
- **Pre-existing bug fixed as a prerequisite**: `SpreadsTabView`'s alert presentation (`.modifier(AlertModelModifier(...))`) was commented out (`// TODO: Re-add alert`), so `SpreadsCoordinator.activeAlert` was already silently doing nothing for every alert app-wide (delete confirmations, discard-changes prompts) before this task. Re-enabled as part of this work since the Inbox notice alert depends on it. [SPRD-274]

#### Overdue Card Status Icon: Status Change With a Grace Period

- **Revised decision (superseding the original "status icon shows a confirm-before-navigate alert" design above)**: the status icon on an overdue row is fully interactive — tapping it rotates status the same way it does on every other task row in the app: open → complete → cancelled → open. There is no confirmation alert for this. [SPRD-274]
- **The problem this solves**: marking an overdue task complete or cancelled immediately removes it from `JournalManager.overdueTaskItems`, and therefore from the card, the instant the tap registers — before the user can register what happened or change their mind (e.g. meant to cancel, tapped into complete first). [SPRD-274]
- **The fix**: a 5-second grace period. When a tap rotates a task away from `.open`, the row keeps showing in the card for 5 seconds even though the task is no longer a live entry in `overdueTaskItems` — using the task's current (post-tap) status for display (greyed out / strikethrough, matching standard task-row treatment), and the source chip captured at the moment of the tap (since the task's source key isn't derivable from `overdueTaskItems` once it's no longer in that list). [SPRD-274]
- Tapping the status icon again within the grace window (e.g. complete → cancelled) restarts the 5-second window from that tap, rather than the row disappearing mid-decision while the user is still actively changing their mind. Rotating back to `.open` within the window clears the grace period immediately — the row then either keeps showing (if still genuinely overdue) or disappears (if not) based on live data, with no artificial delay either way. [SPRD-274]
- Implemented entirely in `OverdueCardView` (not `EntryRowView` or its configuration, which know nothing about grace periods): `@State` dictionaries track each grace-period task's expiration time and snapshotted source key. `OverdueCardView.sections(for:context:graceTaskIDs:graceSourceKeys:onStatusIconTap:)` takes these as parameters (with empty defaults) specifically so the section-building logic stays a pure, directly unit-testable function — the actual timer (`Task.sleep` plus a re-check that the grace entry's expiration hasn't been superseded by a newer tap) lives in the view's `handleStatusIconTap`, which isn't itself unit-tested (no hosted-view test harness in this codebase makes waiting out a real 5-second timer practical) and is left to manual verification instead. [SPRD-274]
- **Entries are always sorted by date, then title — status changes never reorder the list.** `sections(for:context:)` explicitly sorts the combined (live + grace-period) entries by `(sortDate, title)` before returning them. This was a real bug, not a hypothetical: `JournalManager.tasks` (the source for `overdueTaskItems`'s order, and for grace-period task lookups) is itself sorted by `createdDate`, which has nothing to do with the date relevant to the overdue card, and grace-period tasks were being appended after all live entries — so completing a task visibly moved it to the bottom of the list the instant it left `overdueTaskItems`, rather than holding its date-correct position during its grace window. [SPRD-274]

#### `EntryList.Section.Style` — Generic Section Styling

- `EntryList.Section` gains an optional `style: EntryList.Section.Style?` property, defaulting to `nil` (standard rendering). [SPRD-235]
- `EntryList.Section.Style` is an enum with one case in v1: `.card(Color)`. [SPRD-235]
- `EntryListView` in `.list` mode splits sections into two groups before rendering:
  - Card-styled sections (`style != nil`) are rendered above the `List {}` in a `VStack`, each wrapped in the appropriate card chrome.
  - Standard sections (`style == nil`) are rendered inside the `List {}` as today.
- `EntryListView` and `EntryRowView` have no knowledge of the overdue concept — they only respond to `Section.Style`. [SPRD-235]
- Card sections in `.inline` mode render identically to standard sections (card chrome is list-mode-only in v1). [SPRD-235]

### Inbox
- Unassigned entries (tasks/notes) are stored in a global Inbox. [SPRD-14]
- Inbox is surfaced as the first section inside the global search tab's task browser rather than a spread-toolbar button or standalone sheet. [SPRD-148]
- The global task browser uses a top-level tab item with `.search` role. [SPRD-148]
- The Inbox section contains only tasks currently shown in Inbox. [SPRD-148]
- Inbox auto-resolves when a matching spread is created. [SPRD-14, SPRD-31]
- Cancelled tasks are excluded from Inbox. [SPRD-16]
- A standalone `Today` text button appears as a `.glassEffect` overlay button anchored to the bottom-leading corner of the spread content view on both iPhone and iPad. It is always visible regardless of the currently selected spread. [SPRD-130]
- Pressing `Today` navigates to the smallest-granularity spread containing the current absolute today date and synchronizes all spread navigation surfaces, including the selected spread, compact spread context bar, and horizontal content pager. [SPRD-130]
- Conventional mode `Today` target resolution: [SPRD-130]
  - Prefer an explicit day spread for today when it exists.
  - Otherwise prefer the narrowest explicit multiday spread whose range contains today.
  - Otherwise fall back to an explicit month spread for today's month.
  - Otherwise fall back to an explicit year spread for today's year.
  - If multiple multiday spreads contain today, choose the narrowest containing range; break ties by the existing chronological spread ordering.
  - If no explicit spread contains today, the button currently does nothing.
- If `Today` is pressed while today is already the selected spread, it still refreshes the compact context bar and content pager on today's selection if needed. [SPRD-130]

### Mode
The app operates in conventional mode only. Traditional mode is out of scope for v1. [SPRD-226]
- Entries may appear on multiple spreads with per-spread status. [SPRD-15]
- Spreads must be created explicitly. [SPRD-12, SPRD-26]
- Unassigned entries go to global Inbox. [SPRD-14, SPRD-31]
- Inbox auto-resolves when a matching spread is created. [SPRD-14, SPRD-31]
- Inline migration affordances exist in conventional mode. [SPRD-110, SPRD-140]
