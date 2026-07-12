# Release Hardening

> **Status**: Draft
> **SPRD tasks**: SPRD-302, SPRD-303, SPRD-304, SPRD-305, SPRD-306
> **Session**: SESH-30

## Overview

Workstream A of the MVP launch plan (`Documentation/mvp-launch.md` §3): the correctness and first-impression fixes that must land before TestFlight distribution. These are release blockers surfaced by the pre-release codebase audit — silent data-loss paths, a launch crash, blank screens, invisible sync failures, and unverified permission degradation. This spec captures the durable requirements and the design decisions made for each; where a decision changes previously-specced behavior, `Documentation/Specs/ErrorHandling.md` is corrected to point here.

---

## Requirements

### Silent save failures [SPRD-302]

- The **edit-mode** `save()` paths in `TaskEntrySheet` and `NoteEntrySheet` must surface failures to the user via the existing `EntrySheet` error alert, matching the create-mode paths. A failed save must set `viewModel.errorMessage` (not merely reset `isBusy`), so the user is told and the sheet does not silently appear to succeed. [SPRD-302]
- `SettingsView` must render its `saveError` (currently assigned but never shown) — first-weekday save failures must be visible via an alert or inline message. [SPRD-302]
- Collections persistence (`CollectionEditorView`, `CollectionsListView`) must not swallow save/delete failures via `try?`; failures must surface. Collections is flag-hidden for MVP (see `mvp-launch.md` §5), but the data-loss path is fixed regardless so it is safe whenever the flag flips on. [SPRD-302]

### Launch initialization error recovery [SPRD-303]

- App runtime initialization failure must no longer call `fatalError` (`ContentView`). It must present a readable error screen instead of crashing. [SPRD-303]
- The error screen provides an in-place **Try Again** affordance that re-runs runtime initialization without requiring the user to force-quit and relaunch. A repeated failure returns to the same screen. [SPRD-303]
- Build-configuration `fatalError`s for missing Supabase Info.plist keys (`SupabaseConfiguration`) are out of scope — they represent a broken build, not a runtime condition a user can recover from. [SPRD-303]

### Spread empty states [SPRD-304]

- All four spread content views (day, month, year, multiday) must render a purposeful empty state when they contain no entries, instead of a blank area. The existing `ContentUnavailableView` empty state in `EntryListView` (currently dead code, never referenced in `body`) is wired up for this. [SPRD-304]
- Empty-state messaging is differentiated per spread type (day/month/year/multiday), reflecting what that spread is for. [SPRD-304]
- The empty state is **informational only** — it guides the user toward the existing global "+" create affordance. It is not itself a tappable create button and does not open the create flow. [SPRD-304]
- Out of scope: seeded starter content and any first-run guided-creation redesign (parked in `mvp-launch.md` §4). [SPRD-304]

### Sync/offline visibility and outbox quarantine [SPRD-305]

- A queued sync mutation whose params fail to serialize (`SyncEngine`) must no longer be silently removed from the outbox. It is moved to a **quarantined/failed** state: retained in the outbox, flagged, and excluded from the normal retry loop so it cannot block the queue behind it. [SPRD-305]
- Outbox enqueue failures must no longer be log-only; they contribute to the surfaced sync-error state. [SPRD-305]
- Sync/offline status is visible **app-wide**, not only on the Spreads tab — a consistent indicator regardless of the active tab. [SPRD-305]
- A **Sync** section in Settings shows: last successful sync time, current offline/online state, the count of quarantined mutations, and a manual **Retry** action that re-attempts quarantined items. [SPRD-305]

### EventKit permission degradation [SPRD-306]

- The EventKit calendar permission request must fire at the correct time on first access to the day timeline, and the app must degrade gracefully when permission is denied, restricted, or not-yet-determined: the timeline shows a placeholder (or is absent) with no crash. [SPRD-306]
- This is primarily a verification task against the existing implementation; any gap found is closed within it. [SPRD-306]

---

## Design Decisions

### Decision: Quarantine unserializable outbox mutations rather than dropping them

- **Context**: `SyncEngine` currently deletes a queued mutation from the outbox if its params fail to build, with only a log line — a silent, permanent data-loss path with no user signal.
- **Decision**: Move the mutation to a quarantined/failed state kept in the outbox, flagged and excluded from the automatic retry loop, and surface a sync-error state plus a manual retry (see Settings sync detail). The change is preserved for diagnosis and manual recovery; nothing vanishes silently.
- **Rationale**: Preferred over (a) dropping-but-reporting, which still loses the change; (b) normal-backoff retry, which risks an infinite loop on a deterministic serialization bug and blocks the queue; and (c) log-louder-only, which leaves the data unrecoverable. Quarantine is the only option that both preserves the user's data and avoids a poison-message queue stall.
- **SPRD reference**: SPRD-305

### Decision: In-place retry on launch initialization failure

- **Context**: Runtime-init failure currently hard-crashes via `fatalError`. `ErrorHandling.md` previously specified a fatal error screen with "no recovery attempted."
- **Decision**: Present a readable error screen with a **Try Again** button that re-runs initialization in-process; repeated failure returns to the same screen.
- **Rationale**: Many init failures are transient (a momentary resource or connectivity hiccup); forcing a manual relaunch for a recoverable condition is a poor first impression during beta. This supersedes the prior "no recovery" statement in `ErrorHandling.md`.
- **SPRD reference**: SPRD-303

### Decision: Empty states are informational, differentiated per spread type

- **Context**: Empty spreads render nothing; a designed empty state already exists in `EntryListView` but is unwired.
- **Decision**: Wire up the existing empty state across all four spread content views with per-type messaging, presented as guidance pointing at the existing "+" affordance rather than as a tappable create control.
- **Rationale**: Closes the blank-screen blocker and reinforces each spread's purpose without introducing a second, parallel create entry point or expanding into the first-run redesign (which stays in §4).
- **SPRD reference**: SPRD-304

### Decision: Sync status is app-wide plus a Settings detail surface

- **Context**: The sync error banner is mounted only on the Spreads tab and offline state only tints one toolbar icon; with quarantine added, users need a place to see and recover from sync problems.
- **Decision**: Surface a consistent sync/offline indicator regardless of tab, and add a Sync section in Settings (last-sync time, offline state, quarantined count, manual retry).
- **Rationale**: In-the-moment visibility on every tab plus a central recovery surface. Supersedes the `ErrorHandling.md` statement that no persistent offline indicator is shown.
- **SPRD reference**: SPRD-305

---

## Open Questions

- Quarantine persistence: is the quarantined/failed flag stored on the existing outbox/`SyncMutation` record (survives relaunch) or in-memory only for MVP? — resolve during SPRD-305 implementation.
- Manual "Retry" for quarantined items: re-attempt serialization only, or also force a full push? — resolve during SPRD-305 implementation.
- App-wide sync indicator form factor (banner vs. compact status chip vs. toolbar item) — resolve during SPRD-305 with a quick visual check.
