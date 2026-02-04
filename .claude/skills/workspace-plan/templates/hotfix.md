# Hotfix: <n>

## Brief
<!-- What is broken and the urgency -->

## Symptom
<!-- Observable behavior that is incorrect -->

## Severity
<!-- Impact level: critical, high, medium -->

## Affected Users/Systems
<!-- Who/what is impacted right now -->

## Root Cause
<!-- The underlying cause (if known, otherwise mark as unknown) -->

## Affected Repos
<!-- Which repos are affected -->

## Solution
<!-- Minimal fix to resolve the issue — keep scope as small as possible -->

## Risks
<!-- Risk of the fix introducing regressions -->

## Cross-Service Impacts
<!-- Effects on other services or systems -->

## Available Processes
<!-- Detected from the codebase. Mark which processes exist in this project. -->

- [ ] build
- [ ] lint
- [ ] test
- [ ] typecheck

<!-- Add commands if non-standard, e.g. build: npm run build:prod -->

## Testing Strategy
<!-- Minimum tests needed to validate the fix without delaying deployment -->

## Tasks

### Task 1: Worktree Setup
- **Description**: Create hotfix branch, set up worktree at worktrees/hotfix/<n>/ with a subdirectory per affected repo, install dependencies, verify build passes, and write the worktree path to worktree.path
- **Dependencies**: None
- **Acceptance Criteria**:
  - Hotfix branch exists in affected repos
  - Worktree created with repo subdirectories
  - Dependencies installed
  - Build passes
  - worktree.path written with single path to worktrees/{type}/{name}/

<!-- Add tasks as they are discovered during the interview -->

## Rollback Strategy
<!-- Immediate rollback plan if the fix fails in production -->