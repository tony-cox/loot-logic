#!/usr/bin/env python3
"""Generate the Claude Code and Codex agent files from the shared sources.

Sources live in agents/src/<name>.md: a small frontmatter block (name,
description, access) and the agent's instructions. The generated files are

  .claude/agents/<name>.md    Claude Code subagents (markdown, YAML frontmatter)
  .codex/agents/<name>.toml   Codex custom agents (TOML)

Both outputs are committed. Never edit them by hand; edit the source and rerun.

  python agents/build.py           write the generated files
  python agents/build.py --check   exit 1 if any generated file is stale or stray
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "agents" / "src"
CLAUDE_OUT = ROOT / ".claude" / "agents"
CODEX_OUT = ROOT / ".codex" / "agents"

# access value -> Claude Code tool allowlist. This limits which tools exist, not
# which paths they write: Write and Bash can still touch any file, so log-only
# is held by each source's Constraints section. Codex has no per-agent tool list
# and its agent files cannot set a sandbox, so it relies on the instructions too.
CLAUDE_TOOLS = {
    "log-only": "Read, Grep, Glob, Bash, Write",
    "edit": "Read, Grep, Glob, Bash, Write, Edit",
}

GENERATED = "Generated from agents/src/{name}.md by agents/build.py. Do not edit."


def parse(path):
    """Return (meta, body) for a source file."""
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    if not text.startswith("---\n"):
        raise SystemExit(f"{path}: missing frontmatter")
    head, sep, body = text[4:].partition("\n---\n")
    if not sep:
        raise SystemExit(f"{path}: unterminated frontmatter")
    meta = {}
    for line in head.splitlines():
        key, colon, value = line.partition(": ")
        if not colon:
            raise SystemExit(f"{path}: bad frontmatter line: {line!r}")
        meta[key.strip()] = value.strip()
    for key in ("name", "description", "access"):
        if not meta.get(key):
            raise SystemExit(f"{path}: frontmatter lacks {key}")
    if meta["name"] != path.stem:
        raise SystemExit(f"{path}: name {meta['name']!r} differs from the file name")
    if meta["access"] not in CLAUDE_TOOLS:
        raise SystemExit(f"{path}: unknown access {meta['access']!r}")
    return meta, body.strip("\n") + "\n"


def yaml_scalar(text):
    """A one-line YAML value, double-quoted only when plain style would misparse."""
    if ": " in text or " #" in text:
        return json.dumps(text, ensure_ascii=False)
    return text


def claude_file(meta, body):
    return (
        "---\n"
        f"name: {meta['name']}\n"
        f"# {GENERATED.format(name=meta['name'])}\n"
        f"description: {yaml_scalar(meta['description'])}\n"
        f"tools: {CLAUDE_TOOLS[meta['access']]}\n"
        "---\n\n"
        f"{body}"
    )


def codex_file(meta, body):
    if "'''" in body:
        raise SystemExit(f"{meta['name']}: body contains ''' which TOML literal strings cannot hold")
    return (
        f"# {GENERATED.format(name=meta['name'])}\n"
        f"name = {json.dumps(meta['name'])}\n"
        f"description = {json.dumps(meta['description'], ensure_ascii=False)}\n"
        f"developer_instructions = '''\n{body}'''\n"
    )


def expected():
    """Map each generated path to its content."""
    files = {}
    for path in sorted(SRC.glob("*.md")):
        meta, body = parse(path)
        files[CLAUDE_OUT / f"{meta['name']}.md"] = claude_file(meta, body)
        files[CODEX_OUT / f"{meta['name']}.toml"] = codex_file(meta, body)
    return files


def read(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def main(argv):
    check = "--check" in argv
    files = expected()
    problems = []

    for path, content in files.items():
        if not path.exists() or read(path) != content:
            problems.append(f"stale or missing: {path.relative_to(ROOT)}")
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8", newline="\n")

    # A generated folder may hold only generated files.
    for folder, pattern in ((CLAUDE_OUT, "*.md"), (CODEX_OUT, "*.toml")):
        for path in sorted(folder.glob(pattern)):
            if path not in files:
                problems.append(f"stray (no source): {path.relative_to(ROOT)}")

    if check:
        for line in problems:
            print(line)
        if problems:
            print("Run: python agents/build.py")
            return 1
        print(f"{len(files)} generated files match agents/src")
        return 0

    for line in problems:
        print(line.replace("stale or missing", "wrote"))
    strays = [line for line in problems if line.startswith("stray")]
    if strays:
        print("Delete the stray files by hand (or add the missing source).")
        return 1
    print(f"{len(files)} generated files up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
