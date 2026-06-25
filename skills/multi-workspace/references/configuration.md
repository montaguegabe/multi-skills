# multi.json Configuration Reference

## File Location

`multi.json` lives at the workspace root directory. The CLI auto-discovers it by walking up from the current working directory.

## Default Values

If keys are absent, these defaults apply:

```json
{
  "monoRepo": false,
  "allowSymlinks": false,
  "agentInstructions": {
    "enabled": false,
    "partsDir": "AGENTS.parts",
    "includeRepoDescriptions": true
  },
  "vscode": {
    "skipSettings": ["workbench.colorCustomizations"]
  },
  "worktree": {
    "symlink": [],
    "copy": []
  },
  "repos": []
}
```

## Top-Level Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `repos` | array | `[]` | Array of repository configuration objects |
| `monoRepo` | boolean | `false` | Monorepo mode: skip git cloning/branch ops; `repos` entries are local subdirectories |
| `allowSymlinks` | boolean | `false` | Enable global symlink support (must also be enabled per-repo) |
| `agentInstructions` | object | see defaults | Optional generated agent instruction configuration |
| `vscode` | object | see defaults | VS Code merge configuration |
| `worktree` | object | see defaults | Optional local path transfer configuration for `multi worktree add` |

## Mode Decision Table

| Scenario | `monoRepo` |
|-------|------|
| Independent git repositories inside one workspace | `false` |
| One root git repo with project directories (no nested `.git`) | `true` |

## Per-Repo Fields (`repos[]`)

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `url` | string | Yes (except monorepo) | — | Git URL (HTTPS or SSH) |
| `name` | string | No (required in monorepo if no URL) | Last URL path segment | Directory name for the clone |
| `description` | string | No | — | Repository description available to generated root agent instructions |
| `installSets` | string[] | No | included in all sets | Named sync/install sets that include this repo when `multi sync --install-set` is used |
| `skipVSCode` | boolean | No | `false` | Exclude this repo from all VS Code config merging |
| `allowSymlink` | boolean | No | `false` | Allow symlinking to an existing clone for this repo |
| `manageGitignore` | boolean | No | `true` | Allow Multi to manage generated entries in this repo's `.gitignore` |
| `fixedBranch` | string | No | — | Keep this repo on a fixed branch during branch switching and worktree creation |
| `requiredTasks` | string[] | No | — | Task labels to include in the master compound task |
| `requiredCompounds` | string[] | No | — | Compound names to include in the master launch compound |
| `requiredLaunchConfigurations` | string[] | No | — | Launch config names to include in the master launch compound |
| `vscode.settingsOverrides` | object | No | — | Settings key-values to forcibly override during settings merge |

Any additional keys in a repo config are set as attributes on the internal `Repository` object and accessible programmatically.

### Install Sets

Use `installSets` when a workspace has a public/runtime subset for installer scripts and a larger development set:

```json
{
  "repos": [
    {
      "url": "https://github.com/org/product-cli",
      "name": "cli",
      "installSets": ["default", "dev"]
    },
    {
      "url": "git@github.com:org/product-ios.git",
      "name": "ios",
      "installSets": ["dev"]
    },
    {
      "url": "https://github.com/org/product-shared",
      "name": "shared"
    }
  ]
}
```

`multi sync --install-set default` syncs only repos in the `default` set, plus repos without `installSets`. `multi sync` with no install set includes every repo.

Use `--install-set` before sync subcommands when filtering a partial sync:

```bash
multi sync --set default agents
multi sync --install-set default vscode settings
```

### Fixed Branches

Use `fixedBranch` for repositories that should remain on a shared branch while the rest of the workspace moves to a feature branch:

```json
{
  "repos": [
    { "url": "https://github.com/org/app" },
    {
      "url": "https://github.com/org/shared-fixtures",
      "fixedBranch": "main"
    }
  ]
}
```

`multi set-branch` and `multi worktree add` leave fixed-branch repos on their configured branch.

### Gitignore Management

By default Multi manages generated entries in repo `.gitignore` files. Set `manageGitignore: false` for a repo when those entries should be maintained manually:

```json
{
  "repos": [
    {
      "url": "https://github.com/org/manual-gitignore-repo",
      "manageGitignore": false
    }
  ]
}
```

## Worktree Transfer Configuration

`worktree` config controls local ignored files transferred by `multi worktree add`.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `symlink` | string[] | `[]` | Gitignored workspace-relative paths to symlink from the original workspace into the new worktree |
| `copy` | string[] | `[]` | Gitignored workspace-relative paths to copy from the original workspace into the new worktree |

All paths must be relative to the workspace root, must stay inside the workspace, and must be ignored by the owning Git repository. Existing destinations in the new worktree are left unchanged.

Example:

```json
{
  "worktree": {
    "symlink": [".env", ".venv"],
    "copy": [".cursor/local.json", "api/.env.local"]
  },
  "repos": [
    { "url": "https://github.com/org/api", "name": "api" }
  ]
}
```

## VS Code Configuration (`vscode`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `skipSettings` | string[] | `["workbench.colorCustomizations"]` | Settings keys to exclude from `settings.json` merge |

## Example multi.json

```json
{
  "repos": [
    {
      "url": "https://github.com/org/backend",
      "description": "Python FastAPI backend service",
      "requiredTasks": ["Start Backend"],
      "requiredLaunchConfigurations": ["Debug Backend"]
    },
    {
      "url": "https://github.com/org/frontend",
      "name": "web",
      "description": "React frontend application",
      "requiredTasks": ["Start Frontend"],
      "vscode": {
        "settingsOverrides": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        }
      }
    },
    {
      "url": "git@github.com:org/shared-lib.git",
      "description": "Shared TypeScript library",
      "skipVSCode": true
    }
  ],
  "allowSymlinks": false,
  "vscode": {
    "skipSettings": ["workbench.colorCustomizations", "editor.fontFamily"]
  }
}
```

## Symlink System

### Global Registry

Location: `~/.multi/repos.json`

Tracks known repo clones:
```json
{
  "version": 1,
  "repos": {
    "https://github.com/org/repo": "/absolute/path/to/clone"
  }
}
```

URL normalization: `.git` suffix is stripped so HTTPS/SSH URLs with/without `.git` map to the same key.

### Clone Logic (per repo during `multi sync`)

1. If repo directory exists: register in global registry, skip.
2. Try symlink: only if `allowSymlinks: true` (global) AND `allowSymlink: true` (per-repo) AND repo found in registry AND registered path is not inside current workspace AND registered path has no `venv/` or `.venv/`.
3. Fall back to `git clone`, then checkout the workspace's current branch if it exists in the sub-repo.
4. Register new clone in global registry.

## Monorepo Mode

When `monoRepo: true`:
- No git cloning or symlinking occurs
- `repos` entries reference existing subdirectories by `name`
- `multi set-branch` and `multi git` are disabled
- VS Code merging still works normally
- Listed directories are expected to be part of the root git repo (no nested `.git` folders)
