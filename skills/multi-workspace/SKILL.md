---
name: multi-workspace
description: >-
  This skill should be used when the user asks about "multi.json",
  "multi workspace", "multi sync", "multi set-branch", "multi git",
  "multi init", branch switching across repos, VS Code config merging,
  agent instruction generation, "CLAUDE.md" generation, "AGENTS.md" generation,
  working with multiple repositories in a single workspace, or when a
  multi.json file is detected in the project. Provides knowledge of
  Multi CLI commands, configuration, and workspace conventions.
version: 0.1.0
---

# Multi Workspace

Multi (`multi-workspace` on PyPI) is a CLI tool that enables VS Code/Cursor to work across multiple Git repos in a single workspace. Sub-repos are cloned as directories inside the workspace root and `.gitignored` — no submodules are used. The CLI keeps all repos on the same branch and merges their VS Code configurations.

## Key Constraints

- `multi init` is **interactive** and cannot be scripted non-interactively.
- Automation flow should use `multi.json` + `multi sync` (not `multi init`).
- `CLAUDE.md` and `AGENTS.md` are generated from `AGENTS.parts/*.md` only when `agentInstructions.enabled` is `true`. When generated, edit the parts files instead of the outputs.
- All repos must have **clean working directories** before running `multi set-branch`.
- `multi set-branch` and `multi git` are **disabled in monorepo mode**.
- VS Code config files (`settings.json`, `launch.json`, `tasks.json`, `extensions.json`) at the workspace root are **generated** — do not edit directly. Use the repo-level files or `*.shared.json` files instead.
- In `monoRepo` mode, directories listed in `repos` should be part of the root git repo and must not contain nested `.git` folders.

## Commands

### `multi sync`

Run all sync operations: clone/symlink repos, update `.gitignore`, merge VS Code configs, generate agent instructions, sync GitHub workflows.

Subcommands for partial sync:
- `multi sync vscode` — merge all VS Code configs (or specify: `settings`, `launch`, `tasks`, `extensions`, `devcontainer`)
- `multi sync agents` — generate `CLAUDE.md`/`AGENTS.md` from `AGENTS.parts/*.md` when enabled
- `multi sync github` — sync root GitHub Actions workflows for monorepo workspaces

### `multi set-branch BRANCH_NAME`

Switch all repos to a branch. If the branch exists locally or on the remote, check it out. If it doesn't exist anywhere, create it from the current HEAD. All repos must be clean first.

### `multi git GIT_ARGS...`

Run any git command across all repos (root first, then sub-repos in order). All repos must be on the same branch. Example: `multi git pull`, `multi git push -u origin feature/foo`.

### `multi init`

Interactive setup: prompts for repo URLs and descriptions, writes `multi.json`, clones repos, runs full sync, commits.

### `multi doctor`

Diagnose workspace issues (missing/invalid `multi.json`, root git initialization, and `monoRepo` nested `.git` mismatches). Use `--strict` to fail on warnings.

### `multi open PATH`

Open a project path in the Multi desktop app.

## Configuration Overview

The workspace is configured via `multi.json` at the root. Key fields:

- `repos[]` — array of repo configs, each with `url`, optional `name`, `description`, `installSets`, `skipVSCode`, `allowSymlink`, `requiredTasks`, `requiredCompounds`, `requiredLaunchConfigurations`
- `monoRepo` — treat repos as local subdirectories instead of cloning
- `allowSymlinks` — enable symlinking to existing clones from `~/.multi/repos.json`
- `agentInstructions.enabled` — opt into generated `AGENTS.md`/`CLAUDE.md` outputs from Markdown parts
- `vscode.skipSettings` — settings keys to exclude from merge

For the full schema, consult `references/configuration.md`.

### Install Sets

Repos can opt into named install/sync sets with `installSets`, for example public runtime repos can use `["default", "dev"]` while private development-only repos use `["dev"]`.

Run `multi sync --install-set default` or `multi sync --set default` to clone, merge VS Code config, generate agent instructions, sync GitHub workflows, and update managed ignore files only for repos included in that set. Running `multi sync` with no install set includes every repo. Repos without `installSets` are included in every named set for backward compatibility.

### Mode Decision Table

| Scenario | `monoRepo` |
|---|---|
| Independent git repositories under one workspace root | `false` |
| One root git repo with project folders (no nested `.git` in listed folders) | `true` |

## VS Code Merging Overview

Multi merges `.vscode/` config files from all sub-repos into the workspace root:

- **`${workspaceFolder}` rewriting** — paths are automatically prefixed with the repo name
- **`*.shared.json` files** — `settings.shared.json`, `launch.shared.json`, `tasks.shared.json` at workspace root are merged last (for cross-repo config)
- **Master compound** — auto-created launch compound and task containing all "required" entries
- **Settings overrides** — per-repo `vscode.settingsOverrides` in `multi.json`

For detailed merging behavior, consult `references/vscode-sync.md`.

## CLAUDE.md / AGENTS.md Generation

Running `multi sync agents`:
1. Does nothing unless `agentInstructions.enabled` is `true`.
2. Concatenates `AGENTS.parts/*.md` in lexicographic order at the workspace root and each sub-repo.
3. Writes matching `CLAUDE.md` and `AGENTS.md` files beside the parts directory.
4. Includes root repo descriptions when `agentInstructions.includeRepoDescriptions` is `true`.

## Common Tasks

**Automate workspace setup**: Create/update `multi.json`, then run `multi sync`.

**Add a new repo to the workspace**: Add a `url` entry (and optional `name`/`description`) to the `repos` array in `multi.json`, then run `multi sync`.

**Switch all repos to a feature branch**: Run `multi set-branch feature/my-branch`. Ensure all repos are clean first.

**Diagnose mode mismatches**: Run `multi doctor` (or `multi doctor --strict` for CI enforcement).

**Fix a missing launch config**: Check the source repo's `.vscode/launch.json`. Ensure `skipVSCode` is not `true` for that repo. Run `multi sync vscode launch`. For cross-repo compounds, use `.vscode/launch.shared.json` at workspace root.

**Add cross-repo settings**: Create or edit `.vscode/settings.shared.json` at the workspace root, then run `multi sync vscode settings`.

## Additional Resources

### Reference Files

For detailed information, consult:
- **`references/configuration.md`** — full `multi.json` schema with all fields and defaults
- **`references/vscode-sync.md`** — detailed VS Code merging behavior, `*.shared.json` usage, master compound creation
- **`references/commands.md`** — complete command reference with all options and edge cases
