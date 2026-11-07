# The book's drill lines (stats rework chunk #108)

**Goal:** Strength's page in the Character book shows the Health a rep restores, now and at the next level, and its description names that job. Strength's, Body's and Agility's pages say how many perfect sets of the equipped drill the next level takes. The pages follow the equipped drill.

**Issue:** LionelEisenberg/EndlessPath#108, tracked in #85. Needs #102 (PR #130) and #100 (PR #127), both on `main` at 532c9c49.

**Canvas:** [The book's drill lines](https://claude.ai/artifact/YPRsjZmTho2BKcyrmTDRMH), approved as drawn on 2026-11-06. The answers are recorded on #108.

## Approved answers

1. **Health per rep** is the first line under Strength's WHAT IT DOES: "HEALTH PER REP 4.8 → 5.2", in Health ink. It reads `DrillRules.health_for_rep()` for the equipped drill at the Strength of the page's now block and of its next block (#102's exact next block, gear recounted), printed with `AbilityRow.format_number()`, which rounds to two decimals as the board's `LacquerText.rate()` does.
2. **The rep** is a PERFECT one. The row's label doesn't say "perfect".
3. **The sets line** reads "2 perfect sets to Lv 4", or "1 perfect set to Lv 4" for one, in #102's place under the XP bar. It shows on a Physical page while the stat is under the cap and the equipped drill pays it XP. It never names the drill.
4. **Strength's description:** "Raw physical power. Your physical techniques hit harder, and each rep restores more Health."
5. **Before body refining unlocks:** both lines always show, read from the equipped drill a new save starts with. "Not yet active" leaves the page: no stat is left without a line.

The sets count changes no screen. It was built while the canvas waited: commit 904f49da.

## Tasks

Build bottom-up. Run `tests/integration/test_character_book.gd` after each task, then commit.

### Task 1: The sets count (done, 904f49da)

- `CharacterView.sets_to_next_level(stat, drill)` and `sets_line(count, next_level)`. The count shares `_count_to_next_level(stat, xp_each)` with `cycles_to_next_level()`.
- Tests: `test_sets_to_next_level_reads_the_equipped_drill` (a table over stats and drills, and the cap), `test_one_perfect_set_lowers_the_count_by_one`, `test_a_set_count_of_one_reads_in_the_singular`.

### Task 2: Health per rep and Strength's sentence

- `effect_lines()` takes an optional `drill: DrillData`. With one, Strength's first line is "Health per rep": `DrillRules.health_for_rep(drill, PERFECT, block.strength)` for the now and the next block.
- `_POOL_INKS` gains "Health per rep" (Health ink). `STAT_DESCRIPTIONS[STRENGTH]` takes the approved sentence.
- `_show_details()` passes `BodyRefiningManager.get_equipped_drill()`.
- Tests: Strength's labels in `test_each_stat_names_what_it_does`; `test_strength_reads_health_per_rep_first` (each drill: the now figure is what `BodyRefiningManager.perfect_rep_health()` gives, which the board shows, and the next is the rule at the next block's Strength); `test_next_health_per_rep_counts_the_gear_the_next_level_adds`; `test_a_capped_strength_shows_health_per_rep_alone`; Strength without a drill has no Health per rep line.

### Task 3: The sets line on the page, the drill refresh, and "Not yet active" goes

- The scene's `CyclesRow` / `CyclesLabel` become `EstimateRow` / `EstimateLabel`: one row under the XP bar holds the cycles line on a Spiritual page and the sets line on a Physical one. `test_boards_never_trim_text.gd` follows the rename.
- `_show_details()`: a Physical stat reads `sets_to_next_level()` with the equipped drill, a Spiritual one `cycles_to_next_level()` with the equipped technique.
- `_ready()` connects `BodyRefiningManager.equipped_drill_changed` to `_refresh_if_shown`.
- `NO_EFFECTS_TEXT` and the `NoEffectsLabel` node go.
- Tests: `test_the_sets_line_follows_the_equipped_drill` (Body with Horse Stance, then Stone Lifting hides it at once; Strength's Health per rep follows); `test_the_sets_line_names_no_drill`; the Spiritual pages and a capped Strength show no sets line; `test_every_stat_has_a_line` replaces the "Not yet active" test (no abilities known, every page lists at least one row).

### Task 4: Checks

- `tests/run_tests.ps1` green.
- The issue's Done-when checks, played on `-- --save=user://dev/runs/book-physical-lines.tres`, and a new save (`--preset=fresh`).
- An old save loads with the book open on Strength.

## What was built differently

- The row under the XP bar is renamed in the scene, `CyclesRow` / `CyclesLabel` to `EstimateRow` / `EstimateLabel`, since it now holds either count. No node was added.
- `test_a_stat_with_no_known_technique_says_so` became `test_every_stat_has_a_line`, with no ability known at all.
- The Done-when checks ran in the real main scene through a scripted driver (gitignored, `mockups/book_drill_checks/`) on `--save=user://dev/runs/book-physical-lines.tres`, a new save, and on a copy of an old save. All passed: a PERFECT rep restored 4 Health against the page's 4; one perfect set took the count from 2 to 1; a level moved "4 → 4.4" to "4.4 → 4.8"; each of the four drills set Health per rep and the sets lines as approved; a capped Strength read "7.6" alone with no sets line.
