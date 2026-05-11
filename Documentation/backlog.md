# Product Backlog

## Purpose
- Capture all deferred work: TestFlight readiness tasks, post-TestFlight improvements, pre-App Store features, and long-term feature candidates.
- Keep enough information in one place to compare user impact, implementation cost, and sequencing risk before selecting the next branch.
- Estimates are relative and should be revisited during feature discovery.

## Prioritization Rubric
- **Impact**: Expected user-facing value and how directly the item improves daily planning or product quality.
- **Effort**: Rough implementation cost across schema, sync, product logic, UI, tests, and migration risk.
- **Risk**: Whether the item touches core data models, sync, or shared infrastructure in ways that could destabilize other work.

---

## Section 1 — TestFlight Blockers

These items must be resolved before any TestFlight distribution. They represent production correctness issues, debug code exposure, or critical UX gaps that would give beta testers a poor first impression or incorrect signal.

| ID | Item | Description | Impact | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| TF-02 | Replace initialization fatalError | `ContentView` and `AppRuntimeStore` call `fatalError()` on initialization failure. This crashes the app with no user recourse. Replace with an error screen that shows a message and a retry affordance. | High: unhandled crash on startup is disqualifying for any beta. | Low-Medium: add an error state branch to the app startup path. | Low |
| TF-05 | Creation sheet error handling | Task, note, and spread creation/edit sheets do not surface errors when repository saves fail. Failed operations may silently discard user input. | High: data loss on a journaling app is severe. | Low-Medium: audit all sheet `.task {}` and `onSubmit` paths; add error alerts. | Low |
| TF-06 | EventKit permission request | Verify that the EventKit calendar permission request is triggered correctly on first access to the day timeline, and that the app degrades gracefully when permission is denied (timeline shows placeholder, no crash). | High: permission failure crash on a core feature is a TestFlight disqualifier. | Low: audit permission request flow and add a denied-state placeholder. | Low |

---

## Section 2 — TestFlight Polish

These items are not blockers but represent meaningful quality gaps that should be closed before distributing to beta testers. They affect first impressions, usability, and the signal quality of beta feedback.

### 2a — UX Completeness

| ID | Item | Description | Impact | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| TF-10 | Empty states for spreads | Spreads with no entries show a blank list. Add a purposeful empty state for each spread type (day, month, year, multiday) with a brief message and a contextual create-entry CTA. | High: a blank screen erodes confidence and hides the app's value. | Low-Medium: design and implement per-spread-type empty state views. | Low |
| TF-11 | Empty Inbox state | The Inbox surface when empty shows no guidance. Add an empty state explaining what the Inbox is and how tasks accumulate there. | Medium: Inbox is a key concept; an empty first-run state should reinforce it. | Low | Low |
| TF-12 | Sync status visibility | The `SyncErrorBanner` exists but sync errors may not always surface to the user. Verify the banner appears on network loss and sync failure, shows a meaningful message, and offers a retry action. | High: beta testers will test sync; invisible failures create false bug reports. | Low-Medium: audit SyncEngine error paths and wire banner to all failure states. | Low |
| TF-13 | Offline state messaging | When the device is offline, the app should clearly indicate sync is paused rather than silently failing. Add a visible offline indicator or toast when the user attempts sync-dependent actions while offline. | Medium: expected behavior for an offline-first app. | Low | Low |
| TF-14 | Spread creation/edit loading state | Spread creation involves async persistence. Add a loading state and disable the submit button during the operation to prevent duplicate creation. | Medium: UX consistency with auth loading states. | Low | Low |
| TF-15 | Input validation feedback | Form inputs for task titles, note titles, and spread names should provide clear feedback when validation fails (empty title, excessive length). Currently the app may silently reject or accept invalid input. | Medium: form validation is a table-stakes UX expectation. | Low | Low |

### 2b — Accessibility

| ID | Item | Description | Impact | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| TF-20 | Entry row accessibility labels | Task and note rows lack contextual accessibility labels. VoiceOver reads out a flat title string with no status context. Add labels that combine title, status (open, complete, cancelled), and assignment context. | High: accessibility is a TestFlight review signal and an App Store requirement. | Low-Medium: add `.accessibilityLabel()` and `.accessibilityValue()` to `EntryRowView`. | Low |
| TF-21 | Icon-only button labels | Status toggle, favorite, migration, and delete icon buttons lack accessibility labels. Screen reader users cannot identify these actions. | High: icon-only interactive elements without labels are a common accessibility audit failure. | Low: add `.accessibilityLabel()` to each interactive icon button. | Low |
| TF-22 | Spread navigation accessibility | Spread title navigator items and chevron collapse/expand controls need labels that include the spread name, type, and current state (selected, expanded). | Medium: navigation structure must be readable by assistive technology. | Low | Low |
| TF-23 | Calendar grid cell labels | Month calendar day cells need labels that include the full date (e.g., "May 4, 2026") and any entry count or overlay context, so VoiceOver users can navigate the calendar meaningfully. | Medium | Low-Medium | Low |
| TF-24 | Dynamic type compliance | Verify that all key surfaces render correctly at the largest accessibility text sizes. Pay special attention to the day timeline card (fixed-height), entry rows, and the title navigator. | Medium: dynamic type testing is part of Apple's accessibility review criteria. | Medium: involves layout audits and possibly adaptive layout changes. | Low |

### 2c — Visual Polish

| ID | Item | Description | Impact | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| TF-30 | Launch experience | App startup shows a generic `ProgressView("Loading...")`. Consider adding branding (app name, wordmark, or icon) to the loading screen so the first impression is intentional rather than default. | Medium: the launch experience frames the product's perceived quality. | Low | Low |
| TF-31 | Dark mode audit | Audit all screens in dark mode. Check for hardcoded colors, insufficient contrast, and any surfaces that appear washed out or broken. Use `SpreadTheme` tokens consistently; replace any hardcoded `Color` values found. | High: iOS users frequently run dark mode; broken dark mode is visually disqualifying. | Low-Medium: systematic pass through all view files. | Low |
| TF-32 | Consistent sheet presentation | Audit all sheets (task creation, note creation, spread creation, auth, onboarding) for consistent header layout, dismiss affordances, and button placement. Mismatched sheet chrome signals an unfinished product. | Medium | Low | Low |
| TF-33 | Toolbar and action button review | Review all toolbar buttons across spread types for correct placement, appropriate icon choices, and consistent tap-target sizing (minimum 44pt). | Medium | Low | Low |
| TF-34 | Multiday empty day section polish | Multiday spreads with empty day sections use a lighter treatment per spec. Verify this is visually distinct and readable across both light and dark modes. | Low-Medium | Low | Low |

### 2d — Testing

| ID | Item | Description | Impact | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| TF-41 | Smoke test: task and note creation | Add tests covering create task, create note, edit task, edit note, and delete operations through the journal manager layer. | High: these are the core user actions. | Low-Medium | Low |
| TF-42 | Smoke test: spread creation and navigation | Add tests for creating spreads of each type (day, month, year, multiday) and navigating between them via the conventional and traditional modes. | Medium | Medium | Low |
| TF-43 | Sync error recovery test | Add a test that exercises the sync engine's behavior when a network error occurs mid-sync: verify state transitions to error, banner is surfaced, and retry succeeds on reconnect. | High: sync durability is a core promise of the app. | Medium | Low |

---

## Section 3 — Pre-App Store (Post-TestFlight)

These items are not required for TestFlight but should be completed before App Store submission. They include features the user mentioned as pre-App Store work, App Store compliance requirements, and stability improvements informed by beta feedback.

### 3a — Feature Additions

| ID | Item | Description | Impact | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| AS-01 | Collections | Collections is a planned organizational layer for grouping spreads. The view stub (`CollectionsListView`, `CollectionEditorView`) exists but the feature is not implemented. Full discovery needed: data model, relationship to spreads and entries, sync behavior, and UI. | High: collections likely compound with the spread system to support project-style organization. | High: requires schema, sync, UI, and product-level decisions. | High: schema change; define before any other post-TestFlight schema work to avoid conflicts. |
| AS-02 | Google Sign-In | Add Google OAuth as an alternative auth provider via Supabase. Requires Supabase OAuth configuration, Google developer console setup, and a deeplink callback path. | Medium-High: reduces sign-up friction and is expected by iOS users familiar with social auth. | Medium: mostly configuration and thin UI wiring; backend auth provider handles the flow. | Low-Medium: requires Supabase provider config and App Store privacy disclosure update. |
| AS-03 | Sign in with Apple | Add Sign in with Apple as an auth option. Required for App Store submission if any other third-party social auth is offered. | High: App Store requirement when Google or other social auth is present. | Medium: ASAuthorizationController integration + Supabase provider wiring. | Low-Medium: Apple enforces specific UX rules; must review HIG compliance. |
| AS-04 | Event creation | Day and multiday spreads currently show EventKit events in read-only mode. Add the ability to create and edit calendar events from within the app. Requires EventKit write permission, creation sheet, edit sheet, recurrence handling, and calendar selection. | High: read-only calendar display is incomplete for a planning app; event creation closes the loop. | High: EventKit write is complex; recurrence and multi-calendar targeting add scope. | Medium: touches EventKit permission model and requires new write entitlement. |
| AS-05 | Guest / local-only mode | Removed from v1 scope: allow users to use the app without an account (local persistence only, no sync). Requires a product decision on upgrade path (guest → authenticated), data migration, and feature gating. | Medium-High: reduces sign-up friction; increases top-of-funnel conversion. | High: requires auth bypass, local-only data configuration, and upgrade migration path. | High: touches auth gate, sync engine, and data model assumptions. |

### 3b — Quality and Compliance

| ID | Item | Description | Impact | Effort | Risk |
| --- | --- | --- | --- | --- | --- |
| AS-10 | App Store privacy disclosure | Complete App Store privacy nutrition label: enumerate all data types collected, how they are used (account, app functionality, analytics), and whether they are linked to identity. Supabase sync and EventKit access both require disclosure. | High: required for App Store submission. | Low: documentation and App Store Connect configuration, no code changes. | Low |
| AS-11 | App Store metadata | Write App Store description, keywords, subtitle, promotional text, and screenshots for each supported device class (iPhone, iPad). Prepare at least 3 screenshots per device class. | High: required for submission; quality directly affects discoverability. | Medium: copywriting and screenshot capture; no code changes. | Low |
| AS-12 | Localization groundwork | Add `Localizable.strings` infrastructure with all hardcoded English strings extracted. Shipping v1 English-only is acceptable, but infrastructure must be in place before international distribution. | Medium: not blocking for English-only App Store, but deferred extraction compounds cost. | Medium: systematic find-and-replace of string literals with `String(localized:)` calls. | Low |
| AS-15 | Performance audit: large journals | As journal data grows (hundreds of tasks, many spreads), verify that list rendering, sync throughput, and SwiftData fetch performance remain acceptable. Profile and optimize any observed bottlenecks. | Medium: not an issue at launch but important for long-term retention. | Medium: profiling session + targeted fetch/cache optimization. | Low-Medium |
| AS-16 | Data export | Add a data export option in settings that produces a structured file (JSON or CSV) of all user tasks, notes, and spreads. Supports data portability and builds user trust. | Medium: users on a journaling app value ownership of their data. | Medium: serialization + share sheet integration; schema must be documented. | Low |

---

## Section 4 — Deferred Feature Candidates

These are longer-horizon features deferred from v1 implementation. None are required for TestFlight or initial App Store release. They are tracked here for comparison and sequencing before any future feature branch is selected.

### Notes

- **Schema risk** tracks features most likely to require Supabase table changes, SwiftData schema migrations, or sync conflict policy additions.
- Features are loosely ordered by recommended discovery priority, not by impact alone.
- Revisit estimates during dedicated discovery sessions before committing scope.

| Feature | Description | Impact | Effort | Schema Risk | Notes |
| --- | --- | --- | --- | --- | --- |
| Tags and tag filters | Add user-defined tags to tasks, then expose tag-based filtering and search across spreads. | High: improves organization once task volume grows and enables cross-spread workflows. | High: tag model, assignment UI, filtering UI, search integration, sync conflict handling, and indexes. | High: many-to-many task/tag relationship is a new table or join model. | Best candidate for the first post-v1 schema discovery session because it compounds with search and task browsing. Scope tag display, assignment UX, and filter surfaces before committing. |
| Task links | Attach one or more URLs to a task so external references travel with the task. | Medium: useful for tasks referencing documents, tickets, purchases, or websites, but not every task benefits. | Medium: link validation, display, edit UI, row preview decisions, search decisions, sync serialization, and tests. | Medium: likely either a normalized child table or an encoded ordered value with per-field conflict behavior. | Relatively bounded; useful for validating another additive metadata pass without graph behavior. Clarify whether links need titles, ordering, duplicate handling, and open-in-browser affordance. |
| Subtasks | Let a task contain smaller checklist items that can be completed independently. | High: valuable for breaking down larger tasks and reducing task-list clutter. | High: nested persistence, completion rules, row expansion/editing UX, sync merge rules, and tests. | High: child records with ordering and independent completion state. | Clarify whether subtasks affect parent completion, search, migration, and Inbox/spread visibility before starting. |
| Assigned time | Add an optional time-of-day to a task assignment without turning tasks into calendar events. | Medium: helps users plan when work should happen but risks overlap with future event/calendar concepts. | Medium: date/time semantics, timezone handling, UI display, editing, sorting decisions, and tests. | Medium: additive task field or assignment metadata; timezone semantics must be explicit. | Clarify whether assigned time affects ordering, reminders, overdue state, or only display. Best sequenced after event creation decisions are final to avoid duplicate time semantics. |
| Status expansion | Expand task status beyond open/completed/cancelled to include states like blocked, deferred, waiting, or archived. | Medium-High: enables richer workflows and surfaces progress nuance. | High: business rule changes, filters, migration, row actions, sync conflict handling, and backward compatibility. | High: status is core state; changes affect assignment semantics and merge behavior. | Should precede dependency/blocking work if blocked/waiting becomes first-class status. Requires explicit migration plan for existing records. |
| Hidden on spreads | Allow a task to be hidden from a specific spread surface while remaining accessible elsewhere. | Medium: helps keep active spreads focused without deleting or migrating tasks. | Medium: visibility rules, browser access, recovery affordances, sync, and tests. | Medium: additive visibility metadata that touches many query surfaces. | Clarify whether hiding is global, per-spread, per-assignment, temporary, or mode-specific before implementing. |
| Sequential and blocking tasks | Model dependencies so one task blocks another until completed. | Medium-High: useful for project-style work, but heavier than core bullet journal planning. | Very High: dependency graph modeling, cycle prevention, blocked-state UI, completion side effects, sync conflicts, and edge-case tests. | Very High: graph relationships require child/join tables and strict merge/cycle policies. | Best handled after subtasks and status expansion because the concepts overlap and can force incompatible schema choices. |
| Nil-assignment parity for notes | Let notes exist without a preferred assignment and surface in Inbox-like contexts until explicitly assigned, matching task nil-assignment behavior. | Medium: makes note capture more consistent with unassigned tasks. | Medium: note assignment model changes, Inbox/browser behavior, creation/edit UI, migration handling, and tests. | Medium-High: notes currently have non-null assignment semantics; parity likely changes schema and rebuild assumptions. | Clarify whether unassigned notes appear in the same Inbox as tasks or a separate capture surface before starting. |
| Global search | Search across all tasks, notes, and spreads by title, body, tags, or date. | High: becomes increasingly valuable as journal volume grows. | High: query design, index strategy, result ranking, UI, and sync-awareness. | Low: additive query layer; no schema changes if tags/links are not yet in scope. | Should be scoped separately from tag/link search integration to avoid blocking on schema decisions. |
| Reminders and notifications | Send local notifications for tasks with due dates or assigned times. | Medium: useful for time-sensitive tasks but requires notification permission and scheduling infrastructure. | Medium: UNUserNotification integration, scheduling logic, permission handling, and tests. | Low: additive; no schema changes required if assigned time is already in place. | Best sequenced after assigned time is implemented; clarify whether reminders are per-task or per-assignment. |
| Widgets | Home screen and Lock Screen widgets showing today's tasks, upcoming due dates, or inbox count. | Medium-High: increases daily engagement and surfaces the app without requiring full launch. | High: WidgetKit target, intent configuration, data access from app group container, and design work. | Low-Medium: requires shared app group for SwiftData access from widget extension. | Best approached after core journal flows are stable and App Store submission is complete. |

---

## Open Questions For Future Discovery

- Should collections, tags, and search be designed together as a cohesive organization layer, or should they ship independently and compose over time?
- Should future task metadata additions be grouped into one schema pass or shipped as small independent additions?
- Should tags, links, and subtasks participate in global search immediately, or should search/filtering be a separately scoped deliverable?
- Should a guest/local-only mode exist before the App Store release, or is email-only sign-up acceptable for initial launch?
- Should event creation be scoped as a standalone branch or bundled with assigned time to consolidate time-of-day semantics?
- What is the data retention and deletion policy for Supabase user records after account deletion?
