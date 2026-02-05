#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find workspace root
find_workspace_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/config.yaml" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

WORKSPACE_ROOT=$(find_workspace_root) || {
  echo "❌ Could not find workspace root (no config.yaml found)" >&2
  exit 1
}

GIT_COMMIT_SCRIPT="$WORKSPACE_ROOT/.claude/scripts/git-commit.sh"

if [ ! -f "$GIT_COMMIT_SCRIPT" ]; then
  echo "❌ git-commit.sh not found at $GIT_COMMIT_SCRIPT"
  exit 1
fi

# --- Args ---

TARGET="${1:-}"
DRY_RUN=false

for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
  fi
done

if [ -z "$TARGET" ]; then
  echo "❌ Usage: commit.sh <worktree-path> [--dry-run]"
  echo "   commit.sh worktrees/feature/auth-middleware/frontend"
  echo "   commit.sh worktrees/feature/auth-middleware"
  exit 1
fi

# --- Commit a single repo ---

commit_repo() {
  local repo_dir="$1"
  local repo_name
  repo_name=$(basename "$repo_dir")

  echo "  📂 $repo_name"

  # Check for changes
  local status
  status=$(cd "$repo_dir" && git status --porcelain 2>/dev/null)

  if [ -z "$status" ]; then
    echo "    ✅ Clean, nothing to commit"
    return 0
  fi

  local changed_files
  changed_files=$(echo "$status" | wc -l | tr -d ' ')
  echo "    📝 $changed_files changed file(s)"

  # Get diff for analysis
  local diff_file
  diff_file=$(mktemp)
  (cd "$repo_dir" && git diff HEAD --stat) > "$diff_file" 2>/dev/null || true
  (cd "$repo_dir" && git diff HEAD) >> "$diff_file" 2>/dev/null || true

  # Also capture untracked files
  local untracked
  untracked=$(cd "$repo_dir" && git ls-files --others --exclude-standard 2>/dev/null || true)

  local commit_plan_file
  commit_plan_file=$(mktemp)

  # LLM analyzes changes and outputs commit plan
  local analyze_prompt="You are analyzing git changes to create atomic commits.

Working directory: $repo_dir

Git status:
$status

Untracked files:
$untracked

Diff summary and content are in: $diff_file

Analyze the changes and create a commit plan. Write ONLY a JSON array to $commit_plan_file with this format:

[
  {
    \"files\": [\"path/to/file1.ts\", \"path/to/file2.ts\"],
    \"message\": \"feat(auth): add JWT middleware\"
  },
  {
    \"files\": [\"path/to/test.ts\"],
    \"message\": \"test(auth): add JWT middleware tests\"
  }
]

Rules:
- Each commit must be atomic — one logical change
- Use conventional commits: type(scope): description
- Types: feat, fix, refactor, test, docs, chore, style, ci
- Group related files (component + test + styles)
- Separate unrelated changes
- Order so dependencies come first
- Include ALL changed and untracked files — nothing should be left uncommitted
- File paths must be relative to the repo root"

  claude -p "$analyze_prompt" --allowedTools "Read,Write"

  # Validate commit plan exists
  if [ ! -f "$commit_plan_file" ] || [ ! -s "$commit_plan_file" ]; then
    echo "    ❌ Failed to generate commit plan"
    rm -f "$diff_file" "$commit_plan_file"
    return 1
  fi

  # Parse and execute commits
  local commit_count
  commit_count=$(python3 -c "
import json, sys
try:
    with open('$commit_plan_file') as f:
        content = f.read().strip()
        # Strip markdown fences if present
        if content.startswith('\`\`\`'):
            content = content.split('\n', 1)[1]
            content = content.rsplit('\`\`\`', 1)[0]
        plan = json.loads(content)
    print(len(plan))
except Exception as e:
    print(f'error: {e}', file=sys.stderr)
    print('0')
" 2>/dev/null)

  if [ "$commit_count" = "0" ]; then
    echo "    ❌ Failed to parse commit plan"
    rm -f "$diff_file" "$commit_plan_file"
    return 1
  fi

  echo "    📋 $commit_count commit(s) planned"

  # Execute each commit
  python3 -c "
import json, subprocess, sys, os

with open('$commit_plan_file') as f:
    content = f.read().strip()
    if content.startswith('\`\`\`'):
        content = content.split('\n', 1)[1]
        content = content.rsplit('\`\`\`', 1)[0]
    plan = json.loads(content)

dry_run = $( [ "$DRY_RUN" = true ] && echo "True" || echo "False" )
repo_dir = '$repo_dir'
commit_script = '$GIT_COMMIT_SCRIPT'

for i, commit in enumerate(plan):
    files = commit['files']
    message = commit['message']

    print(f'    {\"🔍\" if dry_run else \"💾\"} [{i+1}/{len(plan)}] {message}')
    for f in files:
        print(f'       {f}')

    if dry_run:
        continue

    # Stage files
    for f in files:
        result = subprocess.run(
            ['git', 'add', f],
            cwd=repo_dir,
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f'       ⚠️  Could not stage {f}: {result.stderr.strip()}')

    # Commit using wrapper
    result = subprocess.run(
        ['bash', commit_script, '-m', message],
        cwd=repo_dir,
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f'       ❌ Commit failed: {result.stderr.strip()}')
    else:
        print(f'       ✅ Committed')
"

  rm -f "$diff_file" "$commit_plan_file"
}

# --- Main ---

echo "========================================="
if [ "$DRY_RUN" = true ]; then
  echo "  Workspace Commit (DRY RUN)"
else
  echo "  Workspace Commit"
fi
echo "========================================="
echo ""

# Determine if target is a single repo or a workitem worktree
if [ -f "$TARGET/.git" ] || [ -d "$TARGET/.git" ]; then
  # Single repo
  commit_repo "$TARGET"
elif [ -d "$TARGET" ]; then
  # Workitem worktree — iterate repos
  found=false
  for repo_dir in "$TARGET"/*/; do
    [ -d "$repo_dir" ] || continue
    [ -f "$repo_dir/.git" ] || [ -d "$repo_dir/.git" ] || continue
    found=true
    commit_repo "$repo_dir"
    echo ""
  done

  if [ "$found" = false ]; then
    echo "❌ No git repos found in $TARGET"
    exit 1
  fi
else
  echo "❌ Target not found: $TARGET"
  exit 1
fi

echo "========================================="
if [ "$DRY_RUN" = true ]; then
  echo "  Dry run complete — no commits made"
else
  echo "  Done"
fi
echo "========================================="