---
name: workspace-plan-review
description: Dual-agent plan review workflow for workitems. Use when the user wants to review and iterate on an existing workitem plan using two separate Claude agents — one as planner that addresses feedback and one as critical reviewer. Uses type-specific review criteria (feature, bugfix, refactor, hotfix, chore). Triggers on requests to review a plan, validate a plan, or run a plan review cycle. Not for generating plans from scratch (use workspace-plan).
---

# Workspace Plan Review

Orchestrate a two-agent review workflow on an existing workitem plan by spawning reviewer and planner subagents using the Task tool. The reviewer evaluates the plan against type-specific criteria, and the planner addresses feedback. The cycle repeats until approved or max rounds reached.

## Prerequisites

- An existing plan at `.claude/workitems/{type}/{name}/plan.md`
- The review criteria templates in this skill's `criteria/` directory

## Trigger

User requests like:
- "review the plan for feature/auth-middleware"
- "validate the bugfix plan"
- "run plan review on refactor/api-cleanup"

## Review Criteria

Type-specific criteria templates are in `criteria/`:

- `feature.md` — scope, requirements, dependencies, implementation
- `bugfix.md` — diagnosis, solution, prevention, safety
- `refactor.md` — justification, behavior preservation, incremental tasks
- `hotfix.md` — urgency, minimal scope, safety, rollback
- `chore.md` — justification, impact, verification

## Orchestration Steps

When this skill is invoked, follow these steps:

### 1. Identify the Workitem

If not specified, list available workitems in `.claude/workitems/{type}/{name}/`.

**Empty State**: If no workitems exist:
- Display: "No workitems found. Would you like to create one now?"
- If user accepts, delegate to workspace-plan skill
- If user declines, exit gracefully

If workitems exist, ask the user to choose one. Extract the type (feature, bugfix, refactor, hotfix, chore) from the path.

### 2. Validate Plan Exists

Check that `.claude/workitems/{type}/{name}/plan.md` exists. If not, tell the user to run `workspace-plan` first.

### 3. Setup Review Criteria

Check if `.claude/workitems/{type}/{name}/review-criteria.md` exists:
- If not, copy from `.claude/skills/workspace-plan-review/criteria/{type}.md`

This gives the workitem its own criteria file that tracks review progress.

### 4. Inject Review Status (if needed)

If the plan file doesn't have a Review Status section, add this header after the title:

```markdown
## Review Status

- [ ] Reviewed

Last reviewed: (not yet reviewed)
```

### 5. Review-Planner Cycle

Run up to 3 rounds of reviewer → planner:

**Spawn Reviewer** using Task tool:
```
Use the Task tool with subagent_type "general-purpose" to spawn a reviewer.

Prompt:
"You are a plan reviewer. Evaluate the workitem plan against the review criteria.

Read these files:
- Plan: {absolute_path_to_plan.md}
- Criteria: {absolute_path_to_review-criteria.md}

For each criterion in review-criteria.md:
1. Evaluate whether the plan adequately addresses it
2. Mark [x] if satisfied, leave [ ] if not
3. Add notes explaining your assessment

After evaluating all criteria, update the plan's Review Status section:
- If ALL criteria are satisfied: mark [x] Reviewed and set 'Last reviewed: {date}'
- If ANY criteria are not satisfied: leave [ ] Reviewed

Write your detailed feedback at the bottom of review-criteria.md under a '## Reviewer Notes' section.

Be thorough and critical. The plan must be implementation-ready before approval."
```

**Check Approval**: After reviewer completes, read the plan file. If Review Status shows `[x] Reviewed`:
- Report success to the user
- The plan is approved and ready for task generation

**If Not Approved**, spawn Planner:
```
Use the Task tool with subagent_type "general-purpose" to spawn a planner.

Prompt:
"You are a plan author. Address the reviewer's feedback to improve the plan.

Read these files:
- Plan: {absolute_path_to_plan.md}
- Criteria: {absolute_path_to_review-criteria.md} (check Reviewer Notes for feedback)

For each unmet criterion (marked [ ] in review-criteria.md):
1. Read the reviewer's notes explaining what's missing
2. Update the plan to address the feedback
3. Be specific and concrete — vague plans get rejected

After making changes, update the plan's Review Status:
- Set 'Last reviewed: (pending review)'
- Leave [ ] Reviewed (reviewer will update this)

Do NOT mark criteria as satisfied — that's the reviewer's job."
```

After planner completes, loop back to spawn reviewer again.

### 6. Max Rounds Reached

If 3 rounds complete without approval:
- Report to the user which criteria remain unmet
- Suggest the user manually review and adjust the plan
- Do NOT force approval

## Output

On success:
- Plan file has `[x] Reviewed` in Review Status
- All criteria in review-criteria.md are marked `[x]`
- Plan is ready for `workspace-task-generate`

On failure (max rounds):
- Report unmet criteria
- Plan needs manual intervention

## File Locations

- Plan: `.claude/workitems/{type}/{name}/plan.md`
- Criteria: `.claude/workitems/{type}/{name}/review-criteria.md`
- Criteria templates: `.claude/skills/workspace-plan-review/criteria/{type}.md`
