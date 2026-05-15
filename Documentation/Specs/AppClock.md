# AppClock

> Source: Documentation/spec.md

### AppClock and Temporal Context
- The app must not treat `today` or equivalent temporal context as launch-time-only state for product semantics that are defined relative to the current date, calendar, time zone, or locale. [SPRD-179]
- `AppClock` is a single app-wide temporal-context service with scene lifecycle inputs. The service is shared across windows/scenes, while scene activation/foreground events may trigger refreshes into that shared instance. [SPRD-179]
- `AppClock` owns only system temporal context and derived semantic change metadata:
  - current reference time (`now`)
  - current system `Calendar`
  - current system `TimeZone`
  - current system `Locale`
  - semantic change facts such as whether a refresh crossed a day boundary or was triggered by a significant time change [SPRD-179]
- `AppClock` does not own app product settings such as BuJo mode or first-weekday preference. Consumers compose those settings with clock state when needed. [SPRD-179]
- `AppClock` is infrastructure only. It observes and publishes temporal reality, but it does not decide product behavior such as whether a spread should remain selected or how overdue is evaluated. That policy remains in injected business-rule services, JournalManager orchestration, and view-local rendering code. [SPRD-179]
- `AppClock` should be implemented as a concrete observable service with injectable low-level collaborators such as current-time providers and notification/lifecycle bridges rather than as a top-level protocol-backed service abstraction. [SPRD-179]
- View-layer access to `AppClock` should be provided through the SwiftUI environment so descendant views can read temporal context without prop drilling. Non-view infrastructure such as `JournalManager`, coordinators, and rule engines must still receive explicit constructor-injected access to the same shared instance or to explicit temporal inputs; the app must not rely on view-only environment lookup inside core services. [SPRD-179]
- Time-sensitive pure logic should receive explicit temporal input values from higher layers where practical rather than reaching into shared mutable state directly. `JournalManager` and view models may read from `AppClock`, but evaluators, builders, formatters, and support-layer helpers should prefer explicit reference-date and temporal-context parameters when feasible so tests remain deterministic. [SPRD-180]
- `AppClock` must react automatically to all temporal-context changes that can alter app semantics or date rendering:
  - scene/app activation and foreground return
  - significant time change notifications
  - calendar-day-changed notifications
  - system time-zone changes
  - current locale changes
  - current system calendar changes where the underlying Foundation notifications/messages indicate a change in user date preferences [SPRD-179]
- Automatic temporal refresh is passive with respect to spread selection. When temporal context changes, the app must refresh semantics such as labels, recommendations, badges, overdue state, and `Today` behavior without automatically navigating away from the currently selected spread. [SPRD-179]
- Open create/edit sessions freeze their user-editable draft state and defaulted form inputs at presentation time. Temporal changes may refresh display-only labels around those forms, but they must not silently rewrite the user's current draft values or defaulted assignment/date choices while the form remains open. [SPRD-179]
- The app uses a hybrid recomputation model:
  - shared app semantics that are broadly reused may refresh eagerly on coarse `AppClock` changes
  - pure formatting and view-local checks should remain lazy and derive from current temporal input at render/use time [SPRD-180]
- `AppClock` must not become a global minute ticker for the whole app. Minute-level rendering is view-local:
  - app-wide semantic changes are driven by coarse temporal refreshes only
  - views that truly need minute-aligned updates, such as a future current-time line on a day calendar or minute-relative labels, must use local timeline-based rendering such as `TimelineView(.everyMinute)` or an equivalent local schedule [SPRD-179]
- The spec-defined time-sensitive behaviors that must become correct under `AppClock` include:
  - dynamic spread names such as `Today`, `Yesterday`, `This month`, `Next week`
  - `Today` button target resolution and passive today emphasis
  - overdue evaluation and overdue badge visibility
  - today-based spread recommendations
  - day/month/year/multiday visual today states
  - future day-calendar current-time indicators and similar local live-time surfaces [SPRD-179, SPRD-180]
- Debug and test infrastructure must support both:
  - startup-fixed temporal context for deterministic scenario seeding
  - runtime-controllable temporal context so tests can advance time, cross midnight, simulate significant time changes, and change time zone/locale/calendar context without relaunching the app [SPRD-181]
