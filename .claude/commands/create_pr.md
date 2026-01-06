Create a GitHub pull request from the current branch into `main`.

Rules:
- If there are no changes to commit, still ensure the branch is pushed and create the PR.
- Create a PR on GitHub.
- Include a short summary + testing notes in the PR body.

Steps:
1) Show current branch and status in the terminal:
   - git branch --show-current
   - git status

2) Analyze the acceptance criteria for the task (specified in plan.md), if possible:
   - analyze the changes in the current branch and ensure they are met.

3) List the acceptance criteria as a checklist. If all acceptance criteria are met then cancel the workflow and alert the user. Give the reason.

2) If there are unstage or uncommitted changes then cancel the workflow and alert the user. Give the reason.

3) Push the current branch:
   - git push -u origin HEAD

4) Create the PR using GitHub CLI:
   - gh pr create --base main --head "$(git branch --show-current)" \
     --title "<SPRD-# short descriptive title>" \
     --body "Summary: ... (include the acceptance criteria, tests created, testing notes and how to review the PR)
- <bullets>

5) Print the PR URL (gh will output it; also run `gh pr view --web`).
