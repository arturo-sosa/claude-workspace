---
name: workspace-plan-review
description: Dual-agent plan review workflow for workitems. Use when the user wants to review and iterate on an existing workitem plan using two separate Claude agents — one as planner that addresses feedback and one as critical reviewer. Uses type-specific review criteria (feature, bugfix, refactor, hotfix, chore). Triggers on requests to review a plan, validate a plan, or run a plan review cycle. Not for generating plans from scratch (use workspace-plan).
---

# Workspace Plan Review

Orchestrate a two-agent review workflow on an existing workitem plan using agent teams. Creates a team with planner and reviewer teammates that communicate directly via messages. The reviewer evaluates the plan against type-specific criteria and messages the planner with feedback. The planner revises the plan and notifies the reviewer. This natural conversation continues until the reviewer approves the plan or the cycle stalls.

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

### 5. Create Review Team

Use the Teammate tool to create an agent team for this review cycle:

```
Use Teammate tool with operation: "spawnTeam"
team_name: "{type}-{name}-review"
description: "Plan review for {type}/{name} workitem"
agent_type: "orchestrator"
```

This creates the team infrastructure and designates you as the team lead.

### 6. Spawn Reviewer Teammate

Use the Task tool to spawn a reviewer teammate that will evaluate the plan:

```
Use the Task tool with:
- subagent_type: "general-purpose"
- team_name: "{type}-{name}-review"
- name: "reviewer"

Prompt:
"You are a plan reviewer for the {type}/{name} workitem. Your role is to evaluate the plan against review criteria and work with the planner teammate to ensure it's implementation-ready.

Read these files:
- Plan: {absolute_path_to_plan.md}
- Criteria: {absolute_path_to_review-criteria.md}

For each criterion in review-criteria.md:
1. Evaluate whether the plan adequately addresses it
2. Mark [x] if satisfied, leave [ ] if not
3. Add notes explaining your assessment

Write your detailed feedback at the bottom of review-criteria.md under a '## Reviewer Notes' section.

**Interactive Review Process:**
- If you find issues or gaps: Use SendMessage tool (type: 'message', recipient: 'planner') to send specific feedback about what needs improvement
- If the planner makes changes: Re-evaluate the plan and criteria
- You can ask clarifying questions via message if something is unclear
- When ALL criteria are satisfied and the plan is implementation-ready:
  1. Mark [x] Reviewed in the plan's Review Status section
  2. Set 'Last reviewed: {current_date}'
  3. Use SendMessage tool (type: 'message', recipient: 'team-lead') to notify: 'Plan approved - all criteria met'

Be thorough and critical. The plan must be implementation-ready before approval. Engage in discussion with the planner if needed to clarify intent or push for specificity."
```

### 7. Spawn Planner Teammate

Use the Task tool to spawn a planner teammate that will address feedback:

```
Use the Task tool with:
- subagent_type: "general-purpose"
- team_name: "{type}-{name}-review"
- name: "planner"

Prompt:
"You are the plan author for the {type}/{name} workitem. Your role is to address the reviewer's feedback and improve the plan until it meets all review criteria.

Read these files:
- Plan: {absolute_path_to_plan.md}
- Criteria: {absolute_path_to_review-criteria.md}

**Interactive Revision Process:**
- The reviewer will message you with specific feedback about what needs improvement
- For each issue raised:
  1. Read the reviewer's notes in review-criteria.md
  2. Update the plan to address the feedback with specific, concrete details
  3. Update the plan's Review Status: 'Last reviewed: (pending review)'
- After making changes, use SendMessage tool (type: 'message', recipient: 'reviewer') to notify: 'Plan revised - please re-evaluate'
- You can ask clarifying questions if feedback is unclear
- You can push back on feedback with reasoning if you believe the plan adequately addresses a criterion

Do NOT mark criteria as satisfied in review-criteria.md — that's the reviewer's job.
Do NOT mark [x] Reviewed in the plan — that's the reviewer's job.

Be responsive to feedback and willing to add detail where the plan is vague. Engage in discussion with the reviewer to reach a shared understanding of what makes the plan implementation-ready."
```

### 8. Monitor Review Cycle

As the team lead, you now monitor the review cycle but do not actively manage it. The planner and reviewer teammates will communicate directly via messages until convergence.

**What to watch for:**

1. **Approval notification**: When the reviewer messages you with approval, read the plan file to confirm `[x] Reviewed` is marked, then proceed to "Cleanup Team" below.

2. **Stalled conversation**: If many rounds pass without approval and the conversation seems stuck in a loop, check the latest review-criteria.md feedback. You can message either teammate to help break the impasse.

3. **Blocked state**: If a teammate messages you about a blocker (e.g., "plan requires architectural decision beyond my scope"), escalate to the user for input.

**You will receive messages automatically** — no need to poll or check manually. When a message arrives from a teammate, respond appropriately or proceed to the next step if it's an approval notification.

### 9. Cleanup Team

Once the reviewer has approved the plan (or if you determine the review cycle should end):

1. **Verify approval**: Read the plan file and confirm Review Status shows `[x] Reviewed`

2. **Report to user**:
   - On success: "Plan approved and ready for task generation"
   - If ending without approval: "Review cycle did not converge. See review-criteria.md for remaining issues."

3. **Clean up the team**:
```
Use Teammate tool with operation: "cleanup"
```

This removes the team and task directories.

## Output

On success:
- Plan file has `[x] Reviewed` in Review Status
- All criteria in review-criteria.md are marked `[x]`
- Plan is ready for `workspace-task-generate`
- Team cleaned up

If review cycle does not converge:
- Report unmet criteria to user
- Explain conversation state (e.g., "planner and reviewer disagree on scope")
- Suggest user manually review and adjust the plan
- Team cleaned up

## File Locations

- Plan: `.claude/workitems/{type}/{name}/plan.md`
- Criteria: `.claude/workitems/{type}/{name}/review-criteria.md`
- Criteria templates: `.claude/skills/workspace-plan-review/criteria/{type}.md`

## Key Differences from Previous Approach

This skill was refactored to use **agent teams** instead of sequential subagent spawning. Key improvements:

| Aspect | Previous (Subagents) | Current (Agent Teams) |
|---|---|---|
| **Round limit** | Hard 3-round cap | No limit - natural convergence |
| **Communication** | File-only (review-criteria.md) | Direct messaging + files |
| **Discussion** | None - one-way feedback | Reviewer can ask clarifying questions |
| **Pushback** | None - planner must accept all feedback | Planner can discuss with reasoning |
| **Orchestration** | Lead manages spawn/wait/read loops | Lead creates team, then monitors passively |
| **Flexibility** | Rigid cycle, may need more/fewer rounds | Adapts to complexity of plan |

**Why this is better:**
- Plans that need minor tweaks converge faster (no forced 3 rounds)
- Complex plans can iterate beyond 3 rounds until truly ready
- Planner and reviewer can have nuanced discussions about tradeoffs
- Lead's context window not consumed by orchestration loops
