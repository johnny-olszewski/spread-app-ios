Create a GitHub pull request from the current branch into `main`.

Rules:
- If there are no changes to commit, still ensure the branch is pushed and create the PR.
- Create a PR on GitHub.
- Include a short summary + testing notes in the PR body.

Steps:
1) Show current branch and status in the terminal:
   - git branch --show-current
   - git status

2) Check for workflow edits
   - check the branch name and see if it begins with WKFLW
   - this branch contains changes to workflow files, not production app changes
   - skip steps 3-5
   - for the PR content analyze the changes that are make to the workflow files

3) Analyze the acceptance criteria for the task (specified in plan.md), if possible:
   - analyze the changes in the current branch and ensure they are met.
   - if not then analyze the changes and take note of what was accomplishshed.
   - the task number is the `SPRD-#` in the branch name

4) List the acceptance criteria as a checklist. If all acceptance criteria are NOT met then cancel the workflow and alert the user. Give the reason.

5) If there are unstage or uncommitted changes then cancel the workflow and alert the user. Give the reason.

6) Push the current branch:
   - git push -u origin HEAD

7) Check open PR:
   - check GitHub to see if there is already an open PR for this branch
   - if so then do not create a PR
   - analyze the description and see what may have changed and what might need to be added based on any new commits
   - update the description for the PR
   - skip step 5

8) Create the PR using GitHub CLI:
   - gh pr create --base main --head "$(git branch --show-current)" 
   - reference the GitHub Pull Request template in ./github/pull_request_template.md

9) Print the PR URL (gh will output it; also run `gh pr view --web`).
