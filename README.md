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

```sh
/plugin marketplace add dariusrosendahl/bitbucket-skills
/plugin install bitbucket-skills
```

## Install (Codex CLI)

The SKILL.md files are plain markdown and work in Codex CLI as prompts. Copy them into your Codex prompts folder:

```sh
git clone https://github.com/dariusrosendahl/bitbucket-skills.git /tmp/bitbucket-skills
mkdir -p ~/.codex/prompts
cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-write/SKILL.md \
   ~/.codex/prompts/bitbucket-pr-write.md
cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-review/SKILL.md \
   ~/.codex/prompts/bitbucket-pr-review.md
```

Invoke with `/bitbucket-pr-write` or `/bitbucket-pr-review` in Codex. The same `BITBUCKET_EMAIL` / `BITBUCKET_API_TOKEN` env vars apply (see [Setup](#setup) below).

Note: `bitbucket-pr-review` dispatches subagents, which Codex's prompt-only model doesn't support natively — it will fall back to an inline review covering the same criteria.

## Install (GitHub Copilot, VS Code)

Copy the SKILL.md files into your repo's prompts folder:

```sh
git clone https://github.com/dariusrosendahl/bitbucket-skills.git /tmp/bitbucket-skills
mkdir -p .github/prompts
cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-write/SKILL.md \
   .github/prompts/bitbucket-pr-write.prompt.md
cp /tmp/bitbucket-skills/plugins/bitbucket-skills/skills/bitbucket-pr-review/SKILL.md \
   .github/prompts/bitbucket-pr-review.prompt.md
```

Invoke with `/bitbucket-pr-write` or `/bitbucket-pr-review` in Copilot Chat.

## Cross-tool (AGENTS.md)

For tools that auto-load `AGENTS.md` (Codex, Cursor, Aider), append the SKILL.md content to your repo's `AGENTS.md` to make either skill always-on for that repo. The same Bitbucket env-var setup still applies.

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
