---
name: workspace-task-execute
description: Orchestrate task execution for a workitem by dispatching worker and reviewer subagents. Use when the user wants to execute tasks, run the implementation pipeline, or start working through a task list. Picks up pending tasks from .claude/workitems/{type}/{name}/tasks/, runs worker+reviewer cycles in the worktree, and marks tasks completed. Supports parallel execution via multiple instances. Logs all output to .claude/workitems/{type}/{name}/logs/.
---

# Workspace Task Execute

Dispatch worker and reviewer subagents to execute tasks from a workitem's task list. Processes tasks sequentially, respecting dependencies and blockers, until all tasks are completed or remaining tasks are blocked.

## Prerequisites

- Task files in `.claude/workitems/{type}/{name}/tasks/` (via workspace-task-generate)
- Claude CLI (`claude`) available in PATH
- The executor validates that task files exist before starting

## Usage

```bash
# By workitem path (type/name)
bash <skill-path>/scripts/task_executor.sh feature/auth-middleware

# Interactive selection (no argument)
bash <skill-path>/scripts/task_executor.sh
```

Set `MAX_TASK_ROUNDS` to control max worker-reviewer rounds per task (default: 5):

```bash
export MAX_TASK_ROUNDS=3
bash <skill-path>/scripts/task_executor.sh feature/auth-middleware
```

## How It Works

1. Validates that task files exist (fails with guidance if workspace-task-generate hasn't been run)
2. Recovers any `in-progress` tasks from a previous crashed run back to `pending`
3. Finds the next `pending` task with all dependencies `completed` and no blockers
4. Marks the task as `in-progress`
5. Resolves the working directory:
   - Task 01 (worktree setup): runs from workspace root
   - All other tasks: reads `.claude/workitems/{type}/{name}/worktree.path` and runs from the worktree
6. Passes the absolute path to the task file in the subagent prompt
7. Subagents read the task file directly, do their work, and write progress/feedback back to the same file
8. Runs worker → reviewer cycle (up to MAX_TASK_ROUNDS)
9. If all acceptance criteria are checked: marks `completed`, moves to next
10. If max rounds reached: leaves as `in-progress` for manual review
11. Stops when no more tasks are available or remaining tasks are blocked
12. Prints execution summary with stats

## Task Status Flow

```
pending → in-progress → completed
              ↑
              └── reviewer returns needs-work → worker iterates
```

On crash recovery: `in-progress → pending` (automatic on next run)

## Logging

All output is logged to `.claude/workitems/{type}/{name}/logs/execution-{timestamp}.log`. Each run creates a new log file. Output goes to both stdout and the log file.

## Execution Summary

After all tasks are processed, the executor prints:

- Tasks completed, failed, skipped (blocked)
- Remaining pending tasks
- Total duration
- Path to the log file

## Parallel Execution

Multiple executor instances can run simultaneously. Each instance locks a task by marking it `in-progress` before starting. Other instances skip `in-progress` tasks.

## Cross-Platform

The script runs on both macOS and Linux. It uses a `sedi` wrapper for cross-platform `sed -i` and avoids `grep -P` (PCRE) in favor of `grep -oE` (POSIX ERE).
