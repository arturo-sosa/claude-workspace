---
name: workspace-plan
description: Interactive requirements gathering and plan generation for workitems (features, bugfixes, refactors, hotfixes). Use when the user wants to define requirements for new work through a discovery interview. Triggers on requests to plan a feature, investigate a bug, scope a refactor, or handle a hotfix. Generates a structured plan in .claude/workitems/{type}/{name}/plan.md using type-specific templates. Not for reviewing existing plans (use workspace-plan-review).
---

# Workspace Plan

Guide an interactive discovery interview to turn an initial brief into a structured plan. Select the appropriate template based on workitem type, explore the codebase for context, and incrementally build the plan.

## Workflow

### 1. Initialize

When the user provides a brief:

1. Determine the workitem type: `feature`, `bugfix`, `refactor`, `hotfix`, or `chore`
   - Ask if not obvious from the brief
   - Infer from context when possible (e.g. "this is broken" → bugfix)
2. Suggest a workitem name based on the brief (short, kebab-case, e.g. `auth-middleware`, `login-timeout`). Present it to the user and let them accept or provide their own. If the user provides a name that doesn't follow kebab-case convention, transform it automatically (lowercase, replace spaces and underscores with hyphens, strip special characters) and confirm the normalized name.
3. Create `.claude/workitems/{type}/{name}/` directory
4. Copy the matching template from `templates/{type}.md` to `plan.md`
5. Fill in the Brief section with the user's original brief
6. Confirm the file was created

The workitem name becomes the branch name: `{type}/{name}` (e.g. `feature/auth-middleware`, `bugfix/login-timeout`).

### 2. Explore the Codebase

Limit initial exploration to:

1. Top-level directory structure only (`ls`, not recursive)
2. Key config files (package.json, tsconfig, Makefile, etc.) to identify stack and conventions
3. Only directories and files directly related to the brief
4. For multi-repo workspaces: identify which repos under `repos/` are relevant

**Detect available processes**: Read package.json scripts, Makefile targets, or equivalent config to determine which processes exist (build, lint, test, typecheck). Mark them as `[x]` in the Available Processes section and note the commands if non-standard (e.g. `build: npm run build:prod`, `test: jest --config custom.config.js`).

Do NOT explore the entire repository upfront. Go deeper only as the interview reveals relevant areas.

### 3. Interview

Conduct a focused discovery interview. On each round:

1. Identify the most critical gaps in the plan
2. Ask **one or two** targeted questions — never overwhelm with a long list
3. After the user responds, immediately update the plan file
4. Move to the next gap

#### Discovery Areas by Type

**All types**: Risks, cross-service impacts, unknowns, testing strategy, task breakdown

**Feature**: Scope (in/out), assumptions & constraints, implementation approach, acceptance criteria, development methodology

**Bugfix**: Reproduction steps, investigation findings, root cause, solution approach, prevention measures

**Refactor**: Current state analysis, motivation, desired state, behavior preservation strategy

**Hotfix**: Severity assessment, affected users/systems, minimal solution scope, immediate rollback plan

**Chore**: Motivation, scope boundaries, verification strategy, impact on developer workflows

#### Interview Behavior

- Ask questions specific to the project — use codebase context
- If the user's answer reveals new risks or impacts, capture immediately
- If something contradicts the codebase state, flag it
- Update the plan file after every response — do not batch updates
- When a section is well-covered, move on

### 4. Wrapping Up

The user can end the interview at any time. When it ends:

1. Fill remaining sections with best-effort content based on discussion and codebase context
2. Ensure every task has dependencies and acceptance criteria
3. List remaining unknowns prominently
4. Show summary: workitem type, number of tasks, open unknowns count, identified risks count
5. Suggest running workspace-plan-review on the generated plan

### Task Structure

Every task in the plan must follow this format:

```markdown
### Task N: <Task Name>
- **Description**: What this task accomplishes
- **Dependencies**: Which tasks must complete first (or None)
- **Acceptance Criteria**: Specific, verifiable conditions for completion
```

Keep tasks scoped to a single commit. If a task feels too large, split it.