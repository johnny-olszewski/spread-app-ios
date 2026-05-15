# Migration

> Source: Documentation/spec.md

### Migration
- Moving a task/note from a parent spread to a child spread. [SPRD-15]
- Source assignment status becomes migrated; destination assignment becomes open/active. [SPRD-15]
- Manual migration remains available through explicit user actions. In addition, creating an explicit year/month/day/multiday spread automatically reconciles eligible current tasks and notes to the best available destination in that hierarchy using preferred-date/preferred-period rules. Multiday participation is optional rather than recommendation-driven: the system never recommends creating multiday spreads, but once an explicit multiday spread exists it participates in waterfall assignment and auto-migration. [SPRD-15, SPRD-34, SPRD-186, SPRD-193]
- Notes are never suggested in batch migration UI, even though spread creation can automatically reconcile them. [SPRD-15, SPRD-34, SPRD-186]
- Migration prompt logic in v1 applies to tasks only and only in conventional mode. [SPRD-110, SPRD-140]
- A task is eligible to migrate into a spread only when all of the following are true: [SPRD-110]
  - The task has a current open assignment on a coarser source (`Inbox`, year, or month/day parent) aligned to the destination's date hierarchy.
  - The destination spread is more granular than the current open assignment.
  - The destination spread is not more granular than the task's desired assignment period.
  - The destination spread is the most granular valid existing destination currently available for that task.
  - The task is open; completed, migrated-history-only, and cancelled tasks are not migration-eligible.
- Migration prompt source rules: [SPRD-110]
  - A year spread may pull from `Inbox` only.
  - A month spread may pull from `Inbox` and year spreads.
  - A multiday spread may pull eligible day-preferred and multiday-preferred entries from `Inbox`, year spreads, and month spreads when the entry's preferred date falls inside the multiday range and no finer explicit destination already exists.
  - A day spread may pull from `Inbox`, multiday spreads, month spreads, and year spreads.
  - Multiday spreads never appear in spread recommendations and are never treated as expected-created spreads, but they may receive direct assignments and automatic waterfall migration once they exist. [SPRD-193]
- Source-spread migration affordance: [SPRD-140]
  - In conventional mode, an active task row shows a trailing right-arrow button only when that task has a smaller valid existing destination spread.
  - Tapping the arrow presents a confirmation alert that explicitly names the destination spread the task will be moved to.
  - Confirming the alert migrates that single task to its smallest valid existing destination spread.
- Destination-spread migration affordance: [SPRD-140]
  - In conventional mode, a destination spread may show a bottom section titled `Migrate tasks` when at least one task from the immediate parent hierarchy can migrate into that specific spread.
  - The section is collapsible.
  - The section header includes a trailing `Migrate All` action scoped to that destination spread.
  - The section lists one row per migratable task; tapping a row migrates that task into the current destination spread without additional confirmation.
  - The old migration banner and migration review sheet are removed from this flow.
- Post-migration source behavior: [SPRD-140]
  - A migrated task leaves the source spread's content entirely.
  - The source assignment remains in history with migrated status.
  - Spread content does not retain migrated rows or a `Migrated tasks` subsection after reassignment. [SPRD-186]
- Migration prompting examples: [SPRD-110]
  - Example A: `2026` and `January 2026` exist. A task desired for `January 1, 2026` day is currently open on `January 2026`. When `January 1, 2026` day is created, the task automatically moves to that day spread.
  - Example B: `2026` exists. A task desired for `January 2026` month is open on `2026`. When `January 2026` is created, the task automatically moves to the month spread. If `January 10, 2026` is later created, that day spread does not move this task because day is more granular than the task's desired assignment.
  - Example C: A task desired for `January 10, 2026` day is in `Inbox`. If `2026`, `January 2026`, and `January 10, 2026` all exist, only `January 10, 2026` receives it because that is the most granular valid existing destination.
  - Example D: A task desired for `January 10, 2026` day is open on `2026`. If `January 2026` exists and `January 10, 2026` does not, the task resolves to the month spread. Once the day spread exists, it automatically moves again to the day spread.
- Migration scenario table (absolute-date reference cases): [SPRD-113]

| Scenario date context | Task desired assignment | Current source | Existing valid spreads | Prompted destination | Why |
| --- | --- | --- | --- | --- | --- |
| `January 12, 2026` | `January 2026` month | `2026` year | `2026`, `January 2026` | `January 2026` | Month is the most granular valid existing destination and does not exceed the desired month period. |
| `January 12, 2026` | `January 2026` month | `2026` year | `2026`, `January 2026`, `January 10, 2026` | `January 2026` | `January 10, 2026` is more granular than the task's desired month assignment, so it is never eligible. |
| `January 12, 2026` | `January 10, 2026` day | `2026` year | `2026`, `January 2026` | `January 2026` | The exact day spread does not exist yet, so the month spread is the most granular valid existing destination. |
| `January 12, 2026` | `January 10, 2026` day | `2026` year | `2026`, `January 2026`, `January 10, 2026` | `January 10, 2026` | Once the day spread exists, the coarser month prompt disappears and only the day prompt remains. |
| `January 12, 2026` | `January 10, 2026` day | `Inbox` | `2026`, `January 2026`, `January 10, 2026` | `January 10, 2026` | Inbox follows the same most-granular-valid-existing-destination rule as spread-assigned tasks. |

### Entry Date/Period Changes (Reassignment)
- Changing preferred date or period triggers reassignment logic in conventional mode. [SPRD-24]
- Period is independently editable (e.g., changing from month to day without changing the date month). [SPRD-24]
- Task creation and task editing must use the same period/date normalization and adjustment rules so the saved preferred assignment is consistent regardless of entry point. A period change in the editor must not silently preserve a stale date from the previous period when that would change reassignment outcome. [SPRD-141]
- In the edit sheet, reassignment is the user-facing way to migrate a task; changing preferred date and/or period updates the preferred assignment, and the previous assignment becomes migrated history if reassignment occurs. [SPRD-141]
- Old assignments (on old date/period's spreads) are marked as migrated to preserve history. [SPRD-24]
- New assignment is created on the best matching spread for the new date/period: [SPRD-24, SPRD-13]
  - Search from finest to coarsest within the preferred-period ceiling:
    - day-preferred: day → containing multiday → month → year
    - multiday-preferred: explicit multiday → month → year
    - month-preferred: month → year
    - year-preferred: year [SPRD-24, SPRD-13, SPRD-193]
  - If a matching spread exists, create/update assignment with open/active status.
  - If no matching spread exists, entry goes to Inbox.
- If destination spread already has an assignment, update its status (don't duplicate). [SPRD-52]
- Traditional mode date/period changes also trigger conventional reassignment logic. [SPRD-17, SPRD-24]
- Reassignment example for seeded conventional data: if a task created on the `2026` year spread is edited to preferred assignment `April 6, 2026` day while no `April 2026` month spread and no `April 6, 2026` day spread exist, the task remains open on the `2026` year spread and is shown in the April section with a `6` context label. After an explicit `April 2026` month spread is created, that month spread becomes the migration destination surfaced by inline migration affordances; the edit itself must not jump the task to an unrelated existing day spread such as `January 1, 2026`. [SPRD-141]
