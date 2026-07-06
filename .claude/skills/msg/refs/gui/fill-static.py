#!/usr/bin/env python3
"""msg --gui · static-fallback template fill.

Performs the three placeholder substitutions that protocol-gui.md Step 4 used to
do by hand (Read index.html + styles.css, splice, Write). It is the read-only
counterpart of server.py's `fill_template()` and produces byte-identical output
to the manual splice:

  __STYLES__     <- contents of styles.css              (verbatim, once)
  __PRD_DATA__   <- the Step-3 data-contract JSON        (validated, once)
  __API_TOKEN__  <- the write token (empty in static mode = editing UI stays off)

The `__DEFAULT_VIEW__` placeholder is intentionally left untouched in static mode:
index.html's boot JS falls back to "board" when it still sees the raw placeholder.
Pass --default-view to override it (e.g. "roadmap").

The PRD-DATA JSON is parsed (to guarantee it is valid), re-serialized compactly,
and `</` is escaped to `<\\/` — exactly as server.py does — so the inline
`<script type="application/json">` payload can never break out of its tag.

Usage:
  fill-static.py --data DATA.json --out OUT.html [--template index.html]
                 [--styles styles.css] [--api-token TOKEN]
                 [--default-view board|roadmap]

  DATA may be a file path or "-" to read the JSON from stdin.

Exit: 0 on success; non-zero with a message on stderr on any error.
Stdlib only. Python 3.9+.
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def read_text(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def load_data_json(source):
    """Read the data contract from a file path or stdin ('-'), validate it, and
    return the compact, script-tag-safe JSON string to embed."""
    raw = sys.stdin.read() if source == "-" else read_text(source)
    obj = json.loads(raw)  # raises on invalid JSON — surfaced as an error below
    return json.dumps(obj).replace("</", "<\\/")


def fill(template, styles, data_json, api_token, default_view):
    html = template.replace("__STYLES__", styles, 1)
    html = html.replace("__PRD_DATA__", data_json, 1)
    html = html.replace("__API_TOKEN__", api_token, 1)
    if default_view is not None:
        html = html.replace("__DEFAULT_VIEW__", default_view, 1)
    return html


def main():
    ap = argparse.ArgumentParser(description="Fill the msg --gui static template.")
    ap.add_argument("--data", "-d", required=True,
                    help="Step-3 data-contract JSON: a file path, or '-' for stdin")
    ap.add_argument("--out", "-o", required=True, help="output HTML file to write")
    ap.add_argument("--template", default=os.path.join(HERE, "index.html"),
                    help="index.html template (default: sibling index.html)")
    ap.add_argument("--styles", default=os.path.join(HERE, "styles.css"),
                    help="styles.css source (default: sibling styles.css)")
    ap.add_argument("--api-token", default="",
                    help="X-Msg-Token value; empty (default) keeps the board read-only")
    ap.add_argument("--default-view", default=None, choices=("board", "roadmap"),
                    help="initial tab; omit to leave __DEFAULT_VIEW__ for the JS 'board' fallback")
    args = ap.parse_args()

    try:
        template = read_text(args.template)
        styles = read_text(args.styles)
        data_json = load_data_json(args.data)
    except FileNotFoundError as e:
        sys.exit("fill-static: file not found: %s" % e.filename)
    except json.JSONDecodeError as e:
        sys.exit("fill-static: --data is not valid JSON: %s" % e)
    except OSError as e:
        sys.exit("fill-static: %s" % e)

    html = fill(template, styles, data_json, args.api_token, args.default_view)

    try:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(html)
    except OSError as e:
        sys.exit("fill-static: cannot write %s: %s" % (args.out, e))

    print(args.out)


if __name__ == "__main__":
    main()
