---
name: workspace-task-generate
description: Generate self-contained task files from a reviewed workitem plan. Use when the user wants to break down a plan into executable task files or prepare a workitem for implementation. Reads a plan from .claude/workitems/{type}/{name}/plan.md and generates individual task files in .claude/workitems/{type}/{name}/tasks/. The plan should ideally be reviewed (via workspace-plan-review) before generating tasks.
---

# Workspace Task Generate

Read a workitem plan and generate self-contained task files that can be executed independently without needing to reference the original plan.

## Workflow

### 1. Select Workitem

If the user provides a workitem path (e.g. `feature/auth-middleware`), resolve it to `.claude/workitems/{type}/{name}/plan.md`.

If no path is provided, list available workitems in `.claude/workitems/` and ask the user to select one. Only show workitems that have a `plan.md` file.

### 2. Validate Plan

Before generating tasks:

1. Read the plan file
2. Check that the plan has a Tasks section with at least one task
3. If the plan has a Review Status section, warn the user if it has not been marked as reviewed — suggest running workspace-plan-review first but allow proceeding

### 3. Explore Codebase for Context

For each task in the plan, identify the relevant files in the repository:

- Files that will need to be created or modified
- Files that serve as reference for patterns or conventions
- Config files that may need updates
- For multi-repo workspaces: identify which repos under `repos/` each task affects

Limit exploration to areas directly related to each task. Do NOT do a full repo scan.

### 4. Generate Task Files

Create `.claude/workitems/{type}/{name}/tasks/` directory if it doesn't exist.

For each task in the plan, generate a file named `<NN>-<task-name-kebab>.md` (e.g. `01-worktree-setup.md`, `02-auth-middleware.md`).

Each task file must be fully self-contained using the template from `task-template.md`. A developer (or Claude agent) should be able to pick up any single task file and execute it without reading the plan or any other task file.

#### Populating Task Fields

- **Worktree**: Set to `worktrees/{type}/{name}/`. Individual repos are subdirectories (e.g. `worktrees/feature/auth-middleware/frontend/`). Task 1 creates this structure and writes the path to `worktree.path`.
- **Description**: Expand from the plan — add implementation details informed by codebase patterns
- **Dependencies**: List by task number and name, note their completion status
- **Blockers**: Extract from plan's Unknowns and Risks sections where they apply to this task
- **Relevant Files**: Actual file paths from the codebase, categorized as create/modify/reference. For multi-repo workspaces, prefix with the repo name.
- **Subtasks**: Break the task into concrete steps, ordered by execution sequence
- **Acceptance Criteria**: Carry over from plan, expand with implementation-specific criteria
- **Context**: Extract all relevant information from the plan that this task needs — scope decisions, constraints, assumptions, cross-service impacts, Available Processes (with commands if specified). The task must stand alone.

### 5. Summary

After generating all task files, show:

- Total number of tasks generated
- Tasks with blockers (if any)
- Dependency chain overview (which tasks can run in parallel vs sequential)
- Path to the tasks directory