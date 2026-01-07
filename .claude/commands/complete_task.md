Complete a task from plan.md.

Invocation:
- /complete_task
- /complete_task <TASK_NUMBER>

Behavior:
- throughout the execution ask for clarification if needed, do not make assumptions
- if the answers require the spec or plan to be updated then make the changes after confirming them with the user
- if tasks will be completed in future tasks include `//TODO: SPRD-#` where applicable. Ensure all TODOs relate to a task

Task selection rules (when no task number is provided):
- Choose the earliest task in plan.md that is not marked complete
- Do not skip tasks unless blocked by an explicit dependency
- Do not infer new tasks

- If <TASK_NUMBER> is provided:
  - Locate the matching task in plan.md
  - Treat it as the sole scope of work
- If <TASK_NUMBER> is NOT provided:
  - Select the next incomplete, unblocked task in plan.md:
   - tasks might be marked as completeed
   - or traverese the commit history which means they are completed if merged with task number
  - Treat that task as the sole scope of work
- confirm with the user which task is to be completed before proceeding

Task completion scaffold:

0) Setup
- checkout main, stash any changes if necessary
- create a new branch per the spec and checkout the branch

1) Resolve task  
- With the task to be completed:
  - Echo the task number
  - Quote the full task description from plan.md including the acceptance criteria
- State the expected outcome

2) Load context  
- Read CLAUDE.md for repository rules  
- Read spec.md for functional requirements  
- Read plan.md to confirm ordering and dependencies  

3) Create tests
- based on the spec, think through what tests will need to be created based on the acceptance criteria
- consider all edge cases that need to be tested
- implement the tests based on the spec

4) Implement  
- Implement only the resolved task  
- Follow existing code style and patterns in the spec
- Avoid refactors unrelated to the task  

5) Verify  
- Describe how the task was validated  
- If no tests/builds were run, explicitly say why
- run all tests including newly implemented to ensure there are no regressions

6) Prepare review summary  
- Bullet list of changes  
- Risks, tradeoffs, or follow-ups
- include tests and status
- include acceptance criteria met
- TODOS created with related cards

Restrictions:
- Do not modify other tasks without confirming
- Do not reorder plan.md without confirming
- Do not expand scope beyond the resolved task 
- Do not update plan.md unless explicitly instructed and confirming

End state:
- One task fully implemented
- Mark the task as complete `-[x]` in plan.md. This is the only change allowed to plan.md without confirmation.
- Changes ready for PR creation  