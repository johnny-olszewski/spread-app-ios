# Project Summary

> Source: Documentation/spec.md

## Project Summary
- Multiplatform app (iPadOS primary, iOS) built in SwiftUI with SwiftData local storage + Supabase sync. [SPRD-1, SPRD-5, SPRD-80]
- Adaptive UI: top-level navigation adapts by device using a single `TabView` root configured with SwiftUI's adaptive tab APIs. On iPhone it presents as a tab bar; on iPad it uses Apple's sidebar-adaptable presentation rather than a custom split-view shell. Spread navigation uses a compact in-view spread context bar on both platforms, and a fixed leading affordance in that bar presents the complete rooted spread navigator as a popover on iPad and a sheet on iPhone. Conventional and traditional modes share the same compact bar, rooted selector, swipe pager, and spread-surface architecture; mode differences are expressed through spread availability and entry inclusion/assignment rules rather than separate navigation UIs. A dedicated top-level search-role tab replaces the old Inbox toolbar flow and hosts the global task browser. [SPRD-19, SPRD-25, SPRD-35, SPRD-38, SPRD-125, SPRD-126, SPRD-143, SPRD-148, SPRD-151, SPRD-177]
- Shared foundations package: the app may host reusable UI components and utilities in a local Swift Package named `johnnyo-foundation`, structured for later GitHub publication. App-facing product spec captures integration points and high-level contracts; detailed package API spec should live with the package. [SPRD-152, SPRD-153]
- AppClock is the app-wide temporal-context infrastructure for current time, system calendar, time zone, and locale. It keeps time-sensitive product behavior correct while the app remains open across foregrounding, midnight, DST, travel, and other significant time changes. It is infrastructure only: product policy remains in JournalManager collaborators, view models, and view-local renderers. [SPRD-179]
- Core entities (v1): [SPRD-8, SPRD-9, SPRD-10]
  - Spread: period (day, multiday, month, year) + normalized date. [SPRD-8]
  - Entry: protocol for task and note with type-specific behaviors. [SPRD-9]
  - Task: assignable entry with status and migration history. [SPRD-9, SPRD-10]
  - Note: assignable entry with assignment history and no batch-migration prompts. [SPRD-9, SPRD-34, SPRD-186]
  - TaskAssignment/NoteAssignment: preferred period/date plus current-destination/status history for migration tracking. Direct multiday assignments must identify the explicit multiday spread record rather than infer ownership only from `period + date`, because multiday spread uniqueness is range-based and legacy overlapping multiday records may still exist in synced data. [SPRD-10, SPRD-15, SPRD-193]
- EventKit calendar events appear read-only alongside tasks and notes on day and multiday spreads; live-fetched from EventKit with no local caching or Supabase sync. [SPRD-57, SPRD-194, SPRD-195]
- Day spread surfaces include a fixed-height day timeline card rendered above the entry list. The card shows a time ruler with hour labels on the left and EventKit event blocks positioned proportionally on the right. Events that overlap in time are rendered in start-time order with a leading indent on later-starting events so both are partially visible. The visible time window defaults to 6 AM–10 PM and is configurable at the call site. The card height is also configurable with a default of approximately 240pt. The timeline is absent when EventKit authorization is denied, restricted, or no events are present for the day. [SPRD-196, SPRD-197]
- The `DayTimelineView` component lives in `johnnyo-foundation` (`JohnnyOFoundationUI` target) as a generic, provider-driven view. It depends on a `DayTimelineContentProvider` protocol whose conformer supplies per-item rendering via a typed `DayTimelineItemContext` view-builder method (mirroring the `CalendarContentGenerator` / `MonthCalendarDayContext` pattern) and a time-ruler label view-builder. Layout math (time-to-Y mapping, height, clamping, overlap detection, and overlap offsets) is owned by the package through a first-class `DayTimeCoordinateSpace` value type that lives in `JohnnyOFoundationCore`. The Spread app provides a `SpreadDayTimelineProvider` conformance that renders `CalendarEvent` items. [SPRD-196, SPRD-197]
- JournalManager is the app's central journal facade and in-memory state owner. It owns repository coordination, cached journal state, data-model refresh, and app-facing mutation/query APIs, but business-rule engines should be extracted behind injected protocols so they can be unit tested independently and swapped when needed. [SPRD-11, SPRD-13, SPRD-15, SPRD-154, SPRD-155, SPRD-156, SPRD-157, SPRD-158]
- Two mode-specific spread rule sets over a shared UI architecture: [SPRD-25, SPRD-35, SPRD-38, SPRD-151]
  - Conventional mode exposes only explicitly created spreads, including explicit multiday spreads. Spread content is current-assignment-only; migration history is retained in assignments and surfaced only through dedicated migration affordances/feedback. Multiday is a first-class assignable period in conventional mode, but it remains an optional tool rather than a recommended or assumed spread type. [SPRD-25, SPRD-27, SPRD-30, SPRD-140, SPRD-151, SPRD-186, SPRD-193]
  - Traditional mode exposes year/month/day destinations through the same shared spread navigation and surface components, but applies traditional spread-availability and entry-inclusion rules and does not surface multiday destinations. [SPRD-35, SPRD-38, SPRD-151]
- BuJo modes: "conventional" (explicit-spread-driven, current-assignment content with dedicated migration flows) and "traditional" (full year/month/day hierarchy, preferred-assignment driven). [SPRD-20, SPRD-17, SPRD-151, SPRD-186]

## Goals
- Deliver a tab-based bullet journal focused on spreads, tasks, and notes, with an in-view compact spread context bar, a selected-spread navigator surface presented as an iPad popover and iPhone sheet, and conventional-mode migration flows that preserve assignment history without leaving historical rows in spread content. [SPRD-25, SPRD-15, SPRD-29, SPRD-125, SPRD-126, SPRD-186]
- Provide a unified spread-surface architecture where traditional mode reuses the same navigator, pager, header, section, and list components as conventional mode while preserving traditional spread availability and assignment semantics. [SPRD-17, SPRD-35, SPRD-38, SPRD-151]
- Support offline-first usage with SwiftData local storage and Supabase sync. [SPRD-80, SPRD-85]
- Require authentication for all product usage in dev/prod environments, while preserving offline access for users with an existing cached session and local data. [SPRD-104, SPRD-106]
- Preserve a debug-only `localhost` mode for engineering workflows; it uses mock auth, supports mock data loading, is selected per launch, and never persists across launches. [SPRD-105, SPRD-107]

## Non-Goals (v1)
- Advanced search and filters remain out of scope for v1. Task body participates in the existing global task browser search, but tags and tag filters are deferred beyond `WKFLW-17`. [SPRD-56, SPRD-167, SPRD-170]
- Week period in Period enum or week-based task assignment. [SPRD-8, SPRD-56]
- Fully automatic spread creation or recommendation of multiday spreads. Multiday remains an optional explicit tool rather than an assumed product workflow. [SPRD-56, SPRD-193]
- Advanced collection types beyond plain text pages. [SPRD-39, SPRD-56]
- Links, assigned time, subtasks, sequential/blocking dependencies, hidden-on-spreads behavior, status-model expansion, and nil-assignment parity for notes are deferred beyond `WKFLW-17` and tracked in `Documentation/backlog.md`. [SPRD-167, SPRD-171]
- Manual event creation and Google Calendar OAuth are deferred to v2. [SPRD-69] Per-calendar visibility toggles and events on month/year spreads are deferred to follow-on tasks.
- Localization - hardcoded English strings for v1. Revisit post-v1.
- macOS support - planned for future versions.
- Realtime updates (Supabase Realtime) in v1.

## Platform
- iPadOS 26+ (primary platform). [SPRD-1]
- iOS 26+ (iPhone support). [SPRD-1]
- macOS: Out of scope for v1; planned for future versions.

### Multiplatform Strategy
- Adaptive layouts using size classes: [SPRD-19, SPRD-25]
  - A single top-level `TabView` is used for all devices. [SPRD-143]
  - Regular width (iPad): the root `TabView` uses SwiftUI's sidebar-adaptable presentation so top-level destinations are surfaced through Apple's adaptive sidebar/tab model rather than a custom `NavigationSplitView`. Spread navigation stays in the spread view via a compact spread context bar, whose fixed leading chevron affordance opens the complete rooted spread navigator popover.
  - Compact width (iPhone): the same root `TabView` presents as a bottom tab bar; the same compact spread context bar appears in the spread view, and its fixed leading chevron affordance opens the same rooted spread navigator content in a large sheet.
  - Top-level destinations remain flat, first-class destinations: `Spreads`, `Collections`, `Settings`, and `Debug` when available. [SPRD-19, SPRD-143]
  - User tab/sidebar customization is out of scope for v1; the adaptive tab structure is app-defined and non-customizable. [SPRD-143]
  - `NavigationTab` remains the single source of truth for top-level destination identity and selection. [SPRD-143]
  - The navigation shell keeps an explicit layout/testing override so previews and tests can force compact vs regular adaptive behavior deterministically without maintaining separate root container implementations. [SPRD-143]
- iPad multitasking support: [SPRD-19]
  - Split View (1/3, 1/2, 2/3 configurations)
  - Slide Over
  - App works correctly at all supported sizes
- All views must be responsive and adapt to available space. [SPRD-19]

## BuJo Method Features (v1)
- Future log (year spread). [SPRD-25, SPRD-27]
- Monthly log (month spread with entries). [SPRD-28]
- Daily log (day spread with entries). [SPRD-28]
- Rapid logging symbols (task/note). [SPRD-21, SPRD-22]
- Migration and scheduling (manual). [SPRD-15, SPRD-30]
- Collections (plain text pages). [SPRD-39, SPRD-40, SPRD-41]

## BuJo Method Features (Future/v2)
- Index. [SPRD-56]
- Habit/mood trackers. [SPRD-56]
- Review/reflection. [SPRD-56]
- Search, filters, tagging. [SPRD-56]
- Event logging with Google Calendar OAuth integration. [SPRD-57]

---

## Future Versions
- Spread bookmarking. [SPRD-56]
- Dynamic spread names. [SPRD-56]
