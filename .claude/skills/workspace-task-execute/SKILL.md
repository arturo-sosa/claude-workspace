---
name: workspace-task-execute
description: Orchestrate task execution for a workitem by dispatching worker and reviewer subagents. Use when the user wants to execute tasks, run the implementation pipeline, or start working through a task list. Picks up pending tasks from .claude/workitems/{type}/{name}/tasks/, runs worker+reviewer cycles in the worktree, and marks tasks completed. Supports parallel execution via multiple instances. Logs all output to .claude/workitems/{type}/{name}/logs/.
---

# Workspace Task Execute

Orchestrate task execution by spawning worker and reviewer subagents using the Task tool. Process tasks sequentially, respecting dependencies, until all tasks are completed or blocked.

## Prerequisites

- Task files in `.claude/workitems/{type}/{name}/tasks/` (via workspace-task-generate)
- The `workspace-task-work` and `workspace-task-review` skills available

## Trigger

User requests like:
- "execute tasks for feature/auth-middleware"
- "run the tasks"
- "start working on bugfix/login-timeout"

## Orchestration Steps

When this skill is invoked, follow these steps:

### 1. Identify the Workitem

If not specified, list available workitems in `.claude/workitems/{type}/{name}/`.

**Empty State**: If no workitems exist:
- Display: "No workitems found. Would you like to create one now?"
- If user accepts, delegate to workspace-plan skill
- If user declines, exit gracefully

If workitems exist, ask the user to choose one.

### 2. Validate Task Files Exist

Check that `.claude/workitems/{type}/{name}/tasks/` contains task files (*.md). If empty, tell the user to run `workspace-task-generate` first.

### 3. Crash Recovery

Read all task files. For any with `Status: in-progress`, assess progress before deciding how to proceed.

#### 3a. Clean Up Stale Locks

Before assessing progress, check for stale lock files in the tasks directory:

1. Find all `*.lock` files in `.claude/workitems/{type}/{name}/tasks/`
2. Read the timestamp from each lock file
3. Delete any lock file where the timestamp is older than 30 minutes

Report any stale locks cleaned:
```
Stale lock cleanup:
- Deleted 01-setup.md.lock (45 minutes old)
```

#### 3b. Check for Progress

For each `in-progress` task, look for evidence of work done:

1. **Subtasks**: Count how many subtasks are marked `[x]` vs `[ ]`
2. **Worker Notes**: Check if there are any `### Round N` entries documenting work
3. **Git commits**: In the worktree, check `git log --oneline -10` for commits that might relate to this task

#### 3c. Decide Recovery Action

**If progress exists** (any subtasks done, worker notes present, or related commits found):
- Keep `Status: in-progress`
- Resume the worker-reviewer cycle where it left off
- The worker will read existing subtasks and worker notes to understand what's done

**If no progress** (all subtasks unchecked, no worker notes, no related commits):
- Reset to `Status: pending`
- Task will be picked up fresh in the main loop

Report recovery decisions to the user:
```
Crash recovery:
- Task 03: resuming (2/5 subtasks done, worker notes present)
- Task 04: reset to pending (no progress found)
```

### 4. Process Tasks Loop

Repeat until no pending tasks remain:

#### 4a. Find Next Task

Read all task files and find the first one where:
- `Status: pending`
- All tasks listed in `## Dependencies` have `Status: completed`
- No active blockers in `## Blockers` section

Task files are numbered (01-task-name.md, 02-task-name.md, etc.) — process in order.

If no eligible tasks found:
- If tasks remain but all are blocked → report which tasks are blocked and why
- If all tasks completed → proceed to step 5

#### 4b. Determine Working Directory

- **Task 01** (worktree setup): working directory is the workspace root
- **All other tasks**: read `.claude/workitems/{type}/{name}/worktree.path` to get the worktree path (e.g., `worktrees/feature/auth-middleware`)

#### 4c. Acquire Lock and Mark In-Progress

Before claiming the task:

1. **Generate instance identifier** (if not already generated): `{ISO-timestamp}-{random-6-chars}`
2. **Check for existing lock**: Read `{task-file}.lock` if it exists
3. **Conflict check**:
   - If locked by another instance (different identifier) and recent (within 30 min) → skip to next task
   - If locked by this instance → proceed (resuming work)
   - If lock is stale (older than 30 min) → delete it and proceed
4. **Create lock file**: Write instance identifier to `{task-file}.lock`
5. **Mark in-progress**: Edit the task file to set `Status: in-progress`

The lock must be created **before** writing `Status: in-progress` to prevent race conditions.

#### 4d. Worker-Reviewer Cycle

Run up to 5 rounds of worker → reviewer:

**Spawn Worker** using Task tool:
```
Use the Task tool with subagent_type "general-purpose" to spawn a worker.

Prompt:
"You are a task worker. Your working directory is {work_dir}.

Read the task file at {absolute_path_to_task_file}.

Follow the workspace-task-work skill instructions:
1. Read the task file — it contains everything needed (description, files, subtasks, acceptance criteria, context)
2. If Review Feedback has content, address every point first
3. For Task 01: use the worktree.sh script to create worktrees, do NOT run git commands directly
4. Navigate into the appropriate repo subdirectory before making changes
5. Work through subtasks in order, marking each [x] when done
6. Append your work log to the Worker Notes section

Rules:
- Do NOT mark acceptance criteria — that's the reviewer's job
- Do NOT change Status — that's the executor's job
- Do NOT modify Review Feedback"
```

**Spawn Reviewer** using Task tool:
```
Use the Task tool with subagent_type "general-purpose" to spawn a reviewer.

Prompt:
"You are a task reviewer. Your working directory is {work_dir}.

Read the task file at {absolute_path_to_task_file}.

Follow the workspace-task-review skill instructions:
1. Read the task file — focus on acceptance criteria, subtasks, worker notes, and available processes
2. Verify all subtasks are marked [x]
3. Run only the quality checks listed as available in the Context section (build, lint, typecheck, test)
4. Verify each acceptance criterion is actually met
5. Mark [x] for satisfied criteria, leave [ ] for unmet ones
6. Write feedback under Review Feedback with verdict: approved or needs-work

Rules:
- Do NOT modify source code
- Only run quality checks that are available
- Provide specific, actionable feedback"
```

**Check Verdict**: After reviewer completes, read the task file. If Review Feedback contains `**Verdict**: approved` and all acceptance criteria are `[x]`:
- Mark `Status: completed`
- **Delete the lock file** (`{task-file}.lock`)
- Use `workspace-commit` to commit changes (see Committing below)
- Proceed to next task

If `needs-work`:
- Spawn worker again (next round)
- After 5 rounds without approval:
  - Leave as `in-progress` for manual review
  - **Delete the lock file** (release for other instances or manual intervention)

### 5. Execution Summary

After all tasks processed, report:
- Tasks completed
- Tasks still pending
- Tasks blocked (and why)
- Tasks left in-progress (exceeded max rounds)

## Task Status Flow

```
pending → in-progress → completed
              ↑
              └── reviewer returns needs-work → worker iterates
```

On crash recovery:
- If progress found → stays `in-progress`, resumes worker-reviewer cycle
- If no progress → reset to `pending`

## Parallel Execution

You can run multiple worker-reviewer cycles in parallel for **independent tasks** (tasks with no dependency relationship). Use multiple Task tool calls in a single message to spawn them simultaneously.

However, tasks with dependencies must wait for their dependencies to complete first.

## Locking

When multiple executor instances run in parallel, lock files prevent race conditions where two instances try to claim the same task.

### Lock File Format

Lock files use the naming pattern `{task-file}.lock`:
- Task file: `01-setup.md`
- Lock file: `01-setup.md.lock`

Lock files are stored in the same directory as task files: `.claude/workitems/{type}/{name}/tasks/`

### Lock File Contents

Each lock file contains a single line with a timestamp and instance identifier:
```
2026-02-05T10:30:00Z-abc123
```

Format: `{ISO-8601-timestamp}-{random-6-char-suffix}`

The instance identifier is generated once when the executor starts and used for all locks it creates during that session.

### Conflict Detection

Before claiming a task, check for an existing lock:

1. Check if `{task-file}.lock` exists
2. If it exists, read its contents
3. Parse the timestamp from the lock file
4. **If the lock is from this instance** (same identifier): safe to proceed
5. **If the lock is from another instance AND timestamp is within 30 minutes**: skip this task
6. **If the lock is from another instance AND timestamp is older than 30 minutes**: delete the stale lock and proceed

### Skip Behavior

If a task is locked by another recent instance:
- Log: `Task 03 locked by another instance, skipping`
- Move to the next eligible task in the loop
- Do not wait or retry — the other instance is handling it

### Lock Removal

Remove the lock file when:
1. **Task completed**: Delete lock after marking `Status: completed` and committing
2. **Task abandoned**: Delete lock after exceeding max rounds (5) and leaving for manual review
3. **Crash recovery**: Stale locks (older than 30 min) are deleted during the recovery phase

Always delete the lock file before moving to the next task to allow other instances to claim it if needed.

## Committing

After a task is approved, use the `workspace-commit` skill to commit changes. Follow the skill's instructions:

1. Read git identity from `config.yaml` (falls back to system config)
2. Stage and commit changes in each repo subdirectory
3. Use conventional commit format: `{type}: {short description}`

The commit message type is derived from the task content (feat, fix, refactor, chore, docs, test, style), not the workitem type.

## File Locations

- Task files: `.claude/workitems/{type}/{name}/tasks/*.md`
- Worktree path: `.claude/workitems/{type}/{name}/worktree.path`
- Logs: `.claude/workitems/{type}/{name}/logs/`
