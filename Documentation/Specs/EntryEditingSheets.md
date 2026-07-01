# Entry Editing Sheets

> **Status**: Draft  
> **SPRD tasks**: SPRD-277, SPRD-278, SPRD-279, SPRD-280, SPRD-281, SPRD-282  
> **Session**: SESH-##

## Overview

Task creation/edit, Note creation/edit, and Spread name/creation are each implemented as a pair (or singleton) of near-duplicate SwiftUI sheets: `TaskCreationSheet`/`TaskDetailSheet`, `NoteCreationSheet`/`NoteDetailSheet`, and `SpreadNameEditSheet` (plus the old-UI-only `SpreadCreationSheet` reference). Each pair shares the bulk of its body (title, metadata, details, assignment/period/date sections) but is fully duplicated as a separate `View` + `ViewModel`, differing only in create-vs-edit chrome (toolbar action, auto-focus, lifecycle/status section, assignment history, delete). This area consolidates all of these into one generic, mode-driven `EntrySheet` family so a new entry type (or a future Event-editing sheet) can be added by supplying configuration rather than copy-pasting a ~400-line view. It also replaces native `DatePicker`/`PeriodDatePicker` UI with `johnnyo-foundation`'s `CalendarView` for day/multiday period selection.

---

## Requirements

- A single generic `EntrySheet` (or equivalently-named) view drives both creation and edit flows for Tasks, Notes, and Spreads, replacing `TaskCreationSheet`, `TaskDetailSheet`, `NoteCreationSheet`, `NoteDetailSheet`, and `SpreadNameEditSheet`. [SPRD-279, SPRD-280, SPRD-281]
- A `Mode` enum (`.create` / `.edit`) toggles section/toolbar visibility: delete section, assignment history, and lifecycle actions render only in `.edit`; auto-focus-on-appear and the "hidden until first edit" Create button visibility rule apply only in `.create`. [SPRD-279]
- Per-entry-type section configuration determines which sections render (title, content/body, metadata with priority, due date, list/tags, spread/period/date assignment, assignment history, lifecycle, delete) so Task, Note, and Spread reuse the same shell without entry-type-specific branching inside the shell itself. [SPRD-279, SPRD-280, SPRD-281]
- Shared visual chrome (section header, compact divider, validation error row, loading overlay, selection summary row) is extracted into standalone reusable components instead of being copy-pasted per sheet. [SPRD-277]
- `TaskEditorFormModel` is generalized (or paired with an equivalent abstraction) so Notes drive the same shell through a comparable form-model surface, rather than Notes keeping a parallel, independently-maintained set of `@Observable` properties. [SPRD-278]
- Day/multiday date selection inside entry sheets uses `johnnyo-foundation`'s `CalendarView` instead of `PeriodDatePicker`'s native `DatePicker`-backed UI; year/month period selection may keep a distinct lightweight picker since `CalendarView` is a month-grid view. [SPRD-282]
- No regression in existing Task/Note/Spread creation, editing, validation, or deletion behavior — including accessibility identifiers, which existing UI tests depend on.

---

## Design Decisions

### Decision: Spreads are unified under the same `EntrySheet` shell, not a separate lighter sheet

- **Context**: Spreads (`SpreadNameEditSheet`, and the old-UI-only `SpreadCreationSheet`) don't have a title/body/assignment model the way Tasks and Notes do — they're a much smaller editorial surface (custom name + dynamic-name toggle).
- **Decision**: Rather than keeping Spread editing as a separate, lighter sheet that merely reuses shared visual components, `EntrySheet`'s configuration is generalized far enough that Spread naming/creation is expressed as just another section-configuration variant (e.g. a config with only a "name" section and no title/body/assignment sections at all).
- **Rationale**: User chose full unification over a split shell + shared-components approach, to maximize the long-term payoff of "scalable and adaptable" entry-sheet infrastructure as new entry types are added (e.g. a future Event editing sheet). This raises the bar on how generic the section-configuration model must be (it must support a sheet with almost nothing in it), which SPRD-281 must account for explicitly.
- **SPRD reference**: SPRD-279, SPRD-281

### Decision: CalendarView swap lands as its own task, after the structural migrations

- **Context**: The shell/form-model refactor (structural) and the native-picker-to-`CalendarView` swap (visual/UX) are two independently risky changes.
- **Decision**: The `CalendarView` swap is a separate task (SPRD-282) that lands last, after Task, Note, and Spread sheets are already migrated onto the unified `EntrySheet` shell.
- **Rationale**: Keeps each change independently bisectable — if a regression appears after this work lands, it's possible to tell whether the shell migration or the calendar swap caused it, rather than diagnosing one large combined diff.
- **SPRD reference**: SPRD-282

### Decision: Form-model generalization precedes shell construction

- **Context**: `TaskEditorFormModel` already centralizes Task creation/edit form state; Notes currently duplicate equivalent state directly as `@Observable` properties on each Note sheet's `ViewModel`.
- **Decision**: Generalize the form-model abstraction (SPRD-278) before building the generic `EntrySheet` shell (SPRD-279), so the shell can be designed against one real shared form-model interface from the start instead of being retrofitted afterward.
- **Rationale**: Building the shell first against only `TaskEditorFormModel` risks baking in Task-specific assumptions (e.g. `priority`, `dueDate` as required fields) that don't generalize cleanly to Notes or Spreads.
- **SPRD reference**: SPRD-278, SPRD-279

---

## Open Questions

- Should the generalized form-model abstraction be a protocol with associated types, or a single concrete struct/class with optional fields per entry type? Left to the implementer to decide during SPRD-278, weighing it against the "no namespace enums as factory containers" / "structs by default" guidance in `CLAUDE.md`.
- Should `OldUI_ReferenceOnly/Creation/SpreadCreationSheet.swift` be deleted once `SpreadNameEditSheet`'s replacement covers spread creation, or does it stay as reference-only indefinitely? Resolve during SPRD-281 once the new Spread `EntrySheet` config's coverage is confirmed.
