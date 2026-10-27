#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Local Developer build metadata, without test logs or credentials."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
import uuid


ROOT = Path(__file__).resolve().parents[1]
RECORD_NAME = "build/developer-test-status.json"
RECORD_FIELDS = (
    "schemaVersion", "runID", "state", "scope", "suites", "startedAt",
    "finishedAt", "revision", "sourceFingerprint", "sourceChanged",
)


def git(root: Path, *arguments: str) -> bytes | None:
    environment = dict(os.environ)
    for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
        environment.pop(key, None)
    environment.update(GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0", GIT_NO_LAZY_FETCH="1")
    try:
        result = subprocess.run(
            ["git", *arguments], cwd=root, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=15,
        )
        return result.stdout if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def revision(root: Path, *arguments: str) -> str | None:
    value = git(root, *arguments)
    text = value.decode("ascii", errors="replace").strip() if value else ""
    return text if re.fullmatch(r"[0-9a-f]{40}", text) else None


def source_fingerprint(root: Path) -> str | None:
    names = git(root, "ls-files", "--cached", "--others", "--exclude-standard", "-z")
    if names is None:
        return None
    digest = hashlib.sha256(b"vorssaint-developer-source-v1\0")
    count = 0
    try:
        for name in sorted(set(names.split(b"\0")) - {b""}):
            source = root / os.fsdecode(name)
            if not source.exists() and not source.is_symlink():
                continue
            mode = source.stat().st_mode
            if not stat.S_ISREG(mode):
                return None
            content = hashlib.sha256()
            with source.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    content.update(chunk)
            executable = b"1" if mode & 0o111 else b"0"
            digest.update(name + b"\0" + executable + content.digest())
            count += 1
    except OSError:
        return None
    # Content identity survives committing the tested dirty working tree.
    return digest.hexdigest() if count else None


def write_json(destination: Path, value: dict) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".developer-status-", suffix=".tmp",
                                             dir=destination.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(value, stream, ensure_ascii=False, allow_nan=False, sort_keys=True, indent=2)
            stream.write("\n")
        os.chmod(temporary, 0o644)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def timestamp(value: object) -> bool:
    if type(value) not in (int, float):
        return False
    try:
        return math.isfinite(value) and value >= 0
    except OverflowError:
        return False


def optional_hash(value: object, lengths: tuple[int, ...]) -> bool:
    return value is None or (isinstance(value, str) and len(value) in lengths
                             and re.fullmatch(r"[0-9a-f]+", value) is not None)


def read_json(path: Path) -> object:
    try:
        with path.open("rb") as stream:
            data = stream.read(64 * 1024 + 1)
        if len(data) > 64 * 1024:
            return None
        return json.loads(data)
    except (OSError, ValueError, TypeError):
        return None


def validated_record(record: object) -> dict | None:
    if not isinstance(record, dict) or not all(field in record for field in RECORD_FIELDS):
        return None
    if type(record["schemaVersion"]) is not int or record["schemaVersion"] != 1:
        return None
    if not isinstance(record["runID"], str) or not 0 < len(record["runID"]) <= 64:
        return None
    if record["state"] not in ("incomplete", "passed", "failed"):
        return None
    if record["scope"] not in ("full", "selected"):
        return None
    suites = record["suites"]
    if not isinstance(suites, list) or not all(isinstance(suite, str) for suite in suites):
        return None
    if (record["scope"] == "full") != (len(suites) == 0):
        return None
    if not timestamp(record["startedAt"]) or type(record["sourceChanged"]) is not bool:
        return None
    finished = record["finishedAt"]
    if record["state"] == "incomplete":
        if finished is not None:
            return None
    elif not timestamp(finished) or finished < record["startedAt"]:
        return None
    if not optional_hash(record["revision"], (40,)) or not optional_hash(record["sourceFingerprint"], (64,)):
        return None
    # Never copy unknown fields (paths, output or future private data) into the app.
    return {field: record[field] for field in RECORD_FIELDS}


def read_record(root: Path) -> dict | None:
    return validated_record(read_json(root / RECORD_NAME))


@contextmanager
def record_lock(root: Path):
    directory = (root / RECORD_NAME).parent
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / ".developer-test-status.lock").open("a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(stream, fcntl.LOCK_UN)


def begin(root: Path, suites: list[str]) -> str:
    selected = sorted(set(suites))
    with record_lock(root):
        record = {
            "schemaVersion": 1,
            "runID": str(uuid.uuid4()),
            "state": "incomplete",
            "scope": "selected" if selected else "full",
            "suites": selected,
            "startedAt": time.time(),
            "finishedAt": None,
            "revision": revision(root, "rev-parse", "--verify", "HEAD"),
            "sourceFingerprint": source_fingerprint(root),
            "sourceChanged": False,
        }
        write_json(root / RECORD_NAME, record)
    return record["runID"]


def finish(root: Path, run_id: str, exit_code: int) -> bool:
    with record_lock(root):
        record = read_record(root)
        if record is None or record["runID"] != run_id or record["state"] != "incomplete":
            return False
        fingerprint = source_fingerprint(root)
        record["state"] = "passed" if exit_code == 0 else "failed"
        record["finishedAt"] = max(time.time(), record["startedAt"])
        record["sourceChanged"] = record["sourceFingerprint"] != fingerprint
        write_json(root / RECORD_NAME, record)
        return True


def validated_snapshot(value: object) -> dict | None:
    fields = ("schemaVersion", "revision", "dirty", "sourceFingerprint", "upstreamRevision", "test")
    if not isinstance(value, dict) or not all(field in value for field in fields):
        return None
    if type(value["schemaVersion"]) is not int or value["schemaVersion"] != 1 or type(value["dirty"]) is not bool:
        return None
    if not all(optional_hash(value[key], (40,)) for key in ("revision", "upstreamRevision")):
        return None
    if not optional_hash(value["sourceFingerprint"], (64,)):
        return None
    record = validated_record(value["test"]) if value["test"] is not None else None
    if value["test"] is not None and record is None:
        return None
    result = {field: value[field] for field in fields}
    result["test"] = record
    return result


def snapshot(root: Path, initial: Path | None = None) -> dict:
    if initial is not None:
        captured = validated_snapshot(read_json(initial))
        if captured is None:
            return {"schemaVersion": 1, "revision": None, "dirty": True,
                    "sourceFingerprint": None, "upstreamRevision": None, "test": None}
        current = source_fingerprint(root)
        if captured["sourceFingerprint"] is None or current is None or captured["sourceFingerprint"] != current:
            captured["sourceFingerprint"] = None
            captured["dirty"] = True
        return captured

    commit = revision(root, "rev-parse", "--verify", "HEAD")
    fingerprint = source_fingerprint(root)
    status = git(root, "status", "--porcelain", "--untracked-files=normal")
    return {
        "schemaVersion": 1,
        "revision": commit,
        "dirty": bool(status) or status is None or commit is None or fingerprint is None,
        "sourceFingerprint": fingerprint,
        "upstreamRevision": revision(root, "merge-base", commit, "upstream/main") if commit else None,
        "test": read_record(root),
    }


def commit_label(captured: dict) -> str:
    commit = captured["revision"]
    return (commit[:8] if commit else "unknown") + ("-dirty" if captured["dirty"] else "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser("begin")
    start.add_argument("--suite", action="append", default=[])
    end = commands.add_parser("finish")
    end.add_argument("--run-id", required=True)
    end.add_argument("--exit-code", type=int, required=True)
    capture = commands.add_parser("snapshot")
    capture.add_argument("--output", type=Path, required=True)
    capture.add_argument("--initial", type=Path)
    capture.add_argument("--print-commit", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.command == "begin":
            print(begin(ROOT, arguments.suite))
        elif arguments.command == "finish":
            finish(ROOT, arguments.run_id, arguments.exit_code)
        else:
            captured = snapshot(ROOT, arguments.initial)
            write_json(arguments.output, captured)
            if arguments.print_commit:
                print(commit_label(captured))
        return 0
    except (OSError, ValueError):
        print("Could not record Developer build status.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
