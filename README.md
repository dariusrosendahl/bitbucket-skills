# bitbucket-skills

Claude Code plugin marketplace for Bitbucket Cloud workflows.

## What's inside

Two skills for working with Bitbucket Cloud pull requests from inside Claude Code:

- **`/bitbucket-pr-write`** — generate a PR description from the current branch's git history.
  - **Preview** (default) — outputs copy-pastable markdown.
  - **Create** — POSTs the PR to Bitbucket as a **draft** via the API when you explicitly ask. Empty reviewers (your repo's required-reviewer rules still apply server-side).
- **`/bitbucket-pr-review`** — fetch a PR via the Bitbucket Cloud API and dispatch a parallel multi-agent code review (code quality, silent failures, tests, comments, type design) against the diff. **Read-only** — never posts back.

Workspace, repo, and PR id are derived from the URL you paste or from `git remote get-url origin`. No hardcoded workspace.

## Install as Claude Code skills (recommended)

Works in Claude Code CLI and the `anthropic.claude-code` VS Code extension automatically — same install, both surfaces.

```sh
git clone https://github.com/dariusrosendahl/bitbucket-skills.git /tmp/bitbucket-skills

mkdir -p ~/.claude/skills/bitbucket-pr-review ~/.claude/skills/bitbucket-pr-write

cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-review/SKILL.md \
   ~/.claude/skills/bitbucket-pr-review/SKILL.md
cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-write/SKILL.md \
   ~/.claude/skills/bitbucket-pr-write/SKILL.md
```

Verify in Claude Code: type `/bitbucket-pr-review <url>` or run `/skills`. Verify in VS Code with the Claude Code extension: `Cmd+Shift+P` → "Claude Code: Select skill to open" — the two should appear in the list.

## Install as VS Code Copilot Chat prompt files (no Claude Code)

Only do this if you don't have Claude Code installed. These files are surfaced in the VS Code Copilot Chat "Select prompt file" picker. Run from anywhere — the destination is an absolute path:

```sh
git clone https://github.com/dariusrosendahl/bitbucket-skills.git /tmp/bitbucket-skills

# Pick the right path for your OS:
#   macOS:   ~/Library/Application Support/Code/User/prompts
#   Linux:   ~/.config/Code/User/prompts
#   Windows: %APPDATA%\Code\User\prompts
DEST="$HOME/Library/Application Support/Code/User/prompts"
mkdir -p "$DEST"

cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-review/SKILL.md \
   "$DEST/bitbucket-pr-review.prompt.md"
cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-write/SKILL.md \
   "$DEST/bitbucket-pr-write.prompt.md"

# Rewrite the Claude Code frontmatter into VS Code prompt-file frontmatter:
sed -i.bak '1,/^---$/{ s/^name: .*$/mode: agent/; }' "$DEST/bitbucket-pr-review.prompt.md" "$DEST/bitbucket-pr-write.prompt.md"
rm "$DEST"/*.bak
```

Reload VS Code (`Cmd+Shift+P` → "Developer: Reload Window"), then type `/` in Copilot Chat — both should appear in the autocomplete.

### Caveat for VS Code Copilot Chat users

These prompts were authored for Claude Code and reference patterns like multi-agent dispatch (`pr-review-toolkit:code-reviewer` etc.) and tool invocations that don't exist in Copilot Chat. The chat will follow the instructions as **guidance** (asking you to run `curl` commands manually, doing a single inline review instead of parallel agents). For full auto-execution use Claude Code.

## Setup

Both skills (and create-mode for `bitbucket-pr-write`) need Bitbucket Cloud API credentials. Add to your shell rc (`~/.zshrc`, `~/.bashrc`, etc.):

```sh
export BITBUCKET_EMAIL="<your-atlassian-account-email>"
export BITBUCKET_API_TOKEN="<your-api-token>"
```

### Token sources

1. **Atlassian API token** (recommended) — generate at https://id.atlassian.com/manage-profile/security/api-tokens. Pair with your Atlassian account email.
2. **Bitbucket App Password** (legacy, still supported) — generate at https://bitbucket.org/account/settings/app-passwords/. Needs `Pull requests: read` (+ `write` for create mode) and `Repositories: read` (+ `write`). With App Passwords, set `BITBUCKET_EMAIL` to your **Bitbucket username**, not your email.

The skills never log, echo, or print the token. They use `curl -u "$BITBUCKET_EMAIL:$BITBUCKET_API_TOKEN"` so the token is read from the env directly and never appears in shell history or `ps`.

## Recommended companion plugin

`/bitbucket-pr-review` dispatches review work to subagents from the `pr-review-toolkit` plugin (`code-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`, `comment-analyzer`, `type-design-analyzer`). Install it for the best review quality:

```sh
/plugin install pr-review-toolkit
```

Without it, the review skill falls back to an inline review covering the same criteria.

## Safety guarantees

- **`bitbucket-pr-review` is fully read-only.** It calls only `GET` endpoints. No comment posting, no approve, no PR state changes.
- **`bitbucket-pr-write` never auto-pushes** unless the user's invocation explicitly contains a push instruction. The default for an unpushed branch is to refuse and tell the user to push first.
- **Create mode always creates as a draft** (`"draft": true`) so nothing is shipped before the user marks it ready.
- **Confirmation gate** before any `POST` — the user sees the resolved title, branches, draft flag, and rendered description, and must explicitly approve.
- **"PR already exists" never silently overwrites.** The user is asked at runtime whether to update the existing PR, route to review, or skip.

## Future

When Atlassian ships Bitbucket support in their Remote MCP Server (currently Jira + Confluence only — see https://www.atlassian.com/blog/announcements/remote-mcp-server, "more connected Atlassian apps coming soon"), parts of these skills will be simplified to use MCP tools (`getPullRequestDetails`, `getPullRequestComments`, `createPullRequest`, `updatePullRequest`). The diff-fetching and multi-agent dispatch layers will likely stay, since MCP doesn't yet expose raw diffs.

## License

[MIT](./LICENSE) © Darius Rosendahl
