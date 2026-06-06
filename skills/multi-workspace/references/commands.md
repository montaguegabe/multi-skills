# Multi CLI Commands Reference

## Global Options

- `--version` — print version and exit
- `--verbose` — enable verbose output (available on all commands)

## multi init

Interactive workspace initialization.

**Steps performed:**
1. Prompts for repo URLs one at a time (with optional descriptions for each).
2. Writes `multi.json` with collected URLs and descriptions.
3. Runs a full `multi sync` (which initializes root git and README if missing).
6. Commits everything with message `"Multi init: Configure multi workspace"`.

**Important**: This command is interactive — it prompts for input and cannot be scripted.

**Automation**: For scripted setup, create/update `multi.json` and run `multi sync`.

## multi sync

Run all sync operations in order:
1. Initialize root git repo if missing.
2. Create `README.md` if missing.
3. Clone/symlink missing sub-repos (skipped in monorepo mode).
4. Update `.gitignore` and `.ignore`.
5. Merge VS Code configs.
6. Generate `CLAUDE.md` + `AGENTS.md` when `agentInstructions.enabled` is true.
7. Sync root GitHub Actions workflows for monorepo workspaces.

Options:
- `--install-set NAME` / `--set NAME` — only sync repos included in the named `repos[].installSets` set. Repos without `installSets` are included in every named set. Without this option, all repos are included.

### Subcommands

#### multi sync vscode

Merge all VS Code config files. Sub-subcommands for individual files:

- `multi sync vscode settings` — merge `settings.json`
- `multi sync vscode launch` — merge `launch.json`
- `multi sync vscode tasks` — merge `tasks.json`
- `multi sync vscode extensions` — merge `extensions.json`
- `multi sync vscode devcontainer` — sync `.devcontainer` folder

#### multi sync agents

1. Do nothing unless `agentInstructions.enabled` is true.
2. For the workspace root and each sub-repo, concatenate `AGENTS.parts/*.md` in lexicographic order.
3. Generate matching `CLAUDE.md` and `AGENTS.md` beside each parts directory.

## multi set-branch BRANCH_NAME

Switch all repos to a branch.

**Preconditions:**
- All repos (root + sub-repos) must have clean working directories (no uncommitted or untracked changes).

**Behavior:**
- Operates on root repo first, then sub-repos.
- If branch exists locally or on remote: checks it out.
- If branch doesn't exist anywhere: creates it from current HEAD.
- If repos are on different branches: branch creation is disallowed (can only switch to existing branches).

**Disabled in monorepo mode.**

## multi git GIT_ARGS...

Run any git command across all repos.

**Preconditions:**
- All repos must be on the same branch.

**Behavior:**
- Runs the command in root repo first, then each sub-repo in order.
- Passes all arguments directly to git.

**Examples:**
```bash
multi git pull
multi git status
multi git push -u origin feature/foo
multi git fetch --all
```

**Disabled in monorepo mode. Interactive git commands (e.g., `git rebase -i`) are not supported.**

## multi doctor

Diagnose common workspace issues.

**Checks include:**
- `multi.json` discovery and parseability
- Root git repository initialization
- `monoRepo` mode mismatch (nested `.git` in listed directories)

Use `--strict` to fail on warnings.

## multi open PATH

Open a project path in the Multi desktop app by launching a `multi://open?path=...` URL.

Does not require `multi.json`.

## .gitignore and .ignore Management

After cloning, Multi automatically updates:

**`.gitignore`** — adds under `# Ignore repository directories`:
- `repo-name/` and `repo-name` (without slash, for symlink support)
- Generated files: `.vscode/settings.json`, `.vscode/tasks.json`, `.vscode/launch.json`, `.vscode/extensions.json`, `CLAUDE.md`, `AGENTS.md`

**`.ignore`** — adds under `# Allow us to search inside these gitignored directories`:
- `!repo-name/` and `!repo-name` (so VS Code search works inside gitignored sub-repos)
