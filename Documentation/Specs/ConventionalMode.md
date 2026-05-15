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
- Traditional mode `Today` always navigates to the traditional day destination for today. [SPRD-130]
- If `Today` is pressed while today is already the selected spread, it still refreshes the compact context bar and content pager on today's selection if needed. [SPRD-130]

### Modes
- Conventional: [SPRD-13, SPRD-14, SPRD-25, SPRD-31]
  - Entries may appear on multiple spreads with per-spread status. [SPRD-15]
  - Spreads must be created explicitly. [SPRD-12, SPRD-26]
  - Unassigned entries go to global Inbox. [SPRD-14, SPRD-31]
  - Inbox auto-resolves when a matching spread is created. [SPRD-14, SPRD-31]
  - Inline migration affordances exist only in conventional mode. [SPRD-110, SPRD-140]
- Traditional: [SPRD-17, SPRD-35, SPRD-38]
  - Entries appear only on preferred assignment, no migration history visible. [SPRD-17, SPRD-35]
  - All spreads available for navigation regardless of created spread records. [SPRD-17, SPRD-38]
  - Must not mutate the "created spreads" data used by conventional mode. [SPRD-17, SPRD-53]
  - Migrating updates the preferred date/period; conventional assignments recomputed. [SPRD-17, SPRD-15]
  - If no conventional spread exists for migration target, assign to nearest parent or Inbox. [SPRD-17, SPRD-14]
  - Traditional mode does not show migration prompts because all calendar spreads are navigable without waiting for created conventional spreads. [SPRD-110]
- Traditional mode does not gain any separate overdue review affordance; overdue spread badges are only shown in navigator surfaces where spread destinations are listed. [SPRD-147]
