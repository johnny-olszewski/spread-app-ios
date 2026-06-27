# Entry Model Unification

> **Status**: Draft  
> **SPRD tasks**: SPRD-246, SPRD-247  
> **Session**: SESH-24

## Overview

Two related changes prompted by review findings while building `JournalRuleEngine` (SESH-24): the Supabase schema duplicates the same shape (entry, assignment, tag-join) across separate `tasks`/`notes` tables, and the local Swift model represents "no preferred assignment" via a redundant `Task.hasPreferredAssignment: Bool` flag instead of `date == nil` — even though the Supabase `tasks` table already treats `date`/`period` as nullable and derives the equivalent flag on decode (`SyncSerializer.swift`). This unifies both: the remote schema (`entries`/`assignments`/`entry_tags` replacing six split tables) and the local `Entry` protocol (`date: Date?`, plus eligibility properties that stop being derived from date presence).

---

## Requirements

- Supabase `tasks`/`notes` unify into one `entries` table with a `type` discriminator; `task_assignments`/`note_assignments` unify into one `assignments` table; `task_tags`/`note_tags` unify into one `entry_tags` table. [SPRD-246]
- Local SwiftData models (`DataModel.Task`, `DataModel.Note`) remain separate `@Model` classes — only the remote schema and sync/repository layer unify, per existing `JournalManager.md` guidance against generic `Entry` abstractions blurring task/note semantics. [SPRD-246]
- `Entry.date: Date?` is hoisted to the base `Entry` protocol (currently only `AssignableEntry` has non-optional `date`). `DataModel.Event` conforms by returning `startDate`. [SPRD-247]
- `DataModel.Task.hasPreferredAssignment` and its SwiftData backing field are removed; `date == nil` is the sole signal for "no preferred assignment." [SPRD-247]
- `DataModel.Note.date` becomes optional; a note with no date is not required to ever resolve to a spread, and is visible via the Entries tab rather than Inbox. [SPRD-247]
- Three new required `Bool` properties on `Entry` — `isInboxEligible`, `isMigratable`, `isOverdueEligible` — each a static per-type constant (Task: all `true`; Note/Event: all `false`), independent of `date`/`period`/status. [SPRD-247]
- Inbox membership becomes: `isInboxEligible && status == .open && (date == nil || no existing spread currently displays the entry)`. [SPRD-247]

---

## Design Decisions

### Decision: Unify Supabase tables, not local SwiftData models

- **Context**: `tasks`/`notes` (and assignment/tag-join tables) are structurally near-identical in Postgres, but `DataModel.Task`/`DataModel.Note` differ materially locally, and `JournalManager.md` already warns against a generic local `Entry` abstraction.
- **Decision**: Unify only the Supabase schema and the sync/repository code targeting it. Local `Task`/`Note` stay distinct `@Model` classes.
- **Rationale**: Gets the schema-maintenance win without contradicting existing architecture guidance or rewriting every call site that takes a concrete `Task`/`Note`.
- **SPRD reference**: SPRD-246

### Decision: Wide nullable columns on `entries`, not a `jsonb payload`

- **Context**: Task/Note have non-overlapping fields and different status enums.
- **Decision**: `entries` carries every field from both as nullable columns; `status text` keeps a type-conditional `CHECK` constraint.
- **Rationale**: Mechanical, low-risk migration; every field stays directly indexable/queryable; avoids JSON-path RLS/CHECK complexity.
- **SPRD reference**: SPRD-246

### Decision: Direct-cutover migration, no phased dual-write

- **Context**: Pre-TestFlight, no production users with synced data to protect mid-migration.
- **Decision**: One SQL migration creates the new tables, migrates existing rows, drops the six old tables, updates RLS — no dual-write transitional period.
- **Rationale**: The additive-then-cutover pattern used elsewhere (`ChangeAwareTaskRepository` alongside `SwiftDataTaskRepository`) exists to protect real synced devices mid-migration; that risk doesn't exist yet.
- **SPRD reference**: SPRD-246

### Decision: Eligibility flags are static per-type constants, not derived from `date`

- **Context**: The original `JournalRuleEngine` build (since reverted to `wip/SESH-24-old`) reused `hasPreferredAssignment`/`MigratableEntry` as the gate for migration *and* overdue eligibility, conflating "has a preferred date" with "is eligible for this feature."
- **Decision**: `isInboxEligible`/`isMigratable`/`isOverdueEligible` are simple `Bool` constants per type, with no per-instance variance. Per-instance state (status, date presence, current assignments) stays a separate check wherever a feature needs it.
- **Rationale**: Separates "can this type ever do X" from "is this instance eligible right now," preventing a future entry type from silently inheriting eligibility semantics that don't apply to it.
- **SPRD reference**: SPRD-247

---

## Open Questions

- The original `JournalRuleEngine`/`InboxEligibleEntry`/`MigratableEntry` build (renumbered SPRD-248) needs to be rebuilt on top of this corrected model rather than patched. Preserved in full on `wip/SESH-24-old` for reference.
