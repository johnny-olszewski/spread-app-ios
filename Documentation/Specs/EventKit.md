# EventKit

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

## Events (v2 - Future Calendar Integration)
- Manual event creation in the app. [SPRD-57]
- Google Calendar OAuth integration. [SPRD-57]
- Per-calendar visibility toggles in Settings. [SPRD-60]
- Events on month and year spreads with appropriate aggregation. [SPRD-57]
- Offline caching and cross-device sync for calendar events. [SPRD-59]
