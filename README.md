# Claude Workspace

Multi-repo workspace template for Claude Code with structured workitem management.

## Quick Start

1. Clone this repo
2. Add your repositories: `claude "add repo https://github.com/org/frontend.git"`
3. Start working: `claude "plan a feature called auth-middleware"`

## What's Included

Ten skills that form a complete development lifecycle:

| Skill | Purpose |
|---|---|
| `workspace-setup` | Initialize workspace — create config.yaml from template |
| `workspace-repos` | Clone and sync repos from config.yaml |
| `workspace-plan` | Interactive requirements gathering with type-specific templates |
| `workspace-plan-review` | Dual-agent plan review cycle |
| `workspace-task-generate` | Break plans into self-contained task files |
| `workspace-execute` | Orchestrate task execution with worker/reviewer agents using agent teams |
| `workspace-commit` | Commit changes in worktrees with proper git identity |
| `workspace-worktree` | Create, remove, and check status of git worktrees |
| `workspace-status` | Show progress across all workitems |
| `workspace-archive` | Archive completed workitems with reporting |

## Lifecycle

```
workspace-repos          Clone/sync from config.yaml
       ↓
workspace-plan           Interactive interview → plan.md
       ↓
workspace-plan-review    Dual-agent review (logged)
       ↓
workspace-task-generate  Break into self-contained task files
       ↓
workspace-execute        Orchestrate with agent teams (logged, crash recovery)
       ├── Worker agent         Implements tasks
       ├── Reviewer agent       Verifies implementations
       └── workspace-worktree   Creates worktrees (Task 01)
       ↓
workspace-status         Monitor progress
       ↓
workspace-archive        Report → per-repo docs → cleanup → archive
```

## Workitem Types

- **feature** — New functionality
- **bugfix** — Bug fix with root cause analysis
- **refactor** — Code restructuring
- **hotfix** — Urgent minimal fix
- **chore** — Maintenance, dependencies, CI, tooling

## Commands

```bash
# Setup
claude "refresh repos"

# Plan → Review → Generate → Execute
claude "plan a feature called auth-middleware"
claude "review plan for feature/auth-middleware"
claude "generate tasks for feature/auth-middleware"
claude "execute tasks for feature/auth-middleware"

# Monitor
claude "show workspace status"

# Archive
claude "archive feature/auth-middleware"
```

See `CLAUDE.md` for full details on structure, conventions, and configuration.