---
name: workspace-commit
description: Commit changes in a worktree with proper git identity from config.yaml. Use after a task is approved by the reviewer, or manually when you need to commit changes following workspace conventions. Supports two modes: single commit per task, or atomic commits for manual use.
---

# Workspace Commit

Commit changes in a worktree using the git identity from workspace config. Operates in two modes depending on context.

## Trigger

User requests like:
- "commit changes for feature/auth-middleware"
- "commit the task"
- Invoked by `workspace-task-execute` after task approval

## Prerequisites

- Changes to commit in a worktree
- `config.yaml` at workspace root (for git identity)

## Commit Modes

### Task Mode (Single Commit)

**When**: Invoked from `workspace-task-execute` after a task is approved, or when the user explicitly mentions a task.

**Behavior**: Bundle all changes into a single commit per repo. The commit represents the complete work of one task.

**Message format**: `{type}: {task description}`

Example:
```
feat: add JWT authentication middleware
```

### Manual Mode (Atomic Commits)

**When**: Invoked directly by user without task context (e.g., "commit changes for feature/auth-middleware").

**Behavior**: Analyze the changes and create multiple atomic commits, each representing one logical change. Each commit should:
- Be self-contained and buildable
- Group related files together (component + test + styles)
- Separate unrelated changes
- Order commits so dependencies come first

**Message format**: `{type}({scope}): {description}`

Examples:
```
feat(auth): add JWT token validation
test(auth): add unit tests for JWT validation
refactor(utils): extract token parsing helper
docs(readme): update authentication section
```

## Commit Steps

### 1. Identify the Worktree

If not specified, determine from context:
- If called from `workspace-task-execute`: use the current task's worktree
- Otherwise: ask the user which worktree to commit

Worktrees are at `worktrees/{type}/{name}/` with repo subdirectories inside.

### 2. Determine Mode

- **Task mode**: if invoked from task-execute OR user mentions "task" OR a task file path is in context
- **Manual mode**: otherwise

### 3. Read Git Identity

Read `config.yaml` at workspace root:

```yaml
git:
  user: "Your Name"
  email: "your@email.com"
```

If `git.user` or `git.email` are empty or missing, fall back to system git config (omit the `-c` flags).

### 4. Check for Changes

For each repo subdirectory in the worktree:

```bash
cd {worktree_path}/{repo}
git status --porcelain
git diff --stat
```

Skip repos with no changes.

### 5. Stage and Commit

#### Task Mode

For each repo with changes:

```bash
cd {worktree_path}/{repo}
git add -A
git -c "user.name={git_user}" -c "user.email={git_email}" commit -m "{type}: {description}"
```

#### Manual Mode

Analyze the changes to determine logical groupings:

1. Review `git diff` output to understand what changed
2. Group related changes (same feature, same component, etc.)
3. Plan commit order (dependencies first)
4. For each logical group:
   ```bash
   git add {specific files}
   git -c "user.name={git_user}" -c "user.email={git_email}" commit -m "{type}({scope}): {description}"
   ```

### 6. Commit Message Types

- `feat` — new feature or capability
- `fix` — bug fix
- `refactor` — code restructuring without behavior change
- `chore` — maintenance, dependencies, tooling
- `docs` — documentation only
- `test` — adding or updating tests
- `style` — formatting, whitespace, no code change

Derive the type from the changes, not the workitem type.

### 7. Report Results

After committing, report:
- Mode used (task or manual)
- Which repos had commits
- The commit message(s) used
- Any repos skipped (no changes)

## Multi-Repo Worktrees

When a worktree contains multiple repo subdirectories:

- **Task mode**: One commit per repo, all containing the task's changes
- **Manual mode**: Multiple atomic commits per repo as needed

## Rules

- NEVER commit in `repos/` directly — only in worktrees
- NEVER commit in the workspace root — this repo is configuration only
- Use the git identity from config.yaml when available
- In manual mode, each commit should leave the codebase buildable
