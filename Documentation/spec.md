# Bulleted Specification (v1.0)

## Status
- Specification finalized for v1 implementation (tasks + notes only). [SPRD-1]
- Events (including calendar integrations) are deferred to v2. [SPRD-69]

## Project Summary
- Multiplatform app (iPadOS primary, iOS) built in SwiftUI with SwiftData local storage + Supabase sync. [SPRD-1, SPRD-5, SPRD-80]
- Adaptive UI: top-level navigation adapts by device using a single `TabView` root configured with SwiftUI's adaptive tab APIs. On iPhone it presents as a tab bar; on iPad it uses Apple's sidebar-adaptable presentation rather than a custom split-view shell. Spread navigation uses an in-view horizontal spread-title navigator on both platforms, and the selected spread capsule presents a rooted spread navigator as a popover on iPad and a sheet on iPhone; traditional mode remains calendar-driven. A dedicated top-level search-role tab replaces the old Inbox toolbar flow and hosts the global task browser. [SPRD-19, SPRD-25, SPRD-35, SPRD-38, SPRD-125, SPRD-126, SPRD-143, SPRD-148]
- Core entities (v1): [SPRD-8, SPRD-9, SPRD-10]
  - Spread: period (day, multiday, month, year) + normalized date. [SPRD-8]
  - Entry: protocol for task and note with type-specific behaviors. [SPRD-9]
  - Task: assignable entry with status and migration history. [SPRD-9, SPRD-10]
  - Note: assignable entry with explicit-only migration. [SPRD-9, SPRD-34]
  - TaskAssignment/NoteAssignment: period/date/status for migration tracking. [SPRD-10, SPRD-15]
- Events are a v2 integration (calendar-backed date-range entries), not part of v1 UI/flows. [SPRD-57]
- JournalManager owns in-memory data model, assignment logic, migration, spread creation, and deletion. [SPRD-11, SPRD-13, SPRD-15]
- Two UI paths: [SPRD-25, SPRD-35, SPRD-38]
  - Conventional UI with hierarchical spread tab bar (year/month/day/multiday), entry list, inline migration controls/history, and settings. [SPRD-25, SPRD-27, SPRD-30, SPRD-140]
  - Calendar-style UI for traditional mode with year/month/day drill-in. [SPRD-35, SPRD-38]
- BuJo modes: "conventional" (migration history visible) and "traditional" (preferred assignment only). [SPRD-20, SPRD-17]

## Goals
- Deliver a tab-based bullet journal focused on spreads, tasks, and notes, with an in-view horizontal spread navigator, a selected-spread navigator surface presented as an iPad popover and iPhone sheet, manual migration, and clear task history in conventional mode. [SPRD-25, SPRD-15, SPRD-29, SPRD-125, SPRD-126]
- Provide calendar-style navigation in traditional mode (year/month/day) without altering created-spread data. [SPRD-17, SPRD-35, SPRD-38]
- Support offline-first usage with SwiftData local storage and Supabase sync. [SPRD-80, SPRD-85]
- Require authentication for all product usage in dev/prod environments, while preserving offline access for users with an existing cached session and local data. [SPRD-104, SPRD-106]
- Preserve a debug-only `localhost` mode for engineering workflows; it uses mock auth, supports mock data loading, is selected per launch, and never persists across launches. [SPRD-105, SPRD-107]

## Non-Goals (v1)
- Search, filters, or tagging. [SPRD-56]
- Week period in Period enum or week-based task assignment. [SPRD-8, SPRD-56]
- Automated migration. [SPRD-15, SPRD-56]
- Advanced collection types beyond plain text pages. [SPRD-39, SPRD-56]
- Events (manual creation or calendar integrations) are deferred to v2. [SPRD-69]
- Localization - hardcoded English strings for v1. Revisit post-v1.
- macOS support - planned for future versions.
- Realtime updates (Supabase Realtime) in v1.

## Platform
- iPadOS 26+ (primary platform). [SPRD-1]
- iOS 26+ (iPhone support). [SPRD-1]
- macOS: Out of scope for v1; planned for future versions.

### Multiplatform Strategy
- Adaptive layouts using size classes: [SPRD-19, SPRD-25]
  - A single top-level `TabView` is used for all devices. [SPRD-143]
  - Regular width (iPad): the root `TabView` uses SwiftUI's sidebar-adaptable presentation so top-level destinations are surfaced through Apple's adaptive sidebar/tab model rather than a custom `NavigationSplitView`. Spread navigation stays in the spread view via a centered horizontal spread-title navigator, whose selected capsule can open the rooted spread navigator popover.
  - Compact width (iPhone): the same root `TabView` presents as a bottom tab bar; the same centered horizontal spread-title navigator appears in the spread view, and its selected capsule opens the same rooted spread navigator content in a large sheet.
  - Top-level destinations remain flat, first-class destinations: `Spreads`, `Collections`, `Settings`, and `Debug` when available. [SPRD-19, SPRD-143]
  - User tab/sidebar customization is out of scope for v1; the adaptive tab structure is app-defined and non-customizable. [SPRD-143]
  - `NavigationTab` remains the single source of truth for top-level destination identity and selection. [SPRD-143]
  - The navigation shell keeps an explicit layout/testing override so previews and tests can force compact vs regular adaptive behavior deterministically without maintaining separate root container implementations. [SPRD-143]
- iPad multitasking support: [SPRD-19]
  - Split View (1/3, 1/2, 2/3 configurations)
  - Slide Over
  - App works correctly at all supported sizes
- All views must be responsive and adapt to available space. [SPRD-19]

---

## Core Concepts

### Entry Architecture
- Entry: Protocol defining shared behavior (id, title, createdDate, entryType). [SPRD-9]
- Entry types are separate SwiftData @Model classes for type-safe queries and scalability. [SPRD-9]
- EntryType enum: `.task`, `.note` (v1) - used for UI rendering and type discrimination. [SPRD-9]
- `.event` entry type is reserved for v2 integration and not exposed in v1. [SPRD-57]
- AssignableEntry protocol (Task, Note): adds date, period, assignments array. [SPRD-9]
- DateRangeEntry protocol (Event) is reserved for v2 calendar integration. [SPRD-57]

### Spread
- A journaling page tied to a time period and normalized date. [SPRD-8]
- Periods supported for creation: year, month, day, multiday. [SPRD-8, SPRD-12]
- Week period is NOT supported (removed from Period enum). [SPRD-8, SPRD-56]

### Spread Periods
- Creatable periods: year, month, day, multiday. [SPRD-8]
- Task/Note assignable periods: year, month, day only. [SPRD-13]
- Multiday spreads aggregate entries by date range; no direct entry assignment to multiday. [SPRD-18]
- Period hierarchy: year → month → day (for migration and assignment). [SPRD-8]

### Task
- Inherits Entry protocol. [SPRD-9]
- Has status: open, complete, migrated, cancelled. [SPRD-10]
- `migrated` is system-derived historical assignment state and is not user-editable in the task edit sheet. [SPRD-141]
- Can be assigned to year, month, or day spreads. [SPRD-13]
- Has a desired assignment defined by its preferred `date` and preferred `period`; this is the finest spread granularity the task should ultimately live on in conventional mode. [SPRD-24, SPRD-110]
- Tracks migration history via TaskAssignment array. [SPRD-10]
- Eligible for batch migration suggestions. [SPRD-15]
- Symbol: solid circle (●). [SPRD-21]
- Status visual treatment: [SPRD-22, SPRD-64]
  - Open: solid circle, no overlay, normal styling.
  - Complete: solid circle with X overlay, greyed out row.
  - Migrated: solid circle with arrow (→) overlay, greyed out row.
  - Cancelled: solid circle, no overlay, strikethrough entire row.

### Note
- Inherits Entry protocol. [SPRD-9]
- Has status: active, migrated. [SPRD-9]
- Behaves like tasks for spread assignment (date, period, assignments). [SPRD-9, SPRD-34]
- Can migrate only when user explicitly requests (never suggested in batch migration). [SPRD-15, SPRD-34]
- May have longer content field for extended notes. [SPRD-9]
- Symbol: dash (—). [SPRD-21]
- Status visual treatment: [SPRD-22, SPRD-64]
  - Active: dash, no overlay, normal styling.
  - Migrated: dash with arrow (→) overlay, greyed out row.

### Migration
- Moving a task/note from a parent spread to a child spread. [SPRD-15]
- Source assignment status becomes migrated; destination assignment becomes open/active. [SPRD-15]
- Manual only - user must trigger migration. [SPRD-15]
- Notes migrate only via explicit action (not in batch suggestions). [SPRD-15, SPRD-34]
- Migration prompt logic in v1 applies to tasks only and only in conventional mode. [SPRD-110, SPRD-140]
- A task is eligible to migrate into a spread only when all of the following are true: [SPRD-110]
  - The task has a current open assignment on a coarser source (`Inbox`, year, or month/day parent) aligned to the destination's date hierarchy.
  - The destination spread is more granular than the current open assignment.
  - The destination spread is not more granular than the task's desired assignment period.
  - The destination spread is the most granular valid existing destination currently available for that task.
  - The task is open; completed, migrated-history-only, and cancelled tasks are not migration-eligible.
- Migration prompt source rules: [SPRD-110]
  - A year spread may pull from `Inbox` only.
  - A month spread may pull from `Inbox` and year spreads.
  - A day spread may pull from `Inbox`, month spreads, and year spreads.
  - Multiday spreads never show migration prompts and never receive direct assignment migrations.
- Source-spread migration affordance: [SPRD-140]
  - In conventional mode, an active task row shows a trailing right-arrow button only when that task has a smaller valid existing destination spread.
  - Tapping the arrow presents a confirmation alert that explicitly names the destination spread the task will be moved to.
  - Confirming the alert migrates that single task to its smallest valid existing destination spread.
- Destination-spread migration affordance: [SPRD-140]
  - In conventional mode, a destination spread may show a bottom section titled `Migrate tasks` when at least one task from the immediate parent hierarchy can migrate into that specific spread.
  - The section is collapsible.
  - The section header includes a trailing `Migrate All` action scoped to that destination spread.
  - The section lists one row per migratable task; tapping a row migrates that task into the current destination spread without additional confirmation.
  - The old migration banner and migration review sheet are removed from this flow.
- Post-migration source behavior: [SPRD-140]
  - A migrated task leaves the source spread's active task list.
  - The source assignment remains in history with migrated status.
  - The source spread shows migrated tasks in a disabled `Migrated tasks` subsection.
  - This migrated subsection behavior applies on all spread types that can host tasks.
- Migration prompting examples: [SPRD-110]
  - Example A: `2026` and `January 2026` exist. A task desired for `January 1, 2026` day is currently open on `January 2026`. When `January 1, 2026` day is created, that day spread prompts migration.
  - Example B: `2026` exists. A task desired for `January 2026` month is open on `2026`. When `January 2026` is created, the month spread prompts migration. If `January 10, 2026` is later created, that day spread does not prompt for this task because day is more granular than the task's desired assignment.
  - Example C: A task desired for `January 10, 2026` day is in `Inbox`. If `2026`, `January 2026`, and `January 10, 2026` all exist, only `January 10, 2026` prompts it because that is the most granular valid existing destination.
  - Example D: A task desired for `January 10, 2026` day is open on `2026`. If `January 2026` exists and `January 10, 2026` does not, the month spread prompts it. Once the day spread exists, the month prompt disappears and only the day spread prompts it.
- Migration scenario table (absolute-date reference cases): [SPRD-113]

| Scenario date context | Task desired assignment | Current source | Existing valid spreads | Prompted destination | Why |
| --- | --- | --- | --- | --- | --- |
| `January 12, 2026` | `January 2026` month | `2026` year | `2026`, `January 2026` | `January 2026` | Month is the most granular valid existing destination and does not exceed the desired month period. |
| `January 12, 2026` | `January 2026` month | `2026` year | `2026`, `January 2026`, `January 10, 2026` | `January 2026` | `January 10, 2026` is more granular than the task's desired month assignment, so it is never eligible. |
| `January 12, 2026` | `January 10, 2026` day | `2026` year | `2026`, `January 2026` | `January 2026` | The exact day spread does not exist yet, so the month spread is the most granular valid existing destination. |
| `January 12, 2026` | `January 10, 2026` day | `2026` year | `2026`, `January 2026`, `January 10, 2026` | `January 10, 2026` | Once the day spread exists, the coarser month prompt disappears and only the day prompt remains. |
| `January 12, 2026` | `January 10, 2026` day | `Inbox` | `2026`, `January 2026`, `January 10, 2026` | `January 10, 2026` | Inbox follows the same most-granular-valid-existing-destination rule as spread-assigned tasks. |

### BuJo Mode
- Conventional: show migration history across spreads, tasks appear on multiple spreads. [SPRD-29]
- Traditional: show entries only on their preferred assignment, no migration history visible. [SPRD-17, SPRD-35]

---

## Functional Requirements

### Spreads
- Create a spread for a given period/date with period-based date normalization. [SPRD-7, SPRD-8, SPRD-12]
- Creation rules: allow present or future dates only (no past). [SPRD-12, SPRD-50]
- Multiday creation can start in the past if it is within the current week. [SPRD-12, SPRD-50]
- Multiday presets follow user's first day of week setting; allow override in creation UI. [SPRD-8, SPRD-26, SPRD-49]
- Multiday spreads are creatable (range can be custom start/end or presets like "this week"/"next week"). [SPRD-8, SPRD-26]
- Multiday spreads aggregate entries by date range; entries are not assigned directly to multiday. [SPRD-18, SPRD-13]

### Spread Deletion
- Deleting a year/month/day spread reassigns all entries (open, completed, migrated) to the parent spread. [SPRD-15]
- If no parent spread exists, entries go to Inbox. [SPRD-14, SPRD-15]
- Entries are NEVER deleted when a spread is deleted; history is preserved. [SPRD-15]
- Deletion is blocked if it would orphan entries with no valid destination. [SPRD-15]
- Multiday spread deletion is a simple delete with no reassignment needed (multiday spreads aggregate entries by date range and have no direct assignments). [SPRD-18]

### Entries (Tasks/Notes)
- Create entries with title, preferred date, preferred period, and type. [SPRD-9, SPRD-23]
- Tasks support status (open/complete/migrated/cancelled). [SPRD-9, SPRD-24]
- Notes support status (active/migrated). [SPRD-9]
- Tasks and notes can be assigned to year, month, or day spreads. [SPRD-13]
- Notes are not suggested for batch migration but can be migrated explicitly. [SPRD-15, SPRD-34]
- Creating entries for past dates is not allowed in v1. [SPRD-23, SPRD-56]
- Task creation UI (v1): [SPRD-23, SPRD-71]
  - Task creation uses a sheet with title + period (year/month/day) + period-appropriate date controls.
  - Defaults to the selected spread's period/date; if none selected, uses initial selection logic. [SPRD-25]
  - Date validation uses period-normalized comparison (current month/year allowed). [SPRD-23]
  - Inline validation with Create button shown after first edit; whitespace-only titles are invalid. [SPRD-23]
  - Optional picker to choose from existing spreads or select a custom date; choosing a date without a matching spread is allowed (Inbox fallback). [SPRD-71, SPRD-14]
  - Spread picker lists created spreads chronologically with period filter toggles; multiday items expand to show contained dates (day selections appear on multiday). [SPRD-71]
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
- Events are deferred to v2 and not available in v1. [SPRD-69]

### Entry Date/Period Changes (Reassignment)
- Changing preferred date or period triggers reassignment logic in conventional mode. [SPRD-24]
- Period is independently editable (e.g., changing from month to day without changing the date month). [SPRD-24]
- Task creation and task editing must use the same period/date normalization and adjustment rules so the saved preferred assignment is consistent regardless of entry point. A period change in the editor must not silently preserve a stale date from the previous period when that would change reassignment outcome. [SPRD-141]
- In the edit sheet, reassignment is the user-facing way to migrate a task; changing preferred date and/or period updates the preferred assignment, and the previous assignment becomes migrated history if reassignment occurs. [SPRD-141]
- Old assignments (on old date/period's spreads) are marked as migrated to preserve history. [SPRD-24]
- New assignment is created on the best matching spread for the new date/period: [SPRD-24, SPRD-13]
  - Search from finest to coarsest: day → month → year.
  - If a matching spread exists, create/update assignment with open/active status.
  - If no matching spread exists, entry goes to Inbox.
- If destination spread already has an assignment, update its status (don't duplicate). [SPRD-52]
- Traditional mode date/period changes also trigger conventional reassignment logic. [SPRD-17, SPRD-24]
- Reassignment example for seeded conventional data: if a task created on the `2026` year spread is edited to preferred assignment `April 6, 2026` day while no `April 2026` month spread and no `April 6, 2026` day spread exist, the task remains open on the `2026` year spread and is shown in the April section with a `6` context label. After an explicit `April 2026` month spread is created, that month spread becomes the migration destination surfaced by inline migration affordances; the edit itself must not jump the task to an unrelated existing day spread such as `January 1, 2026`. [SPRD-141]

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
- Pressing `Today` navigates to the smallest-granularity spread containing the current absolute today date and synchronizes all spread navigation surfaces, including the selected spread, horizontal title strip, and horizontal content pager. [SPRD-130]
- Conventional mode `Today` target resolution: [SPRD-130]
  - Prefer an explicit day spread for today when it exists.
  - Otherwise prefer the narrowest explicit multiday spread whose range contains today.
  - Otherwise fall back to an explicit month spread for today's month.
  - Otherwise fall back to an explicit year spread for today's year.
  - If multiple multiday spreads contain today, choose the narrowest containing range; break ties by the existing chronological spread ordering.
  - If no explicit spread contains today, the button currently does nothing.
- Traditional mode `Today` always navigates to the traditional day destination for today. [SPRD-130]
- If `Today` is pressed while today is already the selected spread, it still recenters the title strip and content pager on today's selection if needed. [SPRD-130]

### Navigation and UI
- Spread navigation uses an in-view hierarchical tab bar on both iPad and iPhone; it handles navigation between spreads only. [SPRD-19, SPRD-25]
- The app includes a top-level search-role tab that presents a global task browser. [SPRD-148]
- The search tab is tasks-only in v1; notes and other result types are deferred. [SPRD-148]
- The search screen includes a real search field from day one. [SPRD-148]
- Entering the search tab should require only one press before the user can type: selecting the `Search` tab presents the search field ready for text entry. [SPRD-148]
- The search field should remain visibly present at the top of the search screen rather than requiring a second toolbar/search affordance press to reveal it. [SPRD-148]
- Search results are grouped into hidden-when-empty sections:
  - `Inbox` first.
  - Remaining sections follow the same ordering model as `SpreadTitleNavigatorView` for the active mode (`conventional` vs `traditional`). [SPRD-148]
- Each task appears exactly once in search, under the spread where it is currently shown. Migrated historical entries are excluded. [SPRD-148]
- Tapping a search result navigates to the task's current spread and then opens the task edit sheet there. [SPRD-148]
- Horizontal spread-title navigator behavior: [SPRD-126, SPRD-127]
  - Periods shown remain year → month → (day, multiday); no week period. [SPRD-8, SPRD-126]
  - The navigator replaces the old top spread selection bar and becomes the primary in-view spread-selection control on both iPhone and iPad. [SPRD-126]
  - The navigator is a horizontal scroll view of spread titles ordered according to the app's actual navigable spread sequence for the selected year in the current mode. [SPRD-126, SPRD-127]
  - As long as selection stays within the same year, the strip contents do not rescope based on whether the selected spread is a year, month, day, or multiday spread. [SPRD-127]
  - Conventional mode shows all explicit spreads that exist in the selected year, in chronological order, including explicit year, month, day, and multiday spreads. [SPRD-127]
  - When a conventional-mode day spread and multiday spread share the same start date, the multiday item appears before the day item in the strip ordering. [SPRD-127]
  - Traditional mode shows the full selected calendar year inline as a single chronological sequence: the year item, each month item, and every day in that year; traditional mode does not include multiday items in the strip. [SPRD-127]
  - When selection moves to a spread in a different year, the strip rebuilds to that new year's sequence. [SPRD-127]
  - The currently selected spread is centered in the strip on launch. Strip-originated spread selections animate the strip to the selected spread; intentional non-strip jump actions such as `Today` and rooted spread-surface selection also recenter the strip. Pager-driven selection changes do not automatically recenter the strip; they preserve the current strip browse offset while updating selection state. [SPRD-126, SPRD-127, SPRD-136]
  - The selected spread is rendered with a small indicator dot beneath the selected title. [SPRD-126, SPRD-127, SPRD-136]
  - Non-selected visible spreads are rendered as plain text titles with hierarchy-aware styling. [SPRD-126]
  - Inline month items in the strip should have subtle spacing/separator treatment so month boundaries remain readable within the year-wide sequence. [SPRD-127]
  - The strip passively emphasizes the item representing today's navigable destination even when it is not selected, using a shared configurable today-emphasis color token and a slight weight increase. [SPRD-144]
  - Today emphasis in the strip uses the same resolution semantics as the `Today` button: in conventional mode it highlights the destination that `Today` would navigate to, and in traditional mode it highlights today's traditional day destination. [SPRD-144]
  - Strip styling distinguishes four states: non-today selected, non-today unselected, today selected, and today unselected. [SPRD-144]
  - The navigator preserves a centered selected slot even near list edges or when fewer than five spreads exist by using invisible spacer slots rather than collapsing the layout around the selected item. [SPRD-126]
  - The number of neighboring visible titles is adaptive to available width; it is not hardcoded per device class. Partially visible edge titles are allowed to signal additional offscreen spreads. [SPRD-126]
  - Horizontal drag is browse-only in this task: the user may scroll and snap the strip without changing the currently selected spread or the main spread content. [SPRD-127]
  - Selection does not update continuously during drag or on drag settle. [SPRD-127]
  - Tapping a visible non-selected spread selects it, updates the main app spread content, and animates that spread into the centered selected position. [SPRD-126, SPRD-127]
  - The selected spread always retains its selected-state indicator styling while browsing; browsing the strip does not hide selected-state styling. [SPRD-127]
  - The horizontal title strip itself does not provide rooted spread-surface selection controls. The rooted spread navigator is launched from the spread header title control instead. [SPRD-136]
  - The strip uses browse-only snapping while preserving the user's browse offset across layout-width changes when the strip is already browsed away from the selected spread. If the strip is currently centered on the selected spread, width changes keep it centered. This preserves browsing position, but may leave the selected spread visually off-center after some width changes and should be monitored as a potential UX bug. [SPRD-136]
  - The spread header no longer renders a duplicate spread title once this navigator is present. [SPRD-126]
  - A trailing "+" button remains always visible and opens a creation menu (spread or task). [SPRD-23, SPRD-26, SPRD-126]
  - Navigator label refinements: [SPRD-129]
    - The spread content surface removes the duplicate `Spreads` title, while higher-level container navigation titles may remain when needed. [SPRD-129]
    - Year items use a stacked treatment with the leading century digits rendered smaller above the larger trailing two digits, while accessibility continues to expose the plain spoken year value such as `2026`. [SPRD-129]
    - Month items remain single-line labels but use a more expressive typographic treatment than plain body text. [SPRD-129]
    - Day items render as a three-line label with a smallcaps month abbreviation above the day number and a short weekday label beneath it. [SPRD-129]
    - Multiday items render as a three-line label:
      - same-month ranges show a smallcaps month abbreviation above a compact day range and a short weekday span beneath it
      - cross-month ranges show a smallcaps month span above the compact endpoint day range and a short weekday span beneath it [SPRD-129]
  - The strip height is content-driven with a minimum visual floor; it must not be hardcoded. The strip expands to fit its tallest item label (including multi-line day and multiday items) plus adequate vertical padding so the selected indicator and labels are never clipped or overlapped by sibling views. [SPRD-136]
  - Scrolling the title strip is isolated from the content pager. Strip scroll events must not propagate to the pager or change the selected spread unless the user explicitly taps a strip item. [SPRD-136]
  - Recommended spread inset behavior: [SPRD-137]
    - In conventional mode only, the title navigator shows a separate fixed trailing inset area for recommended spreads to create.
    - Recommendations are based on `today`, not on the currently selected spread.
    - The recommendation engine is defined by an injected protocol so recommendation derivation can be unit tested independently of the view.
    - The protocol returns semantic recommendations only; the navigator view continues to derive label presentation using the existing spread-title formatting system.
    - Recommendations cover missing explicit `year`, `month`, and `day` spreads for today's current year, month, and day.
    - A multiday spread containing today does not satisfy the `day` recommendation; only an explicit day spread does.
    - When multiple recommendations are present, they are shown in `year`, `month`, `day` order.
    - The recommendation inset is not part of the scrollable strip content; it stays fixed on the trailing side while the existing spread strip continues to scroll independently.
    - If no recommendations are available, the trailing inset disappears entirely and does not reserve empty space.
    - Recommended spreads use the same compact label language as ordinary strip items and are visually distinguished with the shimmering recommendation treatment.
    - Recommendation cards remove the ordinary inner horizontal padding and use a shared fixed `3:5` aspect ratio.
    - All visible recommendation cards share the same size.
    - On iPad, all recommendations continue to appear directly in the trailing inset; they do not collapse into a menu.
    - On iPhone, a single recommendation still appears as a direct tappable recommendation card.
    - On iPhone, when more than one recommendation exists, the trailing inset collapses to a single shimmering down-chevron card instead of showing multiple direct cards.
    - The iPhone multi-recommendation chevron card uses the same shared size as the direct recommendation cards.
    - Tapping the iPhone chevron card opens a `Menu` whose items use full spread date/title labels.
    - Tapping a recommendation opens the existing create-spread flow prefilled for that recommendation rather than creating the spread immediately.
    - A recommendation remains visible while the create-spread flow is open and disappears only after successful spread creation.
  - Rooted spread header navigator behavior: [SPRD-125, SPRD-139]
    - The spread header title control opens a rooted spread navigator: as a popover on iPad and as a large sheet on iPhone.
    - The spread header shows the period type in the existing small-caps style above the main title.
    - Year spread headers use the year as the main title and reserve subtitle space without rendering subtitle text.
    - Month spread headers use the month name as the main title and the year as the subtitle.
    - Day spread headers keep the long-form date as the main title and show the weekday as the subtitle.
    - Multiday spread headers use `DD MMM - DD MMM` as the main title regardless of whether the start and end dates share a month, and show the weekday range as the subtitle.
    - When the rooted navigator chevron is present, the title block remains visually centered independent of the chevron's width, and the chevron sits on the trailing edge of the centered title block rather than the far edge of the header.
    - The rooted navigator is a horizontal paging scroll view of year pages ordered chronologically from left to right.
    - Each page is a separate injected year view configured with the spreads for one specific year.
    - The initially visible page is the year of the currently selected spread.
    - The navigation title displays the current year page and updates only after horizontal paging settles.
    - Each year page renders its months in calendar order.
    - Each year page preserves at most one expanded month at a time, and that expanded month state is preserved while the rooted navigator remains open.
    - Tapping a month row toggles that month's expanded state; tapping an already expanded month row collapses it.
    - In conventional mode, a year page shows only months that have an explicit month spread or at least one day or multiday sub-spread in that month.
    - In traditional mode, a year page shows all months.
    - Expanding a month shows that month's calendar grid.
    - Calendar days with no selectable target are disabled and not tappable.
    - A day with exactly one target selects that spread immediately and dismisses the rooted navigator.
    - A day with multiple targets presents a native confirmation dialog so the user can choose among the day spread and any covering multiday spread targets.
    - In conventional mode, multiday spreads count as sub-spreads for determining whether a month is shown.
    - If an expanded month has an explicit month spread, that row also shows a `View Month` button.
    - `View Month` is the only control that selects the month spread from an expanded month row.
- Horizontal spread-content paging behavior: [SPRD-128]
  - Spread content pages are presented in a separate horizontal pager beneath the title strip; the title strip remains the navigation chrome and stays synchronized with the selected page. [SPRD-128]
  - The pager uses the same ordered selected-year sequence as the title strip for the current mode. [SPRD-128]
  - The pager includes the full current sequence inline, including year, month, day, and multiday spreads in conventional mode and year, month, and day destinations in traditional mode. [SPRD-128]
  - Horizontal page swiping changes the selected spread only after the paging gesture settles on a new page. [SPRD-128]
  - The pager rests on a single full-width selected page; adjacent pages do not remain peeked into view at rest. [SPRD-128]
  - When selection changes from the title strip or rooted navigator surface within the same selected-year sequence, the pager animates to the selected page. [SPRD-128]
  - When selection changes to a spread in a different year, the pager rebuilds to the new selected-year sequence and jumps to the selected page without cross-year scrolling animation. [SPRD-128]
  - When the pager settles on a new page, the horizontal spread-title navigator updates selection state to that page but preserves its current browse offset instead of automatically recentering. [SPRD-128, SPRD-136]
  - The pager preserves the full existing spread view for each page rather than rendering preview-only variants. [SPRD-128]
  - The implementation must avoid instantiating the full selected-year content view set at once. Use native lazy containers where feasible and keep only a small live window of pages around the selected spread, with a small nearby cache. [SPRD-128]
  - For this task, the live page window keeps the current page plus two neighboring pages on each side available, and pages outside that window may be torn down and rebuilt, losing transient local view state. [SPRD-128]
  - The pager supports swipe navigation and external programmatic selection only; it does not add separate previous/next arrow buttons. [SPRD-128]
- Traditional mode uses calendar-style navigation (year → month → day). [SPRD-35, SPRD-38]
- Traditional navigation mirrors iOS Calendar-style drill-in. [SPRD-35, SPRD-38]
- Spread navigator surface: [SPRD-125, SPRD-126]
  - The navigator surface is opened from the selected spread capsule in the horizontal spread-title navigator on both iPad and iPhone.
  - On iPad, tapping the selected capsule opens a popover navigator rooted on that capsule.
  - On iPhone, tapping the selected capsule opens a large sheet presenting the same rooted navigator content.
  - The selected capsule uses a subtle chevron/disclosure indicator to communicate interactivity.
  - The iPad popover uses a bounded designed size rather than fully content-driven sizing; exact dimensions are implementation-defined.
  - The navigator always presents a single rooted hierarchy view rather than drill-in navigation. Expanding and collapsing sections is sufficient to traverse the hierarchy in this task.
  - Root content:
    - conventional mode: root year list including explicit year spreads plus derived years that have navigable child spreads beneath them
    - traditional mode: root year list spanning from the earliest year with any entry data or explicitly created conventional spread through the current year plus ten years
  - The hierarchy always uses the same structure:
    - year sections rendered as table-style rows
    - month sections rendered as table-style rows nested under expanded years
    - day tiles rendered in a grid nested under expanded months
    - explicit multiday tiles rendered in the same month grid in conventional mode only
  - The presented navigator opens with the relevant current context already revealed inside that rooted hierarchy:
    - from a year spread, expand the current year
    - from a month spread, expand the current year and current month
    - from a day spread, expand the current year and current month and visibly select the current day tile
    - from a multiday spread, expand the current year and current month and visibly select the current multiday tile
  - Accordion behavior applies at each hierarchy level:
    - only one year section is expanded at a time
    - within the expanded year, only one month section is expanded at a time
  - Month rows are shown only inside expanded years.
  - Year and month rows use split interaction:
    - tapping the row body navigates immediately when the row represents a valid destination
    - a trailing disclosure control expands or collapses that section
    - derived conventional year/month rows that do not exist as explicit spreads are disclosure-only and do not attempt direct app navigation
  - Month detail renders a single mixed grid ordered strictly by spread start date.
  - In conventional mode, day and multiday tiles share the same grid, and multiday tiles use a subtle alternate tint or border plus a date-range label to distinguish them.
  - In traditional mode, month grids show every calendar day in the month and do not include multiday tiles in v1.
  - Selecting a spread row/tile immediately navigates the main app to that spread, dismisses the current navigator surface, and recenters the horizontal spread-title navigator on the new current spread.
  - The current spread is indicated with a light shape background; no checkmark badge is used.
  - Conventional-mode availability rules:
    - derived years and derived months use subtle styling to indicate they are not explicitly created at that level
    - month grids show only explicit created day and multiday spreads
  - Traditional-mode availability rules:
    - year/month/day navigation follows the full calendar structure implied by traditional mode rather than created-spread existence
    - the root year list starts at the earliest year that has either entry data or an explicitly created conventional spread
    - month grids show every calendar day in the month and do not show multiday tiles in v1
- Spread content view shows active entries and migrated entries section (conventional). [SPRD-27, SPRD-29]
  - Year and month spreads use spread-specific task sectioning rather than generic source-based sectioning. [SPRD-138]
  - On a year spread:
    - tasks assigned directly to that year appear in an untitled top section because they belong to the current spread
    - tasks assigned to months appear under titled month sections
    - tasks assigned to days also appear inside their containing month sections and show the day number next to the task
  - On a month spread:
    - tasks assigned directly to that month appear in an untitled top section because they belong to the current spread
    - tasks assigned to days in that month appear in the same list and show the day number next to the task
  - Day and multiday spreads do not use this year/month sectioning rule; they continue to show their normal flat task presentation for the current spread. [SPRD-138]
  - Multiday day cards support normal created, uncreated, and today visual states. [SPRD-149]
  - If a multiday card's date is today, it shows a `Today` label above the weekday, left-aligned with the weekday and matching the structural style role of the short month label above the date. [SPRD-149]
  - If a multiday card's corresponding explicit day spread does not exist, the card uses an uncreated treatment via a dashed outline rather than a distinct grey text or fill color treatment. [SPRD-149]
  - If a multiday card is both today and uncreated, the today treatment fully wins and suppresses the uncreated styling. [SPRD-149]
  - Every multiday day card includes an always-visible footer with a single trailing filled circular icon button. [SPRD-149]
  - If that day's explicit day spread exists, the footer button navigates using the normal spread-selection path to that day spread. [SPRD-149]
  - If that day's explicit day spread does not exist, the footer button opens the create-spread sheet preconfigured for that exact day spread. [SPRD-149]
  - Both footer button states share the same filled circular treatment with a white-tinted background and blue iconography, with the create-day state using `calendar.badge.plus` and the open-day state using a navigation icon. [SPRD-149]
  - After creating a day spread from that multiday footer flow, the app immediately navigates into the newly created day spread. [SPRD-149]
  - Multiday day cards can show an overdue count badge at the top-right, using the same count-badge language as the spread title navigator. [SPRD-149]
- Conventional-mode inline migration UI: [SPRD-140]
  - Year, month, and day spreads may show the bottom `Migrate tasks` section when at least one task is eligible to move into that spread.
  - Multiday spreads never show migration UI.
  - Traditional mode never shows migration UI because all calendar spreads are navigable without created conventional spread records.
- Source spreads expose per-task trailing-arrow migration actions with destination-naming confirmation alerts.
- Destination spreads expose per-task tap-to-migrate rows plus a header-level `Migrate All` action scoped to that destination spread.
- The inline migration UI lists only tasks, never notes.
- A task may be both overdue on its current spread and eligible for conventional inline migration into a finer spread at the same time.
- On a source spread, tapping a task in the disabled `Migrated tasks` subsection first navigates to that task's most granular current open destination spread and then immediately opens the task edit sheet there. If no valid destination spread can be resolved, it falls back to opening the edit sheet on the current spread. [SPRD-146]
- Spread overdue badges: [SPRD-147]
  - Overdue spread signaling moves from a global toolbar button/sheet into per-spread badges in the spread title navigator.
  - Each spread item can show a top-right overdue count badge.
  - Badge counts include only currently open overdue tasks assigned to that spread.
  - Overdue tasks still in `Inbox` are excluded from this navigator badge UI.
  - Badge counts are exact and uncapped.
  - Selecting a spread does not suppress its overdue badge.
  - Tapping a badged spread behaves the same as tapping any other spread; there is no separate overdue review action in v1.
- Collections are accessed from a top-level entry point (outside spread navigation). [SPRD-19, SPRD-40]
- Settings accessible via gear icon in navigation header. [SPRD-20]
- iPad multitasking: UI adapts gracefully to Split View and Slide Over. [SPRD-19]

### Visual Design
- Minimal, clean, paper-like presentation optimized for readability.
- Spread content surfaces use a dot grid background; navigation chrome, settings, and sheets use a flat paper tone without dots. [SPRD-62]
- Light mode paper tone: warm off-white (approx #F7F3EA). [SPRD-62]
- Dark mode paper tone: warm dark variant (approx #1C1A18); navigation chrome uses system secondary background. [SPRD-62]
- Dot grid defaults: 1.5pt dots, 20pt spacing, muted blue color at ~20-25% opacity (same color in both modes); first dot inset equals spacing; configurable via Debug overrides. [SPRD-62, SPRD-63]
- Typography: sans-first; headings use a distinct sans family (e.g., Avenir Next), body uses system sans for legibility; heading font is swappable in Debug for testing. [SPRD-62, SPRD-63]
- Accent color: muted blue (e.g., #5B7A99) for interactive controls and highlights. [SPRD-62]
- Card/list styling stays light: hairline dividers or subtle borders, minimal shadows, and consistent spacing. [SPRD-62]

### Settings (v1)
- BuJo mode toggle: conventional vs traditional with descriptions. [SPRD-20]
  - Conventional: "Track tasks across spreads with migration history"
  - Traditional: "View tasks on their preferred date only"
- First day of week preference: System Default, Sunday, Monday. [SPRD-49]
  - System Default uses device locale. [SPRD-49]
  - Affects multiday preset calculations. [SPRD-49]
- Persist settings locally via UserDefaults/@AppStorage and sync via Supabase when signed in. [SPRD-20, SPRD-88]

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
- Traditional mode does not gain any separate overdue review affordance; overdue spread badges are only shown where the spread title navigator is present. [SPRD-147]

### Collections
- Collections are plain text pages (title + content). [SPRD-39]
- Content is plain text with no character limit (unbounded). [SPRD-39]
- Collections live outside spread navigation in a top-level entry point. [SPRD-19, SPRD-40]
- Support create, edit, delete operations. [SPRD-40, SPRD-41]
- Collections list is sorted by modified date, newest first. [SPRD-40]
- Collections sync via Supabase using the same outbox + pull mechanism as other entities. [SPRD-85]
- Collection model fields: id, title, content, createdDate, modifiedDate. [SPRD-39]
- Auto-save on changes (debounced); updates modifiedDate on save. [SPRD-41]

### Persistence
- Use SwiftData for local storage. [SPRD-4, SPRD-5]
- Schema includes Spread, Task, Note, Collection (Event model reserved for v2). [SPRD-4, SPRD-8, SPRD-9, SPRD-39]
- Supabase sync is the only cloud backend for v1 (CloudKit removed). [SPRD-80, SPRD-104]
- Offline-first, then sync; auto-sync on launch/foreground + manual refresh. [SPRD-85]
- Local changes enqueue outbox and attempt immediate push on explicit Save/Done actions (not on every keystroke). Manual sync remains available. [SPRD-85]
- Sync eligibility in product environments requires an authenticated user session. There is no backup entitlement gate in v1. [SPRD-104]
- In product environments, users without a valid session are blocked by the auth gate instead of entering a local-only app state. [SPRD-106]
- In debug `localhost`, sync is fully disabled and all persistence is local-only for that run. [SPRD-107]
- There is no persistent sync status icon or content-area banner. Sync status is surfaced via pull-to-refresh on the entry list and a persistent error banner when sync has failed. [SPRD-85, SPRD-134, SPRD-135]
- Pull-to-refresh sync behavior: [SPRD-135]
  - Pulling down on the entry list in both conventional and traditional modes triggers a manual sync on release past the standard system threshold.
  - While the user is actively pulling (before releasing), the pull indicator displays the current sync status:
    - `.idle` → "Not yet synced"
    - `.synced(Date)` → "Last synced [relative time]"
    - `.syncing` → standard system spinner; no additional sync triggered on release
    - `.offline` → "Offline"
    - `.localOnly` → "Local only"
    - `.error` → "Last sync failed"
  - Releasing before the threshold dismisses the indicator without triggering sync, allowing the user to read the last sync time without syncing.
  - Pulling while in `.offline` or `.localOnly` state shows the status but does not attempt sync.
- Sync error banner: [SPRD-135]
  - When `SyncStatus` is `.error`, a non-tappable single-line text banner appears below the spread title navigator strip.
  - Banner text: "Last sync failed · Pull down to retry"
  - The banner is dismissed automatically when sync succeeds.
  - The banner does not appear for `.offline` or `.localOnly` states; those states are communicated via the pull indicator only.
- Assignment durability is a product requirement, not a local cache best-effort. [SPRD-119, SPRD-120, SPRD-121, SPRD-122]
  - `task_assignments` and `note_assignments` are first-class synced records.
  - After successful sync, the server must be able to rebuild the exact same current placement and the exact same assignment history for the signed-in user.
  - This includes current spread or Inbox placement plus historical migrated/completed/cancelled task assignments and active/migrated note assignments.
  - This guarantee must hold after:
    - deleting the app, reinstalling, and signing back into the same account
    - signing out, then signing back into the same account
    - rebuilding a clean second device from synced server state
    - wiping the local store and pulling from server again
- Every user action that changes assignment state/history must enqueue and sync the corresponding assignment mutations. [SPRD-121]
  - creation with direct spread assignment
  - Inbox fallback creation
  - migration
  - preferred date/period edits that cause reassignment
  - spread deletion reassignment to parent or Inbox
  - status changes that affect assignment history semantics
  - entry deletion, including assignment tombstones
- Assignment deletion/removal must use soft-delete tombstones with revision updates; hard deletes are not a valid product sync path. [SPRD-121]
- For the same entry and the same `(period, date)` destination, status changes update the same logical assignment record instead of creating duplicate assignment-history rows. [SPRD-120]
- Assignment records require durable IDs so updates and tombstones can target the same logical assignment across devices and reinstalls. [SPRD-120]
- Assignment outbox invariants: [SPRD-121]
  - assignment mutations must be enqueued on every assignment-changing save path
  - parent task/note mutations must push before child assignment mutations when both are pending
  - assignment create/update/delete mutations remain in the outbox until the server acknowledges them
- Safe repair/backfill for already-broken assignment sync is required. [SPRD-122]
  - In sync-enabled signed-in environments, the app may automatically and silently repair a task or note when the local model has assignment history but the server has zero assignment rows for that entry.
  - Repair uploads the full local assignment history for that entry, not just the current open/active assignment.
  - Repair runs at most once per entry per account and is logged internally, but it is silent in product UX.
  - If the server already has any assignment rows for that entry, no automatic reconciliation occurs.

### Supabase Sync + Auth (v1)
- Supabase environments: separate dev and prod projects. Release builds are locked to prod. QA builds are locked to dev. Debug builds default to dev and may be launched in `localhost` for a single run via debug launch configuration or launch arguments. [SPRD-80, SPRD-105, SPRD-107]
- Runtime data-environment switching is not part of v1. There is no in-app environment switcher, no persisted environment selection, and no soft-restart flow for environment changes. [SPRD-105]
- `localhost` is Debug-only, non-persistent, and intended exclusively for engineering workflows such as UI development, debug overrides, and mock data loading. [SPRD-107]
- Auth in product environments is email/password only for v1. Sign in with Apple and Google are out of scope. [SPRD-104, SPRD-108]
- Product usage requires authentication. If no valid product-environment session exists on launch, the app presents an auth gate before journal content is accessible. [SPRD-106]
- In Debug `localhost`, auth is bypassed automatically with a mock user and the app opens directly into journal content. [SPRD-107]
- Sign-up and forgot-password flows remain in-app in product environments. [SPRD-106]
- Sign-out wipes the local store and returns the user to the auth gate. [SPRD-106]
- Sync: field-level last-write-wins (server-arrival time), per-field timestamps set by DB triggers, monotonic revision per table for incremental sync, soft-delete with 90-day cleanup, delete wins conflicts, and device_id recorded on writes. [SPRD-81, SPRD-83, SPRD-85, SPRD-89]
- Data integrity: unique constraints for spreads/assignments, foreign keys enforced, and RLS policies restrict rows to `auth.uid()`. [SPRD-81, SPRD-82]
- Sync status semantics:
  - Debug `localhost`: `localOnly`.
  - Authenticated dev/prod: normal sync states (idle/syncing/synced/offline/error). [SPRD-85, SPRD-107]
- Data environment resolution:
  - Debug supports `-DataEnvironment localhost` for that launch only.
  - Debug without an override defaults to `development`.
  - QA defaults to `development`.
  - Release defaults to `production`. [SPRD-105, SPRD-107]
- `localhost` selection is never persisted across launches.
- Launch-time wipe protection remains only for `localhost` isolation: if the resolved environment changes to or from `localhost`, the local store is wiped before app startup so mock/debug data cannot contaminate dev-backed local state. [SPRD-105, SPRD-107]
- Architecture expectations:
  - Core services expose protocols and accept injected policies (Sync/Auth/Network) to keep debug logic out of production files.
  - Debug overrides live under `Spread/Debug` and are compiled only in Debug/QA builds.
  - Minimize `#if DEBUG` inside core services; prefer debug-only extensions/policy files.

### Sync Conflict Scenarios
- **Duplicate spread creation**: Two devices create a spread with the same period + normalized date. The server's unique constraint (`user_id, period, date`) causes the second push to fail. The merge RPC detects the existing row and applies field-level LWW to update any differing fields; the client receives the canonical row and updates its local copy. No duplicate is created. [SPRD-81, SPRD-83]
- **Concurrent task migration**: Two devices migrate the same task to different spreads. Both pushes succeed because they create different assignment rows. The task ends up with assignments on both destination spreads. The source assignment is marked migrated by whichever push arrives first; the second push's LWW timestamp for the source assignment status is compared and the later write wins. [SPRD-83]
- **Concurrent field edits**: Two devices edit different fields of the same entity (e.g., one changes title, another changes status). Each field has its own `*_updated_at` timestamp; both edits are preserved because LWW is per-field, not per-row. [SPRD-83]
- **Delete wins**: If one device deletes an entity while another edits it, the delete (`deleted_at` timestamp) wins regardless of field-level timestamps. The entity is soft-deleted on all devices after the next pull. [SPRD-83]
- **Merge RPC response**: All merge RPCs return the canonical row after applying LWW, so the client can update its local copy to match the server's resolved state. [SPRD-83]

### Auth UI (v1)
- The auth button remains a trailing toolbar control in spread content views; the old Inbox toolbar group is removed because Inbox is now surfaced through the top-level search tab. [SPRD-84, SPRD-148]
- Auth button in toolbar, trailing the inbox group. [SPRD-84]
- Button appearance: [SPRD-84]
  - Logged out: person icon (`person.crop.circle`)
  - Logged in: filled person icon (`person.crop.circle.fill`)
- On launch in product environments with no valid session, a large auth sheet is presented as a blocking gate before journal content is accessible. [SPRD-106]
- Logged out state from the toolbar also opens the same auth sheet. [SPRD-106]
  - Sheet presentation uses `.large`-style sizing appropriate for iPhone and iPad.
  - Email and password fields
  - Sign In button (disabled until fields populated)
  - Inline error message display for failed login attempts
  - In-sheet navigation to Sign Up and Forgot Password
  - Sheet dismisses on successful login
- Logged in state: tapping button opens profile sheet. [SPRD-84]
  - Shows user email
  - Sign Out button in toolbar
  - Sign out requires confirmation alert (warns that local data will be wiped)
- Apple and Google sign-in are not part of v1. [SPRD-108]
- If a previously authenticated user launches offline and the app has not definitively determined that the session is invalid, cached local data remains accessible and sync resumes when connectivity returns. [SPRD-106]
- If the app later determines online that the session is invalid or expired, it returns to the auth gate. [SPRD-106]

### Development Tooling
- Debug UI is available only in Debug and QA TestFlight builds; Release builds have no debug destinations or data-loading actions. [SPRD-45]
- Replace the debug overlay with a dedicated Debug destination:
  - iPadOS (regular width): sidebar item titled "Debug" with SF Symbol `ant`. [SPRD-45]
  - iOS (compact width): tab bar item titled "Debug" with SF Symbol `ant`. [SPRD-45]
- Debug menu provides grouped sections with labels and descriptions:
  - Environment and dependency summary. [SPRD-2, SPRD-3, SPRD-45]
  - Sync/network/auth override controls for engineering verification. [SPRD-85A, SPRD-85C]
- Mock data sets are generated in code (no external fixtures) and cover varied spread scenarios and edge cases (empty, standard year/month/day, multiday ranges, boundary dates, large volume/perf). [SPRD-46]
- Mock data set loading uses JournalManager APIs to mirror app behavior; loading or clearing data refreshes UI and resets selection to today's spread when available. [SPRD-67]
- Mock data set loading is available only in Debug `localhost`. It is not available in Debug dev, QA, or Release. [SPRD-107]
- Debug menu provides appearance overrides for paper tone, dot grid (size/spacing/opacity), heading font, and accent color (DEBUG builds only). [SPRD-63]
- Debug tooling files live under `Spread/Debug` to keep debug-only views/data isolated. [SPRD-45]
- There is no in-app environment switcher in v1. Environment selection for `localhost` is done before launch in Debug only. [SPRD-105, SPRD-107]
- Debug functionality should be visible only inside the Debug destination (no always-on overlay/badge).
- Debug behavior should be isolated from production code via protocols + dependency injection:
  - Core services (Sync/Auth/Network) expose protocols and default policies in non-debug files.
  - Debug overrides live under `Spread/Debug` as separate policy implementations compiled only in Debug/QA builds.
  - Avoid sprinkling `#if DEBUG` inside core services; prefer debug-only extensions/policy files.
- Debug menu provides Sync & Network overrides (DEBUG builds only) to mock runtime states:
  - Block all network connections (force NWPathMonitor offline and fail requests).
  - Disable sync while keeping network available.
  - Force sign-in auth errors: invalid credentials, email not confirmed, user not found, rate limited, network timeout.
  - Force sync UI states: "syncing" pinned for 5s with engine paused; whole-sync failure error injection.
  - Seed outbox with real `SyncMutation` rows to simulate backlog.
  - Scenario presets that apply multiple overrides at once plus manual toggles/sliders.
  - Live sync readout (network status, last sync time, outbox count, current sync error).
  - Override persistence across relaunch is not required.

### Testing
- Automated testing is split between deterministic unit tests for isolated logic and localhost-backed UI scenario tests for user-visible flows. [SPRD-113, SPRD-114]
- Logic-heavy user scenarios must be exercised through Debug `localhost` launches with seeded mock data and a fixed `today` date so results remain deterministic. [SPRD-114]
- UI scenario tests are additive to existing unit coverage; they do not replace unit tests for JournalManager, assignment logic, migration revalidation, or overdue computation. [SPRD-114]
- Scenario UI tests focus on conventional-mode logic-heavy flows first: assignment fallback, Inbox resolution, migration prompting/review, overdue badge visibility, and edit-time reassignment. [SPRD-114]
- UI scenario fixtures may seed the starting state, but the user action under test must still be performed through the UI. [SPRD-114]
- A shared localhost scenario harness is required for UI tests. It must centralize:
  - app launch with `localhost`, scenario dataset selection, and fixed `today`
  - spread navigation
  - migration banner/review interactions
  - overdue badge interactions
  - common assertions for relocated tasks, source sections, and migrated-history visibility
- The UI scenario suite should stay organized by logic area instead of by fixture: assignment, reassignment, migration, and overdue each get their own test class backed by the shared harness.
- Scenario-only mock data sets may live in the same in-code catalog as debug mock data, but test-only cases must be hidden from normal debug-menu browsing. [SPRD-114]
- Scenario-test-critical UI must expose explicit accessibility identifiers instead of relying only on visible copy. This includes:
  - migration banner, review sheet, section headers, rows, selection controls, and confirm action
  - overdue badge counts, visibility, and selected-spread coexistence
  - any supporting source/destination labels needed to assert assignment and migration outcomes
- UI scenario assertions should prefer user-visible outcomes. Localhost-only debug inspection may be used only when the UI cannot distinguish a required state clearly enough. [SPRD-114]
- Focused unit tests still backstop exclusion-only and revalidation-heavy rules where UI coverage would otherwise become brittle, but user-visible scenario coverage remains the primary integration signal for assignment, migration, reassignment, and overdue.
- Scenario coverage matrix required for v1: [SPRD-114, SPRD-115, SPRD-116, SPRD-117, SPRD-118]

| Scenario area | Required localhost UI coverage | Key assertion |
| --- | --- | --- |
| Creation-time assignment | Creating a task on a created matching spread assigns it directly there. | The new task appears on the selected spread without using Inbox or migration UI. |
| Inbox fallback | Creating a task when no matching spread exists routes it to Inbox. | The task is absent from spread content, present in Inbox, and can be identified by desired assignment. |
| Inbox auto-resolution | A task seeded in Inbox becomes migration-eligible when a valid year/month/day spread is later created. | The destination spread exposes migration UI for that task and the task can be moved out of Inbox from the review sheet. |
| Desired-assignment-bounded migration | A month-desired task on `2026` prompts on `January 2026` but not `January 10, 2026`. | Only the valid month destination shows migration UI. |
| Most-granular-valid destination | A day-desired task on `2026` prompts on `January 2026` only until `January 10, 2026` exists, then only the day spread prompts. | The coarser prompt disappears once the finer valid destination exists. |
| Migration review flow | Conventional migration banner opens a sheet with eligible tasks preselected and sectioned by source. | Source and destination labels are visible, default selection is correct, and confirm migrates the selected tasks. |
| Migration post-submit behavior | After migration, the review sheet updates in place and only dismisses when no eligible tasks remain. | Remaining rows stay visible; fully resolved sheets dismiss automatically. |
| Edit-time reassignment | Editing a task's preferred date/period relocates it according to conventional reassignment rules. | The task appears on the new destination, disappears from the active list on the old spread, and appears in migrated history there. |
| Overdue day threshold | Day-assigned open tasks become overdue after the assigned day passes. | The assigned spread's navigator item shows the overdue count badge. |
| Overdue month/year thresholds | Month- and year-assigned tasks become overdue only after the full assigned period passes. | Navigator badge counts change only at the defined absolute-date boundaries. |
| Inbox overdue fallback | Inbox tasks become overdue from their desired assignment when no open spread assignment exists. | No spread badge is shown until the task has an open spread assignment; Inbox overdue items remain discoverable through the search tab's Inbox section. |
| Overdue badge flow | Overdue signaling is passive in the spread title navigator rather than a toolbar-sheet flow. | Count and visibility remain correct from any spread context without introducing a special review interaction. |
| Note exclusions | Notes never appear in migration or overdue navigator surfaces. | Migration review exclusion is covered in UI; overdue exclusion is backstopped by focused unit tests because notes should not contribute to spread badge counts. |
| Traditional-mode parity check | Traditional mode still has no migration UI. | Traditional mode continues to omit migration controls; overdue navigator badge behavior applies only where the spread title navigator is shown. |
| Spread task row visual treatment | Main spread task lists keep a solid list backing while task rows remain transparent. | The spread dot-grid background remains visible behind the task-list surface instead of each task row rendering as an opaque card. |
| Task inline title editing | Tapping the title of a task row in a main spread list activates an inline text field for editing the title in place. | The row expands to show an editable text field in place of the title. A "×" cancel button appears. Tapping outside, pressing Return, or losing focus commits the change. Tapping "×" discards it. |
| Task full-sheet access | The full task edit sheet (title, date, period, status) is accessible via the swipe-action Edit button. | The edit sheet opens and pre-populates with the current task values. |
| Inline task creation | An "+ Add Task" button appears at the bottom of every spread's task list. Tapping it opens an inline input row with immediate keyboard focus. | The input row appears, a glass-effect toolbar above the keyboard shows Save and Cancel. Return saves the title and opens a new blank row. Save closes the input. Cancel or empty-field focus loss discards. The task is assigned to the spread's period and date. |
| Multiday empty-day visibility | A multiday spread shows a section for every day in its covered range even when no tasks exist for that day. | Empty dates still render a day header and explicit empty-state message. |
| Multiday adaptive layout | A multiday spread uses two columns on regular-width layouts and one column on compact layouts. | The same ordered set of day sections is visible in reading order on both size classes. |
- Durability and rebuild matrix required for v1: [SPRD-119, SPRD-120, SPRD-121, SPRD-122, SPRD-123]

| Scenario area | Required sync-enabled coverage | Key assertion |
| --- | --- | --- |
| Direct assignment durability | Create a task/note on an existing spread, sync, wipe local state, rebuild from server. | The entry returns on the same spread with the same assignment status/history. |
| Inbox fallback durability | Create a task/note with no matching spread so it lands in Inbox, sync, wipe local state, rebuild from server. | The entry returns in Inbox with the same desired assignment and no phantom spread assignment. |
| Migration durability | Migrate a task/note, sync, wipe local state, rebuild from server. | The destination remains active and the source spread still shows migrated history after rebuild. |
| Reassignment durability | Edit preferred date/period to trigger reassignment, sync, wipe local state, rebuild from server. | The entry appears on the same destination, disappears from the old active list, and the old source history remains visible after rebuild. |
| Spread deletion durability | Delete a spread that causes reassignment to parent or Inbox, sync, wipe local state, rebuild from server. | Reassigned destinations and preserved histories match the pre-wipe state exactly. |
| Cross-device parity | Apply assignment-changing actions on one signed-in client, then rebuild a second clean client from server data. | The second client reproduces the same visible placement and source-history UI. |
| Assignment tombstone durability | Delete an entry or remove/supersede an assignment path, sync, wipe local state, rebuild from server. | Removed assignments do not reappear and surviving history remains intact. |
| Safe backfill recovery | Start from an entry with local assignment history and zero server assignment rows, run repair, then rebuild from server. | Full assignment history is backfilled once and survives subsequent rebuilds. |
| Note parity | Repeat durability/rebuild scenarios for notes where assignment behavior exists. | `note_assignments` round-trip with the same guarantees as `task_assignments`. |
- Sync-enabled durability coverage is distinct from pure `localhost` UI scenarios:
  - `localhost` remains the required environment for deterministic logic/UI-only scenario tests.
  - Assignment durability, repair, and rebuild scenarios must run in a sync-enabled integration or UI test layer because pure `localhost` cannot validate server persistence.
  - The preferred free-tier environment split is:
    - `localhost` for UI logic scenarios
    - local Supabase for destructive durability/rebuild/repair testing
    - remote `spread-dev` for shared hosted QA
    - remote `spread-prod` for production use
- Lower-level tests required alongside the user-facing rebuild scenarios: [SPRD-120, SPRD-121, SPRD-122]
  - durable assignment ID generation and persistence
  - assignment mutation enqueueing on every assignment-changing save path
  - assignment update vs create vs tombstone behavior
  - push ordering between parent entries and child assignments
  - exact pull/apply reconstruction of placement and history from server rows
- Device matrix:
  - iPhone is the default scenario-test device. [SPRD-114]
  - Add a targeted iPad subset only for scenarios where layout or navigation behavior differs materially from iPhone. [SPRD-114]
  - iPad UI test infrastructure (separate test plan configuration or device-specific test classes) does not yet exist. iPad-specific tests for features like the Today button [SPRD-130] are deferred until this infrastructure is established.

### Secrets and Configuration
- Supabase publishable (anon) keys and project URLs are stored in build-time xcconfig files. These are client-side keys protected by RLS policies; they are not service role keys.
- Configuration files:
  - `Configuration/Debug.xcconfig` — dev Supabase URL + key, `development` environment, `dev.johnnyo.Spread.debug` bundle ID.
  - `Configuration/QA.xcconfig` — dev Supabase URL + key (same as Debug), `development` environment, `dev.johnnyo.Spread.qa` bundle ID.
  - `Configuration/Release.xcconfig` — prod Supabase URL + key, `production` environment, `dev.johnnyo.Spread` bundle ID.
- `Info.plist` reads values via build variables: `$(SUPABASE_URL)`, `$(SUPABASE_PUBLISHABLE_KEY)`, `$(DATA_ENVIRONMENT)`.
- `SupabaseConfiguration.swift` resolves configuration with this priority:
  1. Debug-only launch selection of `-DataEnvironment localhost` for that run.
  2. Build configuration defaults (`development` for Debug/QA, `production` for Release).
  3. `DataEnvironment`-based hardcoded dev/prod fallbacks (in code).
  4. `Info.plist` build-time values (from xcconfig).
- `DataEnvironment.swift` contains hardcoded URLs and keys for dev/prod as fallback defaults.
- `.gitignore` blocks `.env` files but does not block `.xcconfig` files; publishable keys are committed to git (acceptable for client-side anon keys).
- Service role keys and other server-side secrets are never stored in the client codebase. They exist only in the Supabase dashboard and server-side infrastructure.

### First Launch and Onboarding
- On first authenticated product launch, a brief onboarding walkthrough is shown (2-3 screens explaining BuJo concepts: spreads, tasks, migration). [SPRD-106]
- Onboarding is shown only once per app install; completion is tracked locally.
- After onboarding dismissal, the user lands on the empty spread view with a clear call-to-action to create their first spread via the "+" button.
- Subsequent authenticated launches skip onboarding and go directly to the spread view.
- Onboarding content (v1):
  - Screen 1: Welcome — brief app description and BuJo philosophy.
  - Screen 2: Spreads — explain year/month/day/multiday pages and how to create them.
  - Screen 3: Tasks and Migration — explain rapid logging, task statuses, and manual migration.
- Onboarding occurs after authentication and does not teach account creation; sign-in remains part of the auth gate flow.

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
- An "+ Add Task" button appears at the bottom of the task list on every spread. It replaces the "No Entries" empty state — the button is always visible regardless of entry count. [SPRD-133]
- On multiday spreads, each day section has its own "+ Add Task" button at the bottom of that day's task list. [SPRD-133]
- The multiday `+ Add Task` row and active inline creation row align to the same icon/title columns as standard entry rows: the `+` shares the status-icon column and `Add Task` shares the title column. [SPRD-144]
- Tapping "+ Add Task" appends an inline text field row with immediate keyboard focus. [SPRD-133]
- While the inline creation row is active, a glass-effect toolbar (`.glassEffect`) appears above the keyboard with Save and Cancel buttons. [SPRD-133]
- Tapping Save commits the current title if non-empty and dismisses the input row. [SPRD-133]
- Tapping Cancel discards the input and dismisses the row. [SPRD-133]
- Pressing Return commits the current title if non-empty and immediately opens a new blank input row, allowing rapid sequential task creation without tapping the button again. [SPRD-133]
- When the input row loses focus, non-empty input is saved as a new task; an empty field is silently discarded and the row dismissed. [SPRD-133]
- Tasks created via inline creation are assigned to the spread's own period and date — identical to the defaults the full `TaskCreationSheet` applies when that spread is pre-selected. [SPRD-133]
- For all inline task creation commit paths (`Save`, `Return`, and focus-loss save), once the local add succeeds the transient inline creation row and keyboard dismiss immediately; they do not remain visible while follow-up sync completes. [SPRD-145]
- Inline task creation applies to tasks only in v1. [SPRD-133]
- For multiday spreads, every calendar day in the spread's covered date range renders a visible day section even when that day has no tasks. [SPRD-124]
- Empty multiday day sections show the day header plus an explicit empty-state message rather than collapsing away. [SPRD-124]
- Multiday day sections show tasks only in v1. Expanding those sections to include notes is deferred to a later version. [SPRD-124]
- On regular-width layouts such as iPad, multiday day sections render in two columns using normal reading-order flow. On compact layouts, they render in a single column. [SPRD-124]
- On multiday spreads, only the section for today's date receives passive today emphasis. Its header text, outline, and card background use the shared configurable today-emphasis color family; other day sections remain unchanged. [SPRD-144]

### Header Spread Navigator
- The selected spread capsule in the horizontal spread-title navigator presents the same rooted spread navigator on both platforms: as a popover on iPad and as a large sheet on iPhone. [SPRD-125, SPRD-126]
- The navigator always presents a single rooted hierarchy view with no push navigation in v1. Current context is revealed by expanded sections inside that rooted view rather than by drilling into another screen. [SPRD-125]
- Years and months are presented as collapsible table rows; month contents are presented as grid tiles within the expanded month section. [SPRD-125]
- Year and month rows use split interaction: row-body tap navigates when the row is a valid destination, while a trailing disclosure expands or collapses that section. Derived conventional rows use disclosure-only behavior. [SPRD-125]
- The hierarchy uses accordion behavior: only one year is expanded at a time, and only one month is expanded within that year. [SPRD-125]
- The month grid mixes day and multiday tiles chronologically in conventional mode, visually distinguishing multiday tiles with a subtle alternate treatment; traditional-mode month grids show all calendar days and no multiday tiles in v1. [SPRD-125]
- The current spread opens with its year/month context already expanded and is highlighted with a light shape background. [SPRD-125]
- Conventional mode derives root years and month rows when child spreads make them navigable, but day/multiday tiles remain explicit-created-spread only. [SPRD-125]
- Traditional mode uses the full calendar structure, with the root year list spanning from the first year with entry data or created spreads through current year plus ten years, and month grids showing all calendar days with no multiday tiles in v1. [SPRD-125]
- Keyboard/trackpad-specific navigation enhancements are deferred from the initial implementation. [SPRD-125]
- The rooted navigator surface should be implemented with a separable model/support layer so hierarchy derivation, expansion state, and current-context opening rules can be unit tested independently from the popover/sheet view. [SPRD-125]
- The horizontal spread-title navigator should also use a separable support/model layer so ordered spread sequencing, selection state, adaptive visible-slot behavior, browse-state rules, offscreen-selected detection, and recenter rules can be unit tested independently from the scrolling view. [SPRD-126, SPRD-127]
- Required coverage includes iPhone and iPad UI tests plus lower-level unit tests for navigator state/data derivation, centered-strip behavior, browse-only scrolling, and return-to-selected behavior. [SPRD-125, SPRD-126, SPRD-127]

### Error Handling UX
- **Sign-in errors**: Error messages are displayed inline on the login sheet below the password field. Error text is human-readable and maps from auth error types: [SPRD-84]
  - Invalid credentials: "Incorrect email or password."
  - Email not confirmed: "Please check your email to confirm your account."
  - User not found: "No account found with that email."
  - Rate limited: "Too many attempts. Please try again later."
  - Network timeout: "Unable to connect. Check your internet connection."
- **Sync errors**: Sync failures are non-blocking. Automatic retry occurs with exponential backoff (2s base, 300s max). A non-tappable error banner appears below the navigator strip with text "Last sync failed · Pull down to retry"; it clears on next successful sync. [SPRD-85, SPRD-134, SPRD-135]
- **Network errors**: When offline, the app continues to function normally with local data. When connectivity returns, sync resumes automatically. Offline state is surfaced in the pull-to-refresh indicator only ("Offline"); no persistent banner is shown. [SPRD-85, SPRD-134, SPRD-135]
- **App initialization errors**: If the SwiftData container fails to create on launch, the app shows a fatal error screen with a message to restart the app. No recovery is attempted. [SPRD-TBD]
- **Entry deletion**: Requires confirmation via a standard destructive alert ("Delete this task? This cannot be undone."). [SPRD-24]
- **Spread deletion**: Requires confirmation with a message explaining that entries will be reassigned, not deleted. [SPRD-15]

### Accessibility (v1)
- **VoiceOver**: All interactive elements (buttons, list rows, toggles, pickers) must have descriptive accessibility labels. Entry rows announce entry type, title, and status (e.g., "Task, Buy groceries, open"). [SPRD-TBD]
- **Dynamic Type**: Body text and entry list content support Dynamic Type at standard text sizes. Accessibility text sizes (xxxLarge and above) are not required for v1.
- **Color contrast**: All text and interactive elements meet minimum contrast ratios against their backgrounds (4.5:1 for normal text, 3:1 for large text).
- **Reduce Motion**: Not required for v1. Revisit post-v1 if animations are added.
- **Switch Control**: Not explicitly targeted for v1; standard SwiftUI controls provide baseline support.

---

## BuJo Method Features (v1)
- Future log (year spread). [SPRD-25, SPRD-27]
- Monthly log (month spread with entries). [SPRD-28]
- Daily log (day spread with entries). [SPRD-28]
- Rapid logging symbols (task/note). [SPRD-21, SPRD-22]
- Migration and scheduling (manual). [SPRD-15, SPRD-30]
- Collections (plain text pages). [SPRD-39, SPRD-40, SPRD-41]

## BuJo Method Features (Future/v2)
- Index. [SPRD-56]
- Habit/mood trackers. [SPRD-56]
- Review/reflection. [SPRD-56]
- Search, filters, tagging. [SPRD-56]
- Event logging with calendar integration (EventKit and/or Google). [SPRD-57]

---

## Events (v2 - Calendar Integration)
- Events are calendar-backed date-range entries that appear alongside tasks/notes on spreads. [SPRD-57]
- Supported sources (decide at v2 kickoff): EventKit (device calendars) and/or Google Calendar via OAuth. [SPRD-57]
- Event data is cached locally for offline display; cache mirrors external source and is treated as read-only unless write-back is explicitly in scope. [SPRD-59]
- Event visibility is computed from date-range overlap with spreads (no assignments). [SPRD-33]
- Timing modes: single-day, all-day, timed, multi-day; time zone handling is explicit and source-driven. [SPRD-60]
- UI considerations: show source calendar color/label, allow per-calendar visibility toggles, and handle permission/authorization states gracefully. [SPRD-60]

## Edge Cases (Resolved)
- Date normalization: Use Calendar API with user's firstWeekday setting. [SPRD-7, SPRD-49]
- Entries with no matching spread: Go to Inbox; auto-resolve on spread creation. [SPRD-13, SPRD-14]
- Migration when destination has assignment: Update existing assignment status. [SPRD-15, SPRD-52]
- Deleting year/month/day spread with entries: Reassign all entries to parent or Inbox; never delete entries. [SPRD-15]
- Deleting multiday spread: Simple delete with no reassignment (no direct assignments to multiday). [SPRD-18]
- Overlapping multiday spreads: Each multiday is independent; entries appear on all applicable. [SPRD-8, SPRD-49]
- Past-dated entries: Blocked in v1; validation prevents creation. [SPRD-23, SPRD-56]
- Entry date change: Old assignments marked migrated; new assignment on best spread or Inbox. [SPRD-24]
- Entry period change: Same reassignment logic as date change; period is independently editable. [SPRD-24]
- Duplicate spread on sync: Server unique constraint prevents duplicates; merge RPC applies field-level LWW and returns canonical row. [SPRD-81, SPRD-83]
- Concurrent migration: Both assignment rows are created; source assignment status resolved by LWW timestamp. [SPRD-83]

## Resolved Decisions
- Entry architecture uses protocol + separate @Model classes for scalability. [SPRD-9]
- Week period removed from Period enum; multiday covers week-like scenarios. [SPRD-8, SPRD-56]
- Notes migrate only via explicit user action, not batch suggestions. [SPRD-34]
- Inbox is surfaced through the global search-role tab; there is no spread-toolbar Inbox button or Inbox sheet in v1. [SPRD-148]
- Settings include mode toggle + first day of week preference. [SPRD-20, SPRD-49]
- Spread deletion never deletes entries; reassigns to parent or Inbox (multiday deletion has no reassignment). [SPRD-15, SPRD-18]
- Collections are plain text pages outside spread navigation; sorted by modified date; content is unbounded; collections sync via Supabase. [SPRD-19, SPRD-40, SPRD-85]
- Traditional mode in scope for v1. [SPRD-35, SPRD-38]
- Traditional mode date changes trigger conventional reassignment. [SPRD-17, SPRD-24]
- Multiplatform: iPadOS primary, iOS supported; adaptive layouts per size class. [SPRD-19]
- macOS deferred to post-v1. [SPRD-56]
- Visual style uses dot grid backgrounds on spread content surfaces only, muted blue accents, and Debug-only appearance overrides for paper tone and typography. [SPRD-62, SPRD-63]
- Main spread task lists keep transparent task rows over a solid list backing so the spread dot-grid remains visible. For open tasks, tapping anywhere on the row activates inline editing and focuses the title field. Completed or cancelled task rows still open the full edit sheet on tap. [SPRD-124, SPRD-132, SPRD-142]
- An "+ Add Task" button at the bottom of every spread's task list (and per-day in multiday) enables inline task creation with a glass-effect Save/Cancel keyboard toolbar and rapid Return-to-add flow. [SPRD-133]
- Multiday spreads always render every day in range, with explicit empty-state sections and adaptive one-column/two-column layout by size class. [SPRD-124]
- The selected-spread navigator surface uses a rooted collapsible year/month/grid browser on both platforms, presented as a popover on iPad and as a sheet on iPhone. [SPRD-125, SPRD-126]
- Entry period is independently editable; period changes trigger the same reassignment logic as date changes. [SPRD-24]
- The leading task control in main spread task rows is always the reusable task status toggle button used by the task edit sheet; it remains pressable whether or not the row is inline editing. [SPRD-141, SPRD-142]
- When an open task row becomes inline active, the title row must remain visually stable: the saved title remains visible in the passive state, the focused state adds only the text cursor/selection treatment, and the only new layout that appears is the secondary action row underneath. [SPRD-142]
- While an open task row is in inline edit mode, a secondary action row appears underneath with only two actions: a pencil-writing button that commits any inline title draft and opens the full edit sheet, and a right-arrow migration `Menu`. [SPRD-142]
- Inline row-edit migration options are immediate actions, not draft-only changes. They show only valid destinations for the current task and may include descriptive options such as `Today`, `Tomorrow`, a month-level next-month destination like `May 2026`, and a same-day next-month destination like `May 5, 2026`. [SPRD-142]
- Tapping outside the active inline-edit row dismisses the inline editor, releases focus, commits any pending title draft using the existing blur/Save semantics, and hides the secondary action row. Only one task row can be inline active at a time. [SPRD-142]
- Product usage requires authentication in dev/prod, while Debug `localhost` bypasses auth automatically for engineering workflows. [SPRD-106, SPRD-107]
- `localhost` is non-persistent, selected per Debug launch, and isolated from dev-backed local state by launch-time wipes when switching to or from it. [SPRD-105, SPRD-107]
- Brief onboarding walkthrough shown once on first authenticated product launch, tracked locally. [SPRD-106]
- Minimum accessibility baseline for v1: VoiceOver labels, standard Dynamic Type, contrast ratios. [SPRD-TBD]

## Open Questions
- For v2 events: EventKit only or EventKit + Google? [SPRD-57]
- For v2 events: read-only import vs write-back edits? [SPRD-57]
- For v2 events: local manual events in addition to integrations, or integrations only? [SPRD-57]

---

## Future Versions
- Spread bookmarking. [SPRD-56]
- Dynamic spread names. [SPRD-56]
