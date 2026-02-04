# Feature Review Criteria

Evaluate the plan against each criterion. Mark [x] when satisfied.

## Plan Structure
- [ ] Plan is divided into discrete, well-scoped tasks
- [ ] Worktree setup task exists as Task 1
- [ ] Available Processes are detected and marked (build, lint, test, typecheck)
- [ ] Each task is scoped to a single commit

## Requirements
- [ ] Scope clearly defines what is in and out
- [ ] Acceptance criteria are defined for every task
- [ ] Acceptance criteria are specific and verifiable — not vague

## Dependencies & Risks
- [ ] Inter-task dependencies are explicit
- [ ] Cross-service impacts are identified
- [ ] Risks are documented with mitigation strategies
- [ ] Unknowns are listed and do not block task execution

## Implementation
- [ ] Implementation approach is informed by the actual codebase
- [ ] Testing strategy covers unit, integration, and/or e2e as appropriate
- [ ] Development methodology is defined (TDD, test-alongside, etc.)
- [ ] Rollback strategy exists