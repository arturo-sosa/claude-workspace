---
name: workspace-task-work
description: Execute a single task by implementing code, tests, documentation, and configuration changes. Invoked as a subagent by workspace-task-execute — not meant to be triggered directly by the user. Receives the task file path, reads it, implements the work in the worktree, and writes progress back to the same file.
---

# Workspace Task Work

Implement a single task. The task file path is provided in the prompt. Read it, execute the work in the worktree, and write progress back to the file.

## Behavior

### 1. Read the Task File

Read the task file at the path provided in the prompt. It contains everything needed:

- Description of what to accomplish
- Relevant files (create, modify, reference)
- Subtasks in execution order
- Acceptance criteria
- Full context from the plan

Do NOT read the plan file or other task files. The task is self-contained.

### 2. Review Feedback (if any)

If the Review Feedback section has content, this is a subsequent round. Address every point before continuing with remaining work.

### 3. Task 01: Worktree Setup

If this is Task 01 (worktree setup), do NOT run git commands directly. Instead:

1. Read the plan to identify which repos are affected
2. Run the worktree setup script with those repos:
   ```bash
   bash .claude/skills/workspace-worktree/scripts/worktree.sh create {type}/{name} {repo1} {repo2} ...
   ```
3. Verify the script output — it reports success/failure per repo
4. Mark subtasks complete based on the script output
5. Log the results in Worker Notes

### 4. Execute

The current working directory is the workitem worktree (`worktrees/{type}/{name}/`). Each affected repo is a subdirectory (e.g. `frontend/`, `backend-api/`). Navigate into the appropriate repo subdirectory before running commands or editing files.

Work through subtasks in order:

1. Read reference files first to understand existing patterns and conventions
2. Navigate to the correct repo subdirectory for each change
3. Implement changes following the codebase's existing style
4. Create new files where specified
5. Modify existing files as listed
6. Write tests according to the testing strategy and development methodology noted in the task context
7. Mark each subtask as `[x]` when completed in the task file

When a task spans multiple repos, work on one repo at a time. Use the Relevant Files section to know which repo each file belongs to (paths are prefixed with the repo name).

### 5. Log Work

After each round, append to the Worker Notes section of the task file:

```markdown
### Round N
- What was implemented
- Files created/modified
- Tests written
- Any issues encountered
```

### Rules

- Follow existing codebase patterns — do not introduce new patterns without reason
- All implementation work happens in the current working directory (the worktree)
- Do NOT mark acceptance criteria checkboxes — that is the reviewer's job
- Do NOT change the Status field — that is the executor's job
- Do NOT modify Review Feedback — that is the reviewer's section
- If a blocker is encountered that prevents progress, note it in Worker Notes and stop