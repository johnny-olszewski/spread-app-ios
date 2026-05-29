# Entry Components

> **Status**: Draft  
> **SPRD tasks**: [SPRD-227]  
> **Session**: SESH-22

## Overview

This spec covers the view-layer component architecture for rendering entry status icons and the `Entry` protocol's status contract. The goal is a clean, composable rendering pipeline where `EntryStatusIcon` is a primitive renderer driven entirely by `BaseShape` and `Overlay` values, `EntryStatusButton` is the protocol bridge, status types carry all rendering parameters (color, size) as associated values on their enum cases, and the `Entry` protocol exposes a single `status: any EntryStatusButtonRepresentable` property — eliminating the three separate typed display accessors (`displayTaskStatus`, `displayNoteStatus`, `displayEventStatus`).

---

## Requirements

- `EntryStatusIcon` defines two nested enums — `BaseShape` and `Overlay` — with `color: Color?` and `size: CGFloat?` as associated values on every case. [SPRD-227]
- `EntryStatusIcon` accepts `baseShape: BaseShape` and `overlay: Overlay?` as its only inputs. It coalesces color as overlay color → base shape color → `.primary`, and size as case value → 12.0pt. [SPRD-227]
- `EntryStatusButton` accepts `status: any EntryStatusButtonRepresentable`, reads `iconBaseShape` and `iconOverlay` from the protocol, and passes the resulting `BaseShape` and `Overlay?` to `EntryStatusIcon`. It has no `color` parameter of its own. [SPRD-227]
- `statusColor` is removed from the `EntryStatusButtonRepresentable` protocol. All three conformances (`DataModel.Task.Status`, `DataModel.Note.Status`, `DataModel.Event.Status`) are updated to embed color in their `iconBaseShape` return values. [SPRD-227]
- `EntryIconFactory.swift` is deleted. Its switch logic is absorbed into `EntryStatusIcon`. [SPRD-227]
- `EntryIconSize` is deleted. Call sites that previously used it to convert `Font.TextStyle` to points switch to raw `CGFloat` literals. [SPRD-227]
- `rowIconColor` is removed from `EntryRowView`. `EntryStatusButton` is called without a `color` argument; row icon color is determined by the status type's `iconBaseShape` associated value. [SPRD-227]
- Call sites that render the icon outside of `EntryStatusButton` (e.g. `TaskDetailSheet`) construct a `BaseShape` directly with their desired color rather than relying on the protocol's default. [SPRD-227]

### Entry protocol — single status property

- The `Entry` protocol replaces `displayTaskStatus: DataModel.Task.Status?`, `displayNoteStatus: DataModel.Note.Status?`, and `displayEventStatus: DataModel.Event.Status?` with a single requirement: `var status: any EntryStatusButtonRepresentable { get }`. [SPRD-227]
- The existing extension default `status` property on `Entry` is removed; `status` becomes a first-class protocol requirement. [SPRD-227]
- `DataModel.Task.status: DataModel.Task.Status` satisfies the protocol requirement via Swift's implicit existential covariance — no new property or wrapper is needed. [SPRD-227]
- `DataModel.Note.status: DataModel.Note.Status` satisfies the same requirement the same way. [SPRD-227]
- `DataModel.Event` gains a computed `var status: DataModel.Event.Status { .upcoming }` to satisfy the requirement. Its stored model data is unchanged. [SPRD-227]
- `DataModel.Task+DisplayHelpers.swift` has only its `displayTaskStatus` line removed; the file stays since it also contains `bodyPreview`, `dueDateLabel`, `isDueDateHighlighted`, `displayBodyPreview`, `displayPriority`, and `displayTagChips`. [SPRD-227]
- `DataModel.Note+Display.swift` is deleted (its only content was `displayNoteStatus`). [SPRD-227]
- `DataModel.Event+Display.swift` is deleted (its only content was `displayEventStatus`). The `status` computed property for `DataModel.Event` moves to `DataModelSchemaV1.swift` or a new `DataModel.Event+Entry.swift` extension. [SPRD-227]
- View and configuration code that currently uses `entry.displayTaskStatus`, `entry.displayNoteStatus`, or `entry.displayEventStatus` for typed status comparisons switches to casting the entry to its concrete type (e.g. `(entry as? DataModel.Task)?.status == .open`). [SPRD-227]
- The `displayPriority`, `displayTagChips`, `displayBodyPreview`, and `iconColor` properties on `Entry` are out of scope and unchanged. [SPRD-227]

---

## Design Decisions

### Decision: Associated values on `BaseShape` and `Overlay` cases for color and size

- **Context**: `EntryStatusIcon` previously accepted `status: any EntryStatusButtonRepresentable` plus separate `color` and `size` parameters. The factory (`EntryIconFactory`) switched on `(iconBaseShape, iconOverlay)` tuples to construct the icon. This spread rendering knowledge across three components.
- **Decision**: `BaseShape` and `Overlay` carry `color: Color?` and `size: CGFloat?` as associated values. `EntryStatusIcon` reads these directly — no protocol, no separate parameters.
- **Rationale**: Status types become fully self-describing for rendering. `EntryStatusIcon` is a pure, dumb renderer with no knowledge of the protocol. The component boundary is clean: the protocol bridge lives entirely in `EntryStatusButton`.
- **SPRD reference**: SPRD-227

### Decision: Overlay color and size are independent of base shape, with coalescing fallback

- **Context**: Overlays (xmark, arrow, slash) always decorated the base icon with the same color in the original implementation. Two choices: inherit from base shape, or allow independent values.
- **Decision**: `Overlay` carries its own `color: Color?` and `size: CGFloat?`. When `nil`, they fall back to the base shape's corresponding value, then to the global default (`.primary` / 12.0pt).
- **Rationale**: No current use case requires a differently-colored overlay, but the API is expressive enough to support it without ceremony. The coalescing chain (overlay → base shape → default) makes the common case require zero configuration.
- **SPRD reference**: SPRD-227

### Decision: `CGFloat?` (not `Font.TextStyle?`) for size associated values

- **Context**: The original `EntryStatusIcon.size` was `Font.TextStyle`, converted to points via `EntryIconSize`. Options were to keep the semantic type or move to raw points.
- **Decision**: Raw `CGFloat?` on all cases. `EntryIconSize` is deleted.
- **Rationale**: Callers that need a specific size already know the point value in context. The `Font.TextStyle → CGFloat` conversion added indirection without benefit once size moved out of `EntryStatusIcon`'s top-level API.
- **SPRD reference**: SPRD-227

### Decision: `EntryIconFactory` absorbed into `EntryStatusIcon`, not kept as a separate type

- **Context**: `EntryIconFactory` was a `@MainActor enum` in `Views/Components/` whose sole job was switching on `(baseShape, overlay)` tuples. With `BaseShape` and `Overlay` nested inside `EntryStatusIcon`, the factory's switch logic moves directly into the view.
- **Decision**: Delete `EntryIconFactory.swift`. The switch lives in `EntryStatusIcon.body`.
- **Rationale**: One fewer file, one fewer indirection. `EntryStatusIcon` is small enough to own its own construction logic.
- **SPRD reference**: SPRD-227

---

### Decision: Single `status` property on `Entry` protocol via existential covariance

- **Context**: The `Entry` protocol previously exposed three optional typed accessors (`displayTaskStatus`, `displayNoteStatus`, `displayEventStatus`) to let views determine which kind of entry they were dealing with. The extension default `status: any EntryStatusButtonRepresentable` derived from whichever typed accessor was non-nil. This split rendering from type identity across four properties.
- **Decision**: `status: any EntryStatusButtonRepresentable` becomes the single protocol requirement. The three typed display accessors are removed. Concrete model types satisfy the requirement directly via their existing typed `status` stored properties — no new code needed on `DataModel.Task` or `DataModel.Note`. `DataModel.Event` gains a one-line computed property.
- **Rationale**: Swift's implicit existential covariance (Swift 5.7+) allows a stored `var status: DataModel.Task.Status` to satisfy `var status: any EntryStatusButtonRepresentable` without any explicit bridging code. The result is one status property per type, one status requirement on the protocol, and zero display shim files.
- **SPRD reference**: SPRD-227

### Decision: Typed status comparisons use casts at the call site, not new protocol properties

- **Context**: Once the typed display accessors are gone, view and configuration code that compares status to specific cases (e.g. `== .open`, `== .cancelled`) needs an alternative. Options were: add semantic bool properties to `EntryStatusButtonRepresentable` (e.g. `isOpen`), move comparisons into `Configuration` closures only, or cast to the concrete type at the call site.
- **Decision**: Cast at the call site — `(entry as? DataModel.Task)?.status == .open`.
- **Rationale**: Keeps `EntryStatusButtonRepresentable` as a pure rendering protocol. Business logic comparisons belong at the call site where the concrete type is already known contextually. Adding `isOpen`, `isCancelled` etc. to the protocol would bloat a rendering contract with domain semantics.
- **SPRD reference**: SPRD-227

---

## Open Questions

- `EntryStatusButtonRepresentable` conformances (on `DataModel.Task.Status` etc.) now return `EntryStatusIcon.BaseShape`, coupling model-layer conformances to a view-nested type. If `EntryStatusIcon` is ever renamed, all conformances break. Consider whether `BaseShape` and `Overlay` should be top-level types in a future cleanup pass.
- Verify at implementation time that Swift's implicit existential covariance applies to stored SwiftData `@Model` properties — i.e. that `var status: DataModel.Task.Status` on a `@Model` class satisfies `var status: any EntryStatusButtonRepresentable` in the `Entry` protocol without an explicit computed override.
