# bitbucket-skills

[![skills.sh](https://skills.sh/b/dariusrosendahl/bitbucket-skills)](https://skills.sh/dariusrosendahl/bitbucket-skills)

Bitbucket Cloud skills for AI coding agents — works in Claude Code, Codex, Cursor, GitHub Copilot Chat, and [50+ other agents](https://github.com/vercel-labs/skills#supported-agents).

## What's inside

Two skills for working with Bitbucket Cloud pull requests:

- **`/bitbucket-pr-write`** — generate a PR description from the current branch's git history.
  - **Preview** (default) — outputs copy-pastable markdown.
  - **Create** — POSTs the PR to Bitbucket as a **draft** via the API when you explicitly ask. Empty reviewers (your repo's required-reviewer rules still apply server-side).
- **`/bitbucket-pr-review`** — fetch a PR via the Bitbucket Cloud API and dispatch a parallel multi-agent code review (code quality, silent failures, tests, comments, type design) against the diff. **Read-only** — never posts back.

Workspace, repo, and PR id are derived from the URL you paste or from `git remote get-url origin`. No hardcoded workspace.

## Install

```sh
npx skills add dariusrosendahl/bitbucket-skills
```

Run from inside your agent (Claude Code, Codex CLI, etc.) — the [vercel-labs/skills](https://github.com/vercel-labs/skills) CLI auto-detects which one you're in and symlinks the skills into the right location. Add `-g` for a global install across all your projects, or `--copy` if symlinks aren't supported. Same CLI handles `update`, `remove`, and `list`.

### Backup: Claude Code marketplace

If you'd rather not run `npx` (or want the namespaced `bitbucket-skills:` prefix in the skill picker):

```sh
/plugin marketplace add dariusrosendahl/bitbucket-skills
/plugin install bitbucket-skills
```

### Caveat for non-Claude-Code agents

These skills were authored for Claude Code and reference patterns like multi-agent dispatch (`pr-review-toolkit:code-reviewer` etc.) and tool invocations that other agents don't run natively. In Codex, Copilot Chat, Cursor, etc., the skills are followed as **guidance** — you may be asked to run `curl` commands manually, and `bitbucket-pr-review` falls back to a single inline review instead of the parallel multi-agent flow. For full auto-execution use Claude Code.

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
