# LootLogic: working notes for Claude

The repo for LootLogic, a WoW: Forever addon. It holds the spec and design docs and the addon code (`LootLogic/`, with offline tests in `tests/`); we are partway through milestone M0 of M0 to M4. Nothing has run on a live client yet (it arrives 2026-11-05), and the project is private until the addon is well tested. See `README.md` for the overview.

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

## Git

- Never merge a PR, push to `master`, or rewrite history on `master`. Every write to `master` is made by a human.

## Consistency check

- Before any commit that could leave the docs, or the code and the spec, out of sync, ask the user whether to run the `consistency` agent first (`changes` mode suits a single commit). Commit only after they answer.
- The `buildability` agent checks whether a spec scope (a milestone or a section) can be built without guessing. Run it on request or before starting a milestone, not before every commit.

## Build agents

- `planner` turns a named stage of the spec into an ordered plan in `.work/` (read-only; lists questions for the owner instead of deciding them).
- `implementer` writes the code and offline tests for one plan stage, runs the tools, and stops on anything the docs leave open. It does not commit unless told to.
- `code-reviewer` reviews a diff, range or PR against the spec, style guide and rules, including code comments, and logs findings to `.work/` (read-only).
- `buildability` and `consistency` are as above.

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

When the owner asks "what's next", find the position from the latest plan in `.work/`, the open and merged PRs and the branches, and answer with the next step above.
