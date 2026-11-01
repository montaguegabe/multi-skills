# Multi Skills

Vercel Skills repository for Multi.

## Development install

If you edit these skills, link them instead of copying them so Codex and Claude Code pick up changes immediately:

```bash
scripts/install-dev.sh                      # link every skill in this repo
scripts/install-dev.sh multi-workspace      # link one skill
multi skills install --dev                  # same, run from the Multi CLI
```

The script symlinks each skill into `~/.agents/skills` (read by Codex) and adds a relative link in `~/.claude/skills` (read by Claude Code). Re-run it after adding a skill. Set `AGENTS_SKILLS_DIR` or `CLAUDE_SKILLS_DIR` to use other directories.

## Install with `vercel-labs/skills`

Everyone else installs a copy with the skills.sh installer, or with `multi skills install`:

```bash
# List available skills
npx skills add montaguegabe/multi-skills --list

# Install the Multi workspace skill
npx skills add montaguegabe/multi-skills --skill multi-workspace
```

Optional flags:

- `-g` to install globally
- `-a claude-code` (or other agent names) to target specific agents

## Included Skills

- `multi-workspace` - Multi CLI/workspace command, config, and sync guidance
