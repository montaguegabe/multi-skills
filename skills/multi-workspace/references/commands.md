# Multi CLI Commands Reference

## Global Options

- `--version` — print version and exit
- `--verbose` — enable verbose output (available on all commands)

## multi init

Initialize a new multi workspace.

Usage:

```bash
multi init
multi init --repo https://github.com/org/api-server --repo-description "REST API backend"
multi init --github-repo org/api-server --github-description "REST API backend"
```

By default, `multi init` guides the user through an interactive setup. It can also run non-interactively from flags.

Options:
- `--repo URL` — add an existing repository URL to the workspace. Repeat for multiple repos.
- `--repo-description TEXT` — description for the corresponding `--repo`. Repeat in the same order.
- `--github-repo OWNER/REPO` — create a GitHub repository with `gh repo create` and add it to the workspace.
- `--github-description TEXT` — description for the corresponding `--github-repo`. Also passed to GitHub when creating the repo.
- `--github-visibility private|public|internal` — visibility used for every `--github-repo`. Defaults to `private`.
- `--github-clone-protocol https|ssh` — URL format written to `multi.json` for created GitHub repos. Defaults to `https`.

**Steps performed:**
1. Collects repo URLs and descriptions from prompts or flags.
2. Writes `multi.json` with collected URLs and descriptions.
3. Runs a full `multi sync` (which initializes root git and README if missing).
4. Commits everything with message `"Multi init: Configure multi workspace"`.

**GitHub creation:** `--github-repo` requires the GitHub CLI (`gh`) to be installed and authenticated. Repos are private by default unless `--github-visibility` is provided.

**Automation**: For new workspaces, pass `--repo` / `--repo-description` or `--github-repo` / `--github-description`. For existing/generated configs, create/update `multi.json` and run `multi sync`.

**Local names:** If a repository slug starts with the workspace directory name plus `-`, Multi automatically writes a short local `name` into `multi.json`. For example, in a `t-ide/` workspace, `https://github.com/org/t-ide-cli` becomes local folder `cli`.

Examples:

```bash
multi init \
  --repo https://github.com/org/api-server \
  --repo-description "REST API backend" \
  --repo https://github.com/org/web-client \
  --repo-description "React frontend"

multi init \
  --github-repo org/api-server \
  --github-description "REST API backend" \
  --github-repo org/web-client \
  --github-description "React frontend"

multi init \
  --github-repo org/api-server \
  --github-clone-protocol ssh
```

## multi add REPO_URL

Add a repository to an existing workspace.

Options:
- `--name TEXT` — override the local directory name written to `multi.json`.

**Behavior:**
1. Appends the repository to `multi.json`.
2. Runs `multi sync` so the repo is cloned and generated workspace files are refreshed.
3. If the repo slug starts with the workspace directory name plus `-`, Multi automatically writes a short local `name`. For example, in a `t-ide/` workspace, adding `https://github.com/org/t-ide-cli` uses local folder `cli`.

Examples:

```bash
multi add https://github.com/org/t-ide-cli
multi add https://github.com/org/t-ide-cli --name tools-cli
```

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

## multi worktree add NAME

Create a sibling Git worktree for an entire multi workspace.

Options:
- `--branch BRANCH_NAME` — branch name for the worktree. Defaults to `NAME`.
- `--install-set NAME` / `--set NAME` — only sync repositories included in the named install set.
- `--base-ref REF` — base ref for newly created root and sub-repo branches. Defaults to `HEAD`.

**Preconditions:**
- Root repo and all included sub-repos must have clean working directories.
- The command is disabled in monorepo mode.
- The destination sibling directory must not already exist.

**Behavior:**
1. Creates a sibling root worktree next to the current workspace root.
2. Runs `multi sync` in the new root, forwarding `--install-set` when provided.
3. Checks included sub-repos out to the target branch, except repos with `fixedBranch`.
4. If `--base-ref` is provided and a sub-repo branch needs to be created, Multi tries to fetch that base ref from the source sub-repo and create the branch from it.
5. Transfers configured gitignored paths from the source workspace using `worktree.symlink` and `worktree.copy`.

**Examples:**

```bash
multi worktree add feature-user-auth
multi worktree add user-auth --branch feature/user-auth
multi worktree add public-demo --branch agent-work/public-demo --install-set default
multi worktree add downstream --base-ref agent-work/upstream
```

Use this command for isolated agent/scheduler work instead of manually creating root and sub-repo worktrees.

## multi collaborator

Manage GitHub collaborators across all GitHub-hosted workspace repositories.

Commands:
- `multi collaborator add USERNAME [--permission pull|push|admin|maintain|triage] [--yes]`
- `multi collaborator add [--yes]`
- `multi collaborator accept [--yes]`
- `multi collaborator remove USERNAME [--yes]`
- `multi collaborator recent-users`

**Behavior:**
- Targets every GitHub-hosted sub-repo in `multi.json`.
- Includes the workspace root repo when it has a GitHub `origin`.
- Uses `gh api`, so `gh` must be installed and authenticated.
- Verifies GitHub users before add/remove.
- Remembers verified usernames in `~/.multi/recent-github-users.json`.
- Continues after per-repo API failures, then exits with a summary if any repo failed.

**Add vs accept:**
- `multi collaborator add USERNAME --yes` creates collaborator access or pending invitations using the repo owner/admin's GitHub auth.
- GitHub requires pending invitations to be accepted by the invited user.
- `multi collaborator accept --yes` lists pending repository invitations for the current authenticated `gh` user, filters them to this workspace, and accepts the matching invitations.

**Examples:**

```bash
multi collaborator add octocat --permission maintain --yes
multi collaborator add --yes
multi collaborator accept --yes
multi collaborator remove octocat --yes
multi collaborator recent-users
```

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
