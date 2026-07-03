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
version: 0.2.0
---

# Multi Workspace

Multi (`multi-workspace` on PyPI) is a CLI tool that enables VS Code/Cursor to work across multiple Git repos in a single workspace. Sub-repos are cloned as directories inside the workspace root and `.gitignored` — no submodules are used. The CLI keeps all repos on the same branch and merges their VS Code configurations.

## Key Constraints

- `multi init` can run interactively or non-interactively with `--repo` / `--repo-description` or `--github-repo` / `--github-description`.
- For existing or generated configs, automation should create/update `multi.json` and run `multi sync`.
- For isolated feature work in a multi workspace, use `multi worktree add`; do not hand-roll root + sub-repo worktree creation in downstream tools.
- When using `multi` with worktrees, keep the worktrees in a sibling directory named after the workspace with `-worktrees` appended; for example, `openbase-coder-workspace` should use sibling worktrees under `openbase-coder-workspace-worktrees`.
- `CLAUDE.md` and `AGENTS.md` are generated from `AGENTS.parts/*.md` only when `agentInstructions.enabled` is `true`. When generated, edit the parts files instead of the outputs.
- All repos must have **clean working directories** before running `multi set-branch`.
- All repos must have **clean working directories** before running `multi worktree add`.
- `multi set-branch` and `multi git` are **disabled in monorepo mode**.
- `multi worktree add` is **disabled in monorepo mode**.
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

### `multi worktree add NAME [--branch BRANCH_NAME] [--install-set NAME] [--base-ref REF]`

Create an isolated sibling git worktree for a whole multi workspace. This is the preferred command when an agent, scheduler, or automation needs a separate copy of a multi workspace for parallel work.

Behavior:
- Creates a sibling root worktree named `NAME` next to the current workspace root.
- Uses `NAME` as the branch name unless `--branch` is provided.
- Runs `multi sync` in the new worktree to populate configured sub-repos and generated files.
- When `--install-set` is provided, only repos in that install set are synced and checked out. Use this for public/default installs so private dev-only repos are not cloned.
- Uses `--base-ref` as the starting point for newly created root and sub-repo branches.
- Checks included sub-repos out to the target branch, except repos with `fixedBranch`.
- Transfers local gitignored paths configured under `worktree.symlink` and `worktree.copy`.

Example:

```sh
multi worktree add task-login-flow --branch agent-work/task-login-flow --install-set default
```

### `multi init`

Initialize a new workspace, write `multi.json`, run full sync, and commit the result.

Modes:
- Interactive: prompts for repo URLs and descriptions.
- Existing repos: pass repeated `--repo URL` values with matching `--repo-description TEXT` values.
- New GitHub repos: pass repeated `--github-repo OWNER/REPO` values with matching `--github-description TEXT` values. This uses `gh repo create`, requires `gh` auth, and defaults to private visibility unless `--github-visibility` is provided.

### `multi collaborator`

Manage GitHub collaborators across all GitHub-hosted workspace repos. Includes the workspace root repo if it has a GitHub `origin`.

Common commands:
- `multi collaborator add USERNAME --permission maintain --yes` — add/invite a collaborator across workspace repos.
- `multi collaborator add --yes` — choose from recent GitHub users or enter a username.
- `multi collaborator accept --yes` — accept pending invitations for the current `gh` user, filtered to this workspace.
- `multi collaborator remove USERNAME --yes` — remove a collaborator across workspace repos.
- `multi collaborator recent-users` — list recently used GitHub usernames.

Important: `multi collaborator add` creates invitations as the repo owner/admin. GitHub requires the invited collaborator to accept as their own GitHub identity, so `multi collaborator accept` is a separate command that must be run with `gh` authenticated as the invitee.

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
- `worktree.symlink` — gitignored local paths to symlink into new `multi worktree add` workspaces
- `worktree.copy` — gitignored local paths to copy into new `multi worktree add` workspaces

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

**Automate workspace setup**: For a new workspace, run `multi init --repo ... --repo-description ...` or `multi init --github-repo ... --github-description ...`. For an existing/generated config, create/update `multi.json`, then run `multi sync`.

**Add a new repo to the workspace**: Add a `url` entry (and optional `name`/`description`) to the `repos` array in `multi.json`, then run `multi sync`.

**Switch all repos to a feature branch**: Run `multi set-branch feature/my-branch`. Ensure all repos are clean first.

**Create an isolated workspace for parallel agent work**: Run `multi worktree add task-name --branch feature/task-name --install-set default` from the multi workspace root when working from a default/public install. Use the appropriate install set for the source workspace. Downstream schedulers should call this command rather than creating sub-repo worktrees themselves.

Store multi worktrees in a sibling `*-worktrees` directory for the source workspace, such as `openbase-coder-workspace-worktrees` next to `openbase-coder-workspace`.

**Grant and accept repo access**: Repo owners run `multi collaborator add USERNAME --yes`; invitees run `multi collaborator accept --yes` with their own `gh` authentication.

**Diagnose mode mismatches**: Run `multi doctor` (or `multi doctor --strict` for CI enforcement).

**Fix a missing launch config**: Check the source repo's `.vscode/launch.json`. Ensure `skipVSCode` is not `true` for that repo. Run `multi sync vscode launch`. For cross-repo compounds, use `.vscode/launch.shared.json` at workspace root.

**Add cross-repo settings**: Create or edit `.vscode/settings.shared.json` at the workspace root, then run `multi sync vscode settings`.

## Additional Resources

### Reference Files

For detailed information, consult:
- **`references/configuration.md`** — full `multi.json` schema with all fields and defaults
- **`references/vscode-sync.md`** — detailed VS Code merging behavior, `*.shared.json` usage, master compound creation
- **`references/commands.md`** — complete command reference with all options and edge cases
