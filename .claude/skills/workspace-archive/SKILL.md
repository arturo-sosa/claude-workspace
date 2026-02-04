---
name: workspace-archive
description: Archive a completed workitem. Generates a report, updates repo documentation where needed, removes worktrees, and moves the workitem to archive. Use when a workitem is finished and ready to be closed. Triggers on requests to archive, close, or finish a workitem.
---

# Workspace Archive

Archive a completed workitem by generating documentation, cleaning up worktrees, and moving the workitem to the archive.

## Prerequisites

- All tasks in the workitem must be `completed`
- Claude CLI (`claude`) available in PATH

## Usage

```bash
# By workitem path
bash <skill-path>/scripts/archive.sh feature/auth-middleware

# Interactive selection
bash <skill-path>/scripts/archive.sh
```

## How It Works

### 1. Validate Completion

Verify all tasks are `completed`. If any are `pending` or `in-progress`, abort with a summary of incomplete tasks.

### 2. Generate Workitem Report

Launch a subagent that reads the plan, all task files (including worker notes and review feedback), and generates a consolidated report at `.claude/workitems/{type}/{name}/report.md`.

The report covers:
- Summary of what was done
- Repos and files affected
- Key decisions made during implementation
- Issues encountered and how they were resolved
- Testing summary
- Any follow-up items or tech debt introduced

### 3. Per-Repo Documentation

For each repo in the worktree, launch a subagent that:

1. Reads the workitem report
2. Reads the diff of changes in that repo's worktree
3. Generates `docs/{type}-{name}.md` in the worktree with what is relevant to that repo
4. Evaluates whether the repo's `CLAUDE.md` needs updates — only for structural changes:
    - Infrastructure or architecture changes
    - New or removed dependencies
    - New conventions or patterns introduced
    - API changes (endpoints, contracts, schemas)
    - Configuration changes
    - NOT feature summaries, NOT bug descriptions
5. If `CLAUDE.md` needs updates, applies them
6. Commits the documentation changes in the worktree

### 4. Remove Worktrees

Runs `workspace-worktree remove {type}/{name}` to clean up git worktrees. Branches are kept — they contain the commits.

### 5. Move to Archive

Moves `.claude/workitems/{type}/{name}/` to `.claude/workitems/archive/{type}/{name}/`.

The archive preserves:
- plan.md
- review-criteria.md
- report.md
- tasks/
- logs/