#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: load_docker_archives.sh [DIR...]

Loads Docker images from archives found under the provided directories. If no
directory is supplied, the current working directory is searched.

Options:
  -h, --help       Show this help message

Recognised archive formats:
  *.tar
  *.tar.gz / *.tgz
  *.tar.7z

The script requires:
  * fd            (for file discovery)
  * docker        (to import images)
  * gzip          (when handling .tar.gz/.tgz archives)
  * 7zz or 7z     (when handling .tar.7z archives)
USAGE
}

log() {
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command '$cmd' not found in PATH." >&2
        exit 1
    fi
}

choose_7z() {
    if [ -n "${SEVEN_ZIP_BIN:-}" ] && command -v "$SEVEN_ZIP_BIN" >/dev/null 2>&1; then
        return 0
    fi
    if command -v 7zz >/dev/null 2>&1; then
        SEVEN_ZIP_BIN="7zz"
        return 0
    fi
    if command -v 7z >/dev/null 2>&1; then
        SEVEN_ZIP_BIN="7z"
        return 0
    fi
    return 1
}

load_archive() {
    local path="$1"
    local base
    base="$(basename "$path")"

    require_cmd docker

    case "$base" in
        *.tar)
            log "Loading ${base}"
            docker load --input "$path"
            log "Loaded ${base}"
            ;;
        *.tar.gz|*.tgz)
            require_cmd gzip
            log "Loading ${base}"
            gzip -dc -- "$path" | docker load
            log "Loaded ${base}"
            ;;
        *.tar.7z)
            if ! choose_7z; then
                echo "7z-compatible extractor (7zz or 7z) is required for ${base}" >&2
                return 1
            fi
            log "Loading ${base}"
            "$SEVEN_ZIP_BIN" x -so -- "$path" | docker load
            log "Loaded ${base}"
            ;;
        *)
            echo "Unsupported archive format: $path" >&2
            return 1
            ;;
    esac
}

if [[ "${1-}" == "--load-single" ]]; then
    shift
    if (( $# != 1 )); then
        echo "--load-single expects exactly one argument" >&2
        exit 1
    fi
    load_archive "$1"
    exit 0
fi

declare -a roots
roots=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                roots+=("$1")
                shift
            done
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            roots+=("$1")
            shift
            ;;
    esac
done

if (( ${#roots[@]} == 0 )); then
    roots+=("$PWD")
fi

for dir in "${roots[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Directory not found: $dir" >&2
        exit 1
    fi
done

declare -a search_roots
search_roots=()
for dir in "${roots[@]}"; do
    if [[ "$dir" == -* ]]; then
        search_roots+=("./$dir")
    else
        search_roots+=("$dir")
    fi
done

require_cmd fd
require_cmd docker

pattern='(?i)\.(tar(\.(gz|7z))?|tgz)$'
count=$(fd -u -t f "$pattern" "${search_roots[@]}" | wc -l | tr -d '[:space:]')

if [[ -z "$count" || "$count" == "0" ]]; then
    log "No archives found under ${roots[*]}"
    exit 0
fi

log "Discovered $count archive(s)"

if ! fd -u -t f "$pattern" "${search_roots[@]}" -x "$0" --load-single {} ; then
    echo "Encountered errors while loading archives." >&2
    exit 1
fi

log "All archives loaded successfully."
