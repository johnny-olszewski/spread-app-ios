Review the working branch diff and apply Codex improvements aligned to the task.

Invocation:
- /codex_review

Behavior:
- ask for clarification when the task number cannot be determined
- do not amend existing commits
- only add a new review commit if code changes are needed
- keep changes scoped to the identified task and its requirements
- follow CLAUDE.md for code style, tests, and commit message format

Steps:

1) Identify task
- show current branch and status:
  - git branch --show-current
  - git status
- determine task number:
  - first, parse the branch name for `SPRD-#`
  - if missing, inspect commits on the branch for `SPRD-#`:
    - git log --oneline main..HEAD
  - if still missing or ambiguous, ask the user to confirm the task number

2) Load context
- read CLAUDE.md for repository rules
- read plan.md and locate the matching task
- quote the full task description and acceptance criteria in the response
- reevaluate requirements and identify any gaps in the current implementation

3) Review implementation
- inspect the diff:
  - git diff
  - git diff --stat
- analyze against requirements for correctness, scalability, readability, and clean coding practices
- identify missing tests or edge cases based on acceptance criteria

4) Apply changes (if needed)
- implement only changes required to meet the task requirements and quality bar
- update or add tests as needed
- avoid unrelated refactors

5) Verify
- run relevant tests for the changes
- if tests are not run, explicitly state why

6) Commit review changes
- if no changes are needed, report that and stop
- if changes were made, commit them in a new commit:
  - commit message format:
    - `[SPRD-#][1/n] Codex review: <short description>`
  - the commit message must clearly indicate it is a Codex review change

7) Report
- summarize findings, changes, tests, and any follow-ups or risks
