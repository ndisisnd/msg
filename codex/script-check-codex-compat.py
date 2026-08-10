#!/usr/bin/env python3
"""Static Phase 1 parity checks for the generated Codex tree.

Layer 0 packaging checks only — no model tokens, no runtime execution:

* discovery: exactly nine Codex skills, bijective with the canonical nine;
  `shared` is a reference holder and must not expose a skill entry point
* adapter shape: frontmatter carries `name` and `description` and nothing else;
  the name matches its directory; no stray active-runtime slash handoff
* byte fidelity: every canonical copy and every canonical payload matches its
  `.claude/` source exactly, and the helper mirror is complete
* manifest freshness: the generated tree equals the generation manifest, with no
  unmanaged or stale files
* reference integrity: every skill-relative link inside the generated tree
  resolves inside the generated tree
* Claude isolation: the generator wrote nothing under `.claude/`

Usage: python3 codex/script-check-codex-compat.py
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

CANONICAL_SKILL_ROOT = REPO / ".claude/skills"
CANONICAL_SCRIPT_ROOT = REPO / ".claude/scripts"
CODEX_SKILL_ROOT = REPO / ".agents/skills"
CODEX_SCRIPT_ROOT = REPO / ".agents/scripts"
MANIFEST = REPO / "codex/generation-manifest.json"

SHARED = "shared"
EXPECTED_SKILLS = 9
ALLOWED_ADAPTER_KEYS = {"name", "description"}

# Reference forms that are skill-tree relative and therefore must resolve inside
# the generated tree. Everything else (devkit/, features/, INTAKE.md, ...) is a
# project-runtime path resolved at run time against the user's repository.
SKILL_REF = re.compile(r"(?<![\w./-])((?:\.\./)*(?:refs|shared|scripts)/[\w./-]+\.[a-zA-Z0-9]+)")

failures: list[str] = []
notes: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def git_files(pattern: str) -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", pattern],
        cwd=REPO,
        check=True,
        capture_output=True,
    )
    return sorted(p for p in result.stdout.decode().split("\0") if p)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frontmatter_keys(text: str) -> tuple[set[str], dict[str, str]]:
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return set(), {}
    keys: set[str] = set()
    values: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith((" ", "\t")) or not line.strip():
            continue
        key, _, value = line.partition(":")
        keys.add(key.strip())
        values[key.strip()] = value.strip()
    return keys, values


# --------------------------------------------------------------------------- #


def check_discovery() -> list[str]:
    canonical = sorted(
        p.name for p in CANONICAL_SKILL_ROOT.iterdir() if p.is_dir() and p.name != SHARED
    )
    codex = sorted(
        p.parent.name for p in CODEX_SKILL_ROOT.glob("*/SKILL.md") if p.is_file()
    )
    if len(codex) != EXPECTED_SKILLS:
        fail(f"discovery: expected {EXPECTED_SKILLS} Codex skills, found {len(codex)}: {codex}")
    if canonical != codex:
        fail(
            "discovery: Claude/Codex skill sets are not a bijection: "
            f"claude_only={sorted(set(canonical) - set(codex))} "
            f"codex_only={sorted(set(codex) - set(canonical))}"
        )
    if (CODEX_SKILL_ROOT / SHARED / "SKILL.md").exists():
        fail("discovery: shared/ must not expose a skill entry point")
    return codex


def check_adapters(skills: list[str]) -> None:
    invocation = re.compile(
        r"(?<![\w/.\-$])/(" + "|".join(sorted(map(re.escape, skills), key=len, reverse=True)) + r")(?![\w/.\-])"
    )
    for skill in skills:
        adapter = CODEX_SKILL_ROOT / skill / "SKILL.md"
        text = adapter.read_text()
        keys, values = frontmatter_keys(text)
        extra = keys - ALLOWED_ADAPTER_KEYS
        if extra:
            fail(f"{skill}: adapter frontmatter has non-Codex keys: {sorted(extra)}")
        missing = ALLOWED_ADAPTER_KEYS - keys
        if missing:
            fail(f"{skill}: adapter frontmatter missing {sorted(missing)}")
        if values.get("name") != skill:
            fail(f"{skill}: adapter frontmatter name is {values.get('name')!r}")
        stray = invocation.findall(text)
        if stray:
            fail(f"{skill}: adapter emits Claude slash handoffs: {sorted(set(stray))}")
        if f"${skill}" not in text and skill not in text:
            fail(f"{skill}: adapter never names its own invocation")
        for required in ("../shared/refs/codex-runtime.md", "refs/compatibility-map.md", "CLAUDE-SKILL.md"):
            if required not in text:
                fail(f"{skill}: adapter does not point at {required}")
        metadata = CODEX_SKILL_ROOT / skill / "agents/openai.yaml"
        if not metadata.is_file():
            fail(f"{skill}: missing agents/openai.yaml")
        else:
            meta_keys, meta_values = frontmatter_keys("---\n" + metadata.read_text() + "\n---")
            if meta_values.get("name") != skill:
                fail(f"{skill}: openai.yaml name is {meta_values.get('name')!r}")


def check_byte_fidelity(skills: list[str]) -> None:
    for skill in skills:
        canonical = CANONICAL_SKILL_ROOT / skill / "SKILL.md"
        payload = CODEX_SKILL_ROOT / skill / "CLAUDE-SKILL.md"
        if not payload.is_file():
            fail(f"{skill}: missing CLAUDE-SKILL.md canonical payload")
        elif payload.read_bytes() != canonical.read_bytes():
            fail(f"{skill}: CLAUDE-SKILL.md is not byte-identical to the canonical SKILL.md")

    for path in git_files(".claude/skills/**"):
        relative = path[len(".claude/skills/") :]
        owner, _, inner = relative.partition("/")
        if owner == SHARED:
            mirror = CODEX_SKILL_ROOT / SHARED / inner
        elif inner == "SKILL.md":
            continue
        else:
            mirror = CODEX_SKILL_ROOT / owner / inner
        if not mirror.is_file():
            fail(f"byte fidelity: missing generated copy for {path}")
        elif mirror.read_bytes() != (REPO / path).read_bytes():
            fail(f"byte fidelity: {mirror.relative_to(REPO)} differs from {path}")

    helpers = git_files(".claude/scripts/**")
    for path in helpers:
        mirror = CODEX_SCRIPT_ROOT / Path(path).name
        if not mirror.is_file():
            fail(f"helper mirror: missing {mirror.relative_to(REPO)}")
        elif mirror.read_bytes() != (REPO / path).read_bytes():
            fail(f"helper mirror: {mirror.relative_to(REPO)} differs from {path}")
    notes.append(f"helpers_mirrored={len(helpers)}")


def check_manifest() -> None:
    if not MANIFEST.is_file():
        fail("manifest: codex/generation-manifest.json is missing")
        return
    document = json.loads(MANIFEST.read_text())
    declared = {entry["path"]: entry for entry in document["files"]}
    protected = set(document["protected"])

    for path, entry in sorted(declared.items()):
        target = REPO / path
        if not target.is_file():
            fail(f"manifest: declared file missing on disk: {path}")
            continue
        if sha256(target) != entry["sha256"]:
            fail(f"manifest: digest drift, regenerate: {path}")

    on_disk = {
        p.relative_to(REPO).as_posix()
        for p in (REPO / ".agents").rglob("*")
        if p.is_file()
    }
    unmanaged = sorted(on_disk - set(declared) - protected)
    if unmanaged:
        fail(f"manifest: unmanaged files under .agents/: {unmanaged}")

    for path in sorted(protected):
        if not (REPO / path).is_file():
            fail(f"manifest: protected hand-authored file missing: {path}")
    notes.append(f"manifest_files={len(declared)} protected={len(protected)}")


def check_references() -> None:
    """Reference integrity is differential.

    Canonical protocols address each other with skill-root-relative prose
    (`refs/build/protocol.md`), so some references only resolve from the
    consumer's directory and some are prose that never resolved. The mirror is
    correct when it resolves *exactly the same set* the canonical tree resolves:
    it may not break a working link and may not invent one. Hand-authored Codex
    files have no canonical counterpart and must resolve fully.
    """

    def resolve(path: Path, root: Path, candidate: str) -> bool:
        base = path.parent
        while True:
            if (base / candidate).exists():
                return True
            if base == root:
                return False
            base = base.parent

    def references(path: Path) -> list[str]:
        prose = SKIP_FENCED.sub("", path.read_text(errors="replace"))
        return sorted(set(SKILL_REF.findall(prose)))

    checked = 0
    differential = 0
    standalone = 0
    for path in sorted((REPO / ".agents").rglob("*.md")):
        relative = path.relative_to(CODEX_SKILL_ROOT).as_posix()
        if relative.endswith("/CLAUDE-SKILL.md"):
            # the canonical payload mirrors the canonical entry point
            canonical = CANONICAL_SKILL_ROOT / relative[: -len("CLAUDE-SKILL.md")] / "SKILL.md"
        elif relative.endswith("/SKILL.md"):
            # the generated thin adapter has no canonical counterpart
            canonical = CANONICAL_SKILL_ROOT / "__generated_adapter__"
        else:
            canonical = CANONICAL_SKILL_ROOT / relative
        codex_refs = references(path)
        checked += len(codex_refs)

        if canonical.is_file():
            differential += 1
            canonical_refs = references(canonical)
            if codex_refs != canonical_refs:
                fail(
                    f"reference: {path.relative_to(REPO)} reference set differs from "
                    f"{canonical.relative_to(REPO)}"
                )
                continue
            for candidate in codex_refs:
                mirrored = resolve(path, CODEX_SKILL_ROOT, candidate)
                original = resolve(canonical, CANONICAL_SKILL_ROOT, candidate)
                if mirrored != original:
                    fail(
                        f"reference: {candidate!r} resolves={original} canonically but "
                        f"{mirrored} in {path.relative_to(REPO)}"
                    )
        else:
            standalone += 1
            for candidate in codex_refs:
                if not resolve(path, CODEX_SKILL_ROOT, candidate):
                    fail(f"reference: unresolved {candidate!r} in {path.relative_to(REPO)}")
    notes.append(
        f"references_checked={checked} mirrored_files={differential} codex_only_files={standalone}"
    )


def check_claude_isolation() -> None:
    result = subprocess.run(
        ["git", "status", "--porcelain", "--", ".claude", "install.sh", "package.json"],
        cwd=REPO,
        check=True,
        capture_output=True,
        text=True,
    )
    dirty = [line for line in result.stdout.splitlines() if line.strip()]
    if dirty:
        fail(f"claude isolation: protected paths were modified: {dirty}")


SKIP_FENCED = re.compile(r"```.*?```", re.DOTALL)


def main() -> int:
    skills = check_discovery()
    if len(skills) == EXPECTED_SKILLS:
        check_adapters(skills)
        check_byte_fidelity(skills)
    check_manifest()
    check_references()
    check_claude_isolation()

    if failures:
        for failure in failures:
            print(f"FAIL {failure}")
        print(f"CODEX_COMPAT fail={len(failures)}")
        return 1
    print(f"SKILLS_DISCOVERED {len(skills)}")
    print("BIJECTION_OK")
    print("ADAPTER_SHAPE_OK")
    print("BYTE_FIDELITY_OK")
    print("MANIFEST_OK " + " ".join(notes))
    print("LINKS_OK")
    print("CLAUDE_ISOLATION_OK")
    print("CODEX_COMPAT pass")
    return 0


if __name__ == "__main__":
    sys.exit(main())
