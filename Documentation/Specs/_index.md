# Spec Index

This index replaces the monolithic `Documentation/spec.md`. Each file below covers one feature area. Load only the file(s) relevant to the active task — do not load `spec.md` directly.

## How to Use

1. Find the feature area(s) for the active task below.
2. Read the linked file to understand requirements and design decisions.
3. The task's `Spec:` field in `Documentation/plan.md` links directly to the relevant file.

---

## Active Session Branches

| Branch | Description | Key Spec Files |
|--------|-------------|----------------|
| `feature/SESH-20` (formerly `WKFLW-20`) | UI polish and design system foundation for TestFlight | [DesignSystem.md](DesignSystem.md), [Accessibility.md](Accessibility.md) |
| `feature/SESH-21` | Task Browser tab, List/Tag organizational fields | [TaskBrowser.md](TaskBrowser.md), [DataModel.md](DataModel.md), [TaskMetadata.md](TaskMetadata.md) |
| `feature/SESH-24` | JournalManager/repository performance rebuild: drop logic-layer protocols, incremental dictionary-keyed index, caller-supplied sync diffing — built additively, cut over last | [JournalManager.md](JournalManager.md), [EntryModel.md](EntryModel.md) |
| `feature/SESH-25` | EntryList generic flat-entries grouping/sorting primitive, shared group-by/order-by picker across all spreads, plus EntryList/EntryRow architecture cleanup | [EntryListGrouping.md](EntryListGrouping.md) |
| `feature/SESH-29` | Task scheduled time: `scheduledTime` on Task, Supabase sync, migration rules, sheet chip, row time block, integrated Time sort on day spreads | [TaskScheduledTime.md](TaskScheduledTime.md) |
| `feature/SESH-30` | Release hardening (MVP Workstream A): silent-save-failure fixes, launch error recovery, spread empty states, sync/offline visibility + outbox quarantine, EventKit degradation | [ReleaseHardening.md](ReleaseHardening.md), [ErrorHandling.md](ErrorHandling.md) |
| `feature/SESH-31` | MVP infrastructure: layered feature flags (Collections hidden as first consumer), hybrid Crashlytics + Supabase observability, Workstream B closeouts (SPRD-268/269/274; SPRD-230 cut) | [FeatureFlags.md](FeatureFlags.md), [Observability.md](Observability.md) |
| `feature/SESH-32` | Day spread composition: sort-option hardening (deterministic Default chain), events integrated into the day entry list, containing-period open-task cards | [EntryListGrouping.md](EntryListGrouping.md), [DaySpreadComposition.md](DaySpreadComposition.md) |

---

## Feature Files

| File | Covers | Key SPRD Tasks |
|------|---------|----------------|
| [ProjectSummary.md](ProjectSummary.md) | Project goals, non-goals, platform targets, BuJo features, future versions | SPRD-1, SPRD-5, SPRD-19, SPRD-25 |
| [DataModel.md](DataModel.md) | Core entities: Entry, Spread, Task, Note, Assignment, Persistence | SPRD-8, SPRD-9, SPRD-10, SPRD-13 |
| [EntryModel.md](EntryModel.md) | Entry/AssignableEntry model unification: Supabase `entries`/`assignments`/`entry_tags` tables, optional `Entry.date`, `isInboxEligible`/`isMigratable`/`isOverdueEligible` | SPRD-246, SPRD-247 |
| [Migration.md](Migration.md) | Migration rules, eligibility, source/destination affordances, entry reassignment | SPRD-15, SPRD-110, SPRD-113, SPRD-140 |
| [AppClock.md](AppClock.md) | Temporal context service, time-sensitive behaviors | SPRD-179, SPRD-180, SPRD-181 |
| [JournalManager.md](JournalManager.md) | JournalManager facade, business rule architecture, BuJo mode | SPRD-11, SPRD-13, SPRD-154–SPRD-158 |
| [ConventionalMode.md](ConventionalMode.md) | Functional requirements: spreads, entries, task status, overdue, inbox (conventional mode only — traditional mode removed in SPRD-226) | SPRD-24, SPRD-25, SPRD-27, SPRD-29, SPRD-30, SPRD-226, SPRD-235, SPRD-274 |
| [SpreadNavigation.md](SpreadNavigation.md) | Compact context bar, rooted navigator, pager, spread surface architecture, adaptive nav shell, entry inspector, calendar content column, coordinator-driven popovers, pager render performance | SPRD-125, SPRD-126, SPRD-143, SPRD-148, SPRD-199, SPRD-229, SPRD-230, SPRD-232, SPRD-236, SPRD-244, SPRD-275, SPRD-283, SPRD-284 |
| [SpreadPersonalization.md](SpreadPersonalization.md) | WKFLW-17: favorites, custom/dynamic naming, spread deletion, multiday date edit, visual refresh | SPRD-167–SPRD-178 |
| [TaskMetadata.md](TaskMetadata.md) | WKFLW-17: task body, priority, due date, nil assignment; SESH-21: List and Tags fields; AddTaskButton toolbar quick-pick; priority icon in entry rows | SPRD-170, SPRD-221, SPRD-234, SPRD-288 |
| [TaskBrowser.md](TaskBrowser.md) | SESH-21: Tasks tab, List/Tag models, management sheet, filter behavior | SPRD-221, SPRD-222, SPRD-223, SPRD-224 |
| [CalendarFoundation.md](CalendarFoundation.md) | `johnnyo-foundation` package, MonthCalendarView, row overlays, CalendarView (multi-month) | SPRD-152, SPRD-153, SPRD-183, SPRD-184, SPRD-231 |
| [DesignSystem.md](DesignSystem.md) | SpreadTheme, palette tokens, dark mode, typography, icons, WKFLW-20 polish | SPRD-213–SPRD-220, SPRD-267, SPRD-268, SPRD-269 |
| [Sync.md](Sync.md) | Supabase offline-first sync, persistence, conflict scenarios | SPRD-80, SPRD-85, SPRD-253, SPRD-276 |
| [Authentication.md](Authentication.md) | Auth UI, email confirmation, deeplinks, WKFLW-19, account management | SPRD-104, SPRD-106, SPRD-200–SPRD-207 |
| [EventKit.md](EventKit.md) | Read-only EventKit events, day timeline, DayTimelineView, CalendarEventService, v2 future | SPRD-57, SPRD-194–SPRD-197, SPRD-228 |
| [DayTimeline.md](DayTimeline.md) | Day timeline visual overhaul: column layout, current-time indicator, event block content, all-day chips | SPRD-237 |
| [Settings.md](Settings.md) | Settings v1, collections, first launch and onboarding | SPRD-39 |
| [DevelopmentTooling.md](DevelopmentTooling.md) | Dev tooling, testing strategy, secrets and configuration | SPRD-105, SPRD-107 |
| [Accessibility.md](Accessibility.md) | Accessibility labels, VoiceOver, dynamic type | SPRD-218 |
| [ErrorHandling.md](ErrorHandling.md) | Error handling UX: auth, sync, network, app init, entry/spread ops; alert infrastructure | SPRD-233 |
| [ResolvedDecisions.md](ResolvedDecisions.md) | Edge cases resolved, resolved decisions, open questions | — |
| [EntryComponents.md](EntryComponents.md) | Entry status icon rendering pipeline: EntryStatusIcon, EntryStatusIconRepresentable | SPRD-227, SPRD-270 |
| [EntryListGrouping.md](EntryListGrouping.md) | EntryList generic grouping/sorting primitive, shared group-by/order-by picker, EntryList/EntryRow cleanup, deterministic Default sort chain | SPRD-257–SPRD-266, SPRD-287, SPRD-307 |
| [TaskScheduledTime.md](TaskScheduledTime.md) | Optional scheduled time on tasks: `scheduledTime` instant, `isTimeAssignable` capability flag, day-period gating, Supabase `scheduled_time` sync, sheet chip, row time block, integrated Time sort on day spreads | SPRD-296–SPRD-301 |
| [EntryEditingSheets.md](EntryEditingSheets.md) | Unified `EntrySheet` shell for Task/Note/Spread creation and editing, shared form-model abstraction, CalendarView-backed date selection; SESH-27 visual redesign (SpreadButton pickers, chip clouds, custom header, calendar-embedded spread selection) | SPRD-277–SPRD-282, SPRD-291–SPRD-294 |
| [ReleaseHardening.md](ReleaseHardening.md) | MVP Workstream A release blockers: silent save-failure surfacing, launch init error recovery, spread empty states, sync/offline visibility + outbox quarantine, EventKit permission degradation | SPRD-302–SPRD-306 |
| [DaySpreadComposition.md](DaySpreadComposition.md) | Day spread entry-list composition: calendar events integrated as ordinary entries (no subtitle, leading time block), containing multiday/month/year open-task cards below the day list | SPRD-308, SPRD-309 |
| [FeatureFlags.md](FeatureFlags.md) | Layered feature-flag system: debugOverride → entitlement → buildDefault resolution, EntitlementSource stub seam, DEBUG menu/launch-arg overrides, flag-aware root tab list, Collections hidden as first consumer | SPRD-310 |
| [Observability.md](Observability.md) | Hybrid observability: Crashlytics crashes/non-fatals, Supabase `analytics_events` table with batched offline queue, ErrorReporting/AnalyticsTracking protocols, v1 no-PII event taxonomy | SPRD-311 |

---

## Templates

- [_template.md](_template.md) — Blank spec file template for new features
