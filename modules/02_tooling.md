# CLI Tooling Overview

- `atlassian-remote`: Jira and Wiki pages can be read from here
- `gh`: Github CLI tool for PRs, issues, etc.
  + `gh pr view --comments` — show the discussion timeline (good for quick scans).
  + `gh pr view --json comments --jq '.comments[] | {id: .id, author: .author.login, body: .body}'` — list raw comments with IDs (useful when hunting a reviewer note).
  + `gh pr view --json comments --jq '.comments[] | select(.author.login=="sayann-cerebras")'` — filter comments from a specific reviewer.
  + `gh pr view --json reviews --jq '.reviews[] | {author: .author.login, state: .state}'` — summarize latest reviews.
  + `gh pr view --json files --jq '.files[].path'` — list files touched by the PR.
  + `gh pr checks` — quick glance at CI status for the current PR branch.
  + `gh pr status` — check open PRs associated with your branches.
  + `gh pr comment <pr-number> --body "ready for another look"` — add a top-level PR comment (defaults to current branch when `<pr-number>` omitted).
  + `gh pr view --json id --jq '.id'` — capture the PR's GraphQL node ID for follow-up mutations (only needed for complex GraphQL flows).
  + `gh api repos/Cerebras/monolith/pulls/comments --jq '.[] | select(.user.login=="<reviewer>") | {id, body, path}'` — list inline review comments with their numeric IDs for quick replies.
  + Reply to an inline review comment:
    ```sh
    gh api repos/Cerebras/monolith/pulls/<pr-number>/comments \
      -X POST \
      -F body='Plain text reply without emojis' \
      -F in_reply_to=<comment-id>
    ```
    Use `gh api repos/Cerebras/monolith/pulls/comments/<comment-id>` if you need to confirm the comment still exists or to inspect its context.
    - Always respond directly to review comments (do not create standalone comments) and keep the body emoji-free so automation stays predictable.
    - Pass comment IDs as numbers with `-F in_reply_to=<id>`; using the comment URL or attempting to PATCH the original comment will fail.
  + `gh run list --limit 5` — recent GitHub Actions jobs for the repo; pair with `--json` for details.
  + `gh run view <run-id> --log` — fetch logs for a specific Actions run.
- `ast-grep`: structural search/replace. Quick probes: `ast-grep --lang python -p 'def $FUNC($ARGS): ...' deployment_manager/**/*.py`. For safe refactors, author YAML rewrites (see [transformation docs](https://ast-grep.github.io/reference/yaml/transformation.html)) and execute with `ast-grep -pfile rewrite.yaml --rewrite`.
- `pandoc`: Convert HTML to plain text or Markdown (useful for Jenkins logs).

The `sandbox` repo is cloned at the location `~/Code/sandbox`. Under the folder `~/Code/sandbox/sayan`, you can find analysis on various tickets.
