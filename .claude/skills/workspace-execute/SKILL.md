---
name: workspace-execute
description: Orchestrate task execution for a workitem using agent teams. Creates a team with worker and reviewer teammates that self-coordinate via shared task list and direct messaging. Use when the user wants to execute tasks, run the implementation pipeline, or start working through a task list. Picks up pending tasks from .claude/workitems/{type}/{name}/tasks/, runs worker+reviewer cycles in the worktree, and marks tasks completed. Logs all output to .claude/workitems/{type}/{name}/logs/.
---

# Workspace Execute

Orchestrate task execution using **agent teams**. The lead creates a team, spawns worker and reviewer teammates, populates a shared task list from workitem task files, and monitors execution until all tasks are complete.

Workers and reviewers communicate directly via messaging, self-coordinate via the shared task list, and iterate naturally until each task is approved. The lead operates in **delegate mode** (coordination only, no code editing).

## Prerequisites

- Agent teams feature flag enabled in `.claude/settings.json`:
  ```json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```
- Task files in `.claude/workitems/{type}/{name}/tasks/` (via workspace-task-generate)
- Worktree created for Task 02+ (Task 01 creates it)

## Trigger

User requests like:
- "execute tasks for feature/auth-middleware"
- "run the tasks"
- "start working on bugfix/login-timeout"

## Orchestration Steps

When this skill is invoked, follow these steps:

### 1. Identify the Workitem

If not specified, list available workitems in `.claude/workitems/{type}/{name}/`.

**Empty State**: If no workitems exist:
- Display: "No workitems found. Would you like to create one now?"
- If user accepts, delegate to workspace-plan skill
- If user declines, exit gracefully

If workitems exist, ask the user to choose one.

### 2. Validate Task Files Exist

Check that `.claude/workitems/{type}/{name}/tasks/` contains task files (*.md). If empty, tell the user to run `workspace-task-generate` first.

### 3. Read Task Files

Read all task files from `.claude/workitems/{type}/{name}/tasks/` to understand:
- Which tasks exist
- Their current status (pending, in-progress, completed)
- Dependencies between tasks
- Task descriptions and context

### 4. Crash Recovery

For any tasks with `Status: in-progress`, assess progress before deciding how to proceed.

#### 4a. Check for Progress

For each `in-progress` task, look for evidence of work done:

1. **Subtasks**: Count how many subtasks are marked `[x]` vs `[ ]`
2. **Worker Notes**: Check if there are any `### Round N` entries documenting work
3. **Git commits**: In the worktree, check `git log --oneline -10` for commits that might relate to this task

#### 4b. Decide Recovery Action

**If progress exists** (any subtasks done, worker notes present, or related commits found):
- Keep `Status: in-progress`
- Will be included in the shared task list as in-progress
- Worker can resume where previous worker left off

**If no progress** (all subtasks unchecked, no worker notes, no related commits):
- Reset to `Status: pending`
- Will be picked up fresh from the task list

Report recovery decisions to the user:
```
Crash recovery:
- Task 03: resuming (2/5 subtasks done, worker notes present)
- Task 04: reset to pending (no progress found)
```

### 5. Create Agent Team

Use the Teammate tool to create a team:

```
Operation: spawnTeam
Team name: {type}-{name}-execution
Description: Executing tasks for {type}/{name}
Agent type: delegate
```

The team name format is: `{type}-{name}-execution` (e.g., `feature-auth-middleware-execution`).

### 6. Populate Shared Task List

For each task file (in numeric order 01, 02, 03...):

1. Read the task file to get description, dependencies, and blockers
2. Use TaskCreate to add it to the shared task list:
   - **subject**: Task filename (e.g., "01-setup-worktree")
   - **description**: Full task description from the file, including:
     - Task file absolute path
     - Description section
     - Relevant files
     - Subtasks
     - Acceptance criteria
     - Context
   - **activeForm**: Present continuous (e.g., "Setting up worktree")
   - **metadata**:
     ```json
     {
       "task_file": "/absolute/path/to/task.md",
       "worktree": "worktrees/{type}/{name}",
       "workitem_type": "{type}",
       "workitem_name": "{name}"
     }
     ```

3. If the task file's `Status` is:
   - `pending`: Task starts as pending in shared list
   - `in-progress`: Use TaskUpdate to mark as in_progress
   - `completed`: Use TaskUpdate to mark as completed

4. Use TaskUpdate to set dependencies:
   - Read the task file's `## Dependencies` section
   - For each dependency task, add to `blockedBy` list

After populating, the shared task list mirrors the task files with proper dependency chains.

### 7. Spawn Teammates

Spawn 1 worker and 1 reviewer using the Task tool with the prompts below.

#### Worker Teammate Spawn

Use Task tool with `subagent_type: "general-purpose"` and `team_name: "{type}-{name}-execution"` and `name: "worker"`:

```
You are a task worker for {type}/{name}. Your worktree is at worktrees/{type}/{name}.

When assigned or when you claim a task from the shared task list:
1. Read the task file path from the task's metadata.task_file field
2. Check if "Review Feedback" section has content — if yes, address every point first before continuing
3. For Task 01 (worktree setup): use the workspace-worktree skill to create worktrees
4. Navigate into the correct repo subdirectory in the worktree before making changes
5. Work through subtasks in order, marking each [x] when done in the task file
6. Append your work log to "Worker Notes" section in the task file
7. When all subtasks are done, message the reviewer: "Task {N} ready for review"
8. If reviewer sends needs-work feedback:
   - Read the feedback in the task file's "Review Feedback" section
   - Address every point
   - Update the task file
   - Message reviewer again: "Task {N} revised, ready for re-review"

Rules:
- Do NOT mark acceptance criteria — that's the reviewer's job
- Do NOT change the Status field in the task file — that's managed via the shared task list
- Stay in the worktree — never modify repos/ or workspace root
- If blocked, message the team lead explaining the blocker
- Update TaskList status to in_progress when you start, but do NOT mark completed (reviewer does that)
- Follow existing codebase patterns — do not introduce new patterns without reason

Available skills you can invoke:
- workspace-worktree: For Task 01 to create worktrees
- workspace-commit: To commit changes (but lead may handle this)

Task file format:
- Status: (pending|in-progress|completed)
- Description: What to accomplish
- Relevant Files: Which files to create/modify/reference
- Subtasks: [ ] items to mark [x] as you go
- Acceptance Criteria: [ ] items (do NOT mark these)
- Context: Additional information from the plan
- Worker Notes: <!-- Append your logs here -->
- Review Feedback: <!-- Reviewer writes here -->
```

#### Reviewer Teammate Spawn

Use Task tool with `subagent_type: "general-purpose"` and `team_name: "{type}-{name}-execution"` and `name: "reviewer"`:

```
You are a task reviewer for {type}/{name}. Your worktree is at worktrees/{type}/{name}.

Wait for the worker to message you that a task is ready for review. When you receive a message:
1. Read the task file path from the shared task list metadata.task_file field
2. Verify all subtasks in the task file are marked [x]
3. Navigate to the correct repo subdirectory in the worktree
4. Run only the quality checks listed as "Available Processes" in the task's Context section:
   - build (if available): Run the build command
   - lint (if available): Run the linter
   - typecheck (if available): Run type checking
   - test (if available): Run tests
   - Skip any that are not available — do not fail for missing processes
5. Verify each acceptance criterion in the task file is actually met
6. Write feedback to the "Review Feedback" section in the task file:
   ```
   ### Round N
   **build**: pass | fail | skipped (details if fail)
   **lint**: pass | fail | skipped (details if fail)
   **typecheck**: pass | fail | skipped (details if fail)
   **test**: pass | fail | skipped (details if fail)

   **Acceptance Criteria**:
   - [x] Criterion 1 — verified: explanation
   - [ ] Criterion 2 — not met: what needs to change

   **Issues**:
   - Specific, actionable feedback

   **Verdict**: approved | needs-work
   ```
7. Message the worker:
   - If approved: "Task {N} approved"
   - If needs-work: "Task {N} needs work: {brief summary, full details in file}"
8. If approved:
   - Mark acceptance criteria [x] in the task file
   - Use TaskUpdate to mark the task completed in the shared task list
   - Message the lead: "Task {N} approved and marked complete"

Rules:
- Do NOT modify source code, tests, or configuration files
- Only run quality checks that are marked as available in the task context
- Provide specific, actionable feedback
- If a quality check is not available, skip it (do not fail the review)
- If unsure about a criterion, message the worker to ask for clarification
```

### 8. Monitor Execution

After spawning teammates, the lead monitors progress via:

1. **Incoming messages**: Workers and reviewers will message you about blockers, questions, or completion
2. **Task list status**: Use TaskList periodically to check overall progress
3. **Escalations**: If a teammate is stuck or asks for help, provide guidance

The lead operates in **delegate mode**:
- Can read files, check task status, send messages to teammates
- Cannot edit code, create files, or directly implement work
- Coordinates and unblocks, but does not execute

### 9. Commit Changes Per Task

After each task is marked completed in the shared task list:

1. Check the worktree for uncommitted changes: `git status`
2. If changes exist, use the `workspace-commit` skill to commit them:
   - Read git identity from `config.yaml`
   - Stage and commit changes in each affected repo subdirectory
   - Use conventional commit format based on task content (feat, fix, refactor, chore, docs, test)
   - The commit message should describe what the task accomplished

This maintains the current workspace behavior: **one commit per task**.

Alternatively, if the worker or reviewer can invoke workspace-commit directly, they can handle commits. This is a discovery item to determine during implementation.

### 10. Check for Completion

After each task completes and is committed, check the task list:

- If all tasks are completed → proceed to cleanup
- If tasks remain and are unblocked → continue monitoring
- If tasks remain but are all blocked → investigate and message teammates to resolve

### 11. Cleanup Team

When all tasks are completed:

1. Use SendMessage with `type: "shutdown_request"` to gracefully shut down each teammate:
   - Message worker: shutdown request
   - Message reviewer: shutdown request
2. Wait for shutdown confirmations
3. Use Teammate tool with `operation: "cleanup"` to remove team and task directories

Report execution summary to user:
```
Execution complete:
- 5 tasks completed
- 5 commits created
- Team cleaned up
```

## Team Lifecycle

```
User invokes skill
    │
    ▼
Lead reads task files
    │
    ▼
Lead creates team
    │
    ▼
Lead populates shared task list (with dependencies)
    │
    ▼
Lead spawns worker + reviewer teammates
    │
    ▼
Worker claims task → implements → messages reviewer
    │
    ▼
Reviewer reviews → messages worker (approved or needs-work)
    │
    ├─ needs-work → worker revises → messages reviewer again
    │
    └─ approved → reviewer marks complete → lead commits → next task unblocks
    │
    ▼
All tasks complete → lead commits final changes → lead cleans up team
```

## Task Source of Truth

**Task files** (`.claude/workitems/{type}/{name}/tasks/*.md`) are the authoritative source.

**Shared task list** is a coordination layer for:
- Dependency management and automatic unblocking
- Status tracking for team monitoring
- Task claiming by workers

Workers and reviewers read from and write to task files. The shared task list mirrors the status and dependencies but does not replace the files.

## Crash Recovery Strategy

If the lead session crashes or is restarted:

1. **Check if team still exists**: Read `~/.claude/teams/{type}-{name}-execution/config.json`
2. **If team exists**: Reconnect to it, check task list status, continue monitoring
3. **If team does not exist**:
   - Read task files to assess progress (subtasks, worker notes, commits)
   - Create a new team
   - Populate shared task list from current task file states
   - Spawn new worker and reviewer teammates
   - Resume from where things left off (tasks already completed remain completed, in-progress tasks continue)

Teammates that crash can be respawned by the lead using the same spawn prompts, and they will pick up context from the task files and shared task list.

## Delegate Mode

The lead is restricted to coordination tools only:
- **Can use**: Read, Grep, Glob, Bash (read-only), TaskList, TaskGet, TaskUpdate, SendMessage, Teammate, Skill
- **Cannot use**: Edit, Write, NotebookEdit (or any code modification tools)

If Claude Code supports Shift+Tab for delegate mode, use it. Otherwise, document this restriction and enforce it manually in the skill.

## Parallel Execution

Independent tasks (no dependency relationship) can be worked on simultaneously:
- Multiple workers can be spawned (1 per independent task chain)
- Each worker claims the next available unblocked task from the shared list
- Shared task list handles dependency unblocking automatically

For this initial implementation, spawn **1 worker** to keep it simple. Future iterations can explore multi-worker parallelism.

## Discovery: Skill Invocation by Teammates

**Unknown during design**: How teammates invoke workspace skills like `workspace-commit` or `workspace-worktree`.

During implementation:
1. Test if teammates can call the Skill tool to invoke workspace-commit
2. Test if teammates can call the Skill tool to invoke workspace-worktree
3. If yes, document in the teammate spawn prompts
4. If no, the lead must handle these operations (e.g., lead commits after each task approval)

## Logging

All teammate activity is logged to `.claude/workitems/{type}/{name}/logs/` automatically by the agent teams system.

The lead should also log key events (task completion, commits, blockers) to a `execution.log` file in the same directory for later review.

## File Locations

- Task files: `.claude/workitems/{type}/{name}/tasks/*.md`
- Worktree path: `.claude/workitems/{type}/{name}/worktree.path`
- Logs: `.claude/workitems/{type}/{name}/logs/`
- Team config: `~/.claude/teams/{type}-{name}-execution/config.json`
- Shared task list: `~/.claude/tasks/{type}-{name}-execution/`
