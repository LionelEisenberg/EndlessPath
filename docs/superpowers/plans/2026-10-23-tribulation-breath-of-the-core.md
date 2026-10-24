# Tribulation: Breath of the Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Each task names the `godot-prompter:*` skills to invoke before writing its code (CLAUDE.md, GodotPrompter).

**Goal:** Give Foundation an ending. Core Density stops at 100. The first time it gets there, "The Tribulation" opens in Spirit Valley and runs the Breath of the Core trial. A pass moves the player to Copper; a failure costs 5 Core Density levels.

**Architecture:**
- **The run:** `TribulationRun`, a pure `RefCounted`, builds the beat schedule from a `TribulationData` and judges presses, releases and the passing of time. Tests drive it with exact times.
- **The board:** `TribulationView` is a lacquer board in the map gap. It reads the run every frame, draws it, and applies the result the moment the run ends, through `CultivationManager.advance_to_next_stage()` or `lose_core_density_levels()`.
- **The plumbing:** `ActionManager` only opens and closes the board, through `start_tribulation` and `stop_tribulation`. `TribulationViewState` turns the zone view over to the board, the way cycling does.
- **Rejected** (spec, Approach): building on `CyclingTechnique`, a `TribulationManager` autoload, and applying the result through the action's effects.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, Python 3 + Pillow (art kit only).

**Spec:** [docs/superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md](../specs/2026-10-23-tribulation-breath-of-the-core-design.md). Read it first: its Decisions, The trial and Design sections are the requirements, and this plan is how to build them. The prototype, [mockups/tribulation-breath-of-the-core-prototype.html](../mockups/tribulation-breath-of-the-core-prototype.html), is the reference for Task 6 (`makeSchedule()`, `onPress()`, `onRelease()`, `step()`).

## Global Constraints

- **Engine:** Godot 4.7.2 and GDScript only. Never modify `addons/`.
- **CLAUDE.md coding standards:**
  - every function has a return type;
  - public functions have no `_` and carry a `##` comment; private ones start with `_`;
  - class variables are typed;
  - node references use `%UniqueName`;
  - code is grouped under `#----` section headers;
  - no `print()`: use `Log` for diagnostics and `LogManager.log_message()` for lines the player reads.
- **UI lives in `.tscn` files.** Scripts set text, textures, frames, visibility and state colours from `ThemeConstants.LACQUER_*`. Instancing a scene from code for a short-lived piece (a `MadraPellet`) is fine; the cycling view does it.
- **Style guide** (docs/STYLE_GUIDE.md §3 and §8):
  - every position and size is even, and art shows at its file size with nearest filtering;
  - no glow, gradient, translucency, opacity fade, eased tween or scale pop;
  - things show and hide outright;
  - shakes step through `MapGlyph.shake_offset_at()`;
  - text never ellipsizes or clips: it wraps, and its board grows (rule 14).
- **Art:** agent-made art ends in `_ai` and is listed in the PR. Never edit a file without `_ai`.
- **Saved enum numbers:** `ZoneActionData.ActionType.TRIBULATION` is appended as 7. `.tres` files store enum numbers, so never insert one.
- **Starting values** (spec, verbatim):
  - **Judging:** perfect ±0.07 s, good ±0.14 s, early reach max(0.30 s, good + 0.10 s), release tolerance 0.05 s. 4 cracks fail; a failure costs 5 levels.
  - **Schedule** (tempo 1.0):
    - lead-in 1.2 s;
    - Steady breath 6 × 1.7 s;
    - Heartbeat 1.45, 0.95, 1.4, 0.9, 1.25, 0.85 s;
    - Echo: sphere A 3 × 1.6 s, sphere B 3 × 1.5 s starting 0.6 s after A;
    - Quickening 0.8 s after Echo: 1.3, 1.15, 1.0, 0.9, 0.8, 0.72 s;
    - the last breath 0.5 s later: in 1.8 s to 2.54 R, out 4.5 s;
    - end pause 1.2 s.
  - **Sphere:** 0.42 R to 1.88 R.
  - **Copper:** 20 × 1.02^(L−1) XP per level, Madra cap 600 + 10 × L, Core Density cap 100.
- **Copy** (spec, verbatim):
  - the HUD tips: "Press as the bright aura crosses the brass ring", "The rhythm breaks. Follow it.", "A second breath answers the first. Catch both.", "The breaths come faster. Keep up.", "Press as it crosses the ring, then hold while it pours into your core";
  - the result panels: "Breakthrough" with "Your core condenses into Copper.", and "Your core cracks" with "Core Density falls from 100 to 95.";
  - the rules line: "4 cracks end the trial and cost 5 levels of Core Density." (this plan adds the full stop);
  - the log lines: "Your core is full. The Tribulation waits in Spirit Valley.", "You break through to Copper." and "Your core must be full to face the Tribulation (95 / 100).";
  - the other UI text: "Face the Tribulation", "Copper reached", "Core full" and "Core 95 / 100";
  - the grades: Flawless, Clean, Scraped through.
- **Tests** (docs/testing/TESTING.md):
  - Call the real autoloads, with their state swapped and restored in `after_each()`. No GUT doubles. Never instance `main_game.tscn`.
  - Set `GODOT="/c/Program Files (x86)/Godot/Godot_v4.7.2-stable_win64_console.exe"`.
  - One file: `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/<dir>/<file>.gd -gexit`.
  - The suite: `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`.
  - A pass is exit code 0 with no failing tests.
- **Import:** after adding a script with a new `class_name`, or new art, run `"$GODOT" --headless --import` before the tests. Then run `git diff project.godot`: it must show only this plan's own edits.
- **Commits:**
  - Use conventional messages (`feat(tribulation): …`), ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Stage files by name, with their generated `.gd.uid` and `.png.import` files. Never stage `.godot/`.
  - Commit at the end of each task, on this feature branch (the user approved per-task commits on 2026-10-23). Never commit to `main`, and never merge.

## Review Focus

1. **A held key repeats.** The Space key's echo events during the hold are not presses: the hold survives and nothing cracks. Task 13, `test_key_repeat_does_not_press_again`.
2. **A long frame.** After a stall, late misses resolve in beat order before a press is judged, so the press lands on the right beat. Task 6, `test_press_after_a_stall_counts_the_missed_beat_first`.
3. **The action stopped from outside mid-trial** (a save reset, the dev panel): the board closes, nothing is applied, and the state removes only itself. Task 14, `test_stop_mid_run_applies_nothing`.
4. **Mashing Space through the end:** the result panel stays up and no new run starts. Only Continue closes it. Task 13, `test_presses_on_the_result_panel_do_nothing`.
5. **A click on the zone chest during the trial** never reaches a card, so no other action can replace the trial. Task 13, `test_the_view_stops_every_click_beneath_it`.

## Calls this plan makes beyond the spec

The user has not seen these; flag them in the PR.

1. **The board's size.** It is 952 px wide at (484, 24), with a 900 × 600 stage; R stays 130 px. The spec's "about 1240 × 800" doesn't fit the 992 px gap between the cabinet (right edge 464) and the chest (left edge 1456).
2. **The board's art.** The board is a `PanelContainer` on a new strapped 9-slice, so it grows with wrapped text. The cycling board's texture can't stretch to a landscape shape.
3. **Art strips and drawn cells.** The ring, the core, the crack pips and the card's rod are texture strips from a kit script. The spheres and the hold arc are drawn per 2 px cell in code, from the same band rule the kit uses.
4. **The passed core.** The brass core is a row of the core strip, not `palette_swap.gdshader` at runtime. It looks the same and is one texture swap.
5. **Click blocking.** The board's root is a full-screen, invisible `Control` that stops every click while the board is open. Mouse presses are judged in its `_gui_input()`, and keys in the state's `handle_input()`. A click anywhere, not only on the board, begins the run from the intro panel.
6. **Copy the spec left open:**
   - the last breath's name and tip become data fields;
   - the rules and fail lines are `{placeholder}` templates;
   - the card's ready line is "About 38 s · a failure costs 5 levels";
   - the floater words;
   - the result's stats line, "24 perfect · 1 good · 0 missed".
7. **The "ember" text colour.** Miss words use `LACQUER_HEALTH` (`#E8737A`), the palette's warning text colour, since vermilion can't be text (STYLE_GUIDE G2).
8. **"Core full" elsewhere.** It also replaces the cabinet's XP figure and the cycle's "+N XP" log and result part. XP pellets don't fly while the core is full.
9. **The card hides at once.** The zone chest also rebuilds on `advancement_stage_changed`, so the card hides when the result shows, not only after Continue.
10. **Smaller calls:**
    - the card's need row has no icon;
    - the action id is `spirit_valley_tribulation`;
    - **Not yet** stops the action as unsuccessful, which counts a completion. That is harmless with `max_completions` 0.

---

### Task 1: Cap Core Density per stage

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Modify: `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd`
- Modify: `singletons/cultivation_manager/cultivation_manager.gd` (signals at 8-10, `add_core_density_xp()` at 71-101)
- Test: `tests/unit/test_cultivation_manager.gd` (extend; keep its fixture and helpers)

**Interfaces:**
- **Produces:**
  - `AdvancementStageResource.max_core_density_level: int = 100`, with the comment `## The highest Core Density level of the stage. XP earned there is lost.`
  - `signal core_filled(stage: AdvancementStage)`: emitted on the level-up that reaches the cap.
  - `func get_core_density_cap() -> int`: the current stage resource's `max_core_density_level`, or 0 with no save or no stage resource.
  - `func is_core_full() -> bool`: `cap > 0 and level >= cap`.
  - `func has_next_stage() -> bool`: true when the current stage resource has a `next_stage`.
  - `func add_core_density_xp(amount: float) -> void`: the same function, now with its missing return type.
  - `func lose_core_density_levels(count: int) -> void`:
    - sets `level = max(0, level - count)` and `xp = 0`;
    - then emits `core_density_level_updated` and `core_density_xp_updated`;
    - leaves the path points.
  - `const CORE_FULL_LOG: String = "Your core is full. The Tribulation waits in Spirit Valley."`

- [ ] **Step 1: Write the failing tests** in a new `# CORE DENSITY CAP` section.
  - `test_levels_stop_at_the_cap`: `_use_flat_curve()` and add 150. The level is 100.0 and the XP 0.0.
  - `test_xp_at_the_cap_is_lost`: set `_save.core_density_level = 100.0`, `watch_signals`, and add 50. The level is 100.0, the XP 0.0, and `core_density_level_updated` is not emitted.
  - `test_cap_comes_from_the_stage`: use a flat stage with `max_core_density_level = 20`. `get_core_density_cap() == 20`, and adding 50 stops at level 20.
  - `test_is_core_full`: false at level 99, true at 100.
  - `test_core_filled_once_at_the_cap`: watch, use the flat curve and add 150. `core_filled` is emitted once, with `[Stage.FOUNDATION]`. After adding 10 more, it still counts 1.
  - `test_full_core_log_line_needs_a_next_stage`: watch `LogManager`.
    - On a flat stage whose `next_stage` is a "Test Copper" stage, filling the core logs a line containing `CultivationManager.CORE_FULL_LOG`.
    - On a flat stage with no next stage, no line contains it.
  - `test_a_free_level_does_not_level`: `_use_stages([_make_stage(Stage.FOUNDATION, "Free", 0.0, 1.0)])`, then add 5. The call returns, and the level is 0.0.
  - `test_no_stage_resource_does_not_level`: use an empty `Array[AdvancementStageResource]` and add 5. The level is 0.0, `get_core_density_cap() == 0`, and `is_core_full()` is false.
  - `test_losing_levels`: at level 100, `lose_core_density_levels(5)` leaves 95.0 and XP 0.0. It emits `core_density_level_updated` `[0.0, 95.0]` and `core_density_xp_updated` `[0.0, 95.0]`.
  - `test_losing_more_levels_than_held_stops_at_zero`: at level 3, losing 5 leaves 0.0.
  - `test_losing_levels_keeps_path_points`: with `_save.path_points = 7`, losing 5 leaves `PathManager.get_point_balance() == 7`.
  - `test_has_next_stage`: false for the fixture stage. True once `_stage_resource.next_stage` is set.
- [ ] **Step 2: Run the file.** Expected: FAIL. The new members don't exist.
- [ ] **Step 3: Implement.** In `add_core_density_xp()`:
  - **Core full on entry:** keep the XP at 0 and emit only `core_density_xp_updated`.
  - **Otherwise:** add the XP, then level up while `level < cap` and `xp >= need`.
  - **The guard:** if `need <= 0.0`, call `Log.error()` with the stage and level, and stop levelling. This covers a missing resource and a free level.
  - **The level-up that reaches the cap,** in order:
    1. Set the XP to 0. The remainder is lost.
    2. Emit `core_density_level_updated`, and pay its milestone as today.
    3. Emit `core_filled`.
    4. When `has_next_stage()`, write `CORE_FULL_LOG` through `LogManager.log_message()`, with no colour tag.
  - **Every call** still ends with `core_density_xp_updated`.
- [ ] **Step 4: Run the file.** Expected: PASS, including the 28 existing tests.
- [ ] **Step 5: Commit.** `feat(cultivation): cap Core Density at the stage's level`

### Task 2: Pay each milestone once per stage, and clamp saves past the cap

**Skills:** `godot-prompter:save-load`, `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/persistence_manager/save_game_data.gd` (CULTIVATION MANAGER section at 25-30, `reset()` at 199-202)
- Modify: `singletons/cultivation_manager/cultivation_manager.gd` (`_update_resources()` at 57-65, the milestone award at 91-95)
- Test: `tests/unit/test_cultivation_manager.gd`

**Interfaces:**
- **Consumes:** Task 1's `get_core_density_cap()` and `lose_core_density_levels()`.
- **Produces:**
  - `SaveGameData.core_density_milestones: Dictionary[int, int] = {}`, with the comment `## Stage (AdvancementStage) to the highest Core Density milestone already paid. Missing on old saves, so it is seeded on load.` `reset()` clears it.
  - A private `_pay_milestone(level: int) -> void`. It pays when all of these hold:
    - `level % PATH_POINT_LEVEL_INTERVAL == 0`;
    - `level > 0`;
    - `level > milestones.get(stage, 0)`.

    It then adds the stage's points and records `level`.
  - `_update_resources()`, before its signals:
    1. **The clamp:** when the cap is above 0, a level above it becomes the cap, with XP 0. `Log.info()` records the change.
    2. **The seed:** a stage with no milestone entry gets `floori(level / 10.0) * 10`.

- [ ] **Step 1: Write the failing tests.** Add a helper, `_load(save: SaveGameData) -> void`. It assigns `PersistenceManager.save_game_data`, emits `save_data_reset` and rebinds `_save`.
  - `test_regaining_a_paid_milestone_pays_nothing`: use the flat curve.
    - Adding 100 makes the balance 10.
    - Then lose 5 levels and add 5. The level is back at 100, and the balance stays 10.
  - `test_new_milestones_still_pay_after_a_loss`: flat curve.
    - Adding 20 makes the balance 2. Losing 5 leaves level 15.
    - Adding 15 reaches level 30, and the balance is 3.
  - `test_an_old_save_is_seeded_from_its_level`: `_load()` a save at level 45 with no milestones. `core_density_milestones[Stage.FOUNDATION] == 40`. With the flat curve, adding 5 adds 1 point (level 50 only).
  - `test_a_save_past_the_cap_loads_at_the_cap`: load a save at level 130 with 12.5 XP and 13 path points.
    - It loads at level 100.0 with XP 0.0.
    - The balance is still 13, and the milestone entry is 100.
  - `test_no_clamp_without_a_stage`: with no stage resources, a level-130 save loads at 130.0.
  - `test_reset_clears_the_milestones`: set an entry and call `reset()`. The dictionary is `{}`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.** `test_milestones_count_absolute_level_not_levels_gained` (lines 173-178) and `test_milestone_points_scale_with_stage` must keep passing: first crossings pay as before.
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `fix(cultivation): pay path-point milestones once per stage`

### Task 3: The Copper stage and the breakthrough

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Create: `resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres`
- Modify:
  - `resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres`: point `next_stage` at Copper.
  - `resources/cycling/advancement_stages/advancement_stage_list.tres`: append Copper.
- Modify: `singletons/cultivation_manager/cultivation_manager.gd`
  - add Copper's `preload` to the exported array at 23-25;
  - delete `attempt_breakthrough()` at 103-104.
- Test: `tests/unit/test_cultivation_manager.gd`
- Create: `tests/unit/test_foundation_tribulation_data.gd`. Open it with `##` lines saying it pins the Tribulation's real data wiring.

**Interfaces:**
- **Produces:** `func advance_to_next_stage() -> bool`.
  - It returns false when the current stage has no `next_stage`.
  - Otherwise it sets the stage to `next_stage.stage_id`, the level to 0 and the XP to 0.
  - It emits `core_density_level_updated`, `core_density_xp_updated` and `advancement_stage_changed`.
  - It logs `"You break through to %s." % next_stage.stage_name`.
- **The Copper `.tres`:**
  - `stage_name = "Copper"`, `stage_id = 1`;
  - `core_density_base_xp_cost = 20.0`, `core_xp_scaling_factor = 1.02`;
  - `max_madra_base = 600.0`, `max_madra_per_core_density_level = 10.0`;
  - `max_core_density_level = 100`, and no next stage.

- [ ] **Step 1: Write the failing tests.**
  - **In `test_cultivation_manager.gd`.** Add a helper, `_with_copper() -> AdvancementStageResource`.
    - It builds a flat "Test Copper" stage (madra base 600, +10 per level).
    - It sets it as `_stage_resource.next_stage`, and puts both stages in `_use_stages`.
    - The tests below start at level 100:
      - `test_breakthrough_moves_to_the_next_stage`: returns true. The stage is COPPER, the level 0.0 and the XP 0.0.
      - `test_breakthrough_signals`: `advancement_stage_changed` `[Stage.COPPER]` and `core_density_level_updated` `[0.0, 0.0]`.
      - `test_breakthrough_logs`: a logged line contains "You break through to Test Copper.".
      - `test_no_breakthrough_without_a_next_stage`: returns false. The stage and level are unchanged.
      - `test_madra_cap_follows_the_new_stage`: afterwards, `get_max_madra() == 600.0`.
      - `test_the_new_stage_pays_its_own_milestones`: afterwards, adding 10 adds 2 points.
  - **In `test_foundation_tribulation_data.gd`** (real resources):
    - `test_foundation_leads_to_copper`: the Foundation `.tres`'s `next_stage` has `stage_id == COPPER` and `stage_name == "Copper"`. Foundation's `max_core_density_level == 100`.
    - `test_copper_values`:
      - base 20.0, factor 1.02, and `get_xp_for_level(1) == 20.0`;
      - Madra 600.0 and 10.0;
      - cap 100, and `next_stage == null`.
    - `test_the_madra_cap_does_not_drop_at_the_breakthrough`: `foundation.get_max_madra(100) == copper.get_max_madra(0) == 600.0`.
    - `test_copper_is_registered`: a COPPER resource is in `CultivationManager.advancement_stage_resources` and in `advancement_stage_list.tres`'s `advancement_stages`.
- [ ] **Step 2: Run both files.** Expected: FAIL.
- [ ] **Step 3: Implement.** Write the `.tres` by hand: an `ext_resource` to `advancement_stage.gd` (uid `uid://civ7jgpmmaoro`). A header uid is optional. Then run the import.
- [ ] **Step 4: Run both files.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(cultivation): add the Copper stage and the breakthrough`

### Task 4: Adding Madra never lowers it

**Skills:** `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/resource_manager/resource_manager.gd:70-82`
- Test: `tests/unit/test_resource_manager.gd`

**Interfaces:**
- **Produces:** `add_madra()` sets `madra = clampf(before + amount, 0.0, maxf(CultivationManager.get_max_madra(), before))`.
  - When the pool is above the cap, a gain is lost and the pool is kept. This happens after a failure lowers the cap, or after the load clamp.
  - Update its `##` comment to say so.

- [ ] **Step 1: Write the failing tests.**
  - `test_add_madra_above_a_lowered_cap_keeps_the_pool`: `_save.madra = 150.0`, with a cap of 100 at level 0. Adding 20 leaves 150.0, returns 0.0, and logs nothing.
  - `test_spending_above_the_cap_still_spends`: at 150, adding -30 leaves 120.0.
- [ ] **Step 2: Run the file.** Expected: FAIL. Today the first test trims the pool to 100.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file**, then `tests/unit/test_cultivation_getters.gd`. Expected: PASS, including the existing cap tests.
- [ ] **Step 5: Commit.** `fix(resources): keep Madra above a lowered cap`

### Task 5: The Tribulation's data

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Create: `scripts/resource_definitions/tribulation/tribulation_phase_data.gd`, `scripts/resource_definitions/tribulation/tribulation_data.gd`
- Create: `resources/tribulation/foundation_tribulation.tres`
- Test: `tests/unit/test_foundation_tribulation_data.gd` (extend)

**Interfaces:**
- **Produces:** two resource classes, each field with a `##` comment.

  `class_name TribulationPhaseData extends Resource`:

  | Field | Type and default |
  |---|---|
  | `phase_name`, `tip` | `String` |
  | `gap_before` | `float = 0.0` |
  | `breath_periods`, `echo_periods` | `PackedFloat32Array` |
  | `echo_offset` | `float = 0.0` |
  | `aura_rush` | `bool = false` |

  `class_name TribulationData extends Resource`:

  | Group | Fields and defaults |
  |---|---|
  | Target | `target_stage: CultivationManager.AdvancementStage = COPPER` |
  | Copy | `title` "The Tribulation"; `intro_text` "Your core is full. Breathe with the aura as it gathers, and let it pour into you."; `rules_text` "{cracks} cracks end the trial and cost {levels} levels of Core Density."; `last_breath_name` "The last breath"; `last_breath_tip` (the spec's fifth tip); `pass_title` "Breakthrough"; `pass_text` "Your core condenses into Copper."; `fail_title` "Your core cracks"; `fail_text` "Core Density falls from {before} to {after}." |
  | Timing | `tempo` 1.0, `lead_in` 1.2, `phases: Array[TribulationPhaseData]`, `last_breath_gap` 0.5, `last_breath_in` 1.8, `last_breath_out` 4.5, `last_breath_max_ratio` 2.54, `end_pause` 1.2 |
  | Geometry | `sphere_min_ratio` 0.42, `sphere_max_ratio` 1.88 |
  | Judging | `perfect_window` 0.07, `good_window` 0.14, `early_reach_min` 0.30, `release_tolerance` 0.05, `cracks_to_fail: int` 4 |
  | Penalty | `failure_level_loss: int` 5 |

  `TribulationData` also has:
  - `const EARLY_REACH_PAST_GOOD: float = 0.10`;
  - `func get_early_reach() -> float`: `maxf(early_reach_min, good_window + EARLY_REACH_PAST_GOOD)`;
  - `func get_rules_line() -> String`: fills `{cracks}` and `{levels}` with `String.format()`;
  - `func get_fail_line(before: int, after: int) -> String`.
- **Content:** `foundation_tribulation.tres` holds the defaults above, with `target_stage = 1`, plus four phase sub-resources in order:

  | Phase | Tip | Values |
  |---|---|---|
  | "Steady breath" | the spec's first tip | `breath_periods` 1.7 × 6 |
  | "Heartbeat" | the second | `breath_periods` 1.45, 0.95, 1.4, 0.9, 1.25, 0.85 |
  | "Echo" | the third | `breath_periods` 1.6 × 3; `echo_periods` 1.5 × 3; `echo_offset` 0.6 |
  | "Quickening" | the fourth | `gap_before` 0.8; `breath_periods` 1.3, 1.15, 1.0, 0.9, 0.8, 0.72; `aura_rush` true |

  The `.tres` format:
  - one `[sub_resource type="Resource" id="Phase_steady"]` per phase, with `script = ExtResource("<phase script id>")`;
  - `phases = Array[ExtResource("<phase script id>")]([SubResource("Phase_steady"), …])`;
  - arrays written as `PackedFloat32Array(1.7, 1.7, …)`.

- [ ] **Step 1: Write the failing tests.** They load the real `.tres`.
  - `test_targets_copper`.
  - `test_phases_in_order`: the four names, and the four tips verbatim.
  - `test_breaths`: compare each array with a `PackedFloat32Array([...])` literal. Also check the Echo offset, the Quickening gap, and `aura_rush` (true only on Quickening).
  - `test_timing_and_geometry`: every value in the Timing and Geometry rows.
  - `test_judging_and_penalty`: every value in those rows, and `get_early_reach()` ≈ 0.30.
  - `test_copy`:
    - `get_rules_line()` is "4 cracks end the trial and cost 5 levels of Core Density.";
    - `get_fail_line(100, 95)` is "Core Density falls from 100 to 95.";
    - the titles, the pass text, and the last breath's name and tip.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.** Write the scripts and the `.tres`, then run the import.
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(tribulation): add the Tribulation data`

### Task 6: `TribulationRun`, the judge

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Create: `scripts/tribulation/tribulation_run.gd` (`class_name TribulationRun extends RefCounted`)
- Test: `tests/unit/test_tribulation_run.gd`

**Interfaces:**
- **Consumes:** Task 5's `TribulationData` and `TribulationPhaseData`.
- **Produces:**
  - `enum Result { PERFECT, GOOD, EARLY_MISS, LATE_MISS, HELD, RELEASED_EARLY, IGNORED }`
  - `var cracks: int`, `var perfect_count: int`, `var good_count: int`: public, read by the view.
  - `func _init(data: TribulationData) -> void`
  - `func press(t: float) -> Dictionary`: `{result, offset: float, last: bool}`. The offset is `t - beat time`, negative when early.
  - `func release(t: float) -> Dictionary`: `{result, last: true}`.
  - `func advance(t: float) -> Array[Dictionary]`: `{result: LATE_MISS, last}` and `{result: HELD, last: true}`.
  - `func is_failed() -> bool`, `func is_holding() -> bool`
  - `func is_finished(t: float) -> bool`: not failed, not holding, and `t >= get_duration()`.
  - `func grade() -> String`: "Failed" when failed; otherwise "Flawless" for 0 cracks, "Clean" for 1, "Scraped through" for 2–3.
  - Schedule getters:
    - `func get_beat_times() -> PackedFloat64Array`
    - `func get_hold_seconds() -> float`
    - `func get_duration() -> float`
    - `func get_phase_start(index: int) -> float`
    - `func get_last_breath_start() -> float`
  - Drawing queries:
    - `func phase_at(t: float) -> TribulationPhaseData`: the last phase whose start is at or before `t`. `phases[0]` before the first start (the lead-in). `null` from the last breath's start.
    - `func aura_rush_at(t: float) -> bool`: the phase's `aura_rush`. Always true during the last breath.
    - `func spheres_at(t: float) -> Array[Dictionary]`: `{ratio: float, bright: bool, echo: bool}` for each breath in progress.
    - `func hold_progress(t: float) -> float`: 0 to 1 while holding, else 0.
    - `func progress(t: float) -> float`: `t / duration`, clamped to 0–1.

The schedule (the prototype's `makeSchedule()`):

```
k = 1.0 / tempo
t = lead_in * k
for each phase:
    t += gap_before * k; phase_start = t
    a = t;  for p in breath_periods: add_breath(a, p * k, echo = false); a += p * k
    b = t + echo_offset * k;  for p in echo_periods: add_breath(b, p * k, echo = true); b += p * k
    t = max(a, b) if echo_periods else a
last_start = t + last_breath_gap * k
the last breath: in = last_breath_in * k, out = last_breath_out * k, max = last_breath_max_ratio
duration = last_start + (last_breath_in + last_breath_out + end_pause) * k

add_breath(start, period, echo): in = out = period / 2, max = sphere_max_ratio
cross(max) = (max - 1) / (max - sphere_min_ratio)
beat = start + in + out * cross(max); the last breath's beat also has hold = out * (1 - cross(max))
the sphere: min → max over `in` (faint), then max → min over `out` (bright)
beats are sorted by time, so Echo's two spheres interleave; the judging windows don't scale with tempo
```

Judging (the prototype's `onPress()`, `onRelease()` and `step()`):

```
press(t):   failed, or no unjudged beat left → IGNORED
            first resolve late beats up to t, as advance() does, and keep their LATE_MISS events
              for the next advance(): results don't depend on when frames fall
            candidates: unjudged beats with  t - time <= good  and  time - t <= early_reach
            take the nearest by |t - time| (the earlier one on a tie); d = t - time
            |d| <= perfect → PERFECT;  |d| <= good → GOOD;  otherwise EARLY_MISS (a crack)
            any candidate is judged; a hit on the last beat starts the hold;  no candidate → IGNORED
release(t): not holding → IGNORED; the hold ends;
            t < beat + hold - release_tolerance → RELEASED_EARLY (a crack), else HELD
advance(t): the queued events, then each unjudged beat with t > time + good, in order,
            → LATE_MISS (a crack); then, holding and t >= beat + hold → HELD
the crack that brings `cracks` to cracks_to_fail fails the run at once:
            after it, nothing more is judged, press() and release() return IGNORED, and advance() returns []
```

- [ ] **Step 1: Write the failing tests.**
  - **Setup:**
    - Constants: `CROSS := 0.88 / 1.46`, `LAST_CROSS := 1.54 / 2.12`, `EPS := 0.001`.
    - `_run(tempo := 1.0) -> TribulationRun`: copies the real `.tres` with `duplicate(true)` and sets its `tempo`.
    - `_hit_through(run, index)`: at each beat time from 0 to `index`, calls `advance(t)` then `press(t)`.
  - **Schedule:**
    - `test_foundation_has_25_beats`.
    - `test_run_lasts_about_38_seconds`: `get_duration()` ≈ 37.97.
    - `test_first_beat_crosses_the_ring`: beat 0 ≈ `1.2 + 0.85 + 0.85 * CROSS` (2.5623).
    - `test_phase_starts`: 1.2, 11.4, 18.2, 24.1. The last breath starts at 30.47.
    - `test_echo_beats_interleave`: beats 12–17 ≈ 19.4822, 20.0021, 21.0822, 21.5021, 22.6822, 23.0021. These are A at `18.2 + 1.6 i + 0.8 * (1 + CROSS)` and B at `18.8 + 1.5 i + 0.75 * (1 + CROSS)`.
    - `test_last_beat_and_hold`: beat 24 ≈ `30.47 + 1.8 + 4.5 * LAST_CROSS` (35.5389). `get_hold_seconds()` ≈ `4.5 * (1 - LAST_CROSS)` (1.2311).
    - `test_tempo_divides_every_duration`: at tempo 2.0 the duration is ≈ 18.985, and every beat is ≈ half of tempo 1.0's.
  - **Phases and spheres:**
    - `test_phase_at`:
      - 0.0 and 11.39 are "Steady breath"; 11.41 is "Heartbeat";
      - 23.9 is "Echo": Quickening's gap belongs to Echo;
      - 24.2 and 30.3 are "Quickening";
      - 30.5 is `null`.
    - `test_aura_rush_at`: false at 5.0, true at 25.0 and at 33.0.
    - `test_spheres_breathe`:
      - none at 0.5;
      - one at 1.2, ratio 0.42, faint;
      - at 2.06, just after the out-breath starts: bright, ratio ≈ 1.86 (at exactly 2.05, float rounding can leave it breathing in);
      - at beat 0, ratio ≈ 1.0, bright;
      - two at 18.9, one of them `echo`.
    - `test_last_breath_grows_past_the_ring`: ratio ≈ 2.54 at `30.47 + 1.8`.
  - **Judging** (b0 is beat 0):
    - `test_press_on_the_beat_is_perfect`: PERFECT, offset ≈ 0, and `perfect_count == 1`.
    - `test_press_inside_the_good_window_is_good`: b0 + 0.10 is GOOD. So is b0 - 0.10 on a new run.
    - `test_early_press_is_a_miss`: b0 - 0.20 is EARLY_MISS and `cracks == 1`. Then `advance(b0 + 0.5)` has no LATE_MISS.
    - `test_press_far_from_any_beat_is_ignored`: b0 - 0.40 is IGNORED, and `cracks == 0`.
    - `test_unpressed_beat_is_a_late_miss`: `advance(b0 + 0.13)` returns `[]`. `advance(b0 + 0.15)` returns one LATE_MISS with `last` false, and `cracks == 1`.
    - `test_press_after_a_stall_counts_the_missed_beat_first` (Review Focus 2):
      - `_hit_through(run, 15)`, then `press(22.90)`. It is GOOD on beat 17, with offset ≈ -0.102.
      - `advance(22.90)` returns one LATE_MISS, for beat 16, and `cracks == 1`.
    - `test_nearest_beat_in_echos_close_pair`: `_hit_through(run, 15)`.
      - Pressing at beat 16 + 0.06 is PERFECT, with offset ≈ 0.06.
      - Pressing at beat 17 - 0.01 is PERFECT.
      - `cracks == 0`, and `perfect_count == 18`.
    - `test_mashing_fails` (the spec's early-reach test): press every 0.05 s from 0.05, with an `advance()` before each, while not failed.
      - The run fails with `cracks == 4`.
      - It fails before beat 3's time: each beat's first press falls about 0.26 s early.
  - **The hold:**
    - `test_hitting_the_last_beat_starts_the_hold`: `_hit_through(run, 23)`, then press at beat 24. It is PERFECT with `last` true, and `is_holding()`.
    - `test_early_release_cracks`: then release at beat 24 + hold - 0.10. RELEASED_EARLY, `cracks == 1`, and not holding.
    - `test_release_within_tolerance_is_held`: releasing at beat 24 + hold - 0.04 is HELD.
    - `test_holding_to_the_end_is_held`: `advance(beat 24 + hold + 0.01)` returns `[HELD]`. A later release is IGNORED.
    - `test_hold_progress`: ≈ 0.5 halfway through the hold, and 0 when not holding.
    - `test_missing_the_last_beat_starts_no_hold`: `_hit_through(run, 23)`, then `advance(beat 24 + 0.2)` returns one LATE_MISS with `last` true. No hold.
  - **The end:**
    - `test_fourth_crack_fails_at_once`: `advance(beat 3 + 0.15)` returns 4 events and `is_failed()`. A press then is IGNORED, and `advance()` returns `[]`.
    - `test_three_cracks_do_not_fail`: `advance(beat 2 + 0.15)` returns 3 events, and the run isn't failed.
    - `test_clean_run_passes_at_the_end`: hit every beat and hold to the end. `is_finished(duration - 0.01)` is false, `is_finished(duration)` true, and the grade "Flawless".
    - `test_grades`: let `n` beats pass unpressed, then hit the rest and hold.
      - n = 1 is "Clean"; n = 2 and n = 3 are "Scraped through".
      - A failed run is "Failed".
    - `test_progress`: 0 at 0, 0.5 at half the duration, 1 at the duration + 5.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.** Keep the breaths and beats in small inner classes (`Breath`, `Beat`).
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(tribulation): judge the breathing trial`

### Task 7: The Tribulation action in Spirit Valley

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:godot-testing`

**Files:**
- Modify: `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd:4-12` (append `TRIBULATION`)
- Create: `scripts/resource_definitions/zones/zone_action_data/tribulation_action_data/tribulation_action_data.gd`
- Modify: `singletons/action_manager/action_manager.gd`
  - signals after 33-34;
  - the gate after 121-124;
  - match arms at 203-209 and 232-235;
  - handlers beside 330-334 and 375-379.
- Modify: `scripts/utils/zone_action_groups.gd` (`group_of()` and `mode_tag()`, and their comments)
- Modify: `singletons/zone_manager/zone_manager.gd:220-232` (`get_available_actions()`)
- Modify: `scenes/zones/zone_panel/zone_panel.gd` (`_ready()` at 128-145; a handler beside 389)
- Create: `resources/unlocks/core_density_full.tres`. Modify: `resources/unlocks/unlock_condition_list.tres`.
- Create: `resources/zones/spirit_valley_zone/zone_actions/tribulation_action.tres`. Modify: `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`: an `ext_resource`, and the action appended to `all_actions`.
- Test:
  - `tests/unit/test_zone_action_groups.gd`, `tests/unit/test_foundation_tribulation_data.gd`, `tests/integration/test_zone_panel.gd`;
  - create `tests/integration/test_tribulation_flow.gd`.

**Interfaces:**
- **Consumes:** Tasks 1–3 (`is_core_full()`, `advance_to_next_stage()`, `lose_core_density_levels()`) and Task 5 (`TribulationData`).
- **Produces:**
  - `ZoneActionData.ActionType.TRIBULATION`, which is 7.
  - `class_name TribulationActionData extends ZoneActionData`:
    - `@export var tribulation: TribulationData`, and `_init()` sets the type;
    - `func is_passed() -> bool`: the current stage is at or past `tribulation.target_stage`;
    - `func can_attempt() -> bool`: the current stage is `target_stage - 1`, and `is_core_full()`.
  - In `ActionManager`:
    - `signal start_tribulation(action_data: TribulationActionData)` and `signal stop_tribulation()`;
    - private `_execute_tribulation_action()` emits the start;
    - private `_stop_tribulation_action(successful: bool)` emits the stop, then `_process_completion_effects(successful)`;
    - `select_action()` refuses a `TribulationActionData` that can't be attempted, with a `Log.info()` naming the level and cap. The refusal comes before anything stops, as the adventure gate's does;
    - TRIBULATION is not an idle action, so stopping it resumes the zone's idle action.
  - `ZoneActionGroups.group_of(TRIBULATION)` is `CULTIVATE`, and `mode_tag()` is "TRIAL".
  - `get_available_actions()` skips a `TribulationActionData` that `is_passed()`.
  - `ZonePanel` queues a rebuild on `CultivationManager.advancement_stage_changed`.
- **Content:**
  - **The condition:** `core_density_full.tres` has `condition_id` "core_density_full", `condition_type = 1` (CULTIVATION_LEVEL), `target_value = 100` and `comparison_op` ">=". Add it to the list: conditions missing from it are never evaluated.
  - **The action** `tribulation_action.tres`:
    - `action_id` "spirit_valley_tribulation", `action_name` "The Tribulation", `action_type = 7`;
    - `description` "Your core is full. Face the Tribulation and break through to Copper.";
    - `icon` `res://assets/ui/lacquer/lacquer_ic_core_ai.png`;
    - `unlock_conditions` `[core_density_full]`, `max_completions = 0`;
    - `tribulation` points at `foundation_tribulation.tres`.

- [ ] **Step 1: Write the failing tests.**
  - **`test_zone_action_groups.gd`:**
    - add `TRIBULATION` to `test_group_of_each_type` (CULTIVATE) and to `test_mode_tags` ("TRIAL");
    - in `test_sort_puts_talk_first_and_keeps_order`, put "spirit_valley_tribulation" after "aura_well_training".
  - **`test_foundation_tribulation_data.gd`:**
    - `test_tribulation_type_is_seven`.
    - `test_tribulation_action_is_wired`:
      - the `.tres` is a `TribulationActionData`, with type TRIBULATION and name "The Tribulation";
      - its `tribulation.resource_path` is the Foundation one;
      - its one condition id is "core_density_full".
    - `test_core_density_full_condition`: CULTIVATION_LEVEL, 100 and ">=".
    - `test_the_condition_is_registered`.
    - `test_spirit_valley_lists_the_tribulation`.
  - **`test_zone_panel.gd`:**
    - `_unlock_everything()` now lists ten actions: fix its comment;
    - `test_count_label` expects "10 here";
    - rename `test_chest_fills_for_nine_cards` to `test_chest_fills_for_ten_cards`;
    - add `test_rebuilds_on_stage_change`: force-unlock "core_density_full" and set level 100. The panel has a "spirit_valley_tribulation" card. After `advance_to_next_stage()` and two frames, it has none.
  - **`test_tribulation_flow.gd`:**
    - **Setup:** a fresh save each test; restore the original in `after_each()`, after stopping any action.
    - **Helpers:**
      - `_tribulation()`: `ZoneManager.get_action_by_id("spirit_valley_tribulation")`;
      - `_fill_core()`: set level 99, then add `get_xp_for_next_level()` XP;
      - `_run_foraging()`: `EventManager.trigger_event("q_fill_core_completed")`, which unlocks foraging and starts it.
    - **Tests:**
      - `test_reaching_one_hundred_reveals_the_card`: the action isn't in `get_available_actions("SpiritValley")` before `_fill_core()`, and is after. "core_density_full" is unlocked.
      - `test_select_refuses_below_one_hundred`: force-unlock the condition and set level 95, then `watch_signals(ActionManager)`. `select_action()` leaves the current action, and `start_tribulation` isn't emitted.
      - `test_select_at_one_hundred_starts_the_trial`: after `_fill_core()`, `start_tribulation` is emitted with the action, which is now the current one.
      - `test_stopping_resumes_the_idle_action`: `_run_foraging()`, `_fill_core()`, select the Tribulation, then `stop_action(false)`. Foraging is current again, and `stop_tribulation` was emitted.
      - `test_a_pass_moves_to_copper_and_hides_the_card`: select, `advance_to_next_stage()`, then `stop_action(true)`. The stage is COPPER at level 0, and the card is gone from the available actions.
      - `test_a_failure_costs_five_levels_and_keeps_the_card`: select, `lose_core_density_levels(5)`, then `stop_action(false)`. The level is 95, the card is still available, and a second select is refused.
- [ ] **Step 2: Run the four files.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run the import.
- [ ] **Step 4: Run the four files.** Expected: PASS. If another `test_zone_panel.gd` test now fails only because the list grew by one 80 px drawer, fix its expectation and name it in the commit body. Production layout doesn't change.
- [ ] **Step 5: Commit.** `feat(tribulation): add the Spirit Valley action`

### Task 8: The Goals board and the cabinet at the cap

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:godot-testing`

**Files:**
- Modify: `scenes/ui/goals_panel/goals_panel.gd` (`_ready()` at 69-77, `_update_milestone()` at 131-140)
- Modify: `scenes/zones/cultivator_plate/cultivator_plate.gd:102-118`
- Modify: `singletons/cultivation_manager/cultivation_manager.gd`: delete `BREAKTHROUGH_LEVEL` (35-36).
- Test:
  - `tests/integration/test_goals_panel.gd`: replace `test_milestone_figure_caps_at_breakthrough` at 272-278;
  - `tests/integration/test_cultivator_plate.gd`: replace `test_core_fill_stops_at_breakthrough_level` at 212-214;
  - `tests/unit/test_cultivation_getters.gd`: replace its BREAKTHROUGH section and the header line.

**Interfaces:**
- **Consumes:** `get_core_density_cap()`, `is_core_full()` and `has_next_stage()` (Task 1), and the Copper stage (Task 3).
- **Produces:** the Goals board's milestone row has three states:

  | When | Text | Rod | Figure |
  |---|---|---|---|
  | No next stage | `"%s reached" % get_current_advancement_stage_name()` | full | hidden |
  | Core full | "Face the Tribulation" | full | "100 / 100" |
  | Otherwise | `"Raise Core Density to %d" % cap` | level / cap | "level / cap" |

  - The board also refreshes on `advancement_stage_changed`.
  - **The cabinet:** its core fill is `clampi(level, 0, cap) / cap`, or 0 with no cap. At the cap, its XP label reads "Core full" and its beads show the full row, `XP_BEADS_LAST_ROW`.

- [ ] **Step 1: Write the failing tests.**
  - **The Goals board:**
    - `test_milestone_at_the_cap_asks_for_the_tribulation`: a save at level 120 loads at 100. The text is "Face the Tribulation", the figure "100 / 100", and the rod is at `MILESTONE_ROD_STEPS`.
    - `test_milestone_after_the_breakthrough`: a save on stage COPPER at level 0. "Copper reached", the rod full, and the figure not visible.
    - `test_milestone_follows_the_stage_change`: with the board up, set the save's stage to COPPER and emit only `advancement_stage_changed`. The board reads "Copper reached".
  - **The cabinet:**
    - `test_a_save_past_the_cap_loads_full`: `_load_core_density(140.0, 0.0)` gives a fill of 1.0 and "Level 100".
    - `test_a_full_core_reads_core_full`: at level 100, `XpLabel` is "Core full" and the `XpBeads` frame is `(0, 18)`.
  - **The getters:** `test_foundation_core_density_cap_is_one_hundred`: `get_core_density_cap() == 100`.
- [ ] **Step 2: Run the three files.** Expected: FAIL.
- [ ] **Step 3: Implement.** Confirm nothing else reads `BREAKTHROUGH_LEVEL`: `grep -rn BREAKTHROUGH_LEVEL --include=*.gd .` should match only `addons/`, or nothing.
- [ ] **Step 4: Run the three files.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(ui): show the full core on the Goals board and cabinet`

### Task 9: Cycling says the core is full

**Skills:** `godot-prompter:godot-testing`

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycle_result.gd` (a field; `summary()` at 46-60)
- Modify: `scenes/cycling/cycling_technique/cycling_technique.gd:270-277` (the scoring step)
- Modify: `scenes/cycling/cycling_view/cycling_view.gd:382-400` (`_on_zone_scored()`)
- Test: `tests/unit/test_cycling_rules.gd`, `tests/integration/test_cycling_technique.gd`, `tests/integration/test_cycling_view.gd`

**Interfaces:**
- **Produces:**
  - `CycleResult.core_full: bool = false`, with the comment `## True when the core was full by the cycle's end. The line then says Core full where it would give the XP.`
  - `summary()` appends "Core full" instead of "+N XP" when `core_full` is true.
  - The technique sets `_result.core_full = CultivationManager.is_core_full()` after each scored zone.
  - The view's zone floater reads `"%s · Core full" % CyclingRules.tier_name(tier)` while the core is full, and no XP pellets fly. Madra still flows.

- [ ] **Step 1: Write the failing tests.**
  - `test_cycling_rules.gd`: `test_a_full_core_line_says_so`. `_result(186.4, 3, 4, 1, 75)` with `core_full` gives the log line "Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · Core full".
  - `test_cycling_technique.gd`: `test_a_zone_scored_at_the_cap_marks_the_result`. Set level 100 and score zone 0. `_technique.get_current_result().core_full` is true.
  - `test_cycling_view.gd`: `test_a_full_core_floater_sends_no_pellets`. Set level 100 and score zone 0 (`_approach_zone_0(0.0)`). The floater reads "OK · Core full", and `_pellets().size() == 0`.
- [ ] **Step 2: Run the three files.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the three files.** Expected: PASS. The existing "+25 XP" tests run below the cap.
- [ ] **Step 5: Commit.** `feat(cycling): say the core is full instead of paying XP`

### Task 10: The Tribulation's lacquer art

**Skills:** `godot-prompter:assets-pipeline`, `godot-prompter:godot-testing`

**Files:**
- Create: `docs/superpowers/mockups/tribulation-lacquer/gen/kit_tribulation.py`
- Create: an empty `docs/superpowers/mockups/tribulation-lacquer/.gdignore`. Each mockup folder has one, so Godot never imports the review copies.
- Create (by the script): the PNGs below and, after the import, their `.import` files
- Create: `assets/styleboxes/lacquer/trib_board9.tres`, `assets/styleboxes/lacquer/drawer9.tres`
- Test: `tests/unit/test_tribulation_art.gd`

**Interfaces:**
- **Produces** these `res://` paths, used by Tasks 11 and 13:

  | Path | Size | What |
  |---|---|---|
  | `assets/ui/lacquer/tribulation/lacquer_trib_board9_ai.png` | 164×164 | An 80×80 art-px strapped board: `lq_base.cabinet(80, 80)` and four `strap()` corners, as in `kit_cycling.board()`. A 4 px `#050707` shadow is baked right and bottom. Grain streaks and the gloss dash stay inside the 28 art-px corner squares; the middle rows and columns are uniform, so the 9-slice stretches on the grid |
  | `assets/ui/lacquer/tribulation/lacquer_trib_ring_strip_ai.png` | 544×272 | Two 136×136 art-px frames. Centre at the frame's middle corner (art 68, 68). Ink band at [63, 64), brass at [64, 66), ink at [66, 67) art px (the band rule below), so its middle is 130 screen px. Brass `#D4A84A`, with the lower-right half (`(x + 0.5) + (y + 0.5) > 0`) in `#A66834`. Frame 1, the lit frame, puts cream `#F0E8D8` where brass was and brass where the shade was |
  | `assets/ui/lacquer/tribulation/lacquer_trib_core_strip_ai.png` | 512×768 | 4 columns × 6 rows of 64×64 art-px frames, centred on art (32, 32). Columns are the core radius: 17, 21, 25, 29 art px (34, 42, 50, 58 screen px), with a 1 art px ink outline at [r, r + 1). Rows: 0 whole; 1, 2 and 3 with that many cracks; 4 spent; 5 passed. The whole core is a Madra-ramp disc lit from the top-left, in `lq_base.core_orb()`'s swirl colours. Cracks are jagged 1 art px ink lines with a 1 art px `#A83C30` edge, from the rim to 60% of the radius, at fixed angles (−60°, 160°, 70°). Spent: all three cracks plus one at 250°, the disc in the carved palette (`#230F0F`, `#462020`, the tan `#A89070` rim). Passed: the whole core in the brass ramp (`#F0E8D8`, `#D4A84A`, `#A66834`, `#341E0E`) |
  | `assets/ui/lacquer/tribulation/lacquer_trib_pip_strip_ai.png` | 40×20 | Two 10×10 art-px crack pips. 0: an empty carved socket (ink rim, `#110707` inside, `#612B2B` lit lower lip). 1: the same with a `#A83C30` crack chip |
  | `assets/ui/lacquer/lacquer_rod_core_empty_ai.png`, `assets/ui/lacquer/lacquer_rod_core_full_ai.png` | 152×10 | The goal rod's `_empty` and `_full` (280×10) with the flat middle columns 76–203 cut out: columns 0–75 and 204–279 joined. The script asserts the cut columns are identical before joining. The end cap is `lacquer_rod_goal_end_ai.png` as it is |

- **The band rule.** The kit and Task 12 share it. A cell at offset `(x, y)` from the centre corner lies in the band [inner, outer) when `inner <= hypot(x + 0.5, y + 0.5) < outer`.
- **Styleboxes:**
  - `trib_board9.tres`: a StyleBoxTexture over the board. Texture margins 56, 56, 60, 60; content margins 24, 20, 28, 24 (left, top, right, bottom).
  - `drawer9.tres`: a StyleBoxTexture over `lacquer_drawer9_ai.png`. Texture margins 4, 4, 6, 6; content margins 20, 16, 22, 18.
- **The script** (`kit_tribulation.py`):
  - It imports `lq_base` the way `kit_cycling.py` does, sets `B.OUT` to `docs/superpowers/mockups/tribulation-lacquer/`, draws at 1 art px and saves at 2x with `lq_base.save()`.
  - It then copies the files into `assets/ui/lacquer/` (and its `tribulation/`), baking the board's shadow with a `bake_shadow()` written out as in `import_cycling.py`.
  - Usage: `python docs/superpowers/mockups/tribulation-lacquer/gen/kit_tribulation.py`.

- [ ] **Step 1: Write the failing test.** Copy `test_cycling_art.gd`'s helpers: `_load_texture`, `_assert_size`, `_assert_opaque_or_clear(path, palette)` and `_opaque_width`.
  - `test_sizes`: the table's sizes.
  - `test_opaque_or_clear`, every file. Palettes:
    - ring `["150909","d4a84a","a66834","f0e8d8"]`;
    - pip `["150909","110707","612b2b","692f2f","a83c30","7e2a22","d4a84a"]`;
    - core `["150909","110707","e8f6fd","bbd5e7","849be4","1c2f60","16283e","a83c30","7e2a22","230f0f","462020","612b2b","a89070","7a654c","f0e8d8","d4a84a","a66834","341e0e"]`.
  - `test_ring_band`: every opaque pixel of frame 0 lies 125.9–134.1 px from (136, 136), measured from the pixel centre.
  - `test_core_sizes`: the row-0 frames' opaque widths are 72, 88, 104 and 120.
  - `test_board_middle_is_uniform`:
    - for 56 ≤ x < 104, each pixel equals the pixel at x = 56 on its row;
    - for 56 ≤ y < 104, each pixel equals the pixel at y = 56 in its column.
  - `test_core_rod_is_the_goal_rod_less_its_middle`: each core rod's columns 0–75 and 76–151 equal the goal rod's 0–75 and 204–279.
  - `test_styleboxes`: the two `.tres` files' textures and margins.
- [ ] **Step 2: Run the file.** Expected: FAIL. The files don't exist.
- [ ] **Step 3: Write and run `kit_tribulation.py`**, then run the import.
- [ ] **Step 4: Run the file.** Expected: PASS. Look at each PNG at 2x, against `docs/STYLE_GUIDE.md` §3 and §9. Fix the drawing, not the test, if one reads wrong.
- [ ] **Step 5: Commit.** `feat(tribulation): add the lacquer Tribulation art`. List every new `_ai` file in the body.

### Task 11: The Tribulation card

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/zones/zone_action_button/presenters/tribulation_presenter.gd` and `.tscn`
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd:61-70` (`PRESENTER_SCENES` and its comment)
- Test: `tests/integration/test_tribulation_card.gd`

**Interfaces:**
- **Consumes:** Task 7's `TribulationActionData.can_attempt()`, Task 6's `TribulationRun.get_duration()`, and Task 10's core rod.
- **Produces:** `class_name TribulationPresenter extends ZoneActionPresenter`, modelled on `AdventurePresenter`.
  - **The scene:**
    - `NeedGroup`: a 392×72 Control that ignores the mouse. It holds:
      - `CoreRod` (`%`): a `LacquerRod` at x 64–216, y 40–50, with the core rod's textures, the goal rod's end, and 74 steps;
      - `FigureRow`: an HBox at x 226–380, y 38–56, holding `CoreFigure` (`%`, `LabelLacquerDetail`).
    - `ReadyLabel` (`%`): a `LabelLacquerDetail` with a brass `font_color` override, as the adventure's ready text has.
  - **`setup()`:** reparents `NeedGroup` into the footer slot and `ReadyLabel` into the detail slot. It connects `core_density_level_updated` and `advancement_stage_changed`, and `teardown()` disconnects them.
  - **Below the cap:** the need row shows `"Core %d / %d"`, with the rod at level / cap. The tag is `ZoneActionGroups.mode_tag()` ("TRIAL", CARVED). There is no ready frame.
  - **When `can_attempt()`:**
    - the need row hides;
    - `ReadyLabel` reads `"About %d s · a failure costs %d levels" % [roundi(duration), failure_level_loss]` through `button.fit_detail_label()`;
    - the card gets `set_ready_frame(true)` and `set_mode_tag("ENTER", TagStyle.ENTER)`.
  - **`can_activate()`** returns `can_attempt()`.
  - **`on_activation_rejected()`** shakes the need row with `AdventurePresenter`'s soft shake (copy its three shake functions). It logs `"[color=red]Your core must be full to face the Tribulation (%d / %d).[/color]"`.

- [ ] **Step 1: Write the failing tests.**
  - **Setup:** each test uses a fresh save with "core_density_full" force-unlocked. Build the card as `test_zone_action_cards.gd` does, and copy its `_texts` and `_click` helpers.
  - **Tests:**
    - `test_presenter_is_registered`: `ZoneActionButton.PRESENTER_SCENES` has TRIBULATION.
    - `test_below_the_cap_shows_the_core_figure`: at level 95, the texts include "Core 95 / 100". The tag is "TRIAL", the rod step is `roundi(0.95 * 74)`, and the ready frame is hidden.
    - `test_at_the_cap_the_card_is_ready`: at level 100, the texts include "About 38 s · a failure costs 5 levels". The tag is "ENTER", the ready frame is visible, and the need row is hidden.
    - `test_rejected_click_below_the_cap_logs_why`: at level 95, a click leaves the current action, and the log contains "Your core must be full to face the Tribulation (95 / 100).".
    - `test_click_at_the_cap_starts_the_trial`: the current action becomes the Tribulation.
    - `test_card_follows_a_lost_level`: at level 100, `lose_core_density_levels(5)` makes the card show "Core 95 / 100".
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file**, then `tests/integration/test_zone_action_cards.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(zones): add the Tribulation card`

### Task 12: The stage's spheres and hold arc

**Skills:** `godot-prompter:2d-essentials`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/tribulation/tribulation_stage.gd` (`class_name TribulationStage extends Control`; its node is built in Task 13's scene)
- Test: `tests/unit/test_tribulation_stage.gd`

**Interfaces:**
- **Consumes:** Task 6's `spheres_at()` and `hold_progress()`.
- **Produces:**
  - **Constants:** `CELL := 2`, `RING_RADIUS_PX := 130`, `CENTRE := Vector2(450, 300)` (a grid corner of the 900 × 600 stage), `HOLD_ARC_INNER := 75`, `HOLD_ARC_OUTER := 79`, `HOLD_ARC_STEPS := 24`, `DASH_CELLS := 4`.
  - `static func radius_cells(ratio: float) -> int`: `roundi(ratio * RING_RADIUS_PX / CELL)`.
  - `static func band_runs(inner: int, outer: int) -> Array[Rect2i]`: the band rule's cells as horizontal runs of height 1, in cell offsets from the centre.
  - `static func band_cells_clockwise(inner: int, outer: int) -> Array[Vector2i]`: the band's cells, sorted by `fposmod(atan2(x + 0.5, -(y + 0.5)), TAU)`, which starts at 12 o'clock and runs clockwise.
  - `func show_frame(run: TribulationRun, t: float) -> void`: keeps this frame's spheres and hold progress, and redraws `%SphereLayer` and `%ArcLayer`.
  - `func clear() -> void`
  - `func centre_global() -> Vector2`
- **Drawing:** in the layers' `draw` signal handlers, with `draw_rect()` per run or cell at `CENTRE + offset * CELL`. Cache the runs and cells per (inner, outer).
  - **A bright sphere** of radius r cells:
    - a 2-cell band [r − 2, r) in `LACQUER_MADRA`, with a 1-cell crest [r − 3, r − 2) in `LACQUER_MADRA_HI`;
    - an Echo sphere swaps the two colours.
  - **A faint sphere:** the 1-cell band [r − 1, r) in `LACQUER_TAN`, keeping cells whose index `/ DASH_CELLS` is even.
  - **The hold arc:** the first `cells.size() * steps / 24` cells of [75, 79) in `LACQUER_BRASS`, where `steps = floori(hold_progress * 24)`.

- [ ] **Step 1: Write the failing tests.**
  - `test_radius_cells`: 1.0 is 65, 0.42 is 27, 1.88 is 122, 2.54 is 165.
  - `test_band_cells_lie_in_the_band`: for [10, 12), every cell's `hypot(x + 0.5, y + 0.5)` is in [10, 12), with no duplicates. The count is within 3% of `PI * (144 - 100)`.
  - `test_band_is_symmetric`: for every cell `(x, y)`, the cells `(-1 - x, y)` and `(x, -1 - y)` are in it too.
  - `test_band_runs_cover_the_same_cells`: expanding the runs gives exactly `band_cells_clockwise()`'s set. Every run is 1 tall, and no two overlap.
  - `test_clockwise_starts_at_twelve`: the first cell has `x == 0` and `y < 0`, and the angles never decrease.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(tribulation): draw the spheres and the hold arc`

### Task 13: The Tribulation board

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:hud-system`, `godot-prompter:input-handling`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/tribulation/tribulation_view.tscn`, `scenes/tribulation/tribulation_view.gd`
- Modify: `project.godot`. Add `[input] tribulation_press`, beside `close_cycling_view`:
  ```
  tribulation_press={
  "deadzone": 0.2,
  "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
  , Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":true,"double_click":false,"script":null)
  ]
  }
  ```
- Test: `tests/integration/test_tribulation_view.gd`

**Interfaces:**
- **Consumes:** Task 6's `TribulationRun`, Task 10's art and styleboxes, Task 12's `TribulationStage`, and Tasks 1 and 3's `lose_core_density_levels()` and `advance_to_next_stage()`.
- **Produces:**
  - **The scene tree.** The theme is `lacquer_theme.tres`, and every node not named here ignores the mouse.
    ```
    TribulationView (Control, full rect, mouse_filter STOP, script)
    └── Board (%, PanelContainer, trib_board9.tres, at (484, 24), min width 952, mouse_filter PASS)
        └── BoardVBox (separation 8)
            ├── HeaderVBox: ActionLabel (%, LabelLacquerDetail) · TitleLabel (%, LabelLacquerPanelTitle, wraps)
            ├── StageFrame (Control, 900 × 600)
            │   ├── Stage (%, TribulationStage, 900 × 600, clip_contents)
            │   │   ├── Ring (%, LacquerStripRect, ring strip, frame 272 × 272, at (314, 164))
            │   │   ├── SphereLayer (%, Control, full stage)
            │   │   ├── Core (%, LacquerStripRect, core strip, frame 128 × 128, at (386, 236))
            │   │   ├── ArcLayer (%, Control, full stage)
            │   │   ├── Pellets (%, Node2D)
            │   │   └── Floaters (%, Control) with four LacquerFloater instances
            │   ├── IntroPanel (%, PanelContainer, drawer9.tres, min width 560,
            │   │   bottom-centre 24 px above the frame's bottom, grows upward):
            │   │   IntroTitle (%, LabelLacquerPanelTitle) · IntroText (%, LabelLacquerLore, wraps)
            │   │   · RulesLabel (%, LabelLacquerDetail, wraps, wrap_pad.tres) · HBox: BeginButton (%) · NotYetButton (%)
            │   └── ResultPanel (%, the same, hidden): ResultTitle (%) · ResultText (%)
            │       · GradeLabel (%, LabelLacquerName) · StatsLabel (%, LabelLacquerDetail) · ContinueButton (%)
            ├── HudHBox (separation 16): PhaseVBox (expands): PhaseNameLabel (%, LabelLacquerName)
            │   · PhaseTipLabel (%, LabelLacquerDetail, wraps, wrap_pad.tres) · CrackPips (%, 6 LacquerStripRect pips, 20 × 20)
            └── ProgressRod (%, LacquerRod, the goal rod's textures, 138 steps, centred)
    ```
    - **Buttons:** each is a `TextureButton` built like the chest's About button: `lacquer_about_ai.png` with `lacquer_about_open_ai.png` pressed, a centred `LabelLacquerDetail` ("Begin", "Not yet", "Continue"), a `frame_hover.tres` overlay, and `focus_mode = FOCUS_NONE`.
    - The panels sit low so the core shows above them.
  - **The script,** `class_name TribulationView extends Control`:
    - `signal finished(passed: bool)`
    - `enum Mode { CLOSED, INTRO, RUNNING, RESULT }`
    - `var clock_usec: Callable = Time.get_ticks_usec`. Tests replace it.
    - `func setup(data: TribulationData, zone_name: String) -> void`: shows the intro, with the rules from `get_rules_line()`, `cracks_to_fail` pips shown and unlit, the rod at 0, and core frame (0, 0).
    - `func begin() -> void`: starts a run when on the intro. Its t0 is `clock_usec.call()`.
    - `func cancel() -> void`: on the intro only, emits `finished(false)`.
    - `func close() -> void`: hides the board. A run in progress is dropped, and nothing is applied.
    - `func handle_press_event(event: InputEvent) -> bool`:
      - it consumes every `tribulation_press` event;
      - ignores echoes (the default of `is_action_pressed()`);
      - on the intro, a press begins;
      - while running, a press calls `run.press()` and a release calls `run.release()`, each at `clock_usec.call()`;
      - on the result panel, it does nothing.
    - `_gui_input()` calls it, then `accept_event()`, so every mouse press on the screen lands here.
    - `func get_mode() -> Mode`, `func get_run() -> TribulationRun`
  - **Timing:** every timed effect (the ring flash, the shake, the rush interval) reads `clock_usec`, never `delta`. Tests drive them with `_at()`.
  - **Every frame:**
    - while running: `run.advance()` gives its feedback; a failed run ends with `_end(false)` and a finished one with `_end(true)`;
    - the stage is redrawn, and the HUD (the phase name and tip, from `phase_at()` or the last breath's fields), the rod, the pips and the core frame are updated;
    - while not closed: floaters stand at stage (604, 286) for a word, or (604, 318) for its reason line, raised by `get_rise()`. The board shake keeps stepping.
  - **`_end(passed)`:** applies the result at once, through `advance_to_next_stage()`, or `lose_core_density_levels(failure_level_loss)` with the before and after levels kept for `get_fail_line()`. It then fills and shows the result panel:
    - the title and text;
    - `run.grade()`;
    - `"%d perfect · %d good · %d missed" % [perfect_count, good_count, cracks]`.
  - **Continue** emits `finished(passed)`. **Not yet** calls `cancel()`.
  - **`_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)`:** while running and holding, it calls `run.release(now)` and gives its feedback.
  - **Feedback:**

    | Result | Floater, colour | Also |
    |---|---|---|
    | PERFECT / GOOD | "Perfect" or "Good" ("Perfect · hold" or "Good · hold" on the last beat), in `LACQUER_BRASS` or `LACQUER_MADRA` | The ring shows frame 1 for 0.15 s. 8 or 5 `MadraPellet`s fly from the ring (130 px) to 178 px, at angles `i / n * TAU + 0.3`, over 0.4 s with a 12 px bow |
    | EARLY_MISS / LATE_MISS | "Miss" ("The breath escapes you" on the last beat) and, under it, "Too early" or "Too late", in `LACQUER_HEALTH` | A pip lights. The board steps through `MapGlyph.SOFT_SHAKE_KEYFRAMES`, or `SHAKE_KEYFRAMES` for the crack that fails the run |
    | RELEASED_EARLY | "Released too early", in `LACQUER_HEALTH` | As a miss |
    | HELD | "Held", in `LACQUER_BRASS` | 12 pellets with `lacquer_cyc_pellet_brass_ai.png` |
    | While `aura_rush_at(t)` | none | A Madra pellet every 0.1 s, from 460 px out at angle `index * 2.39996` to the centre, over 0.8 s with a 40 px bow |

  - **The core frame:**
    - column `mini(hits / 7, 3)`, where hits are perfect plus good, plus one once held;
    - row: the cracks (0–3) while running, then 4 on a fail or 5 on a pass.

- [ ] **Step 1: Write the failing tests.**
  - **Setup:**
    - Keep the original save, and put it back in `after_each()`.
    - Load a fresh save at level 100 on the real stages. Instance the scene with `add_child_autofree`.
    - Set `view.clock_usec` to a lambda returning `_now_usec`, which starts at 1,000,000. Then call `setup(data, "Spirit Valley")`.
  - **Helpers:**
    - `_at(seconds)`: sets `_now_usec` to `1_000_000 + roundi(seconds * 1e6)`, then calls `view._process(0.0)`;
    - `_press(down := true)`: an `InputEventAction` for "tribulation_press";
    - `_hit_beats(from, to)`: for each beat, `_at()` it and press;
    - `_play_clean_run()`.
  - **Tests:**
    - `test_setup_shows_the_intro_with_the_rules`: the intro is visible and the result hidden. The rules read "4 cracks end the trial and cost 5 levels of Core Density.". Four pips of six are visible. `ActionLabel` reads "Spirit Valley".
    - `test_the_view_stops_every_click_beneath_it` (Review Focus 5):
      - the root is `MOUSE_FILTER_STOP`, with anchors 0, 0, 1, 1, and the board is `MOUSE_FILTER_PASS`;
      - `view._gui_input()` with a left press, on the intro, begins the run.
    - `test_buttons_take_no_focus`: all three are `FOCUS_NONE`.
    - `test_a_press_on_the_intro_begins`: the mode is RUNNING, and the intro hides.
    - `test_not_yet_finishes_without_a_run`: `NotYetButton.pressed.emit()` emits `finished` `[false]`, and the level is still 100.
    - `test_press_is_judged_at_its_arrival_time`: begin, set `_now_usec` to beat 0 without `_process`, and press. `perfect_count == 1`.
    - `test_hit_pops_a_floater_and_flashes_the_ring`: a visible floater reads "Perfect" in `LACQUER_BRASS`. The ring frame is (1, 0), and is (0, 0) again by `_at(beat0 + 0.2)`.
    - `test_late_miss_lights_a_pip`: `_at(beat0 + 0.2)` lights pip 1 (frame (1, 0)), and floaters read "Miss" and "Too late".
    - `test_fail_applies_the_penalty_at_once`: `_at(beat 3 + 0.15)`.
      - The mode is RESULT and the level 95.
      - The panel reads "Your core cracks", "Core Density falls from 100 to 95.", "Failed" and "0 perfect · 0 good · 4 missed".
      - The core row is 4, and `finished` isn't emitted.
    - `test_pass_breaks_through`: `_play_clean_run()`.
      - The stage is COPPER at level 0.
      - The panel reads "Breakthrough", "Your core condenses into Copper.", "Flawless" and "25 perfect · 0 good · 0 missed".
      - The core row is 5.
    - `test_continue_finishes_with_the_result`: `finished` is `[false]` after the fail and `[true]` after the pass.
    - `test_presses_on_the_result_panel_do_nothing` (Review Focus 4): after the fail, a press keeps RESULT, and `finished` isn't emitted.
    - `test_key_repeat_does_not_press_again` (Review Focus 1):
      - hit up to and including the last beat, so the hold is on;
      - an `InputEventKey` with `physical_keycode = KEY_SPACE`, `pressed` and `echo` true leaves the hold on and `cracks == 0`.
    - `test_focus_loss_during_the_hold_releases_it`: during the hold, set `_now_usec` to beat 24 + 0.3 and call `view.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)`.
      - The hold is off, and `cracks == 1`.
      - `_at(duration)` then passes, graded "Clean": the clock kept going.
    - `test_focus_loss_outside_the_hold_changes_nothing`.
    - `test_close_mid_run_applies_nothing`: begin, `_at(3.0)`, then `close()`. The board is hidden, the mode CLOSED, the level 100, and the stage FOUNDATION.
    - `test_core_grows_with_hits`: after seven hits, the core frame's column is 1.
    - `test_phase_labels_follow_the_run`:
      - at 1.0: "Steady breath";
      - after `_hit_beats(0, 5)` and `_at(11.5)`: "Heartbeat" and "The rhythm breaks. Follow it.".
    - `test_board_shakes_in_whole_steps`: after a late miss, sampled at 0.1 s steps, the board's x minus 484 is each time one of `SOFT_SHAKE_KEYFRAMES`. By `SHAKE_SECONDS` it is back at 484.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement**, then run the import.
- [ ] **Step 4: Run the file.** Expected: PASS. Then run `tests/integration/test_boards_never_trim_text.gd`.
- [ ] **Step 5: Commit.** `feat(tribulation): build the Tribulation board`

### Task 14: Opening the board from the zone view

**Skills:** `godot-prompter:state-machine`, `godot-prompter:input-handling`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/tribulation/tribulation_view_state.gd`
- Modify: `scenes/ui/main_view/main_view.gd`
  - view refs at 11-19 and state refs at 37-45;
  - `_ready()` at 57-65;
  - `set_cycling_mode()` at 129-141.
- Modify: `scenes/main/main_game/main_game.tscn`
  - add `ext_resource` ids `34_tvs` (the state script) and `35_tv` (the view scene);
  - add a `TribulationViewState` node (unique name) under `MainViewStateMachine`;
  - add a hidden `TribulationView` instance at `z_index = 3`, with its unique name, after `CyclingView` and before `DevPanel`. The dev panel must stay above it for input.
- Test:
  - create `tests/unit/test_tribulation_view_state.gd`;
  - extend `tests/unit/test_cycling_mode.gd` and `tests/integration/test_tribulation_flow.gd`.

**Interfaces:**
- **Consumes:** Task 7's signals and Task 13's `TribulationView`.
- **Produces:**
  - **`MainView`:**
    - `@onready var tribulation_view: TribulationView = %TribulationView`, and `tribulation_view_state`, whose `scene_root` is set in `_ready()`;
    - `func set_board_mode(on: bool) -> void`: hides the dock and turns the map's SubViewport input off. Each piece is skipped when it's missing;
    - `set_cycling_mode()` now calls it, after the chest's techniques mode.
  - **`class_name TribulationViewState extends MainViewState`:**
    - **Connections:** `_ready()` connects `start_tribulation` and `stop_tribulation`.
    - **`enter()`:** `hide_hud_boards(self)`, `set_board_mode(true)`, `_block_full_log(true)`, and shows the view.
    - **`exit()`:** `tribulation_view.close()`, `release_hud_boards(self)`, `set_board_mode(false)` and `_block_full_log(false)`.
    - **`handle_input()`:**
      - `ui_cancel` calls `view.cancel()` only on the intro, and is otherwise ignored;
      - everything else goes to `view.handle_press_event()`.
    - **`_on_start_tribulation(action)`:** `view.setup(action.tribulation, <current zone name>)`. It connects `finished` once, and pushes the state only if it isn't already on the stack.
    - **`_on_view_finished(passed)`:** calls `ActionManager.stop_action(passed)` when the current action is a `TribulationActionData`.
    - **`_on_stop_tribulation()`:** `scene_root.remove_state(self)`.

- [ ] **Step 1: Write the failing tests.**
  - **`test_tribulation_view_state.gd`:**
    - **Setup:**
      - A `MainView.new()` that never enters the tree (as in `test_merchant_view_state.gd`), with a real `TribulationView` (`add_child_autofree`, a test clock) and plain Controls for the log, Goals and dock.
      - A bare `SubViewport` for the map, and `state_stack = []`.
      - A fresh save at level 100, with the original restored after.
    - **Tests:**
      - `test_start_pushes_once`: two starts leave a stack of 1. The view shows, the log and Goals hide, the dock hides, and `gui_disable_input` is true.
      - `test_escape_on_the_intro_cancels`: `handle_input()` with a pressed `ui_cancel` `InputEventAction` makes the view emit `finished` `[false]`.
      - `test_escape_during_the_run_does_nothing`: begin, then `ui_cancel`. The mode stays RUNNING, and `finished` isn't emitted.
      - `test_space_reaches_the_view`: a "tribulation_press" on the intro begins.
      - `test_stop_restores_and_removes_only_itself`: with a stack of `[other, state]`, `_on_stop_tribulation()` leaves `[other]`. The view is hidden, the boards and dock visible, and the map input on.
      - `test_stop_mid_run_applies_nothing` (Review Focus 3): begin, step 3 s, then stop. The level is 100, the stage FOUNDATION, and the mode CLOSED.
      - `test_main_game_holds_the_board_and_its_state`: `load()` `main_game.tscn` as a `PackedScene` and read `get_state()` without instancing it. It has a `TribulationView` under `MainView` and a `TribulationViewState` under `MainView/MainViewStateMachine`.
  - **`test_cycling_mode.gd`:** `test_board_mode_leaves_the_chest`. `set_board_mode(true)` hides the dock and turns the map input off. The chest is not in techniques mode.
  - **`test_tribulation_flow.gd`:** set the state's `scene_root` to such a `MainView`, then `add_child_autofree()` the state so its `_ready()` connects.
    - `test_a_failed_trial_end_to_end`:
      1. `_run_foraging()`, then `_fill_core()`.
      2. Select the Tribulation: the state is pushed.
      3. Begin, step past beat 3 + 0.15, then press Continue.
      4. The level is 95, foraging is current again, the state is off the stack, the view hidden, and the card still available.
    - `test_a_passed_trial_end_to_end`: the same with a clean run. The stage is COPPER, the card gone, and foraging resumed.
- [ ] **Step 2: Run the three files.** Expected: FAIL.
- [ ] **Step 3: Implement.** Edit `main_game.tscn` by hand, then run the import, which reports a scene that doesn't parse. Don't run the scene to check it: its `SaveTimer` and `PersistenceManager` would write the developer's real `save.tres`.
- [ ] **Step 4: Run the three files**, then `tests/unit/test_merchant_view_state.gd` and `tests/unit/test_view_state_hud_positions.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(tribulation): open the board from the zone view`

### Task 15: Living docs, the full suite, and the playtest

**Skills:** `godot-prompter:godot-testing`

**Files:**
- Modify:
  - `CLAUDE.md`: the CultivationManager and ActionManager rows; View Architecture (10 states, adding `TribulationViewState`); Key Input Bindings (`tribulation_press`: Space or left click); Progression.
  - `docs/cultivation/CULTIVATION.md`
  - `docs/cultivation/breakthrough-tribulation.md`: the status, now built, and where the code lives.
  - `docs/zones/ZONES.md`
  - `docs/progression/FOUNDATION_PLAYTHROUGH.md` (Beat 9) and `docs/progression/QUESTS.md` (the milestone row)
  - `docs/infrastructure/UNLOCKS.md` and `docs/infrastructure/MAIN_VIEW.md`
  - `docs/cycling/CYCLING.md` ("Core full")
  - `docs/STATE_OF_THE_GAME.md`
  - `docs/testing/TESTING.md`: the suite status and the coverage map.
  - `docs/README.md` and `docs/superpowers/README.md`: the row's status.

- [ ] **Step 1: Run the full suite.** Expected: exit code 0, and the test count up by this plan's tests. If an unrelated test fails, check whether it fails on the base commit before touching it.
- [ ] **Step 2: Update the docs.**
  - Replace every `BREAKTHROUGH_LEVEL`, `attempt_breakthrough()` and "no cap" statement.
  - Follow each doc's own structure, and give `file:line` pointers.
  - Check every relative link resolves.
- [ ] **Step 3: Write the playtest checklist** into the PR description, for the user:
  1. Cycle to 100, and see the log line, the card with NEW, and "Face the Tribulation".
  2. Fail on purpose: the core falls to 95 and the card shows "Core 95 / 100".
  3. Cycle back and pass: you reach Copper, the card is gone, and the board reads "Copper reached".
  4. Alt-tab during the hold.
  5. Mash Space through the end.
- [ ] **Step 4: Commit.** `docs: describe the Tribulation as built`
