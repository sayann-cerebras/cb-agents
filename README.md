# Cerebras Agent Playbook

Setting up the Cerbras Repo for AI agents and human reviewer.

## Repository Layout

This playbook lives in its own Git repository (`cb-agents`) because it is maintained personally rather than as an official team artifact. That lets us iterate on agent SOPs without polluting the main monolith history; when updates are ready, we sync the generated `AGENTS.md` back into the primary repo via `./setup.sh`.

Content is organized by purpose:

- `modules/` – long-form reference docs (numbered to mirror the onboarding flow).
- `flows/` – task-oriented guides and checklists agents follow while working tickets.
- `scripts/` – automation helpers referenced throughout the docs.
- `logs/` and `current_task.md` – scratch space for in-progress notes.

Whenever you add or modify content under `cb-agents/`, commit the change here first, then rerun `./setup.sh` to regenerate the aggregated `AGENTS.md` in the main repo.

## Scripts

All helper scripts live in `scripts/`:

- `transfer_remote_docker_images.sh` – export Docker images on a remote host, compress (optional `--compression none|gz|7z`), skip locally cached archives, and print croc commands for transfer/import.
- `load_docker_archives.sh` – walk one or more directories (default current dir) for `*.tar`, `*.tar.gz`, or `*.tar.7z` files and `docker load` them (requires `fd`, `docker`, plus `gzip`/`7z` as needed).
- `sync_git_changes_to_remote.sh` – rsync local repo changes to a remote target for quick testing.
- `croc_roundtrip_test.py` – small utility to validate croc send/receive behaviour end-to-end.
 
