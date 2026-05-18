---
name: bitbucket-pr-write
description: Use when the user asks to write a Bitbucket PR description (markdown preview) or to actually create the PR on Bitbucket Cloud. Two modes — preview (default, generates copy-pastable markdown from git history) and create (POSTs the PR as a draft via the Bitbucket API when the user explicitly asks). Triggers on "PR description", "write pr", "create pr", "open pr", "bitbucket pr", or /bitbucket-pr-write. For reviewing an existing Bitbucket PR, use `bitbucket-pr-review` instead.
---

# Bitbucket PR Writer

Generate a PR description from the current branch's git history, and optionally open the PR on Bitbucket Cloud as a draft.

## Modes

1. **Preview** (default) — outputs the markdown for copy-paste. No API calls, no side effects.
2. **Create** — POSTs a draft PR to Bitbucket with empty reviewers. Triggered only when the user explicitly asks ("create it", "open the PR", "and push and open it", etc.). When ambiguous, stay in preview and ask.

## Prerequisites (create mode only)

Create mode needs the same env vars as `bitbucket-pr-review`:

```bash
export BITBUCKET_EMAIL="<your-atlassian-account-email>"
export BITBUCKET_API_TOKEN="<your-api-token>"
```

Token sources:
1. **Atlassian API token** (recommended) — https://id.atlassian.com/manage-profile/security/api-tokens.
2. **Bitbucket App Password** — https://bitbucket.org/account/settings/app-passwords/. Needs `Pull requests: write` and `Repositories: write`. With App Passwords, set `BITBUCKET_EMAIL` to your Bitbucket username instead of email.

If either env var is missing in create mode, stop and link to the token page. Never prompt for the token inline.

## Steps — preview (always run)

1. **Determine base branch** — default to `main`, ask if unclear.
2. **Gather data** in parallel:
   - `git log <base>..HEAD --oneline`
   - `git diff <base>..HEAD --stat`
   - Optionally `git diff <base>..HEAD -- '*.json'` for dependency changes
3. **Identify the ticket ID** from branch name or commit prefixes (e.g. `PROJ-123`). If no prefix, derive a short slug from the changes and skip the prefix.
4. **Categorize changes** into groups: dependency changes, code migrations, bug fixes, new features, config changes.
5. **Render markdown** in the format below, wrapped in a single fenced code block.

## Steps — create (only when explicitly requested)

After preview is rendered:

6. **Resolve workspace and repo** from `git remote get-url origin`. Supports:
   - `git@bitbucket.org:<workspace>/<repo>.git`
   - `https://bitbucket.org/<workspace>/<repo>.git`
   - `https://<user>@bitbucket.org/<workspace>/<repo>.git`
   - `ssh://git@bitbucket.org/<workspace>/<repo>.git`

   Strip the trailing `.git`. If the origin isn't a Bitbucket Cloud URL, refuse and explain.

7. **Verify the branch is pushed**. Run `git rev-parse --abbrev-ref @{u}` and `git status -sb`. If the branch has no upstream OR is ahead of its upstream:
   - **Default: refuse.** Tell the user: "Branch `<name>` isn't pushed (or has unpushed commits). Push it with `git push -u origin <name>` and re-run."
   - **Only auto-push** if the user's invocation explicitly contained a push instruction (e.g. "and push it", "push and open the PR"). In that case run `git push -u origin <branch>` first, then continue.

8. **Check for an existing open PR** on this source branch:
   `GET /2.0/repositories/<workspace>/<repo>/pullrequests?q=source.branch.name="<branch>"+AND+state="OPEN"`

   If one or more match, present the user with the existing PR's link and a runtime choice:
   - `(1)` Update the existing PR's title + description (`PUT .../pullrequests/<id>` with the rendered fields).
   - `(2)` Open it via `/bitbucket-pr-review <id>` for review instead.
   - `(3)` Skip — output the preview markdown only.

   Wait for the user's choice. Do not pick one yourself.

9. **Confirm before POST.** Show the resolved title, source → destination branches, `draft: true`, and the rendered description. Wait for explicit go-ahead.

10. **POST the PR**:
    `POST /2.0/repositories/<workspace>/<repo>/pullrequests` with:
    ```json
    {
      "title": "<derived title>",
      "description": "<markdown body>",
      "source":      { "branch": { "name": "<source-branch>" } },
      "destination": { "branch": { "name": "<base>" } },
      "draft": true,
      "reviewers": []
    }
    ```
    Return `links.html.href` so the user can open the PR.

## Output Format (preview markdown)

```
## <Ticket-ID>: <Short descriptive title>

### Summary
1-3 sentences explaining what this PR does and why.

### Changes

**<Category 1>**

- Bullet points of what changed

**<Category 2>**

- Bullet points of what changed

### Testing

- [ ] Checklist of things to verify before merging
```

## Rules

### Markdown rules
- Concise — reviewers scan, they don't read essays.
- Group related changes under bold category headers.
- Imperative mood ("Update X", "Fix Y", not "Updated X").
- Testing checklist of 3-5 items relevant to the changes.
- Title derived from the actual changes, not just the ticket ID.
- For branches with many merged sub-branch commits, focus on those directly relevant to the ticket ID.
- Always put a blank line between a bold category header (e.g. `**Category**`) and its bullet list — Bitbucket's renderer otherwise styles the header as a heading.
- Output the final preview inside a single fenced code block so it's easy to copy.

### Create-mode rules
- **Never auto-push** unless the user's invocation explicitly says so. Refuse and instruct.
- **Always create as draft** (`"draft": true`). The user marks it ready in Bitbucket when they want.
- **Never set reviewers.** Leave `reviewers: []`. Repo default/required-reviewer rules will still apply server-side as configured. Do not read reviewers from any config.
- **Never echo the token.** Use `curl -u "$BITBUCKET_EMAIL:$BITBUCKET_API_TOKEN"` so it isn't visible in `ps` or shell history.
- **Always confirm before POST.** Title, branches, draft flag, description preview, explicit go-ahead.
- **On "already exists" — always ask.** Never silently update or skip.
- **Surface API failures clearly:**
  - `401` → token wrong/expired. Link to the matching token page.
  - `403` → no write access or wrong scopes (App Passwords need `Pull requests: write`).
  - `400` → branch not pushed, or malformed source/destination. Re-check branch state.

## Future

When Atlassian ships Bitbucket support in their Remote MCP Server (currently Jira + Confluence only — https://www.atlassian.com/blog/announcements/remote-mcp-server), the create flow can replace the curl POST with the MCP `createPullRequest` tool. Existing-PR detection (`getPullRequests` with a `source.branch.name` filter) and updates (`updatePullRequest`) would also move to MCP. The preview/markdown layer stays the same. Revisit when the Bitbucket MCP becomes available outside Bitbucket Pipelines.
