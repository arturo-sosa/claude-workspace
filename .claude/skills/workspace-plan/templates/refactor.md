# Refactor: <n>

## Brief
<!-- Original brief provided by the user -->

## Current State
<!-- How the code/system works today and why it needs refactoring -->

## Motivation
<!-- Why this refactor is needed: tech debt, performance, maintainability, etc. -->

## Desired State
<!-- What the code/system should look like after refactoring -->

## Affected Repos
<!-- Which repos are affected and how -->

## Scope

### In Scope
<!-- What is included in the refactor -->

### Out of Scope
<!-- What is explicitly excluded — avoid scope creep -->

## Risks
<!-- Risk of regressions, behavioral changes, performance impacts -->

## Cross-Service Impacts
<!-- Effects on other services or systems -->

## Unknowns
<!-- Open questions, things that need further investigation -->

## Assumptions & Constraints
<!-- What we're assuming to be true, hard constraints -->

## Available Processes
<!-- Detected from the codebase. Mark which processes exist in this project. -->

- [ ] build
- [ ] lint
- [ ] test
- [ ] typecheck

<!-- Add commands if non-standard, e.g. build: npm run build:prod -->

## Testing Strategy
<!-- How to verify behavior is preserved after refactoring, regression tests -->

## Tasks

### Task 1: Worktree Setup
- **Description**: Create refactor branch, set up worktree at worktrees/refactor/<n>/ with a subdirectory per affected repo, install dependencies, verify build passes, and write the worktree path to worktree.path
- **Dependencies**: None
- **Acceptance Criteria**:
  - Refactor branch exists in affected repos
  - Worktree created with repo subdirectories
  - Dependencies installed
  - Build passes
  - worktree.path written with single path to worktrees/{type}/{name}/

<!-- Add tasks as they are discovered during the interview -->

## Rollback Strategy
<!-- How to revert if the refactor introduces issues -->