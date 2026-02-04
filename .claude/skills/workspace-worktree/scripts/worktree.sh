#!/bin/bash
set -euo pipefail

REPOS_DIR="repos"
WORKTREES_DIR="worktrees"
WORKITEMS_DIR=".claude/workitems"

# Cross-platform sed -i
sedi() {
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Detect package manager and install deps
install_deps() {
  local dir="$1"
  if [ -f "$dir/yarn.lock" ]; then
    echo "    📦 Installing deps with yarn..."
    (cd "$dir" && yarn install --frozen-lockfile 2>&1) || echo "    ⚠️  yarn install failed"
  elif [ -f "$dir/pnpm-lock.yaml" ]; then
    echo "    📦 Installing deps with pnpm..."
    (cd "$dir" && pnpm install --frozen-lockfile 2>&1) || echo "    ⚠️  pnpm install failed"
  elif [ -f "$dir/package-lock.json" ]; then
    echo "    📦 Installing deps with npm..."
    (cd "$dir" && npm ci 2>&1) || echo "    ⚠️  npm ci failed"
  elif [ -f "$dir/package.json" ]; then
    echo "    📦 Installing deps with npm..."
    (cd "$dir" && npm install 2>&1) || echo "    ⚠️  npm install failed"
  else
    echo "    ℹ️  No package manager detected, skipping deps"
  fi
}

# --- CREATE ---
cmd_create() {
  local workitem_path="$1"
  shift
  local repos=("$@")

  if [ ${#repos[@]} -eq 0 ]; then
    echo "❌ No repos specified"
    echo "   Usage: worktree.sh create {type}/{name} {repo1} {repo2} ..."
    exit 1
  fi

  local workitem_type="${workitem_path%%/*}"
  local workitem_name="${workitem_path#*/}"
  local branch="${workitem_type}/${workitem_name}"
  local wt_base="${WORKTREES_DIR}/${workitem_type}/${workitem_name}"
  local workitem_dir="${WORKITEMS_DIR}/${workitem_type}/${workitem_name}"

  echo "🔧 Creating worktrees for: $workitem_path"
  echo "   Branch: $branch"
  echo "   Worktree base: $wt_base"
  echo "   Repos: ${repos[*]}"
  echo ""

  mkdir -p "$wt_base"
  mkdir -p "$workitem_dir"

  local created=0
  local skipped=0
  local failed=0

  for repo in "${repos[@]}"; do
    local repo_path="${REPOS_DIR}/${repo}"
    local wt_path="${wt_base}/${repo}"

    echo "  📂 $repo"

    # Validate repo exists
    if [ ! -d "$repo_path/.git" ]; then
      echo "    ❌ Repo not found at $repo_path"
      failed=$((failed + 1))
      continue
    fi

    # Skip if worktree already exists
    if [ -d "$wt_path" ]; then
      echo "    ⏭️  Worktree already exists, skipping"
      skipped=$((skipped + 1))
      continue
    fi

    # Create branch if it doesn't exist
    if ! (cd "$repo_path" && git rev-parse --verify "$branch" >/dev/null 2>&1); then
      echo "    🌿 Creating branch: $branch"
      (cd "$repo_path" && git branch "$branch" 2>&1) || {
        echo "    ❌ Failed to create branch"
        failed=$((failed + 1))
        continue
      }
    else
      echo "    🌿 Branch already exists: $branch"
    fi

    # Create worktree
    echo "    🔗 Creating worktree at $wt_path"
    (cd "$repo_path" && git worktree add "../../${wt_path}" "$branch" 2>&1) || {
      echo "    ❌ Failed to create worktree"
      failed=$((failed + 1))
      continue
    }

    # Install dependencies
    install_deps "$wt_path"

    created=$((created + 1))
    echo "    ✅ Done"
    echo ""
  done

  # Write worktree.path
  local wt_path_file="${workitem_dir}/worktree.path"
  echo "$wt_base" > "$wt_path_file"
  echo "📝 Wrote worktree path: $wt_path_file → $wt_base"

  echo ""
  echo "========================================="
  echo "  Worktree Setup Summary"
  echo "========================================="
  echo "  Created: $created"
  echo "  Skipped: $skipped (already exist)"
  echo "  Failed:  $failed"
  echo "========================================="

  if [ "$failed" -gt 0 ]; then
    exit 1
  fi
}

# --- REMOVE ---
cmd_remove() {
  local workitem_path="$1"
  local force="${2:-}"

  local workitem_type="${workitem_path%%/*}"
  local workitem_name="${workitem_path#*/}"
  local branch="${workitem_type}/${workitem_name}"
  local wt_base="${WORKTREES_DIR}/${workitem_type}/${workitem_name}"

  echo "🧹 Removing worktrees for: $workitem_path"
  echo ""

  if [ ! -d "$wt_base" ]; then
    echo "ℹ️  No worktrees found at $wt_base"
    return 0
  fi

  local removed=0
  local failed=0

  for wt_dir in "$wt_base"/*/; do
    [ -d "$wt_dir" ] || continue
    local repo=$(basename "$wt_dir")
    local repo_path="${REPOS_DIR}/${repo}"

    echo "  📂 $repo"

    # Remove worktree via git
    if [ -d "$repo_path/.git" ]; then
      echo "    🔗 Removing worktree..."
      (cd "$repo_path" && git worktree remove "../../${wt_base}/${repo}" --force 2>&1) || {
        echo "    ⚠️  git worktree remove failed, removing directory manually"
        rm -rf "${wt_base}/${repo}"
      }
    else
      echo "    ⚠️  Repo not found, removing directory manually"
      rm -rf "${wt_base}/${repo}"
    fi

    # Delete branch if --force
    if [ "$force" = "--force" ] && [ -d "$repo_path/.git" ]; then
      echo "    🌿 Deleting branch: $branch"
      (cd "$repo_path" && git branch -D "$branch" 2>&1) || echo "    ⚠️  Branch delete failed"
    fi

    removed=$((removed + 1))
    echo "    ✅ Done"
  done

  # Remove base directory
  rm -rf "$wt_base"
  echo ""
  echo "  Removed $removed worktree(s)"

  # Clean up empty type directory
  local type_dir="${WORKTREES_DIR}/${workitem_type}"
  if [ -d "$type_dir" ] && [ -z "$(ls -A "$type_dir")" ]; then
    rmdir "$type_dir"
  fi

  if [ "$force" != "--force" ]; then
    echo ""
    echo "ℹ️  Branches were kept. Run with --force to delete branches too."
  fi
}

# --- STATUS ---
cmd_status() {
  local workitem_path="$1"

  local workitem_type="${workitem_path%%/*}"
  local workitem_name="${workitem_path#*/}"
  local branch="${workitem_type}/${workitem_name}"
  local wt_base="${WORKTREES_DIR}/${workitem_type}/${workitem_name}"

  echo "📊 Worktree status for: $workitem_path"
  echo "   Branch: $branch"
  echo ""

  if [ ! -d "$wt_base" ]; then
    echo "ℹ️  No worktrees found at $wt_base"
    return 0
  fi

  for wt_dir in "$wt_base"/*/; do
    [ -d "$wt_dir" ] || continue
    local repo=$(basename "$wt_dir")

    echo "  📂 $repo"

    # Check if it's a valid git worktree
    if [ ! -f "$wt_dir/.git" ]; then
      echo "    ❌ Not a valid worktree"
      continue
    fi

    # Branch
    local current_branch
    current_branch=$(cd "$wt_dir" && git branch --show-current 2>/dev/null || echo "detached")
    echo "    🌿 Branch: $current_branch"

    # Clean/dirty
    local status
    status=$(cd "$wt_dir" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$status" -eq 0 ]; then
      echo "    ✅ Clean"
    else
      echo "    ⚠️  Dirty ($status changed files)"
    fi

    # Deps
    if [ -d "$wt_dir/node_modules" ]; then
      echo "    📦 Dependencies installed"
    elif [ -f "$wt_dir/package.json" ]; then
      echo "    ⚠️  Dependencies not installed"
    fi

    echo ""
  done
}

# --- MAIN ---
COMMAND="${1:-}"

case "$COMMAND" in
  create)
    shift
    if [ -z "${1:-}" ]; then
      echo "❌ Usage: worktree.sh create {type}/{name} {repo1} {repo2} ..."
      exit 1
    fi
    cmd_create "$@"
    ;;
  remove)
    shift
    if [ -z "${1:-}" ]; then
      echo "❌ Usage: worktree.sh remove {type}/{name} [--force]"
      exit 1
    fi
    cmd_remove "$@"
    ;;
  status)
    shift
    if [ -z "${1:-}" ]; then
      echo "❌ Usage: worktree.sh status {type}/{name}"
      exit 1
    fi
    cmd_status "$@"
    ;;
  *)
    echo "Usage: worktree.sh {create|remove|status} ..."
    echo ""
    echo "Commands:"
    echo "  create {type}/{name} {repo1} {repo2} ...  Create worktrees"
    echo "  remove {type}/{name} [--force]             Remove worktrees (--force deletes branches)"
    echo "  status {type}/{name}                       Show worktree status"
    exit 1
    ;;
esac