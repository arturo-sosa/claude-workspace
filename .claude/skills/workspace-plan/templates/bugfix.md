# Bugfix: <n>

## Brief
<!-- Original bug report or description -->

## Symptom
<!-- Observable behavior that is incorrect -->

## Reproduction Steps
<!-- How to reproduce the bug -->

## Investigation
<!-- Findings from investigating the bug -->

## Root Cause
<!-- The underlying cause of the bug -->

## Affected Repos
<!-- Which repos are affected and how -->

## Solution
<!-- Proposed fix and rationale -->

## Prevention
<!-- How to prevent this class of bug in the future (tests, linting rules, etc.) -->

## Risks
<!-- Risk of the fix introducing regressions or side effects -->

## Cross-Service Impacts
<!-- Effects on other services or systems -->

## Unknowns
<!-- Open questions, things that need further investigation -->

## Available Processes
<!-- Detected from the codebase. Mark which processes exist in this project. -->

- [ ] build
- [ ] lint
- [ ] test
- [ ] typecheck

<!-- Add commands if non-standard, e.g. build: npm run build:prod -->

## Testing Strategy
<!-- Types of tests needed, regression tests, coverage expectations -->

## Tasks

### Task 1: Worktree Setup
- **Description**: Create bugfix branch, set up worktree at worktrees/bugfix/<n>/ with a subdirectory per affected repo, install dependencies, verify build passes, and write the worktree path to worktree.path
- **Dependencies**: None
- **Acceptance Criteria**:
  - Bugfix branch exists in affected repos
  - Worktree created with repo subdirectories
  - Dependencies installed
  - Build passes
  - worktree.path written with single path to worktrees/{type}/{name}/

<!-- Add tasks as they are discovered during the interview -->

## Rollback Strategy
<!-- How to revert if the fix causes issues -->