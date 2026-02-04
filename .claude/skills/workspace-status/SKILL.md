---
name: workspace-status
description: Show progress across all workitems in the workspace. Use when the user asks for status, progress, overview, or dashboard of workitems. Shows each workitem's type, review status, task progress, and worktree state. Can also show detailed status for a specific workitem.
---

# Workspace Status

Show progress across all workitems or detailed status for a specific one.

## Usage

```bash
# Overview of all workitems
bash <skill-path>/scripts/status.sh

# Detailed status for a specific workitem
bash <skill-path>/scripts/status.sh feature/auth-middleware
```