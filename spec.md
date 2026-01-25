# Bulleted Specification (v1.0)

## Status
- Specification finalized for v1 implementation (tasks + notes only). [SPRD-1]
- Events (including calendar integrations) are deferred to v2. [SPRD-69]

## Project Summary
- Multiplatform app (iPadOS primary, iOS) built in SwiftUI with SwiftData persistence. [SPRD-1, SPRD-5, SPRD-42]
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
- Support offline-first usage with iCloud sync. [SPRD-42, SPRD-44]

## Non-Goals (v1)
- Search, filters, or tagging. [SPRD-56]
- Week period in Period enum or week-based task assignment. [SPRD-8, SPRD-56]
- Automated migration. [SPRD-15, SPRD-56]
- Advanced collection types beyond plain text pages. [SPRD-39, SPRD-56]
- Events (manual creation or calendar integrations) are deferred to v2. [SPRD-69]
- Localization - hardcoded English strings for v1. Revisit post-v1.
- macOS support - planned for future versions.

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
- Deleting a spread reassigns all entries (open, completed, migrated) to the parent spread. [SPRD-15]
- If no parent spread exists, entries go to Inbox. [SPRD-14, SPRD-15]
- Entries are NEVER deleted when a spread is deleted; history is preserved. [SPRD-15]
- Deletion is blocked if it would orphan entries with no valid destination. [SPRD-15]

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

### Entry Date Changes (Reassignment)
- Changing preferred date triggers reassignment logic in conventional mode. [SPRD-24]
- Old assignments (on old date's spreads) are marked as migrated to preserve history. [SPRD-24]
- New assignment is created on the best matching spread for the new date: [SPRD-24, SPRD-13]
  - Search from finest to coarsest: day → month → year.
  - If a matching spread exists, create/update assignment with open/active status.
  - If no matching spread exists, entry goes to Inbox.
- If destination spread already has an assignment, update its status (don't duplicate). [SPRD-52]
- Traditional mode date changes also trigger conventional reassignment logic. [SPRD-17, SPRD-24]

### Task Status
- Statuses: open, complete, migrated, cancelled. [SPRD-10, SPRD-24]
- Cancelled tasks are hidden in v1 (excluded from Inbox, migration, and default lists). [SPRD-16, SPRD-31]

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
- Migration banner appears when tasks can move into the current spread. [SPRD-30]
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
- Persist settings via UserDefaults or @AppStorage. [SPRD-20]

### Modes
- Conventional: [SPRD-13, SPRD-14, SPRD-25, SPRD-31]
  - Entries may appear on multiple spreads with per-spread status. [SPRD-15]
  - Spreads must be created explicitly. [SPRD-12, SPRD-26]
  - Unassigned entries go to global Inbox. [SPRD-14, SPRD-31]
  - Inbox auto-resolves when a matching spread is created. [SPRD-14, SPRD-31]
- Traditional: [SPRD-17, SPRD-35, SPRD-38]
  - Entries appear only on preferred assignment, no migration history visible. [SPRD-17, SPRD-35]
  - All spreads available for navigation regardless of created spread records. [SPRD-17, SPRD-38]
  - Must not mutate the "created spreads" data used by conventional mode. [SPRD-17, SPRD-53]
  - Migrating updates the preferred date/period; conventional assignments recomputed. [SPRD-17, SPRD-15]
  - If no conventional spread exists for migration target, assign to nearest parent or Inbox. [SPRD-17, SPRD-14]

### Collections
- Collections are plain text pages (title + content). [SPRD-39]
- Collections live outside spread navigation in a top-level entry point. [SPRD-19, SPRD-40]
- Support create, edit, delete operations. [SPRD-40, SPRD-41]

### Persistence
- Use SwiftData for local storage. [SPRD-4, SPRD-5]
- Schema includes Spread, Task, Note, Collection (Event model reserved for v2). [SPRD-4, SPRD-8, SPRD-9, SPRD-39]
- iCloud sync required for v1 (CloudKit-backed SwiftData). [SPRD-42, SPRD-43]
- Offline-first, then sync (industry-standard defaults). [SPRD-44]

### Development Tooling
- Debug UI is available only in DEBUG builds; Release builds have no debug destinations or data-loading actions. [SPRD-45]
- Replace the debug overlay with a dedicated Debug destination:
  - iPadOS (regular width): sidebar item titled "Debug" with SF Symbol `ant`. [SPRD-45]
  - iOS (compact width): tab bar item titled "Debug" with SF Symbol `ant`. [SPRD-45]
- Debug menu provides grouped sections with labels and descriptions:
  - Environment and DependencyContainer summary. [SPRD-2, SPRD-3, SPRD-45]
  - Mock Data Sets loader with buttons that overwrite existing data and reload app state. [SPRD-46]
- Mock data sets are generated in code (no external fixtures) and cover varied spread scenarios and edge cases (empty, standard year/month/day, multiday ranges, boundary dates, large volume/perf). [SPRD-46]
- Mock data set loading uses JournalManager APIs to mirror app behavior; loading or clearing data refreshes UI and resets selection to today's spread when available. [SPRD-67]
- Debug menu provides appearance overrides for paper tone, dot grid (size/spacing/opacity), heading font, and accent color (DEBUG builds only). [SPRD-63]
- Debug tooling files live under `Spread/Debug` to keep debug-only views/data isolated. [SPRD-45]

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
- Deleting spread with entries: Reassign all entries to parent or Inbox; never delete entries. [SPRD-15]
- Overlapping multiday spreads: Each multiday is independent; entries appear on all applicable. [SPRD-8, SPRD-49]
- Past-dated entries: Blocked in v1; validation prevents creation. [SPRD-23, SPRD-56]
- Entry date change: Old assignments marked migrated; new assignment on best spread or Inbox. [SPRD-24]

## Resolved Decisions
- Entry architecture uses protocol + separate @Model classes for scalability. [SPRD-9]
- Week period removed from Period enum; multiday covers week-like scenarios. [SPRD-8, SPRD-56]
- Notes migrate only via explicit user action, not batch suggestions. [SPRD-34]
- Inbox appears as a toolbar button in the spread content view and opens as sheet; when non-empty, the icon is tinted yellow. [SPRD-31, SPRD-68]
- Settings include mode toggle + first day of week preference. [SPRD-20, SPRD-49]
- Spread deletion never deletes entries; reassigns to parent or Inbox. [SPRD-15]
- Collections are plain text pages outside spread navigation. [SPRD-19, SPRD-40]
- Traditional mode in scope for v1. [SPRD-35, SPRD-38]
- Traditional mode date changes trigger conventional reassignment. [SPRD-17, SPRD-24]
- Multiplatform: iPadOS primary, iOS supported; adaptive layouts per size class. [SPRD-19]
- macOS deferred to post-v1. [SPRD-56]
- Visual style uses dot grid backgrounds on spread content surfaces only, muted blue accents, and Debug-only appearance overrides for paper tone and typography. [SPRD-62, SPRD-63]

## Open Questions
- For v2 events: EventKit only or EventKit + Google? [SPRD-57]
- For v2 events: read-only import vs write-back edits? [SPRD-57]
- For v2 events: local manual events in addition to integrations, or integrations only? [SPRD-57]

---

## Future Versions
- Spread bookmarking. [SPRD-56]
- Dynamic spread names. [SPRD-56]
