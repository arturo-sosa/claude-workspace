---
name: workspace-setup
description: Initialize workspace configuration. Use when the user wants to set up the workspace for the first time or reconfigure it. Creates config.yaml from config.sample.yaml, prompts for git identity and repository definitions. Triggers on requests to "setup", "initialize", "configure workspace", or when config.yaml is missing.
---

# Workspace Setup

Interactive setup to create `config.yaml` from `config.sample.yaml`. Guides the user through configuring git identity and repository definitions.

## When to Trigger

- User explicitly asks to setup/initialize/configure the workspace
- `config.yaml` does not exist but `config.sample.yaml` does
- User wants to reconfigure the workspace

## Workflow

### 1. Check Prerequisites

Verify `config.sample.yaml` exists. If not, report an error — the workspace template is incomplete.

If `config.yaml` already exists, ask the user if they want to reconfigure (this will overwrite the git identity settings; repos will be added via workspace-repos).

### 2. Git Identity

Ask the user:

> Do you want to configure a git identity for this workspace?
> - Yes, configure git user and email
> - No, use system git config

If yes, prompt for:
- Git user name
- Git email

If no, leave `git.user` and `git.email` as empty strings (the system will fall back to `git config user.name` and `git config user.email`).

### 3. Generate config.yaml

Read `config.sample.yaml` as the base template. Update it with:
- `git.user` and `git.email` from step 2
- Keep `repos` as an empty array (repos will be added interactively)

Write the result to `config.yaml`.

### 4. Repositories

Ask the user:

> Do you want to add repositories to the workspace now?
> - Yes
> - No, I'll add them later

If yes, start an interactive loop:

1. Prompt for repository info:
   - **name**: Short name for the repo (used as directory name in `repos/`)
   - **url**: Git clone URL (SSH or HTTPS)
   - **branch**: Default branch (defaults to `main` if not specified)

2. Use `workspace-repos` skill (add command) to add the repo to `config.yaml` and clone it

3. Ask: "Add another repository?"
   - Yes → repeat from step 1
   - No → exit loop

### 5. Next Steps

After setup is complete, suggest starting a workitem with `workspace-plan`.

Note: `workspace-repos` already clones repos when adding them, so no separate clone step is needed.

## Example Interaction

```
User: setup workspace

Claude: I'll help you set up the workspace configuration.

Do you want to configure a git identity for this workspace, or use your system git config?

User: Configure it

Claude: What name should be used for git commits?

User: John Doe

Claude: What email should be used for git commits?

User: john@example.com

Claude: Created config.yaml with git identity: John Doe <john@example.com>

Do you want to add repositories to the workspace now?

User: Yes

Claude: What's the short name for this repo? (e.g. "frontend", "api")

User: frontend

Claude: What's the git URL for frontend?

User: git@github.com:myorg/frontend.git

Claude: What branch? (default: main)

User: main

Claude: Added frontend to config.yaml.

Add another repository?

User: Yes

Claude: What's the short name for this repo?

User: backend

Claude: What's the git URL for backend?

User: git@github.com:myorg/backend.git

Claude: What branch? (default: main)

User: develop

Claude: Added backend to config.yaml.

Add another repository?

User: No

Claude: Setup complete!

Repositories configured and cloned:
- frontend (main)
- backend (develop)

Next step: Run `/workspace-plan` to start planning a workitem
```
