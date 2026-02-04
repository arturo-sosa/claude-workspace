#!/usr/bin/env bash
#
# Git commit wrapper that uses identity from workspace config.yaml
#
# Usage: bash .claude/scripts/git-commit.sh [git commit arguments]
#
# Reads git.user and git.email from config.yaml and passes them to git commit.
# Falls back to system git config if not set.

set -euo pipefail

# Find workspace root (directory containing config.yaml)
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
    echo "Error: Could not find workspace root (no config.yaml found)" >&2
    exit 1
}

CONFIG_FILE="$WORKSPACE_ROOT/config.yaml"

# Parse git identity from config.yaml using grep/sed (no dependencies)
# Handles both quoted and unquoted values
parse_yaml_value() {
    local key="$1"
    local value
    # Extract value after key:, strip leading/trailing whitespace and quotes
    value=$(grep -E "^\s*${key}:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/^[^:]*://' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//")
    echo "$value"
}

GIT_USER=$(parse_yaml_value "user")
GIT_EMAIL=$(parse_yaml_value "email")

# Build git command with identity flags if configured
GIT_CMD=(git)

if [[ -n "$GIT_USER" ]]; then
    GIT_CMD+=(-c "user.name=$GIT_USER")
fi

if [[ -n "$GIT_EMAIL" ]]; then
    GIT_CMD+=(-c "user.email=$GIT_EMAIL")
fi

GIT_CMD+=(commit "$@")

# Execute git commit
exec "${GIT_CMD[@]}"
