#!/usr/bin/env python3
"""
script-policy-set.py — the one writer for `devkit/policy.json`.

Every msg write to the policy file goes through here: the `/msg --init` Step 3
seed, its Step 5 `policies.github_actions` merge, `/msg --update`'s Step 3-CI
and Step 3-TS merges, and `/msg --init-staging`'s release-flow flip. Four call
sites used to hand-author or hand-edit the JSON, each carrying its own
"surgical, byte-identical, only this key" prose and none of them verified.

Schema authority stays `shared/refs/policy-schema.md`; this script implements
it, it does not replace it.

Semantics
  * A `--set a.b.c=<json>` replaces the value at **exactly** that path. Missing
    parent objects are created. Every sibling, at every level, is preserved —
    both its value and (for an already-canonical file) its bytes: the file is
    re-emitted with 2-space indent and insertion order, so an untouched key
    round-trips to the identical line. New keys append to the end of their
    parent object.
  * `--create` seeds an absent file from the schema's seed skeleton
    (`version:1`, `init:false`, `generated`, `generated_by`, `policies:{}`)
    and then applies the `--set` ops on top. Without it, an absent file is a
    named failure — no call site creates the file by accident.
  * `--skip-if-exists` is AC-LC7 in one flag: with `--create`, an existing file
    is left byte-for-byte alone and the run reports `STATUS=skipped-exists`.
  * `--stamp-by <writer>` stamps `generated` (today, `YYYY-MM-DD`, from the
    system clock) and `generated_by`. Scripts *can* stamp the date — the
    protocol's old claim that they can't was the whole reason the seed was
    hand-written.
  * The result is re-read and re-parsed before the run reports success. A
    write that produces unparseable JSON is rolled back to the original bytes.

Usage:
  script-policy-set.py --file <policy.json> [--set <dotted>=<json>]...
                       [--create] [--skip-if-exists]
                       [--stamp-by <writer>] [--dry-run]

  --file            path to devkit/policy.json (required)
  --set             repeatable; value is parsed as JSON, falling back to a
                    bare string when it is not valid JSON
  --create          seed the file from the skeleton when it is absent
  --skip-if-exists  with --create: an existing file is untouched (exit 0)
  --stamp-by        writer name for generated_by, e.g. "msg --init-staging"
  --dry-run         print the resulting document to stdout, write nothing

Output (stdout, key=value lines):
  FILE=<path>
  STATUS=created|updated|skipped-exists|unchanged
  SET=<dotted path>            one line per applied path, in argument order
  STAMPED=<writer>             only when --stamp-by was given
  PRESERVED=<n>                top-level keys carried through untouched
  VERIFIED=true                the written file re-read and re-parsed

Exit codes:
  0  written (or nothing to do)
  1  usage error
  2  file absent and --create not given
  3  existing file is not parseable JSON, or a --set path collides with a
     non-object (e.g. policies.release_flow.mode.x when mode is a string)
  4  write or post-write verification failed (original bytes restored)

Deterministic apart from the `generated` date stamp.
"""
import argparse
import json
import os
import sys
from datetime import date

SELF = "script-policy-set"


def fail(code, slug, detail):
    sys.stderr.write("%s: ERROR=%s detail=%s\n" % (SELF, slug, detail))
    sys.exit(code)


def parse_value(raw):
    """JSON first; a bare unquoted string is accepted as a string."""
    try:
        return json.loads(raw)
    except ValueError:
        return raw


def set_path(doc, dotted, value):
    """Set doc[a][b][c] = value, creating parent objects, touching no sibling."""
    parts = [p for p in dotted.split(".") if p]
    if not parts:
        fail(1, "empty-path", "--set needs a key path")
    node = doc
    walked = []
    for part in parts[:-1]:
        walked.append(part)
        if part not in node:
            node[part] = {}
        elif not isinstance(node[part], dict):
            fail(3, "path-conflict",
                 "%s is not an object (cannot descend for %s)"
                 % (".".join(walked), dotted))
        node = node[part]
    node[parts[-1]] = value


def dump(doc):
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def main():
    ap = argparse.ArgumentParser(add_help=True, prog="script-policy-set.py")
    ap.add_argument("--file", required=True)
    ap.add_argument("--set", action="append", default=[], dest="sets",
                    metavar="DOTTED=JSON")
    ap.add_argument("--create", action="store_true")
    ap.add_argument("--skip-if-exists", action="store_true")
    ap.add_argument("--stamp-by", default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    path = args.file
    exists = os.path.exists(path)
    out = ["FILE=%s" % path]

    if args.skip_if_exists and not args.create:
        fail(1, "bad-usage", "--skip-if-exists requires --create")

    if exists and args.create and args.skip_if_exists:
        print("FILE=%s" % path)
        print("STATUS=skipped-exists")
        print("VERIFIED=true")
        return 0

    original = None
    if exists:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                original = fh.read()
            doc = json.loads(original)
        except ValueError as exc:
            fail(3, "unparseable-policy", "%s: %s" % (path, exc))
        except OSError as exc:
            fail(3, "unreadable-policy", "%s: %s" % (path, exc))
        if not isinstance(doc, dict):
            fail(3, "not-an-object", "%s does not hold a JSON object" % path)
        status = "updated"
    else:
        if not args.create:
            fail(2, "missing-policy",
                 "%s absent — pass --create to seed it" % path)
        if not args.stamp_by:
            fail(1, "bad-usage", "--create requires --stamp-by (provenance)")
        doc = {
            "version": 1,
            "init": False,
            "generated": date.today().isoformat(),
            "generated_by": args.stamp_by,
            "policies": {},
        }
        status = "created"

    before = json.dumps(doc, sort_keys=True)
    top_before = set(doc.keys())

    for item in args.sets:
        if "=" not in item:
            fail(1, "bad-set", "expected DOTTED=JSON, got %r" % item)
        dotted, raw = item.split("=", 1)
        set_path(doc, dotted.strip(), parse_value(raw))
        out.append("SET=%s" % dotted.strip())

    if args.stamp_by:
        doc["generated"] = date.today().isoformat()
        doc["generated_by"] = args.stamp_by

    if status == "updated" and json.dumps(doc, sort_keys=True) == before:
        status = "unchanged"

    touched = {s.split(".", 1)[0] for s in
               (i.split("=", 1)[0].strip() for i in args.sets)}
    if args.stamp_by:
        touched |= {"generated", "generated_by"}
    preserved = len(top_before - touched) if exists else 0

    rendered = dump(doc)

    if args.dry_run:
        sys.stdout.write(rendered)
        out.insert(1, "STATUS=%s (dry-run)" % status)
    else:
        try:
            tmp = path + ".tmp-policy-set"
            parent = os.path.dirname(os.path.abspath(path))
            if not os.path.isdir(parent):
                fail(4, "missing-parent", "%s does not exist" % parent)
            with open(tmp, "w", encoding="utf-8") as fh:
                fh.write(rendered)
            os.replace(tmp, path)
            with open(path, "r", encoding="utf-8") as fh:
                json.loads(fh.read())
        except (OSError, ValueError) as exc:
            if original is not None:
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write(original)
            elif os.path.exists(path):
                os.remove(path)
            fail(4, "write-failed", "%s: %s (original restored)" % (path, exc))
        out.insert(1, "STATUS=%s" % status)

    if args.stamp_by:
        out.append("STAMPED=%s" % args.stamp_by)
    out.append("PRESERVED=%d" % preserved)
    out.append("VERIFIED=true")
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
