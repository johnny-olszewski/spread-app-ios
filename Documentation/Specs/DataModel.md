# Data Model

> Source: Documentation/spec.md

## Core Concepts

### Entry Architecture
- Entry: Protocol defining shared behavior (id, title, createdDate, entryType). [SPRD-9]
- Entry types are separate SwiftData @Model classes for type-safe queries and scalability. [SPRD-9]
- EntryType enum: `.task`, `.note` (v1) - used for UI rendering and type discrimination. [SPRD-9]
- `.event` entry type and `DateRangeEntry` protocol remain reserved for a future persisted Event @Model. [SPRD-57]
- AssignableEntry protocol (Task, Note): adds date, period, assignments array. [SPRD-9]
- `CalendarEvent` is a lightweight value type (not an Entry) representing a live-fetched EventKit event; it is not persisted, not assigned, and not part of the Entry protocol hierarchy. [SPRD-194]

### Spread
- A journaling page tied to a time period and normalized date. [SPRD-8]
- Periods supported for creation: year, month, day, multiday. [SPRD-8, SPRD-12]
- Week period is NOT supported (removed from Period enum). [SPRD-8, SPRD-56]
- Persisted explicit spreads support user-scoped personalization metadata as part of `WKFLW-17`: favorite state, optional custom name override, and dynamic naming enabled state. These fields do not apply to traditional virtual destinations. [SPRD-169]
- Custom name override is the highest-priority display label. When no override exists and dynamic naming is enabled, qualifying explicit spreads use live relative names; otherwise they use canonical date titles. Relative names never create a new period or assignment granularity. [SPRD-169]
- Persisted explicit spreads can be deleted from the conventional-mode spread actions menu. Deleting a spread does not delete tasks or notes; existing spread deletion rules migrate entry assignments to the nearest parent spread or Inbox. The user-facing behavior is permanent deletion with no restore/trash flow, backed by the existing local hard delete plus sync tombstone/delete-wins architecture. [SPRD-173]
- Persisted explicit multiday spreads can be date-edited from the conventional-mode spread actions menu. Editing a multiday range updates the same spread record's existing date/range fields, preserves personalization, and keeps existing direct multiday assignments attached to that spread record identity. [SPRD-175, SPRD-193]
- New multiday spreads must not overlap other multiday spreads. Existing overlapping multiday spreads already present in local or synced data are grandfathered as legacy data, but create/edit validation for newly saved multiday ranges must reject any overlap. [SPRD-193]

### Spread Periods
- Creatable periods: year, month, day, multiday. [SPRD-8]
- Task/Note assignable periods: year, month, multiday, day. [SPRD-13, SPRD-193]
- Multiday is a first-class preferred period and current assignment destination when the user explicitly assigns to an existing multiday spread or when waterfall reassignment resolves a finer preferred date into an existing multiday spread. Multiday is still optional product behavior: recommendations and default spread expectations never assume users will create multiday spreads. [SPRD-18, SPRD-193]
- Period hierarchy for explicit-spread resolution is year → month → multiday → day. Resolution still respects the entry's preferred-period ceiling:
  - year-preferred entries resolve only across year
  - month-preferred entries resolve across month → year
  - multiday-preferred entries resolve across explicit multiday → month → year
  - day-preferred entries resolve across day → containing multiday → month → year [SPRD-8, SPRD-13, SPRD-193]
- For grandfathered legacy overlap data only, when multiple existing multiday spreads contain the same date and automatic resolution must choose among them, the resolver prefers the narrowest containing multiday range and breaks ties using the app's existing chronological spread ordering. [SPRD-193]

### Task
- Inherits Entry protocol. [SPRD-9]
- Has status: open, complete, migrated, cancelled, in_flight. [SPRD-10, SPRD-316]
- `migrated` is system-derived historical assignment state and is not user-editable in the task edit sheet. [SPRD-141]
- `in_flight` is task-only: the user has taken the action available to them but the task itself isn't finished (e.g. a submitted request awaiting approval). User-editable via the same row tap-cycle and edit-sheet Status picker as open/complete/cancelled; renders as a standalone airplane-tilt icon (no overlay-on-shape, unlike every other status) at full opacity with an editable title; automatically excluded from overdue and migration suggestions via the existing `status == .open` gates. [SPRD-316]
- Can be assigned to year, month, multiday, or day spreads. [SPRD-13, SPRD-193]
- A task may have a desired assignment defined by a preferred `date` and preferred `period`; when no preferred assignment exists, the task remains in Inbox until explicitly assigned. [SPRD-24, SPRD-110, SPRD-170]
- A task's due date is distinct from its assignment target. Due date is informational display metadata only; it does not move the task between spreads, place it in Inbox, affect migration, or determine overdue membership. [SPRD-170]
- `WKFLW-17` task metadata includes one optional plain multiline body field, one optional day-level due date, and one non-null display-only priority enum (`none`, `low`, `medium`, `high`). These are task-level properties, not assignment-level properties. [SPRD-170]
- `SESH-21` adds an optional `list` relationship (one `List` or nil) and an optional `tags` relationship (zero or more `Tag`s) as task-level organizational fields. These are task-level properties, not assignment-level properties. [SPRD-221]
- Links, assigned time, subtasks, sequential/blocking relationships, hidden-on-spreads, and status expansion are deferred. Tags (as a separate feature from the organizational `Tag` model) remain deferred. [SPRD-167, SPRD-171]
- Tracks migration history via TaskAssignment array. [SPRD-10]
- Eligible for batch migration suggestions. [SPRD-15]
- Symbol: solid circle (●). [SPRD-21]
- Status visual treatment: [SPRD-22, SPRD-64]
  - Open: solid circle, no overlay, normal styling.
  - Complete: solid circle with X overlay, greyed out row.
  - Migrated: solid circle with arrow (→) overlay, greyed out row.
  - Cancelled: solid circle, no overlay, strikethrough entire row.
  - In Flight: airplane-tilt icon replacing the circle entirely (no overlay), `.primary` color, full-opacity row, editable title — same non-greyed treatment as Open. [SPRD-316]

### Note
- Inherits Entry protocol. [SPRD-9]
- Has status: active, migrated. [SPRD-9]
- Behaves like tasks for spread assignment (date, period, assignments). [SPRD-9, SPRD-34]
- Uses the same preferred-date/preferred-period assignment resolution as tasks, including first-class multiday assignment semantics. Notes are never suggested in batch migration UI, but explicit spread creation may automatically move them to the best newly available destination under the same hierarchy rules as tasks. [SPRD-15, SPRD-34, SPRD-186, SPRD-193]
- May have longer content field for extended notes. [SPRD-9]
- `SESH-21` adds an optional `list` relationship (one `List` or nil) and an optional `tags` relationship (zero or more `Tag`s) for model parity with Task. Notes are not displayed in the Task Browser tab but share the same organizational model. [SPRD-221]
- Symbol: dash (—). [SPRD-21]
- Status visual treatment: [SPRD-22, SPRD-64]
  - Active: dash, no overlay, normal styling.
  - Migrated: dash with arrow (→) overlay, greyed out row.

### List
- A first-class SwiftData `@Model` entity representing a broad domain grouping (e.g. "Work", "Home", "Personal"). [SPRD-221]
- Has a non-empty, trimmed `name` string. [SPRD-221]
- Has a one-to-many inverse relationship to `DataModel.Task` and `DataModel.Note` (each task/note may belong to at most one List). [SPRD-221]
- Synced via the standard outbox/revision/tombstone architecture. [SPRD-221]
- Not related to `Collection`; Collections are a distinct bullet journal concept outside of spread entries. [SPRD-221]

### Tag
- A first-class SwiftData `@Model` entity representing a specific project or theme (e.g. "Baby Preparation", "EOY Presentation", "Garage Reorganization"). [SPRD-221]
- Has a non-empty, trimmed `name` string. [SPRD-221]
- Has a many-to-many inverse relationship to `DataModel.Task` and `DataModel.Note` (each task/note may have zero or more Tags; each Tag may be used by zero or more tasks/notes). [SPRD-221]
- Synced via the standard outbox/revision/tombstone architecture. [SPRD-221]

### Persistence
- Use SwiftData for local storage. [SPRD-4, SPRD-5]
- Schema includes Spread, Task, Note, Collection, List, Tag (Event model reserved for v2). [SPRD-4, SPRD-8, SPRD-9, SPRD-39, SPRD-221]
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
