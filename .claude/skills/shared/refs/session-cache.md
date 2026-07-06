---
name: session-cache
description: Hash-keyed session cache convention for msg. Derived artifacts (PRD digest, devkit digest, verify prelude) are cached under .claude/msg/cache/ and regenerated only when their source changes. Source is always canonical; the cache is disposable.
---

# Session cache convention

msg skills that derive a compact artifact from larger source files (PRD digest,
devkit digest, verify prelude) cache the result so downstream stages reuse it
instead of recomputing. The rule set below is shared by every cached artifact.

## Location & naming

- Cache root: `.claude/msg/cache/` (gitignored — local, disposable).
- One file per artifact, named for what it derives, e.g.
  `prd-<slug>.digest.json`, `devkit.digest.json`, `verify-prelude.json`.

## The contract (every cached artifact obeys these)

1. **Source is canonical.** The prose/source files are the truth. The cache is a
   derived projection — never edited by hand, never the source of a decision the
   source can't back.
2. **Hash key.** Each artifact records `source_hash` = a hash of the exact source
   file(s) it derives from (concatenated content, or per-file map). For the
   verify prelude, the key also includes the current `HEAD` and diff range.
3. **Staleness = mismatch.** Before consuming, a stage recomputes the source hash
   and compares. **Match → cache hit** (use it). **Mismatch or missing → regenerate**
   (run the generator, overwrite the cache), then consume.
4. **Never a hard failure.** A missing, corrupt, or unparseable cache is not an
   error — the consumer falls back to reading the source directly (full prose /
   live detection) and, where cheap, regenerates the cache for next time.
5. **Generators are deterministic and LLM-free.** Digests/preludes are produced by
   scripts (parsing, hashing, tool detection), not model calls, so a cache hit
   costs ~0 tokens and a miss costs one script run.
6. **Escape hatch.** Every digest entry that omits prose keeps a pointer
   (`prose_lines`, source path) so a consumer needing more can read exactly that
   slice rather than the whole source.

## Consumer pattern (pseudocode)

```
art = read_json(cache_path)                     # may be absent
if art is None or art.source_hash != hash(sources):
    art = run_generator(sources)                # deterministic script
    write_json(cache_path, art)                 # best-effort; ignore write errors
use(art)                                         # or fall back to sources on parse error
```

## Consumers
- **PRD digest** — `scan-prd-digest.py` → `prd-<slug>.digest.json`. See each
  planning/verify stage's read step.
- **devkit digest** — `scan-devkit-digest.py` → `devkit.digest.json`.
- **verify prelude** — diff-resolve + tooling-detect + eval-bootstrap →
  `verify-prelude.json`, consumed by review/test/pre-merge.
