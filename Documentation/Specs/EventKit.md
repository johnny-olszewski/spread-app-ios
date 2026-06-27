# EventKit

> **Status**: Active  
> **SPRD tasks**: SPRD-57, SPRD-194, SPRD-195, SPRD-196, SPRD-197, SPRD-228  
> **Session**: SESH-##

> Source: Documentation/spec.md

## Events (EventKit Integration — v1)

### Decisions
- Source: EventKit only (device calendars — iCloud, Exchange, Google via iOS Settings). Google Calendar OAuth is deferred to v2. [SPRD-57, SPRD-194]
- Persistence: None. Events are live-fetched from EventKit on each spread display. No SwiftData model, no Supabase sync. [SPRD-194]
- Spread scope: Day and multiday spreads only. Month and year spread aggregation is deferred. [SPRD-195]
- Calendar filtering: None in v1 — all authorized calendars are shown. Per-calendar toggles are deferred to a follow-on task. [SPRD-60]
- Write-back: None. Events are read-only; the app opens them for viewing, not editing. [SPRD-59]

### Data Model
- `CalendarEvent` is a value type (struct) wrapping EventKit data relevant for display: event identifier, title, start date, end date, `isAllDay`, calendar title, and calendar color. [SPRD-194]
- `CalendarEvent` is not part of the Entry protocol hierarchy and has no assignments. [SPRD-194]

### EventKit Service
- `EventKitService` protocol exposes: authorization status, `requestAuthorization()`, `fetchEvents(from:to:)`, and `openEvent(_:)`. [SPRD-194]
- `LiveEventKitService` implements the protocol using `EKEventStore`. [SPRD-194]
- `MockEventKitService` supports testing without system EventStore access. [SPRD-194]
- Injected via `DependencyContainer`; spread views receive it through the environment or init injection. [SPRD-194]

### Permission Handling
- Authorization is requested the first time the user views a day or multiday spread. [SPRD-195]
- If denied or restricted, the events section is silently hidden — no error state is shown. [SPRD-195]
- No in-app Settings nudge or re-prompt UI in v1. [SPRD-195]

### UI
- Events appear in a dedicated **Events** section below the task list on day spreads, sorted by start time (all-day events first). [SPRD-195]
- On multiday spreads, events appear within each day section for every day they overlap. [SPRD-195]
- Each event row shows: calendar color indicator, event title, time range or "All Day" label, and calendar name. [SPRD-195]
- Tapping an event row presents an `EKEventViewController` in a sheet, showing native iOS event detail. [SPRD-195]
- The events section is omitted entirely when there are no events for the period or when permission is not granted. [SPRD-195]

### Event Visibility
- Event visibility on a day spread: start date ≤ spread date ≤ end date (inclusive, date comparison only). [SPRD-33]
- For multiday spread day sections: event overlaps the day using the same date-range comparison. [SPRD-33]

## Calendar Event Fetching Service (SPRD-228)

### Context

`CalendarEventStore` is currently a nested `@Observable` class inside `DaySpreadContentView`. It owns both the fetch logic (auth check + EventKit query) and the resulting `[CalendarEvent]` state. `MultidaySpreadContentView` has its own identical copy. This makes the fetch behaviour impossible to mock in tests or previews, and tightly couples the fetch strategy (EventKit) to the view layer. When Google Calendar or other providers are added, the fetch implementation must change without the view knowing.

### CalendarEventService Protocol

- `CalendarEventService` is a `@MainActor` protocol with a single async method: `func fetchEvents(for spread: DataModel.Spread, calendar: Calendar) async -> [CalendarEvent]`. [SPRD-228]
- `LiveCalendarEventService` is the production implementation. It wraps the existing `EventKitService`, handles authorization (request if `.notDetermined`, skip if not `.authorized`), and delegates the date-range query to `service.fetchEvents(from:to:)`. [SPRD-228]
- `MockCalendarEventService` is a test/preview implementation that returns a configurable `[CalendarEvent]` array with no EventKit access. [SPRD-228]
- `EmptyCalendarEventService` returns `[]` unconditionally. Used as the default no-op where calendar events are not relevant. [SPRD-228]

### Dependency Injection

- `CalendarEventService` is added to `AppDependencies` as `let calendarEventService: any CalendarEventService`. [SPRD-228]
- `makeForLive` constructs `LiveCalendarEventService(eventKitService: LiveEventKitService())`. [SPRD-228]
- `makeForPreview` and `make(...)` use `MockCalendarEventService()`. [SPRD-228]
- `SpreadPageContext` gains `let calendarEventService: any CalendarEventService` and drops `eventKitService`. The raw `EventKitService` is no longer threaded through the view layer — it remains inside `LiveCalendarEventService` only. [SPRD-228]

### View Changes

- `DaySpreadContentView.CalendarEventStore` is deleted. The view gains `@State private var calendarEvents: [CalendarEvent] = []` and calls `context.calendarEventService.fetchEvents(for:calendar:)` inside the existing `.task(id: spread.id)` modifier. [SPRD-228]
- `MultidaySpreadContentView` applies the same change — its `CalendarEventStore` is also deleted. [SPRD-228]
- No change to how `calendarEvents` is consumed inside these views (sections, timeline card, etc.). [SPRD-228]

### Design Decisions

### Decision: Pure fetch service, not injectable observable store

- **Context**: The store could be extracted as an `@Observable` protocol-backed class, keeping state ownership outside the view. Alternatively, the fetch concern alone is extracted and the view holds transient display state.
- **Decision**: Extract only the fetch concern as `CalendarEventService`. Views hold `@State var calendarEvents: [CalendarEvent]`.
- **Rationale**: `@Observable` conformance cannot be declared in a protocol, making the store shape harder to mock cleanly. Calendar event state is transient display data — it is correct for the view to own it. The fetch implementation (which provider, which auth flow) is the only part that varies by environment or future provider, so that is the right boundary for the protocol.
- **SPRD reference**: SPRD-228

### Decision: EventKitService stays in Services, not exposed through SpreadPageContext

- **Context**: `EventKitService` is currently in `SpreadPageContext` and used directly by views. With `CalendarEventService` wrapping it, views no longer need direct EventKit access for fetching. `EventKitService.openEvent(_:)` is still needed for tapping events.
- **Decision**: `openEvent(_:)` is moved onto `CalendarEventService` as an additional protocol requirement, or `eventKitService` remains in `SpreadPageContext` solely for `openEvent`. Preference: keep `eventKitService` in `SpreadPageContext` for `openEvent` only, and remove the fetch path from the view.
- **Rationale**: Minimal surface change. `openEvent` is a UI-triggered action (open a sheet), not a data fetch — it is appropriate for the view to call it directly. Folding it into `CalendarEventService` would conflate fetch and navigation concerns.
- **SPRD reference**: SPRD-228

---

## Events (v2 - Future Calendar Integration)
- Manual event creation in the app. [SPRD-57]
- Google Calendar OAuth integration. [SPRD-57]
- Per-calendar visibility toggles in Settings. [SPRD-60]
- Events on month and year spreads with appropriate aggregation. [SPRD-57]
- Offline caching and cross-device sync for calendar events. [SPRD-59]
