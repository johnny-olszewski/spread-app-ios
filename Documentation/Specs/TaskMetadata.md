# Task Metadata

> Source: Documentation/spec.md

## Approved Task Scope (WKFLW-17)
- Tasks gain task-level plain multiline `body`, non-null display-only `priority`, and optional day-only `dueDate`. These fields are not assignment-level metadata. [SPRD-170]
- Priority values are `none`, `low`, `medium`, and `high`, defaulting to `none`; task rows show text badges for `low`, `medium`, and `high` and omit `none`. Priority does not affect ordering. [SPRD-170]
- Due date is informational only. It is fully independent from preferred assignment, may be any calendar day including the past, never drives assignment, Inbox placement, migration, or overdue behavior, and does not validate against preferred assignment. [SPRD-170]
- Task rows show due date inline when present. Open tasks whose due date is today or in the past show a distinct due-date highlight separate from assignment-overdue styling. Completed and cancelled tasks still show due date neutrally, without due-date urgency highlighting. If an open task is both assignment-overdue and due-date-highlighted, both signals are shown distinctly. [SPRD-170]
- Task body is plain multiline text only, trimmed on save, stored as nil when empty, displayed as a single-line row preview when present, and searched alongside task title in the global task browser. Body-backed search results use the normal row plus the body preview rather than a search-specific result layout. [SPRD-170]
- Task create/edit UI keeps priority and due date visible in the main form while body lives in an expandable/details area. Body, priority, and due date remain editable when a task is complete or cancelled even if assignment controls are disabled. [SPRD-170]
- `SESH-21` adds `list` (optional, one `List` entity or nil) and `tags` (optional, zero or more `Tag` entities) as task-level organizational metadata. These are task-level properties, not assignment-level. List and Tags remain editable when a task is complete or cancelled, consistent with body, priority, and due date. [SPRD-221, SPRD-224]
- A task belongs to at most one List; List represents a domain grouping (e.g. "Work", "Home"). A task may have zero or more Tags; Tags represent cross-cutting projects or themes (e.g. "EOY Presentation"). [SPRD-221]
- Tasks can have a real nil preferred assignment. Nil assignment applies to tasks only; note parity is explicitly deferred. [SPRD-170]
- A true nil-assignment task is Inbox-first, remains in Inbox until explicitly assigned, never becomes overdue until it has a preferred assignment, and is unaffected by later spread creation. Due date can still highlight independently on open Inbox-first task rows. [SPRD-170]
- Assigned tasks keep existing most-granular-valid spread resolution and Inbox fallback behavior. Tasks with a preferred assignment but no matching explicit spread remain in Inbox as `assigned, waiting for spread`. [SPRD-170]
- The global Inbox keeps one list structure, but row metadata explicitly distinguishes true `Unassigned` tasks from `Assigned: ...` waiting-for-spread tasks. In traditional mode, true Inbox-first tasks appear only in the global task browser's Inbox until assigned. [SPRD-170]
- In task create/edit UI, assignment is controlled by an explicit optional `Assign to spread` section. Creating from an explicit year/month/day spread defaults assignment on and prefilled to that spread. Creating from an explicit multiday spread defaults assignment on and prefilled to that multiday spread as a true multiday assignment. Creating from a non-spread context defaults assignment off; if the user turns it on, it prepopulates today at day granularity. Editing a true nil-assignment task follows the same assign-on prefill. [SPRD-170, SPRD-193]
- Editing an Inbox task shows `Assign to spread` on when it has a preferred assignment but no matching spread, and off only for true nil-assignment tasks. [SPRD-170]
- Clearing assignment from a task with a real current open spread assignment moves it to Inbox and converts the current open assignment into historical migrated state. Clearing assignment from a task that only had an unmaterialized preferred assignment clears preferred assignment to nil without creating migrated history. [SPRD-170]

---

## AddTaskButton Quick-Pick Popover: List and Tag (SPRD-234)

- The `AddTaskButton` native alert is replaced with a `.popover` attached to the button (`attachmentAnchor: .rect(.bounds)`, `arrowEdge: .leading`). On compact-width (iPhone) the popover automatically becomes a bottom sheet via `.presentationDetents([.height(130)])`. [SPRD-234]
- The popover contains a title header with dismiss (×) button, and a `TextField` auto-focused on appear. Submitting the field (Return key) or tapping "Add" in the keyboard toolbar saves the task and closes the popover. [SPRD-234]
- When `availableLists` is non-empty, a **List** `Menu` button appears in the keyboard `ToolbarItemGroup`; selecting an item sets it as the active list. When `availableTags` is non-empty, a **Tag** `Menu` button appears similarly (single-select). Active selections show a filled icon tinted with `SpreadTheme.Accent.todaySelectedEmphasis`. A "Clear" destructive button inside each menu resets the selection. [SPRD-234]
- `AddTaskButton.onAddTask` signature is extended to accept optional `list: DataModel.List?` and `tag: DataModel.Tag?`. All call sites updated. [SPRD-234]
- `AddTaskButton` receives `availableLists: [DataModel.List]` and `availableTags: [DataModel.Tag]` from its call site (defaulting to `[]`). When both arrays are empty the menu buttons are hidden. [SPRD-234]
- State (title, selectedList, selectedTag) is cleared on `onDisappear` so re-opening the popover starts fresh. [SPRD-234]
- This enhancement is scoped to `AddTaskButton` only — it does not apply to `EntryRowView` inline editing or `TaskCreationSheet`. [SPRD-234]
