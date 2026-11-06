# Following Trains Spirit Implementation Plan (chunk #94)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Following the Madra ball, and only following it, draws Madra and pays Spirit XP on every cycling technique, with Spirit pellets flying to the cabinet's Spirit cell.

**Architecture:** A pure rule (`CyclingRules.is_following()`) judges each frame from what a small window of the last quarter second (`FollowWindow`) measures. `CyclingTechnique` draws Madra only while following and keeps a second clock of followed time that pays Spirit XP through `CharacterManager.add_stat_xp()` every half second, at the cycle's end and when a cycle is cut short. `CycleResult` records the share followed, the XP each stat took and the stats the cap took XP from. `CyclingView` sends each payment's puff of pellets to #92's landing and writes the new status line. `CharacterManager` caches stat reads until the stats change (DM-06), and `add_stat_xp()` returns the XP the stat took.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** issue #94 and its [approved mock-up answers](https://github.com/LionelEisenberg/EndlessPath/issues/94#issuecomment-6674180318) (canvas [Following trains Spirit](https://claude.ai/artifact/AEvPVzEHQdmvhPTBnfoxM9)); the stats rework spec's Phase 3 and "Levels, XP and the cap" (`docs/superpowers/specs/2026-11-04-stats-rework-design.md`); the master plan's Phase 3 outline (`docs/superpowers/plans/2026-11-04-stats-rework.md`), Tasks 3.3, 3.4, 3.10 and 3.11.

## Approved mock-up answers (2026-11-05)

Lionel approved the canvas as drawn.

1. **The follow rule.** Following starts with the press that starts a cycle, or once the cursor moves along with the ball, and keeps going while the cursor stays on the ball (36 px, unchanged) and roughly keeps its place there. Judged over the last 0.25 s: it starts when the true ball went 8 px or more and the cursor's place on the ball shifted less than half of that; it keeps going while that shift stays under 16 px, or under half the ball's travel, whichever allows more. A resting cursor never starts; after a press it lasts until the ball goes 16 px in a quarter second (0.49 s into a Foundational cycle, 1.06 s into Smooth Flow, 0.39 s into Torrential Flow). Auto carries following from one cycle into the next and never starts it. The tan ring shows only while following. Presses keep the 36 px reach.
2. **Spirit XP.** For the share of the cycle followed: 12, 30 and 16 for a fully followed Foundational, Smooth Flow and Torrential Flow cycle; also at full Madra; lost at the cap, with no pellets.
3. **When it lands.** Every 0.5 s of following, one `add_stat_xp()`, carried by a puff of three Spirit pellets that pop out of the ball and home into Spirit's cell (0.75 Spirit XP on the Foundational, 1 on the others). The cycle's end pays what is left. A cycle cut short pays what it followed at once: one last puff on a switch, straight into the cell on a close or any other stop, and no line.
4. **The speed curve.** Dropped.
5. **The status line.** The 13 lines of Task 7's table.
6. **The cycle line.** Chest: "Last cycle · +30 Madra · +12 Spirit XP · no zones", "Last cycle · +80 Madra · +30 Spirit XP · 3 / 4 zones · 1 PERFECT · +75 Core XP"; "Spirit capped" in place of the Spirit XP once the cap took XP; no Spirit part when nothing was followed. Log, one line (RL-05): "Cycle · +80 Madra · +30 Spirit XP · +75 Core XP".

## Global Constraints

- GDScript: explicit types on every variable and return; public functions without `_` and with a `##` doc; private ones with `_`; `%Unique` node refs; `#---` section headers; no `print()` (Log only).
- No text is cut off: changed board text wraps and the board grows; `cycling_view.tscn` joins `BOARD_SCENES`; nothing joins `KNOWN_TRIMMERS`.
- Spirit XP goes only through `CharacterManager.add_stat_xp()`, never once a frame. XP at the cap is lost.
- Presses keep paying Core Density with today's floaters and pellets (#99 moves them).
- No saved field, so no save version. Spirit XP lands in phase 1's training record.
- The cabinet (`scenes/zones/cultivator_plate/`) is not edited: #98 changes it next. Only its public API is called.
- No living doc is edited; the PR's `## Docs to update` lists them. This plan file is the record.
- Copy is exactly the approved text. Screens never print "minor".
- Run a test file in one process with `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`; the whole suite with `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.
- Commit after each task, conventional commits, specific files staged; `_capture94/` (the canvas and measurement scenes) is never committed and is deleted before the PR.

## Review Focus

1. **Frame rate.** The same motion at 30, 60 and 144 FPS and at uneven frame times gives the same streak (to within a frame) and the same Spirit XP (to float error). Pinned in Task 3 and Task 5.
2. **A hitch.** One long frame through the cycle's end keeps a streak whose cursor moved with the ball, and pays Spirit XP for the cycle's time left only. Pinned in Task 5.
3. **Auto.** A streak carries into the next cycle; a cursor resting at the path's start never starts one with Auto on. Pinned in Task 4.
4. **Reaching the cap mid-payment.** The stat takes only what reaches the cap; the result marks it capped; the pellets carry only what it took, so the cabinet holds nothing it never shows. Pinned in Task 1 and Task 5.
5. **Hiding mid-cycle.** The remainder lands straight in the stat, no pellet flies from the hidden board, and the cabinet holds nothing afterwards. Pinned in Task 7.

## File structure

- Create `scenes/cycling/cycling_technique/follow_window.gd`: `FollowWindow`, the last quarter second of a cycle as the follow rule sees it.
- Modify `scenes/cycling/cycling_technique/cycling_rules.gd`: the follow thresholds and `is_following()`.
- Modify `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`: `get_spirit_xp_per_second()`.
- Modify `singletons/character_manager/character_manager.gd`: `add_stat_xp()` returns the XP taken; the stat cache (DM-06); `get_gear_bonus()`'s doc (PK-04).
- Modify `scenes/cycling/cycling_technique/cycling_technique.gd`: following, the Spirit clock, paying a cut cycle, `stat_xp_paid`.
- Modify `scenes/cycling/cycling_technique/cycle_result.gd`: the new totals and lines.
- Modify `scenes/cycling/cycling_view/cycling_view.gd`: the status line and the Spirit pellets.
- Tests: `tests/unit/test_character_manager.gd`, `test_stat_display.gd`, `test_cycling_rules.gd`, `test_follow_window.gd` (new), `test_cycling_technique_data.gd`; `tests/integration/test_cycling_technique.gd`, `test_cycling_view.gd`, `test_zone_panel.gd`, `test_boards_never_trim_text.gd`.

---

### Task 1: The XP a stat took, PK-04 and DM-15

**Files:**
- Modify: `singletons/character_manager/character_manager.gd` (`add_stat_xp()`, `get_gear_bonus()`'s doc)
- Test: `tests/unit/test_character_manager.gd`, `tests/unit/test_stat_display.gd`

**Interfaces:**
- Produces: `CharacterManager.add_stat_xp(stat: AttributeType, amount: float) -> float`: the XP the stat took. All of `amount` short of the cap; the part that bought the level reaching the cap when one does (the rest is lost); 0 at the cap. Signals and logging unchanged. A free level (cost 0) keeps today's guard and returns `amount`.

- [ ] **Step 1: Write the failing tests**

`test_add_stat_xp_returns_the_xp_the_stat_took` (the file's test curve: 10, 20, 40, 80 XP; cap Lv 5), a table:
- Lv 1, 0 XP, +5 → 5.0
- Lv 1, 0 XP, +13 → 13.0
- Lv 4, 70 XP, +50 → 10.0 (Lv 5 reached, 40 lost)
- Lv 5 (the cap), +50 → 0.0

`test_stat_display.gd` `test_a_stat_with_no_icon_has_none`: `var unknown: int = CharacterAttributesData.AttributeType.size()`; `assert_null(StatDisplay.icon_of(unknown as CharacterAttributesData.AttributeType))`.

- [ ] **Step 2: Run both files; the first fails (add_stat_xp returns nothing), the second passes already (it pins the untested branch)**
- [ ] **Step 3: Return the XP taken from `add_stat_xp()`; end `get_gear_bonus()`'s doc sentence at "applies after every FLAT one."**
- [ ] **Step 4: Run both files: PASS**
- [ ] **Step 5: Commit** `feat(character): return the XP a stat took from add_stat_xp`

### Task 2: Cache stat reads until the stats change (DM-06)

**Measured before the cache** (`_capture94/measure.tscn` on `path_open`, the board open, a followed Smooth Flow cycle, editor build): `get_max_madra()` 150 µs a call with no gear and 680 µs with a five-piece Spirit Valley kit; the board, the cabinet and the chest make 32.7 `get_stat()` calls a frame, 3.6 max-Madra reads: 0.54 ms a frame with no gear and 2.47 ms (15% of a 60 FPS frame) with the kit. The Spirit multiplier is read only on `stats_changed` since #91 (146 µs, 575 µs with the kit). The cost shows, so the totals are cached.

**Files:**
- Modify: `singletons/character_manager/character_manager.gd`
- Test: `tests/unit/test_character_manager.gd`

**Interfaces:**
- Produces: `get_stat(stat)` answers from a cache of every stat read since the stats last changed. Every `stats_changed.emit()` in CharacterManager becomes `_stats_changed()`, which clears the cache, then emits. `set_modifier_source()`'s doc: a source is asked again after each change of the stats, and a source whose modifiers change sets itself again. `get_total_attributes_data()` still returns a new snapshot each call.

- [ ] **Step 1: Write the failing tests**
- `test_a_stat_is_read_from_its_sources_once_until_the_stats_change`: a counting source; two `get_stat(Stat.SPIRIT)` reads ask it once; after `set_stat_level(SPIRIT, 2)` the next read asks it again; after an inventory change (`InventoryManager.inventory_changed.emit(...)`) again.
- `test_a_level_bought_with_xp_moves_the_cached_total`: read Spirit's total, `add_stat_xp(SPIRIT, 10.0)` (the test curve's Lv 2), read again: one point higher.
- [ ] **Step 2: Run the file: the first fails**
- [ ] **Step 3: Add the cache and `_stats_changed()`**
- [ ] **Step 4: Run `test_character_manager.gd`, `test_stat_modifier_stack.gd` and the integration files that read stats (`test_character_book.gd`, `test_cultivator_plate.gd`): PASS**
- [ ] **Step 5: Measure again with `_capture94/measure.tscn` and record the numbers here and in the PR**
- [ ] **Step 6: Commit** `perf(character): cache stat reads until the stats change`

### Task 3: The follow rule and its window

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycling_rules.gd`
- Create: `scenes/cycling/cycling_technique/follow_window.gd`
- Modify: `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`
- Test: `tests/unit/test_cycling_rules.gd`, `tests/unit/test_follow_window.gd`, `tests/unit/test_cycling_technique_data.gd`

**Interfaces:**
- Produces, in `CyclingRules`: `FOLLOW_WINDOW = 0.25`, `FOLLOW_START_TRAVEL = 8.0`, `FOLLOW_KEEP_DRIFT = 16.0`, `FOLLOW_DRIFT_SHARE = 0.5`; `static func is_following(on_ball: bool, was_following: bool, travel: float, drift: float) -> bool`: off the ball, false; following, `drift < maxf(FOLLOW_KEEP_DRIFT, travel * FOLLOW_DRIFT_SHARE)`; not following, `travel >= FOLLOW_START_TRAVEL and drift < travel * FOLLOW_DRIFT_SHARE`.
- Produces `FollowWindow` (RefCounted): `reset(starts_following: bool) -> void` (an empty window; its first frame follows if the cursor is on the ball and `starts_following`); `judge(seconds: float, on_ball: bool, ball: Vector2, cursor: Vector2) -> bool` (adds a frame `seconds` long that ended with the true ball at `ball` and the cursor at `cursor`, and returns the verdict); `is_following() -> bool`. It measures `travel` (true ball) and `drift` (the cursor's offset from the true ball) against the newest frame at least `FOLLOW_WINDOW` old, or the oldest kept frame until one is, to within 0.000001 s; older frames are dropped.
- Produces `CyclingTechniqueData.get_spirit_xp_per_second() -> float`: `spirit_xp_per_cycle / cycle_duration`, 0.0 for a cycle of no length.

- [ ] **Step 1: Write the failing tests**
- `test_cycling_rules.gd` `test_is_following`, a table: off the ball (on false, was true, 40, 0) → false; keeps on a still ball (true, true, 0, 10) → true; keeps at speed (true, true, 60, 25) → true; loses at speed (true, true, 60, 31) → false; a resting cursor loses once the ball goes 16 px (true, true, 20, 20) → false; a hand held still on a creeping ball keeps (true, true, 12, 12) → true; starts moving with the ball (true, false, 8, 3.9) → true; no start on a creeping ball (true, false, 7.9, 0) → false; no start resting (true, false, 40, 40) → false; no start loosely (true, false, 40, 20) → false.
- `test_follow_window.gd`, each at 30, 60 and 144 FPS with a ball moving 200 px/s along x: `test_the_press_starts_following_on_the_ball` (reset(true): first frame on the ball true, off it false; reset(false): false); `test_a_resting_cursor_never_follows` (cursor fixed on the path, `on_ball` by the 36 px reach: never true); `test_a_cursor_moving_with_the_ball_starts_and_keeps_following` (cursor 10 px ahead of the ball from the first frame, reset(false): true from the first frame the ball has gone 8 px, and every frame after); `test_catching_the_ball_takes_a_window` (cursor far for 1 s, then on the ball: false until the first frame at least 0.25 s after it arrived, then true); `test_a_still_ball_keeps_a_streak_and_starts_none`; `test_a_long_frame_is_judged_against_the_frame_before_it` (two 1/60 frames, then one 6 s frame whose cursor moved with the ball: still following).
- `test_cycling_technique_data.gd` `test_spirit_xp_per_second`: the three shipped techniques give 1.5, 2.0 and 2.0; a cycle of no length gives 0.0.
- [ ] **Step 2: Run the three files: they fail**
- [ ] **Step 3: Implement the constants, `is_following()`, `FollowWindow` (an inner `Sample` class with `time`, `ball`, `offset`) and `get_spirit_xp_per_second()`**
- [ ] **Step 4: Run the three files: PASS**
- [ ] **Step 5: Commit** `feat(cycling): judge following by moving with the ball`

### Task 4: Only following draws Madra

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycling_technique.gd`, `scenes/cycling/cycling_view/cycling_view.gd` (the one `is_tracking()` call)
- Test: `tests/integration/test_cycling_technique.gd`, `tests/integration/test_cycling_view.gd`

**Interfaces:**
- Consumes: `FollowWindow`, `CyclingRules.is_following()`.
- Produces: `CyclingTechnique.start_cycle(starts_following: bool = true) -> bool` (a press, or an Auto restart carrying the last frame's verdict); `is_following() -> bool` replaces `is_tracking()`. `advance()` judges each frame with the reach against the drawn ball and the window against the true ball; the tan ring and the Madra steps follow the verdict; the rate window records a frame as drawing only while following with room under the max. `wants_pointer()` keeps the reach alone.

- [ ] **Step 1: Write the failing tests**
- `test_a_cursor_resting_on_the_path_draws_nothing`: the Foundational (path start, middle and end at (322, 400) drawn); the cursor rests there from the second frame (the first is far); a whole cycle requests no Madra step and the ring never shows.
- `test_a_cursor_resting_after_the_press_draws_only_the_creeping_start`: the same with the cursor there from the first frame: it follows only until the ball has gone 16 px over the last quarter second (about 0.64 s on the unscaled path), at most 10 steps, none after 0.8 s, and nothing at the middle or the end.
- `test_following_needs_the_cursor_on_the_ball_and_moving_with_it` (rewrites `test_tracking_needs_the_cursor_on_the_ball`): not before a cycle; the first frame off the ball, no; jumping onto the ball mid-cycle, not until the window passes; past the 36 px reach, no.
- `test_on_the_ball_uses_the_drawn_ball` and `test_the_cursor_follows_on_the_ring_and_not_past_it` (rewrite the two straight-technique tests through a press: the first frame judges the reach alone).
- `test_auto_carries_following_into_the_next_cycle` and `test_auto_never_starts_following_for_a_resting_cursor`.
- `test_rate_rises_and_falls_within_a_second` takes the window: half a second on the ball after a second off reads a quarter of the steady rate (0.25 s drew).
- `test_cycling_view.gd`: the status tests read `is_following()` through the view; no copy changes yet.
- [ ] **Step 2: Run both files: the new tests fail**
- [ ] **Step 3: Replace `_tracking` with the window's verdict**
- [ ] **Step 4: Run both files: PASS**
- [ ] **Step 5: Commit** `feat(cycling): draw Madra only while following the ball`

### Task 5: Spirit XP for following

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycling_technique.gd`, `scenes/cycling/cycling_technique/cycle_result.gd`
- Test: `tests/integration/test_cycling_technique.gd`

**Interfaces:**
- Consumes: `add_stat_xp() -> float` (Task 1), `get_spirit_xp_per_second()` (Task 3).
- Produces: `CyclingTechnique.STAT_XP_INTERVAL = 0.5`; `signal stat_xp_paid(stat: CharacterAttributesData.AttributeType, from_pos: Vector2, amount: float)`, emitted after a payment the stat took XP from (amount > 0), with the drawn ball's global centre. A payment is `get_spirit_xp_per_second() * seconds`: every `STAT_XP_INTERVAL` of followed time (to within the Madra step's epsilon), what is left at the cycle's end before `cycle_completed`, and what is left when `setup()` or `stop_cycling()` cuts a cycle short (before `technique_data` changes, from where the ball was). Leaving the tree pays nothing.
- Produces on `CycleResult`: `followed_ratio: float` (followed seconds over the cycle's length, kept up to date while it runs), `stat_xp: Dictionary` (AttributeType to the XP the stat took), `capped_stats: Array[CharacterAttributesData.AttributeType]`, `record_stat_xp(stat, taken: float, capped: bool) -> void`, `get_stat_xp(stat) -> float`, `is_stat_capped(stat) -> bool`.

- [ ] **Step 1: Write the failing tests**
- `test_following_pays_spirit_xp_every_half_second`: the Foundational, 1.6 s followed: `stat_xp_paid` 3 times, 0.75 each, and Spirit's XP is 2.25.
- `test_a_fully_followed_cycle_pays_its_spirit_xp` at 30, 60 and 144 FPS and at the uneven seeded frame times: 12.0 on the Foundational to within 0.0001, `followed_ratio` 1.0 to within 0.01, the result's Spirit XP 12.0.
- `test_following_pays_spirit_xp_with_madra_full`: Madra at its max, a followed Foundational cycle pays 12 Spirit XP and no Madra.
- `test_a_resting_cursor_earns_no_spirit_xp`.
- `test_a_stopped_cycle_keeps_the_spirit_xp_it_followed` (1.2 s followed, `stop_cycling()`: 1.8 XP in all, the last 0.3 paid at the stop) and `test_a_switched_cycle_pays_at_the_old_rate` (1.2 s of Smooth Flow, then `setup(foundation)`: 2.4 XP, paid from the old ball's place).
- `test_spirit_xp_at_the_cap_marks_the_result`: Spirit at the cap: the cycle pays, `stat_xp_paid` never fires, the result has Spirit in `capped_stats` and 0 taken.
- `test_the_payment_that_reaches_the_cap_carries_only_what_it_took`: Spirit one level short of the cap with 0.3 XP missing: the next payment's `stat_xp_paid` amount is 0.3, Spirit is capped and marked.
- `test_a_hitch_through_the_end_pays_only_the_time_left`: as the Madra hitch test: 25% followed, then a 16 s frame with the cursor where the ball ends: 12.0 in all.
- [ ] **Step 2: Run the file: the new tests fail**
- [ ] **Step 3: Add the followed-time clock, the payments, the signal and the result's totals**
- [ ] **Step 4: Run the file: PASS**
- [ ] **Step 5: Commit** `feat(cycling): pay Spirit XP for the time the ball is followed`

### Task 6: The cycle line

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycle_result.gd`
- Test: `tests/unit/test_cycling_rules.gd`, `tests/integration/test_zone_panel.gd`

**Interfaces:**
- Produces: `summary()` (the chest's `result_line()`): Madra, then each Spiritual stat with a part in StatDisplay.SPIRITUAL order ("Spirit capped" when capped, else "+N Spirit XP" when the rounded XP is 1 or more), then the zones, the PERFECTs, then "+N Core XP" or "Core full". `log_line()`: "Cycle · " with Madra, the stat parts and the Core part only.

- [ ] **Step 1: Write the failing tests** (`test_result_lines`, `test_log_line`, `test_a_full_core_line_says_so` rewritten; new `test_the_lines_show_the_spirit_xp`):
- "Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 Core XP"
- "Last cycle · +30 Madra · +12 Spirit XP · no zones"
- "Last cycle · +80 Madra · +30 Spirit XP · 3 / 4 zones · 1 PERFECT · +75 Core XP"
- capped: "Last cycle · +57 Madra · Spirit capped · no zones"
- 0.4 XP: no Spirit part
- log: "Cycle · +80 Madra · +30 Spirit XP · +75 Core XP"; "Cycle · +30 Madra · +12 Spirit XP"; "Cycle · +57 Madra · Spirit capped"; core full: "Cycle · +186 Madra · Core full"
- `test_zone_panel.gd`: "+75 XP" and "+99999 XP" become "+75 Core XP" and "+99999 Core XP" in the two last-cycle tests.
- [ ] **Step 2: Run both files: they fail**
- [ ] **Step 3: Rewrite `summary()` and `log_line()`**
- [ ] **Step 4: Run both files: PASS**
- [ ] **Step 5: Commit** `feat(cycling): show the Spirit XP on the cycle line`

### Task 7: The board: status line and Spirit pellets

**Files:**
- Modify: `scenes/cycling/cycling_view/cycling_view.gd`
- Test: `tests/integration/test_cycling_view.gd`, `tests/integration/test_boards_never_trim_text.gd`

**Interfaces:**
- Consumes: `stat_xp_paid` (Task 5), `CultivatorPlate.get_stat_cell_global_position()`, `hold_stat_xp()`, `release_stat_xp()`, `LacquerPellet.stat_ramp()`, `PelletFlight.burst()`.
- Produces: `static func status_line(cycled_before: bool, running: bool, elapsed: float, duration: float, following: bool, madra_full: bool, spirit_capped: bool, zoneless: bool, zones_pay_xp: bool) -> String`, where `zoneless` is a technique with no zones (false with no technique). Not running: READY_AGAIN once cycled, else READY_NO_ZONES when zoneless, else READY_FIRST. Running: Madra full first (capped or not, zones or not), then Spirit capped, then the seconds with FOLLOW_SUFFIX. `STAT_PELLETS = 3`, `STAT_PELLET_FLIGHT = 0.6`, `STAT_PELLET_FLIGHT_STEP = 0.05`, `STAT_BURST_REACH = 28.0`: a payment's pellets burst from the ball and home into the stat's cell, each carrying an even share held on the cabinet until it lands; none while the board is hidden or has no cabinet.

The copy, verbatim:

| Constant | Line |
|---|---|
| READY_FIRST | Click the Madra ball to begin a cycle. |
| READY_NO_ZONES | No zones to press: click the ball and follow it. |
| READY_AGAIN | Click the ball for another cycle. |
| CYCLING_FORMAT, FOLLOW_SUFFIX | Cycling · %d / %d s, " · follow the ball" |
| MADRA_FULL_FOLLOWING | Madra full · following still trains Spirit |
| MADRA_FULL_OFF | Madra full · follow the ball to train Spirit |
| MADRA_FULL_ZONES_FOLLOWING | Madra full · following and zones still pay XP |
| MADRA_FULL_ZONES_OFF | Madra full · follow the ball · zones still pay XP |
| SPIRIT_CAPPED_FOLLOWING | Spirit capped · following still fills Madra |
| SPIRIT_CAPPED_OFF | Spirit capped · follow the ball for Madra |
| MADRA_FULL_CAPPED | Madra full · Spirit capped |
| MADRA_FULL_CAPPED_ZONES | Madra full · Spirit capped · zones still pay XP |

- [ ] **Step 1: Write the failing tests**
- `test_status_line_copy` rewritten as a table of every row above.
- `test_the_status_label_stops_promising_xp_at_a_full_core` now reads MADRA_FULL_FOLLOWING; new `test_the_status_line_says_spirit_is_capped` and `test_a_technique_with_no_zones_says_so` (the Foundational's ready line, and READY_AGAIN after a cycle).
- `test_spirit_pellets_fly_to_spirit_s_cell`: a followed half second sends 3 pellets in Spirit's ramp, the cabinet's Spirit cell shows the XP once they land, not before.
- `test_no_spirit_pellets_at_the_cap`.
- `test_hiding_the_view_pays_the_spirit_xp_without_pellets`: 0.3 s followed, `hide()`: Spirit's XP is up 0.45, the effects layer holds no pellet, and the cell shows it.
- `test_boards_never_trim_text.gd`: `cycling_view.tscn` in BOARD_SCENES, and ActionLabel, TitleLabel and StatusLabel in the wrapping table.
- [ ] **Step 2: Run both files: they fail**
- [ ] **Step 3: Implement the status line and `_on_stat_xp_paid()`**
- [ ] **Step 4: Run both files: PASS**
- [ ] **Step 5: Commit** `feat(cycling): send Spirit pellets and say what following pays`

### Task 8: Wrap

- [ ] **Step 1:** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`: every test passes (a failure is confirmed in one process before acting).
- [ ] **Step 2:** The issue's Done-when checks on the chunk's own save: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=path_open --save=user://dev/runs/cycling-follow.tres`: parking, following (pellets, the chest line and the log), a close and a switch mid-cycle, a full pool, Spirit raised to the cap, the Foundational's line, Smooth Flow's presses paying Core Density, and "Spirit reached Lv N".
- [ ] **Step 3:** An old save still loads and cycles (a copy of a pre-#94 save).
- [ ] **Step 4:** Delete `_capture94/`; tick this plan; note what was built differently below.
- [ ] **Step 5:** Merge `main` once, run the suite, open the PR that closes #94 with `## Docs to update`.

## Built differently

(Filled in as the work lands.)
