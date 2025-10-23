#!/usr/bin/env python3
"""
Disable Git ident expansion so `jj status` matches `git status`.

Assumes $GITTOP points at the Git checkout that should be patched.
The script is idempotent; it writes a managed block to
<GITTOP>/.git/info/attributes and refreshes any files affected by ident.
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple


BEGIN_MARKER = "# >>> jj-ident-disable >>>"
END_MARKER = "# <<< jj-ident-disable <<<"
MANAGED_COMMENT = (
    "# Managed by cb-agents/scripts/fix_git_ident_for_jj.py to keep git/jj in sync."
)


def git(repo_root: Path, args: Sequence[str], *, check: bool = True, **kwargs):
    """Run git command in repo_root with stdout captured."""
    completed = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        text=True,
        capture_output=True,
        **kwargs,
    )
    if check and completed.returncode != 0:
        raise subprocess.CalledProcessError(
            completed.returncode, completed.args, completed.stdout, completed.stderr
        )
    return completed


def normalize_pattern(rel_dir: Path, pattern: str) -> str:
    """Convert a .gitattributes pattern into repo-root-relative form."""
    pattern = pattern.strip()
    if pattern.startswith("/"):
        return pattern.lstrip("/")
    if rel_dir == Path("."):
        return pattern
    rel_prefix = rel_dir.as_posix()
    if "/" in pattern:
        normalized = f"{rel_prefix}/{pattern}"
    else:
        normalized = f"{rel_prefix}/**/{pattern}"
    while "//" in normalized:
        normalized = normalized.replace("//", "/")
    return normalized


def parse_ident_patterns(repo_root: Path) -> List[str]:
    """Return patterns that have ident enabled in any .gitattributes."""
    patterns = set()
    for attrs_path in repo_root.rglob(".gitattributes"):
        rel_dir = attrs_path.parent.relative_to(repo_root)
        with attrs_path.open("r", encoding="utf-8", errors="ignore") as handle:
            for raw_line in handle:
                line = raw_line.split("#", 1)[0].strip()
                if not line:
                    continue
                parts = line.split()
                if len(parts) < 2:
                    continue
                pattern, attrs = parts[0], parts[1:]
                if not any(attr.split("=", 1)[0] == "ident" for attr in attrs):
                    continue
                normalized = normalize_pattern(rel_dir, pattern)
                patterns.add(normalized)
    return sorted(patterns)


def collect_ident_files(repo_root: Path) -> List[str]:
    """Return tracked files with ident currently enabled."""
    listing = git(repo_root, ["ls-files", "-z"]).stdout.split("\0")
    tracked = [entry for entry in listing if entry]
    if not tracked:
        return []
    query = "\n".join(tracked) + "\n"
    check = git(
        repo_root,
        ["check-attr", "--stdin", "ident"],
        input=query,
    )
    paths: List[str] = []
    for line in check.stdout.splitlines():
        parts = [part.strip() for part in line.split(":", 2)]
        if len(parts) < 3:
            continue
        path, attr, value = parts
        if attr == "ident" and value == "set":
            paths.append(path)
    return paths


def write_info_attributes(repo_root: Path, patterns: Sequence[str]) -> Tuple[Path, bool]:
    """Insert managed -ident block into .git/info/attributes."""
    info_dir = repo_root / ".git" / "info"
    info_dir.mkdir(parents=True, exist_ok=True)
    info_attrs = info_dir / "attributes"
    existing = []
    if info_attrs.exists():
        existing = info_attrs.read_text(encoding="utf-8").splitlines()

    cleaned: List[str] = []
    skipping = False
    for line in existing:
        stripped = line.strip()
        if stripped == BEGIN_MARKER:
            skipping = True
            continue
        if skipping and stripped == END_MARKER:
            skipping = False
            continue
        if not skipping:
            cleaned.append(line)

    managed_block: List[str] = [BEGIN_MARKER, MANAGED_COMMENT]
    managed_block.extend(f"{pattern} -ident" for pattern in patterns)
    managed_block.append(END_MARKER)

    if cleaned and cleaned[-1].strip():
        cleaned.append("")
    cleaned.extend(managed_block)
    new_content = "\n".join(cleaned) + "\n"
    changed = (
        not info_attrs.exists()
        or info_attrs.read_text(encoding="utf-8") != new_content
    )
    info_attrs.write_text(new_content, encoding="utf-8")
    return info_attrs, changed


def refresh_files(repo_root: Path, files: Iterable[str]) -> List[str]:
    """Ensure working tree copies are restored to the `$Id$` placeholder."""
    refreshed: List[str] = []
    for rel in files:
        target = repo_root / rel
        if target.exists():
            if target.is_file() or target.is_symlink():
                target.unlink()
            else:
                continue
        git(repo_root, ["checkout", "HEAD", "--", rel])
        refreshed.append(rel)
    return refreshed


def main() -> int:
    git_top = os.environ.get("GITTOP")
    if not git_top:
        sys.stderr.write("error: GITTOP is not defined\n")
        return 1

    repo_root = Path(git_top).resolve()
    if not (repo_root / ".git").is_dir():
        sys.stderr.write(f"error: {repo_root} does not look like a git repo\n")
        return 1

    patterns = parse_ident_patterns(repo_root)
    if not patterns:
        print("No ident patterns detected; nothing to do.")
        return 0

    ident_files = collect_ident_files(repo_root)
    info_attrs, changed = write_info_attributes(repo_root, patterns)
    rel_info = info_attrs.relative_to(repo_root)
    if changed:
        print(f"Updated {rel_info} with -ident overrides.")
    else:
        print(f"{rel_info} already contains ident overrides.")

    if ident_files:
        refreshed = refresh_files(repo_root, ident_files)
        if refreshed:
            print(f"Refreshed {len(refreshed)} files with ident expansion.")
        else:
            print("Tracked ident files required no refresh.")
    else:
        print("No ident-enabled files detected.")

    print("Ident overrides installed. git/jj status should now match.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
