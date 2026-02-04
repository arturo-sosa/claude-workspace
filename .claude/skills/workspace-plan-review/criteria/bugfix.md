# Bugfix Review Criteria

Evaluate the plan against each criterion. Mark [x] when satisfied.

## Diagnosis
- [ ] Symptom is clearly described
- [ ] Reproduction steps are documented and reproducible
- [ ] Investigation findings are documented
- [ ] Root cause is identified and explained — not just the symptom

## Solution
- [ ] Proposed solution addresses the root cause, not just the symptom
- [ ] Solution scope is minimal — no unrelated changes
- [ ] Affected repos are identified

## Prevention
- [ ] Prevention measures are defined (new tests, linting rules, guards, etc.)
- [ ] Regression tests are part of the testing strategy

## Plan Structure
- [ ] Plan is divided into discrete tasks
- [ ] Worktree setup task exists as Task 1
- [ ] Available Processes are detected and marked (build, lint, test, typecheck)
- [ ] Inter-task dependencies are explicit
- [ ] Acceptance criteria are defined for every task

## Risks
- [ ] Risk of the fix introducing regressions is assessed
- [ ] Cross-service impacts are identified
- [ ] Rollback strategy exists