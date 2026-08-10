#!/usr/bin/env python3
"""Normalize a runtime trace so Claude and Codex runs can be compared.

Plan §8 layer 4: parity is judged on state transitions, command intent and order,
gate sequence, subagent ownership and terminal category — never on model prose or
host-specific chrome. This filter turns a raw event stream into that comparable
form.

Input: Codex `codex exec --json` JSONL on stdin, or msg's own `KEY=value` trace
lines. Output: one normalized semantic event per line.

Normalization rules:

* `/skill` and `$skill` both become `skill`
* tool and item names become semantic operations: read, edit, shell, ask, spawn,
  wait, message
* absolute home paths become `<AGENT_HOME>`, the working repo becomes `<REPO>`
* timestamps, run ids, thread ids, PIDs and token counts are dropped
* model-authored prose is reduced to its terminal category when one is declared
  (`refusal`, `verdict`, `handoff`), otherwise to `message`

Usage: normalize-trace.py [--home <path>] [--repo <path>] < trace
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

SKILLS = (
    "msg", "intake", "plan-pm", "plan-review", "plan-em",
    "eng", "pre-merge", "merge", "emulate",
)
INVOCATION = re.compile(r"(?<![\w/.\-])[/$](" + "|".join(sorted(SKILLS, key=len, reverse=True)) + r")(?![\w/.\-])")
TIMESTAMP = re.compile(r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?")
IDENTIFIER = re.compile(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b")

SEMANTIC = {
    "command_execution": "shell",
    "file_change": "edit",
    "patch_apply": "edit",
    "agent_message": "message",
    "reasoning": None,          # hidden reasoning is never graded
    "error": "error",
    "todo_list": None,
    "web_search": "web",
    "mcp_tool_call": "tool",
}

READ_COMMAND = re.compile(r"^\s*(?:/bin/(?:ba|z)?sh\s+-l?c\s+)?[\"']?(?:sed -n|cat|head|tail|rg|grep|ls)\b")


def scrub(text: str, home: str, repo: str) -> str:
    text = text.replace(repo, "<REPO>") if repo else text
    text = text.replace(home, "<AGENT_HOME>") if home else text
    text = TIMESTAMP.sub("<TS>", text)
    text = IDENTIFIER.sub("<ID>", text)
    text = INVOCATION.sub(r"\1", text)
    return " ".join(text.split())


def emit(kind: str, detail: str) -> None:
    print(f"{kind} {detail}".rstrip())


def handle_codex_event(event: dict, home: str, repo: str) -> None:
    if event.get("type") != "item.completed":
        return
    item = event.get("item", {})
    kind = SEMANTIC.get(item.get("type"), "message")
    if kind is None:
        return
    if kind == "shell":
        command = scrub(item.get("command", ""), home, repo)
        emit("read" if READ_COMMAND.match(command) else "shell", command)
        return
    if kind == "message":
        emit("message", scrub(item.get("text", ""), home, repo)[:200])
        return
    emit(kind, scrub(json.dumps(item, sort_keys=True), home, repo)[:200])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", default=os.environ.get("HOME", ""))
    parser.add_argument("--repo", default=os.environ.get("REPO", ""))
    args = parser.parse_args()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        if line.startswith("{"):
            try:
                handle_codex_event(json.loads(line), args.home, args.repo)
                continue
            except json.JSONDecodeError:
                pass
        if "=" in line and line.split("=", 1)[0].isupper():
            key, _, value = line.partition("=")
            emit(key.lower(), scrub(value, args.home, args.repo))
            continue
        emit("message", scrub(line, args.home, args.repo)[:200])
    return 0


if __name__ == "__main__":
    sys.exit(main())
