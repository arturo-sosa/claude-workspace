# Workspace

This is a multi-repo workspace managed with Claude Code. Work is organized into workitems, each with a plan, tasks, and worktrees.

## Structure

```
.claude/              Configuration and workitems
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
2. **Review**: Run `workspace-plan-review` to validate the plan with a dual-agent review cycle. Uses type-specific review criteria. Logs to `.claude/workitems/{type}/{name}/logs/`.
3. **Generate tasks**: Run `workspace-task-generate` to break the plan into self-contained task files in `.claude/workitems/{type}/{name}/tasks/`. Available processes are propagated to each task's context.
4. **Execute**: Run `workspace-task-execute` to dispatch worker and reviewer subagents that implement and verify each task. Task 01 uses the `workspace-worktree` script to create worktrees. All subsequent tasks run from `worktrees/{type}/{name}/`, navigating into repo subdirectories as needed. Logs to `.claude/workitems/{type}/{name}/logs/`.
5. **Archive**: Run `workspace-archive` to close a completed workitem. Generates a report, creates per-repo documentation, updates repo CLAUDE.md if structural changes warrant it, removes worktrees, and moves the workitem to archive.

## Skills

| Skill | Purpose |
|---|---|
| `workspace-setup` | Initialize workspace — create config.yaml from template |
| `workspace-repos` | Clone and sync repos from config.yaml |
| `workspace-plan` | Plan a workitem via discovery interview |
| `workspace-plan-review` | Dual-agent review cycle for plans |
| `workspace-task-generate` | Break plan into self-contained task files |
| `workspace-task-execute` | Orchestrate worker + reviewer subagents per task |
| `workspace-task-work` | Worker subagent — implements a single task |
| `workspace-task-review` | Reviewer subagent — validates a single task |
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
- `worktree.path` contains a single path: `worktrees/{type}/{name}/` — repos are subdirectories
- Each task file is self-contained — executable without reading the plan or other tasks
- Task status flow: `pending → in-progress → completed`
- On crash recovery: `in-progress` tasks are automatically reset to `pending` on next run
- NEVER commit, push, or modify git history in the workspace root — this repo is configuration only
- ALL code commits happen inside worktrees only — never in repos/ directly
- Use the `workspace-repos` skill to clone and sync repos from config.yaml

## Git Identity

When making commits in worktrees, use the git identity from `config.yaml` if configured:

```yaml
git:
  user: "Your Name"
  email: "your@email.com"
```

If `config.yaml` does not have `git.user` or `git.email` set (empty strings), fall back to the system git config (`git config user.name` and `git config user.email`).

## Repos

Repositories are defined in `config.yaml` and cloned into `repos/`. Use the `workspace-repos` skill to manage them (clone, refresh, status, add, remove). Refresh syncs repos/ to match config.yaml exactly — repos not in config are removed.

## Commands

```bash
# Setup workspace (create config.yaml)
claude "setup workspace"

# Clone/refresh repos from config.yaml
claude "refresh repos"

# Plan a workitem
claude "plan a feature called auth-middleware"

# Review a plan
bash .claude/skills/workspace-plan-review/scripts/plan_review.sh feature/auth-middleware

# Generate tasks
claude "generate tasks for feature/auth-middleware"

# Execute tasks
bash .claude/skills/workspace-task-execute/scripts/task_executor.sh feature/auth-middleware

# Check status
bash .claude/skills/workspace-status/scripts/status.sh
bash .claude/skills/workspace-status/scripts/status.sh feature/auth-middleware

# Manage worktrees
bash .claude/skills/workspace-worktree/scripts/worktree.sh status feature/auth-middleware

# Archive a completed workitem
bash .claude/skills/workspace-archive/scripts/archive.sh feature/auth-middleware
```