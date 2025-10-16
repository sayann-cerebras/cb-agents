set -euo pipefail

# the directory of the script save to a variable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

output_file="$GITTOP/src/cluster_deployment/deployment/AGENTS.md"
md_files=("$SCRIPT_DIR/modules/"*.md)
cat "${md_files[@]}" > "$output_file"
monolith_repo="$GITTOP"
info_exclude="$monolith_repo/.git/info/exclude"
host_rel_prefix="src/cluster_deployment/deployment"
cat <<'EOF' >>"$info_exclude"
$host_rel_prefix/AGENTS.md
$host_rel_prefix/cb-agents/*

EOF

