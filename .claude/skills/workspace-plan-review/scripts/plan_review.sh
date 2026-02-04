#!/bin/bash
set -euo pipefail

WORKITEMS_DIR=".claude/workitems"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Resolve plan file and workitem directory
if [ -n "${1:-}" ]; then
  if [ -f "$1" ]; then
    PLAN_FILE="$1"
    WORKITEM_DIR="$(dirname "$PLAN_FILE")"
  elif [ -f "$WORKITEMS_DIR/$1/plan.md" ]; then
    PLAN_FILE="$WORKITEMS_DIR/$1/plan.md"
    WORKITEM_DIR="$WORKITEMS_DIR/$1"
  else
    echo "❌ Plan not found: $1"
    echo "   Searched: $1, $WORKITEMS_DIR/$1/plan.md"
    exit 1
  fi
  MAX_ROUNDS="${2:-3}"
else
  if [ ! -d "$WORKITEMS_DIR" ]; then
    echo "❌ No workitems directory found at $WORKITEMS_DIR"
    echo "   Usage: plan_review.sh [type/name|plan-path] [max-rounds]"
    exit 1
  fi

  WORKITEMS=()
  while IFS= read -r f; do
    WORKITEMS+=("$f")
  done < <(find "$WORKITEMS_DIR" -name "plan.md" -mindepth 3 -maxdepth 3 | sort)

  if [ ${#WORKITEMS[@]} -eq 0 ]; then
    echo "❌ No workitems with plan.md found"
    exit 1
  fi

  echo "📋 Available workitems:"
  echo ""
  for i in "${!WORKITEMS[@]}"; do
    REL_PATH="${WORKITEMS[$i]#$WORKITEMS_DIR/}"
    TYPE_NAME="${REL_PATH%/plan.md}"
    echo "  $((i + 1)). $TYPE_NAME"
  done
  echo ""
  read -rp "Select a workitem [1-${#WORKITEMS[@]}]: " SELECTION

  if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#WORKITEMS[@]} ]; then
    echo "❌ Invalid selection"
    exit 1
  fi

  PLAN_FILE="${WORKITEMS[$((SELECTION - 1))]}"
  WORKITEM_DIR="$(dirname "$PLAN_FILE")"
  MAX_ROUNDS="${2:-3}"
fi

# Detect workitem type from path (e.g. .claude/workitems/bugfix/login-timeout → bugfix)
WORKITEM_REL="${WORKITEM_DIR#$WORKITEMS_DIR/}"
WORKITEM_TYPE="${WORKITEM_REL%%/*}"

echo "📄 Plan: $PLAN_FILE"
echo "📂 Type: $WORKITEM_TYPE"
echo ""

# Logging
LOG_DIR="$WORKITEM_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/review-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "📝 Logging to: $LOG_FILE"
echo ""

# Copy type-specific criteria to workitem if not present
LOCAL_CRITERIA="$WORKITEM_DIR/review-criteria.md"
TEMPLATE_CRITERIA="${REVIEW_CRITERIA_FILE:-$SKILL_DIR/criteria/$WORKITEM_TYPE.md}"

if [ ! -f "$LOCAL_CRITERIA" ]; then
  if [ -f "$TEMPLATE_CRITERIA" ]; then
    cp "$TEMPLATE_CRITERIA" "$LOCAL_CRITERIA"
    echo "📝 Created review criteria from $WORKITEM_TYPE template"
  else
    echo "❌ No criteria template found for type: $WORKITEM_TYPE"
    echo "   Searched: $TEMPLATE_CRITERIA"
    exit 1
  fi
fi

echo "📋 Using criteria: $LOCAL_CRITERIA"
echo ""

CRITERIA=$(cat "$LOCAL_CRITERIA")

if ! grep -q "## Review Status" "$PLAN_FILE" 2>/dev/null; then
  EXISTING=$(cat "$PLAN_FILE")
  cat > "$PLAN_FILE" <<EOF
## Review Status

- [ ] Reviewed

### Reviewer Notes
<!-- No notes yet -->

---

$EXISTING
EOF
  echo "📝 Injected review header into plan"
fi

PLANNER_PROMPT="You are a planner addressing reviewer feedback. Read $PLAN_FILE.
Address every point listed under '### Reviewer Notes'.
Update the plan content below the '---' separator.
Do NOT modify '## Review Status', the checkbox, or '### Reviewer Notes'."

REVIEWER_PROMPT="You are a critical senior engineer reviewing a development plan. Read $PLAN_FILE.
Evaluate against the criteria in $LOCAL_CRITERIA and mark [x] for each criterion met in that file.

Also write your feedback under '### Reviewer Notes' in the plan file.
If ALL criteria in $LOCAL_CRITERIA are marked [x], change '- [ ] Reviewed' to '- [x] Reviewed' in the plan file.
Do NOT modify any plan content below the '---' separator."

for i in $(seq 1 "$MAX_ROUNDS"); do
  echo "========================================="
  echo "  Round $i/$MAX_ROUNDS: Reviewer"
  echo "========================================="
  claude -p "$REVIEWER_PROMPT" --allowedTools "Read,Write"

  if grep -q "\[x\] Reviewed" "$PLAN_FILE"; then
    echo ""
    echo "✅ Plan approved at round $i"
    exit 0
  fi

  echo ""
  echo "========================================="
  echo "  Round $i/$MAX_ROUNDS: Planner"
  echo "========================================="
  claude -p "$PLANNER_PROMPT" --allowedTools "Edit,Read,Write,Bash"

  echo ""
done

echo "❌ Max rounds ($MAX_ROUNDS) reached without approval"
exit 1