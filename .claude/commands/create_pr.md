Create a GitHub pull request from the current branch into `main`.

Invocation:
- /create_pr

Behavior:
- If there are no changes to commit, still ensure the branch is pushed and create the PR.
- Create or update a PR on GitHub.
- Include a short summary + testing notes in the PR body.
- Use the PR template in `.github/pull_request_template.md`.
- Keep the working tree clean; if there are uncommitted changes, stop and alert the user.

Steps:
1) Show current branch and status in the terminal:
   - git branch --show-current
   - git status -sb

2) Check for workflow edits:
   - if the branch name begins with `WKFLW`, treat it as workflow-only changes
   - skip steps 3-6
   - for the PR content, analyze and summarize workflow file changes

3) Determine the task number:
   - parse the branch name for `SPRD-#`
   - if missing, inspect commits on the branch:
     - git log --oneline main..HEAD
   - if still missing or ambiguous, ask the user to confirm the task number

4) Analyze the acceptance criteria for the task (from `plan.md`):
   - analyze the changes in the current branch and ensure they are met
   - if not, take note of what was accomplished
   - include the acceptance criteria as a checklist in the PR body

5) If all acceptance criteria are NOT met, cancel the workflow and alert the user with the reason.

6) If there are uncommitted changes, cancel the workflow and alert the user with the reason.

7) Push the current branch:
   - git push -u origin HEAD

8) Check for an existing PR:
   - gh pr view --head "$(git branch --show-current)"
   - if one exists, update the PR description with the latest summary/testing/criteria and stop

9) Create the PR using GitHub CLI:
   - gh pr create --base main --head "$(git branch --show-current)"
   - populate the PR body using `.github/pull_request_template.md`

10) Print the PR URL (gh will output it; also run `gh pr view --web`).
