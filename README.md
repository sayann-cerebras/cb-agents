# Cerebras Agent Playbook

Setting up the Cerbras Repo for AI agents and human reviewer.

## Scripts

All helper scripts live in `scripts/`:

- `transfer_remote_docker_images.sh` – export Docker images on a remote host, compress (optional `--compression none|gz|7z`), skip locally cached archives, and print croc commands for transfer/import.
- `load_docker_archives.sh` – walk one or more directories (default current dir) for `*.tar`, `*.tar.gz`, or `*.tar.7z` files and `docker load` them (requires `fd`, `docker`, plus `gzip`/`7z` as needed).
- `sync_git_changes_to_remote.sh` – rsync local repo changes to a remote target for quick testing.
- `croc_roundtrip_test.py` – small utility to validate croc send/receive behaviour end-to-end.
 
