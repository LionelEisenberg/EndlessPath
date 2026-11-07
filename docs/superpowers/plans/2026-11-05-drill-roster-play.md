# Drill Roster Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stats rework chunk #106 (tracked in #85): Horse Stance, Falling Leaf and Waterfall Tempering each play on the body refining board in a scene of their own, judged at exact times, and the player picks which drill to train from drawers in the chest, so Body and Agility train in play beside Strength.

**Architecture:** `DrillRun` is the contract every drill's input plays through (a set starts and stops, presses come in, each rep comes out judged, at exact microsecond times on the set's clock), with one subclass per input: `StoneLiftingRun` (#100's judge, moved), `HorseStanceRun`, `FallingLeafRun` and `WaterfallRun` (on `TimedPressRun`). `DrillPlay` keeps the shared set flow (paying each rep through `pay_rep`, the beads, the floaters, the session) and shows the stage scene of the drill's input kind (`DrillStage`), which draws its own scene and its run. A drills mode in the zone chest, beside the techniques mode, lists one `DrillDrawer` per learned drill; picking one equips it through `BodyRefiningManager`, and the board follows the equipped drill.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** issue #106's Decided list and the approved "Drill roster on the board" canvas (https://claude.ai/artifact/KexMdi7mbSGENCPtfiKmND), whose answers are below and on #106 (issuecomment-6701602559); the first Body Refining canvas (https://claude.ai/artifact/8HWv57erQMXyU2iHCw7cHs), whose scenes and art the drills take; #97's drill answers (issuecomment-6673330078) and #100's board answers (issuecomment-6676292424). The master plan's Phase 5 outline (Tasks 5.10, 5.14, 5.19) for shape only.

## The canvas's answers (approved by Lionel on 2026-11-06, as drawn, after one round: "these gotta look more like what we designed at first, they don't need to follow the 'show the whole body' schema")

- **Horse Stance:** the first canvas's stance gauge over the figure (hips and legs rimmed in brass), its incense burning down over the set with the seconds left under it. Held, the needle sinks deeper (the whole gauge in 2 s); let go, it rises as fast; it never drops. A brass arc, a quarter of the gauge, drifts along it, turning every 0.8 to 1.6 s on a path made for each set; brass while the needle is in it, tan while out. A 4 s rep's share is the part of it the needle spent in the arc. A Miss says the side the needle spent longer on: "Too deep" or "Too shallow". Footer: "Hold Space or the mouse button to sink into the stance." / "Keep the needle in the brass: hold to sink, let go to rise."
- **Falling Leaf:** the first canvas's branch, figure (hands and legs rimmed) and ground line. A leaf drops from the branch every 2 s and sways down for 3.6 s, a dotted trail of its swing behind it. Click a leaf to catch it (the pointer is the hand; Space catches at the pointer), judged by how close to its middle: 12 px Perfect, 24 Good, 36 OK. 36 to 48 px is a Miss ("Too far") and the leaf slips away; further from every leaf does nothing. A leaf reaching the ground is a Miss ("Landed") and stays there for the set. The brass ring shows where a catch was made, and the pellets leave from there. Footer: "Press Space or click to shake the branch." / "Click a leaf to catch it before it lands."
- **Waterfall Tempering:** the first canvas's close-up under the falls (head and shoulders rimmed), the falls streaming in 2 px steps, a brass brace line over the head between two marked rails. A surge of foam rides down 1.5 s and lands on the line 1.5 s into each 3 s rep. The rep's first press is judged by its time from the landing (0.05 / 0.1 / 0.18 s), the rails' marks being those windows at the surge's speed. A hit rings brass at the line. Misses: "Too early", "Too late", "Buckled" (no press: the surge crashes through). Footer: "Press Space or click to open the falls." / "Press as each surge lands on the brass line."
- **Starting a set:** the first press starts it on every drill; on the hold drills it is the first lift or sink, on Falling Leaf it shakes the branch and on Waterfall Tempering it opens the falls, unjudged.
- **Picker:** drawers in the chest, a drills mode beside the techniques mode; opening the board turns the chest to "Drills · N learned", closing turns it back. Each drawer: icon, name, NEW until seen, IN USE (pulled out), how it plays and its rep ("Keep the needle in the brass · 4 s reps"), "Trains [icon] Strength and [icon] Body". Only learned drills show. A click equips (saved); the chest takes its own clicks while the board is up.
- **Picking mid-set:** the set ends there; scored reps stay paid; the set is neither counted nor logged; the board readies the new drill.
- **Icons:** Body's 16 px mini is its heart in steel; Agility's is drawn from its icon. A capped Body or Agility reads "capped" as Strength does, sends no pellets, and Health still refills.
- **Combined drills:** none beyond #97's rule. **Key:** none; `project.godot` doesn't change.

## Global Constraints

- `CLAUDE.md`'s GDScript standards: explicit types, `##` docs on public functions, private names start with `_`, no `print()` (use `Log`).
- UI nodes live in `.tscn` scenes with theme variants; scripts set text, textures, frames, visibility, positions, a shader's `progress` and state colours only. Each `ShaderMaterial` is in a scene and `resource_local_to_scene`.
- No text is ever cut off: a long drill name or line wraps and its drawer or board grows; new boards join `BOARD_SCENES` in `test_boards_never_trim_text.gd` when they hold Labels; no file joins `KNOWN_TRIMMERS`.
- A new log line fits one log line while the log board trims (RL-05). Screens never print "minor".
- Lacquer look: one 2x pixel grid, even positions and sizes, nearest filtering, no glow, gradient, fade or tint; motion in 2 px steps; shaders follow the style guide's pixel-grid pattern.
- New art ends in `_ai`; Lionel's files (no `_ai`) are never edited.
- `project.godot` does not change. Save: none (picking writes the saved `equipped_drill_id`; no field, no version).
- The drill drawer copies `TechniqueDrawer`'s layout in a scene of its own and shares no code with it (#101 may add an Auto mark there).
- Tests call production code, swap in a fresh `SaveGameData` and put the original back in `after_each()`, use no GUT doubles; timed play is tested at exact `clock_usec` times.
- One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. After adding a `class_name` script, a test file or art, run `--headless --import` once and check `git status --short project.godot` prints nothing.

## Review Focus

1. **A long frame on any drill.** A hitch never changes a result: each run judges, in order of time, whatever the time up to `t` decided (`test_a_long_gap_judges_each_rep_in_order` in each run's tests).
2. **Mashing.** Waterfall Tempering judges a rep's first press; Falling Leaf gives each leaf one try, and stray clicks far from every leaf cost nothing (`test_only_the_first_press_of_a_rep_is_judged`, `test_a_near_miss_loses_the_leaf_and_a_far_click_does_nothing`).
3. **A press on the chest.** Picking a drawer while the board is up equips the drill and never reaches the drill as a press; a press anywhere else still does (Task 12: `test_a_press_on_the_chest_picks_and_never_plays`).
4. **Picking mid-set.** Scored reps stay paid, nothing is counted or logged, and the board readies the picked drill (Task 13: `test_picking_another_drill_mid_set_keeps_what_was_paid`).
5. **The starting press.** On Falling Leaf and Waterfall Tempering the press that starts a set is never judged (Task 6: `test_the_starting_press_starts_without_a_rep_on_the_press_drills`).

---

## Part A: the judging (changes no screen)

- [x] **Task 1: DrillRun, the contract; StoneLiftingRun, #100's judge** (3345c3e3). `DrillRun` holds the judgement, the slots, `for_drill(drill, rng_seed)`, `share_through()` and `judges_starting_press()`; #100's judge moved unchanged to `StoneLiftingRun`.
- [x] **Task 2: HorseStanceRun** (f9887b3e): the marker held up or sinking at one speed, the band's path (`band_path(rng_seed, set_usec)`), the exact time inside per rep.
- [x] **Task 3: TimedPressRun and WaterfallRun** (cdb827b2): one judged press a rep, a target 1.5 s into each 3 s rep at #97's 50 / 100 / 180 ms.
- [x] **Task 4: FallingLeafRun as a timed press** (2efda5ae), replaced by Task 5.

### Task 5: The approved judging: Falling Leaf's aimed catch, Horse Stance's sides (691f51f9)

**Files:**
- Modify: `scenes/body_refining/drill/drill_run.gd`, `horse_stance_run.gd`, `timed_press_run.gd`, `waterfall_run.gd`, `falling_leaf_run.gd`
- Test: `tests/unit/test_drill_run.gd`, `test_horse_stance_run.gd`, `test_waterfall_run.gd`, `test_falling_leaf_run.gd` (rewritten)

**Interfaces:**
- `DrillRun.Miss` becomes `{ NONE, TOO_LOW, DROPPED, TOO_LATE, TOO_DEEP, TOO_SHALLOW, TOO_EARLY, TOO_FAR, LANDED, BUCKLED }` (never saved). `Judgement` gains `point: Vector2` (where the rep's piece was, in the stage's px, for the inputs that have one). `press_at(t_usec, point: Vector2) -> Array[Judgement]` (the default ignores the point and calls `press()`); `share_through()` takes floats; `_record_rep(rep, …)` records a rep out of turn.
- `HorseStanceRun`: a MISS is TOO_DEEP or TOO_SHALLOW by the longer time out on that side.
- `WaterfallRun`'s rep with no press is BUCKLED.
- `FallingLeafRun extends DrillRun`: `_init(drill, leaves: Array[FallingLeafRun.Leaf])`; `class Leaf` (`drop_usec`, `x`, `top_y`, `sway_px`, `sway_period_usec`, `sway_phase`); `static leaf_paths(rng_seed, drill) -> Array[Leaf]`; `leaf_position(leaf_index, t) -> Vector2`; `is_airborne(leaf_index, t) -> bool`; `get_leaf_count()`. Constants: `FALL_USEC = 3_600_000`, `GROUND_Y = 856.0` (a leaf's middle on the ground line), `PALM_PX = 12.0`, `FINGERS_PX = 24.0`, `BRUSH_PX = 36.0`, `REACH_PX = 48.0`, the branch line `BRANCH_Y_AT_0 = 46.0` falling `BRANCH_SLOPE = 0.095` px a px, drops between `DROP_X_MIN = 40.0` and `DROP_X_MAX = 400.0`, sway 16 to 32 px over 1.4 to 2.0 s. `judges_starting_press()` false. A press at a point judges the nearest airborne, unjudged leaf within REACH_PX by its distance (share_through at the px windows), a MISS being TOO_FAR; else nothing. A leaf not caught by its landing is LANDED then. Judgements come out in the order of their times; each carries its leaf as its rep and its position as its point.

- [x] **Step 1: Write the failing tests.** `test_drill_run.gd`: `test_a_press_at_a_point_is_a_press_for_the_runs_with_no_aim` (Stone Lifting: `press_at(0, Vector2(9, 9))` lifts). `test_horse_stance_run.gd`: the table's MISS rows become TOO_DEEP (held up through a mid band) and TOO_SHALLOW (left at rest under a band at 0.5). `test_waterfall_run.gd`: MISSED_BEAT becomes BUCKLED. `test_falling_leaf_run.gd` (rewritten, leaves built in the test, no sway unless a test says): `test_a_catch_is_judged_by_how_close_to_the_leaf` (table at the first leaf's position 1 s after its drop: 0 / 12 px → PERFECT, 12.5 → GOOD, 24 → GOOD, 36 → OK, 40 → MISS TOO_FAR; judged at the press, its point the leaf's position); `test_a_click_far_from_every_leaf_does_nothing`; `test_a_near_miss_loses_the_leaf_and_a_far_click_does_nothing` (TOO_FAR, then a click on it judges nothing more); `test_the_nearest_leaf_is_caught` (two leaves in the air, a click between them nearer the second); `test_a_leaf_nobody_catches_lands` (LANDED at its drop + 3.6 s, its point on the ground); `test_a_leaf_falls_and_sways_along_its_path` (`leaf_position()` at its drop, half way and landing, with sway); `test_a_long_gap_judges_each_rep_in_order` (ten LANDED in order; `get_end_usec()` 21.6 s); `test_catches_come_out_of_turn` (the second leaf caught before the first lands: rep 1 then rep 0); `test_the_leaf_paths_stay_on_the_board` (a seed's ten paths: drops 2 s apart, x within the drop range and the sway within the board, the same seed the same, another seed different).
- [x] **Step 2: Run them: FAIL. Step 3: Implement. Step 4: Run them and every drill run test: PASS. Step 5: Commit.**

## Part B: the board and the picker

### Task 6: Stages: DrillPlay shows the drill's own scene (e6c96f18, 994f443e)

**Files:**
- Create: `scenes/body_refining/drill/stages/drill_stage.gd` (`class_name DrillStage extends Control`), `stone_lifting_stage.gd` and `.tscn` (the carved body, the Strength rim, the track, rails, jade and stone, moved from `body_refining_view.tscn` and `drill_play.tscn`)
- Modify: `scenes/body_refining/drill/drill_play.gd` and `.tscn` (a `Stages` node holding one stage per input kind under the beads and floaters), `scenes/body_refining/body_refining_view/body_refining_view.gd` and `.tscn` (FigureBox holds DrillPlay only; the drill's `ready_line` / `play_line`; `get_pellet_origin()`), `scripts/resource_definitions/body_refining/drill/drill_data.gd` and the four drill `.tres` files (`play_hint`, `ready_line`, `play_line`, `icon`), `assets/ui/lacquer/icons/ic_drill_stance_ai.png`, `ic_drill_leaf_ai.png`, `ic_drill_waterfall_ai.png` (new)
- Test: `tests/integration/test_drill_play.gd`, `tests/integration/test_body_refining_view.gd`, `tests/unit/test_drill_data.gd`

**Interfaces:**
- `DrillStage`: `@export var input_kind: DrillData.InputKind`; virtual `setup(drill)`, `show_rest()`, `show_run(run: DrillRun, t_usec: int)`, `show_judgement(judgement)`, `tick(now_usec: int)` (ambient motion every frame), `get_floater_anchor(judgement) -> Vector2` and `get_pellet_origin(judgement) -> Vector2` (stage space).
- `DrillPlay`: `get_stage() -> DrillStage`, `get_pellet_origin(judgement) -> Vector2` (screen space; replaces `get_stone_global_center()`); the run is `DrillRun.for_drill(drill, start_usec)`; a press reaches the run through `press_at(t, point)` (a mouse event's point, else the pointer's), the starting press only when `judges_starting_press()`; `MISS_REASONS` for every `Miss`.

- [x] **Steps:** failing tests: `test_drill_data.gd` `test_every_drill_has_its_words_and_icon`; `test_drill_play.gd` `test_each_drill_shows_its_own_stage` (table: the drill's stage shows, the others hide) and `test_the_starting_press_starts_without_a_rep_on_the_press_drills` (Waterfall Tempering: a press at 0 starts the set and judges nothing, a press 1.5 s later is Perfect); the view's status tests read the drill's lines; run (FAIL); implement (the stone tests reach the stone through the stage); `--import`; run (PASS, with the never-trim test); commit.

### Task 7: The Horse Stance stage (467c9852)

**Files:**
- Create: `scenes/body_refining/drill/stages/horse_stance_stage.gd` and `.tscn` (Backdrop; GaugeLit and GaugeDim, the gauge frame with `lacquer_drill_gauge_band.gdshader` in brass and in tan; Needle with `lacquer_drill_gauge_needle.gdshader`; IncenseBase, IncenseStick, IncenseEmber, Seconds); `assets/shaders/lacquer_drill_gauge_band.gdshader`, `lacquer_drill_gauge_needle.gdshader`; `assets/ui/lacquer/body_refining/lacquer_drill_stance_backdrop_ai.png`, `lacquer_drill_gauge_ai.png`, `lacquer_drill_incense_base_ai.png`, `lacquer_drill_incense_stick_ai.png`, `lacquer_drill_incense_ember_ai.png`
- Test: `tests/integration/test_drill_play.gd`

- [x] **Steps:** `test_a_horse_stance_rep_pays_strength_body_and_health` (a run whose band path the test gives, through a test-only hook on the stage's run seed, kept in the band for a rep: Perfect, 8 Strength XP, 4 Body XP, 4 Health); `test_the_gauge_follows_the_run` (the needle's and arc's `progress` are the run's marker and band centre, the lit gauge shows exactly while inside); `test_the_incense_burns_down_with_the_set` (the seconds left at 0, 10 and 40 s); run (FAIL); implement; run (PASS); commit with the art.

### Task 8: The Falling Leaf stage (dddc3892)

**Files:**
- Create: `scenes/body_refining/drill/stages/falling_leaf_stage.gd` and `.tscn` (Backdrop; ten `falling_leaf.tscn` instances, each a leaf with five trail dots; CatchRing); `assets/ui/lacquer/body_refining/lacquer_drill_leaf_backdrop_ai.png`, `lacquer_drill_leaf_ai.png` (four 32×32 frames), `lacquer_drill_leaf_trail_ai.png`, `lacquer_drill_catch_ai.png`
- Test: `tests/integration/test_drill_play.gd`

- [x] **Steps:** `test_a_falling_leaf_catch_pays_agility` (a click on the first leaf's middle: Perfect, 4 Strength XP, 2 Agility XP, 2 Health; the ring at the catch, the leaf gone); `test_a_landed_leaf_stays_on_the_ground`; `test_the_starting_press_shakes_the_branch` (the first press catches nothing); run (FAIL); implement; run (PASS); commit with the art.

### Task 9: The Waterfall Tempering stage (0d4f5a81)

**Files:**
- Create: `scenes/body_refining/drill/stages/waterfall_stage.gd` and `.tscn` (Backdrop, Falls a four-frame strip, RailLeft, RailRight, Brace, Surge, Hit a four-frame strip); `assets/ui/lacquer/body_refining/lacquer_drill_falls_backdrop_ai.png`, `lacquer_drill_falls_ai.png`, `lacquer_drill_brace_ai.png`, `lacquer_drill_brace_rail_ai.png`, `lacquer_drill_surge_ai.png`, `lacquer_drill_hit_ai.png`
- Test: `tests/integration/test_drill_play.gd`

- [x] **Steps:** `test_a_waterfall_landing_pays_body` (a press at the first landing: Perfect, 6 Strength XP, 3 Body XP, 3 Health); `test_the_surge_rides_down_to_the_line` (on the line at its landing, LEAD_USEC × its speed above it a lead earlier, hidden after a hit); run (FAIL); implement; run (PASS); commit with the art.

### Task 10: Body's and Agility's minis, and a capped minor stat (773788c8)

**Files:**
- Create: `assets/ui/lacquer/lacquer_mini_body_ai.png`, `lacquer_mini_agility_ai.png`
- Modify: `scripts/utils/stat_display.gd`, `scenes/body_refining/drill/drill_play.gd` (`_unpaid_parts()` for every stat the drill trains)
- Test: `tests/unit/test_stat_display.gd`, `tests/integration/test_drill_play.gd`

- [x] **Steps:** `test_every_physical_stat_has_a_mini_icon`; `test_a_capped_minor_stat_pops_capped` (Horse Stance with Body at the cap: "[Body] capped" under a Perfect, Body's XP unchanged, Health restored); run (FAIL); implement; run (PASS, and `test_body_refining_view.gd`); commit.

### Task 11: DrillDrawer and DrillList (81f8c6cb)

**Files:**
- Create: `scenes/body_refining/drill_drawer/drill_drawer.gd` and `.tscn` (TechniqueDrawer's layout copied, with a TrainsRow), `scenes/zones/zone_panel/drill_list/drill_list.gd` and `.tscn`
- Test: `tests/integration/test_drill_drawer.gd`, `tests/integration/test_boards_never_trim_text.gd`

- [x] **Steps:** `test_a_drawer_shows_its_drill` (name, "`play_hint` · 4 s reps", the Trains row's stats); `test_a_press_equips_its_drill_and_marks_it_seen`; `test_the_drawer_in_use_ignores_a_press`; `test_new_clears_when_the_pointer_leaves`; `test_a_long_name_wraps_and_the_drawer_grows`; `test_the_list_lists_the_learned_drills_in_order` (and rebuilds on an unlock, refreshes on an equip); run (FAIL); implement; `--import`; run (PASS); commit.

### Task 12: The chest's drills mode, the board's swap, and the chest's clicks (15d0633d)

**Files:**
- Modify: `scenes/zones/zone_panel/zone_panel.gd` and `.tscn` (`enum ChestMode { ACTIVITIES, TECHNIQUES, DRILLS }`, `set_chest_mode()`, `get_chest_mode()`, `chest_height_for_mode()`, `get_drill_list()`; the techniques API kept as wrappers), `scenes/ui/main_view/board_transition/board_transition_spec.gd` (`chest_mode`), `board_transition.gd`, `scenes/ui/main_view/main_view.gd` (the instant path; the chest handed to the body refining board), `scenes/ui/main_view/states/body_refining_view_state.gd` (`swaps_chest`, `chest_mode = DRILLS`), `scenes/body_refining/body_refining_view/body_refining_view.gd` (`chest`, `_has_point()` false over a showing chest)
- Test: `tests/integration/test_zone_panel.gd`, `tests/integration/test_board_transition.gd`, `tests/unit/test_body_refining_view_state.gd`, `tests/integration/test_body_refining_view.gd`

- [x] **Steps:** `test_drills_mode_lists_the_learned_drills` and `test_leaving_drills_mode_shows_the_activities`; `test_a_drills_board_swaps_the_chest_to_the_drills_both_ways` (the techniques tests unchanged); `test_the_chest_turns_to_the_drills_and_back`; `test_a_press_on_the_chest_picks_and_never_plays`; run (FAIL); implement; run (PASS, with `test_cycling_mode.gd` and every techniques test); commit.

### Task 13: Picking another drill mid-set (edee581a)

- [x] `test_picking_another_drill_mid_set_keeps_what_was_paid` in `test_body_refining_view.gd` (two Stone Lifting reps, then equip Horse Stance: their XP and Health stay, `sets_finished` 0, no log line, the session ended, the beads empty, the footer Horse Stance's `ready_line`, its stage showing); fix if needed; commit.

### Task 14: Wrap

- [x] The suite passes (`tests/run_tests.ps1`); a failure from the parallel run is confirmed in one process first.
- [x] The issue's Done-when checks run on `-- --preset=adventure_open --save=user://dev/runs/drill-roster-play.tres`; an old save still loads and plays.
- [x] `git diff main -- project.godot` is empty.
- [x] The PR closes #106 and ends with `## Docs to update`.

## What was built differently

- **The drills' look changed at the canvas.** The first draft played Horse Stance on Stone Lifting's track, and Falling Leaf and Waterfall Tempering on the carved figure's centre. Lionel sent them back to the first Body Refining canvas's scenes, so Part A's Falling Leaf judge (a timed press at a still hand, Task 4) gave way to an aimed click on the leaves (Task 5), and Horse Stance's miss reason split into "Too deep" and "Too shallow".
- **A catch's point is the click.** Task 5 gave a caught leaf's judgement the leaf's middle as its point. The canvas has the brass ring snap where the player clicked, and this plan sends the pellets from the ring, so a catch's point is the click (Task 8); a landed leaf's is still where it landed. `FallingLeafRun.is_on_ground()` tells the stage when a leaf lies on the ground.
- **A run seam instead of a seed hook.** Task 7's "test-only hook on the stage's run seed" became `DrillPlay.run_for`, a Callable defaulting to `DrillRun.for_drill` that tests replace as they do `clock_usec`, so a test hands the board a Horse Stance arc held still or Falling Leaf's leaves on a known path.
- **Inputs without a stage yet played Stone Lifting's** from Task 6 to Task 9, when every input had its own; that fallback is gone.
- **The floaters stay on the play.** A rep's tier and the line under it slide left together when the wider would run past the play's right edge, as a line with two "capped" parts can (Task 9). Falling Leaf's floaters also stand left of a catch on the stage's right half, and clear of the beads for a leaf on the ground.
- **The Waterfall's ring by tier.** The hit strip's four frames play as the brass ring swelling (frames 0, 2, 3) for a Perfect or Good press and the tan ring (frame 1) for an OK one, 80 ms a frame. The falls stream and the incense's ember flickers in stepped frames on the play's clock.
- **The chest's list is DrillDrawerList**, at `scenes/zones/zone_panel/drill_drawer_list/`: `DrillList` is the drill catalog's resource class. ZonePanel's modes became `enum ChestMode { ACTIVITIES, TECHNIQUES, DRILLS }` with `set_chest_mode()`, `get_chest_mode()` and `chest_height_for_mode()`; `set_techniques_mode()`, `is_techniques_mode()` and `chest_height_for()` stay as wrappers. `BoardTransitionSpec.chest_mode` names the mode a board swaps the chest to.
- **Done-when checks.** A scratch driver ran the real main scene as another scene, so its quit's save is the call the window's close makes, `PersistenceManager.save_data()`; the second launch read the file back in memory. The old save checked is this checkout's copy of the user's save from 2026-10-28 (version 5, before the drill fields), loaded in memory, never written.
