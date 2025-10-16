set -euo pipefail

# the directory of the script save to a variable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

output_file="$GITTOP/src/cluster_deployment/deployment/AGENTS.md"
md_files=("$SCRIPT_DIR/modules/"*.md)
{
  for file in "${md_files[@]}"; do
    cat "$file"
    printf '\n'
  done
} >"$output_file"
monolith_repo="$GITTOP"
info_exclude="$monolith_repo/.git/info/exclude"
host_rel_prefix="src/cluster_deployment/deployment"
entries=("$host_rel_prefix/AGENTS.md" "$host_rel_prefix/cb-agents/")
for entry in "${entries[@]}"; do
  if ! grep -Fxq "$entry" "$info_exclude" 2>/dev/null; then
    echo "$entry" >>"$info_exclude"
  fi
done
