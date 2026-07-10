# Entry Editing Sheets

> **Status**: Draft  
> **SPRD tasks**: SPRD-277, SPRD-278, SPRD-279, SPRD-280, SPRD-281, SPRD-282, SPRD-291, SPRD-292, SPRD-293, SPRD-294  
> **Session**: SESH-## (consolidation), SESH-27 (visual redesign)

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

### Visual Redesign (SESH-27)

- A shared sheet-native selection vocabulary is built on `SpreadButton`: a single-select **choice row** (all options visible inline, `.tonal` = selected / `.plain` = unselected, Phosphor icon per option where applicable), a **chip cloud** (wrapping single- or multi-select chips), and an **add/remove chip** for optional fields. Stock `Picker(.menu)`, `Menu`-over-summary-row, `DisclosureGroup`, and field-level `Toggle` controls are eliminated from entry sheet content. [SPRD-291]
- `EntrySheet`'s chrome is replaced with a custom in-sheet header: title in `SpreadTheme.Typography.largeTitle` (Fuzzy Bubbles) on the leading edge, Cancel (`.plain`) and Create/Save (`.prominent`, small) as `SpreadButton`s trailing. The `NavigationStack` nav bar/toolbar chrome is dropped. This supersedes the SPRD-216 nav-title/toolbar convention for entry sheets (DesignSystem.md amended accordingly); the SPRD-216 rules for loading-disabled primary action, error feedback, and `interactiveDismissDisabled` still apply. [SPRD-291]
- Section headers use `SpreadTheme.Typography.title3` (Mulish), matching content-surface section headers ("Year", "Month"), replacing the caption-sized `EntrySheetSectionHeader`. [SPRD-291]
- `TaskEntrySheet` section order mirrors the entry row: Title (with status, edit mode) → Priority → Due date → List → Tags → Notes → Assignment. [SPRD-292]
- Priority renders as a choice row using the SPRD-288 priority icons and colors (red `caretDoubleUp` high, yellow `caretUp` medium, green `caretDoubleDown` low). [SPRD-292]
- Due date is an add/remove chip; when set, the date is picked via `CalendarView` — no native `DatePicker` or `Toggle`. [SPRD-292]
- List and Tags render as chip clouds; a "+ New" chip swaps inline for a `TextField` to create a new List/Tag in place (new item appears selected). The system `alert`-based creation flow is removed. [SPRD-292]
- Notes (body) is an always-visible section with the `TextEditor` on a `SpreadTheme.Paper.secondary` surface — no `DisclosureGroup`. [SPRD-292]
- Assignment starts with a two-state chip pair (unassigned vs. assigned; exact labels resolved during implementation against `periodDescription` wording) replacing the "Assign to spread" `Toggle`. Selecting the assigned state reveals: period choice row → date selection. [SPRD-292]
- Spread selection is embedded in the date `CalendarView` rather than a separate "Select from existing spreads" launcher: day cells with existing spreads render in a distinct color, multiday spreads render as coverage bars (reusing the `SpreadsNavigatorView`/`RowOverlayGenerator` visual vocabulary), and tapping a covered date selects that spread. The `SpreadPickerView` sheet-on-sheet hop is removed from entry sheets. Multiday assignment remains restricted to existing spreads in this phase. [SPRD-292]
- In edit mode, a status choice row (Open / Complete / Cancelled, using `EntryStatusIcon` colors) replaces both the non-interactive title-row status icon and the bottom lifecycle section; invalid transitions are disabled, not hidden; migrated status renders as a non-selectable informational chip. [SPRD-292]
- `NoteEntrySheet` and `SpreadNameEntrySheet` migrate onto the same vocabulary (shared components, same header chrome, same section-header treatment); the Spread sheet's dynamic-name `Toggle` is restyled consistently with the sheet's chip idiom. [SPRD-293]
- Multiday free-range selection: picking a start and end date on the calendar where no multiday spread exists implicitly creates the spread on save; a range matching an existing spread selects it instead; cancelling the sheet creates nothing. [SPRD-294]
- All existing accessibility identifiers are preserved across the redesign so current UI tests keep passing; every new component ships with multi-state previews; verification is manual visual QA per sheet, both modes, both color schemes — no new unit tests for the visual tasks. [SPRD-291, SPRD-292, SPRD-293]

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

### Decision: One selection idiom — inline SpreadButton rows, not menus

- **Context**: The consolidated sheets still used stock form controls (`Picker(.menu)`, `Menu` over `EntrySheetSelectionSummaryRow`, segmented control, `DisclosureGroup`, `Toggle`), while the rest of the app had developed its own vocabulary (`SpreadButton` styles, Phosphor icons, chip strips like the navigator's context buttons). Priority even ignored its own SPRD-288 icons/colors.
- **Decision**: Every single-choice field (priority, period, status) uses an inline choice row of `SpreadButton`s — all options visible, `.tonal` selected / `.plain` unselected. Multi-select and dynamic collections (list, tags) use chip clouds. No menus, no segmented controls, no disclosure groups in sheet content.
- **Rationale**: One idiom everywhere; selected state is visible without a tap; matches the "two elements over one conditional element" and SpreadButton conventions already in `CLAUDE.md`/DesignSystem. Vertical cost is acceptable because option counts are small (3–4).
- **SPRD reference**: SPRD-291, SPRD-292

### Decision: Spread selection embedded in the calendar, replacing SpreadPickerView

- **Context**: Assigning to an existing spread required a separate "Select from existing spreads" launcher opening `SpreadPickerView` — a sheet-on-sheet hop, disconnected from the date picking happening in the same section.
- **Decision**: The date `CalendarView` itself communicates spread existence — colored day cells for day spreads, coverage bars for multiday spreads (same `RowOverlayGenerator` vocabulary as `SpreadsNavigatorView`) — and tapping covered dates selects the spread. The launcher and the `SpreadPickerView` hop are removed.
- **Rationale**: Formatting can carry the created/uncreated distinction (user-directed); one surface answers "when" and "where" together; reuses an already-built visual language instead of a parallel picker UI.
- **SPRD reference**: SPRD-292

### Decision: Chip pairs replace Toggles; status row replaces the lifecycle section

- **Context**: "Assign to spread" was a `Toggle` hiding three sub-sections; status was displayed as a dead icon (a `Button` with `allowsHitTesting(false)`) while actual status changes lived in a separate bottom lifecycle section ("Cancel Task"/"Restore Task").
- **Decision**: Assignment becomes a two-state chip pair (unassigned/assigned) that reveals period → date when assigned. Status becomes a choice row (Open/Complete/Cancelled) in the edit sheet, replacing both the dead icon and the lifecycle section; invalid transitions are disabled rather than hidden.
- **Rationale**: Both were the last stock/duplicated controls; the chip-pair form makes the on/off state a first-class visible choice, and status editing stops being split across two locations.
- **SPRD reference**: SPRD-292

### Decision: Custom sheet header supersedes the SPRD-216 nav-bar convention

- **Context**: SPRD-216 standardized sheets on system nav titles with leading-Cancel/trailing-primary toolbar items. That convention predates the design-system vocabulary (Fuzzy Bubbles `largeTitle`, `SpreadButton`); system toolbar items can't adopt either cleanly.
- **Decision**: Entry sheets drop the nav bar for an in-sheet header row: Fuzzy Bubbles title leading, `.plain` Cancel and `.prominent` Create/Save `SpreadButton`s trailing. SPRD-216's behavioral rules (primary disabled while busy, error alerts, `interactiveDismissDisabled`) are retained; only the chrome placement rule is superseded, and `DesignSystem.md` is amended in the same change.
- **SPRD reference**: SPRD-291

### Decision: Implicit multiday spread creation is a separate follow-up task

- **Context**: Free start/end range picking implies assigning to a multiday spread that doesn't exist yet, but today the form model requires an existing spread for multiday (`selectedSpreadID` must be non-nil to save), and only the spread-creation flow has spread-creation authority (with auto-migration side effects).
- **Decision**: The redesign (SPRD-292) keeps multiday restricted to existing spreads, selected via coverage bars. Free-range picking with implicit spread creation is specced as its own task (SPRD-294) landing after the visual work.
- **Rationale**: Keeps the visual redesign behavior-neutral and bisectable; spread-creation-from-entry-sheet is a real behavior change deserving its own review (naming, cancel semantics, migration side effects).
- **SPRD reference**: SPRD-292, SPRD-294

### Decision: Task split — vocabulary, Task sheet, sibling sheets, then behavior

- **Context**: The redesign touches a shared shell, several new components, and three sheets.
- **Decision**: Four tasks: SPRD-291 (shared components + shell chrome), SPRD-292 (`TaskEntrySheet`), SPRD-293 (`NoteEntrySheet` + `SpreadNameEntrySheet`), SPRD-294 (multiday implicit creation). SPRD-291's shell chrome change affects all three sheets at once since the shell is shared.
- **Rationale**: Mirrors the SPRD-277–282 structure that worked for the consolidation — each task independently reviewable and bisectable; the hardest sheet (Task) doesn't block the simpler migrations.
- **SPRD reference**: SPRD-291, SPRD-292, SPRD-293, SPRD-294

---

## Open Questions

- Should the generalized form-model abstraction be a protocol with associated types, or a single concrete struct/class with optional fields per entry type? Left to the implementer to decide during SPRD-278, weighing it against the "no namespace enums as factory containers" / "structs by default" guidance in `CLAUDE.md`.
- Should `OldUI_ReferenceOnly/Creation/SpreadCreationSheet.swift` be deleted once `SpreadNameEditSheet`'s replacement covers spread creation, or does it stay as reference-only indefinitely? Resolve during SPRD-281 once the new Spread `EntrySheet` config's coverage is confirmed.
- Exact labels for the assignment chip pair ("Unassigned"/"Assigned" vs. "Inbox"/"On a spread") — resolve during SPRD-292 against how `periodDescription` and inbox eligibility describe the unassigned state.
- How the auto-created multiday spread is named in SPRD-294 (dynamic name only, or prompt for a custom name) — resolve when speccing the SPRD-294 implementation details.
