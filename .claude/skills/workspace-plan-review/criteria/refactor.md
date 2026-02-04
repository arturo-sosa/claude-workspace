# Refactor Review Criteria

Evaluate the plan against each criterion. Mark [x] when satisfied.

## Justification
- [ ] Current state is clearly documented
- [ ] Motivation for the refactor is concrete — not vague "clean up"
- [ ] Desired state is described with enough detail to implement

## Behavior Preservation
- [ ] Scope explicitly excludes behavioral changes
- [ ] Testing strategy includes verification that existing behavior is preserved
- [ ] Existing tests are identified and will be maintained or migrated

## Plan Structure
- [ ] Plan is divided into discrete, incremental tasks
- [ ] Worktree setup task exists as Task 1
- [ ] Available Processes are detected and marked (build, lint, test, typecheck)
- [ ] Each task is scoped to a single commit
- [ ] Tasks are ordered to keep the codebase functional between steps
- [ ] Inter-task dependencies are explicit

## Risks
- [ ] Risk of regressions is assessed
- [ ] Risk of scope creep is addressed — refactors tend to expand
- [ ] Cross-service impacts are identified
- [ ] Rollback strategy exists