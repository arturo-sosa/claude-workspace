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

## URL Validation

Before cloning or adding a repository, validate the URL format and host.

### Format Requirements

URLs must start with one of:
- `https://` — HTTPS clone URLs
- `git@` — SSH clone URLs

Reject any URL that does not match these formats. Examples:
- **Valid**: `https://github.com/org/repo.git`, `git@github.com:org/repo.git`
- **Invalid**: `http://github.com/org/repo.git` (insecure), `ftp://server/repo.git` (wrong protocol), `/local/path` (local path)

### Known Hosts

The following hosts are trusted and require no additional confirmation:
- `github.com`
- `gitlab.com`
- `bitbucket.org`

### Unfamiliar Host Confirmation

For URLs pointing to hosts not in the known hosts list:

1. Display the full URL and extracted host to the user
2. Ask for explicit confirmation before proceeding: "The URL uses an unfamiliar host: {host}. Continue? (y/n)"
3. If the user declines, skip that repo and report it as skipped
4. If the user confirms, proceed with the operation

This prevents accidental cloning from typosquatted or malicious URLs.

## Error Handling

Handle failures gracefully while ensuring no work is lost.

### Local Changes

When a pull or checkout fails due to uncommitted local changes:

1. Automatically run `git stash push -m "workspace-repos auto-stash"`
2. Retry the operation (pull or checkout)
3. Report that changes were stashed: "Stashed local changes in {repo}"
4. Do NOT automatically pop the stash — user must review and pop manually

### Auth Failure

When authentication fails (permission denied, invalid credentials, access denied):

1. Abort the operation for that repo immediately
2. Mark the repo as a blocker
3. Continue processing remaining repos
4. Report the failure: "Auth failure for {repo}: {error message}"

### Network Failure

When a network error occurs (connection refused, timeout, DNS failure):

1. Abort the operation for that repo immediately
2. Mark the repo as a blocker
3. Continue processing remaining repos
4. Report the failure: "Network failure for {repo}: {error message}"

### Continue-with-Blockers Behavior

After processing all repos:

1. Complete all possible operations (clone, update, branch switch) for non-blocked repos
2. Summarize all blockers at the end:
   ```
   Completed: 3 repos (2 cloned, 1 updated)
   Blockers: 2 repos
     - backend-api: Auth failure (permission denied)
     - data-service: Network failure (connection timeout)
   ```
3. Exit with non-zero status if any blockers exist

## Commands

### Refresh

The primary command. When the user asks to refresh, sync, clone, update, or setup repos:

1. Read `config.yaml` from the workspace root
2. Create `repos/` directory if it does not exist
3. Validate all URLs before processing (see URL Validation)
4. For each repo in config:
    - **Not cloned**: `git clone --branch {branch} {url} repos/{name}`
    - **Cloned, correct branch**: `git fetch --all --prune`, stash if dirty, `git pull origin {branch}`, report if stash was needed
    - **Cloned, wrong branch**: stash if dirty, `git checkout {branch}`, `git pull origin {branch}`, report branch switch
5. For each directory in `repos/` that is NOT in config:
    - **Display orphan warning**: "WARNING: Removing orphaned repo: {name} (not in config.yaml)"
    - Remove it with `rm -rf repos/{name}`
    - Report the removal
6. Report summary: cloned, updated, switched, removed, blockers

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
2. Validate the URL format and host (see URL Validation)
3. Append the entry to `config.yaml` under the `repos:` key
4. Clone the repo into `repos/{name}`

### Remove a Repo

When the user asks to remove a repo:

1. Remove the entry from `config.yaml`
2. Remove `repos/{name}` directory
3. Report the removal

## Orphan Removal

During refresh, directories in `repos/` that are not defined in `config.yaml` are considered orphaned and will be removed.

### Warning Behavior

Before removing each orphaned repo:

1. Display an explicit warning in the output: "WARNING: Removing orphaned repo: {name} (not in config.yaml)"
2. List all files/changes that will be lost if the orphan has uncommitted work
3. Proceed with removal — do NOT block for confirmation

The removal proceeds without confirmation because `config.yaml` is the source of truth. If a repo was removed from config, it should be removed from the filesystem.

### Rationale

- Config.yaml is the single source of truth for which repos belong in the workspace
- Orphaned repos are unexpected state that should be cleaned up
- The warning ensures visibility — users see exactly what is being removed
- No confirmation prompt because refresh is explicitly a sync operation

## Rules

- Always read `config.yaml` fresh before any operation
- Validate URLs before any clone or add operation
- Confirm unfamiliar hosts with the user before proceeding
- Refresh is the default action — if the user just says "repos" or "setup repos", run refresh
- On dirty working directory: always stash before any pull or checkout, never lose work
- If a clone or update fails, mark as blocker, continue with remaining repos, and summarize failures at the end
- Never force-push or rewrite history
- Orphaned repos (in repos/ but not in config) are warned and removed during refresh — config.yaml is the source of truth
