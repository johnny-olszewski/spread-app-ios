# Task Browser

> **Status**: Draft
> **SPRD tasks**: SPRD-221, SPRD-222, SPRD-223, SPRD-224
> **Session**: SESH-21

## Overview

The Task Browser is a dedicated tab that replaces the existing Search tab (SPRD-148). It provides a comprehensive view of all tasks across all spreads in one place, organized by lifecycle state and enriched with two new organizational fields — List and Tags — that allow users to group and filter tasks by domain ("Work", "Home") and project/theme ("EOY Presentation", "Baby Preparation"). The tab surfaces the full task lifecycle: Inbox tasks first, then open assigned tasks ordered chronologically by spread, then completed and cancelled tasks below ordered by when they were resolved.

---

## Requirements

### List and Tag Models

- A `List` is a first-class SwiftData `@Model` entity with a name and an ordered relationship to tasks and notes. [SPRD-221]
- A `Tag` is a first-class SwiftData `@Model` entity with a name and a many-to-many relationship to tasks and notes. [SPRD-221]
- `DataModel.Task` gains an optional `list` relationship (one `List` or nil) and an optional `tags` relationship (zero or more `Tag`s). [SPRD-221]
- `DataModel.Note` gains the same optional `list` and `tags` relationships for model parity, though Notes do not appear in the Task Browser tab. [SPRD-221]
- List and Tag are synced entities with the same outbox/revision/tombstone architecture as other SwiftData models. [SPRD-221]
- A List name and Tag name must be non-empty strings, trimmed on save. [SPRD-221]
- Intended semantics: a List is a broad domain grouping (e.g. "Work", "Home", "Personal"); a Tag is a specific project or theme (e.g. "Garage Reorganization", "Baby Preparation", "EOY Presentation"). A task belongs to at most one List but may have multiple Tags. [SPRD-221]

### Tasks Tab

- The Tasks tab replaces the Search tab in the tab bar. [SPRD-222]
- The tab is labeled "Tasks" with an appropriate SF Symbol icon. [SPRD-222]
- The tab uses `EntryList` for row rendering, consistent with spread entry lists. [SPRD-222]
- A `.searchable` search bar is embedded in the tab, filtering tasks by title and body text in real time. [SPRD-222]
- The tab displays two sections: **Open** (top) and **Completed / Cancelled** (bottom). Neither section is collapsible. [SPRD-222]
- The **Open** section orders tasks as follows: [SPRD-222]
  1. Inbox tasks (no preferred assignment) — ordered by `createdDate` ascending.
  2. Assigned open tasks — ordered by preferred spread's normalized date ascending, with period as a tiebreaker (day before month before year within the same date), then by `createdDate` ascending within identical date+period.
- The **Completed / Cancelled** section shows tasks with status `complete` or `cancelled`, ordered by the current assignment's `statusUpdatedAt` descending (most recently resolved first). Falls back to `createdDate` descending when `statusUpdatedAt` is nil. [SPRD-222]
- The tab respects the active search query and active List/Tag filters simultaneously. [SPRD-222]

### List and Tag Filtering

- The Tasks tab exposes filter chips (or equivalent compact controls) for List and Tags. [SPRD-222]
- Selecting a List filter shows only tasks belonging to that List. [SPRD-222]
- Selecting one or more Tag filters shows tasks that have ANY of the selected tags (OR within tags). [SPRD-222]
- When both a List filter and Tag filters are active, results must match the List AND have at least one of the selected Tags (AND across types). [SPRD-222]
- An active search query applies on top of any active filters. [SPRD-222]
- No filter is selected by default; the tab shows all tasks. [SPRD-222]

### List and Tags Management Sheet

- The Tasks tab provides a button or menu action to open a List and Tags management sheet. [SPRD-223]
- The sheet presents a navigation stack. The root level shows two sections: Lists and Tags, each displaying all existing List/Tag names and their task counts. [SPRD-223]
- Tapping a List or Tag navigates to a detail screen showing its name (editable inline) and the count of tasks assigned to it. [SPRD-223]
- From the detail screen, the user can rename the List or Tag. The new name must be non-empty and trimmed. [SPRD-223]
- From the detail screen, the user can delete the List or Tag. [SPRD-223]
- Deleting a List or Tag nils out that field on all affected tasks (and notes, for model parity). The List or Tag entity itself is then deleted. [SPRD-223]
- The delete confirmation dialog states the List or Tag name and the count of affected tasks (e.g. "Deleting 'Work' will remove it from 12 tasks. This cannot be undone."). [SPRD-223]
- Deletion proceeds only after the user confirms. [SPRD-223]

### List and Tags in Entry Create/Edit

- The task create/edit sheet gains a List picker (select one List or none) and a Tags picker (select zero or more Tags). [SPRD-224]
- The note create/edit sheet gains the same List and Tags pickers for model parity, even though Notes are not displayed in the Task Browser. [SPRD-224]
- Both pickers allow creating a new List or Tag inline without leaving the create/edit sheet. [SPRD-224]
- The List and Tags fields remain editable when a task is complete or cancelled, consistent with the existing pattern for body, priority, and due date. [SPRD-224]

---

## Design Decisions

### Decision: List and Tag as first-class models (not string fields)

- **Context**: Organizational fields could be stored as plain strings (e.g. `list: String?`, `tags: [String]`) or as relationships to typed model entities.
- **Decision**: First-class SwiftData `@Model` types with named relationships.
- **Rationale**: String fields produce drift over time (duplicate spellings, case mismatches). First-class models enable centralized rename/delete from the management sheet and make task-count queries straightforward. The management sheet requirement makes a relational model clearly superior.
- **SPRD reference**: SPRD-221

### Decision: List is one-to-many, Tags is many-to-many

- **Context**: Should a task be allowed to belong to multiple Lists?
- **Decision**: A task belongs to at most one List. A task may have zero or more Tags.
- **Rationale**: A List is a domain bucket (Work, Home) — the intent is mutually exclusive membership. Tags are cross-cutting project or theme labels where overlap is expected and useful. This mirrors the semantics of tools like Reminders and Things.
- **SPRD reference**: SPRD-221

### Decision: Notes get List/Tags for model parity but are not shown in the Task Browser

- **Context**: Notes are `AssignableEntry` types and could logically belong to Lists or Tags. The Task Browser is task-focused and Notes do not have the same status lifecycle.
- **Decision**: Both `DataModel.Task` and `DataModel.Note` get `list` and `tags` relationships. Notes are not displayed in the Task Browser tab.
- **Rationale**: Adding the fields to Notes now avoids a schema migration later if Notes are surfaced in a broader browser. Keeping them out of the tab keeps the lifecycle model (open/complete/cancelled ordering) clean.
- **SPRD reference**: SPRD-221, SPRD-222

### Decision: List/Tag deletion nils out task associations, confirmed with task count

- **Context**: When a List or Tag is deleted, tasks that referenced it need a defined outcome.
- **Decision**: Deletion nils out the `list` or `tags` field on all affected tasks and notes, then deletes the entity. A confirmation dialog shows the affected task count before proceeding.
- **Rationale**: Deleting an organizational label should never cascade-delete content. Showing the count gives users informed consent without requiring a reassignment flow, which is v1 overkill.
- **SPRD reference**: SPRD-223

### Decision: Filtering uses AND across types, OR within Tags

- **Context**: When a List filter and Tag filters are both active, results must satisfy both (AND) or either (OR).
- **Decision**: AND across List and Tags (task must match the selected List AND have at least one selected Tag). OR within multiple selected Tags (task needs any one of the selected Tags, not all).
- **Rationale**: This is the standard pattern in productivity apps (Reminders, Notion). AND across types narrows results meaningfully. OR within tags is more natural — selecting "Baby Preparation" and "EOY Presentation" should mean "show me tasks about either project," not tasks that are simultaneously about both.
- **SPRD reference**: SPRD-222

### Decision: Inbox tasks appear at the top of the Open section

- **Context**: Inbox tasks have no preferred assignment date and therefore no natural position in a date-ordered list.
- **Decision**: Inbox tasks (nil preferred assignment) appear first within the Open section, ordered among themselves by `createdDate` ascending.
- **Rationale**: Inbox tasks represent unprocessed work that needs attention. Surfacing them at the top mirrors the existing Inbox-first emphasis in the spread navigation and encourages the user to process them.
- **SPRD reference**: SPRD-222

### Decision: Tasks tab is mode-agnostic

- **Context**: The app has two modes — Conventional (explicit user-created spreads) and Traditional (calendar-driven implicit spreads). The question was whether the Tasks tab should behave differently per mode.
- **Decision**: The Tasks tab behaves identically in both modes. No mode-specific branching.
- **Rationale**: The underlying data model is identical across modes — tasks store the same preferred date and period regardless of mode. The tab's ordering logic works correctly either way without any adaptation. Restricting the tab to Conventional mode would unnecessarily penalize Traditional mode users.
- **SPRD reference**: SPRD-222

### Decision: Filters behind a toolbar button with active-state badge

- **Context**: List and Tag filters needed a home on the Tasks tab without cluttering the default view.
- **Decision**: A single filter button (e.g. `line.3.horizontal.decrease.circle`) in the nav bar toolbar. Tapping opens a filter sheet where the user selects a List and/or Tags. When one or more filters are active, the button displays a badge or filled variant to indicate the filtered state.
- **Rationale**: Keeps the default task list uncluttered. Scales gracefully as Lists and Tags grow in number. The active-state badge provides clear feedback that results are filtered without requiring the sheet to be open. Consistent with the iOS Reminders pattern for tag filtering.
- **SPRD reference**: SPRD-222

### Decision: Management accessible from within the filter sheet

- **Context**: The management sheet (rename/delete for Lists and Tags) needed a trigger point in the Tasks tab UI.
- **Decision**: The filter sheet includes a "Manage Lists & Tags" row at the bottom. Tapping it pushes the management navigation stack within the same sheet presentation.
- **Rationale**: Logical grouping — the filter sheet is already where the user thinks about Lists and Tags. Adding management as a footer row there makes it discoverable without adding another toolbar button or ellipsis menu. Keeps the nav bar uncluttered.
- **SPRD reference**: SPRD-223

### Decision: Maximum of 5 Tags per task

- **Context**: Tags are meant to be focused project/theme labels. Without a limit, a task could accumulate an impractical number of tags.
- **Decision**: A task may have at most 5 Tags. The Tags picker disables adding more once the limit is reached and shows a brief inline message (e.g. "Maximum 5 tags").
- **Rationale**: 5 is generous for real-world use while keeping row display and filter UX predictable. Encourages focused tagging consistent with the intended semantics. Matches the pattern used by tools like Linear and Notion in early tag implementations.
- **SPRD reference**: SPRD-224
