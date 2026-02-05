# Feature: <n>

## Brief
<!-- Original brief provided by the user -->

## Scope

### In Scope
<!-- What is included -->

### Out of Scope
<!-- What is explicitly excluded -->

## Risks
<!-- Technical risks, dependency risks, timeline risks -->

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
<!-- Types of tests needed (unit, integration, e2e), coverage expectations, existing test patterns -->

## Development Methodology
<!-- TDD, BDD, or other approach. Whether tests are written before or alongside implementation -->

## Tasks

### Task 1: Worktree Setup
- **Description**: Create feature branch, set up worktree at worktrees/feature/<n> with a subdirectory per affected repo, install dependencies, verify build passes, and write the worktree path to worktree.path
- **Dependencies**: None
- **Acceptance Criteria**:
  - Feature branch exists in affected repos
  - Worktree created with repo subdirectories
  - Dependencies installed
  - Build passes
  - worktree.path written with single path to worktrees/{type}/{name}

<!-- Add tasks as they are discovered during the interview -->

## Rollback Strategy
<!-- How to revert if something fails -->