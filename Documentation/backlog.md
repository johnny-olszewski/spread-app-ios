# Product Backlog

## Purpose
- Capture deferred feature candidates that are not part of the current v1 implementation plan.
- Keep enough information in one place to compare user impact, schema/sync cost, UI complexity, and sequencing risk before selecting the next feature branch.
- Estimates are relative and should be revisited during feature discovery.

## Prioritization Rubric
- **Impact**: Expected user-facing value and how often the feature improves daily planning.
- **Effort**: Rough implementation cost across schema, sync, product logic, UI, tests, and migration risk.
- **Schema risk**: Whether the feature likely changes persisted models, Supabase tables/RPCs, conflict handling, or local rebuild paths.

## Deferred From `WKFLW-17`

| Feature | Description | Impact | Effort | Schema Risk | Notes |
| --- | --- | --- | --- | --- | --- |
| Task links | Attach one or more URLs to a task so external references can travel with the task. | Medium: useful for tasks that point to documents, tickets, purchases, or websites, but not every task needs it. | Medium: requires link validation/display, edit UI, row preview decisions, search decisions, sync serialization, and tests. | Medium: likely either a normalized child table or encoded ordered value with per-field conflict behavior. | Clarify whether links need titles, ordering, duplicate handling, and open-in-browser behavior. |
| Tags and tag filters | Add user-defined tags to tasks, then expose tag-based filtering/search. | High: improves organization once task volume grows and enables cross-spread workflows. | High: requires tag model decisions, assignment UI, filtering UI, search behavior, sync conflict handling, and potentially indexes. | High: many-to-many task/tag data is likely a new table or join model, not just a scalar field. | Strong candidate after core v1 is stable because it compounds with search and task browsing. |
| Assigned time | Add an optional time-of-day to a task assignment without turning tasks into calendar events. | Medium: helps users plan when work should happen, but risks overlapping with future event/calendar concepts. | Medium: requires date/time semantics, timezone handling, UI display, editing, sorting decisions, and tests. | Medium: likely additive task field or assignment metadata; timezone semantics must be explicit. | Clarify whether assigned time affects ordering, reminders, overdue state, or only display. |
| Subtasks | Let a task contain smaller checklist items that can be completed independently. | High: valuable for breaking down larger tasks and reducing task-list clutter. | High: requires nested persistence, completion rules, row expansion/editing UX, sync merge rules, and tests. | High: likely child records with ordering and independent completion state. | Clarify whether subtasks affect parent completion, search, migration, and Inbox/spread visibility. |
| Sequential/blocking tasks | Model dependencies so one task can block another until completed. | Medium-High: useful for project-style work, but heavier than core bullet journal planning. | Very High: requires dependency graph modeling, cycle prevention, blocked-state UI, completion side effects, sync conflicts, and edge-case tests. | Very High: graph relationships usually require child/join tables and strict merge/cycle policies. | Best handled after subtasks/status expansion decisions because the concepts overlap. |
| Hidden on spreads | Allow a task to be hidden from spread surfaces while remaining accessible elsewhere. | Medium: helps keep active spreads focused without deleting or migrating tasks. | Medium: requires visibility rules, browser access, clear recovery affordances, sync, and tests. | Medium: likely additive task visibility metadata, but behavior touches many query surfaces. | Clarify whether hiding is global, per-spread, per-assignment, temporary, or mode-specific. |
| Status expansion | Expand task status beyond the current open/completed/cancelled model. | Medium-High: enables richer workflows such as blocked, deferred, waiting, or archived states. | High: affects business rules, filters, migration/history, row actions, sync conflict handling, and backward compatibility. | High: status is core state, so changes affect assignment semantics and merge behavior. | Should precede dependency/blocking work if blocked/waiting becomes first-class status. |
| Nil-assignment parity for notes | Let notes have no preferred assignment and live in Inbox-like surfaces until explicitly assigned, matching task nil-assignment behavior. | Medium: makes note capture more consistent with unassigned tasks. | Medium: needs note assignment model changes, Inbox/browser behavior, creation/edit UI, migration handling, and tests. | Medium-High: notes currently retain non-null assignment semantics; parity likely changes schema and rebuild assumptions. | Clarify whether unassigned notes appear in the same Inbox as tasks or a separate notes capture surface. |

## Initial Priority Read
- **Best next discovery candidate**: tags and tag filters. It has high user impact and unlocks organization across spreads, but it should be scoped carefully because the schema shape matters.
- **Best contained implementation candidate**: task links. It is useful, relatively bounded, and can validate another additive metadata pass without introducing graph behavior.
- **Highest-risk candidates**: sequential/blocking tasks, status expansion, and subtasks. These should not be bundled casually because their semantics overlap and can force incompatible schema choices.
- **Needs product clarification before implementation**: assigned time, hidden-on-spreads, and nil-assignment parity for notes. Each looks contained at first, but the behavior depends on where the feature should surface in the UI.

## Open Questions For Future Discovery
- Should future task metadata changes be grouped into one schema pass again, or should small scalar additions ship independently?
- Should tags, links, and subtasks participate in global search immediately, or should search/filtering be phased separately?
- Should any backlog item be v1-blocking, or are these all post-v1 enhancements?
