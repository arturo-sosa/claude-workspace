---
name: workspace-plan-review
description: Dual-agent plan review workflow for workitems. Use when the user wants to review and iterate on an existing workitem plan using two separate Claude agents — one as planner that addresses feedback and one as critical reviewer. Uses type-specific review criteria (feature, bugfix, refactor, hotfix, chore). Triggers on requests to review a plan, validate a plan, or run a plan review cycle. Not for generating plans from scratch (use workspace-plan).
---

# Workspace Plan Review

Orchestrate a two-agent review workflow on an existing workitem plan. A reviewer agent evaluates the plan against type-specific criteria, and a planner agent addresses the feedback. The cycle repeats until the reviewer approves or max rounds are reached.

## Prerequisites

- An existing plan at `.claude/workitems/{type}/{name}/plan.md`
- Claude CLI (`claude`) available in PATH

## Usage

```bash
# By workitem path (type/name)
bash <skill-path>/scripts/plan_review.sh feature/auth-middleware [max-rounds]

# By full path
bash <skill-path>/scripts/plan_review.sh path/to/plan.md [max-rounds]

# Interactive selection (no argument)
bash <skill-path>/scripts/plan_review.sh
```

- `max-rounds`: Maximum review rounds (default: 3)

## How It Works

1. Detects the workitem type from the path (feature, bugfix, refactor, hotfix, chore)
2. Copies the type-specific criteria template to `.claude/workitems/{type}/{name}/review-criteria.md` if it doesn't exist yet
3. Injects a Review Status header into the plan file if not present
4. **Reviewer** reads the plan and evaluates against the criteria, marking checkboxes in the local `review-criteria.md`
5. **Planner** reads reviewer notes and adjusts the plan to address feedback
6. Cycle repeats until reviewer marks `[x] Reviewed` or max rounds exhausted
7. Exit code 0 on approval, 1 if max rounds reached

## Review Criteria

Type-specific criteria templates are in `criteria/`:

- `feature.md` — scope, requirements, dependencies, implementation
- `bugfix.md` — diagnosis, solution, prevention, safety
- `refactor.md` — justification, behavior preservation, incremental tasks
- `hotfix.md` — urgency, minimal scope, safety, rollback
- `chore.md` — justification, impact, verification

Each workitem gets its own copy at `.claude/workitems/{type}/{name}/review-criteria.md`. The reviewer marks criteria in this local copy, so each workitem tracks its own review progress independently.

To override with custom criteria:

```bash
export REVIEW_CRITERIA_FILE="/path/to/custom-criteria.md"
bash <skill-path>/scripts/plan_review.sh feature/auth-middleware
```