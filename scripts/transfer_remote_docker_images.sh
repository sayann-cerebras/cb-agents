#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REMOTE="dev-old"
DEFAULT_COMPRESSION="none"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
loader_script="$script_dir/load_docker_archives.sh"

usage() {
    cat <<'USAGE'
Usage: transfer_remote_docker_images.sh [--remote HOST] [--image REPO:TAG]... [--local-dir DIR]
                                 [--compression TYPE]

Exports Docker images on the remote host into /tmp/docker-image-transfer-<timestamp>,
then prints the commands needed to:
  1. start the croc send on the remote host,
  2. receive the archives locally, and
  3. import the downloaded images.

Options:
  --remote HOST   SSH host alias of the remote machine (default: dev-old)
  --image NAME    Specific image (repository:tag) to export; repeat for multiple
  --local-dir DIR Directory to store received archives (default: PWD/<host>-docker-images-<timestamp>)
  --compression TYPE
                  Archive compression to use: none, gz, or 7z (default: none).
                  Existing archives in --local-dir are skipped automatically.
  -h, --help      Show this message
USAGE
}

remote="$DEFAULT_REMOTE"
local_dir=""
compression="$DEFAULT_COMPRESSION"
declare -a images
images=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --remote)
            [[ $# -ge 2 ]] || { echo "--remote expects a value" >&2; exit 1; }
            remote="$2"
            shift 2
            ;;
        --image)
            [[ $# -ge 2 ]] || { echo "--image expects a value" >&2; exit 1; }
            images+=("$2")
            shift 2
            ;;
        --local-dir)
            [[ $# -ge 2 ]] || { echo "--local-dir expects a value" >&2; exit 1; }
            local_dir="$2"
            shift 2
            ;;
        --compression)
            [[ $# -ge 2 ]] || { echo "--compression expects a value" >&2; exit 1; }
            compression="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

compression="$(echo "$compression" | tr 'A-Z' 'a-z')"
case "$compression" in
    ""|none)
        compression="none"
        archive_suffix=".tar"
        ;;
    gz|gzip|tgz)
        compression="gz"
        archive_suffix=".tar.gz"
        ;;
    7z|7zz)
        compression="7z"
        archive_suffix=".tar.7z"
        ;;
    *)
        echo "Unsupported compression type: $compression" >&2
        exit 1
        ;;
esac

timestamp="$(date +%Y%m%d-%H%M%S)"
remote_dir_name="docker-image-transfer-$timestamp"
remote_dir="/tmp/$remote_dir_name"
local_dir="${local_dir:-$PWD/${remote}-docker-images-$timestamp}"
secret="$(uuidgen | tr 'A-Z' 'a-z')"

skip_list_file=""
skip_count=0
if [ -d "$local_dir" ]; then
    tmp_skip="$(mktemp)"
    if find "$local_dir" -type f \( -name '*.tar' -o -name '*.tar.gz' -o -name '*.tar.7z' \) -print0 \
        | while IFS= read -r -d '' existing; do
            base="$(basename "$existing")"
            case "$base" in
                *.tar) safe="${base%.tar}" ;;
                *.tar.gz) safe="${base%.tar.gz}" ;;
                *.tar.7z) safe="${base%.tar.7z}" ;;
                *) continue ;;
            esac
            printf '%s\n' "$safe"
        done | sort -u > "$tmp_skip"; then
        if [ -s "$tmp_skip" ]; then
            skip_list_file="$tmp_skip"
            skip_count=$(wc -l < "$skip_list_file" | tr -d '[:space:]')
            echo "[INFO] Found $skip_count cached archives under $local_dir; matching images will be skipped."
        else
            rm -f "$tmp_skip"
        fi
    else
        rm -f "$tmp_skip"
    fi
fi

echo "[INFO] Exporting images from $remote into $remote_dir"
ssh "$remote" "mkdir -p '$remote_dir'"

if (( ${#images[@]} > 0 )); then
    tmp_file="$(mktemp)"
    printf '%s\n' "${images[@]}" > "$tmp_file"
    scp "$tmp_file" "$remote:$remote_dir/selected-images.txt" >/dev/null
    rm -f "$tmp_file"
else
    ssh "$remote" "rm -f '$remote_dir/selected-images.txt'" >/dev/null
fi

if [[ -n "$skip_list_file" && -s "$skip_list_file" ]]; then
    scp "$skip_list_file" "$remote:$remote_dir/skip-archives.txt" >/dev/null
    rm -f "$skip_list_file"
else
    ssh "$remote" "rm -f '$remote_dir/skip-archives.txt'" >/dev/null
fi

ssh "$remote" "export REMOTE_DIR='$remote_dir' ARCHIVE_SUFFIX='$archive_suffix' COMPRESSION='$compression'; bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail

export_dir="$REMOTE_DIR"
manifest="$export_dir/manifest.tsv"
images_file="$export_dir/image-list.txt"
archive_suffix="${ARCHIVE_SUFFIX:-.tar}"
compression="${COMPRESSION:-none}"
skip_file="$export_dir/skip-archives.txt"

should_skip() {
    [ -s "$skip_file" ] && grep -Fxq "$1" "$skip_file"
}

seven_zip=""
if [ "$compression" = "7z" ]; then
    if command -v 7zz >/dev/null 2>&1; then
        seven_zip="7zz"
    elif command -v 7z >/dev/null 2>&1; then
        seven_zip="7z"
    else
        echo "Compression '7z' requested but neither 7zz nor 7z is available" >&2
        exit 5
    fi
fi

if [ -s "$export_dir/selected-images.txt" ]; then
    awk 'NF' "$export_dir/selected-images.txt" >"$images_file"
else
    docker images --format '{{.Repository}}:{{.Tag}}' \
        | awk '$0 !~ /^<none>:<none>$/' \
        | sort -u >"$images_file"
fi

if [ ! -s "$images_file" ]; then
    echo "No docker images selected" >&2
    exit 3
fi

: >"$manifest"
while IFS= read -r image; do
    [ -n "$image" ] || continue
    safe=$(echo "$image" | sed 's#[^0-9A-Za-z._-]#_#g')
    dest="$export_dir/${safe}${archive_suffix}"
    if should_skip "$safe"; then
        echo "Skipping $image (already cached locally)" >&2
        continue
    fi
    echo "Saving $image -> $dest" >&2
    case "$compression" in
        none)
            tmp_archive=$(mktemp "$export_dir/.${safe}.XXXXXX.tar")
            if docker save "$image" -o "$tmp_archive"; then
                mv "$tmp_archive" "$dest"
            else
                rm -f "$tmp_archive"
                exit 4
            fi
            ;;
        gz)
            tmp_archive=$(mktemp "$export_dir/.${safe}.XXXXXX.tar.gz")
            if docker save "$image" | gzip -c >"$tmp_archive"; then
                mv "$tmp_archive" "$dest"
            else
                rm -f "$tmp_archive"
                exit 4
            fi
            ;;
        7z)
            tmp_tar=$(mktemp "$export_dir/.${safe}.XXXXXX.tar")
            tmp_archive_base=$(mktemp "$export_dir/.${safe}.XXXXXX")
            rm -f "$tmp_archive_base"
            tmp_archive="${tmp_archive_base}.tar.7z"
            if docker save "$image" -o "$tmp_tar" && "$seven_zip" a -mx=3 -bd -bsp0 -bso0 "$tmp_archive" "$tmp_tar" >/dev/null; then
                rm -f "$tmp_tar"
                mv "$tmp_archive" "$dest"
            else
                rm -f "$tmp_tar" "$tmp_archive"
                exit 4
            fi
            ;;
        *)
            echo "Unknown compression: $compression" >&2
            exit 6
            ;;
    esac
    printf '%s\t%s\n' "$image" "$(basename "$dest")" >>"$manifest"
done <"$images_file"

rm -f "$skip_file"

echo "Remote export complete: $export_dir" >&2
REMOTE_SCRIPT

mkdir -p "$local_dir"
transfer_dir="$local_dir/$remote_dir_name"

printf -v loader_cmd "%q %q" "$loader_script" "$transfer_dir"

cat <<EOF

[DONE] Archives prepared on $remote:$remote_dir

Run on $remote to start croc send:
  CROC_SECRET=$secret CROC_NO_LOCAL=1 croc --yes send --no-local $remote_dir

Run locally to receive into $local_dir:
  croc --yes --out '$local_dir' $secret

After download completes, import the images with:
  $loader_cmd

When finished, clean up remote exports with:
  ssh $remote "rm -rf '$remote_dir'"
EOF
