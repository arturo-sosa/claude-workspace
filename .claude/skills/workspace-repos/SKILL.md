---
name: workspace-repos
description: Manage repositories defined in config.yaml. Use when the user wants to clone, update, refresh, or check the status of workspace repos. Triggers on requests like "clone the repos", "refresh repos", "repo status", or "add a repo". Reads config.yaml for repository definitions and manages them in the repos/ directory.
---

# Workspace Repos

Manage the repositories defined in `config.yaml`. The repos/ directory should always reflect what config.yaml defines.

## Config Format

Repositories are defined in `config.yaml` at the workspace root:

```yaml
repos:
  - name: frontend
    url: git@github.com:org/frontend.git
    branch: main
  - name: backend-api
    url: git@github.com:org/backend-api.git
    branch: main
```

Each repo entry requires `name` and `url`. The `branch` field defaults to `main` if omitted.

## Commands

### Refresh

The primary command. When the user asks to refresh, sync, clone, update, or setup repos:

1. Read `config.yaml` from the workspace root
2. Create `repos/` directory if it does not exist
3. For each repo in config:
    - **Not cloned**: `git clone --branch {branch} {url} repos/{name}`
    - **Cloned, correct branch**: `git fetch --all --prune`, stash if dirty, `git pull origin {branch}`, report if stash was needed
    - **Cloned, wrong branch**: stash if dirty, `git checkout {branch}`, `git pull origin {branch}`, report branch switch
4. For each directory in `repos/` that is NOT in config:
    - Remove it with `rm -rf repos/{name}`
    - Report the removal
5. Report summary: cloned, updated, switched, removed, failures

This is a destructive sync — repos/ is made to match config.yaml exactly.

### Status

When the user asks for repo status:

1. Read `config.yaml`
2. For each repo in config:
    - Not cloned: report as "missing"
    - Cloned: report current branch, clean/dirty, ahead/behind remote
3. For each directory in `repos/` not in config: report as "orphaned"
4. Show a summary table

### Add a Repo

When the user asks to add a repo:

1. Ask for name, url, and branch (default main)
2. Append the entry to `config.yaml` under the `repos:` key
3. Clone the repo into `repos/{name}`

### Remove a Repo

When the user asks to remove a repo:

1. Remove the entry from `config.yaml`
2. Remove `repos/{name}` directory
3. Report the removal

## Rules

- Always read `config.yaml` fresh before any operation
- Refresh is the default action — if the user just says "repos" or "setup repos", run refresh
- On dirty working directory: always stash before any pull or checkout, never lose work
- If a clone or update fails, continue with remaining repos and report failures at the end
- Never force-push or rewrite history
- Orphaned repos (in repos/ but not in config) are removed during refresh without confirmation — config.yaml is the source of truth