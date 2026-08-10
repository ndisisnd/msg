#!/usr/bin/env python3
"""Verify the frozen Claude baseline and Phase 0 map inventories."""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
BASELINE = REPO / "evals/codex/baselines/claude-tree.sha256"
SCOPES = (
    "msg",
    "intake",
    "plan-pm",
    "plan-review",
    "plan-em",
    "eng",
    "pre-merge",
    "merge",
    "emulate",
    "shared",
)
MAP_ROW = re.compile(
    r"^\| `(?P<path>\.claude/skills/[^`]+)` \| `(?P<digest>[0-9a-f]{64})` \|"
)


def git_files(*patterns: str) -> set[str]:
    command = ["git", "ls-files", *patterns]
    result = subprocess.run(
        command,
        cwd=REPO,
        check=True,
        capture_output=True,
        text=True,
    )
    return {line for line in result.stdout.splitlines() if line}


def canonical_runtime_files() -> set[str]:
    return (
        git_files(".claude/skills/**")
        | git_files(".claude/scripts/**")
        | git_files(".claude/settings.json", "install.sh", "package.json")
    )


def load_baseline() -> dict[str, str]:
    entries: dict[str, str] = {}
    for line_number, raw_line in enumerate(BASELINE.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split(maxsplit=1)
        if len(fields) != 2 or not re.fullmatch(r"[0-9a-f]{64}", fields[0]):
            raise ValueError(f"invalid baseline row at line {line_number}: {raw_line}")
        digest, path = fields
        if path in entries:
            raise ValueError(f"duplicate baseline path: {path}")
        entries[path] = digest
    return entries


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_map_rows(scope: str) -> dict[str, str]:
    map_path = REPO / f".agents/skills/{scope}/refs/compatibility-map.md"
    rows: dict[str, str] = {}
    for raw_line in map_path.read_text().splitlines():
        match = MAP_ROW.match(raw_line)
        if not match:
            continue
        path = match.group("path")
        if path in rows:
            raise ValueError(f"{scope}: duplicate map row for {path}")
        rows[path] = match.group("digest")
    return rows


def main() -> int:
    failures: list[str] = []

    baseline = load_baseline()
    runtime_files = canonical_runtime_files()
    if set(baseline) != runtime_files:
        missing = sorted(runtime_files - set(baseline))
        orphaned = sorted(set(baseline) - runtime_files)
        failures.append(f"baseline set mismatch: missing={missing}, orphaned={orphaned}")

    for relative_path, expected_digest in sorted(baseline.items()):
        path = REPO / relative_path
        if not path.is_file():
            failures.append(f"baseline file missing: {relative_path}")
            continue
        actual_digest = sha256(path)
        if actual_digest != expected_digest:
            failures.append(
                f"Claude baseline drift: {relative_path}: "
                f"expected {expected_digest}, got {actual_digest}"
            )

    all_mapped_paths: set[str] = set()
    for scope in SCOPES:
        expected_paths = git_files(f".claude/skills/{scope}/**")
        rows = load_map_rows(scope)
        row_paths = set(rows)
        if row_paths != expected_paths:
            missing = sorted(expected_paths - row_paths)
            orphaned = sorted(row_paths - expected_paths)
            failures.append(
                f"{scope} map set mismatch: missing={missing}, orphaned={orphaned}"
            )
        overlap = all_mapped_paths & row_paths
        if overlap:
            failures.append(f"canonical paths mapped more than once: {sorted(overlap)}")
        all_mapped_paths |= row_paths

        for relative_path, mapped_digest in sorted(rows.items()):
            baseline_digest = baseline.get(relative_path)
            if mapped_digest != baseline_digest:
                failures.append(
                    f"{scope} map digest mismatch: {relative_path}: "
                    f"map={mapped_digest}, baseline={baseline_digest}"
                )

    canonical_skill_files = git_files(".claude/skills/**")
    if all_mapped_paths != canonical_skill_files:
        failures.append(
            "global skill map coverage mismatch: "
            f"mapped={len(all_mapped_paths)}, canonical={len(canonical_skill_files)}"
        )

    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        print(f"PHASE0_VERIFY fail={len(failures)}")
        return 1

    print(f"BASELINE_OK files={len(baseline)}")
    print(f"MAP_INVENTORY_OK files={len(all_mapped_paths)} scopes={len(SCOPES)}")
    print("PHASE0_VERIFY pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
