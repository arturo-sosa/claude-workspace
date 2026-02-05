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

If not specified, list available workitems and ask the user to choose:
```
.claude/workitems/{type}/{name}/
```

### 2. Validate Task Files Exist

Check that `.claude/workitems/{type}/{name}/tasks/` contains task files (*.md). If empty, tell the user to run `workspace-task-generate` first.

### 3. Crash Recovery

Read all task files. For any with `Status: in-progress`, assess progress before deciding how to proceed:

#### 3a. Check for Progress

For each `in-progress` task, look for evidence of work done:

1. **Subtasks**: Count how many subtasks are marked `[x]` vs `[ ]`
2. **Worker Notes**: Check if there are any `### Round N` entries documenting work
3. **Git commits**: In the worktree, check `git log --oneline -10` for commits that might relate to this task

#### 3b. Decide Recovery Action

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
- **All other tasks**: read `.claude/workitems/{type}/{name}/worktree.path` to get the worktree path (e.g., `worktrees/feature/auth-middleware/`)

#### 4c. Mark In-Progress

Edit the task file to set `Status: in-progress`.

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
- Use `workspace-commit` to commit changes (see Committing below)
- Proceed to next task

If `needs-work`:
- Spawn worker again (next round)
- After 5 rounds without approval, leave as `in-progress` for manual review

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
