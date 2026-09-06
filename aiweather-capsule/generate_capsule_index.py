#!/usr/bin/env python3
"""Inventory immutable capsules. No measurements are generated or changed."""
import argparse
from datetime import date
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from verify_chain import compute_content_hash


def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError(f"Invalid JSON constant: {value}")


def build_index(capsules_dir: Path) -> dict:
    if not capsules_dir.is_dir():
        raise ValueError(f"Missing capsules directory: {capsules_dir}")
    entries, dates = [], set()
    for path in sorted(capsules_dir.glob("*/*/*.json")):
        relative = path.relative_to(capsules_dir).as_posix()
        try:
            capsule = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=strict_object, parse_constant=reject_constant)
        except (ValueError, UnicodeError) as error:
            raise ValueError(f"Invalid capsule JSON: {relative}: {error}") from error
        if not isinstance(capsule, dict):
            raise ValueError(f"Invalid capsule JSON object: {relative}")
        day = capsule.get("date")
        if not isinstance(day, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", day):
            raise ValueError(f"Invalid date: {relative}")
        date.fromisoformat(day)
        if day in dates:
            raise ValueError(f"Duplicate capsule date: {day}")
        dates.add(day)
        if relative != day.replace("-", "/") + ".json":
            raise ValueError(f"Date/path mismatch: {relative}")
        if path.is_symlink() or path.resolve() != capsules_dir.resolve() / relative:
            raise ValueError(f"Noncanonical capsule path: {relative}")
        if not isinstance(capsule.get("observations"), list):
            raise ValueError(f"Missing observations array: {relative}")
        chain = capsule.get("chain")
        if not isinstance(chain, dict) or chain.get("content_hash") != compute_content_hash(capsule):
            raise ValueError(f"Invalid capsule content hash: {relative}")
        entries.append({"date": day, "path": "../aiweather-capsule/capsules/" + relative})
    return {"schema_version": 1, "capsules": sorted(entries, key=lambda e: e["date"], reverse=True)}


def encode_index(index: dict) -> bytes:
    return (json.dumps(index, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def write_atomic(output: Path, payload: bytes) -> bool:
    if output.exists() and output.read_bytes() == payload:
        return False
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=".capsule-index-", suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, output)
        return True
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def check_index(output: Path, expected: bytes) -> None:
    if not output.is_file() or output.read_bytes() != expected:
        raise ValueError("Capsule index missing or stale; regenerate during Measure before Release.")


def check_git_index(repo: Path, output: Path, index: dict) -> None:
    """Check the exact prospective commit, including Git's existing EOL filters."""
    paths = [output] + [(output.parent / entry["path"]).resolve() for entry in index["capsules"]]
    for path in paths:
        relative = path.resolve().relative_to(repo.resolve()).as_posix()
        def git(*args):
            result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, check=False)
            if result.returncode:
                raise ValueError(f"Not publishable in Git index: {relative}")
            return result.stdout.decode("utf-8").strip()
        mode = git("ls-files", "--stage", "--", relative).split(" ", 1)[0]
        if mode not in ("100644", "100755"):
            raise ValueError(f"Not a staged regular file: {relative}")
        staged = git("rev-parse", "--verify", ":" + relative)
        working = git("hash-object", "--path=" + relative, str(path.resolve()))
        if staged != working:
            raise ValueError(f"Staged content differs from indexed capsule/manifest: {relative}")


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capsules-dir", type=Path, default=root / "aiweather-capsule/capsules")
    parser.add_argument("--output", type=Path, default=root / "data/capsule-index.json")
    parser.add_argument("--check", action="store_true", help="Read-only freshness validation")
    parser.add_argument("--git-index", type=Path, help="Also validate references in the staged prospective commit (requires --check)")
    args = parser.parse_args()
    if args.git_index and not args.check:
        parser.error("--git-index requires --check")
    try:
        index = build_index(args.capsules_dir)
        payload = encode_index(index)
        if args.check:
            check_index(args.output, payload)
            if args.git_index:
                check_git_index(args.git_index, args.output, index)
        else:
            write_atomic(args.output, payload)
        print(f"[OK] Capsule index: {len(index['capsules'])} entries ({'checked' if args.check else 'generated'}).")
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"[ERROR] {error}\n")


if __name__ == "__main__":
    main()
