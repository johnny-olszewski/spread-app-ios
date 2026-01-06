# Bulleted Specification (v1.0)

## Status
- Specification finalized for v1 implementation. [SPRD-1]

## Project Summary
- iOS app built in SwiftUI with SwiftData persistence. [SPRD-1, SPRD-5, SPRD-42]
- Primary UI direction is tab-based spreads; traditional mode uses calendar navigation. [SPRD-25, SPRD-35, SPRD-38]
- Core entities: [SPRD-8, SPRD-9, SPRD-10]
  - Spread: period (day, multiday, month, year) + normalized date. [SPRD-8]
  - Entry: protocol for task, event, note with type-specific behaviors. [SPRD-9]
  - Task: assignable entry with status and migration history. [SPRD-9, SPRD-10]
  - Event: date-range entry that appears on overlapping spreads. [SPRD-9, SPRD-33]
  - Note: assignable entry with explicit-only migration. [SPRD-9, SPRD-34]
  - TaskAssignment/NoteAssignment: period/date/status for migration tracking. [SPRD-10, SPRD-15]
- JournalManager owns in-memory data model, assignment logic, migration, spread creation, and deletion. [SPRD-11, SPRD-13, SPRD-15]
- Two UI paths: [SPRD-25, SPRD-35, SPRD-38]
  - Tab-based UI (`MainTabView`) with spread tabs, entry list, migration banner, and settings. [SPRD-25, SPRD-27, SPRD-30]
  - Calendar-style UI for traditional mode with year/month/day drill-in. [SPRD-35, SPRD-38]
- BuJo modes: "conventional" (migration history visible) and "traditional" (preferred assignment only). [SPRD-20, SPRD-17]

## Goals
- Deliver a tab-based bullet journal focused on spreads, with manual migration and clear task history in conventional mode. [SPRD-25, SPRD-15, SPRD-29]
- Provide calendar-style navigation in traditional mode (year/month/day) without altering created-spread data. [SPRD-17, SPRD-35, SPRD-38]
- Support offline-first usage with iCloud sync. [SPRD-42, SPRD-44]

## Non-Goals (v1)
- Search, filters, or tagging. [SPRD-56]
- Week period in Period enum or week-based task assignment. [SPRD-8, SPRD-56]
- Automated migration. [SPRD-15, SPRD-56]
- Advanced collection types beyond plain text pages. [SPRD-39, SPRD-56]
- Localization - hardcoded English strings for v1. Revisit post-v1.

## Platform
- iOS 26+ (SwiftUI). [SPRD-1]

---

## Core Concepts

### Entry Architecture
- Entry: Protocol defining shared behavior (id, title, createdDate, entryType). [SPRD-9]
- Entry types are separate SwiftData @Model classes for type-safe queries and scalability. [SPRD-9]
- EntryType enum: `.task`, `.event`, `.note` - used for UI rendering and type discrimination. [SPRD-9]
- AssignableEntry protocol (Task, Note): adds date, period, assignments array. [SPRD-9]
- DateRangeEntry protocol (Event): adds startDate, endDate, `appearsOn(period:date:calendar:)`. [SPRD-9]

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

### Event
- Inherits Entry protocol. [SPRD-9]
- Supports four timing modes: singleDay, allDay, timed, multiDay. [SPRD-9]
- Properties: startDate, endDate, startTime (optional), endTime (optional), timing. [SPRD-9]
- Appears on all spreads that overlap its date range (computed, not assigned). [SPRD-13, SPRD-33]
- Cannot be migrated. [SPRD-15]
- Has no assignments array - visibility is derived from date range. [SPRD-33]
- Symbol: empty circle (○). [SPRD-21]

### Note
- Inherits Entry protocol. [SPRD-9]
- Has status: active, migrated. [SPRD-9]
- Behaves like tasks for spread assignment (date, period, assignments). [SPRD-9, SPRD-34]
- Can migrate only when user explicitly requests (never suggested in batch migration). [SPRD-15, SPRD-34]
- May have longer content field for extended notes. [SPRD-9]
- Symbol: dash (—). [SPRD-21]

### Migration
- Moving a task/note from a parent spread to a child spread. [SPRD-15]
- Source assignment status becomes migrated; destination assignment becomes open/active. [SPRD-15]
- Manual only - user must trigger migration. [SPRD-15]
- Events cannot migrate. [SPRD-15]
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

### Entries (Tasks/Events/Notes)
- Create entries with title, preferred date, preferred period, and type. [SPRD-9, SPRD-23]
- Tasks support status (open/complete/migrated/cancelled). [SPRD-9, SPRD-24]
- Notes support status (active/migrated). [SPRD-9]
- Events have no status. [SPRD-9]
- Tasks and notes can be assigned to year, month, or day spreads. [SPRD-13]
- Events appear on all applicable spreads based on date range overlap. [SPRD-13, SPRD-33]
- Events are not migratable. [SPRD-15, SPRD-22]
- Notes are not suggested for batch migration but can be migrated explicitly. [SPRD-15, SPRD-34]
- Creating entries for past dates is not allowed in v1. [SPRD-23, SPRD-56]
- Edit entries (title, date/period, status where applicable). [SPRD-24]
- Delete entries across all spreads. [SPRD-11, SPRD-5]

### Task Status
- Statuses: open, complete, migrated, cancelled. [SPRD-10, SPRD-24]
- Cancelled tasks are hidden in v1 (excluded from Inbox, migration, and default lists). [SPRD-16, SPRD-31]

### Inbox
- Unassigned entries (tasks/notes) are stored in a global Inbox. [SPRD-14]
- Inbox appears as badge/button in navigation header (not a tab). [SPRD-31]
- Badge shows count of unassigned entries; hidden when count is 0. [SPRD-31]
- Tapping badge opens Inbox view as sheet. [SPRD-31]
- Inbox auto-resolves when a matching spread is created. [SPRD-14, SPRD-31]
- Events are NEVER in Inbox (they have computed visibility). [SPRD-14]
- Cancelled tasks are excluded from Inbox. [SPRD-16]

### Navigation and UI
- Primary UI is tab-based spread navigation (conventional mode). [SPRD-25]
- Traditional mode uses calendar-style navigation (year → month → day). [SPRD-35, SPRD-38]
- Traditional navigation mirrors iOS Calendar-style drill-in. [SPRD-35, SPRD-38]
- Spread content view shows active entries and migrated entries section (conventional). [SPRD-27, SPRD-29]
- Migration banner appears when tasks can move into the current spread. [SPRD-30]
- Collections are accessed from a top-level entry point (outside spread navigation). [SPRD-19, SPRD-40]
- Settings accessible via gear icon in navigation header. [SPRD-20]

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
- Schema includes Spread, Task, Event, Note, Collection. [SPRD-4, SPRD-8, SPRD-9, SPRD-39]
- iCloud sync required for v1 (CloudKit-backed SwiftData). [SPRD-42, SPRD-43]
- Offline-first, then sync (industry-standard defaults). [SPRD-44]

---

## BuJo Method Features (v1)
- Future log (year spread). [SPRD-25, SPRD-27]
- Monthly log (month spread with entries). [SPRD-28]
- Daily log (day spread with entries). [SPRD-28]
- Rapid logging symbols (task/event/note). [SPRD-21, SPRD-22]
- Migration and scheduling (manual). [SPRD-15, SPRD-30]
- Collections (plain text pages). [SPRD-39, SPRD-40, SPRD-41]

## BuJo Method Features (Future/v2)
- Index. [SPRD-56]
- Habit/mood trackers. [SPRD-56]
- Review/reflection. [SPRD-56]
- Search, filters, tagging. [SPRD-56]

---

## Edge Cases (Resolved)
- Date normalization: Use Calendar API with user's firstWeekday setting. [SPRD-7, SPRD-49]
- Entries with no matching spread: Go to Inbox; auto-resolve on spread creation. [SPRD-13, SPRD-14]
- Migration when destination has assignment: Update existing assignment status. [SPRD-15, SPRD-52]
- Deleting spread with entries: Reassign all entries to parent or Inbox; never delete entries. [SPRD-15]
- Overlapping multiday spreads: Each multiday is independent; entries appear on all applicable. [SPRD-8, SPRD-49]
- Past-dated entries: Blocked in v1; validation prevents creation. [SPRD-23, SPRD-56]

## Resolved Decisions
- Entry architecture uses protocol + separate @Model classes for scalability. [SPRD-9]
- Week period removed from Period enum; multiday covers week-like scenarios. [SPRD-8, SPRD-56]
- Events use computed visibility (date range overlap), not assignments. [SPRD-33]
- Notes migrate only via explicit user action, not batch suggestions. [SPRD-34]
- Inbox appears as badge/button in header, opens as sheet. [SPRD-31]
- Settings include mode toggle + first day of week preference. [SPRD-20, SPRD-49]
- Spread deletion never deletes entries; reassigns to parent or Inbox. [SPRD-15]
- Collections are plain text pages outside spread navigation. [SPRD-19, SPRD-40]
- Traditional mode in scope for v1. [SPRD-35, SPRD-38]

## Open Questions
- None for v1 spec.
