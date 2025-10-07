# the directory of the script save to a variable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat "$SCRIPT_DIR/modules/*.md" > "$GITTOP/src/cluster_deployment/deployment/AGENTS.md"
