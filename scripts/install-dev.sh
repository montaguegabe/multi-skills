#!/usr/bin/env sh
# Development install: symlink every skill in this repo into the shared agent
# skill directories so edits here are live for Codex and Claude Code.
#
# Codex reads ~/.agents/skills. Claude Code reads ~/.claude/skills, which gets
# a relative link back into ~/.agents/skills so both agents share one source.
# Override the directories with AGENTS_SKILLS_DIR and CLAUDE_SKILLS_DIR.
#
# Pass skill names to link only those; with no arguments every skills/*/
# directory that contains a SKILL.md is linked.
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
HUB="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CLAUDE="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

mkdir -p "$HUB" "$CLAUDE"

if [ "$#" -gt 0 ]; then
  selected="$*"
else
  selected=""
  for dir in "$REPO_ROOT"/skills/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    selected="$selected $(basename "$dir")"
  done
fi

if [ -z "$selected" ]; then
  echo "no skills found under $REPO_ROOT/skills" >&2
  exit 1
fi

linked=0
for name in $selected; do
  src="$REPO_ROOT/skills/$name"
  if [ ! -f "$src/SKILL.md" ]; then
    echo "skip $name: $src/SKILL.md not found" >&2
    continue
  fi

  if [ -e "$HUB/$name" ] && [ ! -L "$HUB/$name" ]; then
    echo "replacing copied directory $HUB/$name with a symlink" >&2
  fi
  rm -rf "$HUB/$name" "$CLAUDE/$name"
  ln -s "$src" "$HUB/$name"

  # Keep the Claude link relative when both directories sit in their default
  # places, so it survives the home directory moving.
  if [ "$HUB" = "$HOME/.agents/skills" ] && [ "$CLAUDE" = "$HOME/.claude/skills" ]; then
    ln -s "../../.agents/skills/$name" "$CLAUDE/$name"
  else
    ln -s "$HUB/$name" "$CLAUDE/$name"
  fi

  echo "linked $name -> $src"
  linked=$((linked + 1))
done

[ "$linked" -gt 0 ] || exit 1
