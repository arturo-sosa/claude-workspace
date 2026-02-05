#!/bin/bash
set -euo pipefail

WORKITEMS_DIR=".claude/workitems"
MAX_ROUNDS="${MAX_TASK_ROUNDS:-5}"

# Cross-platform sed -i
sedi() {
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Update status field in a task file
set_status() {
  local file="$1" new_status="$2"
  sedi '/^## Status$/,/^$/{/^## Status$/!{/^$/!s/.*/'"$new_status"'/}}' "$file"
}

# Extract dependency task numbers (cross-platform, no grep -P)
extract_dep_numbers() {
  echo "$1" | grep -oE 'Task [0-9]+' | grep -oE '[0-9]+' || true
}

# Logging
setup_logging() {
  LOG_DIR="$WORKITEM_DIR/logs"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/execution-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "📝 Logging to: $LOG_FILE"
}

# Resolve workitem
if [ -n "${1:-}" ]; then
  if [ -d "$WORKITEMS_DIR/$1/tasks" ]; then
    WORKITEM_DIR="$WORKITEMS_DIR/$1"
  elif [ -d "$1/tasks" ]; then
    WORKITEM_DIR="$1"
  else
    echo "❌ Workitem tasks not found: $1"
    echo "   Searched: $WORKITEMS_DIR/$1/tasks, $1/tasks"
    exit 1
  fi
else
  if [ ! -d "$WORKITEMS_DIR" ]; then
    echo "❌ No workitems directory found at $WORKITEMS_DIR"
    echo "   Usage: task_executor.sh [type/name|path]"
    exit 1
  fi

  WORKITEMS=()
  while IFS= read -r f; do
    DIR=$(dirname "$f")
    if [ -d "$DIR/tasks" ]; then
      WORKITEMS+=("$DIR")
    fi
  done < <(find "$WORKITEMS_DIR" -name "plan.md" -mindepth 3 -maxdepth 3 | sort)

  if [ ${#WORKITEMS[@]} -eq 0 ]; then
    echo "❌ No workitems with tasks found"
    exit 1
  fi

  echo "📋 Available workitems:"
  echo ""
  for i in "${!WORKITEMS[@]}"; do
    REL="${WORKITEMS[$i]#$WORKITEMS_DIR/}"
    TOTAL=$(find "${WORKITEMS[$i]}/tasks" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    DONE=$(grep -rl "^completed$" "${WORKITEMS[$i]}/tasks/"*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  $((i + 1)). $REL ($DONE/$TOTAL completed)"
  done
  echo ""
  read -rp "Select a workitem [1-${#WORKITEMS[@]}]: " SELECTION

  if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#WORKITEMS[@]} ]; then
    echo "❌ Invalid selection"
    exit 1
  fi

  WORKITEM_DIR="${WORKITEMS[$((SELECTION - 1))]}"
fi

TASKS_DIR="$WORKITEM_DIR/tasks"
WORKITEM_REL="${WORKITEM_DIR#$WORKITEMS_DIR/}"
WORKTREE_PATH_FILE="$WORKITEM_DIR/worktree.path"

# Prerequisite validation
if [ ! -d "$TASKS_DIR" ] || [ -z "$(ls "$TASKS_DIR"/*.md 2>/dev/null)" ]; then
  echo "❌ No task files found in $TASKS_DIR"
  echo "   Run workspace-task-generate first to create task files from the plan."
  exit 1
fi

# Start logging
setup_logging

echo ""
echo "🚀 Executing tasks for: $WORKITEM_REL"
echo "   Tasks directory: $TASKS_DIR"
echo "   Max rounds per task: $MAX_ROUNDS"
echo "   Started: $(date)"
echo ""

# Recover stuck in-progress tasks from previous crashed runs
for task_file in "$TASKS_DIR"/*.md; do
  [ -f "$task_file" ] || continue
  STATUS=$(sed -n '/^## Status$/,/^$/p' "$task_file" | tail -1 | tr -d '[:space:]')
  if [ "$STATUS" = "in-progress" ]; then
    echo "🔄 Recovering stuck task: $(basename "$task_file") → pending"
    set_status "$task_file" "pending"
  fi
done

resolve_worktree_cwd() {
  local task_file="$1"

  # Task 01 creates worktrees — runs from workspace root
  if [[ "$(basename "$task_file")" == 01-* ]]; then
    echo "."
    return
  fi

  # All other tasks run from the workitem worktree: worktrees/{type}/{name}/
  # Individual repos are subdirectories the worker navigates into as needed
  if [ -f "$WORKTREE_PATH_FILE" ]; then
    local wt_path
    wt_path=$(cat "$WORKTREE_PATH_FILE" | tr -d '[:space:]')
    if [ -d "$wt_path" ]; then
      echo "$wt_path"
      return
    fi
  fi

  echo "⚠️  No worktree.path found, working from workspace root" >&2
  echo "."
}

check_dependencies() {
  local task_file="$1"
  local deps_section
  deps_section=$(sed -n '/^## Dependencies/,/^## /p' "$task_file" | head -n -1)

  if echo "$deps_section" | grep -qi "none\|no dependencies"; then
    return 0
  fi

  local dep_numbers
  dep_numbers=$(extract_dep_numbers "$deps_section")

  if [ -z "$dep_numbers" ]; then
    return 0
  fi

  for num in $dep_numbers; do
    local padded
    padded=$(printf "%02d" "$num")
    local dep_file
    dep_file=$(find "$TASKS_DIR" -name "${padded}-*.md" 2>/dev/null | head -1)

    if [ -z "$dep_file" ]; then
      continue
    fi

    local dep_status
    dep_status=$(sed -n '/^## Status$/,/^$/p' "$dep_file" | tail -1 | tr -d '[:space:]')

    if [ "$dep_status" != "completed" ]; then
      return 1
    fi
  done

  return 0
}

# Track stats
TASKS_COMPLETED=0
TASKS_FAILED=0
TASKS_SKIPPED=0
START_TIME=$(date +%s)

while true; do
  NEXT_TASK=""

  for task_file in "$TASKS_DIR"/*.md; do
    [ -f "$task_file" ] || continue

    STATUS=$(sed -n '/^## Status$/,/^$/p' "$task_file" | tail -1 | tr -d '[:space:]')

    if [ "$STATUS" != "pending" ]; then
      continue
    fi

    if check_dependencies "$task_file"; then
      BLOCKERS=$(sed -n '/^## Blockers/,/^## /p' "$task_file" | head -n -1 | grep -v "^## Blockers" | grep -v "^<!--" | grep -v "^$" || true)
      if [ -n "$BLOCKERS" ] && ! echo "$BLOCKERS" | grep -qi "none"; then
        echo "⚠️  $(basename "$task_file") has blockers, skipping:"
        echo "$BLOCKERS" | sed 's/^/   /'
        echo ""
        TASKS_SKIPPED=$((TASKS_SKIPPED + 1))
        continue
      fi

      NEXT_TASK="$task_file"
      break
    fi
  done

  if [ -z "$NEXT_TASK" ]; then
    PENDING=$(grep -rl "^pending$" "$TASKS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    IN_PROGRESS=$(grep -rl "^in-progress$" "$TASKS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')

    echo ""
    echo "========================================="
    echo "  Execution Summary"
    echo "========================================="
    echo "  Completed: $TASKS_COMPLETED"
    echo "  Failed:    $TASKS_FAILED"
    echo "  Skipped:   $TASKS_SKIPPED (blocked)"
    echo "  Pending:   $PENDING"
    echo "  Duration:  $(( ($(date +%s) - START_TIME) / 60 ))m"
    echo "  Log:       $LOG_FILE"
    echo "========================================="

    if [ "$PENDING" -eq 0 ] && [ "$IN_PROGRESS" -eq 0 ] && [ "$TASKS_FAILED" -eq 0 ]; then
      echo ""
      echo "🎉 All tasks completed!"
    elif [ "$TASKS_FAILED" -gt 0 ]; then
      echo ""
      echo "❌ Some tasks failed. Review logs and task files for details."
    else
      echo ""
      echo "🔒 Remaining tasks are blocked."
    fi
    exit 0
  fi

  TASK_NAME=$(basename "$NEXT_TASK")
  TASK_ABS_PATH="$(cd "$(dirname "$NEXT_TASK")" && pwd)/$(basename "$NEXT_TASK")"
  WORK_CWD=$(resolve_worktree_cwd "$NEXT_TASK")

  echo "========================================="
  echo "  Executing: $TASK_NAME"
  echo "  Working directory: $WORK_CWD"
  echo "========================================="
  echo ""

  set_status "$NEXT_TASK" "in-progress"

  WORKER_PROMPT="You are a task worker. Read the task file at $TASK_ABS_PATH and implement everything it requires.
Follow these rules:
- Work through subtasks in order
- Follow existing codebase patterns
- Write tests per the testing strategy in the task context
- Mark subtasks [x] as you complete them in the task file
- Append your work log to the Worker Notes section in the task file
- Do NOT mark acceptance criteria or change Status
- Do NOT modify Review Feedback"

  REVIEWER_PROMPT="You are a task reviewer. Read the task file at $TASK_ABS_PATH and evaluate the worker's implementation.
Follow these rules:
- Verify all subtasks are marked complete
- Run only the quality checks listed as available in the task's Context section
- Skip any checks not marked as available — do not fail for missing processes
- Verify each acceptance criterion and mark [x] if met in the task file
- Write detailed feedback in the Review Feedback section of the task file
- End with verdict: approved or needs-work
- Do NOT modify any source code, Worker Notes, or Status"

  APPROVED=false

  for round in $(seq 1 "$MAX_ROUNDS"); do
    echo "-----------------------------------------"
    echo "  Round $round/$MAX_ROUNDS: Worker"
    echo "-----------------------------------------"
    (cd "$WORK_CWD" && claude -p "$WORKER_PROMPT" --allowedTools "Edit,Read,Write,Bash")

    echo ""
    echo "-----------------------------------------"
    echo "  Round $round/$MAX_ROUNDS: Reviewer"
    echo "-----------------------------------------"
    (cd "$WORK_CWD" && claude -p "$REVIEWER_PROMPT" --allowedTools "Read,Write,Bash")

    UNCHECKED_AC=$(grep -c "^- \[ \]" "$NEXT_TASK" || echo "0")
    TOTAL_AC=$(grep -c "^- \[.\]" "$NEXT_TASK" || echo "0")

    if [ "$UNCHECKED_AC" -eq 0 ] && [ "$TOTAL_AC" -gt 0 ]; then
      APPROVED=true
      break
    fi

    echo ""
    echo "⏳ Not approved yet ($((TOTAL_AC - UNCHECKED_AC))/$TOTAL_AC AC met). Continuing..."
    echo ""
  done

  if [ "$APPROVED" = true ]; then
    set_status "$NEXT_TASK" "completed"
    TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
    echo ""
    echo "✅ $TASK_NAME completed!"

    # Commit changes if worktree exists and task is not 01 (setup)
    if [[ "$(basename "$NEXT_TASK")" != 01-* ]] && [ "$WORK_CWD" != "." ] && [ -d "$WORK_CWD" ]; then
      COMMIT_SCRIPT=".claude/skills/workspace-commit/scripts/commit.sh"
      if [ -f "$COMMIT_SCRIPT" ]; then
        echo ""
        echo "  📦 Committing changes..."
        bash "$COMMIT_SCRIPT" "$WORK_CWD" || echo "  ⚠️  Commit step failed, continuing..."
      fi
    fi
  else
    TASKS_FAILED=$((TASKS_FAILED + 1))
    echo ""
    echo "❌ $TASK_NAME did not pass review after $MAX_ROUNDS rounds"
    echo "   Status left as in-progress for manual review"
  fi

  echo ""
done