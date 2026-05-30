# Entry Components

> **Status**: Draft  
> **SPRD tasks**: [SPRD-227]  
> **Session**: SESH-22

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

## Open Questions

- `EntryStatusIconRepresentable` returns `EntryStatusIcon.BaseShape`, coupling model-layer conformances to a view-nested type. If `EntryStatusIcon` is ever renamed, all conformances break. Consider whether `BaseShape` and `OverlayShape` should be top-level types in a future cleanup pass.
