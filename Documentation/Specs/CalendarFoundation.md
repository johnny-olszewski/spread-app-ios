# Calendar Foundation

> Source: Documentation/spec.md

### Shared Foundations Package
- The repository may contain a local Swift Package named `johnnyo-foundation` for reusable components and utilities intended to be publishable independently later. [SPRD-152]
- `johnnyo-foundation` starts as a real local Swift Package integrated into the app through Xcode package dependency wiring, not as an app-only target. [SPRD-152]
- The package should begin with separate targets so UI components and non-UI utilities can evolve independently. The app should import only the package UI target for calendar UI use cases; that UI target may depend on the package core target internally. [SPRD-152]
- The package must include package-local tests and minimal package-local example/preview coverage from the start so the package boundary is validated independently of the app target. [SPRD-152]
- The package must also include package-local documentation suitable for future publication, including at least a package `README.md`, a package-local `spec.md`, and unit-test coverage for exported behavior. [SPRD-152]

### Shared Month Calendar Component
- `johnnyo-foundation` should provide a reusable month-based calendar shell component intended for embedding inside spread surfaces rather than replacing the month spread surface entirely. [SPRD-153]
- In `Spread`, both conventional and traditional month spreads should embed the shared month calendar above the month-level and day-section content areas. The calendar is structural and navigational rather than the primary entry-list container. [SPRD-153, SPRD-186]
- In the redesigned spread system, month-calendar borders communicate explicit spread existence, while secondary indicators communicate currently assigned content. Existence and content must not be conflated into one visual signal. [SPRD-186]
- The month calendar shell owns month structure and calendar math, including: [SPRD-153]
  - header placement
  - weekday header row placement
  - date-grid generation
  - first-weekday handling
  - locale-aware weekday ordering
  - leading and trailing peripheral-date generation when enabled
- Peripheral-date visibility is configurable. When enabled, the shell renders dates that share the first or last visible week with the target month even when those dates are outside the displayed month. [SPRD-153]
- The month shell renders the minimum number of week rows required for the displayed month and peripheral-date policy; it does not force a fixed six-row grid. [SPRD-153]
- Grid cells are abutting with no built-in spacing by default so callers can render content that visually spans adjacent days. [SPRD-153]
- The package month shell is driven by a displayed month `Date`, an injected `Calendar`, and explicit configuration rather than by a caller-precomputed month model. [SPRD-153]
- The package month shell uses an injected `CalendarContentGenerator` protocol to render month-specific content. The shell owns structure; the content generator supplies views for semantic slots such as: [SPRD-153]
  - the month header
  - weekday column headers
  - each date cell
  - any additional shell-defined decoration slots needed to keep the shell flexible
- Date-cell rendering callbacks should receive rich semantic context models rather than raw dates alone, so callers can render based on in-month vs peripheral state, today state, row/column position, and related shell-owned metadata without recomputing package-owned calendar logic. [SPRD-153]
- The package month shell also accepts an optional injected delegate protocol for shell-generated actions and interactions. The initial `Spread` integration may omit the delegate and remain view-only, but the action API should exist from the start so later interactive consumers do not require a package API redesign. [SPRD-153]
- The package month shell does not ship with built-in previous/next month controls in v1; header rendering is generator-driven so callers can choose their own month-navigation affordances later. [SPRD-153]

### Month Calendar Row Overlays
- `MonthCalendarView` must support optional row-bounded overlay decorations that can visually span multiple visible day cells within a single week row. Cross-row continuation is explicitly out of scope for this version; a logical overlay that crosses a week boundary renders as separate row segments. [SPRD-183]
- Row overlays are a separate concern from day-cell rendering. `CalendarContentGenerator` remains focused on header, weekday, day-cell, placeholder-cell, and week-background content; row overlays must be introduced through a separate optional overlay generator protocol rather than broadening `CalendarContentGenerator`. [SPRD-183]
- The first API should be generic enough for multiple decoration use cases, not only multiday spreads, but the semantic model remains calendar-aware and date-driven in v1. Overlay coverage is defined against dates, not raw row/column coordinates. A future revision may add non-date-driven row decorations if a real consumer requires them. [SPRD-183]
- Row overlays are decorative-only in v1. They do not own taps, gestures, focus, or accessibility interaction targets; underlying day/week interactions continue to belong to the existing shell content and delegate surfaces. [SPRD-183]
- When peripheral dates are visible, row overlays may render over any visible day cell, including visible peripheral dates. Hidden placeholder slots never participate in overlay coverage. [SPRD-183]
- Overlay rendering must occur between `weekBackgroundView` and the day/placeholder cell content so overlays can act as spanning background signals without obscuring day labels, borders, or existing tap targets. [SPRD-183]
- `johnnyo-foundation` owns the structural overlay math:
  - splitting logical overlay coverage into visible same-row segments
  - automatic lane packing for colliding segments within a week row
  - enforcing a configurable visible-lane limit
  - surfacing overflow metadata when packed overlays exceed the visible-lane limit [SPRD-183]
- The app owns overlay visuals. The overlay generator supplies app-defined overlay views or view-building logic for packed row segments and overflow presentation, while `johnnyo-foundation` supplies the packed render context needed to position those visuals correctly. Foundation should not ship a built-in visual style system for row overlays in this version. [SPRD-183]
- The packed row-segment render context must include enough semantic and layout metadata for app-owned rendering without exposing raw shell internals as the primary API. At minimum, the context should make available:
  - the overlay identity/payload
  - the week context
  - the segment's visible start and end coverage within the row
  - the assigned packed lane index
  - the total visible lane count for that row
  - whether the logical overlay continues before or after the current row segment
  - overflow metadata for any clipped packed lanes
  - row-scoped geometry or proportional layout information needed to render the app-owned overlay view [SPRD-183]
- The visible-lane count must be configurable by the consumer. When packed overlays exceed that limit, the shell must not silently discard information. Instead, foundation must reserve overflow metadata so the app can render an explicit overflow indicator lane or equivalent app-owned summary treatment. [SPRD-183]
- Package-local tests must prove the row-overlay contract independently of `Spread`, including:
  - visible-date participation
  - row segmentation at week boundaries
  - automatic lane packing for overlapping overlays
  - visible-lane limiting
  - overflow metadata derivation [SPRD-183]
- App-level integration tests must verify that `Spread` converts multiday spread semantics into the new overlay contract and renders the intended row-bounded overlay visuals in the rooted navigator without regressing existing month-grid interactions. [SPRD-184]
