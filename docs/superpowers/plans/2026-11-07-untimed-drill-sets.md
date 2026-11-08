# Untimed Drill Sets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Riverbank Training sets play at the player's own pace: no rep slot and no set clock, each rep starting on the player's press and ending with its own motion, ten reps a set, and a set's XP paid when it ends.

**Architecture:** `DrillRun` keeps its contract (presses, releases and time in, judgements out, exact times on the set's clock) but loses its slots: each run decides when its rep starts (on a press) and ends (its motion). `rep_seconds` becomes Auto's pace only. `BodyRefiningManager.pay_rep()` pays Health at once and stores the rep's XP on the set's `DrillSetResult`; `finish_set()` pays the stored XP, so a set's end (or a stop) is when XP lands. `DrillPlay` marks the rep you are on, flashes the beads' frame when the tenth lands, gates Auto's next set on its pace, and the board pours each bead's XP into the cabinet.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** issue #143 (its Decided section), the approved canvas "Untimed drill sets" (https://claude.ai/artifact/6xWuRBVhASvaXtG8zMJJNV), and its recorded answers on #143 (issuecomment-6713460149), which add "XP comes at the set's end".

## Global Constraints

- A set is `reps_per_set` (10) reps. No rep pays a different amount: only when XP lands changes. No balancing (#111 is paused).
- Each drill keeps its input and its tiers, judged through `DrillRules.judge()`'s shares (0.85 / 0.6 / 0.3).
- Nothing in a set moves on until the player acts, except a rep already started (its own motion). No seconds count down on the board.
- Auto plays a rep each `rep_seconds` (4, 4, 2, 3 s) as a good player would, at `DrillRules.AUTO_RATE`; a set Auto plays takes `reps_per_set × rep_seconds` before the next one starts.
- A set stopped short (board closed, drill switched, Auto toggled, play hidden) keeps its Health, pays its stored XP at the stop with no pellets, and is neither counted nor logged.
- No text is cut off; UI nodes live in `.tscn` scenes; new art ends in `_ai` (only `lacquer_drill_bead_mark_ai.png`). No save change: sets are never saved.
- Copy, verbatim: drawer detail `"%s · %d reps a set"`; Falling Leaf `play_line` "Click a leaf to catch it before it lands. Click anywhere else to shake down the next."; Waterfall Tempering `ready_line` "Press Space or click to send a surge down the falls." and `play_line` "Press to send each surge, and again as it lands on the brass line."
- No living-doc edits (#85); the PR ends with `## Docs to update`.

## Review Focus

1. A press held through a rep's end (a drop, a stance landing) must start nothing until it is released and pressed again: tested in Tasks 2 and 3.
2. A long pause (a minute with the board open) between reps judges nothing on any drill: one test per run (Tasks 2 to 5) and one on the board (Task 6).
3. Quitting the game mid-set must not lose the set's stored XP: the save on close comes first in tree order, so `DrillPlay` pays and saves again on `NOTIFICATION_WM_CLOSE_REQUEST` (Task 6).
4. Two leaves caught out of turn: the ring follows the first bead not lit and the Now strip the reps landed plus one, not the judged count's bead (Task 6), and the pour sends each pellet from its own leaf's bead (Task 8).
5. Auto's pace across sets: the next Auto set waits for `reps × rep_seconds` from the last one's start, and toggling Auto or reopening the board starts one at once (Task 6).

---

## File map

- `scripts/body_refining/drill_set_result.gd`: stored XP (new API).
- `singletons/body_refining_manager/body_refining_manager.gd`: `pay_rep()` stores XP, `finish_set()` pays it, set progress counts landed reps.
- `scenes/body_refining/drill/drill_run.gd`: the slotless contract.
- `scenes/body_refining/drill/stone_lifting_run.gd`, `horse_stance_run.gd`, `falling_leaf_run.gd`, `timed_press_run.gd`, `waterfall_run.gd`: what starts and ends each rep.
- `scenes/body_refining/drill/drill_play.gd` + `.tscn`: the set flow, `%BeadMark`, `%SetFrame`, Auto's pace, the close request.
- `scenes/body_refining/drill/stages/horse_stance_stage.gd` + `.tscn` (incense, `Seconds` removed), `falling_leaf_stage.gd`, `falling_leaf.gd` (hanging leaf), `waterfall_stage.gd` + `.tscn` (`%WaitingSurge`).
- `scenes/body_refining/body_refining_view/body_refining_view.gd`: Health pellets per rep, the pour at the set's end.
- `scenes/body_refining/drill_drawer/drill_drawer.gd`, `scripts/resource_definitions/body_refining/drill/drill_data.gd`, the four drill `.tres`, `scenes/zones/zone_panel/now_strip/now_strip.gd` (docs only).
- `assets/ui/lacquer/body_refining/lacquer_drill_bead_mark_ai.png` (new, 28 x 28).

---

### Task 1: A set stores its XP and pays it when it ends

**Files:** Modify `scripts/body_refining/drill_set_result.gd`, `singletons/body_refining_manager/body_refining_manager.gd`. Test `tests/unit/test_body_refining_manager.gd`.

**Interfaces:**
- Produces on `DrillSetResult`: `store_stat_xp(stat: AttributeType, xp: float) -> void`, `get_stored_stat_xp(stat: AttributeType) -> float`, `take_stored_xp() -> Dictionary` (AttributeType to float, and clears it).
- Produces on `BodyRefiningManager`: `pay_rep(drill, tier, result = null) -> float` pays Health now and stores the rep's XP on `result` (with no result, pays the XP at once, as before); `pay_stored_xp(result: DrillSetResult) -> void` pays each stat's stored XP in one `CharacterManager.add_stat_xp()` call and records what it took (`record_stat_xp(stat, taken, taken < stored)`); `finish_set(result)` calls `pay_stored_xp()`, counts a complete set, ends the session; `get_set_progress()` returns `(rep - 1) / reps`, the reps landed.

- [ ] Rewrite the pay tests: `test_a_rep_in_a_set_pays_health_and_stores_its_xp` (Strength XP unchanged after `pay_rep(_body_drill, PERFECT, result)`, Health up, `result.get_stored_stat_xp(STRENGTH) == 8.0`, Body 4.0); `test_finishing_a_set_pays_its_stored_xp_in_one_payment` (two Perfect reps then `finish_set(result)`: Strength +16, `result.get_stat_xp(STRENGTH) == 16.0`, stored now 0); `test_a_set_cut_short_pays_what_it_stored_and_counts_nothing` (one rep, `finish_set`: XP paid, `sets_finished` unchanged); `test_the_cap_takes_the_stored_xp_at_the_set_s_end` (Strength one XP short of the cap: `is_stat_capped(STRENGTH)` true on the result); `test_a_rep_with_no_set_pays_at_once` (null result: XP paid now); `test_set_progress_counts_the_landed_reps` (`update_set_session(4, 0.5)` gives `get_set_progress() == 0.3`). Keep the Auto, minor-stat and full-Health cases, moved to stored XP.
- [ ] Run `test_body_refining_manager.gd` (one-process command, `-gtest=res://tests/unit/test_body_refining_manager.gd`): new tests FAIL.
- [ ] Implement; docs on both files say the XP lands at the set's end.
- [ ] Run: PASS. Commit `feat(body-refining): pay a set's XP when it ends`.

### Task 2: The slotless run contract, and Stone Lifting

**Files:** Modify `drill_run.gd`, `stone_lifting_run.gd`. Test `tests/unit/test_drill_run.gd`, `tests/unit/test_stone_lifting_run.gd`.

**Interfaces:**
- `DrillRun`: `_auto_rep_usec` (from `rep_seconds`), `get_auto_set_usec() -> int` (`reps × pace`), `rep_progress_at(t) -> float` (virtual, 0 while the drill waits), `get_end_usec()` (base: the last judgement's time once every rep is judged, else -1). `rep_at()` and `judges_starting_press()` are removed. `for_drill()` builds Horse Stance with `HorseStanceRun.band_paths(rng_seed, reps)` (Task 3).
- `StoneLiftingRun`: a lift starts on a press made at or after the last judgement, once the stone is down (a press made while it sets down lifts as it lands); it ends on a release (judged as today, `TOO_LOW` below OK) or at the top (`DROPPED`). No `TOO_LATE`. Auto: rep k lifts at `max(k × pace, stone down)`, lets go `BAND_CENTRE_USEC` later. `rep_progress_at(t)` is the height while lifting, else 0. `height_at()` and the release rule stay (#148 reads them).

- [ ] Tests (stone): replace the slot tests with `test_a_press_lifts_whenever_the_stone_is_down` (release at CENTRE, press at 30 s: lifts at 30 s, judged Perfect at 30 s + CENTRE), `test_a_pause_judges_nothing` (advance 60 s after rep 1: no judgement), `test_a_press_held_through_a_drop_lifts_nothing` (hold from 0: DROPPED at 2 s; still held at 10 s, not lifting; release and press at 11 s: lifts), `test_a_press_made_while_the_stone_sets_down_lifts_as_it_lands` (press at CENTRE + 0.4 s: lifts at CENTRE + 0.6 s), `test_a_set_is_ten_reps_and_ends_when_the_last_stone_is_down` (reps pressed 2 s apart: end = last release + 0.6 s), `test_rep_progress_is_the_lift`. Keep share, release-judging, drop, rest and set-down tests.
- [ ] Tests (contract): `test_the_first_press_is_every_drill_s_first_input` replaces the starting-press test (Task 2 covers the stone: `is_lifting()` after `press_at(0, point)`; Tasks 3 to 5 add their kinds); `test_auto_keeps_its_pace` replaces `test_rep_progress_follows_the_slot` (for each kind, rep k's judgement lands in `[k × pace, (k + 1) × pace)` and `get_auto_set_usec() == reps × pace`).
- [ ] Run both files: FAIL. Implement. Run: PASS. Commit `feat(body-refining): lift the stone on the player's press, with no slot`.

### Task 3: Horse Stance, a rep per stance

**Files:** Modify `horse_stance_run.gd`. Test `tests/unit/test_horse_stance_run.gd`.

**Interfaces:**
- Constants: `BAND_START = 0.12` (each rep's arc starts here, its near edge at the standing needle); `HOLD_USEC = 2_000_000`; `OUT_LIMIT_USEC = 4_666_667` (`HOLD × (1 / OK_SHARE − 1)`, rounded up); `PATH_USEC = 7_000_000`; the rest unchanged.
- `_init(drill, paths: Array)`: `paths[k % size]` is rep k's `[PackedInt64Array times, PackedFloat64Array centres]`, times from the rep's start. `static band_paths(rng_seed, reps) -> Array` (one RNG, a path per rep from `BAND_START`, each `PATH_USEC` long); `band_path(rng: RandomNumberGenerator, path_usec) -> Array`.
- A press made at or after the last judgement, with the needle standing, starts a rep (held while it rises: starts the moment it stands). During a rep the needle sinks or rises with the hold. The rep lands the moment its time inside reaches `HOLD_USEC`: share `HOLD / (landing − start)`. It is a MISS the moment its time out reaches `OUT_LIMIT_USEC`, `TOO_DEEP` if it spent at least as long deep as shallow, else `TOO_SHALLOW`. After either the needle rises whatever the press, and the arc glides linearly to `BAND_START`, arriving as the needle stands. Between reps the arc rests at `BAND_START`. Exact times: step between turns (path points, needle stops, presses), and inside each straight step find where inside or out time reaches its mark.
- Queries: `marker_at(t)`, `band_centre_at(t)`, `is_inside_at(t)`, `is_rep_in_play() -> bool`, `hold_progress() -> float` (inside / HOLD for the rep in play, else 0), `rep_progress_at(t)` = `hold_progress()`, `get_end_usec()` (last judgement plus the stand). Auto: on the 50 ms grid, starts rep k at `k × pace` (releasing first if it holds), and tracks the arc's centre while a rep runs.

- [ ] Tests (paths given per test): `test_a_rep_lands_once_the_needle_has_held_the_arc` (still arc at 0.88, hold from 0: lands at 3.52 s, OK); `test_a_rep_inside_from_the_start_is_perfect` (still arc at BAND_START, press then release at 0.1 s: lands at 2 s, PERFECT); `test_a_rep_out_of_the_arc_too_long_is_a_miss` (still arc at 0.88, press and release at 0.1 s: MISS TOO_SHALLOW at 4_666_667; still arc at BAND_START held: TOO_DEEP at 0.48 s + OUT_LIMIT); `test_after_a_rep_the_needle_stands_and_the_arc_returns` (glide checked at the stand's middle and end); `test_a_press_held_through_the_landing_sinks_nothing`; `test_a_press_made_while_standing_up_sinks_once_standing`; `test_a_pause_judges_nothing_and_the_arc_stays_still`; `test_the_set_ends_once_the_needle_stands_after_the_tenth`; `test_hold_progress_follows_the_time_inside`; `test_the_band_paths_start_at_the_top_and_stay_on_the_gauge` (same seed, same paths). Keep the needle-speed and needle-stop tests.
- [ ] Add the stance case to `test_the_first_press_is_every_drill_s_first_input` (`is_rep_in_play()`).
- [ ] Run: FAIL. Implement. Run: PASS. Commit `feat(body-refining): make each Horse Stance rep one stance`.

### Task 4: Falling Leaf, shaken down one at a time

**Files:** Modify `falling_leaf_run.gd`. Test `tests/unit/test_falling_leaf_run.gd`.

**Interfaces:**
- `Leaf.drop_usec` is -1 until shaken. `FIRST_DROP_X = 220.0` (leaf 0 hangs at the branch's middle), `MAX_FALLING = 2`. `leaf_paths(rng_seed, drill)` sets no drop times.
- `press_at(t, point)`: the nearest airborne leaf within `REACH_PX` is caught (tiers as today); else the press shakes: the next undropped leaf drops at `t` if fewer than `MAX_FALLING` fall. `press(t)` (no aim) shakes. Landed leaves are MISS `LANDED` at `drop + FALL_USEC`.
- Queries: `is_dropped(i)`, `leaf_position(i, t)` (hanging at `(x, top_y)` before its drop), `is_airborne`, `is_on_ground`, `is_judged`, `hanging_leaf_at(t) -> int` (the next undropped leaf when a shake would drop it, else -1), `rep_progress_at(t)` (the earliest-dropped airborne leaf's fall share), `get_end_usec()` (the last judgement). Auto: shake leaf k at `k × pace`, catch it at its middle `AUTO_CATCH_USEC` later.

- [ ] Tests: `test_the_first_press_shakes_down_the_first_leaf`, `test_a_press_away_from_the_leaves_drops_the_next`, `test_at_most_two_leaves_fall_at_once`, `test_no_leaf_drops_on_its_own` (60 s after the first lands: one judgement, LANDED, nothing else dropped), `test_the_next_leaf_hangs_until_shaken` (`hanging_leaf_at`, `leaf_position` before the drop), `test_the_first_leaf_hangs_at_the_branch_s_middle`, `test_a_set_ends_with_its_tenth_leaf`; adapt the catch, nearest, near-miss, landing, sway and out-of-turn tests to shaken leaves; drop the far-click-does-nothing test (a far click shakes now).
- [ ] Add the leaf case to the first-press test (`is_dropped(0)`).
- [ ] Run: FAIL. Implement. Run: PASS. Commit `feat(body-refining): shake down each Falling Leaf on a press`.

### Task 5: Waterfall Tempering, each surge sent by a press

**Files:** Modify `timed_press_run.gd`, `waterfall_run.gd`. Test `tests/unit/test_waterfall_run.gd`.

**Interfaces:**
- `TimedPressRun._init(drill, lead_usec, reaches, no_press_miss)`. A press with no rep in play starts the next rep (target `t + lead`); the next press is judged (tiers as today; TOO_EARLY / TOO_LATE); no press by `target + reaches[3]` is `no_press_miss` there. `target_usec(rep)` (-1 until sent), `rep_in_play() -> int` (-1 when the next waits), `rep_progress_at(t)` (`(t − start) / lead`, clamped), `get_end_usec()` (base). Auto: send rep k at `k × pace`, press at its target.
- `WaterfallRun`: `super(drill, LEAD_USEC, reaches, BUCKLED)`; `BEAT_AT_USEC` goes.

- [ ] Tests: `test_a_press_sends_the_waiting_surge`, `test_a_brace_is_judged_by_its_time_from_the_landing` (send at 0, cases around 1.5 s), `test_a_surge_nobody_braces_buckles` (at 1_760_000), `test_the_press_after_a_judged_rep_sends_the_next`, `test_no_surge_comes_on_its_own`, `test_a_release_judges_nothing`, `test_a_set_ends_with_its_tenth_surge`.
- [ ] Add the surge case to the first-press test (`rep_in_play() == 0`).
- [ ] Run: FAIL. Implement. Run: PASS. Commit `feat(body-refining): send each Waterfall surge on a press`.

### Task 6: The set on the board

**Files:** Modify `drill_play.gd`, `drill_play.tscn`; create `assets/ui/lacquer/body_refining/lacquer_drill_bead_mark_ai.png` (the canvas's 28 x 28 ring). Test `tests/integration/test_drill_play.gd`.

**Interfaces:**
- Nodes: `%BeadMark` (TextureRect, the ring, hidden by default, 2 px up and left of a bead), `%SetFrame` (a `lacquer_frame_overlay.tscn` around `%Beads`, 10 px out each side). `SET_FLASH_TIMES = 2`.
- Every press goes to the run (`press_at(t, point)`), the first starting the set. Each frame: `update_set_session(mini(judged + 1, reps), run.rep_progress_at(t))`; the mark stands on the first bead not lit while a set runs, hidden otherwise. `_finish()`: `finish_set(result)` (pays the XP), `%SetFrame.flash(SET_FLASH_TIMES)`, `set_completed`; an Auto set sets `_auto_ready_usec = start + run.get_auto_set_usec()`, and Auto starts its next set only once the clock reaches it (0 after `setup()`, `set_auto_play()` and a stop). `stop_set()` calls `finish_set(result)` for a running set. `rep_judged(judgement, health, stat_xp)`: `stat_xp` is the XP the rep stored. A scored rep pops "capped" for each trained stat `CharacterManager.is_stat_capped()` and "full" when it restored no Health. `get_bead_origin(rep: int) -> Vector2` (the bead's middle, screen space). `NOTIFICATION_WM_CLOSE_REQUEST` mid-set: `pay_stored_xp(result)`, then `PersistenceManager.autosave()`.

- [ ] Tests: `test_a_pause_judges_nothing_and_the_next_press_plays_on` (two stone reps, 60 s: two beads, rep 3 on the next press); `test_the_ring_marks_the_rep_you_are_on` (bead 0 at the first press, bead 2 after two reps, hidden after the set); `test_the_tenth_rep_flashes_the_set_frame`; `test_reps_pay_health_and_the_set_s_end_pays_xp`; `test_stopping_mid_set_pays_the_stored_xp_and_counts_nothing`; `test_closing_the_window_mid_set_pays_the_stored_xp`; `test_the_first_press_drops_a_leaf_and_sends_a_surge` (replaces the starting-press test); `test_the_session_counts_landed_reps`; `test_auto_waits_for_its_pace_before_the_next_set` (Stone Lifting: no new set at 38 s, a new one at 40 s); adapt the Auto, pop and capped tests.
- [ ] Run: FAIL. Implement. Run: PASS. Commit `feat(body-refining): mark the rep in play and end each set on its tenth`.

### Task 7: Stages that wait for the player

**Files:** Modify `horse_stance_stage.gd` + `.tscn` (`Seconds` removed), `falling_leaf_stage.gd`, `falling_leaf.gd`, `waterfall_stage.gd` + `.tscn` (`%WaitingSurge`, a copy of `Surge` at the ledge). Test `tests/integration/test_drill_play.gd`.

**Interfaces:**
- Horse Stance: the stick shows `1 − (judged + hold_progress()) / reps` of its height (2 px steps); whole at rest; `SECONDS_FORMAT` goes.
- Falling Leaf: `FallingLeaf.show_hanging(point)` (frame `HANGING_FRAME = 2`, no trail). At rest leaf 0 hangs at `(FIRST_DROP_X, branch y)`; during a set `run.hanging_leaf_at(t)` hangs at its position.
- Waterfall: `%WaitingSurge` shows at the ledge (`LEAD_PX` over the line) at rest and while `rep_in_play()` is -1 with reps left; `%Surge` draws the latest sent surge (riding, or a Miss falling `CRASH_PX` past the line); a braced surge is gone.

- [ ] Tests: `test_the_incense_burns_only_in_the_arc`, `test_horse_stance_shows_no_seconds`, `test_the_next_leaf_hangs_until_shaken`, `test_the_surge_waits_at_the_ledge_until_sent`; replace the old incense and surge tests.
- [ ] Run: FAIL. Implement. Run: PASS. Commit `feat(body-refining): show the leaf and surge that wait for the player`.

### Task 8: Health per rep, XP poured at the set's end

**Files:** Modify `body_refining_view.gd`. Test `tests/integration/test_body_refining_view.gd`.

**Interfaces:** `_on_rep_judged()` sends only Health pellets (by tier, as today) and records `[judgement.rep, stat_xp]`; `_on_set_started()` clears it; `_on_set_completed()` pours: for each stat the result took XP for, one pellet per bead that stored some, from `DrillPlay.get_bead_origin(rep)`, carrying `taken × stored / total stored`, held and released on the cabinet as today. No pour for a stopped set or while hidden.

- [ ] Tests: `test_a_rep_sends_only_health_pellets`; `test_the_set_s_end_pours_xp_from_the_beads` (one Strength pellet per scored bead to Strength's cell); `test_the_pour_carries_only_what_was_taken` (near the cap); `test_no_strength_pellets_at_the_cap`; `test_closing_mid_set_pays_the_stored_xp`; adapt the existing pellet tests.
- [ ] Run: FAIL. Implement. Run: PASS. Commit `feat(body-refining): pour a set's XP from its beads`.

### Task 9: Words and data

**Files:** Modify `drill_drawer.gd`, `drill_data.gd`, `falling_leaf.tres`, `waterfall_tempering.tres`, `now_strip.gd` (docs). Test `tests/integration/test_drill_drawer.gd`, `tests/unit/test_drill_data.gd`, `tests/integration/test_zone_panel.gd`.

- [ ] Tests: the drawer's detail reads "Keep the needle in the brass · 10 reps a set"; the two drills' lines read the Global Constraints' copy; the strip while drilling shows the rod at `(rep − 1) / reps`.
- [ ] Implement (`DETAIL_FORMAT`, `rep_seconds` doc as Auto's pace, the lines, NowStrip's doc). Run: PASS. Commit `feat(body-refining): say what a set is in the drawers and lines`.

### Task 10: Verify and ship

- [ ] `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`: all green (rerun any failure in one process).
- [ ] Done-when checks on `-- --preset=harden_core --save=user://dev/runs/drill-sets-untimed.tres`, and an old save loading.
- [ ] Merge `main` once, rerun the suite, open the PR closing #143 with `## Docs to update`.

## What was built differently

- **XP at the set's end** came from Lionel's review of the canvas ("Yes, add it", then "actually just implement"), so no canvas board draws it. The set-done beat keeps the canvas's brass frame, and the pour from the beads plays beside it, so a set that pays no XP (all misses, a capped Strength) still has its beat.
- **Closing the window mid-set** pays the stored XP and saves again from `DrillPlay`: `PersistenceManager`, the first autoload, saves on the close request before the play hears it.
- **Horse Stance's arc starts at 0.12**, `BAND_LOW`, around the standing needle (it started at 0.2), as the approved answer says; otherwise the sink into the arc would eat half a Perfect's allowance. Its gauge lights brass only while a rep's needle is in the arc: between reps the resting arc touches the standing needle.
- **A stopped set** pays its XP and ends the session itself, uncounted, unless its last rep has landed: a set stopped while its tenth stone sets down, or while the player stands from the tenth stance, is finished (paid, counted, reported, a perfect one unlocking Auto). The final review caught the first version dropping it.
- **The per-rep "capped" pop** reads `CharacterManager.is_stat_capped()` at the rep, since a rep's XP is only stored; a set that crosses the cap shows "capped" on its result line only.
- **Built in a different order than the plan's tasks said:** `rep_at()` and `judges_starting_press()` left the contract with their last callers (Tasks 6 and 7), and the base `get_end_usec()` changed with `TimedPressRun` (Task 5), so every commit compiles; `FallingLeafRun`'s own `get_end_usec()` went, being the new base. The field `_rep_usec` keeps its name, documented as Auto's pace.
- **Not tested:** the two drills' new footer copy (CLAUDE.md: exact wording is checked by eye).
- **The Now strip** needed no code: its ring and rod read the session, whose set progress now counts the reps landed (Task 1). Only its docs changed.
- **Merging main** brought #148's Stone Lifting target; its "a missed slot leaves no mark" check now covers the drop alone, since a slot nobody lifts in no longer exists.
- **In the scripted Done-when run** a steady set took 20.9 s (Stone Lifting), 30.3 s (Horse Stance), 14.6 s (Falling Leaf) and 17.7 s (Waterfall Tempering); Auto started Stone Lifting sets at 0, 40 and 80 s.
