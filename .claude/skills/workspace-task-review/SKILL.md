---
name: workspace-task-review
description: Review work done by a task worker against acceptance criteria. Runs only the quality checks that the project supports (build, lint, test, typecheck) as defined in the task context. Invoked as a subagent by workspace-task-execute — not meant to be triggered directly by the user. Receives the task file path, reads it, runs quality checks in the worktree, and writes feedback back to the same file.
---

# Workspace Task Review

Evaluate the work performed by the task worker. The task file path is provided in the prompt. Read it, run quality checks in the worktree, and write feedback back to the file.

## Behavior

### 1. Read the Task File

Read the task file at the path provided in the prompt. Focus on:

- Acceptance criteria (the checklist to verify)
- Subtasks (should all be marked `[x]`)
- Worker Notes (what was done this round)
- Relevant files (what to inspect)
- Context (contains Available Processes — which quality checks to run)

### 2. Verify Subtasks

Check that all subtasks are marked as completed `[x]`. If any are unchecked, note them as incomplete in feedback.

### 3. Run Quality Checks

Read the Available Processes from the task's Context section. **Only run checks for processes marked as available.** Skip any that are not available — do not fail the review for missing processes.

For each available process, execute in this order, stopping on first failure:

1. **build** (if available): Run the project's build command. Verify it completes without errors.
2. **lint** (if available): Run the project's linter. Verify no new warnings or errors were introduced.
3. **typecheck** (if available): Run the project's type checker. Verify no type errors.
4. **test** (if available): Run the project's test suite. Verify all tests pass, including new tests the worker wrote.

Use the commands noted in the Available Processes if specified (e.g. `build: npm run build:prod`). Otherwise, detect from config files (package.json scripts, Makefile, etc.).

If no processes are available at all, skip this step entirely and proceed to acceptance criteria verification.

### 4. Verify Acceptance Criteria

For each acceptance criterion:

1. Inspect the relevant code changes
2. Verify the criterion is actually met, not just superficially addressed
3. Mark `[x]` if satisfied, leave `[ ]` if not

### 5. Write Feedback

Replace the content under Review Feedback in the task file:

```markdown
### Round N
**build**: pass | fail | skipped (details if fail)
**lint**: pass | fail | skipped (details if fail)
**typecheck**: pass | fail | skipped (details if fail)
**test**: pass | fail | skipped (details if fail)

**Acceptance Criteria**:
- [x] Criterion 1 — verified: explanation
- [ ] Criterion 2 — not met: what needs to change

**Issues**:
- Specific, actionable feedback for the worker

**Verdict**: approved | needs-work
```

### Rules

- Do NOT modify any source code, tests, or configuration files
- The current working directory is the workitem worktree (`worktrees/{type}/{name}`). Navigate into the appropriate repo subdirectory before running quality checks.
- When multiple repos are affected, run quality checks in each repo subdirectory separately
- Do NOT modify Worker Notes, Description, Context, or Status
- Only run quality checks that are marked as available in the task context
- If an available process fails, verdict is always `needs-work`
- Provide specific, actionable feedback — not vague suggestions