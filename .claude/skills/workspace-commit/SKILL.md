---
name: workspace-commit
description: Create atomic git commits from pending changes in a worktree. Analyzes staged and unstaged changes, groups them into logical atomic commits, and executes using the workspace git-commit.sh wrapper for identity management. Use after a task is approved by the reviewer, or manually when you need to commit changes following workspace conventions.
---

# Workspace Commit

Create atomic git commits from pending changes in a worktree.

## Usage

```bash
# Commit changes in a specific repo worktree
bash <skill-path>/scripts/commit.sh worktrees/feature/auth-middleware/frontend

# Commit changes across all repos in a workitem worktree
bash <skill-path>/scripts/commit.sh worktrees/feature/auth-middleware

# Dry run — show what would be committed without executing
bash <skill-path>/scripts/commit.sh worktrees/feature/auth-middleware --dry-run
```

## How It Works

### Single Repo

When pointed at a repo directory (contains `.git`):

1. Runs `git status` and `git diff` to collect pending changes
2. Launches a subagent that analyzes the changes and outputs a commit plan as structured JSON
3. Executes each commit in order using `git-commit.sh`

### Workitem Worktree

When pointed at a workitem worktree directory (contains repo subdirectories):

1. Iterates each repo subdirectory
2. Runs the single-repo flow for each one that has pending changes
3. Skips clean repos

### Commit Rules

The subagent follows these rules when grouping changes:

- Each commit should be atomic — one logical change per commit
- Each commit should leave the codebase in a buildable state
- Commit messages follow conventional commits: `type(scope): description`
- Types: feat, fix, refactor, test, docs, chore, style, ci
- Group related file changes together (e.g. a component + its test + its styles)
- Separate unrelated changes into distinct commits
- Order commits so dependencies come first

### Identity

All commits use `git-commit.sh` which reads `git.user` and `git.email` from `config.yaml`. Falls back to system git config if not set.