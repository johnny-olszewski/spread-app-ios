# Entry Components

> **Status**: Draft  
> **SPRD tasks**: [SPRD-227], [SPRD-270]  
> **Session**: SESH-22, SESH-25

## Overview

This spec covers the view-layer component architecture for rendering entry status icons and the `Entry` protocol's status contract. The goal is a clean, composable rendering pipeline where `EntryStatusIcon` is a primitive renderer driven by `BaseShape`, `OverlayShape`, and optional `Config` values, while the `Entry` protocol exposes a single `status: EntryStatus` property and a `baseShape` requirement.

---

## Requirements

- `EntryStatusIcon` defines nested `BaseShape` and `OverlayShape` enums with shape-only cases. [SPRD-227]
- `EntryStatusIcon` accepts `baseShape`, optional `bseeShapeConfig`, optional `overlay`, and optional `overlayConfig`. Color and size are supplied by `Config` values and fall back to `.primary` and 12.0pt. [SPRD-227]
- Status presentation helpers expose `overlayShape` and `iconColor`; entry type presentation exposes `statusIconBaseShape`. [SPRD-227]
- `EntryIconFactory.swift` is deleted. Its switch logic is absorbed into `EntryStatusIcon`. [SPRD-227]
- `EntryIconSize` is deleted. Call sites that previously used it to convert `Font.TextStyle` to points switch to raw `CGFloat` literals. [SPRD-227]
- `rowIconColor` is removed from `EntryRowView`. `EntryRowView` renders `EntryStatusIcon` directly from `entry.baseShape` and the effective row status config. [SPRD-227]
- `TaskDetailSheet` renders its title status icon with an inline button containing `EntryStatusIcon`; no shared wrapper component is used. [SPRD-227]
- The `.slash` overlay's `frameSize` is enlarged (centered, no alignment change) so it visually extends past the base circle's edges on both ends, matching the "extends beyond the circle" look `.arrowRight` already has — a configuration-only change to existing `EntryStatusIcon.overlayView` values, with no new shapes, enums, or view types. [SPRD-270]

### Entry protocol — single status property

- The `Entry` protocol replaces `displayTaskStatus: DataModel.Task.Status?`, `displayNoteStatus: DataModel.Note.Status?`, and `displayEventStatus: DataModel.Event.Status?` with a single requirement: `var status: EntryStatus { get }`. [SPRD-227]
- `Entry` conforms to `EntryStatusIconRepresentable`, which requires `var baseShape: EntryStatusIcon.BaseShape { get }`. [SPRD-227]
- The existing extension default `status` property on `Entry` is removed; `status` becomes a first-class protocol requirement. [SPRD-227]
- `DataModel.Task.status`, `DataModel.Note.status`, and `DataModel.Event.status` satisfy the shared `EntryStatus` requirement. [SPRD-227]
- `DataModel.Task`, `DataModel.Event`, and `DataModel.Note` expose `.filledCircle`, `.emptyCircle`, and `.dash` base shapes respectively. [SPRD-227]
- `DataModel.Task+DisplayHelpers.swift` has only its `displayTaskStatus` line removed; the file stays since it also contains `bodyPreview`, `dueDateLabel`, `isDueDateHighlighted`, `displayBodyPreview`, `displayPriority`, and `displayTagChips`. [SPRD-227]
- `DataModel.Note+Display.swift` is deleted (its only content was `displayNoteStatus`). [SPRD-227]
- `DataModel.Event+Display.swift` is deleted (its only content was `displayEventStatus`). The `status` computed property for `DataModel.Event` moves to `DataModelSchemaV1.swift` or a new `DataModel.Event+Entry.swift` extension. [SPRD-227]
- View and configuration code that currently uses `entry.displayTaskStatus`, `entry.displayNoteStatus`, or `entry.displayEventStatus` for typed status comparisons switches to casting the entry to its concrete type (e.g. `(entry as? DataModel.Task)?.status == .open`). [SPRD-227]
- The `displayPriority`, `displayTagChips`, `displayBodyPreview`, and `iconColor` properties on `Entry` are out of scope and unchanged. [SPRD-227]

---

## Design Decisions

### Decision: Shape and configuration are separate

- **Context**: `EntryStatusIcon` previously mixed shape selection with color and size data.
- **Decision**: `BaseShape` and `OverlayShape` are shape-only enums. `Config` carries optional color and size for base and overlay rendering.
- **Rationale**: Shape identity stays stable and easy to compare, while visual styling stays explicit at call sites.
- **SPRD reference**: SPRD-227

### Decision: Overlay color and size are independently configurable

- **Context**: Overlays usually share the base icon color and size, but the renderer should not depend on that assumption.
- **Decision**: `overlayConfig` is separate from `bseeShapeConfig`; callers can pass the same config for both or override one independently.
- **Rationale**: The common case stays straightforward while allowing future overlay-specific styling.
- **SPRD reference**: SPRD-227

### Decision: `CGFloat?` (not `Font.TextStyle?`) for size associated values

- **Context**: The original `EntryStatusIcon.size` was `Font.TextStyle`, converted to points via `EntryIconSize`. Options were to keep the semantic type or move to raw points.
- **Decision**: Raw `CGFloat?` in `EntryStatusIcon.Config`. `EntryIconSize` is deleted.
- **Rationale**: Callers that need a specific size already know the point value in context. The `Font.TextStyle → CGFloat` conversion added indirection without benefit once size moved out of `EntryStatusIcon`'s top-level API.
- **SPRD reference**: SPRD-227

### Decision: `EntryIconFactory` absorbed into `EntryStatusIcon`, not kept as a separate type

- **Context**: `EntryIconFactory` was a `@MainActor enum` in `Views/Components/` whose sole job was switching on `(baseShape, overlay)` tuples. With `BaseShape` and `Overlay` nested inside `EntryStatusIcon`, the factory's switch logic moves directly into the view.
- **Decision**: Delete `EntryIconFactory.swift`. The switch lives in `EntryStatusIcon.body`.
- **Rationale**: One fewer file, one fewer indirection. `EntryStatusIcon` is small enough to own its own construction logic.
- **SPRD reference**: SPRD-227

---

### Decision: Single `status` property on `Entry` protocol

- **Context**: The `Entry` protocol previously exposed three optional typed accessors (`displayTaskStatus`, `displayNoteStatus`, `displayEventStatus`) to let views determine which kind of entry they were dealing with.
- **Decision**: `status: EntryStatus` becomes the single protocol requirement. The three typed display accessors are removed.
- **Rationale**: One status property per type keeps row rendering and accessibility logic consistent.
- **SPRD reference**: SPRD-227

### Decision: Typed status comparisons use casts at the call site, not new protocol properties

- **Context**: Once the typed display accessors are gone, view and configuration code that compares status to specific cases (e.g. `== .open`, `== .cancelled`) needs an alternative. Options were: add semantic bool properties to the icon presentation contract, move comparisons into `Configuration` closures only, or use the unified `EntryStatus`.
- **Decision**: Cast at the call site — `(entry as? DataModel.Task)?.status == .open`.
- **Rationale**: Business logic comparisons belong at the call site where the concrete type or shared status is already known contextually.
- **SPRD reference**: SPRD-227

---

---

## EntryRowView Architecture (SESH-22)

### EntryRowView.Configuration

`EntryRowView` is a type-blind renderer. All entry-type-specific logic lives in `Configuration` closures and `Action` cases supplied by the call site. The view has no concrete-type knowledge.

**Closure properties:**

| Property | Type | Purpose |
|---|---|---|
| `isGreyedOut` | `((any Entry) -> Bool)?` | Returns whether the row text renders at secondary opacity |
| `hasStrikethrough` | `((any Entry) -> Bool)?` | Returns whether the title renders with strikethrough |
| `dueDateLabel` | `((any Entry) -> String?)?` | Returns a due date string for display |
| `isDueDateHighlighted` | `((any Entry) -> Bool)?` | Returns whether the due date renders highlighted |
| `subtitle` | `((any Entry) -> String?)?` | Returns an optional subtitle beneath the title |
| `onStatusIconTap` | `((any Entry) -> Void)?` | Called when the leading status icon is tapped; nil disables the button |
| `onTitleCommit` | `(@MainActor (any Entry, String) async -> Void)?` | Called when the user submits a title edit |
| `showAlert` | `((SpreadsCoordinator.AlertDestination) -> Void)?` | Routes alert presentation to the owning coordinator |

**Action cases** (rendered in context menu and keyboard toolbar):

| Case | Associated value | Rendered as |
|---|---|---|
| `.openEdit(onTapEditButton:)` | `(any Entry) -> Void` | Edit button (pencil icon) |
| `.migrate(migrationOptions:onMigrationSelected:)` | options closure + async selection handler | Migrate menu |
| `.delete(deleteEntry:)` | `(any Entry) async -> Void` | Delete button (trash icon), triggers `deleteEntryConfirmation` alert |

### EntryStatus additions

- `displayName: String` — human-readable name; moved from `EntryStatusPresentation` to `EntryStatus` directly.
- `rotate(in options: [EntryStatus]) -> EntryStatus` — returns the next status in the options array, wrapping around. Used by the status icon tap handler to cycle through `[.open, .complete, .cancelled]`.
- `inlineChangesAreLocked: Bool` — `false` for `.open` and `.active`; `true` for all terminal statuses. Controls `TextField.disabled` state so users cannot edit titles on completed/cancelled/migrated entries.

### Status icon tap behavior

Tapping the leading status icon on a task row rotates the status through `[.open, .complete, .cancelled]`. This is intentional — all three user-editable statuses are reachable from the row without opening the task sheet.

### Inline title editing

The `TextField` is always present in the layout (no `isInlineActive` mode switch). Editing is gated by `entry.status.inlineChangesAreLocked`. When a toolbar action fires while the title has unsaved edits, `confirmChanges(_:)` checks whether there are actual pending changes:
- **No changes**: calls `completion()` directly, no alert.
- **Has changes**: presents `SpreadsCoordinator.AlertDestination.discardChanges` to let the user save or discard before the action runs.

`isConfirmingChanges` is a `@State` flag that prevents the `onChange(of: isTitleFocused)` observer from resetting `editingText` when focus is lost as part of the confirmation flow. It is reset in all three exit paths of `confirmChanges`.

### Alert routing

All alerts (spread delete, entry delete, discard title changes) are handled by a single `.alert(item:)` modifier on `RootNavigationView` bound to `spreadsCoordinator.activeAlert`. Previously, spread-related alerts were handled in `SpreadContentPagerView`; they were lifted to `RootNavigationView` in SESH-22 so the entry-row delete and discard-changes alerts could be routed through the same coordinator without threading a separate alert binding into each row.

### Note row configuration

`standardNoteConfig` provides `.openEdit` (opens the note detail sheet) and `.delete` (triggers the `deleteEntryConfirmation` alert) actions, matching the task row pattern. Notes do not have a status icon tap handler — the leading icon is display-only.

---

### Decision: `.slash` mirrors `.xmark`'s shape/configuration structure, not a standalone frameSize tweak

- **Context**: `.arrowRight` (the `.migrated` overlay) already reads as "extending beyond the circle" — its `frameSize` is `CGSize(width: s * 2, height: s)` with `overlayAlignment == .leading`, so the arrow starts at the base shape's center and pokes out past its trailing edge. The user wants `.slash` (the `.cancelled` overlay, originally `frameSize: CGSize(width: s * 1.1, height: s * 1.1)`, centered, fully contained within the circle) to read the same way. A first pass (since superseded) just grew `.slash`'s own `frameSize` multiplier in isolation (`s * 2.2`). The user then asked explicitly for component reuse: make `SlashShape` structurally match `XMarkShape` (centered-in-rect, scaled by an `armLength` parameter, single arm) and configure `.slash` in `EntryStatusIcon` exactly like `.xmark` already is.
- **Decision**: `SlashShape` (in `johnnyo-foundation`) now takes an `armLength: CGFloat` and draws one diagonal arm from top-right to bottom-left, centered on `rect.midX`/`rect.midY` — the same shape-construction pattern `XMarkShape` already uses (it draws two such arms via one continuous `Path` for `.trim` animation; `SlashShape` only needs one). `EntryStatusIcon.overlayView`'s `.slash` case now computes `decoratorSize`/`armLength` with the **identical formula** `.xmark` uses (`decoratorSize = s * (1 + 2 * 0.35)`, `armLength = decoratorSize * 0.6`, `frameSize = decoratorSize²`) — `overlayAlignment` stays `.center` (a slash, like an X mark, has no inherent direction). `.slash`'s own `strokeStyle`/`animationDuration` values are unchanged (still distinct from `.xmark`'s, since those are legitimately different visual weights/timings, not part of what needed to match).
- **Rationale**: This is the literal "reuse the same component structure" outcome — `SlashShape` and `XMarkShape` are now the same kind of shape (centered, `armLength`-scaled), and `.slash`'s configuration block in `EntryStatusIcon` is now line-for-line structurally identical to `.xmark`'s, differing only in which `Shape` type and stroke values are passed in. No new types, alignment cases, or one-off magic numbers were introduced.
- **SPRD reference**: SPRD-270

## Open Questions

- `EntryStatusIconRepresentable` returns `EntryStatusIcon.BaseShape`, coupling model-layer conformances to a view-nested type. If `EntryStatusIcon` is ever renamed, all conformances break. Consider whether `BaseShape` and `OverlayShape` should be top-level types in a future cleanup pass.
