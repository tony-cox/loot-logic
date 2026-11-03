# Agent setup smoke test

Run these checks separately in Claude Code and Codex from the repository root. Use a fresh session after regenerating agent files. Keep the results in an unused `.work/agent-smoke-<tool>-<label>.md`. Do not use a smoke test as a milestone review or a consistency pass.

## Static checks

1. Record the tool version, model if exposed, branch, full commit id (`git rev-parse HEAD`) and working diff (`git status --short` and `git diff`). Record any pre-existing untracked files too. Before launch checks, record the existing `.work/` filenames and content hashes so changes to ignored artifacts can also be detected.
2. Run `python agents/build.py --check`. All ten generated files must match their sources.
3. With Python 3.11 or later, parse the Codex files:

   ```powershell
   python -c "import pathlib,tomllib; files=list(pathlib.Path('.codex/agents').glob('*.toml')); [tomllib.loads(p.read_text(encoding='utf-8')) for p in files]; print(str(len(files))+' TOML files parse')"
   ```

4. Confirm that the tool lists `buildability`, `planner`, `implementer`, `code-reviewer` and `consistency` as available custom agents. A file existing on disk does not prove discovery. In Claude Code, use `/agents`; in Codex, ask the session to list available custom agent roles without launching any.
5. Confirm the shared project instructions are loaded. In Claude Code, inspect `/context` for `CLAUDE.md` and its `AGENTS.md` import. In Codex, ask the session to identify the loaded repository instructions and the rule forbidding writes to `master`.

## Runtime checks

1. Ask explicitly: `Spawn the planner agent with no scope. This is a setup smoke test; pass no milestone, section, files or plan stage to it. Wait for its reply.` It must ask for scope and stop, without writing a plan or changing project files. Confirm that the launched role is the custom planner.
2. Choose a committed change to `AGENTS.md` or `CLAUDE.md`. Start with `HEAD~1..HEAD`, then run `git diff <base>..<head> -- AGENTS.md CLAUDE.md` and confirm it contains changes. If it is empty, choose an earlier range containing an instruction-file change. Resolve both endpoints to full commit ids with `git rev-parse` and record them. If no suitable history is available, mark this check pending; an empty diff cannot pass it. Use those ids and an unused label in this prompt: `Spawn the consistency agent in changes mode on commit range <base-id>..<head-id>, limited to changes in AGENTS.md and CLAUDE.md and anything those changes could contradict. Confirm the instruction-file diff is non-empty before reviewing. Write the findings only to .work/agent-smoke-<tool>-<label>-findings.md. This is an isolated first pass with no prior findings or handoff. Wait for its reply. Do not fix anything, commit or post anywhere.` The log must identify the range, quote at least one changed instruction and identify the related text checked against it, give evidence for any findings and finish with totals. Findings need not be zero for the launch check to pass.
3. Compare project files and git status with the baseline. Only the named findings log may have been created or changed. Check ignored artifacts separately because `git status` does not show `.work/` files. Record the role launched, output paths, results and unexpected changes.

## Pass rule

Report static checks and runtime checks separately for each tool. Runtime support passes only when all five roles are discovered, shared instructions are loaded, and both launch checks behave as specified. Mark unavailable or unrun checks as pending with the reason. Prompt compliance in these checks does not establish enforced write isolation.
