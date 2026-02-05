---
name: workspace-archive
description: Archive a completed workitem. Generates a report, updates repo documentation where needed, removes worktrees, and moves the workitem to archive. Use when a workitem is finished and ready to be closed. Triggers on requests to archive, close, or finish a workitem.
---

# Workspace Archive

Archive a completed workitem by generating documentation, cleaning up worktrees, and moving to the archive.

## Trigger

User requests like:
- "archive feature/auth-middleware"
- "close the workitem"
- "finish bugfix/login-timeout"

## Prerequisites

- All tasks in the workitem must be `completed`

## Archive Steps

### 1. Identify the Workitem

If not specified, list available workitems (those with tasks) and ask the user to choose.

### 2. Validate Completion

Read all task files in `.claude/workitems/{type}/{name}/tasks/`. Check each file's `## Status` section.

If any task is not `completed`:
- Report which tasks are incomplete
- Abort the archive

```
Cannot archive — incomplete tasks:
  03-write-tests.md: in-progress
  04-update-docs.md: pending
```

### 3. Generate Workitem Report

Read the plan and all task files, paying attention to Worker Notes and Review Feedback (what actually happened).

Write a report to `.claude/workitems/{type}/{name}/report.md`:

```markdown
# Report: {type}/{name}

## Summary
What was accomplished in 2-3 sentences.

## Changes
For each repo affected:
- Key changes (files created/modified)
- What was added/removed/changed

## Decisions
Key technical decisions made during implementation and why.

## Issues
Problems encountered and how they were resolved.

## Testing
What was tested and how.

## Follow-Up
Any tech debt introduced, known limitations, or future work items.
```

Base everything on what Worker Notes and Review Feedback say actually happened, not what the plan said should happen.

### 4. Per-Repo Documentation

Read the worktree path from `.claude/workitems/{type}/{name}/worktree.path`.

For each repo subdirectory in the worktree:

1. **Create repo-specific docs**:
   - Create `docs/{type}-{name}.md` in the worktree
   - Include only what's relevant to this repo:
     - What changed and why
     - Files affected
     - New patterns or conventions
     - Testing details

2. **Evaluate CLAUDE.md updates**:
   - Only update for **structural changes**:
     - Infrastructure or architecture changes
     - New or removed dependencies
     - New conventions or patterns
     - API changes (endpoints, contracts, schemas)
     - Configuration changes
   - Do NOT add feature summaries, bug descriptions, or changelog entries
   - If no structural changes, do NOT modify CLAUDE.md

3. **Commit documentation**:
   - Use `workspace-commit` or commit directly with proper identity
   - Message: `docs: {type}/{name} documentation`

### 5. Remove Worktrees

Use `workspace-worktree` remove operation:
- Remove all repo worktrees for this workitem
- Keep branches (they contain the commits)
- Clean up the worktree directory

### 6. Move to Archive

```bash
mkdir -p .claude/workitems/archive/{type}
mv .claude/workitems/{type}/{name} .claude/workitems/archive/{type}/{name}
```

Clean up empty type directory:
```bash
rmdir .claude/workitems/{type} 2>/dev/null || true
```

### 7. Report Completion

```
Archive Complete
================
Workitem: feature/auth-middleware
Report:   .claude/workitems/archive/feature/auth-middleware/report.md
Archive:  .claude/workitems/archive/feature/auth-middleware/
```

## Archive Contents

The archive preserves:
- `plan.md` — original plan
- `review-criteria.md` — review checklist
- `report.md` — generated completion report
- `tasks/` — all task files with worker notes and review feedback
- `logs/` — execution logs

## File Locations

- Active workitems: `.claude/workitems/{type}/{name}/`
- Archived workitems: `.claude/workitems/archive/{type}/{name}/`
- Worktrees: `worktrees/{type}/{name}/`

## Rules

- Cannot archive if any tasks are incomplete
- Report is based on actual work (worker notes), not planned work
- CLAUDE.md updates are only for structural changes
- Branches are kept after archive (contain commit history)
- Logs are preserved for debugging/auditing
