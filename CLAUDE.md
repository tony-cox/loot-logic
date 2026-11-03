# LootLogic: working notes for Claude

@AGENTS.md

The project rules, the document map, the decisions workflow and the build workflow are in `AGENTS.md`, which every coding tool shares. Keep this file for anything only Claude Code needs.

The agents in `.claude/agents/` are generated from `agents/src/` (see "One definition, two tools" in `AGENTS.md`). Edit the source, run `python agents/build.py`, and never edit the generated file.
