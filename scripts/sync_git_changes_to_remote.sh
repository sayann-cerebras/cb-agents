#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: sync_git_changes_to_remote.sh [options] <remote-host> [remote-path]

Copies the files changed in the current branch (relative to a base ref) to the
remote host under /opt/cerebras/cluster-deployment (or a custom path).

By default diffs are computed against origin/master. Override with --base-ref or
by setting SYNC_BASE_REF.

Options:
  --base-ref REF          Diff against REF instead of origin/master.
  -n, --dry-run           Show what would be copied without transferring.
      --sudo              Run rsync via sudo on the remote host.
      --ssh-options OPTS  Extra ssh options (e.g. "-F /dev/null ...").
      --rsync-extra OPT   Extra rsync option (repeatable).
  -h, --help              Show this help message.

Notes:
  * Only paths beneath src/cluster_deployment/ are transferred; others are
    reported and skipped.
  * If SSHPASS is set the script will use sshpass -e for both ssh and rsync.
USAGE
}

err() {
  echo "[error] $*" >&2
  exit 1
}

ensure_binary() {
  command -v "$1" >/dev/null 2>&1 || err "Required command '$1' not found in PATH."
}

ensure_binary git
ensure_binary rsync

BASE_REF=${SYNC_BASE_REF:-origin/master}
DRY_RUN=0
USE_SUDO=0
SSH_OPTS=""
REMOTE_PATH="/opt/cerebras/cluster-deployment"
REMOTE_PATH_SET=0
REMOTE_HOST=""
RSYNC_EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-ref)
      [[ $# -lt 2 ]] && err "--base-ref requires an argument"
      BASE_REF="$2"
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    --sudo)
      USE_SUDO=1
      ;;
    --ssh-options)
      [[ $# -lt 2 ]] && err "--ssh-options requires an argument"
      SSH_OPTS="$2"
      shift
      ;;
    --rsync-extra)
      [[ $# -lt 2 ]] && err "--rsync-extra requires an argument"
      RSYNC_EXTRA+=("$2")
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        RSYNC_EXTRA+=("$1")
        shift
      done
      break
      ;;
    -*)
      err "Unknown option: $1"
      ;;
    *)
      if [[ -z "$REMOTE_HOST" ]]; then
        REMOTE_HOST="$1"
      elif [[ $REMOTE_PATH_SET -eq 0 ]]; then
        REMOTE_PATH="$1"
        REMOTE_PATH_SET=1
      else
        err "Unexpected argument: $1"
      fi
      ;;
  esac
  shift
done

[[ -z "$REMOTE_HOST" ]] && err "Remote host is required."

# REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || err "Not inside a git repository."
REPO_ROOT="$GITTOP"
cd "$REPO_ROOT"

SRC_SUBDIR="src/cluster_deployment"
SRC_ROOT="$REPO_ROOT/$SRC_SUBDIR"
[[ -d "$SRC_ROOT" ]] || err "Expected directory $SRC_SUBDIR under repo root."

MERGE_BASE=$(git merge-base HEAD "$BASE_REF" 2>/dev/null || true)
[[ -n "$MERGE_BASE" ]] || err "Unable to determine merge-base with '$BASE_REF'."

declare -A unique_paths=()

mapfile -t diff_commits < <(git diff --name-only --diff-filter=ACMRTUB "$MERGE_BASE"..HEAD)
mapfile -t diff_worktree < <(git diff --name-only --diff-filter=ACMRTUB HEAD)
mapfile -t untracked < <(git ls-files --others --exclude-standard)

collect_paths() {
  local -n _arr=$1
  shift
  while [[ $# -gt 0 ]]; do
    local entry="$1"
    [[ -n "$entry" && -e "$entry" ]] && _arr+=("$entry")
    shift
  done
}

changed_files=()
collect_paths changed_files "${diff_commits[@]}"
collect_paths changed_files "${diff_worktree[@]}"
collect_paths changed_files "${untracked[@]}"

for path in "${changed_files[@]}"; do
  unique_paths["$path"]=1
done

if [[ ${#unique_paths[@]} -eq 0 ]]; then
  echo "No files changed relative to '$BASE_REF'; nothing to copy."
  exit 0
fi

mapfile -t files_sorted < <(printf '%s\n' "${!unique_paths[@]}" | sort)

echo "Using base ref: $BASE_REF (merge-base $MERGE_BASE)"
printf 'Preparing to copy %d file(s) (including skips):\n' "${#files_sorted[@]}"
for file in "${files_sorted[@]}"; do
  printf '  %s\n' "$file"
done

sync_list=()
skipped=0
for file in "${files_sorted[@]}"; do
  if [[ $file != $SRC_SUBDIR/* ]]; then
    echo "[skip] $file (outside $SRC_SUBDIR)"
    ((skipped++))
    continue
  fi
  rel=${file#${SRC_SUBDIR}/}
  if [[ ! -f "$SRC_ROOT/$rel" ]]; then
    echo "[warn] Expected file missing: $SRC_SUBDIR/$rel"
    continue
  fi
  sync_list+=("$rel")

done

if [[ ${#sync_list[@]} -eq 0 ]]; then
  echo "No files under $SRC_SUBDIR to copy."
  exit 0
fi

cd "$SRC_ROOT"

tmp_list=$(mktemp)
trap 'rm -f "$tmp_list"' EXIT
printf '%s\0' "${sync_list[@]}" >"$tmp_list"

REMOTE_PATH=${REMOTE_PATH%/}

build_remote_shell() {
  local parts=()
  if [[ -n ${SSHPASS:-} ]]; then
    parts+=(sshpass -e)
  fi
  parts+=(ssh)
  if [[ -n "$SSH_OPTS" ]]; then
    # shellcheck disable=SC2086
    parts+=($SSH_OPTS)
  fi
  printf '%q ' "${parts[@]}"
}

remote_shell=$(build_remote_shell)
remote_shell=${remote_shell%% }

rsync_args=(
  --archive
  --verbose
  --compress
  --from0
  --files-from="$tmp_list"
)
[[ $DRY_RUN -eq 1 ]] && rsync_args+=(--dry-run)
[[ $USE_SUDO -eq 1 ]] && rsync_args+=("--rsync-path=sudo rsync")
rsync_args+=("${RSYNC_EXTRA[@]}")
[[ -n "$remote_shell" ]] && rsync_args+=(-e "$remote_shell")

set -x
rsync "${rsync_args[@]}" . "$REMOTE_HOST:${REMOTE_PATH}/"
set +x

if [[ $skipped -gt 0 ]]; then
  echo "Skipped $skipped file(s) outside $SRC_SUBDIR."
fi

echo "Done."
