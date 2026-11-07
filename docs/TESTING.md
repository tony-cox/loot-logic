# LootLogic: in-game test checklists

One checklist per milestone, run on a live Forever client after installing that milestone's build, with the rule that says when the milestone passes. Spec section 19 points here from the "Done when" of each milestone that has a section below. The offline tests are in `docs/technical-findings.md` section 17.1, and the live checks (L1 to L64) in its section 18.

---

## M1: Probe and tooltip

### Pass rule

- **Live checks.** Every live check that spec section 19 lists for M1 passes. A check that fails does not block M1 when the fallback in its "If wrong" column (technical findings 18) is built. It blocks M1 only when it has no fallback that can be built.
- **Correct tooltips.** For each item checked, the tooltip's category and reason are the ones the team would choose by hand from the rules in the spec (sections 7 and 8). Each disagreement is logged as a bug or as a rule change.
- **Enough trips.** Three town trips on each of the four test characters (Druid Bear, Shaman Enhancement, Paladin Protection and Warlock Affliction, spec 8.2). Together the trips cover at least one item in each of Equip, another character's category, AH, Vendor and Vendor/AH.

### Checklist

1. Type `/ll probe`. Each automatic check prints PASS, FAIL or SKIP with its value, and the manual ones are listed.
2. Run each manual check listed for M1 by hand, as technical findings 18 describes it, and note the result.
3. For each check that failed, note whether its fallback is built. A failed check with no fallback that can be built stops M1.
4. On each test character, do three town trips. Before selling, listing or mailing, hover the items in the bags: each tooltip line should show the category and reason the rules give. Log each disagreement as a bug or a rule change.
5. Check that the trips together showed at least one item in Equip, one in another character's category, one in AH, one in Vendor and one in Vendor/AH. Until each has shown, the trips are not enough.
6. On the Druid, create Bear and Restoration loadouts; on the Paladin, create Protection and Retribution loadouts. Switch the worn loadout and check that gear best for the other loadout stays protected, and that the tooltip names the loadout and comparison that explain the result.
7. Before moving to M2, choose each test character's spec with `/ll loadout` (L54).

## M2: linked-set selection check

Run L64 for Equipment Manager and Outfitter. For each source whose signal is reliable, equip each of two linked sets and verify its loadout becomes worn; change an individual piece and equip an unlinked set, verifying the selection stays. Verify one loadout can link to multiple sets, that a set cannot link to a second loadout, and that an unlinked loadout still gives gear advice and can be selected manually. For a source without a reliable signal, verify manual selection remains available.
