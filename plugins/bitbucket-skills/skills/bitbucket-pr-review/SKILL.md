---
name: bitbucket-pr-review
description: Use when the user asks to review a Bitbucket Cloud pull request, runs /bitbucket-pr-review, or pastes a bitbucket.org PR URL. Fetches the PR via the Bitbucket Cloud API and dispatches a multi-agent code review (code quality, silent failures, tests, comments, type design) against the diff. Read-only — never posts back. For writing a new PR description, use the `bitbucket-pr-write` skill instead.
---

# Review Bitbucket PR

Fetch a Bitbucket Cloud PR and run a parallel multi-agent code review locally. Read-only — never posts comments back to the PR.

## Prerequisites

This skill dispatches review work to subagents from the **`pr-review-toolkit`** plugin (`pr-review-toolkit:code-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`, `comment-analyzer`, `type-design-analyzer`). If that plugin isn't installed, either install it via the plugin marketplace or fall back to an inline review covering the same criteria each agent represents.

## Required env vars

The skill reads credentials from the environment. **Never** hardcode them in files or commit them.

```bash
# In ~/.zshrc, ~/.bashrc, or a shell rc file
export BITBUCKET_EMAIL="<your-atlassian-account-email>"
export BITBUCKET_API_TOKEN="<your-api-token>"
```

**Token sources** (use one):

1. **Atlassian API token** (recommended) — https://id.atlassian.com/manage-profile/security/api-tokens. Works against all Atlassian Cloud products with Basic auth (`email:token`).
2. **Bitbucket App Password** (legacy, still supported) — https://bitbucket.org/account/settings/app-passwords/. Needs at least `Pull requests: read` and `Repositories: read` scopes. Use your Bitbucket username (not email) with App Passwords; set `BITBUCKET_EMAIL` to that username instead.

If either env var is missing, stop and tell the user which one to set and link to the appropriate token page. **Do not** prompt for the token inline — it would land in conversation history.

## Input forms

Accept either:

1. **Full URL** — `https://bitbucket.org/<workspace>/<repo>/pull-requests/<id>`. Parse `<workspace>`, `<repo>`, and `<id>` from the URL. Strip any trailing `#diff`, `?query`, or path segments after the id.

2. **Just the PR id** — derive `<workspace>` and `<repo>` from `git remote get-url origin` of the current directory. Supports any of these remote forms:
   - `git@bitbucket.org:<workspace>/<repo>.git`
   - `https://bitbucket.org/<workspace>/<repo>.git`
   - `https://<user>@bitbucket.org/<workspace>/<repo>.git`
   - `ssh://git@bitbucket.org/<workspace>/<repo>.git`

   Strip the trailing `.git`. If the origin remote isn't a Bitbucket Cloud URL, ask the user for the full PR URL instead of guessing.

## Steps

1. **Resolve PR coordinates** — parse the URL or build from id + remote. Confirm `<workspace>/<repo>/<id>` back to the user in one line before fetching.

2. **Fetch PR data in parallel** with curl using `-u "$BITBUCKET_EMAIL:$BITBUCKET_API_TOKEN"`:
   - Metadata: `GET https://api.bitbucket.org/2.0/repositories/<workspace>/<repo>/pullrequests/<id>`
   - Diff (raw): `GET .../pullrequests/<id>/diff` → save to `/tmp/bb-pr-<id>.diff`
   - Diffstat (file list + stats): `GET .../pullrequests/<id>/diffstat?pagelen=100`
   - Existing comments (for context, not to reply to): `GET .../pullrequests/<id>/comments?pagelen=100&q=deleted=false`

   Extract from metadata: `title`, `description`, `source.branch.name`, `destination.branch.name`, `author.display_name`, `state`, `links.html.href`.

3. **Sync source branch locally** — only if the current directory's git remote points at the same `<workspace>/<repo>` as the PR. This gives agents access to full files, not just diff hunks:
   ```bash
   git fetch origin <source-branch>:refs/remotes/origin/<source-branch>
   ```
   Do **not** check it out — keep the user's working tree untouched. Agents read files via `git show origin/<source-branch>:<path>` or manage their own worktree.

   If the current directory is unrelated to the PR's repo, skip this step. Tell the agents they're reviewing diff-only (no full-file context). Optionally offer to clone the repo into `/tmp/bb-pr-<id>-checkout/` for full-file access.

4. **Dispatch the review agents in parallel** — single message, multiple `Agent` tool calls. Pick from:

   | Agent | Focus |
   |-------|-------|
   | `pr-review-toolkit:code-reviewer` | Bugs, logic errors, security, conventions |
   | `pr-review-toolkit:silent-failure-hunter` | Swallowed errors, suspicious fallbacks |
   | `pr-review-toolkit:pr-test-analyzer` | Test coverage gaps for the new code |
   | `pr-review-toolkit:comment-analyzer` | Comment rot, inaccurate docstrings (only if PR adds/changes comments) |
   | `pr-review-toolkit:type-design-analyzer` | Only if PR introduces or changes types |

   Each agent prompt must include:
   - PR title, description, source → destination branch
   - Path to the saved diff: `/tmp/bb-pr-<id>.diff`
   - The source branch ref (`origin/<source-branch>`) so it can read full files (omit if step 3 was skipped)
   - Explicit "you are reviewing a Bitbucket PR — do not try to post comments, just report findings"
   - "Report only high-confidence, high-priority findings — no nitpicks"

   Skip an agent if its scope clearly doesn't apply (e.g. no comments touched → no comment-analyzer). Don't dispatch agents on autopilot.

5. **Synthesize** the agent outputs into one report. Dedupe overlapping findings. Group by severity. Format:

   ```
   # Review: <PR title> (#<id>)

   <workspace>/<repo> · <source-branch> → <destination-branch> · by <author>
   <link>

   ## Summary
   1-3 sentences on what the PR does and the overall verdict.

   ## Blocking issues
   - **<file>:<line>** — <issue> (<which agent flagged it>)

   ## Should fix
   - ...

   ## Nice to have
   - ...

   ## Test coverage notes
   - ...

   ## Looks good
   - 1-2 things the PR got right (keeps the review balanced)
   ```

   Omit empty sections. If there are no blocking issues, say so explicitly.

## Rules

- **Read-only.** Never call any Bitbucket API endpoint that writes (no POST/PUT/DELETE). The skill does not post comments, approve, or change PR state.
- **Never echo the token.** Don't print `$BITBUCKET_API_TOKEN`, don't pass it as a shell arg that would show in `ps`, don't include it in error messages. Use `curl -u "$BITBUCKET_EMAIL:$BITBUCKET_API_TOKEN"` so curl reads the env var directly.
- **Don't touch the user's working tree.** Fetch refs, don't checkout. If an agent needs a worktree, it manages its own.
- **Surface API failures clearly:**
  - `401` → token/email wrong, expired, or wrong type (App Password vs API token). Link the user to the token page that matches what they're using.
  - `403` → no access to the repo. Have the user confirm they can open the PR in a browser.
  - `404` → wrong workspace/repo/id. Have the user double-check the URL.
  - Don't retry silently.
- **No nitpicks in the final report.** If agents return style nits, drop them. The user wants signal.
- **Parallelize.** Both the curl fetches and the agent dispatches go in single batched tool calls.

## Common mistakes

- Checking out the source branch (clobbers the user's WIP) — fetch only.
- Passing the diff as a giant inline string to each agent (wastes context) — pass the file path.
- Dispatching all five agents when the PR is comment-only or type-free — pick what's relevant.
- Forgetting to URL-encode repo names that contain dots or special chars in the API path.
- Treating a 200 with an empty diff as success — large PRs may need pagination via the diff endpoint's `path` filter, or the diff may genuinely be empty (merge commit). Sanity check the diffstat count against the diff size.
- Running `git fetch` when the current directory's git remote points at a different repo than the PR — the fetch will pull a branch from the wrong repo and agents will read the wrong files.

## Future

When Atlassian ships Bitbucket support in their Remote MCP Server (currently Jira + Confluence only — see https://www.atlassian.com/blog/announcements/remote-mcp-server, "more connected Atlassian apps coming soon"), the metadata/comments parts of step 2 can be replaced with MCP tool calls (e.g. `getPullRequestDetails`, `getPullRequestComments`). The diff-fetching layer and the multi-agent dispatch will still be needed unless MCP also exposes a `getPullRequestDiff` tool. Revisit this skill when the Bitbucket MCP becomes available outside Bitbucket Pipelines.
