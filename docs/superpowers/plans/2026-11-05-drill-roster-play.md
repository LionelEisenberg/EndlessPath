# Drill Roster Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stats rework chunk #106 (tracked in #85): Horse Stance, Falling Leaf and Waterfall Tempering each play on the body refining board with their own input, judged at exact times, and the player picks which drill to train from drawers in the chest, so Body and Agility train in play beside Strength.

**Architecture:** `DrillRun` becomes the contract every drill's input plays through (a set starts and stops, presses come in, each judged rep comes out in order, at exact microsecond times on the set's clock), with one subclass per input: `StoneLiftingRun` (#100's judge, moved), `HorseStanceRun`, and `TimedPressRun` under `FallingLeafRun` and `WaterfallRun`. `DrillPlay` keeps the shared set flow (paying each rep through `pay_rep`, the beads, the floaters, the session) and shows one stage scene per input kind, which draws its run. A drills mode in the zone chest, beside the techniques mode, lists one `DrillDrawer` per learned drill; picking one equips it through `BodyRefiningManager`, and the board follows the equipped drill.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** issue #106's Decided list and its "Settle at the mock-up step"; the "Drill roster on the board" canvas (https://claude.ai/artifact/KexMdi7mbSGENCPtfiKmND), whose proposals are below; #97's drill answers (issuecomment-6673330078) and #100's board answers (issuecomment-6676292424). The master plan's Phase 5 outline (Tasks 5.10, 5.14, 5.19) for shape only: where it differs, the issue and the canvas win.

## The canvas's answers (proposed; amended on Lionel's approval)

- **Horse Stance:** Stone Lifting's stone, track and jade. Held, the stone rises at 200 px a second; let go, it sinks at 200 px a second; it stops at the top and at rest and never drops. A 96 px brass band drifts along the track (40 to 110 px a second, turning every 0.8 to 1.6 s) on a path made for the set; the band shows brass while the stone's base is in it, tan while out. A 4 s rep's share is the part of it the base spent in the band. Miss: "Out of the band". Footer: "Hold Space or the mouse button to raise the stone." / "Keep the stone in the drifting band. Let go and it sinks."
- **Falling Leaf:** a golden leaf sways down beside the figure's right hand once a 2 s rep, reaching the palm 0.9 to 1.5 s into it, at 200 px a second near the hand. A palm line between two rails marks the catch. The first press of a rep catches, judged by the leaf's distance from the palm: 12 px (Perfect), 24 (Good), 44 (OK), the share falling to 0 at 64. Misses: "Too early", "Too late", "Let it fall" (no press by 64 px below). Footer: "Press Space or click to let the first leaf fall." / "Press as the leaf crosses your palm."
- **Waterfall Tempering:** water pours down the carved track; once each 3 s rep a blow of water falls 1.5 s onto a brass strike line, landing 1.5 s into the rep. The first press of a rep is judged by its time from the landing: 0.05 s, 0.1 s, 0.18 s, the share falling to 0 at 0.26 s. Misses: "Too early", "Too late", "Missed the beat" (no press by 0.26 s after). Footer: "Press Space or click to let the water fall." / "Press as each blow of water lands on the line."
- **Starting a set:** the first press starts the set on every drill. On the hold drills it is also the first lift; on Falling Leaf and Waterfall Tempering it is not judged.
- **Picker:** drawers in the chest, a drills mode beside the techniques mode: opening the board turns the chest to "Drills · N learned", closing turns it back. Each drawer: the drill's icon, name, NEW until seen, IN USE on the equipped drill (pulled out), how it plays and its rep ("Hold steady in the drifting band · 4 s reps"), and "Trains [icon] Strength and [icon] Body". Only learned drills show. A click equips the drill; a press anywhere but the chest is the drill's.
- **Picking mid-set:** the set ends there; scored reps stay paid; the set is neither counted nor logged; the board readies the new drill.
- **Icons:** Body's 16 px mini is its heart in steel (Body's pellet colour), apart from the Health heart; Agility's is drawn from its icon. A capped Body or Agility reads "capped" as Strength does, sends no pellets, and Health still refills.
- **Combined drills:** none beyond #97's rule (one drill at a time, a rep pays each stat once). **Key:** none; every drill plays on `drill_press`.

## Global Constraints

- `CLAUDE.md`'s GDScript standards: explicit types, `##` docs on public functions, private names start with `_`, no `print()` (use `Log`).
- UI nodes live in `.tscn` scenes with theme variants; scripts set text, textures, visibility, positions and state colours only.
- No text is ever cut off: a long drill name or line wraps and its drawer or board grows; the drill drawer joins `BOARD_SCENES` in `test_boards_never_trim_text.gd` if it holds Labels; no file joins `KNOWN_TRIMMERS`.
- A new log line fits one log line while the log board trims (RL-05). Screens never print "minor".
- Lacquer look: one 2x pixel grid, even positions and sizes, nearest filtering, no glow, gradient, fade or tint; motion in 2 px steps.
- New art ends in `_ai`; Lionel's files (no `_ai`) are never edited.
- `project.godot` does not change (no new key).
- Save: none. Picking writes the saved `equipped_drill_id`; no field is added, so no version is taken.
- The drill drawer copies `TechniqueDrawer`'s layout in a scene of its own and shares no code with it (#101 may add an Auto mark there).
- Tests call production code, swap in a fresh `SaveGameData` and put the original back in `after_each()`, use no GUT doubles; timed play is tested at exact `clock_usec` times.
- One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. After adding a `class_name` script or a test file, run `--headless --import` once and check `git status --short project.godot` prints nothing.

## Review Focus

1. **A long frame on any drill.** A hitch never changes a result: each run judges, in order, whatever the time up to `t` decided (Tasks 2, 3, 4: `test_a_long_gap_judges_each_rep_in_order`).
2. **Mashing.** On Falling Leaf and Waterfall Tempering the first press of a rep is the one judged, so mashing misses (Task 3: `test_only_the_first_press_of_a_rep_is_judged`); on Horse Stance holding the stone at the top scores only the time the band spends there (Task 2: `test_holding_at_the_top_scores_only_the_band_passing`).
3. **A press on the chest.** Picking a drawer while the board is up equips the drill and never reaches the drill as a press; a press anywhere else still does (Task 13: `test_a_press_on_the_chest_picks_and_never_lifts`).
4. **Picking mid-set.** Scored reps stay paid, nothing is counted or logged, and the board readies the picked drill (Task 14: `test_picking_another_drill_mid_set_keeps_what_was_paid`).
5. **The starting press.** On Falling Leaf and Waterfall Tempering the press that starts a set is never judged, so a set can't open on a "Too early" (Task 8: `test_the_starting_press_starts_without_a_rep_on_the_press_drills`).

---

## Part A: the judging (changes no screen)

### Task 1: DrillRun, the contract; StoneLiftingRun, #100's judge

**Files:**
- Modify: `scenes/body_refining/drill/drill_run.gd` (the base: types, shared slots, the factory, the share helper)
- Create: `scenes/body_refining/drill/stone_lifting_run.gd` (#100's judge, moved unchanged)
- Modify: `scenes/body_refining/drill/drill_play.gd` (`StoneLiftingRun` in place of `DrillRun.new`, nothing else)
- Test: `tests/unit/test_drill_run.gd` (the base), `tests/unit/test_stone_lifting_run.gd` (`git mv` of today's `test_drill_run.gd`, then the class names)

**Interfaces:**
- Produces on `DrillRun extends RefCounted`: `enum Miss { NONE, TOO_LOW, DROPPED, TOO_LATE, OUT_OF_BAND, TOO_EARLY, LET_FALL, MISSED_BEAT }` (appended: TOO_LATE is shared by every input that can be late); inner `class Judgement` as today (`rep`, `tier`, `miss`, `height`, `at_usec`); `_init(drill: DrillData)`; `static func for_drill(drill: DrillData, seed: int = 0) -> DrillRun` (by `drill.input_kind`; every kind gets `StoneLiftingRun` until its own run lands); virtual `press(t_usec) / release(t_usec) / advance(t_usec) -> Array[Judgement]`; virtual `judges_starting_press() -> bool` (true here); `rep_at(t)`, `rep_progress_at(t)`, `get_judged_count()`, `get_judgements()`; virtual `get_end_usec() -> int` (default: the last slot's end once every rep is judged, else -1); `static func share_through(offset_usec: int, perfect_usec: int, good_usec: int, ok_usec: int, zero_usec: int) -> float`; protected `_record(tier, miss, height, at_usec) -> Judgement`.
- Produces: `StoneLiftingRun extends DrillRun` with today's constants, `height_at()`, `is_lifting()` and `static share_for_offset()` (now `share_through(offset, 70_000, 210_000, 630_000, 1_050_000)`).

- [ ] **Step 1: Move the tests.** `git mv tests/unit/test_drill_run.gd tests/unit/test_stone_lifting_run.gd` (and its `.uid`); in it, `StoneLiftingRun` for `DrillRun` where the stone's judge is meant (`DrillRun.Judgement` and `DrillRun.Miss` stay); move `test_drill_press_is_space_and_the_left_button` and `test_rep_progress_follows_the_slot` to a new `tests/unit/test_drill_run.gd`, which adds `test_the_share_falls_through_any_windows` (a table: 0 → 1.0, the perfect reach → 0.85, good → 0.6, ok → 0.3, zero and past → 0.0, both signs) and `test_each_input_gets_its_run` (a table of the four kinds → `StoneLiftingRun`; Tasks 2 to 4 change their rows).
- [ ] **Step 2: Run both files: FAIL** (no `StoneLiftingRun`, no `share_through`).
- [ ] **Step 3: Implement** the split; the settle loop and the rest timings move as they are.
- [ ] **Step 4: Run both files, `test_drill_play.gd` and `test_body_refining_view.gd`: PASS.**
- [ ] **Step 5: Commit.**

### Task 2: HorseStanceRun, the drifting band

**Files:**
- Create: `scenes/body_refining/drill/horse_stance_run.gd`
- Modify: `scenes/body_refining/drill/drill_run.gd` (HOLD_STEADY → `HorseStanceRun`)
- Test: `tests/unit/test_horse_stance_run.gd`, `tests/unit/test_drill_run.gd` (its row)

**Interfaces:**
- Produces: `HorseStanceRun extends DrillRun`; `_init(drill: DrillData, band_times: PackedInt64Array, band_centres: PackedFloat64Array)` (the band's centre at each time, 0 to 1 of the stone's travel, straight between, held after the last); `static func band_path(seed: int, set_usec: int) -> Array` (`[PackedInt64Array, PackedFloat64Array]`); `marker_at(t) -> float` (the stone's base, 0 to 1); `band_centre_at(t) -> float`; `is_inside_at(t) -> bool`.
- Constants: `RISE_USEC = 2_000_000` and `SINK_USEC = 2_000_000` (the whole travel), `BAND_HEIGHT = 0.24` (96 of 400 px), `BAND_START = 0.2`, the centre held to `[0.12, 0.88]`, turns `800_000` to `1_600_000` usec apart, speeds `0.1` to `0.275` travel a second.

Rules the tests pin: the first press lifts at time 0 (`judges_starting_press()` true); held, the base rises at 1 / RISE_USEC a usec, let go it sinks at 1 / SINK_USEC, clamped to 0..1, never dropping; inside means `abs(marker - centre) <= BAND_HEIGHT / 2`; each rep is judged at its slot's end with share = time inside / rep length (exact, piecewise between breakpoints: slot ends, the band's turns, the stone reaching the top or rest, and each press or release), miss OUT_OF_BAND for a MISS, height = the base there; after the last rep the stone sinks and the set ends when it is down; presses after the last rep do nothing.

- [ ] **Step 1: Write the failing tests** (a 4 s, 10-rep drill; paths built in the test): `test_the_stone_rises_while_held_and_sinks_when_let_go` (press 0: base 0.5 at 1 s; release 1 s: 0.25 at 1.5 s, 0 at 3 s); `test_the_stone_stops_at_the_top_and_never_drops` (held from 0: 1.0 at 3 s, and the only judgement is rep 0 at 4 s); `test_a_rep_is_judged_by_its_time_in_the_band` (a table on still bands: centre 0.12 with a 0.48 s lift → PERFECT, the whole rep inside; centre 0.5 held throughout → MISS OUT_OF_BAND at 4 s, height 1.0; a hover between 0.25 and 0.3 in a band at 0.3 from 0.6 s → PERFECT; the same, held to the top from 2.9 s → GOOD); `test_a_moving_band_counts_the_time_inside` (the stone left at rest by `press(0)` then `release(0)`, the band from 0.5 at 0 to 0.12 at 2 s and still after: OK, half the rep inside); `test_holding_at_the_top_scores_only_the_band_passing` (band rising from 0.12 at 0 to 0.88 at 4 s, held throughout: the share is the time the band's top half covers the top, a MISS); `test_a_long_gap_judges_each_rep_in_order` (band still at 0.12, a 0.48 s lift, `advance(41 s)`: ten PERFECT at 4, 8 … 40 s, in order); `test_the_set_ends_once_the_stone_has_sunk` (held to the end: `get_end_usec()` 42 s, a press after it judges nothing); `test_the_band_path_stays_on_the_track` (a seed's path: starts at BAND_START, every centre in [0.12, 0.88], every segment's length and speed in range, it outlasts the set; the same seed gives the same path, another seed another).
- [ ] **Step 2: Run it: FAIL.**
- [ ] **Step 3: Implement.** The settle loop steps from the last settled time to `t` across the next breakpoint, adds the exact time inside on each piece (both lines are straight there, so the inside part is one interval of the piece), and judges a slot at its end.
- [ ] **Step 4: Run it and `test_drill_run.gd`: PASS.**
- [ ] **Step 5: Commit.**

### Task 3: TimedPressRun and WaterfallRun, the steady beat

**Files:**
- Create: `scenes/body_refining/drill/timed_press_run.gd`, `scenes/body_refining/drill/waterfall_run.gd`
- Modify: `scenes/body_refining/drill/drill_run.gd` (BEAT → `WaterfallRun`)
- Test: `tests/unit/test_waterfall_run.gd`, `tests/unit/test_drill_run.gd` (its row, and `test_only_the_hold_drills_judge_the_starting_press`)

**Interfaces:**
- Produces: `TimedPressRun extends DrillRun`, a run whose every rep is one target time: `_init(drill: DrillData, targets: PackedInt64Array, reaches: Array[int], no_press_miss: Miss)` (`targets[k]` on the set's clock; `reaches` = perfect, good, OK, zero in usec); `target_usec(rep: int) -> int`; `judges_starting_press()` false. A press judges the next unjudged rep when it falls in that rep's slot (a press in the rest of a judged rep's slot does nothing): share = `share_through(press - target, …)`, a MISS is TOO_EARLY before the target, TOO_LATE after; a rep with no press is a MISS (`no_press_miss`) at its target + the zero reach; `release()` only settles.
- Produces: `WaterfallRun extends TimedPressRun`: `_init(drill: DrillData)`; targets `k × rep + BEAT_AT_USEC`; `BEAT_AT_USEC = 1_500_000`, `LEAD_USEC = 1_500_000` (the blow's fall, for the stage), reaches `50_000, 100_000, 180_000, 260_000`, `no_press_miss` MISSED_BEAT.

- [ ] **Step 1: Write the failing tests** (a 3 s, 10-rep drill): `test_a_press_is_judged_by_its_time_from_the_landing` (a table at the first beat, 1.5 s: on it → PERFECT; ±50 ms → PERFECT; +50.001 ms → GOOD; −100 ms → GOOD; +180 ms → OK; −180.001 ms → MISS TOO_EARLY; +180.001 ms → MISS TOO_LATE; judged at the press); `test_each_blow_lands_on_a_steady_beat` (`target_usec(k)` = 3k + 1.5 s); `test_a_blow_nobody_meets_is_missed` (nothing at 1.76 s − 1 us; MISS MISSED_BEAT at 1.76 s); `test_only_the_first_press_of_a_rep_is_judged` (−0.5 s TOO_EARLY, then a press on the beat judges nothing; the next rep's beat is judged); `test_a_long_gap_judges_each_rep_in_order` (`advance(31 s)`: ten MISSED_BEAT at 3k + 1.76 s); `test_a_set_is_ten_beats_and_ends_after_the_last` (ten presses on the beat: ten PERFECT; `get_end_usec()` 30 s; a press after it judges nothing). `test_drill_run.gd`: `test_only_the_hold_drills_judge_the_starting_press` (table by kind).
- [ ] **Step 2: Run them: FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them: PASS.**
- [ ] **Step 5: Commit.**

### Task 4: FallingLeafRun, a leaf a rep

**Files:**
- Create: `scenes/body_refining/drill/falling_leaf_run.gd`
- Modify: `scenes/body_refining/drill/drill_run.gd` (CATCH → `FallingLeafRun`)
- Test: `tests/unit/test_falling_leaf_run.gd`, `tests/unit/test_drill_run.gd` (its row)

**Interfaces:**
- Produces: `FallingLeafRun extends TimedPressRun`: `_init(drill: DrillData, arrivals: PackedInt64Array)` (when each rep's leaf reaches the palm, from its slot's start); `static func leaf_arrivals(seed: int, reps: int) -> PackedInt64Array` (each in `ARRIVE_MIN_USEC = 900_000` to `ARRIVE_MAX_USEC = 1_500_000`); `offset_px_at(rep: int, t: int) -> float` (the leaf's distance below the palm line, negative above, at `FALL_PX_PER_S = 200.0`, for the stage).
- Constants: the windows as px at that speed and as the usec the judge uses: palm `12` px = `60_000`, fingers `24` = `120_000`, brushed `44` = `220_000`, zero `64` = `320_000`; `no_press_miss` LET_FALL.

- [ ] **Step 1: Write the failing tests** (a 2 s, 10-rep drill, every leaf arriving 1 s into its rep unless a test says): `test_a_catch_is_judged_by_the_leaf_s_distance_from_the_palm` (a table at the first leaf: on the line → PERFECT; ±12 px → PERFECT; 12.001 px below → GOOD; 24 px above → GOOD; 44 px below → OK; just over 44 above → MISS TOO_EARLY, below → MISS TOO_LATE); `test_each_leaf_reaches_the_palm_at_its_own_time` (arrivals 0.9, 1.5, 1.2 s: targets 0.9, 3.5, 5.2 s; `offset_px_at()` 0 there and −20 px 0.1 s before); `test_a_leaf_nobody_catches_falls_past_the_hand` (MISS LET_FALL at the target + 0.32 s, nothing a usec before); `test_a_long_gap_judges_each_rep_in_order` (`advance(21 s)`: ten LET_FALL in order; `get_end_usec()` 20 s); `test_the_leaf_times_stay_in_their_window` (a seed's ten arrivals all in range; the same seed the same, another seed different).
- [ ] **Step 2: Run it: FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and `test_drill_run.gd`: PASS.**
- [ ] **Step 5: Commit.**

## Part B: the board and the picker (after the canvas's approval)

### Task 5: The drills' words, icons and minis

**Files:**
- Modify: `scripts/resource_definitions/body_refining/drill/drill_data.gd` (`play_hint`, `ready_line`, `play_line`, `@export_multiline` not needed: one line each), the four drill `.tres` files (the three fields and `icon`, every value written out), `scripts/utils/stat_display.gd` (Body's and Agility's minis)
- Create: `assets/ui/lacquer/icons/ic_drill_stance_ai.png`, `ic_drill_leaf_ai.png`, `ic_drill_waterfall_ai.png` (16×16, the canvas's); `assets/ui/lacquer/lacquer_mini_body_ai.png`, `lacquer_mini_agility_ai.png` (16×16, the canvas's)
- Test: `tests/unit/test_drill_data.gd` (`test_every_value_is_written_out` reads the new fields; `test_every_drill_has_its_words_and_icon`: each shipped drill's three lines non-empty, its icon set), `tests/unit/test_stat_display.gd` (`test_every_physical_stat_has_a_mini_icon`)

- [ ] **Steps:** failing tests; run (FAIL); implement (Stone Lifting's lines are today's `READY` and `LIFT`, its icon `ic_stone_ai.png`; the others' as the canvas); `--import`; run (PASS); commit.

### Task 6: A capped Body or Agility on the floaters

**Files:**
- Modify: `scenes/body_refining/drill/drill_play.gd` (`_unpaid_parts()` lists every trained stat that took nothing, Strength first, then Health)
- Test: `tests/integration/test_drill_play.gd` (`test_a_capped_minor_stat_pops_capped`: Horse Stance with Body at the cap, a Perfect rep pops "[Body mini] capped", Body's XP unchanged, Health restored; `test_a_capped_strength_pops_capped` stays)

- [ ] **Steps:** failing test; run (FAIL); implement; run (PASS, and `test_body_refining_view.gd`); commit.

### Task 7: Stages: the drill's input picks what DrillPlay shows

**Files:**
- Create: `scenes/body_refining/drill/stages/drill_stage.gd` (`class_name DrillStage extends Control`), `stone_lifting_stage.gd` and `.tscn` (today's Track, rails, Fill and Stone, moved from `drill_play.tscn`)
- Modify: `scenes/body_refining/drill/drill_play.gd` and `.tscn` (the stages as children, the factory, the starting press rule, the floater anchor and pellet origin from the stage), `scenes/body_refining/body_refining_view/body_refining_view.gd` (the drill's `ready_line` / `play_line` in place of `READY` / `LIFT`; `get_pellet_origin()`)
- Test: `tests/integration/test_drill_play.gd`, `tests/integration/test_body_refining_view.gd`

**Interfaces:**
- Produces on `DrillStage`: `input_kind: DrillData.InputKind` (`@export`); `show_rest() -> void`; `show_run(run: DrillRun, t_usec: int) -> void`; `show_judgement(judgement: DrillRun.Judgement) -> void`; `get_floater_anchor() -> Vector2` (DrillPlay's space); `get_pellet_origin() -> Vector2` (the screen's space).
- Produces on `DrillPlay`: `get_pellet_origin() -> Vector2` (replaces `get_stone_global_center()`), `get_stage() -> DrillStage`; the run comes from `DrillRun.for_drill(drill, start_usec)`; the starting press reaches the run only when `judges_starting_press()`.

- [ ] **Step 1: Write the failing tests:** `test_each_drill_shows_its_own_stage` (a table of the four drills: `get_stage().input_kind` is the drill's, the others hidden); `test_the_starting_press_starts_without_a_rep_on_the_press_drills` (Waterfall Tempering: a press at 0 starts the set, nothing is judged, and a press 1.5 s later is Perfect); the view's status tests read the drill's lines (`test_the_status_line_follows_the_set` for Stone Lifting and Horse Stance).
- [ ] **Step 2: Run them: FAIL.** **Step 3: Implement** (the stone tests reach the stone through the stage). **Step 4: PASS**, with the never-trim test. **Step 5: Commit.**

### Task 8: The Horse Stance stage

**Files:**
- Create: `scenes/body_refining/drill/stages/horse_stance_stage.gd` and `.tscn` (Track, Fill, Stone as Stone Lifting's; BandLeft and BandRight 8×96 brackets at the rails' x, BandTop and BandBottom 36×2 edges across the track); `assets/ui/lacquer/body_refining/lacquer_drill_band_ai.png` (a 2-frame strip, 8×96: brass lit, tan dim) and `lacquer_drill_band_edge_ai.png` (2 frames, 36×2)
- Test: `tests/integration/test_drill_play.gd`

- [ ] **Steps:** `test_a_horse_stance_set_scores_the_time_in_the_band` (a seeded run's band read from `get_run()`; holding the stone inside by presses timed from the run's own `band_centre_at()` over one rep scores Perfect and pays 8 Strength XP, 4 Body XP and 4 Health); `test_the_band_lights_while_the_stone_is_in_it` (the brackets' strip frame follows `is_inside_at()`); `test_focus_loss_lets_the_stone_sink`; run (FAIL); implement; run (PASS); commit with the art.

### Task 9: The Falling Leaf stage

**Files:**
- Create: `scenes/body_refining/drill/stages/falling_leaf_stage.gd` and `.tscn` (Leaf, RailLeft, RailRight, PalmLine at the right hand: palm at stage (424, 488)); `assets/ui/lacquer/body_refining/lacquer_drill_leaf_ai.png` (three 48×22 frames: flat, edge-on, mirrored), `lacquer_drill_leaf_rail_ai.png` (8×88), `lacquer_drill_palm_ai.png` (76×6)
- Test: `tests/integration/test_drill_play.gd`

- [ ] **Steps:** `test_a_falling_leaf_catch_pays_and_rests_in_the_palm` (a press at the run's first target: Perfect, 4 Strength XP, 2 Agility XP, 2 Health; the leaf drawn on the palm line until the next rep); `test_a_missed_leaf_falls_on_past_the_hand`; run (FAIL); implement (the sway is drawn only: x = palm + amplitude shrinking to 0 at the palm, the frame from the sway's direction); run (PASS); commit with the art.

### Task 10: The Waterfall Tempering stage

**Files:**
- Create: `scenes/body_refining/drill/stages/waterfall_stage.gd` and `.tscn` (Track, Water a tiled 28-wide fill scrolling down in 2 px steps, Blow, RailLeft, RailRight, StrikeLine at stage y 430); `assets/ui/lacquer/body_refining/lacquer_drill_water_ai.png` (28×32 tile), `lacquer_drill_blow_ai.png` (28×30), `lacquer_drill_beat_rail_ai.png` (8×94), `lacquer_drill_strike_ai.png` (96×6)
- Test: `tests/integration/test_drill_play.gd`

- [ ] **Steps:** `test_a_waterfall_beat_pays_on_the_line` (a press at the first landing: Perfect, 6 Strength XP, 3 Body XP, 3 Health; the blow drawn on the line at its landing, LEAD_USEC × speed above it a lead earlier); run (FAIL); implement; run (PASS); commit with the art.

### Task 11: DrillDrawer and DrillList

**Files:**
- Create: `scenes/body_refining/drill_drawer/drill_drawer.gd` and `.tscn` (TechniqueDrawer's layout copied: Drawer, Face, Socket, Icon, Title, NewSeal, Tag, Detail, a TrainsRow `HFlowContainer` of Strength, Body and Agility entries, HoverFrame, FlashFrame), `scenes/zones/zone_panel/drill_list/drill_list.gd` and `.tscn`
- Test: `tests/integration/test_drill_drawer.gd`, `tests/integration/test_boards_never_trim_text.gd` (BOARD_SCENES gains the drawer)

**Interfaces:**
- Produces: `DrillDrawer` (`setup(drill)`, `refresh()`, `is_in_use()`, `is_new_shown()`, `static detail_text(drill) -> String` = "`play_hint` · `rep_seconds` s reps", `static trained_stats(drill) -> Array[AttributeType]`, signal `height_changed`); `DrillList` (`build()`, `get_content_height()`, `get_slide_rows()`, `get_drawer(drill_id)`, `get_drawer_count()`, signal `layout_changed`; rebuilds on `drill_unlocked`, refreshes on `equipped_drill_changed`).

- [ ] **Steps:** `test_drill_drawer.gd`: `test_a_drawer_shows_its_drill` (name, detail, the Trains row's stats and words, Stone Lifting's Strength only); `test_a_press_equips_its_drill_and_marks_it_seen`; `test_the_drawer_in_use_ignores_a_press`; `test_new_clears_when_the_pointer_leaves`; `test_a_long_name_wraps_and_the_drawer_grows`; `test_the_list_lists_the_learned_drills_in_order` (and rebuilds on an unlock); run (FAIL); implement; `--import`; run (PASS, and the never-trim test); commit.

### Task 12: The chest's drills mode and the board's swap

**Files:**
- Modify: `scenes/zones/zone_panel/zone_panel.gd` and `.tscn` (DrillList beside TechniqueList in SlideClip; `enum ChestMode { ACTIVITIES, TECHNIQUES, DRILLS }`, `set_chest_mode()`, `get_chest_mode()`, `chest_height_for_mode()`, `set_drills_mode()`, `is_drills_mode()`, `get_drill_list()`; the techniques API kept as wrappers), `scenes/ui/main_view/board_transition/board_transition_spec.gd` (`chest_mode: ZonePanel.ChestMode = TECHNIQUES`), `board_transition.gd` (swaps to the spec's mode), `scenes/ui/main_view/main_view.gd` (the instant path), `scenes/ui/main_view/states/body_refining_view_state.gd` (`swaps_chest = true`, `chest_mode = DRILLS`)
- Test: `tests/integration/test_zone_panel.gd`, `tests/integration/test_board_transition.gd`, `tests/unit/test_body_refining_view_state.gd`

- [ ] **Steps:** `test_zone_panel.gd`: `test_drills_mode_lists_the_learned_drills` (header "Drills", "N learned", the activity list hidden) and `test_leaving_drills_mode_shows_the_activities`; `test_board_transition.gd`: `test_a_drills_board_swaps_the_chest_to_the_drills_both_ways` (and the techniques tests unchanged); `test_body_refining_view_state.gd`: `test_the_chest_turns_to_the_drills_and_back` (instant path), `test_the_goals_board_and_the_log_stay`; run (FAIL); implement; run (PASS, with `test_cycling_mode.gd` and every techniques test); commit.

### Task 13: The chest takes its own clicks while the board is up

**Files:**
- Modify: `scenes/body_refining/body_refining_view/body_refining_view.gd` (`var chest: Control`, `_has_point()` false over a showing chest), `scenes/ui/main_view/main_view.gd` (hands the zone panel over with the cabinet)
- Test: `tests/integration/test_body_refining_view.gd`

- [ ] **Steps:** `test_a_press_on_the_chest_picks_and_never_lifts` (a hosted chest and board: a click on a drawer equips its drill and starts no set; a click beside the board still starts one); run (FAIL); implement; run (PASS); commit.

### Task 14: Picking another drill mid-set

**Files:**
- Test: `tests/integration/test_body_refining_view.gd` (and code only if it fails)

- [ ] **Steps:** `test_picking_another_drill_mid_set_keeps_what_was_paid` (two Stone Lifting reps, then equip Horse Stance: their Strength XP and Health stay, `sets_finished` 0, no log line, the session ended, the beads empty, the footer the new drill's `ready_line`, the stage Horse Stance's); run; fix if needed; commit.

### Task 15: Wrap

- [ ] The suite passes (`tests/run_tests.ps1`); a failure from the parallel run is confirmed in one process first.
- [ ] The issue's Done-when checks run on `-- --preset=adventure_open --save=user://dev/runs/drill-roster-play.tres`, by a scripted driver kept out of git and by hand where a check needs the file written; an old save still loads and plays.
- [ ] `git diff main -- project.godot` is empty.
- [ ] The PR closes #106 and ends with `## Docs to update`.

## What was built differently

(Filled in as the build goes.)
