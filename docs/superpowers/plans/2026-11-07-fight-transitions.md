# Fight Transitions Implementation Plan (#138)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every fight a way in from the adventure map and a way out back to it that the player can follow, as Lionel approved them on the canvas "Into and out of a fight", with nothing in the fight acting outside its live span.

**Architecture:** A new `FightTransition` node in the adventure view plays each edge as beats at set times (a tween of intervals and callbacks that ignores the time scale) and emits a signal where the view's game logic takes over: `landed` (the fight starts), `fight_hidden` (its fighters go) and `map_whole` (the board news shows, and a lost fight or the boss's win ends the run). `AdventureCombat` creates its fighters held (`CombatantNode.set_held()`: every node of the fighter but its visual stops processing), starts them in one frame at `begin()`, and decides the fight once, holding both again. The view pays at the hit, as today, and holds the boards' news until the map is whole.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** issue #138 (Decided, Touches, Done when) and its recorded answers (https://github.com/LionelEisenberg/EndlessPath/issues/138#issuecomment-6714238751). Canvas: https://claude.ai/artifact/Dp5ShNfU6Qt4PaB2tLp1fZ.

## Approved answers (the mock-up step)

Lionel approved every pick as drawn ("All picks stand"):

| Question | Answer |
|---|---|
| On the map first | The map's camera pushes in on the player's hex to 1.5 times its zoom over 0.3 s, cubic ease in. A new move for the style guide's Camera row. |
| Map to fight | `ViewDissolve` as it is: a still of the pushed-in map, under the boards, dissolves away over the fight in its two 0.1 s steps. |
| The fighters' arrival | Both at once: 420 px in from each one's side, 2 px steps at a steady speed, 0.4 s, shown outright, starting with the dissolve. The enemy's nameplate shows as it lands. |
| When the fight starts | Once both have landed (0.7 s after the press): no cast, tick, technique or consumable before. The opening starts then for both sides in one frame, and the dock goes live. |
| The run clock | Held from the press until the landing, and from the deciding hit until the map is whole. |
| Elites and the boss | The same edges as every fight. |
| The deciding hit | The boss reveal's hit-stop: time at a quarter for 0.15 s of real time. Its flash, recoil and number keep today's look. |
| The loser | Knocked 48 px back in 2 px steps over 0.16 s, then off, on, off, on, gone, 0.08 s each. The player's fall too. An enemy's nameplate goes as its exit starts. No new art. |
| Fight to map | A 0.3 s beat, then the same 0.2 s dissolve. The close lasts 1.13 s, hit to a whole map. Nothing skips it. |
| The beads | They leave the hex the frame the map is whole. |
| The dock | Live from the landing to the deciding hit. |
| What updates at the hit | Paid and saved at the hit; the chest's tile line, the Run ledger and the beads show it with the map. The chest is unchanged through a fight. |
| Runs that end in a fight | A lost fight and the boss's win: the close, the map, then the end card. An Exit or a timeout cuts at once, on either edge too. |
| The rework's fight PR | Only the edges come in. |

## Global Constraints

- Motion in whole steps, shown and hidden outright, no opacity fade, glow or blur. The only eased moves are the camera push (`TRANS_CUBIC`, `EASE_IN`) and the hit-stop. The deciding hit's flash, recoil and number stay as `CombatantVisual` draws them today.
- Timings: push 0.3 s to 1.5x; dissolve 2 x `ViewDissolve.STEP_SECONDS` (0.2 s); arrival `420` px over `0.4` s; landing at 0.7 s; hit-stop `0.25` x the base speed for `0.15` s of real time; knockback `48` px over `0.16` s; blink 4 steps of `0.08` s (off, on, off, on), then hidden; beat `0.3` s; map whole 1.13 s after the hit.
- The log's words don't change: "Encounter: %s" at the press, "Combat Victory!" / "Combat Defeat..." at the hit (#150 rewrites them later).
- `q_first_steps_adventure_ended` fires once per run's end, in `AdventureView.stop_adventure()` inside `if run_is_on`, however the run ends.
- A dev force-win counts as no play, including the boss's run end it causes after the close.
- No save change, no enum, no balancing (#111 paused), no living-doc edit; no new art.
- GDScript standards from `CLAUDE.md`: typed vars, `-> void`, `##` docs on public functions, `%` unique names, `Log` not `print`. UI nodes in `.tscn`.

## Review Focus

1. **A run that ends during an edge** (Exit on the way in, mid-fight, on the way out): the map shows, the fight is hidden and its fighters freed, the camera's zoom is back, the run clock isn't left paused, a kill made before is still paid, and the next run opens clean. Test: Task 6 `test_an_exit_cuts_every_edge`.
2. **A deciding hit reported again** (another write at 0 Health, a second force-win): pays nothing more, starts no second close. Tests: Task 4 `test_the_fight_is_decided_once`, Task 6 `test_a_win_reported_again_pays_once`.
3. **The boss force-won from the dev panel**: its run end after the close is still no play. Test: Task 6 (in `test_dev_adventure_commands.gd`) `test_force_win_of_the_boss_wins_the_adventure` keeps `adventures_won == 0`.
4. **A press on either edge** (a technique key, a consumable key) does nothing, and the enemy starts no cast before the landing. Tests: Task 4 `test_presses_reach_only_a_live_fight`, Task 6 `test_nothing_acts_on_the_way_in`.
5. **The run clock left paused**: after each edge, after each cut, and at the next run's start it runs. Test: Task 6 `test_the_run_clock_holds_through_both_edges` and `test_an_exit_cuts_every_edge`.

---

### Task 1: One hit-stop for the boss reveal and the deciding hit

**Files:**
- Modify: `scripts/utils/game_speed.gd`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` (`_play_boss_reveal()`)
- Test: `tests/unit/test_game_speed.gd` (new)

**Interfaces:**
- Produces: `GameSpeed.HIT_STOP_SCALE: float = 0.25`, `GameSpeed.HIT_STOP_SECONDS: float = 0.15`, `static func GameSpeed.hit_stop(tree: SceneTree) -> void` (time at `HIT_STOP_SCALE * base_scale` now, back to the base speed it reads when `HIT_STOP_SECONDS` of real time have passed).

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_game_speed.gd`: `test_a_hit_stop_slows_time_then_returns` (base 1: 0.25 right after, 1.0 after `await wait_seconds(0.3)`) and `test_a_hit_stop_returns_to_the_dev_speed` (base 2: 0.5 then 2.0). `after_each` puts `GameSpeed.set_base_scale(1.0)`.
- [ ] **Step 2: Run** `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_speed.gd -gexit`: FAIL, `hit_stop` not found.
- [ ] **Step 3: Implement `GameSpeed.hit_stop()`** with the timer from `_play_boss_reveal()` (`create_timer(HIT_STOP_SECONDS, true, false, true)`), and make `_play_boss_reveal()` call it.
- [ ] **Step 4: Run** the new file and `tests/integration/test_adventure_map_render.gd`: PASS.
- [ ] **Step 5: Commit** `refactor(adventure): share the boss reveal's hit-stop`.

### Task 2: Fighters arrive and fall in whole steps

**Files:**
- Modify: `scenes/combat/combatant/combatant_visual/combatant_visual.gd`
- Test: `tests/unit/test_combatant_motion.gd` (new)

**Interfaces:**
- Produces: constants `ENTER_DISTANCE: int = 420`, `ENTER_SECONDS: float = 0.4`, `KNOCKBACK_DISTANCE: int = 48`, `KNOCKBACK_SECONDS: float = 0.16`, `BLINK_STEP_SECONDS: float = 0.08`, `BLINK_STEPS: int = 4`, `DEFEAT_SECONDS: float = KNOCKBACK_SECONDS + BLINK_STEP_SECONDS * BLINK_STEPS` (0.48).
- Statics: `enter_offset_at(elapsed: float) -> int` (the distance still to go: the even number nearest `ENTER_DISTANCE * (1 - clamp(elapsed / ENTER_SECONDS, 0, 1))`); `knockback_offset_at(elapsed: float) -> int` (the even number nearest `KNOCKBACK_DISTANCE * clamp(elapsed / KNOCKBACK_SECONDS, 0, 1)`); `shown_while_falling_at(elapsed: float) -> bool` (true through the knockback, then step `floori((elapsed - KNOCKBACK_SECONDS) / BLINK_STEP_SECONDS)`: odd steps under `BLINK_STEPS` shown, the rest hidden).
- Methods: `place_for_entrance() -> void` (the visual root at `-facing * ENTER_DISTANCE`, shown), `play_enter() -> void` (root x from `enter_offset_at`, linear over `ENTER_SECONDS`), `play_defeat() -> void` (root x `-facing * knockback_offset_at`, Body and Shadow shown per `shown_while_falling_at`, over `DEFEAT_SECONDS`), `is_fallen() -> bool` (Body hidden after a defeat).
- Rules: the moves go on the visual root (`position.x`), so the hit's recoil on Body plays on untouched; both tweens drive a static through `tween_method`, as `MapGlyph` shakes do. The old eased slide and its alpha fade go.

- [ ] **Step 1: Write the failing tests:** `test_the_entrance_steps_in_even_px` (table: 0 → 420, 0.1 → 316, 0.2 → 210, 0.3 → 106, 0.4 → 0, 0.6 → 0; every value even), `test_the_knockback_steps_in_even_px` (0 → 0, 0.04 → 12, 0.08 → 24, 0.16 → 48, 0.3 → 48), `test_the_fall_blinks_then_stays_gone` (0.1 → shown, 0.17 → hidden, 0.25 → shown, 0.33 → hidden, 0.41 → shown, 0.49 → hidden, 2.0 → hidden), and on a `combatant_visual.tscn` set up facing left (an enemy): `test_an_enemy_waits_off_its_spot_and_arrives` (420 px right after `place_for_entrance()`, 0 after `await wait_seconds(ENTER_SECONDS + 0.1)` of `play_enter()`, no `modulate.a` below 1 meanwhile) and `test_a_fallen_fighter_is_gone` (after `play_defeat()` and `DEFEAT_SECONDS + 0.1` s: `is_fallen()`, root x 48).
- [ ] **Step 2: Run** the file: FAIL.
- [ ] **Step 3: Implement** the constants, statics and methods.
- [ ] **Step 4: Run** the file and `tests/integration/test_adventure_view_frame.gd`: PASS.
- [ ] **Step 5: Commit** `feat(combat): step fighters in and out in whole px`.

### Task 3: A fighter can be held still

**Files:**
- Modify: `scenes/combat/combatant/combatant_node.gd`
- Test: `tests/unit/test_combatant_hold.gd` (new)

**Interfaces:**
- Produces: `CombatantNode.set_held(held: bool) -> void` (every child but `visual` to `PROCESS_MODE_DISABLED`, or back to `PROCESS_MODE_INHERIT`: the ability, consumable, effect and buff managers, an own `VitalsManager` and a `SimpleEnemyAI`), `CombatantNode.is_held() -> bool`.

- [ ] **Step 1: Write the failing tests** on real fighters set up as `AdventureCombat` sets them up (`combatant_node.tscn`, `amorphous_spirit.tres`, a `SimpleEnemyAI` child): `test_a_held_fighters_clocks_stand_still` (held, a technique's opening `cooldown_timer.time_left` is still `INITIAL_COOLDOWN` after `await wait_seconds(0.3)`, the AI `is_in_opening()` with its countdown unmoved), `test_a_held_fighter_takes_no_tick` (a DoT buff applied, held: Health unchanged after 1.2 s), `test_a_released_fighter_runs_again` (after `set_held(false)` the opening counts down), `test_the_visual_plays_on_while_held` (`visual.can_process()` true).
- [ ] **Step 2: Run** the file: FAIL.
- [ ] **Step 3: Implement** `set_held()` and `is_held()`.
- [ ] **Step 4: Run** the file: PASS.
- [ ] **Step 5: Commit** `feat(combat): let a fighter be held still`.

### Task 4: AdventureCombat starts held, begins in one frame, ends once

**Files:**
- Modify: `scenes/combat/adventure_combat/adventure_combat.gd`
- Modify: `scenes/combat/ai/simple_enemy_ai.gd` (doc comment only: both openings start at `begin()`)
- Test: `tests/unit/test_adventure_combat_edges.gd` (new); update `tests/unit/test_adventure_combat_victory_event.gd`, `tests/unit/test_fight_rules.gd`, `tests/unit/test_simple_enemy_ai.gd` (their `_start_fight()` calls `begin()` after `start()`)

**Interfaces:**
- Consumes: `CombatantNode.set_held()`, `CombatantVisual.place_for_entrance()`, `play_enter()`, `play_defeat()`.
- Produces: `start()` (fighters created held, placed for their entrance, the nameplate hidden); `play_enter() -> void`; `begin() -> void` (releases both in one frame, shows the nameplate; does nothing once begun or decided); `is_live() -> bool` (begun and not decided); `play_defeat(won: bool) -> void` (the enemy falls on a win, the player on a loss; the nameplate hides as the enemy's fall starts); `trigger_combat_end` emitted once per fight, from the Health handlers only while live, with both fighters held from that frame; `stop()` also forgets the fight's begun and decided state.

- [ ] **Step 1: Write the failing tests:** `test_a_fight_starts_held_with_its_name_hidden` (after `start()`: both `is_held()`, `is_live()` false, nameplate hidden, enemy root x 420, player root x -420); `test_begin_starts_both_openings_in_one_frame` (after `begin()`: neither held, nameplate shown; the player's technique and the AI count down together over `await wait_seconds(0.3)`); `test_the_fight_is_decided_once` (live, enemy Health to 0 three times: one `trigger_combat_end`, `[true, gold]`; both held after it); `test_health_before_the_fight_starts_decides_nothing` (Health 0 after `start()`, before `begin()`: no emission); `test_nothing_acts_after_the_deciding_hit` (live, DoT on the enemy, the player dies: enemy casts nothing and the DoT ticks nothing over 1.6 s); `test_presses_reach_only_a_live_fight` (a technique press and a consumable press before `begin()` and after the decision: nothing used); `test_the_loser_falls` (table: won → enemy `is_fallen()`, nameplate hidden; lost → player `is_fallen()`).
- [ ] **Step 2: Run** the file: FAIL.
- [ ] **Step 3: Implement** in `adventure_combat.gd`; update the three unit tests' helpers.
- [ ] **Step 4: Run** `tests/unit/`: PASS.
- [ ] **Step 5: Commit** `feat(combat): start a fight held and decide it once`.

### Task 5: The map pushes in on the player's hex; the boss's win leaves the run's end to the view

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`
- Test: `tests/integration/test_adventure_map_zoom.gd` (new tests), comments in `tests/integration/test_play_stats_recording.gd`

**Interfaces:**
- Produces: `const FIGHT_PUSH_ZOOM: float = 1.5`; `push_in_on_player(seconds: float) -> void` (settles and holds the wheel's zoom controller, then tweens the camera's zoom from its own to `FIGHT_PUSH_ZOOM` times it, `TRANS_CUBIC` / `EASE_IN`, the offset following through `_apply_camera_offset()` so the hex stays at (960, 470)); `end_push_in() -> void` (the zoom back outright, the wheel live again; nothing when no push); `is_pushed_in() -> bool`. `handle_combat_result()` still emits `boss_defeated` for the boss's win, but no longer calls `ActionManager.stop_action(true)`; `stop_adventure()` ends a push.

- [ ] **Step 1: Write the failing tests** in `test_adventure_map_zoom.gd`: `test_the_push_in_keeps_the_hex_in_place` (zoom 1: 1.5 after `await wait_seconds(0.4)`, the player's hex at screen (960, 470) within 2 px; a wheel meanwhile aims no zoom); `test_ending_the_push_puts_the_camera_back` (zoom 2 → push → `end_push_in()`: zoom 2, the wheel zooms again). In `test_adventure_tilemap_events.gd`: `test_the_boss_win_ends_no_run_itself` (the run's action is still current after the boss's `handle_combat_result(true, 0)`, `boss_defeated` once).
- [ ] **Step 2: Run** those files: FAIL.
- [ ] **Step 3: Implement**; reword the comment in `test_play_stats_recording.gd` that says the tilemap ends the run.
- [ ] **Step 4: Run** `test_adventure_map_zoom.gd`, `test_adventure_tilemap_events.gd`, `test_play_stats_recording.gd`, `test_adventure_map_render.gd`: PASS.
- [ ] **Step 5: Commit** `feat(adventure): push the map in on the player's hex`.

### Task 6: The edges in the adventure view

**Files:**
- Create: `scenes/adventure/adventure_view/fight_transition.gd`
- Modify: `scenes/adventure/adventure_view/adventure_view.gd`, `adventure_view.tscn` (a `FightDissolve` instance of `view_dissolve.tscn` between `CombatView` and `VitalsPlate`; a `FightTransition` node; both unique)
- Modify: `singletons/dev_manager/dev_commands.gd` (`force_win_fight()` refuses unless `view.is_fight_live()`), `scenes/ui/dev_panel/tabs/adventure_tab.gd` (the fight box shows while the fight is live)
- Test: `tests/integration/test_fight_transitions.gd` (new); update `test_riverbank_training_unlock.gd`, `test_adventure_end_flow.gd`, `test_adventure_view_frame.gd`, `test_adventure_map_zoom.gd`, `test_kill_beads.gd`, `test_dev_adventure_commands.gd`

**Interfaces:**
- Consumes: Tasks 1 to 5.
- `FightTransition` (Node): signals `landed`, `fight_hidden`, `map_whole`; constants `PUSH_SECONDS = 0.3`, `BEAT_SECONDS = 0.3`, `DISSOLVE_SECONDS = ViewDissolve.STEP_SECONDS * 2`, `WAY_IN_SECONDS = PUSH_SECONDS + CombatantVisual.ENTER_SECONDS` (0.7), `WAY_OUT_SECONDS = GameSpeed.HIT_STOP_SECONDS + CombatantVisual.DEFEAT_SECONDS + BEAT_SECONDS + DISSOLVE_SECONDS` (1.13); `play_way_in() -> void` (0 s: map push; `PUSH_SECONDS`: `FightDissolve.play()`, map hidden, fight shown, push ended, `combat.play_enter()`; `WAY_IN_SECONDS`: `landed`); `play_way_out(won: bool) -> void` (`HIT_STOP_SECONDS`: `combat.play_defeat(won)`; + `DEFEAT_SECONDS + BEAT_SECONDS`: `FightDissolve.play()`, fight hidden, map shown, `fight_hidden`; + `DISSOLVE_SECONDS`: `map_whole`); `finish_now() -> void` (runs the beats not yet run, in order, at once); `cut() -> void` (runs none: push ended, map shown, fight hidden, outright); `is_playing() -> bool`; `is_closing() -> bool`. Its tween ignores the time scale, so the hit-stop slows the fight, not the beats.
- `AdventureView`: `is_fight_live() -> bool`; `finish_fight_transition() -> void` (for the tests: `FightTransition.finish_now()`); `_on_start_combat()` sets the fight up held, pauses the run clock and plays the way in; on `landed` the fight begins, the dock and the cabinet bind, the clock runs; `_on_combat_decided(won, gold)` (was `_on_stop_combat`, once per fight; a decision on the way in finishes it first) logs, counts, lets the boards go, pauses the clock, holds the board news, pays (`handle_combat_result`), notes a loss, captures `recording_paused`, `GameSpeed.hit_stop()`, plays the way out; on `fight_hidden` `combat.stop()`; on `map_whole` the fight is over, the news shows, the clock runs, and a lost fight or the boss's win ends the run (`ActionManager.stop_action()`) under the pause captured at the hit; `stop_adventure()` cuts a fight under way before the map clears (the news released, an undecided fight's result handled as a loss as today) and unpauses the clock; `force_win_combat()` acts only while live. Held news: the chest's resolved line, the ledger's announce, and each burst's Core Density (held in the cabinet at once with `hold_core_xp()`, so the Core row stands still until the beads fly).

- [ ] **Step 1: Write the failing tests** in `test_fight_transitions.gd` (the real `AdventureView` on the fixture map, as `test_adventure_view_frame.gd` drives it):
  - `test_the_way_in_shows_the_fight_at_the_swap_and_starts_it_at_the_landing`: right after the pick the map shows and the camera pushes; after `PUSH_SECONDS + 0.05` the fight shows, the map hides, nothing is live; after `WAY_IN_SECONDS + 0.05` `is_fight_live()`, the dock `is_active()`, the nameplate shows.
  - `test_nothing_acts_on_the_way_in`: before the landing the enemy isn't casting, a `ability_slot_1` press and a `consumable_slot_1` press use nothing, the player's opening `time_left` is still 1.5.
  - `test_the_run_clock_holds_through_both_edges`: paused from the pick to the landing and from the hit to the map; running between and after.
  - `test_the_way_out_pays_at_the_hit_and_shows_it_with_the_map`: at the hit the gold and Core Density are saved and the dock lets go, while the ledger, the chest's line, the Core row and the bead count are unchanged and the fight still shows; after `WAY_OUT_SECONDS + 0.05` the map shows, the fighters are freed, the ledger and line show the win, and the beads are in flight.
  - `test_a_win_reported_again_pays_once`: `trigger_combat_end` emitted twice: gold, fights and Core Density counted once.
  - `test_a_lost_fight_ends_the_run_after_its_close`: no `adventure_completed` at the hit; one after `finish_fight_transition()`, reading "Your health reached zero".
  - `test_the_boss_win_ends_the_run_after_its_close`: the same as a victory, the boss's Core Density counted once.
  - `test_an_exit_cuts_every_edge` (table: on the way in, mid-fight, on the way out): after `force_end_adventure(false)` the map shows, the fight is hidden with no fighter left, the camera's zoom is back, the clock isn't paused, the kill (way out case) is paid and in the ledger, and a second run opens with `_assert_a_clean_start()`'s checks.
  - `test_force_win_waits_for_the_fight_to_start`: `DevCommands.force_win_fight()` returns "No fight is on" on the way in, "" once live, "No fight is on" in the close.
- [ ] **Step 2: Run** the file: FAIL.
- [ ] **Step 3: Implement** `fight_transition.gd`, the scene nodes, the view's rework, `DevCommands.force_win_fight()` and the dev panel's fight box.
- [ ] **Step 4: Update the existing tests** where they expect a fight's switch in one frame: after a pick, `_view.finish_fight_transition()` before the fight is driven; after a decision, `_view.finish_fight_transition()` before the map, the ledger or the run's end is checked. Keep `test_every_way_a_run_ends_opens_npc_3_and_not_the_river()` driving the real view through a win, a loss, a stop mid-fight and no fight, with the event once each. In `test_dev_adventure_commands.gd`, the boss's force-win finishes its close and still counts no adventure won; the "already down" test checks a second force-win in the close pays nothing.
- [ ] **Step 5: Run** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`: all pass.
- [ ] **Step 6: Commit** `feat(adventure): play a fight's way in and way out`.

### Task 7: The issue's checks in the game

- [ ] **Step 1:** Run the issue's "Done when" list on `-- --preset=adventure_open --save=user://dev/runs/adventure-combat-transition.tres` with a scratch driver under `mockups/` (gitignored) that drives the real main scene through the dev commands and shoots frames on each edge, and check each frame.
- [ ] **Step 2:** Fix what fails, rerun the suite, commit.

### Task 8: The PR

- [ ] Merge `main` once right before it merges, rerun `tests/run_tests.ps1`.
- [ ] Open a PR that closes #138, with the checks for Lionel and a `## Docs to update` list: `docs/adventuring/ADVENTURING.md`, `docs/combat/COMBAT.md`, `docs/STYLE_GUIDE.md` (§8's Camera row gains the fight push; the hit-stop on the deciding hit; §13's S3 rows on the fade and the slide), `docs/tooling/DEV_TOOLS.md` (Force-win waits for the fight to start; the fight box shows while it is live), `docs/infrastructure/MAIN_VIEW.md` (`ViewDissolve` also plays a fight's edges, inside the adventure view), `scenes/combat/combat_architecture.md`.
