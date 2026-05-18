#!/usr/bin/env bash
set -euo pipefail

# Symlinks every SKILL.md in this repo into ~/.codex/prompts/<name>.md so
# Codex CLI picks them up as user prompts invokable with /<name>.
# Pulling new commits propagates automatically.
#
# Codex tolerates the 'name:' / 'description:' frontmatter as-is, so no
# rewrite is needed — symlinks Just Work.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.codex/prompts"

mkdir -p "$DEST"

find "$REPO/plugins/bitbucket-skills/skills" -name SKILL.md -print0 |
while IFS= read -r -d '' skill_md; do
  name="$(basename "$(dirname "$skill_md")")"
  target="$DEST/$name.md"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -f "$target"
  fi

  ln -sfn "$skill_md" "$target"
  echo "linked $name.md -> $skill_md"
done
