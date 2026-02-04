---
name: workspace-worktree
description: Manage git worktrees for workitems. Use when creating, removing, or checking the status of worktrees. Typically invoked by the Task 01 worker during workitem execution — the LLM identifies affected repos from the plan and calls the script with the repo list. Also used for cleanup of completed workitems. Triggers on requests to create worktrees, remove worktrees, or check worktree status.
---

# Workspace Worktree

Manage git worktrees for workitems. Provides deterministic creation, removal, and status of worktrees so the LLM doesn't need to run git commands directly.

## Usage

```bash
# Create worktrees for a workitem
bash <skill-path>/scripts/worktree.sh create {type}/{name} {repo1} {repo2} ...

# Remove worktrees for a workitem
bash <skill-path>/scripts/worktree.sh remove {type}/{name}

# Show worktree status for a workitem
bash <skill-path>/scripts/worktree.sh status {type}/{name}
```

## Commands

### create

Creates the worktree structure for a workitem:

1. Creates branch `{type}/{name}` in each specified repo under `repos/`
2. Creates `worktrees/{type}/{name}/` directory
3. Runs `git worktree add` for each repo into `worktrees/{type}/{name}/{repo}/`
4. Installs dependencies in each worktree (detects package manager from lockfile)
5. Verifies build passes in each worktree (if build process is available)
6. Writes the worktree path to `.claude/workitems/{type}/{name}/worktree.path`

If a branch already exists, it reuses it. If a worktree already exists, it skips it.

### remove

Cleans up worktrees for a completed or abandoned workitem:

1. Runs `git worktree remove` for each repo worktree
2. Removes the `worktrees/{type}/{name}/` directory
3. Optionally deletes the branches (prompts unless `--force` is passed)

### status

Shows the current state of worktrees for a workitem:

- Which repo worktrees exist
- Branch name and status (clean/dirty, ahead/behind)
- Whether dependencies are installed