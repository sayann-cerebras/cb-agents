# Guidelines

- When adding type annotations, keep compatibility with the supported Python runtimes by importing container types from `typing` (e.g. `from typing import List, Dict`) instead of using the native `list`, `dict`, etc. generics introduced in newer Python releases.

# Project Workflow

## `cluster_deployment/`

The deployment code lives under `deployment_manager/`; CLI entry points are in `deployment_manager/cli`, shared helpers and database models sit in `deployment_manager/db`, and reusable tooling is in `tools/`. Integration and regression tests reside in `deployment_manager/tests`, while heavier Docker-backed suites live in `deployment_manager/tests_container` and protobuf scenarios in `deployment_manager/tests_pb3`. Support scripts and generated artefacts are collected in `bin/`, and review artifacts or agent notes (including this guide) live under `agnt/`.

Bootstrap dependencies with `make venv`, then activate the environment using `source venv/bin/activate`. Run fast feedback tests with `pytest` or `make pytest` (skips container-only suites). Execute the Django-backed checks with `make unittest`, and combine everything with `make test`. For target-specific runs, `pytest deployment_manager/tests/test_cluster_upgrade.py -k batch` filters to cluster upgrade cases, while `FILE=deployment_manager/tests/test_foo.py make pytest` narrows the Makefile target.

## `cluster_mgmt/`

`$GITTOP/src/cluster_mgmt/src/cli/` contains the CLI for full installation of PB3.

You can use the `gh` tool for interacting with Github. Use the PR template in `.github/pull_request_template.md`. Include the JIRA ticket URL in the description.
**After each push add the following comment to trigger 2 required CI test pipelines**:

```sh
gh pr comment --body $'test pre-q\ntest multibox-canary-deploy'
```

For Jenkins-specific workflows, refer to [Jenkins ops notes](jenkins.md).

## Version Control with Jujutsu + GitHub CLI

- Treat Jujutsu (`jj`) as the primary tool for local history management. The repository is already colocated (`.jj/` alongside `.git/`); if you reclone, run `jj git init --colocate` from the repo root to re-establish the dual view.
- Keep Git's view clean by ignoring `.jj/` locally (it lives in `.git/info/exclude`). Do not add `.jj/` to the shared `.gitignore`.
- Daily loop:
  1. `jj git fetch` to pull remote updates, then `jj git import` so new commits appear in your JJ graph.
  2. Create or amend work with `jj new`, `jj commit`, `jj squash`, or `jj split` as needed. Use `jj status` (alias `jj st`) to inspect your stack.
  3. Rebase or fold changes with `jj rebase`/`jj absorb`; resolve conflicts with `jj resolve` followed by `jj commit`.
  4. When ready to surface work to Git, run `jj git export` (or `jj git push --export`) so Git sees updated commits. From there, push via `jj git push` or `git push` interchangeably.
- Keep using the GitHub CLI for PR interactions (`gh pr create`, `gh pr view`, `gh pr comment`, etc.). JJ operates purely on the local history while `gh` handles server-side workflow.
- For conflict-heavy rebases, `jj rebase -r @ --onto <target>` gives an interactive step-by-step conflict fixer. After resolving each file with your editor, mark it done via `jj resolve <path> --mark-resolved`.
- If you need to sync Git-only operations (e.g., `git pull --rebase` you ran out of habit), follow up with `jj git import` to avoid divergent JJ and Git views.
- Prefer difftastic for structural diffs: install `difft`, then enable it with `jj config set --user ui.diff.tool difftastic`. Running `jj diff --tool` or `jj show --tool` now launches difftastic; see [difftastic's JJ tips](https://difftastic.wilfred.me.uk/jj.html) for extra flags such as `--syntax-highlight=off`.
- Configure your identity once for JJ so exported commits have correct metadata:
  ```sh
  jj config set --user user.name "Sayan Naskar"
  jj config set --user user.email "sayan.naskar@cerebras.net"
  ```
- Useful aliases (add with `jj config edit --user`):
  - `st = status --no-graph`
  - `ls = log -r 'ancestors(@,3)' -T 'commit_id.short() \" \" change_id.short() \" \" description.first_line()'`
