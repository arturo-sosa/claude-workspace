#!/bin/bash
set -euo pipefail

WORKITEMS_DIR=".claude/workitems"
WORKTREES_DIR="worktrees"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WORKTREE_SCRIPT=".claude/skills/workspace-worktree/scripts/worktree.sh"

# --- Resolve workitem ---

if [ -n "${1:-}" ]; then
  if [ -d "$WORKITEMS_DIR/$1" ]; then
    WORKITEM_DIR="$WORKITEMS_DIR/$1"
    WORKITEM_REL="$1"
  else
    echo "❌ Workitem not found: $1"
    exit 1
  fi
else
  if [ ! -d "$WORKITEMS_DIR" ]; then
    echo "❌ No workitems directory found"
    exit 1
  fi

  WORKITEMS=()
  for type_dir in "$WORKITEMS_DIR"/*/; do
    [ -d "$type_dir" ] || continue
    type_name=$(basename "$type_dir")
    [ "$type_name" = "archive" ] && continue
    for wi_dir in "$type_dir"/*/; do
      [ -d "$wi_dir" ] || continue
      [ -d "$wi_dir/tasks" ] || continue
      WORKITEMS+=("${type_name}/$(basename "$wi_dir")")
    done
  done

  if [ ${#WORKITEMS[@]} -eq 0 ]; then
    echo "❌ No workitems with tasks found"
    exit 1
  fi

  echo "📋 Available workitems:"
  echo ""
  for i in "${!WORKITEMS[@]}"; do
    echo "  $((i + 1)). ${WORKITEMS[$i]}"
  done
  echo ""
  read -rp "Select a workitem [1-${#WORKITEMS[@]}]: " SELECTION

  if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#WORKITEMS[@]} ]; then
    echo "❌ Invalid selection"
    exit 1
  fi

  WORKITEM_REL="${WORKITEMS[$((SELECTION - 1))]}"
  WORKITEM_DIR="$WORKITEMS_DIR/$WORKITEM_REL"
fi

WORKITEM_TYPE="${WORKITEM_REL%%/*}"
WORKITEM_NAME="${WORKITEM_REL#*/}"
TASKS_DIR="$WORKITEM_DIR/tasks"
WT_PATH_FILE="$WORKITEM_DIR/worktree.path"

# --- Logging ---

LOG_DIR="$WORKITEM_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/archive-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "📦 Archiving: $WORKITEM_REL"
echo "📝 Logging to: $LOG_FILE"
echo ""

# --- 1. Validate completion ---

echo "========================================="
echo "  Step 1: Validate Completion"
echo "========================================="

if [ ! -d "$TASKS_DIR" ] || [ -z "$(ls "$TASKS_DIR"/*.md 2>/dev/null)" ]; then
  echo "❌ No task files found. Nothing to archive."
  exit 1
fi

INCOMPLETE=()
for task_file in "$TASKS_DIR"/*.md; do
  [ -f "$task_file" ] || continue
  STATUS=$(sed -n '/^## Status$/,/^$/p' "$task_file" | grep -v "^## Status$" | grep -v "^$" | head -1 | tr -d '[:space:]')
  if [ "$STATUS" != "completed" ]; then
    INCOMPLETE+=("$(basename "$task_file"): $STATUS")
  fi
done

if [ ${#INCOMPLETE[@]} -gt 0 ]; then
  echo "❌ Cannot archive — incomplete tasks:"
  for item in "${INCOMPLETE[@]}"; do
    echo "   $item"
  done
  exit 1
fi

echo "✅ All tasks completed"
echo ""

# --- 2. Generate workitem report ---

echo "========================================="
echo "  Step 2: Generate Workitem Report"
echo "========================================="

PLAN_FILE="$WORKITEM_DIR/plan.md"
REPORT_FILE="$WORKITEM_DIR/report.md"
TASK_FILES=$(ls "$TASKS_DIR"/*.md | tr '\n' ' ')

REPORT_PROMPT="You are a technical writer generating a workitem completion report.

Read the plan at $PLAN_FILE and all task files in $TASKS_DIR/.
Pay close attention to Worker Notes and Review Feedback in each task — they contain what actually happened.

Generate a report at $REPORT_FILE with these sections:

# Report: $WORKITEM_TYPE/$WORKITEM_NAME

## Summary
What was accomplished in 2-3 sentences.

## Changes
For each repo affected, list the key changes (files created/modified, what was added/removed/changed).

## Decisions
Key technical decisions made during implementation and why.

## Issues
Problems encountered and how they were resolved.

## Testing
What was tested and how.

## Follow-Up
Any tech debt introduced, known limitations, or future work items.

Be factual and concise. Base everything on what the worker notes and review feedback say actually happened, not what the plan said should happen."

claude -p "$REPORT_PROMPT" --allowedTools "Read,Write"

if [ -f "$REPORT_FILE" ]; then
  echo "✅ Report generated: $REPORT_FILE"
else
  echo "⚠️  Report generation may have failed, continuing..."
fi
echo ""

# --- 3. Per-repo documentation ---

echo "========================================="
echo "  Step 3: Per-Repo Documentation"
echo "========================================="

if [ -f "$WT_PATH_FILE" ]; then
  WT_BASE=$(cat "$WT_PATH_FILE" | tr -d '[:space:]')
else
  WT_BASE=""
fi

if [ -n "$WT_BASE" ] && [ -d "$WT_BASE" ]; then
  for repo_dir in "$WT_BASE"/*/; do
    [ -d "$repo_dir" ] || continue
    [ -f "$repo_dir/.git" ] || continue
    REPO_NAME=$(basename "$repo_dir")

    echo ""
    echo "  📂 $REPO_NAME"

    REPO_DOC_PROMPT="You are documenting changes made to the $REPO_NAME repository as part of workitem $WORKITEM_TYPE/$WORKITEM_NAME.

Read the workitem report at $REPORT_FILE.
Look at the changes in $repo_dir using git diff and git log on the $WORKITEM_TYPE/$WORKITEM_NAME branch.

Do two things:

1. Create $repo_dir/docs/${WORKITEM_TYPE}-${WORKITEM_NAME}.md with documentation relevant to this repo:
   - What changed in this repo and why
   - Files affected
   - Any new patterns or conventions introduced
   - Testing details specific to this repo
   Only include what is relevant to this repo, not the full workitem report.

2. Check if $repo_dir/CLAUDE.md exists. If it does, evaluate whether it needs updates.
   ONLY update CLAUDE.md for structural changes:
   - Infrastructure or architecture changes
   - New or removed dependencies
   - New conventions or patterns introduced
   - API changes (endpoints, contracts, schemas)
   - Configuration changes
   Do NOT add feature summaries, bug descriptions, or changelog entries.
   If no structural changes apply, do NOT modify CLAUDE.md.

3. After creating/updating docs, commit the changes:
   git add docs/ CLAUDE.md
   git commit -m 'docs: $WORKITEM_TYPE/$WORKITEM_NAME documentation'"

    (cd "$repo_dir" && claude -p "$REPO_DOC_PROMPT" --allowedTools "Read,Write,Edit,Bash")

    echo "  ✅ $REPO_NAME done"
  done
else
  echo "⚠️  No worktrees found, skipping per-repo documentation"
fi

echo ""

# --- 4. Remove worktrees ---

echo "========================================="
echo "  Step 4: Remove Worktrees"
echo "========================================="

if [ -x "$WORKTREE_SCRIPT" ]; then
  bash "$WORKTREE_SCRIPT" remove "$WORKITEM_REL"
  echo "✅ Worktrees removed"
elif [ -n "$WT_BASE" ] && [ -d "$WT_BASE" ]; then
  echo "⚠️  Worktree script not found, removing manually"
  rm -rf "$WT_BASE"
  echo "✅ Worktree directory removed"
else
  echo "ℹ️  No worktrees to remove"
fi

echo ""

# --- 5. Move to archive ---

echo "========================================="
echo "  Step 5: Move to Archive"
echo "========================================="

ARCHIVE_DIR="$WORKITEMS_DIR/archive/$WORKITEM_TYPE/$WORKITEM_NAME"
mkdir -p "$(dirname "$ARCHIVE_DIR")"
mv "$WORKITEM_DIR" "$ARCHIVE_DIR"

echo "✅ Moved to: $ARCHIVE_DIR"
echo ""

# Clean up empty type directory
TYPE_DIR="$WORKITEMS_DIR/$WORKITEM_TYPE"
if [ -d "$TYPE_DIR" ] && [ -z "$(ls -A "$TYPE_DIR")" ]; then
  rmdir "$TYPE_DIR"
fi

echo "========================================="
echo "  Archive Complete"
echo "========================================="
echo "  Workitem: $WORKITEM_REL"
echo "  Report:   $ARCHIVE_DIR/report.md"
echo "  Archive:  $ARCHIVE_DIR/"
echo "========================================="