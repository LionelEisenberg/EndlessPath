# Foundation's Core Density curve retune: implementation plan

Stats rework chunk #96, tracked in #85. Design: the spec's Phase 4 (`docs/superpowers/specs/2026-11-04-stats-rework-design.md`), its "Levels, XP and the cap" and "Left to the builder" sections, and the master plan's Task 4.3 (`docs/superpowers/plans/2026-11-04-stats-rework.md`).

**Goal:** filling the core in Foundation takes about 8 Shallow Woods runs as played, with no new maps.

## Answers (Lionel, on #96)

1. **Runs as played, not full clears.** Early runs win only 1, 2, maybe 3 fights before the player gets stronger, so the curve is tuned to runs as a growing player plays them.
2. **No load rule for old saves.** Old saves' compatibility isn't a concern: `CultivationManager`'s load step doesn't change, and a saved Core Density XP figure is read at the new costs as it is. The bar of a Foundation save below 100 may read over-full until its next kill levels it up.
3. **The kill amounts may move.** They don't need to: the curve alone reaches the target, so the encounter files stay untouched at 20 / 50 / 120.

## The curve

`foundation_advancement_stage.tres`, every value written out:

- `core_density_base_xp_cost = 5.0` (level 1 costs 5 XP)
- `core_xp_scaling_factor = 1.01` (each level 1% more than the last; level 100 costs 13.4)
- `max_core_density_level = 100`

A full core costs 852 XP, against 3,122 today. XP per run grows about fourfold as the player gets stronger (40 to about 160), and level costs rise about 2.7-fold, so each run pays a similar number of levels, 7 to 19.

Copper's curve stays (Copper has no content).

## How it was tuned: measured runs

A first pass fitted a hand-made run model that grew from 2 regular kills to full clears by run 7 (4 XP, ×1.027, 1,979 XP). A playthrough at ×10 showed that no character reaches full clears on `main` today, so that curve took about 15 runs as played. The curve is now fitted to measured play.

**The playthrough bot** (throwaway, not committed) plays the real main scene at the dev panel's ×10 speed:
- **Walking:** it heads for the nearest revealed regular fight. With none in sight it explores, takes elites after that, and saves the boss for last.
- **Fights:** it presses the strongest ready technique (longest cooldown first), and would drink a healing item below 35% Health (no character had one).
- **Other tiles:** it rests at a rest site below 60% Health and skips dialogue.
- **Between runs:** it refills Madra with `DevCommands.set_madra()`, since cycling's presses still pay Core Density until #99.

XP per run doesn't depend on the curve, so each measurement holds for any curve.

**Core Density XP per run, by character:**

| Character | Fights won a run | XP a run |
|---|---|---|
| Fresh (`adventure_open`: Basic Strike and Enforce, every stat 1) | 2, once 3 in 16 runs | 40 |
| Empty Palm (`path_open`), every stat 1 | 4 to 5, an elite once | 80 to 110 |
| Strength and Spirit 10, Empty Palm (`tribulation_ready`, core emptied) | 6 to 9, an elite now and then, never the boss | 120 to 210, about 160 |

Every run ends in death: Health stays at 100 (Body can't be trained on `main` yet), and a regular fight at stat 1 costs about 45 of it.

**The growth profile** follows the tuning target that the core fills about when Spirit reaches the cap. Strength and Spirit rise about a level a run, from 1 to 10 by run 9, and Empty Palm comes in from run 3, after the story's Core Density 10 beat. Two calibration playthroughs paid:
- A: 40, 40, 120, 100, 170, 130, 140, 120, 140, 120, 160, 140.
- B: 40, 40, 100, 80, 100, 120, 160, 120, 80, 120, 260, 190.

**Core Density after each run** on the chosen curve:

| Run | Calibration A | Calibration B | Confirmation A | Confirmation B |
|---|---|---|---|---|
| 1 | 7 | 7 | 7 | 7 |
| 2 | 14 | 14 | 14 | 14 |
| 3 | 33 | 30 | 33 | 33 |
| 4 | 47 | 42 | 49 | 52 |
| 5 | 66 | 54 | 65 | 67 |
| 6 | 79 | 67 | 79 | 82 |
| 7 | 91 | 82 | 89 | 96 |
| 8 | 100 | 92 | 100 | 100 |
| 9 | | 99 | | |
| 10 | | 100 | | |

The calibration columns are computed from the measured XP. The confirmation columns are two more playthroughs on the chosen curve, read from the game. Both filled the core on run 8, with Strength and Spirit at 8.

- **Runs to a full core:** 8 to 10 on the growth profile; 6 for a character already at the cap; about 22 for one who never trains, who can't break through anyway (the Tribulation needs Strength and Spirit at the cap).
- **Core Density 10** (the first path point and `q_reach_cd_10`): 52 XP, in the second run.
- **A failed Tribulation:** levels 96 to 100 cost 66 XP, about 3 regular kills. That's half a run late in the stage, so one run wins them back.
- **Spirit:** the growth profile is the Spirit-cap target itself. The core fills a run before Spirit reaches 10. #91 put Spirit Lv 1 to 10 at about 22 to 29 minutes of cycling, which a player fits between the runs. #111 checks the joint timing end to end.
- **What moves XP per run later:**
  - **Fewer runs:** a player who saves Empty Palm to cut enemy casts may win more fights a run. So does a character whose Health can grow (Body, phase 5) or who wears gear.
  - **More runs:** #104's runs that no longer refill Health would pay less.

## Tasks

1. **The curve.** Write the three values in `foundation_advancement_stage.tres`. Give `AdvancementStageResource.get_xp_for_level()` its `##` doc comment (the cost of one level, not the total to reach it).
2. **Tests.** Drop `test_cultivation_getters.gd`'s `test_xp_for_level_follows_the_stages_curve` with its section and its line in the header comment: no test pins shipped tuning ("What to test" in `docs/testing/TESTING.md`). `test_cultivation_manager.gd`'s `test_xp_for_level_follows_base_times_scaling` keeps covering the formula. Run `tests/run_tests.ps1` and fix any test that leaned on the real curve's numbers by giving it its own fixture.
   - **Built:** seven files leaned on it (the adventure end flow, tilemap events, cultivator plate, cycling technique, kill beads, the run cabinet's core row and the Core Density effect). A new helper, `tests/helpers/core_curve.gd` (`CoreCurve.use_fixed_curve()` / `restore()`), swaps in copies of the real stages whose Foundation runs on a fixed 10 × 1.02 curve, so their figures stay as written and no longer move with tuning.
3. **Check in the game** on the chunk's own save (`-- --save=user://dev/runs/core-density-curve.tres`): the playthroughs above, at ×10.
4. **PR** closing #96 with the arithmetic and `## Docs to update`.

## Save

No new field and no version step. A saved Core Density XP figure means XP toward the next level at the new costs (#85's "Saved values that change meaning"). With no load rule, a save holding more than its next level's new cost levels up at its next award.
