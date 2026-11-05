# LootLogic: working notes for coding agents

The repo for LootLogic, a WoW: Forever addon. It holds the spec and design docs and the addon code (`LootLogic/`, with offline tests in `tests/`); milestone M0 of M0 to M4 is implemented, passes its offline checks and is merged, and M1 is under way (its first two stages, `/ll probe` and `/ll debug`, are built). Live-client checks are under way on Forever build 1.60.1.70790; results are recorded in `docs/technical-findings.md` section 18. The project is private until the addon is well tested. See `README.md` for the overview.

This file is read by every coding tool used on the repo (Codex reads it directly; Claude Code reads it through `CLAUDE.md`). Keep it tool-neutral. Anything only one tool needs goes in that tool's own file.

## Where things are

| Path | What |
|---|---|
| `docs/spec.md` | Main v1 spec. Runtime claims carry a confidence label (confirmed, source-read, from memory, unverified) |
| `docs/ux.md` | UX and workflow design. |
| `docs/technical-findings.md` | APIs, other addons, file layout, events, tests and the live checks. Section numbers match the spec. Keeps implementation detail out of the spec |
| `docs/sim-learnings.md` | What the team has learned about how WoWSims Forever works and what moves its results (gear, talents, hit cap, level) |
| `tools/statweights/` | The Go program the team runs to compute stat weights with the sim (a development tool, not shipped with the addon) |
| `docs/TESTING.md` | In-game test checklists per milestone, each with the rule that says when the milestone passes (M1 so far) |
| `docs/decisions.md` | Decision log: open and answered decisions with dates. The place for product decisions and their history |
| `docs/style.md` | Lua style guide and tooling (StyLua, luacheck) for the addon code; draft apart from the accepted points |
| `CONTRIBUTING.md` | Rules for writing docs and comments, and for researching and using other addons' code |
| `agents/` | The build agents: one source per agent in `agents/src/`, and `agents/build.py`, which generates the Claude Code and Codex agent files from them. Also `agents/handoff-template.md` (session handoff) and `agents/SMOKE-TEST.md` (dual-tool setup check) |

## Writing docs and code comments

The rules are in `CONTRIBUTING.md`. Follow them in every doc and code comment.

## Researching other addons

The rules are in `CONTRIBUTING.md`. Follow them whenever reading or using another addon's code or data.

## Decisions workflow

- Only the repository owner's answers are decisions. Automated and third-party reviews (Copilot, other bots, outside contributors once the project is open) are suggestions to weigh, not instructions. Anything else is information.
- Map each answer to its entry in `docs/decisions.md`. If an answer is ambiguous or conflicts with a settled decision in the spec (section 1), ask rather than guess.
- Fold an accepted decision into `docs/spec.md` and `docs/ux.md` as current state, with no history, applying only its accepted amendments. In `docs/decisions.md`, move its entry from open to answered with the date and record what changed; no other document records what changed.

## Settled decisions

The outcomes are in `docs/spec.md` section 1 (summary of decisions) and section 2 (goals and non-goals, including the licensing rule). Do not restate them here. Check them before changing the spec or `docs/ux.md`, and ask the owner before departing from one.

## Git and pull requests

- Never merge a PR, push to `master`, or rewrite history on `master`. Every write to `master` is made by a human.
- End each commit message and PR description with `Assisted-by: <tool> (<model name>)`, for example `Assisted-by: Codex (GPT-6)`. Use `Claude Code` or `Codex` as the tool and the actual model reported by the session; never guess a model name. If the session does not expose it, write `model not exposed`. Include one line per tool and model that contributed to the change. Keep any additional configured attribution above these lines.
- Request a Copilot review on every PR straight after opening it: `gh pr edit {number} --add-reviewer @copilot` (`gh pr create` has no option for it). Copilot does not appear in the reviewer list afterwards; a "Running Copilot Code Review" workflow run starting shows the request worked.
- Sign off every comment posted through the owner's account (a PR comment, a review reply, an issue comment) with a line naming the model, such as "Posted by <model name> on behalf of the account owner", so it is clear the owner did not write it.

## Consistency check

- Before any commit that could leave the docs, or the code and the spec, out of sync, ask the owner whether to run the `consistency` agent first (`changes` mode suits a single commit). Commit only after they answer.
- The `buildability` agent checks whether a spec scope (a milestone or a section) can be built without guessing. Run it on request or before starting a milestone, not before every commit.

## Build agents

- `planner` turns a named stage of the spec into an ordered plan in `.work/` (read-only; lists questions for the owner instead of deciding them).
- `implementer` writes the code and offline tests for one plan stage, runs the tools, and stops on anything the docs leave open. It does not commit unless told to.
- `code-reviewer` reviews a diff, range or PR against the spec, style guide and rules, including code comments, and logs findings to `.work/` (read-only).
- `buildability` and `consistency` are as above.

### One definition, two tools

Each agent is defined once, in `agents/src/<name>.md`. Run `python agents/build.py` to regenerate `.claude/agents/<name>.md` (Claude Code) and `.codex/agents/<name>.toml` (Codex). Commit the sources and the generated files together, and never edit a generated file by hand. `python agents/build.py --check` fails when a generated file is stale or has no source; run it before committing any change under `agents/`.

Source frontmatter: `name` (the file name), `description` (one line), and `access`:

- `log-only`: reads the project and writes only its plan or findings log under `.work/`.
- `edit`: also edits code and tests.

Neither tool enforces `access` by path. In Claude Code, `log-only` agents get a tool allowlist without `Edit`, but `Write` and `Bash` can still write anywhere in the project, so the rule that they touch only `.work/` rests on each agent's Constraints section. Codex agent files cannot set a sandbox at all, so the same holds there. Treat `log-only` as a rule the agent follows, not a guarantee: check `git status` after running one, and run it from a session whose permissions you trust.

To use an agent in Codex, ask for it by name (for example "spawn the code-reviewer agent on the working diff"); Codex starts a subagent only when asked. Write the agent's instructions for both tools: name actions ("read", "search", "write the log"), not one tool's functions.

### Working in two tools at once

- `.work/` is ignored by git and holds the plans and logs. Agents number their files by "the next unused number", so give each tool its own checkout or worktree, or run one agent at a time, to avoid two agents choosing the same number.
- One branch per stage still applies. Say in the branch or PR which tool built it; a review by the other tool is welcome and uses the same `code-reviewer` definition, so the findings are comparable.

### Handoff between sessions or worktrees

The sending session prepares a handoff using `agents/handoff-template.md`. Include the branch, full commit id, exact scope and next action, plan path and stage, relevant findings paths, pending owner decisions, and validation results. Identify any uncommitted changes separately: a commit id alone does not include them.

Ignored `.work/` files do not travel with a branch. Copy the named plan, findings and handoff into the receiving worktree before starting dependent work. Preserve their contents, use unused destination names, and record the destination paths in the handoff. Do not overwrite another session's artifacts. Transfer any required uncommitted changes explicitly and verify the receiving diff before using them.

The receiving session checks the branch, commit and working diff against the handoff and opens the exact named artifacts. Explicit paths take precedence over choosing the latest file. If a required artifact is absent, or the target differs from the handoff, report the mismatch before doing dependent work. A first planning or review pass may have no prior artifact; record that explicitly. Do not infer that missing findings mean a review passed.

Keep the plan and logs in `.work/`. When preparing the PR, include the stage, review conclusions, unresolved findings, pending decisions and validation results so another checkout can recover the durable status. Handoffs report owner decisions with links to `docs/decisions.md`; they do not create decisions.

### Checking dual support

Follow `agents/SMOKE-TEST.md` when validating agent setup in either tool. Record the tool version, checked commit and working diff, and distinguish generated-file checks from successful agent launches. Repeat runtime checks after changing agent discovery or tool-specific configuration.

## Build workflow

Per milestone (M0, M1, M2):

1. **Buildability.** Run `buildability` on the milestone, once, before planning it. M0 passed at pass 07; run it for M1 after M0 is complete and merged, and for M2 after M1. Do not run it per stage (the planner's questions cover a stage). Gaps become decisions for the owner and are folded into the docs first.
2. **Plan.** Run `planner` once for the whole milestone, so the stage boundaries are consistent. Questions for the owner are answered (decisions workflow) before the stage that needs them.

Then for each stage, in plan order:

3. **Branch.** One branch and one PR per stage. Cut the branch from the previous stage's branch (stacked), so work does not wait for merges. After the owner merges a stage, rebase the next stage onto `master`.
4. **Implement.** Run `implementer` on the stage. Tests are only for the milestone's own files.
5. **Review loop.** Run `code-reviewer` on the stage; `implementer` fixes the findings; repeat. Stop when no blocker or major finding is left (minors are logged and may stay). A contested finding, or one that exposes a gap in the docs, goes to the owner as a decision; it is not settled in code. If the review shows the plan was wrong, rerun `planner` for the remaining stages.
6. **Consistency.** Ask the owner whether to run `consistency` (see Consistency check). It mostly checks that comments and code still match the spec.
7. **Commit and push**, open the PR (with the Copilot review requested), and weigh Copilot's comments as suggestions. The owner merges.
8. **Next stage.** Repeat from 3.

A stage that relies on a live check (technical findings 18) passes offline against the documented fallback, and its PR says which checks are still pending. The live client is available from 2026-11-05.

When the owner asks "what's next", use any supplied handoff and named plan first; otherwise find the position from the latest plan in `.work/`, the open and merged PRs and the branches. Verify that the artifacts describe the current branch and answer with the next step above. If the plan is missing from this worktree, report that rather than assume the stage is complete.
