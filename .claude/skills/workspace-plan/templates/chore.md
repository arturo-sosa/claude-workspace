# Chore: <n>

## Brief
<!-- What needs to be done and why -->

## Motivation
<!-- Why this chore is needed now: dependency updates, CI changes, tooling, cleanup, etc. -->

## Affected Repos
<!-- Which repos are affected -->

## Scope

### In Scope
<!-- What is included -->

### Out of Scope
<!-- What is explicitly excluded -->

## Risks
<!-- Risk of breaking builds, CI, or developer workflows -->

## Cross-Service Impacts
<!-- Effects on other services, pipelines, or environments -->

## Unknowns
<!-- Open questions -->

## Available Processes
<!-- Detected from the codebase. Mark which processes exist in this project. -->

- [ ] build
- [ ] lint
- [ ] test
- [ ] typecheck

<!-- Add commands if non-standard, e.g. build: npm run build:prod -->

## Testing Strategy
<!-- How to verify the chore was done correctly: build passes, CI green, etc. -->

## Tasks

### Task 1: Worktree Setup
- **Description**: Create chore branch, set up worktree at worktrees/chore/<n> with a subdirectory per affected repo, install dependencies, verify build passes, and write the worktree path to worktree.path
- **Dependencies**: None
- **Acceptance Criteria**:
  - Chore branch exists in affected repos
  - Worktree created with repo subdirectories
  - Dependencies installed
  - Build passes
  - worktree.path written with single path to worktrees/{type}/{name}

<!-- Add tasks as they are discovered during the interview -->

## Rollback Strategy
<!-- How to revert if the chore causes issues -->