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

If not specified, list available workitems (those with tasks) in `.claude/workitems/{type}/{name}/`.

**Empty State**: If no workitems exist (or none have tasks):
- Display: "No workitems found. Would you like to create one now?"
- If user accepts, delegate to workspace-plan skill
- If user declines, exit gracefully

If workitems exist, ask the user to choose one.

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

### 3. Verify Branch is Pushed

Read the worktree path from `.claude/workitems/{type}/{name}/worktree.path`.

For each repo subdirectory in the worktree:

1. **Check if branch is pushed to remote**:
   ```bash
   cd worktrees/{type}/{name}/{repo}
   git rev-parse --abbrev-ref HEAD  # Get current branch
   git fetch origin
   git rev-list HEAD...origin/{branch} --count  # Check for unpushed commits
   ```

2. **Auto-push if needed**:
   - If there are unpushed commits, push the branch:
     ```bash
     git push -u origin {branch}
     ```
   - Report what was pushed:
     ```
     Pushed branch {type}/{name} to origin for {repo}
     ```

3. **Continue with archive** after all branches are pushed

This ensures all work is preserved on the remote before archiving locally.

### 4. Generate Workitem Report

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

### 5. Per-Repo Documentation

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

   CLAUDE.md describes the codebase structure and conventions for AI assistants. Only update it for changes that affect how an AI should navigate or work with the codebase.

   **DO update CLAUDE.md for**:
   - New top-level directories (e.g., added `migrations/` folder)
   - New external service integrations (e.g., added Redis caching layer)
   - New build targets or commands (e.g., added `npm run e2e`)
   - Breaking API changes (e.g., changed auth endpoint from `/login` to `/auth/login`)
   - New conventions or patterns (e.g., introduced repository pattern for data access)

   **DO NOT update CLAUDE.md for**:
   - New files within existing structure (e.g., added `UserService.ts` to `services/`)
   - Internal refactors (e.g., split large function into smaller helpers)
   - Bug fixes (e.g., fixed null pointer in auth handler)
   - Test additions (e.g., added unit tests for UserService)
   - Feature implementations that follow existing patterns (e.g., added new API endpoint following existing conventions)

   If no structural changes, do NOT modify CLAUDE.md

3. **Commit documentation**:
   - Use `workspace-commit` or commit directly with proper identity
   - Message: `docs: {type}/{name} documentation`

### 6. Remove Worktrees

Use `workspace-worktree` remove operation:
- Remove all repo worktrees for this workitem
- Keep branches (they contain the commits)
- Clean up the worktree directory

### 7. Move to Archive

```bash
mkdir -p .claude/workitems/archive/{type}
mv .claude/workitems/{type}/{name} .claude/workitems/archive/{type}/{name}
```

Clean up empty type directory:
```bash
rmdir .claude/workitems/{type} 2>/dev/null || true
```

### 8. Report Completion

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
- Worktrees: `worktrees/{type}/{name}`

## Rules

- Cannot archive if any tasks are incomplete
- Report is based on actual work (worker notes), not planned work
- CLAUDE.md updates are only for structural changes
- Branches are kept after archive (contain commit history)
- Logs are preserved for debugging/auditing
