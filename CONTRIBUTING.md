# Contributing to LootLogic

## Writing docs and code comments

These rules apply to the docs and to comments in code.

- Write as a team project: no personal names, no pronouns for individuals. Use "the player", "the team", "agreed", "the example account".
- No em dashes. Use a colon, comma, parentheses or a new sentence.
- Mark anything not observed on a live client with its confidence label, and add a live check (technical findings section 18) when a claim needs one.
- Keep what separate from how. The spec says what LootLogic needs and does; where the game or another addon supplies a fact, the call that reads it and the evidence belong in `docs/technical-findings.md` under the same section number. Write the spec for a reader who does not know where in the game information comes from and so cannot check a "how we get it" statement.
- The spec describes version 1 as the product. Later versions go in its last sections, each pointing back to the sections it changes.

## Researching other addons

Looking at other addons is welcome. The rules are:

- Reading any addon's code is allowed whatever its licence when it is to learn its public API and behaviour for integration, to learn which APIs, events and constants exist on the Forever client, or to design a proposed upstream API. Record it where the work is documented and copy nothing. Check the licence first for anything else.
- Code is only copied from open source repositories, under their licence. This project is MIT, so GPL and other copyleft code is never copied, translated or closely paraphrased. Permissive code (MIT, BSD, Apache-2.0) may be used with its notice kept and attribution given.
- Where code or logic is replicated from open source, name the source and its licence where it is used (a code comment beside it, or the specification or design note it appears in), and in a credits or notices file.
- Code and data with no licence, or "All Rights Reserved", are never copied or paraphrased, only called through their public APIs.
- Record what each piece of researched material is and its licence where the project documents its sources.
