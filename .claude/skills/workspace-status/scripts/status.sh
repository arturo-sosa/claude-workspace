#!/bin/bash
set -euo pipefail

WORKITEMS_DIR=".claude/workitems"
WORKTREES_DIR="worktrees"

# --- HELPERS ---

count_tasks_by_status() {
  local tasks_dir="$1" status="$2"
  grep -rl "^${status}$" "$tasks_dir"/*.md 2>/dev/null | wc -l | tr -d ' '
}

review_status() {
  local workitem_dir="$1"
  local plan="$workitem_dir/plan.md"
  local criteria="$workitem_dir/review-criteria.md"

  if [ ! -f "$plan" ]; then
    echo "no plan"
    return
  fi

  if grep -q "\[x\] Reviewed" "$plan" 2>/dev/null; then
    echo "approved"
    return
  fi

  if grep -q "## Review Status" "$plan" 2>/dev/null; then
    echo "in review"
    return
  fi

  if [ -f "$criteria" ]; then
    echo "in review"
    return
  fi

  echo "not reviewed"
}

worktree_status() {
  local workitem_dir="$1"
  local wt_file="$workitem_dir/worktree.path"

  if [ ! -f "$wt_file" ]; then
    echo "none"
    return
  fi

  local wt_path
  wt_path=$(cat "$wt_file" | tr -d '[:space:]')

  if [ ! -d "$wt_path" ]; then
    echo "missing"
    return
  fi

  local repo_count=0
  local dirty_count=0
  for repo_dir in "$wt_path"/*/; do
    [ -d "$repo_dir" ] || continue
    [ -f "$repo_dir/.git" ] || continue
    repo_count=$((repo_count + 1))
    local changes
    changes=$(cd "$repo_dir" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$changes" -gt 0 ]; then
      dirty_count=$((dirty_count + 1))
    fi
  done

  if [ "$repo_count" -eq 0 ]; then
    echo "empty"
  elif [ "$dirty_count" -gt 0 ]; then
    echo "$repo_count repos ($dirty_count dirty)"
  else
    echo "$repo_count repos (clean)"
  fi
}

phase_indicator() {
  local workitem_dir="$1"
  local has_plan="n" has_review="n" has_tasks="n" has_worktree="n"

  [ -f "$workitem_dir/plan.md" ] && has_plan="y"
  [ -f "$workitem_dir/review-criteria.md" ] && has_review="y"
  [ -d "$workitem_dir/tasks" ] && [ -n "$(ls "$workitem_dir/tasks/"*.md 2>/dev/null)" ] && has_tasks="y"
  [ -f "$workitem_dir/worktree.path" ] && has_worktree="y"

  if [ "$has_tasks" = "y" ]; then
    local total pending completed
    total=$(find "$workitem_dir/tasks" -name "*.md" | wc -l | tr -d ' ')
    completed=$(count_tasks_by_status "$workitem_dir/tasks" "completed")
    if [ "$completed" -eq "$total" ] && [ "$total" -gt 0 ]; then
      echo "done"
    else
      echo "executing"
    fi
  elif [ "$has_review" = "y" ]; then
    if grep -q "\[x\] Reviewed" "$workitem_dir/plan.md" 2>/dev/null; then
      echo "reviewed"
    else
      echo "reviewing"
    fi
  elif [ "$has_plan" = "y" ]; then
    echo "planned"
  else
    echo "empty"
  fi
}

# --- DETAIL VIEW ---

show_detail() {
  local workitem_path="$1"
  local workitem_dir="$WORKITEMS_DIR/$workitem_path"

  if [ ! -d "$workitem_dir" ]; then
    echo "❌ Workitem not found: $workitem_path"
    exit 1
  fi

  local workitem_type="${workitem_path%%/*}"
  local workitem_name="${workitem_path#*/}"

  echo "========================================="
  echo "  $workitem_type/$workitem_name"
  echo "========================================="
  echo ""

  # Phase
  echo "  Phase:    $(phase_indicator "$workitem_dir")"
  echo "  Review:   $(review_status "$workitem_dir")"
  echo "  Worktree: $(worktree_status "$workitem_dir")"
  echo ""

  # Tasks
  if [ -d "$workitem_dir/tasks" ] && [ -n "$(ls "$workitem_dir/tasks/"*.md 2>/dev/null)" ]; then
    local total pending in_progress completed
    total=$(find "$workitem_dir/tasks" -name "*.md" | wc -l | tr -d ' ')
    pending=$(count_tasks_by_status "$workitem_dir/tasks" "pending")
    in_progress=$(count_tasks_by_status "$workitem_dir/tasks" "in-progress")
    completed=$(count_tasks_by_status "$workitem_dir/tasks" "completed")

    echo "  Tasks: $completed/$total completed"
    echo ""

    for task_file in "$workitem_dir/tasks"/*.md; do
      [ -f "$task_file" ] || continue
      local name status icon
      name=$(basename "$task_file" .md)
      status=$(sed -n '/^## Status$/,/^$/p' "$task_file" | tail -1 | tr -d '[:space:]')
      case "$status" in
        completed)   icon="✅" ;;
        in-progress) icon="🔄" ;;
        pending)     icon="⏳" ;;
        *)           icon="❓" ;;
      esac
      echo "    $icon $name"
    done
  else
    echo "  Tasks: none generated"
  fi

  echo ""

  # Logs
  if [ -d "$workitem_dir/logs" ]; then
    local log_count
    log_count=$(find "$workitem_dir/logs" -name "*.log" | wc -l | tr -d ' ')
    if [ "$log_count" -gt 0 ]; then
      echo "  Logs: $log_count file(s)"
      local latest
      latest=$(ls -t "$workitem_dir/logs"/*.log 2>/dev/null | head -1)
      echo "    Latest: $latest"
    fi
  fi
}

# --- OVERVIEW ---

show_overview() {
  if [ ! -d "$WORKITEMS_DIR" ]; then
    echo "ℹ️  No workitems directory found"
    exit 0
  fi

  local found=0

  echo "========================================="
  echo "  Workspace Status"
  echo "========================================="
  echo ""

  for type_dir in "$WORKITEMS_DIR"/*/; do
    [ -d "$type_dir" ] || continue
    local type_name
    type_name=$(basename "$type_dir")

    for workitem_dir in "$type_dir"/*/; do
      [ -d "$workitem_dir" ] || continue
      local name
      name=$(basename "$workitem_dir")
      found=$((found + 1))

      local phase review tasks_info
      phase=$(phase_indicator "$workitem_dir")
      review=$(review_status "$workitem_dir")

      # Task progress
      if [ -d "$workitem_dir/tasks" ] && [ -n "$(ls "$workitem_dir/tasks/"*.md 2>/dev/null)" ]; then
        local total completed
        total=$(find "$workitem_dir/tasks" -name "*.md" | wc -l | tr -d ' ')
        completed=$(count_tasks_by_status "$workitem_dir/tasks" "completed")
        tasks_info="$completed/$total tasks"
      else
        tasks_info="no tasks"
      fi

      # Phase icon
      local icon
      case "$phase" in
        done)      icon="✅" ;;
        executing) icon="🔧" ;;
        reviewed)  icon="📋" ;;
        reviewing) icon="🔍" ;;
        planned)   icon="📝" ;;
        *)         icon="❓" ;;
      esac

      printf "  %s  %-12s %-25s %-12s %s\n" "$icon" "$type_name" "$name" "$phase" "$tasks_info"
    done
  done

  if [ "$found" -eq 0 ]; then
    echo "  No workitems found"
  fi

  echo ""
}

# --- MAIN ---

if [ -n "${1:-}" ]; then
  show_detail "$1"
else
  show_overview
fi