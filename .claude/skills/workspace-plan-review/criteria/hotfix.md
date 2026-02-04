# Hotfix Review Criteria

Evaluate the plan against each criterion. Mark [x] when satisfied.

## Urgency & Impact
- [ ] Severity is assessed (critical, high, medium)
- [ ] Affected users/systems are identified
- [ ] Symptom is clearly described

## Solution
- [ ] Root cause is identified (or explicitly marked as unknown with justification)
- [ ] Solution is the minimum viable fix — no scope creep
- [ ] Solution does not introduce new features or refactoring

## Plan Structure
- [ ] Plan has minimal number of tasks — hotfixes should be fast
- [ ] Worktree setup task exists as Task 1
- [ ] Available Processes are detected and marked (build, lint, test, typecheck)
- [ ] Acceptance criteria are defined for every task

## Safety
- [ ] Risk of the fix introducing regressions is assessed
- [ ] Cross-service impacts are identified
- [ ] Testing strategy is sufficient to validate the fix without delaying deployment
- [ ] Immediate rollback plan is defined and actionable