# MVP Launch Plan

> **Status**: Draft — created 2026-07-11 from a full codebase + documentation audit
> **Purpose**: Single source of truth for everything between the current state and an App Store MVP launch. Supersedes `backlog.md` Sections 1–2 for launch sequencing (backlog item IDs are cross-referenced, not duplicated). Individual features listed here still get specced via `/spread-spec` into `Documentation/Specs/` + `plan.md` SPRD blocks before implementation.

---

## 1. Launch Strategy

- **Sequence**: TestFlight beta → iterate on feedback → App Store submission.
- **Monetization**: Deferred decision with a hard checkpoint before App Store submission (§8.3). The feature-flag entitlement layer (§5) is designed now so premium gating can be added without rework.
- **Collections**: Out of MVP scope. Hidden behind a build-time feature flag (§5); code stays in place.

### MVP definition

The MVP is: the existing spread/task/note journal, hardened (§3), brought to internal consistency (§4), plus **repeating tasks** (§6.1) and **subtask checklists** (§6.2), gated by the new feature-flag infrastructure (§5), instrumented with **error logging and analytics** (§6.4), with the launch-process work in §8 complete.

---

## 2. Current State — Implemented Feature Inventory

| Area | State |
| --- | --- |
| Spreads (year / month / day / multiday) | Complete. Conventional mode only (traditional removed, SPRD-226). Explicit creation, favorites, custom naming, deletion with reassignment, multiday free-range selection. |
| Entries (Task / Note / Event) | Complete. Unified `EntrySheet` shell (SESH-27/28 redesign), status lifecycle, priority, due date, body, List/Tag organization, scheduled time (SESH-29). |
| Migration | Complete. First-class BuJo migration with history, inline source/destination affordances, overdue review, scheduled-time rebase rules (SPRD-298). |
| Task Browser (Entries tab) | Complete. Tasks/Notes modes, adaptive filter panel, List/Tag filters, proper empty states. |
| EventKit | Read-only events on day/multiday spreads + day timeline card (SPRD-237 overhaul). No event creation (AS-04, post-MVP). |
| Sync | Offline-first Supabase outbox + pull, LWW per-field merge, coalescing, batched push. Single-place error banner (gap — §3.4). |
| Auth | Email auth complete (WKFLW-19): confirmation, deeplinks, password reset, resend. Social auth removed (SPRD-108). Sign-out + account deletion in `ProfileSheet`. |
| Settings | Minimal: First Day of Week (synced), version. BuJo-mode toggle removed with traditional mode. |
| Onboarding | Exists: 3-page `OnboardingSheet` after first auth, persisted via `OnboardingStateStore`. Hands off to a blank day spread (gap — §3.3/§4). |
| Design system | SpreadTheme palette/typography/icons. Phosphor migration done; typography ~95% (§4). |
| Collections | Functional plain-text pages (list, editor, autosave, sync) but excluded from MVP — to be flag-hidden. |
| Debug tooling | Localhost mode, debug menu, mock data, launch-arg overrides — the pattern the flag system extends. |

---

## 3. Workstream A — Hardening (release blockers first)

Ordered by severity. Items 3.1–3.4 are TestFlight blockers.

### 3.1 Silent save failures (data-loss UX) — backlog TF-05
- `TaskEntrySheet.swift:803` and `NoteEntrySheet.swift:513`: **edit-mode** `save()` catch blocks reset `isBusy` but never set `viewModel.errorMessage`, so failures are invisible. Create-mode paths do this correctly; fix is to populate the existing alert plumbing (`EntrySheet.swift:95–103`).
- `SettingsView.swift:98`: `saveError` is assigned but never rendered anywhere in `body`. Add the alert/inline error.
- Collections persistence is 100% `try?` (`CollectionEditorView.swift:111`, `CollectionsListView.swift:124/132`) — flag-hidden for MVP, but fix before the flag ever flips on.

### 3.2 Launch crash path — backlog TF-02
- `ContentView.swift:136` `fatalError` on runtime-init failure. Replace with an error screen + retry affordance. `SupabaseConfiguration.swift:33/42` `fatalError`s are build-config-time and acceptable.

### 3.3 Spread empty states — backlog TF-10/TF-11
- All four spread content views render nothing when empty. `EntryListView.swift:122–132` already contains a designed `ContentUnavailableView` empty state that is **dead code** (never referenced in `body`); wire it up, then differentiate messaging per spread type.
- First-run compounding: onboarding dismisses onto a blank day spread. Minimum fix: contextual create-entry CTA in the empty state. Better (§4): starter content or a guided first action.

### 3.4 Sync/offline visibility — backlog TF-12/TF-13
- `SyncErrorBanner` is mounted in exactly one place (`SpreadContentPagerView.swift:83`); Entries/Settings tabs show no sync state. `SyncStatus.offline` exists but only tints a toolbar icon.
- **Silent outbox drop**: `SyncEngine.swift:369` removes a mutation whose params fail to build with only a log — a real data-loss path with no user signal. Decide policy (retry / quarantine / surface) and implement.
- Enqueue failure at `SyncEngine.swift:246` is also log-only.

### 3.5 EventKit permission flow — backlog TF-06
- Verify request timing and denied-state degradation (placeholder, no crash).

### 3.6 Remaining hardening (TestFlight polish tier)
- Input max-length validation (TF-15); spread creation loading state (TF-14).
- Accessibility pass: navigator labels (TF-22), calendar cell labels (TF-23), dynamic type audit — day timeline card is fixed-height (TF-24).
- Smoke tests: entry CRUD (TF-41), spread creation/navigation (TF-42), sync error recovery incl. the §3.4 drop path (TF-43).

---

## 4. Workstream B — Consistency Closeout (bring features inline)

Half-finished migrations and stragglers found in the audit:

| Item | State | Action |
| --- | --- | --- |
| SPRD-268 typography | ~95% done (144 token usages) | **Decided 2026-07-12: exempt + close.** The 3 holdouts are fixed-pixel calendar digits (CLAUDE.md carve-out); document exemption at the sites, delete commented-out `.font` lines in `EntryRowView.swift:193/204/213`, mark Done. Executes in SESH-31. |
| SPRD-269 Phosphor icons | Done in code (0 `Image(systemName:)` in views) | Verify + mark Done in plan.md. Executes in SESH-31. |
| SPRD-230 entry edit popover | Pending | **Decided 2026-07-12: cut from MVP** — entry editing works via the SESH-27/28 sheet redesign. Re-marked Backlog in plan.md. |
| SPRD-274 OverdueCardView on all spreads | Pending | In — overdue review is a core BuJo loop and inconsistent surfacing is confusing. |
| `EntryListView.emptyState` dead code | Never wired | Absorbed into §3.3. |
| Grouping/sorting prefs | `@AppStorage`, device-local | Decide: acceptable for MVP (recommend yes) or move to synced Settings. Document the decision either way. |
| First-run experience | Onboarding → blank spread | Redesign candidate: seed a starter day spread + sample entries, or a guided "create your first task" moment. Scope in its own spec. |

---

## 5. Workstream C — Feature-Flag Infrastructure

**Requirement** (decided 2026-07-11): flags have two distinct jobs —
1. **Build-time exclusion** of in-development features (e.g. Collections) — resolved at compile/launch, not user-dependent.
2. **Runtime entitlement gating** for user-permission and future premium features — per-user, remote-driven.

### Design: layered resolution

```
effectiveValue(flag) = debugOverride(flag)      // DEBUG builds only, UserDefaults-persisted
                    ?? entitlement(flag)         // remote per-user layer (premium/permissions)
                    ?? buildDefault(flag)        // compile-time default per flag
```

- **`FeatureFlag` enum**: one case per gated feature (`collections`, `repeatingTasks`, `subtaskChecklists`, …). Evolves the existing vestigial `FeatureFlags` enum (`Spread/Additions/FeatureFlags.swift`, currently one dead constant).
- **`FeatureFlagProviding` protocol + concrete service**, constructed in `AppDependencies.makeForLive/make/makeForPreview` and exposed on `AppRuntime` — same shape as `settingsRepository`.
- **Build layer**: static defaults, may consult `BuildInfo` / `DataEnvironment.current`.
- **Entitlement layer**: protocol seam (`EntitlementSource`) implemented **now as a stub returning nil** for every flag. When premium/permissions arrive, back it with per-user data — natural home is typed columns on the Supabase `settings` table (per-field LWW, following `first_weekday`), or a dedicated entitlements table if server-authoritative pricing demands it. No backend work in MVP; the seam is the deliverable.
- **Debug layer**: launch-arg overrides via the existing `AppLaunchConfiguration` pattern + a "Feature Flags" section in `DebugMenuView` (slots in after `buildInfoSection`), persisted to UserDefaults in DEBUG only. Follows the `AppRuntimeConfiguration` hooks precedent — no global mutable state.

### First consumer: hide Collections
- Tab list lives at `RootNavigationView+Content.swift:32–38`, which already conditionally appends `.debug` via `BuildInfo.allowsDebugUI` — the exact precedent. Because `allCases` is `static`, gating on an injected service means converting the tab list to an instance-computed property on `RootNavigationView` (which already holds all runtime deps) or passing flags into `allCases(flags:)`.
- Acceptance: Release builds never show Collections; DEBUG can toggle it live from the debug menu.

---

## 6. Workstream D — New MVP Features

### 6.1 Repeating tasks
**Decided**: both generation modes, user-selectable per task (Todoist "every" vs "every!" semantics).

- **Spawn-on-completion**: completing the task creates the next occurrence at the next rule date. Fits migration semantics — each occurrence is a real task.
- **Fixed-schedule**: occurrences exist on their day regardless of completion. Needs: a series/template concept, a materialization window (e.g. generate on spread build within visible horizon), and explicit rules for uncompleted past occurrences (pile up as overdue? auto-cancel? — spec decision).
- **Rule shape (v1)**: frequency (daily / weekly / monthly / yearly) + interval + weekday set (weekly) + day-of-month policy (monthly). End conditions (until date / after N) — spec decision, recommend deferring.
- **Storage**: encoded recurrence rule + `_updated_at` LWW pair on `entries`, following the `scheduled_time` template (SPRD-297). Fixed-schedule mode likely adds a series identifier linking occurrences. Additive columns; fold into `baseline_schema.sql` while pre-release.
- **Interactions to spec**: recurrence × migration (migrating one occurrence vs the series), recurrence × scheduledTime (rebase rules exist for day→day), recurrence × dueDate, editing scope (this occurrence vs series), deletion scope.
- This is the largest MVP feature. Spec via `/spread-spec` as its own session; the dual-mode decision roughly doubles rule-engine tests — budget accordingly.

### 6.2 Subtask checklists
**Decided**: lightweight checklist now; keep a scoped upgrade path to full child tasks post-MVP.

- Ordered items (`id`, `title`, `isDone`, `order`) embedded on the parent Task as an encoded value-type array — same pattern as `Assignment` (Codable value type, not a `@Model`). One column pair on `entries` (`checklist` + `checklist_updated_at`), whole-array LWW.
- **Not** participating in: assignments, migration (checklist travels with the parent), Inbox, overdue, search, the Entries browser.
- Spec decisions: does checklist completion affect parent status (recommend: no auto-complete; show progress count `2/5` on the row); row-level display vs sheet-only editing; item count cap.
- Known trade-off: whole-array LWW means concurrent edits from two devices last-write-win the entire list. Acceptable for MVP; the post-MVP child-task upgrade fixes it.

### 6.3 Error logging and analytics (in MVP — vendor decision pending)

**Requirement** (added 2026-07-11): the MVP ships with crash reporting, error logging, and basic product analytics. Beta feedback without telemetry is anecdotes; the App Store launch needs activation/retention signal. **Decided 2026-07-12: the hybrid stack** (Crashlytics + Supabase events), specced as SPRD-311 in `Documentation/Specs/Observability.md` with the v1 event taxonomy — the comparison below is retained for the record.

**What to capture (v1):**
- **Crashes**: native crash reports with symbolicated stacks.
- **Errors**: the non-fatal failures §3 makes visible — sheet save failures, sync push/pull errors, the `SyncEngine.swift:369` outbox-drop path, auth failures. Every user-facing error alert should also be reported.
- **Product events**: a deliberately small set — activation (first spread created, first task created), core loop (task completed, task migrated, entry created per type), feature adoption (recurrence used, checklist used, time sort used), retention proxy (session start). No content, no titles — event names + non-PII properties only.

**Options:**

| | Supabase-native | Firebase (Crashlytics + Analytics) | Hybrid (recommended) |
| --- | --- | --- | --- |
| Crash reporting | ✗ — Supabase has none; you'd fall back to MetricKit (delayed delivery, manual symbolication, weak DX) | ✓✓ Crashlytics is best-in-class: real-time, symbolicated, non-fatals, breadcrumbs | ✓✓ Crashlytics |
| Error/event logging | ✓ `analytics_events` table written through the existing client; fits the outbox/offline-first pattern; queryable in SQL next to product data | ✓ but events live in Google's console, not your DB; BigQuery export to own the data | ✓ errors as Crashlytics non-fatals; product events → Supabase table |
| Dashboards | Build your own (Studio/SQL) | ✓ out of the box | Crash dashboards free; product analytics via SQL |
| Dependency cost | Zero new SDKs | Heavy SDK, `FirebaseApp.configure()` global (isolatable behind a protocol), Google data-sharing + privacy-label additions | One new SDK (Crashlytics only — skip Firebase Analytics) |
| Data ownership | ✓✓ everything in your Postgres | ✗ analytics in Google | ✓ product data in your Postgres; only crash payloads to Google |

**Recommendation — hybrid**: Crashlytics for crashes and non-fatal error reports (the one job Supabase genuinely cannot do), and a Supabase `analytics_events` table for product events (append-only: `id`, `user_id`, `name`, `properties jsonb`, `created_at`, batched through a lightweight queue reusing the offline-first posture; RLS insert-only). If you want to avoid Google entirely, Supabase + MetricKit is viable but materially worse crash DX during the beta, which is exactly when you need it most.

**Architecture** (follows existing patterns): `ErrorReporting` and `AnalyticsTracking` protocols injected via `AppDependencies` — protocols at boundaries keep the vendor swappable and tests clean. No-op implementations for localhost/debug and previews, gated by `DataEnvironment` (never report from `localhost`). Console logging stays on OSLog; reporting is additive, not a replacement. Privacy-label impact tracked in §8.2.

### 6.4 Recommended additions (decision pending — not yet committed)
| Candidate | Why | Cost | Recommendation |
| --- | --- | --- | --- |
| Local reminders/notifications | Every competitor has them; `dueDate` + `scheduledTime` already exist, so this is UNUserNotificationCenter + scheduling logic, no schema | Medium | **In for App Store, optional for TestFlight** — sequence after recurrence |
| Quick capture (share ext. / quick-add) | Capture friction is the #1 churn driver in task apps | Medium-High (app group, extension target) | Post-MVP |
| Global search | Valuable at volume; browser search exists for tasks | High | Post-MVP (backlog) |
| Widgets | Engagement driver | High (WidgetKit target, app group) | Post-MVP (backlog) |
| Data export (AS-16) | Trust signal for a journal | Medium | Pre-App-Store if time allows |

---

## 7. Industry Comparison

Feature-level position vs. the apps Spread will be shelved next to:

| Capability | Spread today | Things 3 | Todoist | TickTick | Structured | NotePlan | Apple Reminders |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Repeating tasks | ✗ → §6.1 | ✓ (rich, incl. after-completion) | ✓ (NL input, every/every!) | ✓ | ✓ | ✓ | ✓ |
| Subtasks/checklists | ✗ → §6.2 | ✓ checklists | ✓ nested | ✓ | ✓ | ✓ | ✓ |
| Reminders | ✗ → §6.3 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Calendar overlay | ✓ (read-only + timeline) | ✓ | ✓ | ✓✓ (built-in cal) | ✓✓ (core UX) | ✓ | ✗ |
| Time-of-day scheduling | ✓ (SESH-29) | partial | ✓ | ✓ | ✓✓ | ✓ | ✓ |
| Migration/BuJo semantics | ✓✓ **differentiator** | ✗ | ✗ | ✗ | partial (shift day) | ✓ (closest rival) | ✗ |
| Journal page model (spreads) | ✓✓ **differentiator** | ✗ | ✗ | ✗ | ✗ | ✓ (daily notes) | ✗ |
| Offline-first + sync | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Quick capture | ✗ | ✓✓ | ✓✓ | ✓ | ✓ | ✓ | ✓✓ (Siri) |
| Search | partial (browser) | ✓ | ✓ | ✓ | ✗ | ✓✓ | ✓ |
| Widgets | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Read**: Spread's moat is the BuJo methodology executed with real product depth (migration history, spreads, overdue review) — closest competitor is NotePlan, which is markdown-first rather than structure-first. The three ✗ rows at the top are table stakes everywhere including the free system app; §6 closes two of them and reminders should follow immediately. Quick capture is the most important post-MVP gap because capture friction undermines the journaling habit the app exists to build.

---

## 8. Workstream E — Launch Process

### 8.1 TestFlight gate (all must be true)
- §3.1–3.5 complete; §5 flags in place with Collections hidden; §4 closeouts decided.
- Beta plan: tester list, feedback channel, what signal each beta cycle is meant to produce.

### 8.2 App Store gate
- Privacy nutrition label (AS-10): Supabase account data + EventKit usage enumerated.
- Metadata (AS-11): description, keywords, subtitle, ≥3 screenshots per device class (iPhone + iPad).
- Review compliance: account deletion in-app (exists — `ProfileSheet`), permission purpose strings audit, sign-in requirement justification (App Review may ask why no guest mode — AS-05 was cut; have the answer ready).
- Support URL + privacy policy URL (need to exist publicly).
- Error logging and analytics live per §6.3, integrated before TestFlight. Privacy label must reflect the chosen stack (Crashlytics adds crash-data disclosure; a Supabase events table adds product-interaction disclosure either way).
- Data retention/deletion policy for Supabase rows after account deletion (open question from backlog).

### 8.3 Monetization checkpoint (before App Store submission)
Decision deferred by design. When taken: free / subscription / one-time. The §5 entitlement layer is the technical prerequisite either way; StoreKit 2 + paywall UI only enter scope if not-free. Revisit after TestFlight retention data.

---

## 9. Proposed Session Sequencing

| Session | Bundle | Depends on |
| --- | --- | --- |
| SESH-30 | Workstream A hardening: 3.1 save failures, 3.2 init error screen, 3.3 empty states, 3.4 sync/offline surfacing, 3.5 EventKit | — |
| SESH-31 | Workstream C feature flags + hide Collections (SPRD-310); error logging & analytics (SPRD-311); Workstream B closeouts (268/269/274; 230 cut) | — |
| SESH-32 | *(taken by interleaved work: Day spread composition, SPRD-307–309 — not part of this plan's original sequence)* | — |
| SESH-33 | Repeating tasks (spec session first — largest feature) | SESH-31 (ships behind flag) |
| SESH-34 | Subtask checklists | SESH-31 |
| SESH-35 | Reminders/notifications + first-run experience redesign | SESH-33 |
| SESH-36 | TestFlight prep: accessibility pass, smoke tests, beta plan → **distribute** | SESH-30–34 |
| SESH-37+ | Beta feedback loop; App Store gate items (§8.2); monetization checkpoint (§8.3) | SESH-36 |

Each feature session begins with `/spread-spec` to produce the spec file + SPRD blocks; this document is the input, not the substitute.

---

## 10. Open Questions

- Fixed-schedule recurrence: policy for uncompleted past occurrences (overdue pile-up vs auto-cancel vs auto-migrate)?
- Recurrence end conditions in v1 or deferred?
- Checklist progress display on entry rows: count chip, mini-bar, or sheet-only?
- Starter content on first run: seeded sample spread vs guided empty-state CTA only?
- ~~Error logging/analytics stack (§6.3)~~ — resolved 2026-07-12: hybrid Crashlytics + Supabase events (SPRD-311, `Specs/Observability.md`).
- ~~Analytics event taxonomy~~ — resolved 2026-07-12: v1 list fixed in `Specs/Observability.md` (7 events, no PII, server-side derivation).
- Guest-mode question for App Review (AS-05 was cut) — is email-required acceptable friction for launch?
- Which §6.4 candidates make the App Store cut (reminders recommended; others recommended post-MVP)?
