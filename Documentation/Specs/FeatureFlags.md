# Feature Flags

> **Status**: Draft
> **SPRD tasks**: SPRD-310
> **Session**: SESH-31

## Overview

A layered feature-flagging system serving two distinct jobs (decided 2026-07-11, `mvp-launch.md` §5): build-time exclusion of in-development features (first consumer: the Collections tab, out of MVP scope), and a runtime entitlement seam for future user-permission and premium gating. Flags resolve through three layers — debug override, then entitlement, then compile-time default — so Release builds behave deterministically today while per-user remote gating can be added later without rework. Replaces the vestigial `FeatureFlags` enum (`Spread/Additions/FeatureFlags.swift`, one build-time constant) so the app never carries two parallel flag mechanisms.

---

## Requirements

### Flag model and resolution [SPRD-310]

- A `FeatureFlag` enum declares one case per gated feature. Initial cases: `collections` (build default **off**) and `events` (build default **off** — migrated from the legacy `FeatureFlags.eventsEnabled` constant, whose type is deleted). [SPRD-310]
- A `FeatureFlagProviding` protocol (`isEnabled(_ flag: FeatureFlag) -> Bool`) with a concrete `FeatureFlagService` resolving `debugOverride(flag) ?? entitlement(flag) ?? buildDefault(flag)`. [SPRD-310]
- **Entitlement layer**: an `EntitlementSource` protocol seam whose MVP implementation is a stub returning nil for every flag. No backend work; the seam is the deliverable (premium/permissions later back it with per-user data). [SPRD-310]
- **Debug layer** (DEBUG builds only, following the `AppRuntimeConfiguration` hooks pattern — no `#if DEBUG` in production files): launch-argument overrides parsed via `AppLaunchConfiguration`, plus a "Feature Flags" section in `DebugMenuView` with live toggles persisted to `UserDefaults`. Release builds never read overrides — resolution collapses to `entitlement ?? buildDefault`. [SPRD-310]

### Injection and first consumer [SPRD-310]

- The service is constructed in `AppDependencies.makeForLive/make/makeForPreview` (same shape as `settingsRepository`), exposed on `AppRuntime`, and threaded into `RootNavigationView`. [SPRD-310]
- The root tab list becomes flag-aware: `RootNavigationView.Content`'s static `allCases` is replaced by an instance-computed tab list on `RootNavigationView` (which already holds runtime dependencies), mirroring the existing `BuildInfo.allowsDebugUI` conditional-append precedent for the Debug tab. [SPRD-310]
- **Collections is hidden** when `collections` is off: tab absent from the tab list; a DEBUG toggle flips it live without relaunch. Collections code, repository, and sync behavior are untouched — gating is presentation-level only. [SPRD-310]

---

## Design Decisions

### Decision: Three-layer resolution with an entitlement stub now

- **Context**: Flags must serve build-time exclusion today and premium/permission gating later (user decision, 2026-07-11). Building remote flag infra now would be speculative; building compile-time-only flags would force a rework when entitlements arrive.
- **Decision**: `debugOverride ?? entitlement ?? buildDefault`, with `EntitlementSource` stubbed to nil for all flags in MVP.
- **Rationale**: Release behavior is fully deterministic (compile-time) until an entitlement source ships; the resolution order and protocol seam are the only parts that would otherwise need retrofitting. The natural future home for per-user values is typed columns on the Supabase `settings` table (per-field LWW) or a dedicated entitlements table — deferred.
- **SPRD reference**: SPRD-310

### Decision: Delete the legacy `FeatureFlags` enum rather than extending it in place

- **Context**: `Spread/Additions/FeatureFlags.swift` holds one dead-ish build constant (`eventsEnabled`, consumed only by `DebugDataService`).
- **Decision**: Migrate `eventsEnabled` to a `FeatureFlag.events` case with build default off and delete the old type; `DebugDataService` reads the injected service.
- **Rationale**: Two parallel flag mechanisms is exactly the redundancy CLAUDE.md prohibits; the constant's semantics are unchanged.
- **SPRD reference**: SPRD-310

### Decision: Tab gating is presentation-level only

- **Context**: Hiding Collections could also gate its repository/sync participation.
- **Decision**: Only the tab is gated. Collection data continues to load and sync.
- **Rationale**: Existing users' collection data (including the developer's) keeps syncing safely; flipping the flag on later reveals intact data. Gating sync would create a second data-visibility semantic for no MVP benefit.
- **SPRD reference**: SPRD-310

---

## Open Questions

- When entitlements arrive: settings-table columns vs. dedicated entitlements table (server-authoritative for pricing) — decide during the premium/monetization checkpoint (`mvp-launch.md` §8.3).
- Should launch-argument flag overrides also drive UI tests' scenario setup (they follow the existing `AppLaunchConfiguration` mechanism, so likely yes) — confirm during implementation.
