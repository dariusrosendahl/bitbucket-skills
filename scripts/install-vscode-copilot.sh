#!/usr/bin/env bash
set -euo pipefail

# Installs every SKILL.md in this repo as a <name>.prompt.md file in VS
# Code's User/prompts dir, so colleagues without Claude Code or Codex
# can run them from Copilot Chat's "Select prompt file" picker.
#
# These are copies (not symlinks) because Copilot Chat expects different
# frontmatter than Claude Code:
#   - Claude Code: `name: bitbucket-pr-review`
#   - Copilot:     `mode: agent`
# We sed the first frontmatter block to swap them. Re-run after `git pull`.

REPO="$(cd "$(dirname "$0")/.." && pwd)"

case "$(uname -s)" in
  Darwin*) DEST="$HOME/Library/Application Support/Code/User/prompts" ;;
  Linux*)  DEST="$HOME/.config/Code/User/prompts" ;;
  *)
    echo "error: unsupported OS '$(uname -s)'. Set DEST manually or run on macOS/Linux." >&2
    echo "Windows users: copy each SKILL.md to %APPDATA%\\Code\\User\\prompts\\<name>.prompt.md and rewrite the 'name:' line to 'mode: agent'." >&2
    exit 1
    ;;
esac

mkdir -p "$DEST"

find "$REPO/plugins/bitbucket-skills/skills" -name SKILL.md -print0 |
while IFS= read -r -d '' skill_md; do
  name="$(basename "$(dirname "$skill_md")")"
  target="$DEST/$name.prompt.md"

  cp "$skill_md" "$target"
  # Within the first frontmatter block (line 1 through next `---`), rewrite
  # any `name: ...` line to `mode: agent`. -i.bak is portable between BSD
  # and GNU sed; the resulting `.bak` is then removed.
  sed -i.bak '1,/^---$/{ s/^name: .*$/mode: agent/; }' "$target"
  rm "$target.bak"

  echo "installed $name.prompt.md -> $target"
done

cat <<EOF

Done. Open VS Code, reload (Cmd+Shift+P → "Developer: Reload Window"),
then type / in Copilot Chat — both bitbucket-pr-* prompts should appear.

Note: these prompts were authored for Claude Code and reference patterns
(multi-agent dispatch, tool invocations) that Copilot Chat doesn't run.
Copilot will follow the instructions as guidance — you'll be asked to run
curl commands manually and get a single inline review instead of parallel
agents. For full auto-execution use Claude Code (\`/plugin install
bitbucket-skills\`) or Codex (\`scripts/link-codex.sh\`).
EOF
