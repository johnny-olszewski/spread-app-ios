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

---

## Feature Files

| File | Covers | Key SPRD Tasks |
|------|---------|----------------|
| [ProjectSummary.md](ProjectSummary.md) | Project goals, non-goals, platform targets, BuJo features, future versions | SPRD-1, SPRD-5, SPRD-19, SPRD-25 |
| [DataModel.md](DataModel.md) | Core entities: Entry, Spread, Task, Note, Assignment, Persistence | SPRD-8, SPRD-9, SPRD-10, SPRD-13 |
| [Migration.md](Migration.md) | Migration rules, eligibility, source/destination affordances, entry reassignment | SPRD-15, SPRD-110, SPRD-113, SPRD-140 |
| [AppClock.md](AppClock.md) | Temporal context service, time-sensitive behaviors | SPRD-179, SPRD-180, SPRD-181 |
| [JournalManager.md](JournalManager.md) | JournalManager facade, business rule architecture, BuJo mode | SPRD-11, SPRD-13, SPRD-154–SPRD-158 |
| [ConventionalMode.md](ConventionalMode.md) | Functional requirements: spreads, entries, task status, overdue, inbox (conventional mode only — traditional mode removed in SPRD-226) | SPRD-24, SPRD-25, SPRD-27, SPRD-29, SPRD-30, SPRD-226 |
| [SpreadNavigation.md](SpreadNavigation.md) | Compact context bar, rooted navigator, pager, spread surface architecture | SPRD-125, SPRD-126, SPRD-143, SPRD-148, SPRD-199 |
| [SpreadPersonalization.md](SpreadPersonalization.md) | WKFLW-17: favorites, custom/dynamic naming, spread deletion, multiday date edit, visual refresh | SPRD-167–SPRD-178 |
| [TaskMetadata.md](TaskMetadata.md) | WKFLW-17: task body, priority, due date, nil assignment; SESH-21: List and Tags fields | SPRD-170, SPRD-221 |
| [TaskBrowser.md](TaskBrowser.md) | SESH-21: Tasks tab, List/Tag models, management sheet, filter behavior | SPRD-221, SPRD-222, SPRD-223, SPRD-224 |
| [CalendarFoundation.md](CalendarFoundation.md) | `johnnyo-foundation` package, MonthCalendarView, row overlays | SPRD-152, SPRD-153, SPRD-183, SPRD-184 |
| [DesignSystem.md](DesignSystem.md) | SpreadTheme, palette tokens, dark mode, WKFLW-20 polish | SPRD-213–SPRD-220 |
| [Sync.md](Sync.md) | Supabase offline-first sync, persistence, conflict scenarios | SPRD-80, SPRD-85 |
| [Authentication.md](Authentication.md) | Auth UI, email confirmation, deeplinks, WKFLW-19, account management | SPRD-104, SPRD-106, SPRD-200–SPRD-207 |
| [EventKit.md](EventKit.md) | Read-only EventKit events, day timeline, DayTimelineView, v2 future | SPRD-57, SPRD-194–SPRD-197 |
| [Settings.md](Settings.md) | Settings v1, collections, first launch and onboarding | SPRD-39 |
| [DevelopmentTooling.md](DevelopmentTooling.md) | Dev tooling, testing strategy, secrets and configuration | SPRD-105, SPRD-107 |
| [Accessibility.md](Accessibility.md) | Accessibility labels, VoiceOver, dynamic type | SPRD-218 |
| [ErrorHandling.md](ErrorHandling.md) | Error handling UX: auth, sync, network, app init, entry/spread ops | — |
| [ResolvedDecisions.md](ResolvedDecisions.md) | Edge cases resolved, resolved decisions, open questions | — |
| [EntryComponents.md](EntryComponents.md) | Entry status icon rendering pipeline: EntryStatusIcon, EntryStatusIconRepresentable | SPRD-227 |

---

## Templates

- [_template.md](_template.md) — Blank spec file template for new features
