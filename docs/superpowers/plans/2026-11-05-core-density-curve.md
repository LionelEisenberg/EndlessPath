# Foundation's Core Density curve retune: implementation plan

Stats rework chunk #96, tracked in #85. Design: the spec's Phase 4 (`docs/superpowers/specs/2026-11-04-stats-rework-design.md`), its "Levels, XP and the cap" and "Left to the builder" sections, and the master plan's Task 4.3 (`docs/superpowers/plans/2026-11-04-stats-rework.md`).

**Goal:** filling the core in Foundation takes about 8 Shallow Woods runs as played, with no new maps.

## Answers (Lionel, on #96)

1. **Runs as played, not full clears.** Early runs win only 1, 2, maybe 3 fights before the player gets stronger, so the curve is tuned to a run model that grows from 2 regular kills up to full clears.
2. **No load rule for old saves.** Old saves' compatibility isn't a concern: `CultivationManager`'s load step doesn't change, and a saved Core Density XP figure is read at the new costs as it is. The bar of a Foundation save below 100 may read over-full until its next kill levels it up.
3. **The kill amounts may move.** They don't need to: 20 / 50 / 120 fit the run model, so the encounter files stay untouched.

## The curve

`foundation_advancement_stage.tres`, every value written out:

- `core_density_base_xp_cost = 4.0` (level 1 costs 4 XP)
- `core_xp_scaling_factor = 1.027` (each level 2.7% more than the last; level 100 costs 55.9)
- `max_core_density_level = 100`

A full core costs 1,978.7 XP, against 3,122 today. On today's curve (10 XP for level 1, ×1.02) a 2-kill first run pays 3 levels and the run model fills the core in 10 to 11 runs. Cheap early levels make the small early runs count, and the 2.7% rise slows the late runs, where a full clear pays 460.

Copper's curve stays (Copper has no content).

## The arithmetic

A full clear is 7 regular, 4 elite and 1 boss fight: 7 × 20 + 4 × 50 + 120 = 460.

Runs as played (regular / elite / boss wins):

| Run | Wins | Pays | Total | Core Density after |
|---|---|---|---|---|
| 1 | 2 / 0 / 0 | 40 | 40 | 8 |
| 2 | 3 / 0 / 0 | 60 | 100 | 19 |
| 3 | 4 / 1 / 0 | 130 | 230 | 35 |
| 4 | 5 / 2 / 0 | 200 | 430 | 51 |
| 5 | 7 / 3 / 0 | 290 | 720 | 66 |
| 6 | 7 / 4 / 0 | 340 | 1,060 | 78 |
| 7 | 7 / 4 / 1 | 460 | 1,520 | 90 |
| 8 | 7 / 4 / 1 | 460 | 1,980 | 100 |

Full clears from the first run: 53, 74, 87, 97, then 100 on the 5th.

- **Runs to a full core:** 8 as played; 5 full clears.
- **CD 10** (the first path point and `q_reach_cd_10`): 45 XP, in the second run.
- **A failed Tribulation:** levels 96 to 100 cost 265 XP, about 6 regular kills, or 58% of a full clear. One run wins them back.
- **Spirit:** #91 recorded Lv 1 to 10 Spirit at 2,579 XP, 215 / 86 / 162 fully followed cycles, about 22 to 29 minutes. Eight runs of up to 300 s each, with cycling between them to refill Madra (Madra being the one pool after #89), put the full core at roughly 30 to 45 minutes, in the same window. #111 checks the joint timing end to end.

## Tasks

1. **The curve.** Write the three values in `foundation_advancement_stage.tres`. Give `AdvancementStageResource.get_xp_for_level()` its `##` doc comment (the cost of one level, not the total to reach it).
2. **Tests.** Drop `test_cultivation_getters.gd`'s `test_xp_for_level_follows_the_stages_curve` with its section and its line in the header comment: no test pins shipped tuning ("What to test" in `docs/testing/TESTING.md`). `test_cultivation_manager.gd`'s `test_xp_for_level_follows_base_times_scaling` keeps covering the formula. Run `tests/run_tests.ps1` and fix any test that leaned on the real curve's numbers by giving it its own fixture.
   - **Built:** seven files leaned on it (the adventure end flow, tilemap events, cultivator plate, cycling technique, kill beads, the run cabinet's core row and the Core Density effect). A new helper, `tests/helpers/core_curve.gd` (`CoreCurve.use_fixed_curve()` / `restore()`), swaps in copies of the real stages whose Foundation runs on a fixed 10 × 1.02 curve, so their figures stay as written and no longer move with tuning.
3. **Check in the game** on the chunk's own save (`-- --preset=adventure_open --save=user://dev/runs/core-density-curve.tres`): Core Density after each run lands near the table, refilling Madra with the dev panel between runs, since cycling's presses pay Core Density until #99.
4. **PR** closing #96 with the arithmetic and `## Docs to update`.

## Save

No new field and no version step. A saved Core Density XP figure means XP toward the next level at the new costs (#85's "Saved values that change meaning"); with no load rule, a save holding more than its next level's new cost levels up at its next award.
