# bitbucket-skills

Claude Code plugin marketplace for Bitbucket Cloud workflows.

## What's inside

Two skills for working with Bitbucket Cloud pull requests from inside Claude Code:

- **`/bitbucket-pr-write`** — generate a PR description from the current branch's git history.
  - **Preview** (default) — outputs copy-pastable markdown.
  - **Create** — POSTs the PR to Bitbucket as a **draft** via the API when you explicitly ask. Empty reviewers (your repo's required-reviewer rules still apply server-side).
- **`/bitbucket-pr-review`** — fetch a PR via the Bitbucket Cloud API and dispatch a parallel multi-agent code review (code quality, silent failures, tests, comments, type design) against the diff. **Read-only** — never posts back.

Workspace, repo, and PR id are derived from the URL you paste or from `git remote get-url origin`. No hardcoded workspace.

## Install (Claude Code)

Works in Claude Code CLI and the `anthropic.claude-code` VS Code extension — same install, both surfaces. Auto-updates via `/plugin marketplace update`, cleanly reverses with `/plugin uninstall`.

```sh
/plugin marketplace add dariusrosendahl/bitbucket-skills
/plugin install bitbucket-skills
```

Skills then appear in the skill picker as `bitbucket-skills:bitbucket-pr-review` and `bitbucket-skills:bitbucket-pr-write`.

### Alternative: symlink from a local clone

If you want to hack on the skills locally and have changes show up in Claude Code immediately (without `/plugin marketplace update`), clone the repo and run the link script. Skills are then exposed un-namespaced as `bitbucket-pr-review` / `bitbucket-pr-write` (no `bitbucket-skills:` prefix), so don't combine this with the `/plugin install` above or you'll see duplicates.

```sh
git clone https://github.com/dariusrosendahl/bitbucket-skills.git
cd bitbucket-skills
./scripts/link-skills.sh
```

`scripts/list-skills.sh` prints every `SKILL.md` in the repo if you want a manifest.

## Install (Codex CLI)

Symlinks `SKILL.md` into `~/.codex/prompts/` so Codex picks them up as user prompts. `git pull` propagates new versions automatically.

```sh
git clone https://github.com/dariusrosendahl/bitbucket-skills.git
cd bitbucket-skills
./scripts/link-codex.sh
```

Invoke with `/bitbucket-pr-review` or `/bitbucket-pr-write` in Codex. The Bitbucket env vars from [Setup](#setup) still apply.

Note: `bitbucket-pr-review` dispatches subagents in Claude Code. Codex doesn't support subagents — it falls back to a single inline review covering the same criteria.

## Install (VS Code Copilot Chat — no Claude Code)

For colleagues who use **only** VS Code (no Claude Code, no Codex). Copies `SKILL.md` files into VS Code's User-prompts dir as `<name>.prompt.md`, rewriting the Claude Code `name:` frontmatter to the `mode: agent` field Copilot expects. macOS and Linux auto-detected; Windows users should follow the script's error message.

```sh
git clone https://github.com/dariusrosendahl/bitbucket-skills.git
cd bitbucket-skills
./scripts/install-vscode-copilot.sh
```

Reload VS Code (`Cmd+Shift+P` → "Developer: Reload Window"), then type `/` in Copilot Chat — both prompts should appear in the autocomplete. Re-run the script after `git pull` (these are copies, not symlinks, since the frontmatter has to be rewritten).

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
