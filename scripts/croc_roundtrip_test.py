#!/usr/bin/env python3
"""
Minimal end-to-end croc transfer check.

This script uses the helpers from transfer_remote_docker_images.py to
send a directory from a remote host and receive it locally. Useful for
validating croc connectivity before running the full export/import flow.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

from transfer_remote_docker_images import (
    DEFAULT_TIMEOUT,
    CommandError,
    ensure_local_dir,
    generate_code,
    receive_with_croc,
    start_remote_croc_send,
    wait_for_remote_ready,
)

def arg_quote(path: str) -> str:
    """Return a shell-quoted version of `path`."""
    return "'" + path.replace("'", "'\\''") + "'"

def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Test croc send/receive between remote and local hosts.")
    parser.add_argument("remote", help="SSH host alias for the remote machine")
    parser.add_argument("remote_path", help="Directory on the remote host to send")
    parser.add_argument(
        "--code",
        help="Optional croc code to reuse. If omitted, a random code is generated.",
    )
    parser.add_argument(
        "--local-dir",
        type=Path,
        default=Path.cwd() / "croc-roundtrip",
        help="Where to store the received payload (default: ./croc-roundtrip)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help="Timeout in seconds for each async operation (default: %(default)s).",
    )
    return parser.parse_args(argv)


def confirm_remote_dir(remote: str, path: str, timeout: int | None) -> None:
    """Ensure the remote path exists and is a directory."""
    command = f"test -d {arg_quote(path)}"
    try:
        proc = subprocess.run(
            ["ssh", remote, command],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
    except OSError as exc:
        raise CommandError(f"Failed to invoke ssh on {remote}: {exc}")

    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip().replace("\n", " ")
        raise CommandError(
            f"Unable to confirm directory {path} on {remote} (exit {proc.returncode}). "
            f"Details: {detail or 'no output'}"
        )


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    timeout = None if args.timeout == 0 else args.timeout

    confirm_remote_dir(args.remote, args.remote_path, timeout)

    ensure_local_dir(args.local_dir)
    remote_log = args.local_dir / "remote-croc-send.log"
    code = args.code or generate_code()
    print(f"[INFO] Using croc code: {code}")
    print(f"[INFO] Remote log will stream to {remote_log}")

    send_proc = start_remote_croc_send(
        args.remote,
        args.remote_path,
        code,
        log_path=remote_log,
    )
    print(
        f"[TRACK] Remote croc status: ssh {args.remote} 'pgrep -af \"croc --yes send\"'"
    )

    try:
        wait_for_remote_ready(send_proc, remote_log, timeout)
        print(f"[INFO] Receiving into {args.local_dir}")
        receive_with_croc(code, args.local_dir)
    finally:
        try:
            send_proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            send_proc.kill()
        if hasattr(send_proc, "log_file"):
            send_proc.log_file.close()  # type: ignore[attr-defined]

    print("[INFO] Roundtrip completed successfully")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except CommandError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("[ERROR] Aborted", file=sys.stderr)
        sys.exit(1)
