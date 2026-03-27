# Bulleted Specification (v1.0)

## Status
- Specification finalized for v1 implementation (tasks + notes only). [SPRD-1]
- Events (including calendar integrations) are deferred to v2. [SPRD-69]

## Project Summary
- Multiplatform app (iPadOS primary, iOS) built in SwiftUI with SwiftData local storage + Supabase sync. [SPRD-1, SPRD-5, SPRD-80]
- Adaptive UI: top-level navigation adapts by device (sidebar on iPad, tab/sheet on iPhone), while spread navigation uses an in-view hierarchical tab bar on both platforms; traditional mode uses calendar navigation. [SPRD-19, SPRD-25, SPRD-35, SPRD-38]
- Core entities (v1): [SPRD-8, SPRD-9, SPRD-10]
  - Spread: period (day, multiday, month, year) + normalized date. [SPRD-8]
  - Entry: protocol for task and note with type-specific behaviors. [SPRD-9]
  - Task: assignable entry with status and migration history. [SPRD-9, SPRD-10]
  - Note: assignable entry with explicit-only migration. [SPRD-9, SPRD-34]
  - TaskAssignment/NoteAssignment: period/date/status for migration tracking. [SPRD-10, SPRD-15]
- Events are a v2 integration (calendar-backed date-range entries), not part of v1 UI/flows. [SPRD-57]
- JournalManager owns in-memory data model, assignment logic, migration, spread creation, and deletion. [SPRD-11, SPRD-13, SPRD-15]
- Two UI paths: [SPRD-25, SPRD-35, SPRD-38]
  - Conventional UI (`MainTabView`) with hierarchical spread tab bar (year/month/day/multiday), entry list, migration banner, and settings. [SPRD-25, SPRD-27, SPRD-30]
  - Calendar-style UI for traditional mode with year/month/day drill-in. [SPRD-35, SPRD-38]
- BuJo modes: "conventional" (migration history visible) and "traditional" (preferred assignment only). [SPRD-20, SPRD-17]

## Goals
- Deliver a tab-based bullet journal focused on spreads, tasks, and notes, with in-view hierarchical navigation, manual migration, and clear task history in conventional mode. [SPRD-25, SPRD-15, SPRD-29]
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
  - Regular width (iPad): NavigationSplitView for top-level destinations; spread navigation stays in the spread view via hierarchical tabs
  - Compact width (iPhone): Tab bar/sheets for top-level destinations; same in-view hierarchical spread tabs
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
- Migration prompt logic in v1 applies to tasks only and only in conventional mode. [SPRD-110, SPRD-111]
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
- Edit entries (title, date/period, status where applicable). [SPRD-24]
- Delete entries across all spreads. [SPRD-11, SPRD-5]
- Events are deferred to v2 and not available in v1. [SPRD-69]

### Entry Date/Period Changes (Reassignment)
- Changing preferred date or period triggers reassignment logic in conventional mode. [SPRD-24]
- Period is independently editable (e.g., changing from month to day without changing the date month). [SPRD-24]
- Old assignments (on old date/period's spreads) are marked as migrated to preserve history. [SPRD-24]
- New assignment is created on the best matching spread for the new date/period: [SPRD-24, SPRD-13]
  - Search from finest to coarsest: day → month → year.
  - If a matching spread exists, create/update assignment with open/active status.
  - If no matching spread exists, entry goes to Inbox.
- If destination spread already has an assignment, update its status (don't duplicate). [SPRD-52]
- Traditional mode date/period changes also trigger conventional reassignment logic. [SPRD-17, SPRD-24]

### Task Status
- Statuses: open, complete, migrated, cancelled. [SPRD-10, SPRD-24]
- Cancelled tasks are hidden in v1 (excluded from Inbox, migration, and default lists). [SPRD-16, SPRD-31]

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
- Inbox appears as a toolbar button in the spread content view (not a tab). [SPRD-31, SPRD-68]
- When Inbox has entries, tint the button yellow instead of showing a badge count. [SPRD-68]
- Tapping the button opens Inbox view as sheet. [SPRD-31]
- Inbox auto-resolves when a matching spread is created. [SPRD-14, SPRD-31]
- Cancelled tasks are excluded from Inbox. [SPRD-16]

### Navigation and UI
- Spread navigation uses an in-view hierarchical tab bar on both iPad and iPhone; it handles navigation between spreads only. [SPRD-19, SPRD-25]
- Hierarchical tab bar behavior: [SPRD-25]
  - Periods shown: year → month → (day, multiday); no week period. [SPRD-8]
  - Chronological ordering within each level. [SPRD-25]
  - Selected year and month are sticky on the leading edge while children scroll horizontally. [SPRD-25]
  - Re-tapping the selected year/month opens a picker listing available years/months (created spreads only); selection updates and expands children, with no "show all" toggle. [SPRD-66]
  - Initial selection is the smallest period containing today (day > multiday); if multiple multiday spreads contain today, choose earliest start date, then earliest end date, then earliest creation date. [SPRD-25]
  - Show "No spreads" placeholder when a selected year/month has no children. [SPRD-25]
  - Tap-only navigation; keep the selected spread visible via horizontal scroll. [SPRD-25]
  - A trailing "+" button is always visible and opens a creation menu (spread or task). [SPRD-23, SPRD-25, SPRD-26]
- Traditional mode uses calendar-style navigation (year → month → day). [SPRD-35, SPRD-38]
- Traditional navigation mirrors iOS Calendar-style drill-in. [SPRD-35, SPRD-38]
- Spread content view shows active entries and migrated entries section (conventional). [SPRD-27, SPRD-29]
- Conventional-mode migration prompt UI: [SPRD-111]
  - Year, month, and day spreads may show a small migration banner when at least one task is eligible to move into that spread.
  - Multiday spreads never show the migration banner.
  - Traditional mode never shows the migration banner because all calendar spreads are navigable without created conventional spread records.
  - The banner reappears on every visit as long as eligible tasks still exist; dismissal state is not persisted in v1.
  - Tapping the banner opens a migration review sheet; it never auto-migrates tasks.
  - The sheet lists only tasks, never notes.
  - Eligible tasks are preselected by default.
  - Tasks are sectioned by source (`Inbox`, year, or month/day parent spread).
  - Each row shows both source and destination.
  - Confirming migration applies one batch action to all selected tasks.
  - On submit, eligibility is revalidated. Still-eligible tasks migrate; no-longer-eligible tasks are skipped with non-blocking feedback.
  - After migration, the sheet stays open if eligible tasks remain and dismisses automatically when none remain.
- Global overdue review UI: [SPRD-112]
  - A yellow overdue toolbar button appears on all spreads in both conventional and traditional modes whenever at least one overdue task exists anywhere in the journal.
  - The button shows an icon plus overdue count.
  - Tapping it opens a global overdue review sheet.
  - The overdue review sheet is read/review oriented in v1: rows open the task for inspection/editing, but there are no bulk overdue actions.
  - Tasks are sectioned by current source assignment, ordered chronologically by source spread date; `Inbox` is treated as a source section when needed.
  - A task may appear in both the overdue review sheet and a conventional migration review sheet at the same time when it is overdue globally and also eligible to move into the currently viewed spread.
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
  - Migration prompt and review sheet exist only in conventional mode. [SPRD-110, SPRD-111]
- Traditional: [SPRD-17, SPRD-35, SPRD-38]
  - Entries appear only on preferred assignment, no migration history visible. [SPRD-17, SPRD-35]
  - All spreads available for navigation regardless of created spread records. [SPRD-17, SPRD-38]
  - Must not mutate the "created spreads" data used by conventional mode. [SPRD-17, SPRD-53]
  - Migrating updates the preferred date/period; conventional assignments recomputed. [SPRD-17, SPRD-15]
  - If no conventional spread exists for migration target, assign to nearest parent or Inbox. [SPRD-17, SPRD-14]
  - Traditional mode does not show migration prompts because all calendar spreads are navigable without waiting for created conventional spreads. [SPRD-110]
  - The global overdue toolbar button remains available in traditional mode. [SPRD-112]

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
- Toolbar sync status is icon-only; any status copy is shown in main content (not in the toolbar). Use a minimal, visible banner or status line near the top of the main spreads content. [SPRD-85]
- Assignment durability is a product requirement, not a local cache best-effort. [SPRD-119, SPRD-120, SPRD-121]
  - `task_assignments` and `note_assignments` are first-class synced records.
  - After successful sync, the server must be able to rebuild the exact same current placement and the exact same assignment history for the signed-in user.
  - This includes current spread or Inbox placement plus historical migrated/completed/cancelled task assignments and active/migrated note assignments.
  - This guarantee must hold after:
    - deleting the app, reinstalling, and signing back into the same account
    - signing out, then signing back into the same account
    - rebuilding a clean second device from synced server state
    - wiping the local store and pulling from server again
- Every user action that changes assignment state/history must enqueue and sync the corresponding assignment mutations. [SPRD-120]
  - creation with direct spread assignment
  - Inbox fallback creation
  - migration
  - preferred date/period edits that cause reassignment
  - spread deletion reassignment to parent or Inbox
  - status changes that affect assignment history semantics
  - entry deletion, including assignment tombstones
- Assignment deletion/removal must use soft-delete tombstones with revision updates; hard deletes are not a valid product sync path. [SPRD-120]
- For the same entry and the same `(period, date)` destination, status changes update the same logical assignment record instead of creating duplicate assignment-history rows. [SPRD-119]
- Assignment records require durable IDs so updates and tombstones can target the same logical assignment across devices and reinstalls. [SPRD-119]
- Assignment outbox invariants: [SPRD-120]
  - assignment mutations must be enqueued on every assignment-changing save path
  - parent task/note mutations must push before child assignment mutations when both are pending
  - assignment create/update/delete mutations remain in the outbox until the server acknowledges them
- Safe repair/backfill for already-broken assignment sync is required. [SPRD-121]
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
- Auth button in toolbar, trailing the Inbox button. [SPRD-84]
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
- Scenario UI tests focus on conventional-mode logic-heavy flows first: assignment fallback, Inbox resolution, migration prompting/review, overdue review, and edit-time reassignment. [SPRD-114]
- UI scenario fixtures may seed the starting state, but the user action under test must still be performed through the UI. [SPRD-114]
- A shared localhost scenario harness is required for UI tests. It must centralize:
  - app launch with `localhost`, scenario dataset selection, and fixed `today`
  - spread navigation
  - migration banner/review interactions
  - overdue toolbar/review interactions
  - common assertions for relocated tasks, source sections, and migrated-history visibility
- The UI scenario suite should stay organized by logic area instead of by fixture: assignment, reassignment, migration, and overdue each get their own test class backed by the shared harness.
- Scenario-only mock data sets may live in the same in-code catalog as debug mock data, but test-only cases must be hidden from normal debug-menu browsing. [SPRD-114]
- Scenario-test-critical UI must expose explicit accessibility identifiers instead of relying only on visible copy. This includes:
  - migration banner, review sheet, section headers, rows, selection controls, and confirm action
  - overdue toolbar button, review sheet, section headers, rows, and row-open actions
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
| Overdue day threshold | Day-assigned open tasks become overdue after the assigned day passes. | The yellow overdue toolbar button count includes the task and the sheet lists it under its current source. |
| Overdue month/year thresholds | Month- and year-assigned tasks become overdue only after the full assigned period passes. | Counts and sections change only at the defined absolute-date boundaries. |
| Inbox overdue fallback | Inbox tasks become overdue from their desired assignment when no open spread assignment exists. | The overdue review sheet includes an `Inbox` section for those tasks. |
| Overdue review flow | Tapping the yellow overdue button opens the global review sheet from conventional and traditional contexts. | Count and visibility remain correct from any spread context. |
| Note exclusions | Notes never appear in migration or overdue review surfaces. | Migration review exclusion is covered in UI; overdue exclusion is backstopped by focused unit tests because the row surface is not reliably distinguishable enough for stable UI assertions. |
| Traditional-mode parity check | Traditional mode still shows the global overdue button when overdue tasks exist, but never shows migration UI. | Overdue remains available and migration controls remain absent. |
- Durability and rebuild matrix required for v1: [SPRD-119, SPRD-120, SPRD-121, SPRD-122]

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
- Lower-level tests required alongside the user-facing rebuild scenarios: [SPRD-119, SPRD-120, SPRD-121]
  - durable assignment ID generation and persistence
  - assignment mutation enqueueing on every assignment-changing save path
  - assignment update vs create vs tombstone behavior
  - push ordering between parent entries and child assignments
  - exact pull/apply reconstruction of placement and history from server rows
- Device matrix:
  - iPhone is the default scenario-test device. [SPRD-114]
  - Add a targeted iPad subset only for scenarios where layout or navigation behavior differs materially from iPhone. [SPRD-114]

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

### Error Handling UX
- **Sign-in errors**: Error messages are displayed inline on the login sheet below the password field. Error text is human-readable and maps from auth error types: [SPRD-84]
  - Invalid credentials: "Incorrect email or password."
  - Email not confirmed: "Please check your email to confirm your account."
  - User not found: "No account found with that email."
  - Rate limited: "Too many attempts. Please try again later."
  - Network timeout: "Unable to connect. Check your internet connection."
- **Sync errors**: Sync failures are non-blocking. The sync status banner shows an error icon with a brief message. Automatic retry occurs with exponential backoff (2s base, 300s max). Manual retry is available via pull-to-refresh or the sync status view. [SPRD-85]
- **Network errors**: When offline, the app continues to function normally with local data. Sync status shows "offline" state. When connectivity returns, sync resumes automatically. [SPRD-85]
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
- Inbox appears as a toolbar button in the spread content view and opens as sheet; when non-empty, the icon is tinted yellow. [SPRD-31, SPRD-68]
- Settings include mode toggle + first day of week preference. [SPRD-20, SPRD-49]
- Spread deletion never deletes entries; reassigns to parent or Inbox (multiday deletion has no reassignment). [SPRD-15, SPRD-18]
- Collections are plain text pages outside spread navigation; sorted by modified date; content is unbounded; collections sync via Supabase. [SPRD-19, SPRD-40, SPRD-85]
- Traditional mode in scope for v1. [SPRD-35, SPRD-38]
- Traditional mode date changes trigger conventional reassignment. [SPRD-17, SPRD-24]
- Multiplatform: iPadOS primary, iOS supported; adaptive layouts per size class. [SPRD-19]
- macOS deferred to post-v1. [SPRD-56]
- Visual style uses dot grid backgrounds on spread content surfaces only, muted blue accents, and Debug-only appearance overrides for paper tone and typography. [SPRD-62, SPRD-63]
- Entry period is independently editable; period changes trigger the same reassignment logic as date changes. [SPRD-24]
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
