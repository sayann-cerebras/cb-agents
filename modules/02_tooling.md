# CLI Tooling Overview

- `atlassian-remote`: Jira and Wiki pages can be read from here
- `gh`: Github CLI tool for PRs, issues, etc.
  + `gh pr view --comments` — show the discussion timeline (good for quick scans).
  + `gh pr view --json comments --jq '.comments[] | {id: .id, author: .author.login, body: .body}'` — list raw comments with IDs (useful when hunting a reviewer note).
  + `gh pr view --json comments --jq '.comments[] | select(.author.login=="sayann-cerebras")'` — filter comments from a specific reviewer.
  + `gh pr view --json reviews --jq '.reviews[] | {author: .author.login, state: .state}'` — summarize latest reviews.
  + `gh pr view --json files --jq '.files[].path'` — list files touched by the PR.
  + `gh pr comment <pr-number> --body "ready for another look"` — add a top-level PR comment (defaults to current branch when `<pr-number>` omitted).
  + `gh pr view --json id --jq '.id'` — capture the PR's GraphQL node ID for follow-up mutations (only needed for complex GraphQL flows).
  + `gh api repos/Cerebras/monolith/pulls/comments --jq '.[] | select(.user.login=="<reviewer>") | {id, body, path}'` — list inline review comments with their numeric IDs for quick replies.
  + Reply to an inline review comment:
    ```sh
    gh api repos/Cerebras/monolith/pulls/<pr-number>/comments \
      -F body='your reply text here' \
      -F in_reply_to=<comment-id>
    ```
    Use `gh api repos/Cerebras/monolith/pulls/comments/<comment-id>` if you need to confirm the comment still exists or to inspect its context.
- `pandoc`: Convert HTML to plain text or Markdown (useful for Jenkins logs).

The `sandbox` repo is cloned at the location `~/Code/sandbox`. Under the folder `~/Code/sandbox/sayan`, you can find analysis on various tickets.
