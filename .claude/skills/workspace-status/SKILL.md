---
name: workspace-status
description: Show progress across all workitems in the workspace. Use when the user asks for status, progress, overview, or dashboard of workitems. Shows each workitem's type, review status, task progress, and worktree state. Can also show detailed status for a specific workitem.
---

# Workspace Status

Show progress across all workitems or detailed status for a specific one.

## Trigger

User requests like:
- "show status"
- "what's the progress?"
- "status of feature/auth-middleware"
- "workspace overview"

## Status Views

### Overview (all workitems)

When no specific workitem is mentioned, show a summary of all workitems.

### Detail (specific workitem)

When a workitem is specified, show detailed information about it.

## Gathering Status Information

### 1. Find Workitems

List directories in `.claude/workitems/{type}/` for each type (feature, bugfix, refactor, hotfix, chore). Skip the `archive/` directory.

**Empty State**: If no active workitems exist:
- Display: "No active workitems. Would you like to create one now?"
- If user accepts, delegate to workspace-plan skill
- If user declines, exit gracefully (e.g., "Use workspace-plan to create a workitem when ready.")

### 2. For Each Workitem, Determine:

**Phase** (current stage):
- `done` — all tasks completed
- `executing` — has tasks, some not completed
- `reviewed` — plan approved, no tasks yet
- `reviewing` — has review-criteria.md but plan not approved
- `planned` — has plan.md only
- `empty` — no plan yet

**Review Status**:
- Check plan.md for `[x] Reviewed` → "approved"
- Check for `## Review Status` section → "in review"
- Check if review-criteria.md exists → "in review"
- Otherwise → "not reviewed"

**Task Progress** (if tasks/ directory exists):
- Count total task files (*.md)
- Count by status: read each task file's `## Status` section
  - `pending`, `in-progress`, `completed`
- Format: `{completed}/{total} tasks`

**Worktree Status** (if worktree.path exists):
- Read the path from worktree.path
- Check if directory exists
- Count repo subdirectories (contain .git file)
- Check each for uncommitted changes (`git status --porcelain`)
- Format: `{n} repos (clean)` or `{n} repos ({m} dirty)`

## Output Format

### Overview

```
=========================================
  Workspace Status
=========================================

  ✅  feature      auth-middleware          done         3/3 tasks
  🔧  feature      user-profile             executing    1/4 tasks
  📋  bugfix       login-timeout            reviewed     no tasks
  🔍  refactor     api-cleanup              reviewing    no tasks
  📝  hotfix       memory-leak              planned      no tasks

```

**Phase icons**:
- ✅ done
- 🔧 executing
- 📋 reviewed
- 🔍 reviewing
- 📝 planned
- ❓ unknown

### Detail

```
=========================================
  feature/auth-middleware
=========================================

  Phase:    executing
  Review:   approved
  Worktree: 2 repos (1 dirty)

  Tasks: 2/4 completed

    ✅ 01-setup-worktree
    ✅ 02-add-middleware
    🔄 03-write-tests
    ⏳ 04-update-docs

  Logs: 3 file(s)
    Latest: .claude/workitems/feature/auth-middleware/logs/execution-20240205-1423.log
```

**Task status icons**:
- ✅ completed
- 🔄 in-progress
- ⏳ pending

## Reading Task Status

To get a task's status, read the file and find the `## Status` section:

```markdown
## Status
Status: pending
```

The status is the value after `Status: ` on the line immediately following `## Status`. Valid values are: `pending`, `in-progress`, `completed`.

## File Locations

- Workitems: `.claude/workitems/{type}/{name}/`
- Plan: `.claude/workitems/{type}/{name}/plan.md`
- Review criteria: `.claude/workitems/{type}/{name}/review-criteria.md`
- Tasks: `.claude/workitems/{type}/{name}/tasks/*.md`
- Worktree path: `.claude/workitems/{type}/{name}/worktree.path`
- Logs: `.claude/workitems/{type}/{name}/logs/`
