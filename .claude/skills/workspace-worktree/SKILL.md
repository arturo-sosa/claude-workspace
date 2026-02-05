---
name: workspace-worktree
description: Manage git worktrees for workitems. Use when creating, removing, or checking the status of worktrees. Typically invoked by the Task 01 worker during workitem execution. Also used for cleanup of completed workitems. Triggers on requests to create worktrees, remove worktrees, or check worktree status.
---

# Workspace Worktree

Manage git worktrees for workitems. Provides create, remove, and status operations.

## Trigger

- Task 01 worker needs to set up worktrees
- User requests "create worktree for feature/auth-middleware"
- User requests "remove worktree" or "clean up worktrees"
- User requests "worktree status"
- `workspace-archive` needs to remove worktrees

## Operations

### Create Worktrees

**When**: Task 01 of a workitem, or user explicitly requests.

**Input**: workitem path (`{type}/{name}`) and list of repos to include.

**Steps**:

1. **Identify repos**: Read from the plan which repos are affected, or use the provided list.

2. **Create base directory**:
   ```bash
   mkdir -p worktrees/{type}/{name}
   ```

3. **For each repo**:

   a. Verify repo exists at `repos/{repo}/.git`

   b. Check if worktree already exists at `worktrees/{type}/{name}/{repo}` — skip if so

   c. Create branch if it doesn't exist:
   ```bash
   cd repos/{repo}
   git branch {type}/{name} 2>/dev/null || true  # OK if exists
   ```

   d. Create worktree:
   ```bash
   cd repos/{repo}
   git worktree add ../../worktrees/{type}/{name}/{repo} {type}/{name}
   ```

   e. Install dependencies (detect from lockfile):
   ```bash
   cd worktrees/{type}/{name}/{repo}
   # If yarn.lock exists:
   yarn install --frozen-lockfile
   # If pnpm-lock.yaml exists:
   pnpm install --frozen-lockfile
   # If package-lock.json exists:
   npm ci
   # If only package.json exists:
   npm install
   ```

4. **Write worktree path**:
   ```bash
   echo "worktrees/{type}/{name}" > .claude/workitems/{type}/{name}/worktree.path
   ```

5. **Report summary**:
   ```
   Worktree Setup Summary
   ======================
   Created: 2
   Skipped: 1 (already exist)
   Failed: 0
   ```

### Remove Worktrees

**When**: Archiving a workitem, or user explicitly requests cleanup.

**Input**: workitem path (`{type}/{name}`), optionally `--force` to delete branches.

**Steps**:

1. **Read worktree path** from `.claude/workitems/{type}/{name}/worktree.path`

2. **For each repo subdirectory** in the worktree:

   a. Remove via git:
   ```bash
   cd repos/{repo}
   git worktree remove ../../worktrees/{type}/{name}/{repo} --force
   ```

   b. If git command fails, remove directory manually:
   ```bash
   rm -rf worktrees/{type}/{name}/{repo}
   ```

   c. If `--force` specified, delete the branch:
   ```bash
   cd repos/{repo}
   git branch -D {type}/{name}
   ```

3. **Remove base directory**:
   ```bash
   rm -rf worktrees/{type}/{name}
   ```

4. **Clean up empty parent**:
   ```bash
   rmdir worktrees/{type} 2>/dev/null || true
   ```

5. **Report**: "Removed N worktree(s)"

### Worktree Status

**When**: User wants to check worktree state.

**Input**: workitem path (`{type}/{name}`)

**Steps**:

1. **Read worktree path** from `.claude/workitems/{type}/{name}/worktree.path`

2. **For each repo subdirectory**:

   a. Check if valid worktree (has `.git` file)

   b. Get current branch:
   ```bash
   cd worktrees/{type}/{name}/{repo}
   git branch --show-current
   ```

   c. Check for uncommitted changes:
   ```bash
   git status --porcelain | wc -l
   ```

   d. Check if dependencies installed (node_modules exists for JS projects)

3. **Report**:
   ```
   Worktree status for: feature/auth-middleware
   Branch: feature/auth-middleware

     📂 frontend
       🌿 Branch: feature/auth-middleware
       ✅ Clean
       📦 Dependencies installed

     📂 backend-api
       🌿 Branch: feature/auth-middleware
       ⚠️  Dirty (3 changed files)
       📦 Dependencies installed
   ```

## File Locations

- Repos: `repos/{repo}/`
- Worktrees: `worktrees/{type}/{name}/{repo}/`
- Worktree path file: `.claude/workitems/{type}/{name}/worktree.path`

## Rules

- Branch name matches workitem: `{type}/{name}`
- One worktree per repo per workitem
- Dependencies are installed automatically on create
- Branches are kept on remove (unless `--force`)
- Always use `git worktree` commands, not manual symlinks
