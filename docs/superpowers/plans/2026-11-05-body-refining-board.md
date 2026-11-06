# Body Refining Board Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stats rework chunk #100 (tracked in #85): a Riverbank Training card in Spirit Valley's Cultivate group opens the body refining board in the map gap, where the player plays sets of Stone Lifting; every scored rep pays through `BodyRefiningManager.pay_rep` and sends Strength and Health pellets to the cabinet, so Strength can reach the cap in play and the breakthrough opens.

**Architecture:** A new zone action type, BODY_REFINING, runs through ActionManager like cycling (start and stop signals, a branch in each dispatch) and opens `BodyRefiningView` through `BodyRefiningViewState`, which opens and closes the board through `BoardTransition` like `CyclingViewState` and takes input like `TribulationViewState`. `DrillRun` is the pure judge of one set at exact microsecond times (modelled on `TribulationRun`); `DrillPlay` is the Stone Lifting stage that drives it from an injectable clock, pays each judged rep and reports it; the view sends the pellets, writes the lines and keeps the cabinet in view. A transient set session on `BodyRefiningManager` feeds the Now strip, as `CyclingManager`'s cycle session does.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1.

**Spec:** issue #100's Decided list; the approved "Body refining board" canvas (https://claude.ai/artifact/JgQ54brroi9CTLVKsYjrJB), whose answers are below and on #100 (issuecomment-6676292424); #97's drill answers (issuecomment-6673330078). The master plan's Phase 5 outline (Tasks 5.6, 5.10, 5.11, 5.13, 5.21 to 5.23) for shape only: where it differs, the issue and the canvas win.

## The canvas's answers (approved by Lionel on 2026-11-05, as drawn, after one round: "Use icons. Use the stat icons where possible.")

- **Action:** Riverbank Training, Cultivate after Wilderness Cycling, ACTIVE, unlocked on `q_fill_core_completed`, a stone-weight icon.
- **Card:** detail "[Health heart] Health  [Strength icon] Strength XP"; NEW on unlock and on any drill unlock; pulled out and RUNNING while its board is up.
- **Icons:** Strength's stat icon as a 16 px mini drawn from `strength_icon.png` (`lacquer_mini_strength_ai.png`), and the dock's Health heart (`lacquer_mini_health_ai.png`), on the board, the card, the Now strip, the floaters and the footer result. The log keeps words.
- **Board:** the cycling board's frame and size in the map gap; header: action, drill, Esc, close; under them "Perfect rep · [Strength] +6 XP · [Health] +4" ("[Strength] capped" in brass at the cap); the carved figure with its arms rimmed in brass; the stone on a jade column in a carved track with the tiers' rails; ten rep beads; the footer line. The chest, the Goals board and the log stay.
- **Input:** hold Space or the left button, a `drill_press` action; while the board is up a press anywhere is the drill's.
- **A rep:** 4 s; 10 reps a set, the first lift starts it; the stone reaches the top in 2 s; judged by where its base stops: brass Perfect (±0.07 s), cream Good, tan OK, else Miss: Too low, Dropped (held past the top), Too late (no lift).
- **Now strip:** shows the running set: Riverbank Training, [Health] "+4 / rep", Stone Lifting, "Rep 4 / 10" ("10 reps" between sets), the ring over each rep, the rod over the set.
- **Pellets:** Perfect 4, Good 3, OK 2 of each kind; a Miss none; none of a kind that paid nothing.
- **Floaters:** the tier in its colour (brass, cream, tan; a Miss crimson with its reason); under a scored tier, in tan, "[Health] full" and/or "[Strength] capped".
- **Lines:** footer READY "Hold Space or the mouse button to lift the stone.", during a set "Let go with the stone in the brass band.", after one "Last set · [Strength] +48 XP · [Health] +32 · 6 / 10 perfect" ("Last set · Perfect set · …" for ten Perfect reps) until the next lift; log "Set · +48 Strength XP · +32 Health" ("Strength capped", "Health full" in place of a part that paid nothing); nothing for a set stopped midway.
- **Sets counted:** `sets_finished` in the play stats; the next save version at merge.

## Global Constraints

- `CLAUDE.md`'s GDScript standards: explicit types, `##` docs on public functions, private names start with `_`, no `print()` (use `Log`).
- UI nodes live in `.tscn` scenes with theme variants; scripts set text, textures, visibility and state colours only.
- No text is ever cut off: Labels that can run long wrap and their board grows; the new board and presenter join `BOARD_SCENES` in `test_boards_never_trim_text.gd`; no file joins `KNOWN_TRIMMERS`.
- A new log line fits one log line while the log board trims (RL-05).
- Lacquer look: one 2x pixel grid, even positions and sizes, nearest filtering, no glow, gradient, fade or tint; motion in 2 px steps.
- New art ends in `_ai`; Lionel's files (no `_ai`) are never edited.
- `project.godot` changes are committed alone, and `git diff project.godot` shows the `[dialogic]` directory keys intact.
- Claimed at merge: `ZoneActionData.ActionType.BODY_REFINING = 8` and `SaveGameData.CURRENT_VERSION = 5` (renumber while merging `main` if another chunk took either).
- Screens never print "minor".
- Tests call production code, swap in a fresh `SaveGameData` and put the original back in `after_each()`, use no GUT doubles; timed play is tested at exact `clock_usec` times.
- One test file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`. Suite: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.

## Review Focus

1. **Space and the mouse together.** A lift started by one kind of input (key or mouse button) is let go only by that kind coming up; the other kind's release does nothing (Task 8: `test_a_mouse_release_leaves_a_key_lift`).
2. **Focus loss mid-lift.** Alt-tabbing away while the stone rises lets it go at that moment, judged there (Task 8: `test_focus_loss_lets_the_stone_go`).
3. **A long frame.** A hitch never changes a result: a drop is judged 2 s after the lift and each rep nobody lifted at its slot's end, in order, however late the frame comes (Task 7: `test_a_long_gap_judges_each_slot_in_order`).
4. **Closing mid-set.** Esc, the close button, another action or a dev session switch keeps the reps already paid, writes no result or log line, counts no set and ends the set session (Task 9: `test_closing_mid_set_keeps_what_was_paid`; Task 12).
5. **Reaching a limit mid-rep.** The rep that reaches the Strength cap sends pellets only for the XP Strength took, and the rep that tops Health up sends pellets only for what it restored; "capped" and "full" show only when that part took nothing (Task 6: `test_a_rep_that_reaches_the_cap_records_what_strength_took`; Task 9: `test_pellets_carry_only_what_was_taken`).

---

### Task 1: The drill_press input action

**Files:**
- Modify: `project.godot` (`drill_press` after `tribulation_press`: Space by physical keycode 32, and the left mouse button, as `tribulation_press` has them)
- Test: `tests/unit/test_drill_run.gd` (created here, first test only)

- [x] **Step 1: Write the failing test** `test_drill_press_is_space_and_the_left_button`: `InputMap.has_action(&"drill_press")`; its events are one `InputEventKey` with `physical_keycode == KEY_SPACE` and one `InputEventMouseButton` with `button_index == MOUSE_BUTTON_LEFT`.
- [x] **Step 2: Run it: FAIL** (no action).
- [x] **Step 3: Add the action** to `project.godot` by copying `tribulation_press`'s block under the new name.
- [x] **Step 4: Run it: PASS.** `git diff project.godot` shows only the new action.
- [x] **Step 5: Commit `project.godot` alone**, then the test file with Task 7.

### Task 2: The BODY_REFINING type through ActionManager

**Files:**
- Modify: `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd` (`BODY_REFINING` appended after `TRIBULATION`, commented "Appended: saved .tres files store the number")
- Create: `scripts/resource_definitions/zones/zone_action_data/body_refining_action_data/body_refining_action_data.gd`
- Modify: `singletons/action_manager/action_manager.gd`, `scripts/utils/zone_action_groups.gd`
- Test: `tests/integration/test_body_refining_action_data.gd`, `tests/unit/test_zone_action_groups.gd`, `tests/integration/test_idle_action_resolution.gd`

**Interfaces:**
- Produces: `class_name BodyRefiningActionData extends ZoneActionData` whose `_init()` sets `action_type = ActionType.BODY_REFINING`; ActionManager `signal start_body_refining(action_data: BodyRefiningActionData)` and `signal stop_body_refining()`.

- [x] **Step 1: Write the failing tests.** `test_body_refining_action_data.gd` (fresh save each test, every action stopped after): `test_body_refining_type_is_eight` (`ZoneActionData.ActionType.BODY_REFINING == 8`, `BodyRefiningActionData.new().action_type == BODY_REFINING`); `test_selecting_starts_body_refining_and_stopping_stops_it` (watch ActionManager's signals: select emits `start_body_refining` once with the action, `stop_action()` emits `stop_body_refining` once, the current action is null after); `test_stopping_runs_the_completion_effects` (a fixture action with an `AwardResourceEffectData` of 10 gold in `success_effects`: gold +10 after the stop); `test_it_pauses_the_idle_action_and_stopping_resumes_it` (Aura Well running via `aura_well_discovered`; selecting body refining stops it; `stop_action()` resumes it). Rows: `test_group_of_each_type` gains `BODY_REFINING → CULTIVATE`, `test_mode_tags` gains `"ACTIVE"`, `test_is_idle_action_is_foraging_and_training_only` gains `BODY_REFINING: false`.
- [x] **Step 2: Run the three files: FAIL.**
- [x] **Step 3: Implement.** ActionManager: the two signals; `_execute_body_refining_action(action_data: BodyRefiningActionData)` emits the start; `_stop_body_refining_action(successful: bool)` emits the stop then `_process_completion_effects(successful)`; a branch each in `_execute_action()` and `_stop_executing_current_action()`, as cycling's; `stop_action()`'s doc lists body refining among session actions. ZoneActionGroups: CULTIVATE and "ACTIVE".
- [x] **Step 4: Run the three files: PASS.**
- [x] **Step 5: Commit.**

### Task 3: Riverbank Training in Spirit Valley, and NEW on a drill unlock

**Files:**
- Create: `assets/ui/lacquer/icons/ic_stone_ai.png` (16×16 stone weight, the canvas's icon), `resources/zones/spirit_valley_zone/zone_actions/body_refining_action.tres`
- Modify: `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` (in `all_actions` right after the cycling action), `singletons/zone_manager/zone_manager.gd`
- Test: `tests/unit/test_body_refining_content.gd`, `tests/integration/test_zone_panel.gd` (`test_count_label`: "11 here"), `tests/integration/test_seen_actions.gd`

**Interfaces:**
- Produces: action id `"riverbank_training_action"`, name "Riverbank Training", `action_type = 8`, description "Lift, hold and temper your body by the river.", icon `ic_stone_ai.png`, `unlock_conditions = [q_fill_core_completed.tres]`, `max_completions = 0`.

- [x] **Step 1: Write the failing tests.** `test_body_refining_content.gd`: `test_the_file_writes_out_its_values` (the text holds `action_type = 8` and `max_completions = 0`); `test_it_unlocks_with_the_adventure` (one condition, id `q_fill_core_completed`); `test_spirit_valley_lists_it_after_cycling` (index in `all_actions` = cycling's + 1; `ZoneActionGroups.group_of()` CULTIVATE). `test_seen_actions.gd`: `test_a_drill_unlock_lights_the_body_refining_card` (mark the action seen; `BodyRefiningManager.unlock_drill("horse_stance")`; `ZoneManager.is_action_seen(id)` is false). `test_count_label` expects "11 here".
- [x] **Step 2: Run them: FAIL.**
- [x] **Step 3: Implement.** Draw the icon (a 16×16 native icon in ink and the locked-veil greys, shown at 2x in the card's socket like the other `ic_*_ai.png`); write the `.tres`; add it to `all_actions`; ZoneManager connects `BodyRefiningManager.drill_unlocked` to `_on_drill_unlocked(_drill: DrillData)`, which marks every BODY_REFINING action unseen, as `_on_technique_unlocked` does for cycling.
- [x] **Step 4: Run them, and `test_story_route.gd`: PASS.**
- [x] **Step 5: Commit** the icon (and its `.import`), the two resources, ZoneManager and the tests.

### Task 4: The card

**Files:**
- Create: `assets/ui/lacquer/lacquer_mini_strength_ai.png` (16×16 mini drawn from `strength_icon.png`), `scenes/zones/zone_action_button/presenters/body_refining_presenter.gd` and `.tscn`
- Modify: `scripts/utils/stat_display.gd`, `scenes/zones/zone_action_button/zone_action_button.gd`, `tests/integration/test_boards_never_trim_text.gd` (BOARD_SCENES gains the presenter)
- Test: `tests/integration/test_zone_action_cards.gd`, `tests/unit/test_stat_display.gd` (create if missing)

**Interfaces:**
- Produces: `StatDisplay.mini_icon_of(stat: AttributeType) -> Texture2D` (Strength's mini; any other stat logs an error and returns null until #106 draws theirs); `BodyRefiningPresenter` in `ZoneActionButton.PRESENTER_SCENES[BODY_REFINING]`.

- [x] **Step 1: Write the failing tests.** `test_body_refining_detail_shows_health_and_strength_xp` (a card for the action: texts hold "Health" and "Strength XP"; the two icons are `lacquer_mini_health_ai.png` and `StatDisplay.mini_icon_of(STRENGTH)`; the card is `MIN_HEIGHT` tall); `test_a_running_body_refining_card_is_tagged` (select the action: tag "RUNNING", the drawer at `RUNNING_OFFSET`; stop it: "ACTIVE"); `test_running_session_action_is_not_tagged_running` stays green for cycling. `test_stat_display.gd`: `test_strength_has_a_mini_icon`.
- [x] **Step 2: Run them: FAIL.**
- [x] **Step 3: Implement.** The presenter's scene: an `HFlowContainer` (h separation 12) holding two instances of `forage_yield.tscn`, `HealthReward` and `StrengthReward`; `setup()` reparents the flow into the detail slot, sets each icon and text ("Health", "Strength XP") and relays the card out. ZoneActionButton: `_is_running_action()` replaces `_is_running_idle_action()`: current, and an idle action or BODY_REFINING (the chest stays in view under its board); the class doc says so.
- [x] **Step 4: Run them and the never-trim test: PASS.**
- [x] **Step 5: Commit.**

### Task 5: Sets in the play stats, save version 5

**Files:**
- Modify: `singletons/persistence_manager/play_stats_data.gd` (`@export var sets_finished: int = 0` after `cycles_finished`, `count_set_finished()`, `_to_string`), `singletons/persistence_manager/save_game_data.gd` (`CURRENT_VERSION = 5`, a stamp step)
- Test: `tests/unit/test_play_stats.gd`, `tests/unit/test_save_migration.gd`, `tests/unit/test_save_round_trip.gd`

- [x] **Step 1: Write the failing tests.** `test_play_stats.gd`: `_counts()` and `_record_everything()` gain the set count; `test_count_set_finished_counts_one` and that it records nothing while paused (join the existing paused table). `test_save_migration.gd`: `test_v5_gives_an_old_save_no_sets` (a version 4 save: `sets_finished` 0, version stamped 5). `test_save_round_trip.gd`: `_full_save()` sets `stats.sets_finished = 7`.
- [x] **Step 2: Run them: FAIL.**
- [x] **Step 3: Implement.** The step in `_run_version_steps()`: `if save_version < 5: save_version = 5`, commented "Version 5 added the play stats' set count, whose default of 0 suits an old save, so the step moves nothing".
- [x] **Step 4: Run them: PASS.**
- [x] **Step 5: Commit.**

### Task 6: What a set paid, and the set session

**Files:**
- Modify: `scripts/body_refining/drill_set_result.gd`, `singletons/body_refining_manager/body_refining_manager.gd`
- Test: `tests/unit/test_drill_rules.gd` (its DrillSetResult section), `tests/unit/test_body_refining_manager.gd`

**Interfaces:**
- Produces on `DrillSetResult`: `add_rep(tier: Tier, health: float)` (kept), `record_stat_xp(stat: AttributeType, taken: float, capped: bool)`, `get_stat_xp(stat) -> float`, `is_stat_capped(stat) -> bool`, `get_rep_health(index: int) -> float`, `is_health_full() -> bool` (a scored rep was recorded and the set restored no Health), `log_line() -> String`.
- Produces on `BodyRefiningManager`: `pay_rep()` records each stat's taken XP in the result (`taken < paid` means capped); `perfect_rep_health(drill: DrillData) -> float` (`DrillRules.health_for_rep(drill, PERFECT, Strength total)`); `start_set_session(reps: int)`, `update_set_session(rep: int, rep_progress: float)` (rep counted from 1), `end_set_session()`, `is_set_running() -> bool`, `get_set_rep() -> int`, `get_set_reps() -> int`, `get_rep_progress() -> float`, `get_set_progress() -> float` (`(rep - 1 + rep_progress) / reps`, 0 when none runs); `finish_set(result: DrillSetResult)` counts a complete set in the play stats, then ends the session. The session is transient, never saved.

- [x] **Step 1: Write the failing tests.** DrillSetResult: `test_log_line_reads_what_the_set_paid` (table: "Set · +48 Strength XP · +32 Health"; capped "Set · Strength capped · +30 Health"; full "Set · +60 Strength XP · Health full"; all misses "Set · +0 Strength XP · +0 Health"); `test_health_full_needs_a_scored_rep_that_restored_nothing`. Manager: `test_a_rep_records_the_xp_each_stat_took`; `test_a_rep_that_reaches_the_cap_records_what_strength_took` (Strength one XP short of the cap: the result holds 1 taken and Strength capped); `test_perfect_rep_health_follows_strength` (4.0 at Lv 1, 7.6 at Lv 10 with Stone Lifting); `test_the_set_session_snapshot` (start 10, update 4 and 0.5: rep 4, progress 0.35; end: not running, all 0); `test_finish_set_counts_a_complete_set_only` (a 10-rep result counts 1; a 4-rep one counts nothing; both end the session).
- [x] **Step 2: Run them: FAIL.**
- [x] **Step 3: Implement**, keeping `pay_rep()`'s return (the Health restored) and its order (Health first, at the Strength before the rep's XP).
- [x] **Step 4: Run both files: PASS.**
- [x] **Step 5: Commit.**

### Task 7: DrillRun, the judge of a set

**Files:**
- Create: `scenes/body_refining/drill/drill_run.gd`
- Test: `tests/unit/test_drill_run.gd`

**Interfaces:**
- Produces: `class_name DrillRun extends RefCounted`; `enum Miss { NONE, TOO_LOW, DROPPED, TOO_LATE }`; inner `class Judgement` with `rep: int` (from 0), `tier: DrillRules.Tier`, `miss: Miss`, `height: float` (0 to 1 of the travel), `at_usec: int`; `_init(drill: DrillData)`; `press(t_usec: int) -> Array[Judgement]`, `release(t_usec: int) -> Array[Judgement]`, `advance(t_usec: int) -> Array[Judgement]` (each returns what was judged up to `t`, in order); `height_at(t_usec: int) -> float`; `is_lifting() -> bool`; `rep_at(t_usec: int) -> int`; `rep_progress_at(t_usec: int) -> float`; `get_judged_count() -> int`; `get_end_usec() -> int` (-1 until the last rep is judged, then when its stone is down); `static share_for_offset(offset_usec: int) -> float`.
- Constants (usec): `RISE_USEC = 2_000_000`, `BAND_CENTRE_USEC = 1_370_000`, `PERFECT_REACH_USEC = 70_000`, `GOOD_REACH_USEC = 210_000`, `OK_REACH_USEC = 630_000`, `ZERO_SHARE_REACH_USEC = 1_050_000`, `REST_HOLD_USEC = 300_000`, `SET_DOWN_USEC = 300_000`. Time 0 is the set's first press; slot `k` is `[k·rep, (k+1)·rep)` with rep = `drill.rep_seconds`.

Rules the tests pin: the share is piecewise linear in |offset| through (0, 1.0), (70 ms, 0.85), (210 ms, 0.6), (630 ms, 0.3), (1050 ms, 0.0), clamped, and `DrillRules.judge()` turns it into the tier, so each edge lands in the better tier. Settling time to `t`, in order: a lift whose top (`lift + RISE_USEC`) comes first is DROPPED there (height 1); a lift still held at its slot's end is judged there; a slot with no lift is TOO_LATE at its end (height 0). A press lifts when the next rep's slot has begun and the stone is down; a press during the rest of a judged slot, still held when the next slot begins, lifts at the slot's start (or when the stone is down, if later). A release judges the lift: offset = held − 1.37 s; a MISS below the band is TOO_LOW. After a judgement the stone rests where it stopped for 0.3 s (none after a drop), then sets down over 0.3 s; a stone at 0 needs no setting down. Presses after the last rep do nothing.

- [x] **Step 1: Write the failing tests** (a 4 s, 10-rep fixture drill): `test_the_share_falls_through_the_windows` (table of offsets: 0 → 1.0, ±70 ms → 0.85, ±210 ms → 0.6, ±630 ms → 0.3, ≥1050 ms → 0.0, and `judge()` of each edge gives PERFECT, GOOD, OK); `test_a_release_is_judged_by_how_long_it_was_held` (table: held 1.37 s PERFECT, 1.20 s GOOD, 0.90 s OK, 0.60 s MISS/TOO_LOW); `test_holding_past_the_top_drops_the_stone` (press 0, advance 2.5 s: one DROPPED at 2.0 s, height 1; the release after it judges nothing); `test_a_rep_with_no_lift_is_too_late` (first rep released, then advance to 8.0 s: rep 1 TOO_LATE at 8.0 s); `test_a_lift_held_at_the_slot_end_is_judged_there` (press 3.5 s into rep 1's slot, advance to 8.0 s: judged at 8.0 s with 0.5 s held, TOO_LOW); `test_a_press_held_over_lifts_at_the_next_slot` (release at 1.37 s, press at 3.9 s and hold: the lift starts at 4.0 s); `test_the_stone_rests_then_sets_down` (`height_at()` at the release, 0.3 s on, 0.45 s on (half), 0.6 s on (0)); `test_a_set_is_ten_reps_and_ends_when_the_last_stone_is_down` (ten perfect reps: ten judgements, `get_end_usec()` = the tenth release + 0.6 s; a press after it judges nothing); `test_a_long_gap_judges_each_slot_in_order` (press 0, release 1.37 s, `advance(41 s)`: reps 1 to 9 TOO_LATE at 8, 12, … 40 s, in order, and the set ends at 40 s); `test_rep_progress_follows_the_slot`.
- [x] **Step 2: Run it: FAIL.**
- [x] **Step 3: Implement.** The settle loop, the one piece the rules leave to the implementer's order:

```gdscript
func _settle(t: int) -> void:
	while _judged.size() < _reps:
		var slot_end: int = (_judged.size() + 1) * _rep_usec
		if _lift_start >= 0:
			var top: int = _lift_start + RISE_USEC
			if top <= t and top <= slot_end:
				_judge_drop(top)
			elif slot_end <= t:
				_judge_lift(slot_end)
			else:
				return
		else:
			if _held and _try_lift(t):
				continue
			if slot_end <= t:
				_judge_too_late(slot_end)
			else:
				return
```

- [x] **Step 4: Run it: PASS.**
- [x] **Step 5: Commit** (with Task 1's test).

### Task 8: The floater's icon parts

**Files:**
- Modify: `scenes/common/lacquer/lacquer_floater/lacquer_floater.gd`
- Test: `tests/unit/test_lacquer_floater.gd` (the existing file, or create it)

**Interfaces:**
- Produces: `LacquerFloater.pop_parts(parts: Array, color: Color) -> void`: each part a `String` (text) or a `Texture2D` (an `ITEM_ICON_SIZE` icon), in order; `get_text()` returns the strings joined, `get_icons()` the textures.

- [x] **Step 1: Write the failing test** `test_pop_parts_shows_icons_and_text` (parts `[icon, " capped"]`: shows, text " capped", icons `[icon]`, colour as given, token width even).
- [x] **Step 2: Run it: FAIL.**
- [x] **Step 3: Implement** beside `pop_items()`.
- [x] **Step 4: Run it: PASS.**
- [x] **Step 5: Commit.**

### Task 9: DrillPlay, the Stone Lifting stage

**Files:**
- Create: `assets/ui/lacquer/body_refining/` `lacquer_drill_stone_ai.png` (64×56), `lacquer_drill_beads_ai.png` (five 24×24 frames: empty, brass, cream, tan, miss), `lacquer_drill_track9_ai.png` (16×16, ink lips top and left 4 px, rim-shade lips right and bottom 2 px), `lacquer_drill_jade_ai.png` (28×4 jade tile), `lacquer_drill_rail_ai.png` (8×252: tan 84, cream 28, brass 28, cream 28, tan 84); `scenes/body_refining/drill/drill_play.gd` and `.tscn`
- Test: `tests/integration/test_drill_play.gd`

**Interfaces:**
- Consumes: `DrillRun` (Task 7), `pay_rep()`, the set session and `finish_set()` (Task 6), `pop_parts()` (Task 8), `StatDisplay.mini_icon_of()` (Task 4).
- Produces: `class_name DrillPlay extends Control` (524×872, the figure box's space); `signal set_started`; `signal rep_judged(judgement: DrillRun.Judgement, health: float, stat_xp: Dictionary)` (AttributeType → XP that stat took this rep); `signal set_completed(result: DrillSetResult)`; `var clock_usec: Callable = Time.get_ticks_usec`; `setup(drill: DrillData)`, `handle_press_event(event: InputEvent) -> bool`, `stop_set()`, `is_set_running() -> bool`, `get_result() -> DrillSetResult`, `get_run() -> DrillRun`, `get_stone_global_center() -> Vector2`; `const PRESS_ACTION: StringName = &"drill_press"`.
- Geometry (DrillPlay's space): track at (244, 32), 36×462; the stone's base at rest y 492, travel 400 px (2 px steps), the stone 64 wide at x 230; jade fill at x 248, 28 wide, from the base down to 492; rails at x 218 and 298 from y 92 (252 tall); beads 24 px apart 30 from x 115, y 812; floaters at the stone's (84, 6), the second 30 px under.

- [x] **Step 1: Write the failing tests** (fresh save, `clock_usec` on a test clock, `_at(seconds)` sets it and runs a frame): `test_drill_press_starts_a_set_and_lifts` (`set_started` once; the session runs with rep 1); `test_a_set_scores_and_pays_each_rep` (ten releases at 1.37 s into each slot: ten PERFECT judgements, Strength XP 60, Health restored 40 from Health 50, bead frames all 1, `set_completed` once with a perfect result, `sets_finished` 1, the session ended); `test_a_miss_lights_its_bead_and_pops_its_reason` (a release at 0.6 s: bead 4, floaters "Miss" and "Too low"); `test_a_rep_at_full_health_pops_full` (floater parts: the Health mini and " full"); `test_a_capped_strength_pops_capped`; `test_key_repeats_are_not_presses`; `test_a_mouse_release_leaves_a_key_lift`; `test_focus_loss_lets_the_stone_go`; `test_the_stone_stands_on_the_jade` (at 1.0 s held the stone's base is 200 px above rest, the fill as tall); `test_stop_set_keeps_the_paid_reps_and_counts_nothing` (two reps then `stop_set()`: their XP stays, `sets_finished` 0, the session ended, no `set_completed`).
- [x] **Step 2: Run it: FAIL.**
- [x] **Step 3: Implement.** Make the art (stone and beads from the 2026-11-01 Body Refining canvas, saved as `_ai` files), the scene (Track, RailLeft, RailRight, Fill, Stone, Beads as ten `LacquerStripRect`s, Floaters with two `LacquerFloater`s) and the script: a press with no running set starts one at that time (a set is running from its first press until `finish_set()` or `stop_set()`); each frame advances the run, then for each judgement pays it through `pay_rep()` (a MISS records itself), works out each stat's taken XP from the result's totals before and after, lights its bead, pops the tier word and its second line, and emits `rep_judged`; it updates the session (rep, progress) and draws the stone; when `get_end_usec()` has passed it calls `finish_set()` and emits `set_completed`. The hold belongs to the input kind that started it; `NOTIFICATION_APPLICATION_FOCUS_OUT` lets it go.
- [x] **Step 4: Run it: PASS.**
- [x] **Step 5: Commit** the art (with `.import` files), the scene and the test.

### Task 10: BodyRefiningView, the board

**Files:**
- Create: `assets/ui/lacquer/body_refining/lacquer_drill_rim_strength_ai.png` (524×872 overlay: the brass rim of the carved figure's arms and shoulders), `scenes/body_refining/body_refining_view/body_refining_view.gd` and `.tscn`
- Modify: `assets/themes/lacquer/lacquer_theme.tres` (`RichTextLacquerName`: RichTextLacquer at 17 px in cream, the footer's look), `tests/integration/test_boards_never_trim_text.gd` (BOARD_SCENES gains the view and DrillPlay)
- Test: `tests/integration/test_body_refining_view.gd`

**Interfaces:**
- Consumes: DrillPlay (Task 9), `perfect_rep_health()` (Task 6), the cabinet's `get_stat_cell_global_position()`, `hold_stat_xp()`, `release_stat_xp()`, `get_health_orb_global_position()`, `hold_health()`, `release_health()`.
- Produces: `class_name BodyRefiningView extends Control`; `const READY: String = "Hold Space or the mouse button to lift the stone."`, `const LIFT: String = "Let go with the stone in the brass band."`, `const PELLETS_BY_TIER: Dictionary = {PERFECT: 4, GOOD: 3, OK: 2}`; `var cultivator_plate: CultivatorPlate`; `setup(action: ZoneActionData)`, `halt()`, `close()`, `handle_press_event(event: InputEvent) -> bool`, `get_board_rect() -> Rect2`, `get_status_text() -> String`; `static pay_line(drill: DrillData, strength_capped: bool, perfect_health: float) -> String` and `static result_line(result: DrillSetResult) -> String` (BBCode with the two minis as `[img]` tags and numbers through `LacquerText.decimal_bbcode`).

- [x] **Step 1: Write the failing tests** (the cabinet beside the view, as `test_cycling_view.gd` builds it): `test_setup_names_the_action_and_the_drill` (labels "Riverbank Training", "Stone Lifting"; status READY); `test_the_pay_line_reads_a_perfect_rep_at_your_strength` (parsed text holds "+6 XP" and "+4"; at Strength Lv 10 "+7.6"; capped "capped"; both minis' paths in the BBCode); `test_the_status_line_follows_the_set` (READY, LIFT once a set runs, the result line after it: "Last set", "+60 XP", "+40", "Perfect set" for ten Perfect reps; "6 / 10 perfect" otherwise); `test_a_finished_set_writes_one_log_line` ("Set · +60 Strength XP · +40 Health"); `test_health_pellets_land_on_the_health_orb` (a Perfect rep at Health 40: four crimson pellets, the orb reads 40 until they land, then 44); `test_strength_pellets_land_on_strength_s_cell`; `test_no_strength_pellets_at_the_cap`; `test_pellets_carry_only_what_was_taken` (Health 98: the crimson pellets carry 2 in all); `test_closing_mid_set_keeps_what_was_paid` (close after two reps: no result line, no log line, `sets_finished` 0, pellets freed, their XP and Health shown at once); `test_the_close_button_stops_the_action`; `test_the_view_stops_every_click_beneath_it` (a mouse press anywhere is accepted and lifts); `test_a_long_name_wraps_and_the_board_grows`.
- [x] **Step 2: Run it: FAIL.**
- [x] **Step 3: Implement.** The scene mirrors `cycling_view.tscn` (Board with the cycling board art, ActionLabel, TitleLabel, EscLabel, CloseButton, PayLine, FigureBox with Body, StrengthRim and the DrillPlay instance, StatusText, EffectsLayer); the root covers the screen and stops every click as `TribulationView`'s does. The header stacks and the board grows from its art's height as `CyclingView._relayout_board()` does, the figure box at board-local y 80 or lower under the pay line. Pellets: a `PelletFlight.burst` from the stone of `PELLETS_BY_TIER[tier]` pellets per kind (0.6 s, 0.05 s step, 28 px reach), holding each share on the cabinet and releasing it on `delivered`; nothing while hidden. The pay line follows `stats_changed` and the equipped drill.
- [x] **Step 4: Run it and the never-trim test: PASS.**
- [x] **Step 5: Commit** the rim art, the theme, the scene, the script and the tests.

### Task 11: BodyRefiningViewState and the main scene

**Files:**
- Create: `scenes/ui/main_view/states/body_refining_view_state.gd`
- Modify: `scenes/ui/main_view/main_view.gd`, `scenes/main/main_game/main_game.tscn` (`BodyRefiningViewState` under the state machine after TribulationViewState; `BodyRefiningView` hidden at z 3 after TribulationView and before BoardTransition), `tests/unit/test_cycling_mode.gd` (the furniture test: BoardTransition after BodyRefiningView)
- Test: `tests/unit/test_body_refining_view_state.gd`

**Interfaces:**
- Produces: `class_name BodyRefiningViewState extends MainViewState`; MainView `body_refining_view: BodyRefiningView`, `body_refining_view_state: MainViewState`, and the cabinet handed to both boards (`_hand_cabinet_to_boards()`, replacing `_hand_cabinet_to_cycling_view()`).

- [x] **Step 1: Write the failing tests**, mirroring `test_tribulation_view_state.gd` with `swaps_chest = false` and `moves_hud_boards = false`: `test_start_pushes_once`; `test_start_sets_the_board_up_for_the_action`; `test_escape_stops_the_action` (ui_cancel: the action stops and the board closes); `test_the_press_action_reaches_the_view` (a `drill_press` press starts a set); `test_the_full_log_is_blocked_while_the_board_is_up`; `test_the_goals_board_and_the_log_stay`; `test_stop_removes_only_itself`; `test_start_opens_the_board_through_the_transition`; `test_the_state_stays_until_the_close_has_finished`; `test_a_stop_halts_the_set_while_the_board_stays_drawn`; `test_a_start_while_closing_reverses_and_keeps_the_state`; `test_input_while_closing_is_dropped`; `test_presses_while_opening_are_dropped`; `test_main_game_holds_the_board_and_its_state`.
- [x] **Step 2: Run it: FAIL.**
- [x] **Step 3: Implement**: enter blocks the full log and opens the board; exit closes the view and lifts the block; `handle_input()` drops everything while the board closes, stops the action on `ui_cancel`, drops presses while it opens, else hands the event to the view; start sets the view up, then pushes or turns the close around; stop halts the view and closes the board, removing only itself when the close ends.
- [x] **Step 4: Run it, `test_cycling_mode.gd` and `test_tribulation_view_state.gd`: PASS.**
- [x] **Step 5: Commit** (main_game.tscn with its nodes only: no editor re-saves).

### Task 12: The running set in the Now strip

**Files:**
- Modify: `scenes/zones/zone_panel/now_strip/now_strip.gd` and `.tscn` (the rate's icon gets a unique name, `RateIcon`)
- Test: `tests/integration/test_zone_panel.gd`

- [x] **Step 1: Write the failing tests**: `test_tray_shows_the_set_ready` (texts "Riverbank Training", "+4 / rep", "Stone Lifting", "10 reps"; the rate icon the Health mini; the ring dark, the rod empty; takes no clicks); `test_tray_follows_the_running_set` (session rep 4 at 0.5: ring frame 6, "Rep 4 / 10", the rod at 0.35 of its steps); `test_tray_rate_follows_strength` (Strength Lv 10: "+7.6 / rep"); `test_tray_gives_the_set_back_to_the_idle_action` (stopping resumes the Aura Well's own strip, its Madra icon back).
- [x] **Step 2: Run it: FAIL.**
- [x] **Step 3: Implement** a body refining branch beside cycling's: the layout, the figure, ring and rod from BodyRefiningManager's session each frame, the rate from `perfect_rep_health()` refreshed on `stats_changed` and `equipped_drill_changed`.
- [x] **Step 4: Run it: PASS.**
- [x] **Step 5: Commit.**

### Task 13: A session switch ends a running set

**Files:**
- Modify: `singletons/dev_manager/dev_manager.gd` (`_tear_down()` calls `BodyRefiningManager.end_set_session()` after the cycle session)
- Test: `tests/integration/test_dev_manager_sessions.gd`

- [x] **Step 1: Extend** `test_teardown_clears_the_runtime_state` with a running set session: after the switch, `is_set_running()` is false.
- [x] **Step 2: Run it: FAIL. Step 3: Implement. Step 4: PASS. Step 5: Commit.**

### Task 14: Wrap

- [x] The suite passes (`tests/run_tests.ps1`); a failure from the parallel run is confirmed in one process first.
- [x] The issue's Done-when checks run on `-- --save=user://dev/runs/body-refining-board.tres`, and from the `tribulation_ready` preset (Strength set to Lv 9 just short of the next level, drilled to the cap: the Tribulation card turns ready and starts the trial). An old save still loads and plays.
- [x] `git diff main -- project.godot` shows only `drill_press`.
- [x] The PR closes #100, says the breakthrough can be reached in play again so an itch build is possible (Lionel publishes by hand), and ends with `## Docs to update`.

## What was built differently

- **The card's presenter and the drill stage stay off the never-trim walk's `BOARD_SCENES`.** The walk requires each listed scene to hold Labels. The presenter holds only RichTextLabels in a wrapping flow, as the unlisted foraging presenter does, and DrillPlay's text is in its LacquerFloaters. The board, which instances the stage, is listed.
- **`StatDisplay.mini_icon_of()` returns null quietly** for a stat whose mini is not drawn yet; it logs no error. A line then names that stat in words.
- **`BodyRefiningView.pay_line()` takes the capped stats as an Array**, not a Strength flag, so a drill with another stat (#106's) shows that stat's capped state too.
- **Every drill plays on Stone Lifting's hold-and-release stage until #106**, each with its own numbers: a dev-equipped Horse Stance plays as hold-and-release. #100 builds only the starting drill's input.
- **ZoneManager's NEW marking became `_mark_actions_of_type_unseen(action_type)`**, which a technique unlock (cycling) and a drill unlock (body refining) share.
- **The chest rebuilds on `drill_unlocked`** (`ZonePanel._on_drill_unlocked`), as it does on `technique_unlocked`. Task 3 tested the seen record but not the card on screen. Playing the Done-when checks found that the card's NEW seal stayed dark after a drill unlock until something else rebuilt the list.
- **Tests beyond the plan's lists:**
  - The view state's Esc test runs on ActionManager's real signals, with the state in the tree.
  - Esc while the board closes leaves the resumed action alone.
  - A stop with no board up changes nothing.
  - The state keeps one spec.
  - The Now strip goes back to "10 reps" when a set ends, and follows the equipped drill.
  - The cabinet is handed to the body refining board.
- **The stage also lets go on the window's focus loss** (`NOTIFICATION_WM_WINDOW_FOCUS_OUT`). The Web build never sends the application's focus loss, so Review Focus 2 failed in the browser. Found by the final review.
- **The log checks watch `message_logged`**, not the log's history. That covers `test_a_finished_set_writes_one_log_line` and the no-log-line check in `test_closing_mid_set_keeps_what_was_paid`. The history keeps only 200 lines, and once earlier scripts had filled it in a parallel run, a size check could no longer see a new line.
- **Left for Lionel (from the final review):** a hold kept past its judgement lifts the stone again at the next slot. As a result one late press can cost two reps, and a dev-equipped 2 s drill scores Perfect by holding. Also, "Strength capped" replaces XP the crossing set partly paid, which matches #94's cycle line but not the approved "in place of a part that paid nothing".
- **The Done-when checks were played by a scripted driver**, kept out of git. It loads the real main scene in place of its own launch scene, then drives it with parsed input and the dev panel's own commands. Such a run plays its save in memory, so the `--save` file is never written.
