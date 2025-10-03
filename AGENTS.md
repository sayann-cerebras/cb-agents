# Cerebras Agent Playbook

Modular context notes for deployment agents. Each module below can be opened individually depending on the task. You can also do `cat cb-agents/modules/*.md` to see everything in one go.

## Modules
- [MCP servers](cb-agents/modules/mcps.md) — connector config for external MCP endpoints.
- [CLI tooling overview](cb-agents/modules/tooling.md) — GitHub CLI, pandoc hints, sandbox references.
- [Cluster node types](cb-agents/modules/cluster-node-types.md) — roles of C-mgmt, D-mgmt, deploy, and related nodes.
- [Dev environment access](cb-agents/modules/dev-environment.md) — SSH targets, password retrieval via $(pass show ssh/cb).
- [Running PB3 tests](cb-agents/modules/pb3-tests.md) — environment variables and sample commands.
- [Project workflow](cb-agents/modules/project-workflow.md) — repository layout, build/test commands, PR requirements.
- [Jenkins ops notes](cb-agents/modules/jenkins.md) — HTML-to-text conversions and log-handling workflow.

## Conventions
- Keep shared guidance lightweight in this index; append deeper sections inside modules.
- When adding sensitive instructions (e.g., credentials), always reference `$(pass show <>)` rather than recording passwords in plain text.
- Large CI logs should be downloaded to `/tmp` and summarized before adding snippets to these docs.
- The `cb-agents` directory is ignored by the main repo; manage its contents with your private git as needed.

