#!/usr/bin/env python3
"""Verify Phase 0 semantic-map structure in addition to file inventory."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
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
EXPECTED_STATUS = "phase-0-audited-blocked-on-deviations"
PLACEHOLDERS = (
    "pending-audit",
    "pending audit",
    "pending full",
    "pending authoring",
)
ASSERTION_ID = re.compile(r"^[A-Z][A-Z0-9-]*-CX-\d{3}$")


def frontmatter(lines: list[str]) -> list[str]:
    if not lines or lines[0] != "---":
        raise ValueError("missing opening frontmatter delimiter")
    try:
        end = lines.index("---", 1)
    except ValueError as error:
        raise ValueError("missing closing frontmatter delimiter") from error
    return lines[1:end]


def scalar(lines: list[str], key: str) -> str | None:
    prefix = f"{key}:"
    for line in lines:
        if line.startswith(prefix):
            return line[len(prefix) :].strip()
    return None


def sequence(lines: list[str], key: str) -> list[str]:
    prefix = f"{key}:"
    for index, line in enumerate(lines):
        if not line.startswith(prefix):
            continue
        value = line[len(prefix) :].strip()
        if value.startswith("[") and value.endswith("]"):
            return [item.strip() for item in value[1:-1].split(",") if item.strip()]
        items: list[str] = []
        for candidate in lines[index + 1 :]:
            match = re.match(r"^\s+-\s+(.+?)\s*$", candidate)
            if not match:
                break
            items.append(match.group(1).strip("`"))
        return items
    return []


def map_path(scope: str) -> Path:
    return REPO / f".agents/skills/{scope}/refs/compatibility-map.md"


def assertion_suffixes(eval_section: str) -> set[int]:
    """Expand assertion suffixes from the final column of eval-table rows."""
    covered: set[int] = set()
    for line in eval_section.splitlines():
        if not line.startswith("|") or line.startswith("|---"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if not cells:
            continue
        assertion_cell = " ".join(cells[1:])
        for start, end in re.findall(r"\b(\d{3})\.\.(\d{3})\b", assertion_cell):
            covered.update(range(int(start), int(end) + 1))
        without_ranges = re.sub(r"\b\d{3}\.\.\d{3}\b", "", assertion_cell)
        covered.update(int(value) for value in re.findall(r"\b\d{3}\b", without_ranges))
    return covered


def git_files(pattern: str) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", pattern],
        cwd=REPO,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def main() -> int:
    failures: list[str] = []

    inventory = subprocess.run(
        [sys.executable, str(REPO / "evals/codex/verify_phase0.py")],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    if inventory.returncode:
        failures.append(f"inventory verifier failed:\n{inventory.stdout}{inventory.stderr}")

    seen_assertions: dict[str, str] = {}
    seen_evals: dict[str, str] = {}
    combined_maps = ""

    for scope in SCOPES:
        path = map_path(scope)
        text = path.read_text()
        lower = text.lower()
        combined_maps += f"\n{text}"
        lines = text.splitlines()

        try:
            metadata = frontmatter(lines)
        except ValueError as error:
            failures.append(f"{scope}: {error}")
            continue

        if scalar(metadata, "skill") != scope:
            failures.append(f"{scope}: frontmatter skill does not match scope")
        if scalar(metadata, "status") != EXPECTED_STATUS:
            failures.append(f"{scope}: status is not {EXPECTED_STATUS}")

        for placeholder in PLACEHOLDERS:
            if placeholder in lower:
                failures.append(f"{scope}: unresolved placeholder text: {placeholder}")

        assertions = sequence(metadata, "assertions")
        evals = sequence(metadata, "evals")
        if not assertions:
            failures.append(f"{scope}: no frontmatter assertions")
        if not evals:
            failures.append(f"{scope}: no frontmatter evals")

        eval_heading = next(
            (index for index, line in enumerate(lines) if line.startswith("## ") and "eval" in line.lower()),
            None,
        )
        eval_section = "\n".join(lines[eval_heading:]) if eval_heading is not None else ""
        covered_suffixes = assertion_suffixes(eval_section)
        if not eval_section:
            failures.append(f"{scope}: no eval section")

        for assertion in assertions:
            if not ASSERTION_ID.fullmatch(assertion):
                failures.append(f"{scope}: malformed assertion id: {assertion}")
            owner = seen_assertions.setdefault(assertion, scope)
            if owner != scope:
                failures.append(f"duplicate assertion id {assertion}: {owner}, {scope}")
            suffix = int(assertion.rsplit("-", 1)[-1])
            if assertion not in eval_section and suffix not in covered_suffixes:
                failures.append(f"{scope}: assertion not linked from an eval: {assertion}")

        for eval_name in evals:
            owner = seen_evals.setdefault(eval_name, scope)
            if owner != scope:
                failures.append(f"duplicate eval name {eval_name}: {owner}, {scope}")
            if eval_name not in eval_section:
                failures.append(f"{scope}: frontmatter eval missing from eval section: {eval_name}")

        for dimension in ("file", "reference", "behavior", "eval", "dependency"):
            if dimension not in lower:
                failures.append(f"{scope}: coverage dimension absent: {dimension}")
        if lower.count("1.0000") < 5:
            failures.append(f"{scope}: fewer than five explicit 1.0000 mapping ratios")
        if "not-run" not in lower:
            failures.append(f"{scope}: runtime proof is not explicitly not-run")
        if "approved-deviation" in lower or "approved-translation" in lower:
            failures.append(f"{scope}: contains an unapproved disposition")

    helper_files = git_files(".claude/scripts/**")
    for helper in helper_files:
        basename = Path(helper).name
        if basename not in combined_maps:
            failures.append(f"helper absent from every transitive map: {helper}")

    deviation_ledger = (REPO / "codex/deviations.md").read_text()
    ledger_lines = deviation_ledger.splitlines()
    pending_deviations = sum(
        1
        for line in ledger_lines
        if line.startswith("| DEV-CX-") and line.rstrip().endswith("| pending |")
    )
    pending_ambiguities = sum(
        1
        for line in ledger_lines
        if line.startswith("| AMB-CX-") and line.rstrip().endswith("| pending |")
    )
    for number in range(1, 17):
        deviation = f"DEV-CX-{number:03d}"
        if f"### {deviation}" not in deviation_ledger:
            failures.append(f"missing full deviation record: {deviation}")
        if deviation not in combined_maps:
            failures.append(f"deviation has no affected map: {deviation}")
    for number in range(1, 8):
        ambiguity = f"AMB-CX-{number:03d}"
        if ambiguity not in deviation_ledger:
            failures.append(f"missing ambiguity ledger entry: {ambiguity}")
        if ambiguity not in combined_maps:
            failures.append(f"ambiguity has no affected map: {ambiguity}")

    # The freeze artifact is baselines/claude-tree.sha256: per-file digests are
    # verified upstream (PHASE0_VERIFY), so an edit that skips the recorded
    # re-freeze fails there. Here, assert the canonical file *set* still matches
    # the baseline listing — a file added to or removed from the canonical tree
    # without a baseline update fails loudly. User-authorized canonical
    # corrections re-freeze the baseline and are audited via its own git diff
    # plus the codex/deviations.md ledger.
    tracked = set(
        subprocess.run(
            [
                "git",
                "ls-files",
                "--",
                ".claude/skills",
                ".claude/scripts",
                ".claude/settings.json",
                "install.sh",
                "package.json",
            ],
            cwd=REPO,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    )
    baseline_paths = {
        line.split("  ", 1)[1].strip()
        for line in (REPO / "evals/codex/baselines/claude-tree.sha256")
        .read_text()
        .splitlines()
        if line and not line.startswith("#")
    }
    if tracked != baseline_paths:
        added = sorted(tracked - baseline_paths)
        removed = sorted(baseline_paths - tracked)
        failures.append(
            f"canonical file set drifted from baseline: added={added} removed={removed}"
        )

    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        print(f"PHASE0_STRICT fail={len(failures)}")
        return 1

    print(inventory.stdout.strip())
    print(
        "MAP_SEMANTICS_OK "
        f"scopes={len(SCOPES)} assertions={len(seen_assertions)} "
        f"eval_specs={len(seen_evals)} helpers={len(helper_files)}"
    )
    print(
        "DEVIATION_GATE_OK "
        f"pending={pending_deviations} ambiguities_pending={pending_ambiguities}"
    )
    print("CLAUDE_DIFF_OK")
    print("PHASE0_STRICT pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
