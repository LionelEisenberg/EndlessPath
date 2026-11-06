# Cycling Trains Mind and Control Implementation Plan (chunk #99)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Smooth Flow's presses pay Control and Torrential Flow's new seals pay Mind, with no Core Density from cycling, the board, the chest, the log, the drawers, the Cycling card and Torrential Flow's path node all showing what each technique trains.

**Architecture:** The data says what each technique trains: zone tier XP pays the technique's other stat, and new seal fields (`seal_seconds`, `seal_xp`) place seals on the path. A pure rule (`CyclingRules.seal_progress()`, `random_seal()`) judges each key. `SealNode` is a seal on the path, like `CyclingZone` is a zone. `CyclingTechnique` pays both through `CharacterManager.add_stat_xp()`, and `CycleResult` keeps each stat's XP and the zones' and seals' outcomes. `CyclingView` sends pellets to the stat's cabinet cell and writes the status line. `CyclingViewState` routes four new input actions to the seals. A new `LastCycleCard` replaces the chest's text line, and `LogWindow` learns to draw inline icons.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** issue #99 and its [approved mock-up answers](https://github.com/LionelEisenberg/EndlessPath/issues/99#issuecomment-6676694306) (canvas [Cycling trains Mind and Control](https://claude.ai/artifact/GE7ydpWnchD5XGsRgKa6QA), round 3); #91's roster answers (#91's comment, 2026-11-05); #94's pay path and status line (#94's two comments, and `docs/superpowers/plans/2026-11-05-following-trains-spirit.md`); the stats rework spec's Phase 3 (`docs/superpowers/specs/2026-11-04-stats-rework-design.md`); the master plan's Tasks 3.1, 3.5, 3.6, 3.10 and 3.11 (`docs/superpowers/plans/2026-11-04-stats-rework.md`).

## Approved mock-up answers (2026-11-06)

Lionel approved round 3 of the canvas as drawn. Round 1 drew Mind as an unbroken-following streak (too close to Spirit's following). Round 2 drew "follow the ball through the dark" (rejected). Round 3 drew seals.

1. **Control comes from the presses.** Today's tier rule is unchanged. Hits pay Control XP: Smooth Flow's zones 1, 2 and 4 pay 6 / 3 / 1, the top zone (3) pays 12 / 6 / 2, so four PERFECTs pay 30. Every zone file writes all three values out. Torrential Flow's press zone goes. Cycling pays no Core Density.
2. **A hit's floater and pellets.** "PERFECT +12 [Control's icon] Control" in the tier's colour, kept on the board at an edge zone. The tier's 8, 5 or 3 pellets fly to Control's cell in `LacquerPellet.stat_ramp(CONTROL)`. No core pellets; the cabinet's held core XP code stays, unused, for #103.
3. **Mind comes from seals.**
   - Three diamond seal nodes on Torrential Flow's path, reached at 2, 4.5 and 7 s into its 8 s cycle.
   - 1.5 s before the ball arrives, the node's rim turns green and a seal of three random arrows shows over it.
   - Keys: W A S D or the arrow keys. The next arrow is cream, each one hit turns brass. A wrong key flashes the arrows red, shakes the seal and starts it over.
   - Opened, the node fills green. As the ball bursts through it: "+5 [Mind's icon] Mind" and five green pellets to Mind's cell, 15 a cycle.
   - Too late, the node cracks and goes dark, and pays nothing. A stop or a switch before the ball reaches an open node drops it. A full Madra pool changes nothing.
4. **Keys.** Four input actions handled only by `CyclingViewState`; the `project.godot` change is committed alone.
5. **Combined play.** One technique at a time (#91). No save field, no save version.
6. **At the cap.** "PERFECT · Control capped" and "OPEN · Mind capped" in brass, no pellets, the XP lost.
7. **Status line.** Running: Smooth Flow adds " Click it over a zone for Control XP.", Torrential Flow " Open each seal with W A S D for Mind XP."; each clause drops while its stat is capped, read as a cycle starts.
8. **The last cycle card.** The Now tray's frame, a brass "Last cycle" tag, 32 px icons with "+N" (Madra, then Spirit, Mind, Control), the zones' studs or the seals' nodes on the right, "capped" in brass for a capped stat. It grows a row rather than trim.
9. **The log.** "Cycle [Madra icon] +80 [Spirit icon] +30 [Control icon] +21", "capped" for a capped stat, one line. `LogWindow` draws inline icons on the board and in the full log, fading with the line.
10. **The drawers.** A "Trains" row with 16 px icons ("Trains Spirit", "Trains Spirit and Control", "Trains Spirit and Mind"). Torrential Flow's detail reads "50 Madra · 8 s cycle · 3 seals".
11. **The Cycling card.** What the known techniques train: "Madra and Spirit XP", "Madra, Spirit and Control XP", "Madra, Spirit, Mind and Control XP", with icons.
12. **Torrential Flow's path node.** "A faster, more unwieldy cycling technique. It draws Madra quicker than Smooth Flow, and opening its seals trains Mind." A cycling technique unlock's effect line names the technique. Benefit: "Torrential Flow unlocked".

## Global Constraints

- GDScript: explicit types on every variable and return; public functions without `_` and with a `##` doc; private ones with `_`; `%Unique` node refs; `#---` section headers; no `print()` (Log only).
- UI nodes live in `.tscn` scenes with theme variants; scripts set text, visibility, textures and frames. Repeated items (a stud per zone, a floater per seal) are instanced from their own scene, as `CyclingView` does floaters and `ForagingPresenter` does finds.
- No text is cut off: new labels wrap or sit in containers that wrap whole entries, and boards grow. New board scenes join `BOARD_SCENES`; nothing joins `KNOWN_TRIMMERS`.
- Stat XP goes only through `CharacterManager.add_stat_xp()`, which returns what the stat took. XP at the cap is lost; a capped stat gets no pellets.
- The cabinet (`scenes/zones/cultivator_plate/`) is not edited: only `get_stat_cell_global_position()`, `hold_stat_xp()` and `release_stat_xp()` are called. `hold_core_xp()`, `release_core_xp()` and `rewind_core()` stay, unused.
- No saved field, so no save version. Old saves load as they are.
- `project.godot`'s change is its own commit, and `git diff project.godot` shows the `[dialogic]` directory keys intact.
- No living doc is edited; the PR's `## Docs to update` lists them. This plan file is the record.
- Copy is exactly the approved text. Screens never print "minor".
- New art is written by script, ends in `_ai`, and no existing art file is edited.
- Run one test file with `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=<res path> -gexit`; the suite with `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`.
- Commit after each task, conventional commits, specific files staged. `mockups/` is gitignored and never committed.

## Review Focus

1. **A key held down.** An echo of a held key presses nothing; only a fresh press does. Pinned in Task 6.
2. **A key with no seal showing.** A key between seals, or on a technique with none, does nothing: no crack, no error. Pinned in Task 5.
3. **A hitch across a seal's whole window.** One long frame that passes both its show time and its arrival shows the seal and fizzles it in that frame, paying nothing. Pinned in Task 5.
4. **Arrow keys taken by focus.** Clicking the board's Auto toggle or close button never gives it keyboard focus, so the arrow keys still reach the seals. Pinned in Task 6.
5. **A hit that reaches the cap.** The floater shows the hit's XP, the pellets carry only what Control took, and a hit at the cap shows the capped floater with no pellets. Pinned in Task 7.

## File structure

- Modify `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`: `seal_seconds`, `seal_xp`, `get_xp_per_cycle()`.
- Modify `scripts/resource_definitions/cycling/cycling_technique/cycling_zone_data.gd`: the tier XP's doc.
- Modify the content: `resources/cycling/cycling_techniques/smooth_flow/cycling_zone_data/zone_1.tres` to `zone_4.tres`, the three technique files, `resources/path_progression/pure_madra/nodes/torrential_flow.tres`.
- Modify `scenes/cycling/cycling_technique/cycling_rules.gd`: the seal rule.
- Create `scenes/cycling/cycling_technique/seal_node.gd` and `seal_node.tscn`: one seal on the path.
- Modify `scenes/cycling/cycling_technique/cycling_technique.gd`: presses pay the other stat; seals.
- Modify `scenes/cycling/cycling_technique/cycle_result.gd`: outcomes, paid stats, the log line with icons; the chest line goes.
- Modify `scenes/cycling/cycling_view/cycling_view.gd` and `.tscn`: floaters, pellets, seal floaters, status line, `press_seal()`, buttons without focus.
- Modify `scenes/ui/main_view/states/cycling_view_state.gd` and `project.godot`: the seal keys.
- Modify `scenes/common/lacquer/lacquer_floater/lacquer_floater.gd`: `pop_stat()`.
- Modify `scripts/utils/lacquer_text.gd`: `list_words()`. `scripts/utils/theme_constants.gd`: `LACQUER_MIND`.
- Create `scenes/zones/zone_panel/last_cycle_card/last_cycle_card.gd`, `.tscn`, `reward_chip.tscn` and `last_cycle_stud.tscn`; modify `scenes/zones/zone_panel/zone_panel.gd` and `.tscn`.
- Modify `scenes/ui/log_window/log_window.gd` and `.tscn`: inline icons.
- Modify `scenes/cycling/technique_drawer/technique_drawer.gd` and `.tscn`: seals in the detail, the Trains row.
- Modify `scenes/zones/zone_action_button/presenters/cycling_presenter.gd` and `.tscn`: the reward row.
- Modify `scenes/path_progression/path_details_card.gd` and `singletons/cycling_manager/cycling_manager.gd` (`get_technique()`).
- Art: `assets/ui/lacquer/cycling/lacquer_cyc_seal_strip_ai.png`, `lacquer_cyc_seal_arrows_ai.png`, `lacquer_cyc_last_studs_ai.png`.
- Tests: `tests/unit/test_cycling_technique_data.gd`, `test_cycling_technique_catalog.gd`, `test_cycling_rules.gd`, `test_cycling_manager.gd`, `test_lacquer_pieces.gd`, `test_cycling_mode.gd`, `test_path_details_card.gd` (new); `tests/integration/test_seal_node.gd` (new), `test_cycling_technique.gd`, `test_cycling_view.gd`, `test_last_cycle_card.gd` (new), `test_zone_panel.gd`, `test_log_board.gd`, `test_technique_drawer.gd`, `test_zone_action_cards.gd`, `test_boards_never_trim_text.gd`.

---

### Task 1: What each technique trains, in the data

**Files:**
- Modify: `cycling_technique_data.gd`, `cycling_zone_data.gd`, the four Smooth Flow zone files, `smooth_flow.tres`, `torrential_flow.tres`, `foundation_cycling_technique.tres`
- Test: `tests/unit/test_cycling_technique_data.gd`, `tests/unit/test_cycling_technique_catalog.gd`

**Interfaces:**
- Produces: `CyclingTechniqueData.seal_seconds: Array[float]` (when the ball reaches each seal node, seconds into the cycle, in order) and `seal_xp: float` (the other stat's XP an opened seal pays). `get_xp_per_cycle(stat: CharacterAttributesData.AttributeType) -> float`: a cycle at its best: SPIRIT → `spirit_xp_per_cycle`; the technique's `minor_stat` → the zones' `perfect_xp` summed plus `seal_xp × seal_seconds.size()`; any other stat → 0. #102 reads it.

- [ ] **Step 1: Write the failing tests**

`test_cycling_technique_data.gd` `test_xp_per_cycle`, a table on fixtures (no catalog): Spirit only (12 Spirit, 0 Mind, 0 Control); zones with minor CONTROL, perfect_xp 6, 6, 12, 6 (30 Control, 0 Mind); seals with minor MIND, `seal_seconds` [2.0, 4.5, 7.0], `seal_xp` 5.0 (15 Mind, 0 Control); and Strength asked of any of them (0).

`test_cycling_technique_catalog.gd`:
- `test_zones_pay_control_and_seals_pay_mind`: a technique with zones has `minor_stat` CONTROL and no seals; with seals, MIND and no zones; with neither, -1.
- `test_seals_fit_their_cycle`: each seal's time ≥ `CyclingRules.SEAL_LEAD` and ≤ `cycle_duration`, ascending, and each at least `SEAL_LEAD` after the one before (windows never overlap); `seal_xp` > 0 whenever there are seals. (`SEAL_LEAD` comes in Task 2; write this test with Task 2 if you take Task 1 alone.)
- `test_every_zone_writes_out_its_tier_xp`: every zone of every technique is its own file whose text contains `\nperfect_xp = `, `\ngood_xp = ` and `\nok_xp = `.
- `test_the_roster_s_xp_per_cycle`: Foundational 12 Spirit; Smooth Flow 30 Spirit, 30 Control; Torrential Flow 16 Spirit, 15 Mind.
- `WRITTEN_OUT_FIELDS` gains `"seal_seconds"` and `"seal_xp"`.

- [ ] **Step 2: Run both files; the new tests fail.**

- [ ] **Step 3: Add the fields and `get_xp_per_cycle()`; write the content.**
- `cycling_zone_data.gd`: the tier XP's doc says it is XP of the technique's other stat. Defaults stay.
- Zones 1, 2 and 4: `perfect_xp = 6`, `good_xp = 3`, `ok_xp = 1`; zone 3: 12, 6, 2; all three written in every file.
- `torrential_flow.tres`: the inline zone sub-resource goes, `cycling_zones` is empty, `seal_seconds = Array[float]([2.0, 4.5, 7.0])`, `seal_xp = 5.0`.
- `smooth_flow.tres` and `foundation_cycling_technique.tres`: `seal_seconds = Array[float]([])`, `seal_xp = 0.0`, written out.

- [ ] **Step 4: Run both files; they pass.**

- [ ] **Step 5: Commit** — `feat(cycling): pay zones in Control and place Torrential Flow's seals`

### Task 2: The seal rule

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycling_rules.gd`
- Test: `tests/unit/test_cycling_rules.gd`

**Interfaces:**
- Produces, in `CyclingRules`: `enum Arrow { UP, LEFT, DOWN, RIGHT }`; `const SEAL_LENGTH: int = 3`; `const SEAL_LEAD: float = 1.5`; `static func seal_progress(seal: Array[int], keyed: int, arrow: int) -> int` (the arrows keyed after `arrow`: `keyed + 1` when `arrow` is `seal[keyed]`, else 0: a wrong key starts the seal over); `static func random_seal(rng: RandomNumberGenerator) -> Array[int]` (`SEAL_LENGTH` arrows, never all the same).

- [ ] **Step 1: Write the failing tests**
- `test_seal_progress`, a table on the seal [UP, RIGHT, DOWN]: 0 keyed + UP → 1; 1 + RIGHT → 2; 2 + DOWN → 3; 0 + LEFT → 0; 2 + UP → 0; 1 + UP → 0.
- `test_random_seal`: with `rng.seed = 7`, 200 seals: each has 3 arrows, each 0 to 3, not all three equal; and two RNGs on one seed give the same seals.

- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement.** The class doc gains a paragraph on seals.
- [ ] **Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(cycling): add the seal rule`

### Task 3: Presses pay the other stat

**Files:**
- Modify: `cycling_technique.gd` (`try_score_zone()`, `zone_scored`), `cycle_result.gd` (`xp` and `core_full` go)
- Test: `tests/integration/test_cycling_technique.gd`, `tests/unit/test_cycling_rules.gd`

**Interfaces:**
- Produces: `signal zone_scored(zone: CyclingZone, tier: CyclingRules.Tier, xp: int, taken: float)`: `xp` what the hit was worth, `taken` what the technique's other stat took (0 at its cap, or for a technique with no other stat). `try_score_zone()` pays `CharacterManager.add_stat_xp(technique_data.minor_stat, xp)` when `minor_stat >= 0`, records it with `_result.record_stat_xp()` (capped when it took less than `xp`), and never calls `CultivationManager`.
- Consumes: Task 1's zone values.

- [ ] **Step 1: Rewrite and add the tests**
- `test_scoring_an_active_zone_uses_the_tier_rule`: the hit's Control XP goes to Control, and Core Density's level and XP don't move.
- `test_a_scored_zone_shows_in_the_result`: Smooth Flow's zone 1 PERFECT gives `result.get_stat_xp(CONTROL) == 6.0`, one zone scored, one PERFECT.
- `test_a_zone_scored_at_the_cap_marks_the_result` (replaces the core version): Control at the cap; a hit leaves Control's XP at 0, `is_stat_capped(CONTROL)` on the result, and `zone_scored`'s `taken` is 0.
- `test_the_zone_that_fills_the_core_marks_the_result` goes.
- `test_cycling_rules.gd`: the helpers that set `result.xp` and `core_full` go with `test_a_full_core_line_says_so`; Task 9 rewrites the line tests.

- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement.** `CycleResult` loses `xp`, `core_full`, `CORE_XP_FORMAT` and its core part; the class and signal docs follow.
- [ ] **Step 4: Run `test_cycling_technique.gd`; it passes** (the view's tests are Task 7's).
- [ ] **Step 5: Commit** — `feat(cycling): make presses pay Control, not Core Density`

### Task 4: The seal node

**Files:**
- Create: `scenes/cycling/cycling_technique/seal_node.gd`, `seal_node.tscn`, art `lacquer_cyc_seal_strip_ai.png` (48 px frames IDLE, SHOWING, OPEN, SPENT: the canvas's diamond) and `lacquer_cyc_seal_arrows_ai.png` (20 px: columns UP, LEFT, DOWN, RIGHT; rows WAITING tan-dim, NEXT cream, DONE brass, WRONG red)
- Test: `tests/integration/test_seal_node.gd`; `test_boards_never_trim_text.gd` needs nothing (no labels)

**Interfaces:**
- Produces: `class_name SealNode extends Node2D`, built like `CyclingZone`. `enum State { IDLE, SHOWING, OPEN, SPENT }`. `var arrive_seconds: float`. `func setup(seconds: float) -> void` (IDLE, plate hidden). `func show_seal(arrows: Array[int]) -> void` (SHOWING; the plate over the node shows the arrows, the first NEXT, the rest WAITING). `func press(arrow: int) -> bool` (only while SHOWING: true when the key was right; the arrow turns DONE and the next NEXT; the last opens the node; false for a wrong key: every arrow WRONG for `CRACK_SECONDS` (0.3 s) while the plate shakes 2 px left and right each 0.05 s, then back to the first NEXT; outside SHOWING it returns false and changes nothing). `func burst() -> void` (the ball passed an open node: the plate hides, the node keeps OPEN). `func fizzle() -> void` (SPENT, plate hidden). `func reset() -> void` (IDLE). `func get_state() -> State`. `func get_arrows() -> Array[int]`. `func get_keyed() -> int`. An open plate hides `OPEN_PLATE_SECONDS` (0.25 s) after it opens.
- Nodes: `%Socket` (LacquerStripRect, 48 px, centred on the node), `%Plate` (Panel, `assets/styleboxes/lacquer/token.tres`, 92 × 30, its bottom 16 px above the socket's top), `%Glyph1` to `%Glyph3` (LacquerStripRect, 20 px, at x 12, 36, 60 in the plate). Everything ignores the mouse.

- [ ] **Step 1: Write the failing tests** (`test_seal_node.gd`, the scene instanced and stepped with `_process()`):
- `test_a_new_node_waits`: IDLE, plate hidden.
- `test_showing_a_seal_shows_its_arrows`: SHOWING, plate visible, `get_arrows()` as given, glyph 1's frame (arrow, NEXT), glyphs 2 and 3 WAITING.
- `test_the_right_keys_open_it`: three right presses return true; after them OPEN; after 0.25 s the plate hides.
- `test_a_wrong_key_starts_it_over`: one right, one wrong → false, `get_keyed()` 0, every glyph WRONG; after 0.3 s glyph 1 is NEXT again and the plate is back at its place.
- `test_keys_outside_a_showing_seal_do_nothing`: IDLE, OPEN and SPENT nodes return false and keep their state.
- `test_fizzle_and_burst`: a SHOWING node fizzles to SPENT with the plate hidden; an OPEN node bursts and stays OPEN; `reset()` makes either IDLE.

- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Draw the two strips by script (from the canvas mock) and build the scene and script.**
- [ ] **Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(cycling): add the seal node`

### Task 5: Seals in the technique

**Files:**
- Modify: `cycling_technique.gd`, `cycle_result.gd`
- Test: `tests/integration/test_cycling_technique.gd`

**Interfaces:**
- Consumes: Tasks 1, 2 and 4.
- Produces, in `CyclingTechnique`: `var seal_nodes: Array[SealNode]` (one per `seal_seconds`, built in `setup()` under the path like the zones, at the path's point for the eased ratio at that second, snapped to even px); `var seal_rng: RandomNumberGenerator` (tests seed it); `func press_seal(arrow: int) -> bool` (presses the seal that shows; false with none); `signal seal_shown(seal: SealNode)`; `signal seal_burst(seal: SealNode, xp: float, taken: float)` (after the payment; `xp` is `seal_xp`, `taken` what the other stat took); `signal seal_missed(seal: SealNode)`.
- `advance()` handles the seals after the zones: an IDLE seal shows once the elapsed time reaches `arrive_seconds - SEAL_LEAD`, with `CyclingRules.random_seal(seal_rng)`; once it reaches `arrive_seconds`, an OPEN seal bursts (pays `add_stat_xp(minor_stat, seal_xp)`, records it, emits `seal_burst`), and a SHOWING one fizzles (emits `seal_missed`). One frame can do both.
- `start_cycle()` and `_return_to_ready()` reset every seal: an open seal the ball had not reached is dropped.
- `CycleResult` gains `zone_states: Array[int]` and `seal_states: Array[int]` (each zone's and seal's state as the cycle ended, in data order), written by `_finish_cycle()`.

- [ ] **Step 1: Write the failing tests** (Torrential Flow, the cursor riding the ball, `seal_rng.seed` fixed):
- `test_the_seals_sit_where_the_ball_arrives`: three nodes; each node's position is where the drawn ball is at its second (within 2 px).
- `test_a_seal_shows_its_lead_before_the_ball_arrives`: at 0.49 s none shows; at 0.51 s the first shows and `seal_shown` fired once.
- `test_keying_a_seal_opens_it`: `press_seal()` with the seal's three arrows → true each, the node OPEN.
- `test_an_open_seal_pays_mind_as_the_ball_bursts_through`: Mind XP +5 only once 2.0 s passes, `seal_burst` with (node, 5.0, 5.0).
- `test_a_missed_seal_fizzles_and_pays_nothing`: no keys; at 2.0 s the node is SPENT, `seal_missed` fired, Mind XP unchanged.
- `test_a_capped_mind_opens_seals_for_nothing`: Mind at the cap; an opened seal bursts with taken 0 and the result marks Mind capped.
- `test_a_stop_drops_an_open_seal`: opened at 1.5 s, stopped at 1.8 s: no Mind XP, every node IDLE.
- `test_keys_do_nothing_with_no_seal_showing`: at 0.2 s and between seals `press_seal()` returns false; on Smooth Flow too.
- `test_a_hitch_across_a_seal_s_window`: one `advance(2.2)` from the start shows the first seal and fizzles it in that frame, no pay.
- `test_the_result_keeps_each_seal_and_zone_outcome`: two seals opened and one missed give `seal_states` [OPEN, SPENT, OPEN]; Smooth Flow with one PERFECT and the rest missed gives the zone states in order.

- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement.** The class doc gains a paragraph on seals.
- [ ] **Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(cycling): play Torrential Flow's seals for Mind`

### Task 6: The seal keys

**Files:**
- Modify: `project.godot` (own commit), `scenes/ui/main_view/states/cycling_view_state.gd`, `cycling_view.gd` (`press_seal()`), `cycling_view.tscn` (`focus_mode = 0` on `CloseButton` and `AutoToggle`)
- Test: `tests/unit/test_cycling_mode.gd`, `tests/integration/test_cycling_view.gd`

**Interfaces:**
- Produces: input actions `cycling_seal_up` (W, Up), `cycling_seal_left` (A, Left), `cycling_seal_down` (S, Down), `cycling_seal_right` (D, Right), physical keycodes, written like `open_path`. `CyclingView.press_seal(arrow: int) -> bool` forwards to the technique. `CyclingViewState.handle_input()` turns a fresh press of each action into `scene_root.cycling_view.press_seal(arrow)`, except while the board closes.

- [ ] **Step 1: Add the four actions to `project.godot`; check `git diff project.godot` (only the four actions; `[dialogic]` intact); commit alone** — `chore(input): add the cycling seal keys`
- [ ] **Step 2: Write the failing tests**
- `test_cycling_mode.gd` `test_seal_keys_reach_the_board` (a table of the four actions → arrows, through a stand-in board that records `press_seal()`), `test_a_held_seal_key_presses_once` (an echo event presses nothing), `test_seal_keys_while_closing_are_dropped`.
- `test_cycling_view.gd` `test_press_seal_reaches_the_technique` (Torrential Flow, a seal showing: the view's `press_seal()` keys it) and `test_the_board_s_buttons_take_no_keyboard_focus` (`focus_mode == Control.FOCUS_NONE` on both).
- [ ] **Step 3: Run; they fail. Step 4: Implement. Step 5: Run; they pass.**
- [ ] **Step 6: Commit** — `feat(cycling): route the seal keys to the board`

### Task 7: The board: floaters, pellets and the status line

**Files:**
- Modify: `cycling_view.gd`, `lacquer_floater.gd` (`pop_stat()`), `theme_constants.gd` (`LACQUER_MIND: Color = Color("#A8DE78")`, Mind's pellet green)
- Test: `tests/integration/test_cycling_view.gd`, `tests/unit/test_lacquer_pieces.gd`

**Interfaces:**
- Produces: `LacquerFloater.pop_stat(lead: String, stat: CharacterAttributesData.AttributeType, color: Color) -> void`: the lead, a space, the stat's icon at 16 px, a space and its name; `get_text()` gives "<lead> <name>", `get_icons()` the icon.
- `CyclingView`: `const ZONES_CLAUSE: String = " Click it over a zone for %s XP."`, `const SEALS_CLAUSE: String = " Open each seal with W A S D for %s XP."`; `static func status_line(running: bool, technique: CyclingTechniqueData, other_capped: bool) -> String` (READY while not running; FOLLOW, then the zones clause when the technique has zones and the seals clause when it has seals, each with its other stat's name, neither while `other_capped` or with no other stat). The view reads `other_capped` on `cycling_started`, so a cap reached mid-cycle changes the line at the next cycle. `FOLLOW_ZONES` goes.
- Zone hits: the floater pops `pop_stat("%s +%d" % [tier name, xp], stat, tier colour)`, or `pop("%s · %s capped" % [tier name, stat name], tier colour)` when `taken` is 0; with `taken > 0` the tier's `pellet_count()` pellets burst from the zone in `LacquerPellet.stat_ramp(stat)` to the stat's cell, each holding `taken / count` (`hold_stat_xp()`, released on `delivered`). A hidden board sends none.
- Floaters stay on the board: `_place_floater()` keeps a floater's x within the board's rect, `FLOATER_BOARD_MARGIN` (22 px) in from each side.
- Seals: one floater per seal node, rebuilt with the technique. `seal_burst` with `taken > 0` pops `pop_stat("+%d" % roundi(xp), stat, ThemeConstants.LACQUER_MIND)` over the node and bursts `SEAL_PELLETS` (5) pellets to the stat's cell; with `taken` 0 it pops "OPEN · Mind capped" (the stat's name) in brass and sends none.

- [ ] **Step 1: Rewrite and add the tests**
- `test_status_line_copy`, a table: not running → READY on every technique; running Foundational → "Follow the ball for Madra and Spirit."; Smooth Flow → "Follow the ball for Madra and Spirit. Click it over a zone for Control XP."; Torrential Flow → "Follow the ball for Madra and Spirit. Open each seal with W A S D for Mind XP."; either with `other_capped` → the Foundational's line.
- `test_the_status_line_reads_the_cap_as_a_cycle_starts`: Control reaches the cap mid-cycle; the line keeps its clause until the next cycle starts.
- `test_scoring_pops_the_zone_floater_and_pellets` (rewritten): text "PERFECT +12 Control", the Control icon, `pellet_count(PERFECT)` pellets in `stat_ramp(CONTROL)`; once they land, Control's cell shows the XP.
- `test_a_capped_control_floater_sends_no_pellets` (replaces the full-core one): "PERFECT · Control capped", no pellets.
- `test_a_hit_that_reaches_the_cap_sends_what_control_took`: Control 2 XP short of the cap, a PERFECT on the top zone: the floater says +12, the pellets carry 2 in all.
- `test_a_floater_over_an_edge_zone_stays_on_the_board`: Smooth Flow's left zone (zone 2) scored OK: the floater's rect lies inside the board's, 22 px in.
- `test_an_open_seal_bursts_mind_pellets`: Torrential Flow, a seal opened and burst: floater "+5 Mind", 5 pellets in `stat_ramp(MIND)`.
- `test_a_capped_mind_seal_floater`: "OPEN · Mind capped", no pellets.
- `test_the_core_shows_the_xp_as_its_pellets_land` and `test_a_full_core_floater_sends_no_pellets` go; `test_hiding_the_view_shows_what_its_pellets_carried` and `test_hiding_the_view_frees_the_pellets_in_flight` use Control's pellets.
- `test_lacquer_pieces.gd` `test_pop_stat_shows_the_stat_s_icon_and_name`.

- [ ] **Step 2: Run; they fail. Step 3: Implement. Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(cycling): send stat pellets and name the stat on the board`

### Task 8: Inline icons in the log

**Files:**
- Modify: `scenes/ui/log_window/log_window.gd`, `log_window.tscn` (each `Board/Line<N>` gains `%LineIcons<N>`, a hidden RichTextLabel over its label: `RichTextLacquer`, BBCode off, no wrap, no scroll)
- Test: `tests/integration/test_log_board.gd`

**Interfaces:**
- Produces: `LogWindow.plain_text()` drops `[img…]…[/img]` with what it holds, then strips tags as today. `static func line_parts(bbcode: String) -> Array`: the line in order, a String for each run of text (tags stripped) and a Texture2D for each `[img…]path[/img]` that loads. A board line with an icon shows on `%LineIcons<N>` (text in the line's colour, icons at 16 px, white at ages 0 and 1, in the line's faded colour from age 2), its label hidden; a line without icons is the label, as today. The full log adds the same parts to its line's text cell.

- [ ] **Step 1: Write the failing tests**
- `test_plain_text_drops_images`: `"[color=cyan]Cycle [img=16x16]res://assets/ui/lacquer/lacquer_mini_madra_ai.png[/img] +80[/color]"` → `"Cycle  +80"`.
- `test_line_parts`: that line gives `["Cycle ", <the Madra texture>, " +80"]`; an `[img]` whose path doesn't load is left out.
- `test_a_line_with_icons_shows_them_on_the_board`: the newest line logged with icons: `LineIcons0` visible with the text "Cycle  +80" (`get_parsed_text()`, images aside) and one image; `LineLabel0` hidden; a plain line logged after it moves to age 1 on its twin while age 0 is a label.
- `test_the_full_log_shows_a_line_s_icons`: opened, the full log's text holds the line without its path.

- [ ] **Step 2: Run; they fail. Step 3: Implement. Step 4: Run; they pass (with the file's other tests).**
- [ ] **Step 5: Commit** — `feat(log): draw inline icons in the log`

### Task 9: The cycle's lines

**Files:**
- Modify: `cycle_result.gd`, `cycling_view.gd` (`_on_cycle_completed()` unchanged in shape)
- Test: `tests/unit/test_cycling_rules.gd`, `tests/integration/test_cycling_view.gd`

**Interfaces:**
- Produces: `CycleResult.get_paid_stats() -> Array[CharacterAttributesData.AttributeType]` (the Spiritual stats, in `StatDisplay.SPIRITUAL` order, that took XP rounding to 1 or more or that the cap took XP from). `CycleResult.log_line() -> String`: "Cycle", then three spaces, `[img=16x16]` of `res://assets/ui/lacquer/lacquer_mini_madra_ai.png` and " +80", then for each paid stat three spaces, its icon's `[img=16x16]` and " +30" or " capped". `summary()` and `result_line()` go: the card shows the cycle.

- [ ] **Step 1: Rewrite the tests**: `test_log_line` (a table: Foundational "Cycle   [img…madra] +30   [img…spirit] +12"; Smooth Flow with Control; Torrential Flow with Mind; Spirit and Control capped → " capped" twice; nothing followed → the Madra part alone), `test_paid_stats`, and `test_cycling_view.gd` `test_a_tracked_cycle_reports_the_madra_it_drew` (the last result is the cycle's, and the log's line is `"[color=cyan]%s[/color]" % result.log_line()`). `test_result_lines`, `test_the_lines_show_the_spirit_xp` and `_last_line()` go.
- [ ] **Step 2: Run; they fail. Step 3: Implement. Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(cycling): write the cycle's log line with icons`

### Task 10: The last cycle card

**Files:**
- Create: `scenes/zones/zone_panel/last_cycle_card/last_cycle_card.gd`, `last_cycle_card.tscn`, `reward_chip.tscn`, `last_cycle_stud.tscn`; art `assets/ui/lacquer/cycling/lacquer_cyc_last_studs_ai.png` (24 px frames: PERFECT, GOOD, OK, MISSED zone; OPEN, MISSED seal: the 48 px sockets at half size)
- Modify: `zone_panel.gd`, `zone_panel.tscn` (`%LastCycleLabel` gives way to `%LastCycleCard`); `test_boards_never_trim_text.gd` (`BOARD_SCENES` gains the card)
- Test: `tests/integration/test_last_cycle_card.gd` (new), `tests/integration/test_zone_panel.gd`

**Interfaces:**
- Consumes: Tasks 5 and 9 (`zone_states`, `seal_states`, `get_paid_stats()`).
- Produces: `class_name LastCycleCard extends Control`, 392 wide. `func show_result(result: CycleResult) -> void`. `signal height_changed`. `static func stud_frame(zone_state: int) -> int` and `static func seal_frame(seal_state: int) -> int` (frames of the studs strip: PERFECT 0, GOOD 1, OK 2, a missed zone 3; OPEN 4, a missed seal 5).
- Nodes: `%Tray` (NinePatchRect, `lacquer_now_tray_ai.png`, margins 4, 4, 2, 2), `%Tag` (NinePatchRect over `lacquer_now_plate_ai.png`, margins 8, 4, 8, 4, 98 × 24 at (12, -10)) with `%TagLabel` ("Last cycle", `LabelLacquerLegend`), `%Row` (HBoxContainer at (16, 20), 360 wide): `%Chips` (HFlowContainer, expands, h 18, v 6) holding `%MadraChip`, `%SpiritChip`, `%MindChip`, `%ControlChip` (each a `reward_chip.tscn`: HBoxContainer, separation 6, `%Icon` TextureRect 32 × 32 and `%Amount` Label `LabelLacquerNowName`), and `%Score` (HBoxContainer, separation 2) for the studs (`last_cycle_stud.tscn`: LacquerStripRect, 24 × 24).
- `show_result()`: the Madra chip "+80" (rounded); each Spiritual stat's chip shows while it is paid: "+30", or "capped" in `ThemeConstants.LACQUER_BRASS`; the others hide. The studs: one per `zone_states` entry, else one per `seal_states` entry, else none. The card's height: 64 while its row is one line, and taller by the row's extra height; `height_changed` fires when it changes.
- `ZonePanel`: the card shows while the player cycles and a result exists; its top is 20 px under the Now strip (the tag rises 10 px into that gap); it pushes the lore, the header and the list down by its height plus 20.

- [ ] **Step 1: Write the failing tests** (`test_last_cycle_card.gd`):
- `test_the_chips_show_what_the_cycle_paid`: Smooth Flow's result (80 Madra, 30 Spirit, 21 Control): Madra "+80", Spirit "+30", Control "+21" shown, Mind hidden; the icons are `StatDisplay.icon_of()`'s.
- `test_a_capped_stat_reads_capped_in_brass`.
- `test_the_studs_follow_the_zones`: zone states [PERFECT, GOOD, SPENT, PERFECT] → four studs with frames 0, 1, 3, 0.
- `test_the_seals_show_as_seal_nodes`: seal states [OPEN, SPENT, OPEN] → frames 4, 5, 4.
- `test_the_foundational_card_has_no_score`: no studs.
- `test_a_crowded_card_wraps_and_grows`: chips with five-digit amounts on all four stats wrap to a second line: the card is taller than 64 and `height_changed` fired; every chip shows whole.
- `test_zone_panel.gd`: `test_the_last_cycle_card_shows_the_result`, `test_the_card_pushes_the_rest_down` (header and drawers move down by the card's height plus 20), `test_the_last_cycle_card_shows_only_while_cycling`, `test_clearing_the_last_cycle_hides_the_card` replace the four line tests; `LAST_CYCLE_PUSH` becomes 84.

- [ ] **Step 2: Run; they fail. Step 3: Draw the studs strip, build the scenes and scripts, swap the label in the zone panel. Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(zones): show the last cycle as a card`

### Task 11: The drawers

**Files:**
- Modify: `technique_drawer.gd`, `technique_drawer.tscn`; `scripts/utils/lacquer_text.gd`
- Test: `tests/integration/test_technique_drawer.gd`, `tests/integration/test_zone_panel.gd` (drawer heights), `tests/unit/test_lacquer_pieces.gd` (or the text helper's own file)

**Interfaces:**
- Produces: `LacquerText.list_words(words: PackedStringArray) -> PackedStringArray`: each word but the last two followed by ",", the second to last by " and" (["Spirit"] → ["Spirit"]; ["Spirit", "Control"] → ["Spirit and", "Control"]; ["Madra", "Spirit", "Control"] → ["Madra,", "Spirit and", "Control"]).
- `TechniqueDrawer.detail_text()`: the count part is "N zones", "1 zone", "N seals", "1 seal", or "no zones" with neither. `static func trained_stats(data: CyclingTechniqueData) -> Array[CharacterAttributesData.AttributeType]` (Spirit, then `minor_stat` if any).
- Scene: `%TrainsRow` (HFlowContainer at x 64, 316 wide, h 4) with `%TrainsLabel` ("Trains", `LabelLacquerDetail`) and `%SpiritEntry`, `%MindEntry`, `%ControlEntry` (each an HBoxContainer: a 16 × 16 icon TextureRect and a `LabelLacquerDetail` name). The script shows the trained stats' entries with `list_words()`'s words. `SHORT_HEIGHT` becomes 92: the row stands 2 px under the detail line and the drawer ends 16 px under the row.

- [ ] **Step 1: Rewrite and add the tests**: `test_detail_text` (Torrential Flow's fixture with three seals: "50 Madra · 8 s cycle · 3 seals"; one seal "· 1 seal"), `test_the_trains_row_names_what_a_technique_trains` (Foundational "Trains" + Spirit; Smooth Flow Spirit and Control with the words "Spirit and", "Control"; Torrential Flow Spirit and Mind), `test_list_words`; `DRAWER_SIZE` in `test_technique_drawer.gd` becomes (392, 92) and the zone panel's technique-drawer height 92 (the activity card's 72 stays its own constant).
- [ ] **Step 2: Run; they fail. Step 3: Implement. Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(cycling): show what each technique trains on its drawer`

### Task 12: The Cycling card and Torrential Flow's node

**Files:**
- Modify: `cycling_presenter.gd`, `cycling_presenter.tscn`; `path_details_card.gd`; `cycling_manager.gd` (`get_technique()`); `torrential_flow.tres`; `test_boards_never_trim_text.gd` (the presenter's wrapping entry)
- Test: `tests/integration/test_zone_action_cards.gd`, `tests/unit/test_cycling_manager.gd`, `tests/unit/test_path_details_card.gd` (new)

**Interfaces:**
- Produces: `CyclingManager.get_technique(technique_id: String) -> CyclingTechniqueData` (null for an unknown id). `CyclingPresenter.reward_stats() -> Array[CharacterAttributesData.AttributeType]` (Spirit, then each unlocked technique's other stat, in `StatDisplay.SPIRITUAL` order, each once) and `static func reward_words(stats: Array) -> PackedStringArray` (`list_words()` over "Madra" and the stats' names, " XP" after the last). The scene's `%DetailLabel` gives way to `%RewardRow` (HFlowContainer, h 4) with `%MadraLabel` and `%SpiritEntry`, `%MindEntry`, `%ControlEntry` (16 px icon and `LabelLacquerDetail` name), moved into the card's detail slot. The row refreshes on `CyclingManager.technique_unlocked` (disconnected in `teardown()`), then `button.relayout()`.
- `PathDetailsCard.format_effect()`: an `UNLOCK_CYCLING_TECHNIQUE` effect reads "▲ Unlocks: <technique_name>", falling back to the id for an unknown technique.
- `torrential_flow.tres`: `description = "A faster, more unwieldy cycling technique. It draws Madra quicker than Smooth Flow, and opening its seals trains Mind."`, `benefit_summary = "Torrential Flow unlocked"`.

- [ ] **Step 1: Write the failing tests**: `test_zone_action_cards.gd` `test_the_cycling_card_lists_what_the_known_techniques_train` (a new save: words ["Madra and", "Spirit XP"]; with Smooth Flow: ["Madra,", "Spirit and", "Control XP"]; with all three: ["Madra,", "Spirit,", "Mind and", "Control XP"], Mind's and Control's entries shown accordingly) and `test_the_cycling_card_follows_a_technique_unlock`; `test_cycling_manager.gd` `test_get_technique`; `test_path_details_card.gd` `test_a_technique_unlock_names_the_technique` (torrential_flow → "▲ Unlocks: Torrential Flow"; an unknown id → itself) and `test_torrential_flow_s_node_copy` (no "Core Density", no "minor", the approved description).
- [ ] **Step 2: Run; they fail. Step 3: Implement. Step 4: Run; they pass.**
- [ ] **Step 5: Commit** — `feat(cycling): name what cycling trains on the card and the path node`

### Task 13: Wrap

- [ ] Run the suite in parallel; confirm any failure in one process.
- [ ] Run the issue's Done-when checks on the chunk's own save: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn -- --preset=path_open --save=user://dev/runs/cycling-minor-stats.tres`, as the answers reread them; and load a copy of an old save.
- [ ] Record what was built differently below; open the PR closing #99 with `## Docs to update`.

## Built differently

- **A capped hit is brass whatever its tier.** Answer 6 says both capped floaters are brass; Task 7's brief said the tier's colour.
- **The capped card wraps to a second row.** The canvas drew the capped Smooth Flow and Torrential Flow cards on one row, but its last stud ran past the tray's edge. With 32 px chips, "capped" and four studs there is no room in 360 px, so the card follows answer 8's "grows a row rather than trim". Shrinking the gaps or the icons would keep one row, if Lionel prefers it.
- **The seal plate sits 10 px above its socket**, where the canvas drew it (the plan said 16).
- **SealNode runs on the technique's clock** (`advance(delta)`, no `_process`), so its flash and plate step with the cycle and in tests.
- **`CyclingViewState.arrow_for(event)`** is a static seam the plan did not name; the state reaches the board through `as CyclingView`.
- **`summary()` and `result_line()` lived until Task 10**, since the chest's label read them until the card replaced it.
- **The Madra chip's icon is set by the script**, not overridden inside the instanced chip, which would need editable children. The score hides while it has no studs.
- **The Trains row and the reward row take their icons from `StatDisplay`** at run time, so the stat-to-icon map keeps one home.
- **`project.godot` was committed twice, alone each time**: Task 6's hand-written seal actions, then the editor's own layout of them after an import rewrote it.
- **Tests check rules, not colours or exact copy** where CLAUDE.md says so: the capped chip's "capped" (not its brass), the path node's copy (no Core Density, names Mind, the benefit names the technique).
- **Extra tests**: a right key during the red flash counts; each zone's outcome is kept on the result; the board's buttons take no keyboard focus; a growing card pushes the chest down; `trained_stats()`.
