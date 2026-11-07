# Core Density stars (#103) Implementation Plan

> Stats rework chunk #103 (tracking issue #85). Built from `main` at ca2c2a06, with #96, #98, #99 and #87 merged.

**Goal:** Core Density reads as the core orb with ten stars that fill, on both cabinets, the Goals board, the Tribulation card and the adventure end card, in place of every figure out of 100.

**Canvas:** [Core Density stars](https://claude.ai/artifact/3WSuTXhGi73wwsqR1TMWAL), approved as drawn (answers on #103).

## Approved answers

- 10 stars a stage, each an equal share of the stage's cap (10 levels of Foundation's 100), written in both stage files. A lit star is a path point earned.
- The star being filled rises a tenth per level of its share.
- Level N, the XP beads, "xp / need XP", "Core full" and the "N / 100" figures go wherever the stars show. The dev panel keeps its numbers.
- Lines that count levels count stars: the card's "failure costs half a star"; the Tribulation board's fail line "Your core loses half a star" and rules line "4 cracks end the trial and cost half a star of Core Density".
- Requirement lines: "a full core" (refusal: "The Tribulation needs a full core."); the Goals board's "Fill your core"; with only the stage refusing, "the Foundation stage" (DM-13).
- Cabinet: a row of 18 px stars under the stage, where the beads were; the cabinet keeps its size, so the Goals board and the full log stay. The run's cabinet takes the same row.
- Goals board: large stars in place of the rod and figure; "Face the Tribulation" over full stars; "<Stage> reached" with no stars. A quest step measured on Core Density shows the stars up to its target instead of its figure (the Journal keeps the figure).
- Tribulation card: 14 px stars in place of the rod and figure, the stat line under them; the ready card shows the full stars under its line.
- End card: a CORE DENSITY row under the six stats: the stars as the core stands (parchment look, twice size), the run's part in jade (a star's part from before the run stays brass), then "+N" (the run's XP), "none this run", "+N · Core full" or "Core full".
- No new end card line for a lost run or a manual; no kill pay on the Goals board during a run.

## Architecture

- **Rule (done first):** `AdvancementStageResource.core_density_star_count`, `get_stars_lit(level)`, `get_star_fill(level, star)`, `get_star_fills(level)`; `CultivationManager.get_core_density_star_count()`, `get_core_density_stars_lit()`, `get_core_density_star_fill(star)`, `get_star_fills_at(level)` and `describe_levels_in_stars(levels)` ("half a star", "a star", "2 stars", falling back to "N levels").
- **One widget, `LacquerStarRow`** (`scenes/common/lacquer/lacquer_star_row/`): a scene with ten star slots, each a base `LacquerStripRect` and an overlay rect for the brass part from before a run. `set_fills(fills, before = [])` shows `fills.size()` stars, star i at step `floori(fill × 10)`, on the jade row where it rose past `before[i]`, with `before[i]`'s part drawn brass over it. Exports pick the strip, frame size, gap and the parchment rows. Scripts only set data.
- **Art:** `assets/ui/lacquer/lacquer_core_stars_strip_ai.png` (18 px) and `lacquer_core_stars_small_strip_ai.png` (14 px): columns 0 to 10 (empty, tenths, lit); rows brass, jade, brass on parchment, jade on parchment, brass fill alone (the overlay).
- **Cabinet:** `CultivatorPlate` loses `%LevelLabel`, `%XpBeads`, `%XpLabel`, the held core XP (`hold_core_xp`, `release_core_xp`, `_shown_core`), `get_core_orb_global_position` and its bead constant; `%CoreStars` shows `get_star_fills_at(level)`. `rewind_core` stays (stats and the run cabinet).
- **Run cabinet:** `VitalsPlate`'s Core row the same, its held XP kept for #90's beads (rewound level → stars). `CultivationManager.CORE_FULL_TEXT` goes.
- **Goals board:** `%MilestoneStars` replaces `%MilestoneRod` and `%MilestoneFigureLabel`; `%QuestStars` beside `%QuestFigureLabel` for a `CULTIVATION_LEVEL` step.
- **Card:** `%CoreStars` replaces `%CoreRod` and `%CoreFigure` in `NeedGroup`; `%ReadyStars` under `%ReadyLabel`. `TribulationActionData.get_missing_requirements(include_core, trial)` gains the stage line when given the trial; `get_refusal_lines()` is the card's. `ActionManager.select_action` is not edited (its diagnostic `Log.info` keeps the static lines).
- **Tribulation data:** `rules_text` and `fail_text` templates take `{loss}`; `get_fail_line()` drops its level arguments.
- **End card:** `AdventureResultData.core_density_xp_earned`, `core_density_level_before`, `core_density_level_after`, filled by `AdventureView._build_result_data()` (the level before recorded in `start_adventure()`); `AdventureEndCard` shows `%CoreDensityStars` and `%CoreDensityValueLabel` (wraps). The end card joins `BOARD_SCENES`.

## Tasks

1. Star rule and reads, tested (`test_cultivation_manager.gd`). Done.
2. LL-01: the card re-reads on a save reset (`test_tribulation_card.gd`). Done.
3. Art strips and `LacquerStarRow`, with `test_lacquer_star_row.gd` (frames per fill, jade where risen, the overlay, hidden extra stars).
4. Cabinet and run cabinet in stars; rewrite the core tests in `test_cultivator_plate.gd`, `test_vitals_plate_core.gd` and `test_kill_beads.gd`; delete the held core XP tests.
5. Goals board in stars; rewrite the milestone tests in `test_goals_panel.gd`, add the quest row's stars.
6. Tribulation card, requirement lines (a full core, the stage, DM-13), the trial's two lines; rewrite the card and flow tests; DM-12 (the not-ready card's height follows its stat line below the cap) and DM-14 (a refusal on the core alone) pins.
7. End card's Core Density row from the run's result; `test_adventure_end_flow.gd` and `test_adventure_end_card.gd`; the never-trim board list.
8. Suite, the Done-when checks on `-- --save=user://dev/runs/core-density-stars.tres` and the presets, an old save's copy, PR.

## Built differently

- **The card's small stars sit with no gap** (a 14 px pitch, 140 px for ten), where the canvas drew a 16 px pitch. The ready card's right column, "failure costs half a star", wraps to two lines at its 158 px, and its second line sits level with the stars: at 16 px the stars ran into it and pushed it past the card's edge. Both the not-ready and the ready star rows use the same pitch.
- **The ready card is 90 px**, one line taller than before, for its row of stars (the canvas's drawing).
- **The Goals board keeps its height:** the stars' row is 18 px under a 2 px margin, where the rod was 14 px under 6, so no board height moves and the full log keeps its place.
- **`get_missing_requirements()` stays static** and gains the trial as an optional argument for the stage's line; the card calls `get_refusal_lines()`. `ActionManager.select_action`'s diagnostic `Log.info` still reads the static lines without the stage (it is not edited this wave), so it names no stage; the player's log line does.
- **The bead strip `lacquer_beads_xp_strip_ai.png` is deleted:** no scene reads it once both cabinets show stars.
- **`CultivationManager.CORE_FULL_TEXT` is gone** with the "Core full" figure; the end card keeps its own "Core full" for the run's line.
