# Workspace

This is a multi-repo workspace managed with Claude Code. Work is organized into workitems, each with a plan, tasks, and worktrees.

## Structure

```
.claude/              Configuration and workitems
  settings.json       Model, attribution, and hooks
  skills/             Installed skills
  workitems/          Active workitems organized by type
    feature/
    bugfix/
    refactor/
    hotfix/
    chore/
      {name}/
        plan.md
        review-criteria.md
        worktree.path
        report.md          (generated during archive)
        tasks/
        logs/
    archive/           Archived workitems
      {type}/{name}/
repos/                Cloned repositories
worktrees/            Git worktrees for active workitems
  {type}/{name}/      One directory per workitem
    {repo}/           Subdirectory per affected repo
config.yaml           Repository and workspace configuration
```

## Workflow

1. **Plan**: Start a workitem with `workspace-plan`. Choose a type (feature, bugfix, refactor, hotfix, chore), name it, and go through the discovery interview. The plan lands in `.claude/workitems/{type}/{name}/plan.md`. During planning, available processes (build, lint, test, typecheck) are detected from the codebase and recorded in the plan.
2. **Review**: Run `workspace-plan-review` to validate the plan using agent teams. Creates a team with planner and reviewer teammates that communicate via direct messages (not file-only). The reviewer evaluates the plan against type-specific criteria and iterates naturally with the planner until approval or the cycle stalls. Logs to `.claude/workitems/{type}/{name}/logs/`.
3. **Generate tasks**: Run `workspace-task-generate` to break the plan into self-contained task files in `.claude/workitems/{type}/{name}/tasks/`. Available processes are propagated to each task's context.
4. **Execute**: Run `workspace-execute` to create an agent team with worker and reviewer teammates. The team lead populates a shared task list from task files, and teammates self-coordinate through direct messaging and the shared task list. Workers claim tasks, implement them, and notify reviewers. Reviewers verify work and mark tasks complete. The team lead monitors progress and handles escalations in delegate mode (coordination only, no code editing). Task 01 uses `workspace-worktree` to create worktrees. All subsequent tasks run from `worktrees/{type}/{name}`, navigating into repo subdirectories as needed. After each task is approved, changes are committed as a single commit per task. Logs to `.claude/workitems/{type}/{name}/logs/`.
5. **Archive**: Run `workspace-archive` to close a completed workitem. Generates a report, creates per-repo documentation, updates repo CLAUDE.md if structural changes warrant it, removes worktrees, and moves the workitem to archive.

## Skills

| Skill | Purpose |
|---|---|
| `workspace-setup` | Initialize workspace — create config.yaml from template |
| `workspace-repos` | Clone and sync repos from config.yaml |
| `workspace-plan` | Plan a workitem via discovery interview |
| `workspace-plan-review` | Agent team review cycle with planner + reviewer teammates |
| `workspace-task-generate` | Break plan into self-contained task files |
| `workspace-execute` | Agent team orchestration — worker + reviewer teammates self-coordinate via shared task list and direct messaging |
| `workspace-commit` | Commit changes in worktrees with proper git identity |
| `workspace-worktree` | Create, remove, and check status of git worktrees |
| `workspace-status` | Show progress across all workitems |
| `workspace-archive` | Archive completed workitems with reporting |

## Workitem Types

- **feature**: New functionality or capability
- **bugfix**: Fix for a known bug — documents symptom, root cause, solution, and prevention
- **refactor**: Code restructuring — documents current state, motivation, and desired state
- **hotfix**: Urgent fix — minimal scope, documents severity and immediate rollback plan
- **chore**: Maintenance work — dependency updates, CI changes, tooling, cleanup, documentation

## Conventions

- Workitem names are kebab-case: `auth-middleware`, `login-timeout`
- The workitem name becomes the git branch: `{type}/{name}` (e.g. `feature/auth-middleware`)
- `worktree.path` contains a single path: `worktrees/{type}/{name}` — repos are subdirectories
- Each task file is self-contained — executable without reading the plan or other tasks
- Task status flow: `pending → in-progress → completed`
- On crash recovery: `in-progress` tasks are assessed for progress (subtasks, worker notes, commits) — resumed if work exists, reset to `pending` if not
- NEVER commit, push, or modify git history in the workspace root — this repo is configuration only
- ALL code commits happen inside worktrees only — never in repos/ directly
- Use the `workspace-repos` skill to clone and sync repos from config.yaml

## Git Identity

Git identity is configured in `config.yaml`:

```yaml
git:
  user: "Your Name"
  email: "your@email.com"
```

The `workspace-commit` skill reads this config and uses it when committing. If not set (empty strings), falls back to system git config.

For manual commits, use git with the `-c` flags:

```bash
git -c "user.name=Your Name" -c "user.email=your@email.com" commit -m "message"
```

Or just use `workspace-commit` which handles identity automatically.

## Attribution

Commit attribution (e.g., Co-Authored-By trailers) is configured in `.claude/settings.json`:

```json
{
  "attribution": {
    "commit": "Co-Authored-By: Name <email>",
    "pr": "Generated by ..."
  }
}
```

- `attribution.commit`: Appended as a trailer to commit messages (empty = no attribution)
- `attribution.pr`: Used in pull request descriptions (empty = no attribution)

The `workspace-commit` skill checks this setting and adds the trailer if configured.

## Agent Teams

The workspace uses Claude Code Agent Teams for orchestration in `workspace-execute` and `workspace-plan-review`. This requires the experimental feature flag in `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Agent teams enable:
- **Persistent teammates** that self-coordinate via direct messaging
- **Shared task list** with automatic dependency management
- **Natural conversation** between planner and reviewer, worker and reviewer
- **Delegate mode** where the team lead coordinates without editing code

Teammates are spawned for the duration of a workitem and cleaned up when complete. All teammate activity is logged to `.claude/workitems/{type}/{name}/logs/`.

## Repos

Repositories are defined in `config.yaml` and cloned into `repos/`. Use the `workspace-repos` skill to manage them (clone, refresh, status, add, remove). Refresh syncs repos/ to match config.yaml exactly — repos not in config are removed.

## Multi-Repo Operations

Operations that span multiple repositories are **NOT atomic**. Each repo is processed independently, and a failure in one repo does not prevent operations on other repos from completing.

### Partial Failure Behavior

When a multi-repo operation fails partway through:

1. **Report per-repo status** — clearly indicate which repos succeeded and which failed
2. **Keep successful changes** — changes that completed successfully remain in place
3. **No automatic rollback** — successful operations are not undone when others fail
4. **User decides next steps** — the user chooses how to handle failed repos (retry, remove, investigate)

### Example: Partial Refresh Failure

If `workspace-repos refresh` fails on 1 of 3 repos:

```
frontend:     SUCCESS  updated to latest
backend-api:  SUCCESS  updated to latest
data-service: FAILED   network error

Result:
- frontend and backend-api have the new changes
- data-service remains at its previous state
- User decides: retry data-service, remove from config, or investigate the error
```

This approach ensures that successful work is preserved and gives the user full control over error recovery.

## Commands

```bash
# Setup workspace (create config.yaml)
claude "setup workspace"

# Clone/refresh repos from config.yaml
claude "refresh repos"

# Plan a workitem
claude "plan a feature called auth-middleware"

# Review a plan (dual-agent review cycle)
claude "review plan for feature/auth-middleware"

# Generate tasks
claude "generate tasks for feature/auth-middleware"

# Execute tasks (agent team orchestration)
claude "execute tasks for feature/auth-middleware"

# Check status
claude "show workspace status"
claude "status of feature/auth-middleware"

# Manage worktrees
claude "create worktree for feature/auth-middleware"
claude "worktree status for feature/auth-middleware"
claude "remove worktree for feature/auth-middleware"

# Commit changes in worktrees
claude "commit changes for feature/auth-middleware"

# Archive a completed workitem
claude "archive feature/auth-middleware"
```