#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOLITH_REMOTE="${MONOLITH_REMOTE:-https://github.com/Cerebras/monolith.git}"

fail_if_no_gittop() {
  if [ -z "${GITTOP:-}" ]; then
    echo "error: GITTOP must be set to the desired monolith checkout path." >&2
    exit 1
  fi
}

repo_exists() {
  [ -d "$GITTOP/.git" ]
}

ensure_tools_present() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: GitHub CLI (gh) is required. Install it from https://cli.github.com/ before running setup." >&2
    exit 1
  fi
}

ensure_github_account() {
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    echo "GitHub CLI not authenticated; starting gh auth login..." >&2
    gh auth login --hostname github.com --git-protocol https
  fi

  local account_count
  account_count=$(gh auth status --json hosts --jq '.hosts["github.com"] // [] | map(select(.login=="sayann-cerebras")) | length' 2>/dev/null || echo "0")
  if [ -z "${account_count}" ] || [ "${account_count}" = "null" ]; then
    account_count=0
  fi

  if [ "${account_count}" -eq 0 ]; then
    echo "Authenticating GitHub account sayann-cerebras..." >&2
    gh auth login --hostname github.com --git-protocol https
  fi

  local active_login
  active_login=$(gh auth status --json hosts --jq '.hosts["github.com"] // [] | map(select(.active==true)) | map(.login) | first // empty' 2>/dev/null || true)

  if [ "${active_login:-}" != "sayann-cerebras" ]; then
    echo "Switching gh default account to sayann-cerebras..." >&2
    gh auth switch --hostname github.com --user sayann-cerebras
  fi
}

ensure_empty_target() {
  if [ -e "$GITTOP" ] && [ ! -d "$GITTOP" ]; then
    echo "error: $GITTOP exists and is not a directory; aborting." >&2
    exit 1
  fi
  if [ -d "$GITTOP" ] && [ "$(ls -A "$GITTOP" 2>/dev/null)" ]; then
    echo "error: $GITTOP exists, is not empty, and lacks a Git repo. Clean it up or set GITTOP elsewhere." >&2
    exit 1
  fi
}

clone_monolith() {
  mkdir -p "$(dirname "$GITTOP")"
  echo "Cloning ${MONOLITH_REMOTE} into $GITTOP..." >&2
  git clone "$MONOLITH_REMOTE" "$GITTOP"
}

apply_ident_overrides() {
  echo "Disabling ident expansion for jj compatibility..." >&2
  "$SCRIPT_DIR/scripts/fix_git_ident_for_jj.py"
}

init_jj_colocation() {
  if ! command -v jj >/dev/null 2>&1; then
    echo "warning: jj CLI not found; skipping jj git init --colocate." >&2
    return
  fi

  if [ ! -d "$GITTOP/.jj" ]; then
    echo "Initializing jj colocation at $GITTOP..." >&2
    (cd "$GITTOP" && jj git init --colocate .)
  else
    echo "jj already initialized at $GITTOP; skipping colocation." >&2
  fi
}

configure_git_identities() {
  echo "Configuring git identities..." >&2
  git config --global user.name "Sayan Naskar"
  git config --global user.email "nascarsayan@gmail.com"
  git -C "$GITTOP" config user.name "Sayan Naskar"
  git -C "$GITTOP" config user.email "sayan.naskar@cerebras.net"
}

configure_jj_identities() {
  if ! command -v jj >/dev/null 2>&1; then
    echo "warning: jj CLI not found; skipping jj identity configuration." >&2
    return
  fi

  echo "Configuring jj identities..." >&2
  jj config set --user user.name "Sayan Naskar"
  jj config set --user user.email "nascarsayan@gmail.com"

  if [ -d "$GITTOP/.jj" ]; then
    (cd "$GITTOP" && jj config set --repo user.name "Sayan Naskar")
    (cd "$GITTOP" && jj config set --repo user.email "sayan.naskar@cerebras.net")
    (cd "$GITTOP" && jj metaedit --update-author)
  else
    echo "warning: jj repo config skipped; $GITTOP/.jj not found." >&2
  fi
}

configure_info_exclude() {
  local info_exclude host_rel_prefix entries entry

  info_exclude="$GITTOP/.git/info/exclude"
  host_rel_prefix="src/cluster_deployment/deployment"
  entries=("$host_rel_prefix/AGENTS.md" "$host_rel_prefix/cb-agents/")

  for entry in "${entries[@]}"; do
    if ! grep -Fxq "$entry" "$info_exclude" 2>/dev/null; then
      echo "$entry" >>"$info_exclude"
    fi
  done
}

configure_identities() {
  configure_git_identities
  configure_jj_identities
}

write_agents_markdown() {
  local output_file md_files file

  output_file="$GITTOP/src/cluster_deployment/deployment/AGENTS.md"
  md_files=("$SCRIPT_DIR/modules/"*.md)
  {
    for file in "${md_files[@]}"; do
      cat "$file"
      printf '\n'
    done
  } >"$output_file"
}

main() {
  fail_if_no_gittop

  if repo_exists; then
    write_agents_markdown
    return
  fi

  ensure_tools_present
  ensure_github_account
  ensure_empty_target
  clone_monolith
  apply_ident_overrides
  init_jj_colocation
  configure_identities
  configure_info_exclude
  write_agents_markdown
}

main "$@"
