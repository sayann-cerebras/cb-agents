# Project Workflow

The deployment code lives under `deployment_manager/`; CLI entry points are in `deployment_manager/cli`, shared helpers and database models sit in `deployment_manager/db`, and reusable tooling is in `tools/`. Integration and regression tests reside in `deployment_manager/tests`, while heavier Docker-backed suites live in `deployment_manager/tests_container` and protobuf scenarios in `deployment_manager/tests_pb3`. Support scripts and generated artefacts are collected in `bin/`, and review artifacts or agent notes (including this guide) live under `agnt/`.

Bootstrap dependencies with `make venv`, then activate the environment using `source venv/bin/activate`. Run fast feedback tests with `pytest` or `make pytest` (skips container-only suites). Execute the Django-backed checks with `make unittest`, and combine everything with `make test`. For target-specific runs, `pytest deployment_manager/tests/test_cluster_upgrade.py -k batch` filters to cluster upgrade cases, while `FILE=deployment_manager/tests/test_foo.py make pytest` narrows the Makefile target.

You can use the `gh` tool for interacting with Github. Use the PR template in `.github/pull_request_template.md`. Include the JIRA ticket URL in the description.
**After each push add the following comment to trigger 2 required CI test pipelines**:

```sh
gh pr comment --body $'test pre-q\ntest multibox-canary-deploy'
```

For Jenkins-specific workflows, refer to [Jenkins ops notes](jenkins.md).

