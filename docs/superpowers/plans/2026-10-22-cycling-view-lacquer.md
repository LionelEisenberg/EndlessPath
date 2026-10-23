# Cycling View in Lacquer and Brass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Each task names the `godot-prompter:*` skills to invoke before writing its code (CLAUDE.md, GodotPrompter).

**Goal:** Rebuild the cycling view as a lacquer board in the zone view's map gap, with the cabinet as its readout, the chest listing techniques, a carved figure, a groove that lights in Madra blue, a stepped and snapped ball, zone sockets with tier studs, and the cycling bugs the new look would show fixed.

**Architecture:** `CyclingView` stays a `MainView` child, redrawn as a 560x1032 board at (680, 24). A cycling-mode switch on `MainView` turns the zone chest's list into technique drawers, hides the dock and stops the map's input. `CyclingManager` becomes the single source of truth for equipping and holds a read-only snapshot of the running cycle that the Now tray and the cabinet read. The ball's motion moves from a tween to an `advance(delta, cursor)` step the tests drive directly. The groove is drawn per art pixel from the technique's curve.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, Python 3 + Pillow (art import only).

**Spec:** [docs/superpowers/specs/2026-10-22-cycling-view-lacquer-design.md](../specs/2026-10-22-cycling-view-lacquer-design.md). Read it first: its Decisions, Layout, Behaviour and Copy sections are the requirements; this plan is how. Mock: [docs/superpowers/mockups/cycling-view-lacquer-mockup.html](../mockups/cycling-view-lacquer-mockup.html).

## Global Constraints

- Godot 4.7.2 and GDScript only. Never modify `addons/`.
- CLAUDE.md coding standards. Every function has a return type. Public functions have no leading `_` and carry a `##` doc comment; private ones start with `_`. Class variables are typed. Node references use `%UniqueName`. Use `#----` section headers. No `print()`: use `Log` for diagnostics and `LogManager.log_message()` for player lines.
- UI lives in `.tscn` files. Scripts set text, textures, frames, visibility and state colours from `ThemeConstants.LACQUER_*`. No `Node.new()`, `StyleBoxFlat.new()`, `ShaderMaterial.new()` or `add_theme_*_override()` for styling; the one exception is a state colour on a label, as `ZoneActionButton._apply_tag()` does. Instancing a scene per item from code is fine (cards, drawers, pellets, floaters).
- Every lacquer root sets `res://assets/themes/lacquer/lacquer_theme.tres`. Labels use `LabelLacquer*` variants. Numbers with a decimal point go in a `RichTextLacquer` through `LacquerText.decimal_bbcode()`. No new theme variants are needed.
- Style guide §3 and §12: every position and size is even; textures show at file size; nearest filtering; no glow, gradient, translucency, opacity fade, eased UI tween or scale pop; things show and hide outright.
- Agent-made art ends in `_ai`. Never edit `assets/sprites/cycling/cycling_technique_outline.png` or `Madra-Ball.png`.
- The copy is exactly the spec's Copy table: "Click the Madra ball to begin a cycle.", "Click the ball for another cycle.", "Cycling · 9 / 15 s", " · follow the ball", "Madra full · zones still pay XP", "Madra full", "Last cycle · …", "Cycle · …", "PERFECT +25 XP", "Techniques", "N learned", "IN USE", "Auto · off", "Auto · on", "Esc".
- The cycle rules don't change: a 0.08 s Madra step, a 29.5 px ball radius, a 20 px zone radius, PERFECT under 6 px (ratio 0.3), GOOD under 14 px (ratio 0.7), zone XP from `CyclingZoneData`, one score per zone per cycle.
- Commits use conventional messages (`feat(cycling): …`) and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Stage files by name.
- Tests: `GODOT="/c/Program Files (x86)/Godot/Godot_v4.7.2-stable_win64_console.exe"`. Run one file with `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<dir>/<file>.gd -gexit`, and the suite with `-gdir=res://tests/unit/,res://tests/integration/`. A pass ends with GUT's summary showing no failing tests.

## Review Focus

1. **A frame hitch mid-cycle** (one long `delta`): Madra steps catch up but stop at the cap, and zones the ball jumped past end the cycle SPENT, never stuck IDLE or ACTIVE. Task 14, `test_a_frame_hitch_spends_skipped_zones`.
2. **Madra reaching the cap mid-cycle:** pellets stop on that step, the result counts only the Madra added, and the status reads "Madra full · zones still pay XP". Task 14, `test_cap_reached_mid_cycle`; Task 15, `test_status_line_copy`.
3. **Clicking the drawer already in use:** nothing happens (no flash, no equip, no cycle end). Task 11, `test_click_on_the_drawer_in_use_does_nothing`.
4. **A technique unlocking while the chest shows techniques** (the dev panel can do it mid-cycle): a drawer appears with NEW and the chest grows, and a mid-cycle rebuild keeps the "Techniques" header. Task 12, `test_unlock_in_techniques_mode_adds_a_drawer` and `test_a_rebuild_in_techniques_mode_keeps_the_header`.
5. **Reopening after closing mid-cycle:** zones idle, groove dark, ball at the start, no floater showing, no stale result line. Task 14, `test_stop_resets_zones`; Task 15, `test_reopening_starts_clean`.

---

### Task 1: Cycling art in the project

**Skills:** `godot-prompter:assets-pipeline`, `godot-prompter:godot-testing`

**Files:**
- Create: `docs/superpowers/mockups/cycling-view-lacquer/gen/import_cycling.py`
- Create (by the script): `assets/ui/lacquer/cycling/*.png`, `assets/ui/lacquer/icons/lacquer_ic_tech_{foundation,smooth,torrent}_ai.png`, and their `.import` files
- Test: `tests/unit/test_cycling_art.gd`

**Interfaces:**
- Produces these `res://` paths, used by every later task:

| Path | Size | From the mock folder |
|---|---|---|
| `assets/ui/lacquer/cycling/lacquer_cyc_board_ai.png` | 564x1036 | `lacquer_cyc_board_a_ai.png`, 4 px `#050707` shadow baked |
| `assets/ui/lacquer/cycling/lacquer_cyc_body_carved_ai.png` | 500x832 | as is |
| `assets/ui/lacquer/cycling/lacquer_cyc_ball_strip_ai.png` | 480x60 (8 frames of 60) | as is |
| `assets/ui/lacquer/cycling/lacquer_cyc_ball_rings_ai.png` | 160x80 (frame 0 brass, 1 tan dots) | as is |
| `assets/ui/lacquer/cycling/lacquer_cyc_zone_strip_ai.png` | 288x48 (idle, active, spent, perfect, good, ok) | as is |
| `assets/ui/lacquer/cycling/lacquer_cyc_pellet_{brass,cream,tan}_ai.png` | 12x12 | as is |
| `assets/ui/lacquer/cycling/lacquer_cyc_auto_ai.png` | 122x38 | 2 px `#150909` shadow baked |
| `assets/ui/lacquer/cycling/lacquer_cyc_auto_on_ai.png` | 122x38 | pressed: no shadow, padded with 2 clear px right and bottom to match |
| `assets/ui/lacquer/icons/lacquer_ic_tech_{foundation,smooth,torrent}_ai.png` | 32x32 | as is |

- [ ] **Step 1: Write the failing test.** `test_cycling_art.gd` loads each path above and asserts its size. A helper `_assert_opaque_or_clear(path, palette)` asserts every pixel has alpha 0 or 1 and, when a palette is given, a colour in it. Palettes: brass pellet `["f0e8d8","d4a84a","a66834","341e0e","150909"]`, cream pellet `["f0e8d8","a89070","7a654c","150909"]`, tan pellet `["f0e8d8","a89070","7a654c","341e0e","150909"]`. The board, body, strips and toggles get the opaque-or-clear check with no palette.
- [ ] **Step 2: Run it.** `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_cycling_art.gd -gexit`. Expected: FAIL, the textures don't exist.
- [ ] **Step 3: Write `import_cycling.py`.** Usage: `python import_cycling.py <mock folder> <assets/ui/lacquer>`. It copies the table's files byte for byte unless they get a shadow or padding, and skips everything else in the folder (the turned-down boards B and C, `body_brass`, `body_seated`, `pellet_jade`, `tray_side`, `dither`, `gen/`, `.gdignore`). Its `bake_shadow(src, dst, offset, rgb)` matches `zone-view-lacquer/gen/import_kit.py`: grow the canvas by `offset` right and bottom, paste the art's silhouette in `rgb` at `+offset`, then the art at 0. Write it fresh: importing `import_kit.py` runs its module-level `sys.argv` code.
- [ ] **Step 4: Run the import.** `python docs/superpowers/mockups/cycling-view-lacquer/gen/import_cycling.py docs/superpowers/mockups/cycling-view-lacquer assets/ui/lacquer`, then `"$GODOT" --headless --import`. The new `.import` files use Godot's defaults, which match the kit's (`compress/mode=0`, `mipmaps/generate=false`).
- [ ] **Step 5: Run the test.** Expected: PASS.
- [ ] **Step 6: Commit.** `git add` the script, the new PNGs and their `.import` files, and the test; `git commit -m "feat(cycling): add the lacquer cycling art"`.

### Task 2: Technique icons and the seen-technique save fields

**Skills:** `godot-prompter:resource-pattern`, `godot-prompter:save-load`

**Files:**
- Modify: `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd`
- Modify: `resources/cycling/cycling_techniques/foundation_cycling_technique/foundation_cycling_technique.tres`, `smooth_flow/smooth_flow.tres`, `torrential_flow/torrential_flow.tres`
- Modify: `singletons/persistence_manager/save_game_data.gd` (fields beside lines 95-96; `reset()` beside 219-220)
- Test: `tests/unit/test_cycling_technique_data.gd`

**Interfaces:**
- Produces: `CyclingTechniqueData.icon: Texture2D`; `SaveGameData.seen_cycling_technique_ids: Array[String] = []`; `SaveGameData.seen_cycling_techniques_initialized: bool = false`.

- [ ] **Step 1: Write the failing tests.**
  - `test_every_catalog_technique_has_an_icon`: for each entry of `cycling_technique_list.tres`, `assert_not_null(t.icon)` and `t.icon.get_size() == Vector2(32, 32)`.
  - `test_icons_match_the_techniques`: foundation, smooth and torrential point at `lacquer_ic_tech_foundation_ai.png`, `_smooth_ai.png` and `_torrent_ai.png`.
  - `test_reset_clears_seen_techniques`: set both fields, call `reset()`, assert `[]` and `false`.
  - `test_seen_techniques_survive_a_save`: `ResourceSaver.save` to `user://test_seen_techniques.tres`, load it back, assert both fields equal, then delete the file.
- [ ] **Step 2: Run them.** Expected: FAIL (no `icon`, no fields).
- [ ] **Step 3: Implement.** Add `## The technique's icon, 16 art px shown at 32 (its drawer in the zone chest).` and `@export var icon: Texture2D`. Point each `.tres` at its icon through an `ext_resource`. Add both fields with `##` comments mirroring `seen_action_ids`, and clear them in `reset()`. While in `cycling_technique_data.gd`, drop the stale "This is the key change" comments (CYCLING.md tech debt).
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(cycling): give techniques an icon and save the seen ones`.

### Task 3: `CyclingManager`: seen techniques and the cycle snapshot

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/cycling_manager/cycling_manager.gd`
- Test: `tests/unit/test_cycling_manager.gd` (extend; keep its injection fixture)

**Interfaces:**
- Consumes: Task 2's save fields.
- Produces:
  - `signal madra_rate_changed(rate: float)`: emitted when `snappedf(rate, 0.1)` changes, including the drop to 0.
  - `func mark_technique_seen(technique_id: String) -> void`: ignores "" and duplicates.
  - `func is_technique_seen(technique_id: String) -> bool`: true when the technique is in the seen list or is the equipped one.
  - `func start_cycle_session(duration: float) -> void`, `func update_cycle_session(elapsed: float, madra_rate: float) -> void`, `func end_cycle_session() -> void`.
  - `func is_cycle_running() -> bool`, `func get_cycle_progress() -> float` (elapsed / duration, clamped 0–1; 0 when not running), `func get_cycle_elapsed() -> float`, `func get_cycle_duration() -> float`, `func get_madra_rate() -> float`.
  - Private `_initialize_seen_techniques() -> void`, called on `_ready` and from `_on_save_data_reset()`. When the save's flag is false, it marks every unlocked technique seen and sets the flag (the `ZoneManager._initialize_seen_actions()` pattern).

- [ ] **Step 1: Write the failing tests.**
  - `test_first_init_marks_unlocked_techniques_seen`: `_save_data.unlocked_cycling_technique_ids.append("tech_a")`, call `CyclingManager._initialize_seen_techniques()`, assert `is_technique_seen("tech_a")` and `_save_data.seen_cycling_techniques_initialized`.
  - `test_init_runs_once`: after the init, unlock `tech_a` and run the init again; `tech_a` stays unseen.
  - `test_mark_seen_stores_once`: mark twice; `count("tech_a") == 1`.
  - `test_equipped_counts_as_seen`: unlock and equip `tech_a` without marking it; `is_technique_seen("tech_a")` is true.
  - `test_cycle_snapshot`: `start_cycle_session(15.0)`, `update_cycle_session(6.0, 10.0)`. Assert `is_cycle_running()`, `is_equal_approx(get_cycle_progress(), 0.4)`, elapsed 6.0, duration 15.0, rate 10.0. `end_cycle_session()`: not running, progress 0.0, rate 0.0.
  - `test_rate_signal_fires_on_tenths`: `watch_signals(CyclingManager)`; start, update with 13.3, then 13.32, then end. `assert_signal_emit_count(CyclingManager, "madra_rate_changed", 2)`; the last emitted rate is 0.0.
  - In `after_each`, also call `CyclingManager.end_cycle_session()`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement** the interfaces above. Keep the snapshot in private vars; nothing is saved.
- [ ] **Step 4: Run the file.** Expected: PASS, the 20 existing tests included.
- [ ] **Step 5: Commit.** `feat(cycling): track seen techniques and the running cycle`.

### Task 4: NEW on the cycling card when a technique unlocks

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/zone_manager/zone_manager.gd` (seen section, around line 185)
- Test: `tests/unit/test_seen_actions.gd` (extend)

**Interfaces:**
- Produces: `func mark_action_unseen(action_id: String) -> void`, which erases the id from `seen_action_ids`. Private `_on_technique_unlocked(_technique: CyclingTechniqueData) -> void` marks unseen every action of type `ZoneActionData.ActionType.CYCLING` in every zone's `all_actions`. `_ready` connects it to `CyclingManager.technique_unlocked`. Godot creates every autoload before adding any, so `CyclingManager` exists when ZoneManager's `_ready` runs.

- [ ] **Step 1: Write the failing tests.**
  - `test_mark_unseen_clears_seen`: mark `FORAGING_ID`, unmark it, then `assert_false(ZoneManager.is_action_seen(FORAGING_ID))`.
  - `test_technique_unlock_lights_the_cycling_card`: load a save with `FIRST_DIALOGUE_ID` unlocked (cycling counts as seen), call `CyclingManager.unlock_technique("smooth_flow")`, then `assert_false(ZoneManager.is_action_seen(CYCLING_ID))`.
  - `test_opening_cycling_clears_it_again`: after the unlock, `ActionManager.select_action(ZoneManager.get_action_by_id(CYCLING_ID))` makes it seen again.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(zones): light NEW on the cycling card when a technique unlocks`.

### Task 5: Madra added, and the cycling rate in `ActionManager`

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Modify: `singletons/resource_manager/resource_manager.gd:77` (`add_madra`)
- Modify: `singletons/action_manager/action_manager.gd:163` (`get_current_madra_per_second`)
- Test: `tests/unit/test_quiet_madra.gd` (extend), `tests/unit/test_cycling_rate.gd` (new)

**Interfaces:**
- Produces: `func add_madra(amount: float, quiet: bool = false) -> float`, returning the snapped amount actually added (0.0 at the cap). Callers that ignore it are unchanged. `get_current_madra_per_second()` returns `CyclingManager.get_madra_rate()` while the current action's type is CYCLING.

- [ ] **Step 1: Write the failing tests.**
  - In `test_quiet_madra.gd` (fresh save: 25 Madra, cap 100): `test_add_returns_what_it_added` (`add_madra(5.0, true) == 5.0`), `test_capped_add_returns_what_fit` (`add_madra(90.0, true) == 75.0`), `test_add_at_the_cap_returns_zero` (after `set_madra(100.0)`, `add_madra(1.0, true) == 0.0`).
  - In `test_cycling_rate.gd`: select the cycling action, `CyclingManager.start_cycle_session(15.0)`, `update_cycle_session(5.0, 13.3)`; assert `is_equal_approx(ActionManager.get_current_madra_per_second(), 13.3)`; after `end_cycle_session()` it is 0.0. In `after_each`, stop the action and end the session.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(madra): report the Madra added and the cycling rate`.

### Task 6: Palette constants and the pellet's texture

**Skills:** `godot-prompter:godot-testing`

**Files:**
- Modify: `scripts/utils/theme_constants.gd` (lacquer palette block, lines 40-60)
- Modify: `scenes/zones/zone_transition/madra_pellet.gd`
- Test: `tests/unit/test_lacquer_pieces.gd` (`test_lacquer_palette_matches_the_kit`), `tests/unit/test_madra_pellet.gd`

**Interfaces:**
- Produces:
  - `ThemeConstants.LACQUER_RIM = Color("#692F2F")`: lit rims, and the lip under a carved groove.
  - `ThemeConstants.LACQUER_MADRA_HI = Color("#E8F6FD")`: the top edge of lit Madra.
  - `ThemeConstants.LACQUER_MADRA_MID = Color("#849BE4")`: the lower edge of lit Madra.
  - `func set_texture(texture: Texture2D) -> void` on `MadraPellet`: sets `%Sprite.texture` and re-centres it with `%Sprite.position = -texture.get_size() / 2.0`.

- [ ] **Step 1: Write the failing tests.** Add the three constants to the palette test. Add `test_set_texture_swaps_and_centres` to `test_madra_pellet.gd`: set the brass pellet texture, then assert the sprite's texture path and `position == Vector2(-6, -6)`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, with a `##` comment on each constant naming its use.
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(ui): add the groove colours and a pellet texture setter`.

### Task 7: Promote the floater (`MapFloater` → `LacquerFloater`)

**Skills:** `godot-prompter:scene-organization`

**Files:**
- Move: `scenes/zones/map_markers/map_floater/map_floater.{gd,gd.uid,tscn}` → `scenes/common/lacquer/lacquer_floater/lacquer_floater.{gd,gd.uid,tscn}` (with `git mv`; keep the UIDs)
- Modify: `scenes/zones/map_markers/map_markers.gd` (lines 9, 119, 226), `map_markers.tscn` (the ext_resource path at line 5)
- Modify: `tests/integration/test_map_markers.gd` (`MapFloater` type references)
- Test: `tests/unit/test_lacquer_pieces.gd` (new FLOATER section)

**Interfaces:**
- Produces: `class_name LacquerFloater`, with `MapFloater`'s API unchanged: `pop(text: String, color: Color)`, `stop()`, `get_text()`, `get_color()`, `get_rise() -> int`, `get_token_width() -> int`, `static rise_at(elapsed: float) -> int`. Scene: `res://scenes/common/lacquer/lacquer_floater/lacquer_floater.tscn`. Its header comment drops the map wording: the placer positions it each frame and adds `get_rise()`.

- [ ] **Step 1: Write the failing test.** `test_floater_pops_on_an_even_token`: instance the new scene, `pop("PERFECT +25 XP", ThemeConstants.LACQUER_BRASS)`, then assert it is visible, `get_token_width() % 2 == 0`, `get_color() == LACQUER_BRASS`, and `LacquerFloater.rise_at(0.05) == 2`.
- [ ] **Step 2: Run it.** Expected: FAIL (no class, no scene).
- [ ] **Step 3: Move, rename and update the references.**
- [ ] **Step 4: Run** `test_lacquer_pieces.gd` and `test_map_markers.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `refactor(ui): promote the map floater to a shared lacquer floater`.

### Task 8: Cycling rules and the cycle result

**Skills:** `godot-prompter:gdscript-patterns`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/cycling/cycling_technique/cycling_rules.gd`, `scenes/cycling/cycling_technique/cycle_result.gd`
- Test: `tests/unit/test_cycling_rules.gd`

**Interfaces:**
- Produces `class_name CyclingRules extends RefCounted` (static only):
  - `enum Tier { OK, GOOD, PERFECT }`
  - `const ZONE_RADIUS: float = 20.0`, `const PERFECT_RATIO: float = 0.3`, `const GOOD_RATIO: float = 0.7`
  - `static func tier_for_distance(distance: float) -> Tier`: the ratio is `distance / ZONE_RADIUS`, clamped 0–1
  - `static func xp_for_tier(zone: CyclingZoneData, tier: Tier) -> int`
  - `static func pellet_count(tier: Tier) -> int`: 8, 5 or 3
  - `static func tier_name(tier: Tier) -> String`: "PERFECT", "GOOD", "OK"
  - `static func tier_color(tier: Tier) -> Color`: `LACQUER_BRASS`, `LACQUER_CREAM`, `LACQUER_TAN`
- Produces `class_name CycleResult extends RefCounted`:
  - `var madra_added: float`, `var zones_scored: int`, `var zones_total: int`, `var perfect_count: int`, `var xp: int`
  - `func summary() -> String`, `func result_line() -> String` ("Last cycle · " + summary), `func log_line() -> String` ("Cycle · " + summary)
  - `summary()` is `"+%d Madra" % roundi(madra_added)`, then either "no zones" or `"%d / %d zones"` ("zone" when the total is 1), then `"%d PERFECT"` only if `perfect_count > 0`, then `"+%d XP"` only if `xp > 0`, all joined by " · ".

- [ ] **Step 1: Write the failing tests.**
  - `test_tiers_at_the_thresholds`: 0.0 and 5.9 → PERFECT; 6.0 and 13.9 → GOOD; 14.0 and 49.0 → OK.
  - `test_xp_per_tier`: a `CyclingZoneData` with `perfect_xp 50, good_xp 25, ok_xp 10` gives 50, 25 and 10.
  - `test_pellet_counts`: 8, 5 and 3. `test_tier_names_and_colours`: as above.
  - `test_result_lines`, as five cases:

    | Result (Madra, scored / total, PERFECT, XP) | `result_line()` |
    |---|---|
    | 186.4, 3 / 4, 1, 75 | "Last cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP" |
    | 120, 2 / 4, 0, 30 | "Last cycle · +120 Madra · 2 / 4 zones · +30 XP" |
    | 90, 0 / 4, 0, 0 | "Last cycle · +90 Madra · 0 / 4 zones" |
    | 250, 1 / 1, 1, 30 | "Last cycle · +250 Madra · 1 / 1 zone · 1 PERFECT · +30 XP" |
    | 50, 0 / 0, 0, 0 | "Last cycle · +50 Madra · no zones" |

    And `log_line()` of the first is "Cycle · +186 Madra · 3 / 4 zones · 1 PERFECT · +75 XP".
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(cycling): add the scoring rules and the cycle result`.

### Task 9: `CyclingGroove`

**Skills:** `godot-prompter:2d-essentials` (custom drawing), `godot-prompter:math-essentials`

**Files:**
- Create: `scenes/cycling/cycling_groove/cycling_groove.gd`
- Test: `tests/unit/test_cycling_groove.gd`

**Interfaces:**
- Consumes: Task 6's colours.
- Produces `class_name CyclingGroove extends Node2D`:
  - `const CELL: float = 2.0`
  - `static func build_cells(points: PackedVector2Array) -> Dictionary`: maps each `Vector2i` cell to the shortest path length (cumulative distance along `points`) that covers it. Point `p` covers the 2x2 cells at `Vector2i(floori(p.x / CELL - 0.5), floori(p.y / CELL - 0.5))` plus (1, 0), (0, 1) and (1, 1).
  - `static func lip_cells(cells: Dictionary) -> Array[Vector2i]`: for each cell whose cell below is not a cell, that cell below.
  - `func setup(curve: Curve2D) -> void`: samples `curve.sample_baked(d, true)` every 1 px along `curve.get_baked_length()`, plus the end point; builds the cells sorted by path length and the lips.
  - `func set_lit_length(length: float) -> void`: lights every cell whose length is at or under `length`; `queue_redraw()` only when the lit count changes.
  - `func get_lit_count() -> int`, `func get_cell_count() -> int`.
  - `_draw()`: one `draw_rect(Rect2(cell * CELL, Vector2(CELL, CELL)), …)` per cell. Lips are `LACQUER_RIM`; unlit cells `LACQUER_INK`; lit cells `LACQUER_MADRA_HI` when the cell above is not a cell, `LACQUER_MADRA_MID` when the cell below is not, otherwise `LACQUER_MADRA`.

- [ ] **Step 1: Write the failing tests.** The line runs from (0, 10) to (20, 10), one point per px.
  - `test_a_line_covers_two_rows`: 24 cells; rows 4 and 5 for columns −1 to 10; none in row 6.
  - `test_cells_keep_their_first_pass`: points out and back along the same line. Cell (0, 4) keeps a length under 3.0, not the return pass's 38 or more.
  - `test_lips_sit_under_the_bottom_row`: `lip_cells` returns 12 cells, all in row 6.
  - `test_lit_count_follows_the_length`: a node set up with a two-point `Curve2D` from (0, 10) to (100, 10). `set_lit_length(-1.0)` lights 0. The count rises as the length grows. `set_lit_length(1e9)` lights all of `get_cell_count()`.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(cycling): draw the groove in art pixels from the path`.

### Task 10: The cabinet's Core orb and the cycling rate

**Skills:** `godot-prompter:hud-system`, `godot-prompter:godot-testing`

**Files:**
- Modify: `scenes/zones/cultivator_plate/cultivator_plate.gd`
- Test: `tests/integration/test_cultivator_plate.gd`

**Interfaces:**
- Consumes: Task 3's `madra_rate_changed`, Task 5's `get_current_madra_per_second()`.
- Produces: `func get_core_orb_global_position() -> Vector2` (the `%CoreOrb` centre). The rate label refreshes on `CyclingManager.madra_rate_changed` as well, and shows `LacquerText.rate(snappedf(rate, 0.1)) + " / s"`.

- [ ] **Step 1: Write the failing tests.**
  - `test_core_orb_position_is_orb_centre`: as the Madra test, with `+ Vector2(40, 40)`.
  - `test_rate_shows_the_cycling_rate`: select cycling, `start_cycle_session(15.0)`, `update_cycle_session(5.0, 13.333)`. The `RateLabel` is visible with parsed text "+13.3 / s". After `end_cycle_session()` it is hidden.
  - The existing `test_rate_shows_while_aura_well_runs` keeps passing: right after cycling is selected the rate is 0, so the label is hidden.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(zones): show the cycling rate and the core orb's centre on the cabinet`.

### Task 11: `TechniqueDrawer`

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:scene-organization`

**Files:**
- Create: `scenes/cycling/technique_drawer/technique_drawer.gd`, `technique_drawer.tscn`
- Modify: `scenes/zones/zone_action_button/zone_action_button.gd` (extract the title row's layout)
- Test: `tests/integration/test_technique_drawer.gd`; `tests/integration/test_zone_action_cards.gd` must still pass

**Interfaces:**
- Consumes: Task 2 (icons), Task 3 (`is_technique_seen`, `mark_technique_seen`).
- Produces:
  - `static func layout_title_row(title: Label, new_seal: Control, tag: Control) -> void` on `ZoneActionButton`, holding today's `_layout_title_row()` body. That method now calls it.
  - `class_name TechniqueDrawer extends Control`: `const IN_USE_TAG_TEXT: String = "IN USE"`, `const FLASH_TIMES: int = 2`, `const IN_USE_OFFSET: Vector2 = Vector2(-2, -2)`, `var technique: CyclingTechniqueData`.
  - Methods: `func setup(data: CyclingTechniqueData) -> void`, `func refresh() -> void`, `func is_in_use() -> bool`, `func is_new_shown() -> bool`, `func flash() -> void`.
  - `static func detail_text(data: CyclingTechniqueData) -> String`: `"%d Madra · %d s cycle · %s"` with `roundi(base_madra_per_cycle)`, `roundi(cycle_duration)`, and "no zones", "1 zone" or "N zones".
- Scene: the root is a Control, 392x72, with the lacquer theme, mouse STOP and the hand cursor. Under it, `%Drawer` (Control 392x72, mouse IGNORE) holds:
  - `%Face`: TextureRect, `lacquer_drawer_ai.png`;
  - `%Icon`: TextureRect, 32x32 at (16, 20);
  - `%Title`: Label, `LabelLacquerName`, at (64, 14);
  - `%NewSeal`: TextureRect with `lacquer_seal_new_s_ai.png`, holding a `LabelLacquerSeal` that reads "NEW";
  - `%Tag`: TextureRect with `lacquer_tag_ai.png` at (304, 13), holding `%TagLabel` (`LabelLacquerTag`, "IN USE");
  - `%Detail`: Label, `LabelLacquerDetail`, at (64, 38), 316x18, ellipsis;
  - `%HoverFrame`: `lacquer_frame_overlay.tscn` with `frame_hover.tres`;
  - `%FlashFrame`: `lacquer_frame_overlay.tscn`.

  Copy the node settings from `zone_action_button.tscn`.
- Behaviour:
  - **In use** (`CyclingManager.get_equipped_technique() == technique`): the face is `lacquer_drawer_run_ai.png`, `%Drawer` sits at `IN_USE_OFFSET`, the tag shows, and the tag label gets `LACQUER_CREAM` as its font colour. Otherwise the plain face at (0, 0) and no tag.
  - **NEW** shows while `not CyclingManager.is_technique_seen(technique.id)`.
  - **A left press** on a drawer not in use calls `CyclingManager.equip_technique(technique.id)`, `mark_technique_seen()`, `refresh()` and `flash()`. On the drawer in use it does nothing.
  - **Hover** shows `%HoverFrame` and marks the technique seen.

- [ ] **Step 1: Write the failing tests.** Use a fresh save with `smooth_flow` unlocked through `CyclingManager.unlock_technique()`; `foundation_technique` stays equipped.
  - `test_detail_text`: "50 Madra · 8 s cycle · no zones", "200 Madra · 15 s cycle · 4 zones", "250 Madra · 8 s cycle · 1 zone".
  - `test_setup_shows_icon_name_and_detail`.
  - `test_drawer_in_use_is_pulled_out`: `%Drawer.position == Vector2(-2, -2)`, the face texture is `drawer_run`, the tag is visible, and `%TagLabel.get_theme_color("font_color") == LACQUER_CREAM`.
  - `test_other_drawer_is_plain`.
  - `test_click_equips_and_flashes`: send `gui_input` a left press on the smooth drawer. The equipped id becomes "smooth_flow", `%FlashFrame.is_flashing()` is true, and the drawer is in use.
  - `test_click_on_the_drawer_in_use_does_nothing` (Review Focus 3): the equipped id is unchanged and nothing flashes.
  - `test_new_seal_clears_on_hover`: smooth is NEW; after `mouse_entered.emit()` it is not, and `is_technique_seen("smooth_flow")` is true.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Extract `layout_title_row`, then build the scene and script.**
- [ ] **Step 4: Run** `test_technique_drawer.gd` and `test_zone_action_cards.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** First `refactor(zones): share the drawer title row layout`, then `feat(cycling): add the technique drawer`.

### Task 12: The chest's techniques mode

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:godot-testing`

**Files:**
- Create: `scenes/zones/zone_panel/technique_list/technique_list.gd`, `technique_list.tscn`
- Modify: `scenes/zones/zone_panel/zone_panel.gd`, `zone_panel.tscn`
- Test: `tests/integration/test_zone_panel.gd`

**Interfaces:**
- Consumes: Task 11's `TechniqueDrawer`, Task 4's unseen hook.
- Produces:
  - `class_name TechniqueList extends Control` (mouse IGNORE), with a `%Drawers` VBoxContainer (separation 8) at (0, 0).
  - Its members: `signal layout_changed`, `const DRAWER_SCENE`, `const DRAWER_HEIGHT: float = 72.0`, `const DRAWER_GAP: float = 8.0`, `func build() -> void` (one drawer per `CyclingManager.get_unlocked_techniques()`, in that order), `func get_content_height() -> float` (n × 72 + (n − 1) × 8; 0 for none), `func get_drawer(technique_id: String) -> TechniqueDrawer`, `func get_drawer_count() -> int`.
  - It rebuilds and emits `layout_changed` on `CyclingManager.technique_unlocked`, and calls `refresh()` on every drawer on `equipped_technique_changed`.
  - `ZonePanel`: `const ACTIVITIES_HEADER: String = "Activities"`, `const TECHNIQUES_HEADER: String = "Techniques"`, `const HERE_FORMAT: String = "%d here"`, `const LEARNED_FORMAT: String = "%d learned"`, `func set_techniques_mode(on: bool) -> void`, `func is_techniques_mode() -> bool`, `func get_technique_list() -> TechniqueList`.
- Scene changes in `zone_panel.tscn`:
  - give the "Activities" Label a unique name, `%HeaderLabel`;
  - add `%TechniqueList` (`technique_list.tscn`) at local (16, 208), hidden.
- Script changes in `zone_panel.gd`:
  - a private `_apply_header()` sets the header and count for the mode; `_rebuild()` calls it instead of setting `"%d here"` itself;
  - `_relayout()` measures and places `TechniqueList` instead of `ActivityList` in techniques mode;
  - `_ready()` connects `TechniqueList.layout_changed` to `_relayout`, and `CyclingManager.technique_unlocked` to `_queue_rebuild` (so the cycling card's NEW seal refreshes).

- [ ] **Step 1: Write the failing tests.** Use a fresh save with `smooth_flow` and `torrential_flow` unlocked.
  - `test_techniques_mode_lists_unlocked_techniques`:
    - `set_techniques_mode(true)` shows `TechniqueList` and hides `ActivityList`;
    - the drawers are foundation, smooth and torrential, in that order;
    - the header reads "Techniques" and the count "3 learned".
  - `test_techniques_mode_chest_hugs_the_list`: `_panel.size.y == 464.0` (208 + 232 + 24); the list's `position.y == LIST_TOP`.
  - `test_leaving_techniques_mode_restores_activities`.
  - `test_unlock_in_techniques_mode_adds_a_drawer` (Review Focus 4):
    - start with only smooth unlocked, in techniques mode;
    - unlock `torrential_flow` and wait 2 frames;
    - the count is 3, torrential's drawer `is_new_shown()`, and the chest grew 80 px.
  - `test_a_rebuild_in_techniques_mode_keeps_the_header`: `UnlockManager.condition_unlocked.emit("test")`, wait 2 frames, and the header still reads "Techniques".
  - `test_cycling_card_shows_new_after_a_technique_unlock`:
    - the first dialogue is unlocked, so the card counts as seen;
    - unlock `smooth_flow` and wait 2 frames;
    - `(_panel.get_card(CYCLING_ID) as ZoneActionButton).is_new_shown()` is true.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test_zone_panel.gd`. Expected: PASS, the 48 existing tests included.
- [ ] **Step 5: Commit.** `feat(zones): list the techniques in the chest while cycling`.

### Task 13: The Now tray shows the cycle

**Skills:** `godot-prompter:hud-system`, `godot-prompter:godot-testing`

**Files:**
- Modify: `scenes/zones/zone_panel/now_strip/now_strip.gd` (header comment, `_show_action`, `_update_timer_display`, `_ready`)
- Test: `tests/integration/test_zone_panel.gd` (`test_tray_reads_paused_while_cycling` becomes the two tests below)

**Interfaces:**
- Consumes: Task 3's snapshot.
- Produces:
  - **What shows.** The cycling action shows in the tray. It reuses `%TrainingContent`, whose layout is the same: name and rate, then a detail and a figure, then a rod.
  - **Constants.** `const CYCLE_TIME_FORMAT: String = "%d / %d s"`, `const CYCLE_READY_FORMAT: String = "%d s cycle"`.
  - **Mouse.** IGNORE while cycling: no hover frame, no hand cursor, no `strip_pressed`.
  - **Ring.** `mini(floori(get_cycle_progress() × 13), 12)`.
  - **Rod.** `%WellRod.set_fraction(get_cycle_progress())`.
  - **Figure.** While a cycle runs, `"%d / %d s" % [floori(get_cycle_elapsed()), roundi(get_cycle_duration())]`. Otherwise `"%d s cycle"` of the equipped technique's duration.
  - **Detail.** The equipped technique's name; it refreshes on `CyclingManager.equipped_technique_changed`.
  - **Rate.** `%RateGroup` shows while `get_madra_rate() >= 0.05`, as `"%s Madra / s" % LacquerText.rate(snappedf(rate, 0.1))` through `decimal_bbcode`.
  - **Comment.** Update the header comment: the "· paused" line stays for the shop, adventures and dialogue.

- [ ] **Step 1: Write the failing tests.**
  - `test_tray_shows_the_cycle_ready`:
    - select cycling on a fresh save (Foundational is equipped);
    - the texts are "Wilderness Cycling", "Foundational Technique", "8 s cycle" and "Now";
    - the ring is at frame 0, the icon is the action's, the rod is at step 0, the rate is hidden, and `mouse_filter == MOUSE_FILTER_IGNORE`.
  - `test_tray_follows_the_running_cycle`:
    - `start_cycle_session(15.0)`, `update_cycle_session(9.0, 13.3)`, then wait 1 frame;
    - the ring is at frame 7, the figure reads "9 / 15 s", the rod step is 91, and the rate's parsed text is "+13.3 Madra / s".
  - `test_tray_reads_paused_with_the_shop_open` stays as it is.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test_zone_panel.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(zones): show the running cycle in the Now tray`.

### Task 14: `CyclingZone` and `CyclingTechnique` rebuilt

**Skills:** `godot-prompter:2d-essentials`, `godot-prompter:input-handling` (physics picking), `godot-prompter:godot-testing`

**Files:**
- Modify: `scenes/cycling/cycling_technique/cycling_zone.gd`, `cycling_zone.tscn`, `cycling_technique.gd`, `cycling_technique.tscn`
- Test: `tests/integration/test_cycling_technique.gd` (new)

**Interfaces:**
- Consumes: Tasks 1, 3, 5, 8 and 9.
- `class_name CyclingZone extends Area2D`:
  - `enum State { IDLE, ACTIVE, SPENT, PERFECT, GOOD, OK }`: the zone strip's frame order;
  - `signal zone_clicked(zone: CyclingZone)` on a left press while open;
  - `var zone_data: CyclingZoneData`;
  - `func setup(data: CyclingZoneData) -> void`, `func set_state(state: State) -> void`, `func get_state() -> State`, `func is_open() -> bool` (IDLE or ACTIVE);
  - `static func state_for_tier(tier: CyclingRules.Tier) -> State`.

  Scene: `input_pickable`, a `CollisionShape2D` whose `CircleShape2D` (radius 20) is `resource_local_to_scene`, and `%Socket`, a `LacquerStripRect` (strip `lacquer_cyc_zone_strip_ai.png`, frame 48x48) at (−24, −24). Always visible; the state is the frame.
- `class_name CyclingTechnique extends Node2D`:
  - Signals: `signal cycling_started`, `signal cycle_completed(result: CycleResult)`, `signal madra_particle_requested(from_pos: Vector2)` (the ball's drawn global centre), `signal zone_scored(zone: CyclingZone, tier: CyclingRules.Tier, xp: int)`.
  - Constants: `const BALL_RADIUS: float = 29.5`, `const MADRA_PARTICLE_INTERVAL: float = 0.08`, `const SWIRL_FRAMES: int = 8`, `const SWIRL_FPS: float = 10.0`, `const RATE_WINDOW: float = 1.0`.
  - Properties: `var auto_cycle: bool = false`, `var technique_data: CyclingTechniqueData`, `var cycling_zones: Array[CyclingZone]`.
  - `func setup(data: CyclingTechniqueData) -> void`: ends any running cycle without `cycle_completed`, rebuilds the zones (IDLE), sets up the groove and returns the ball to the start.
  - `func start_cycle() -> bool`: only from ready. It sets every zone to IDLE (clearing the last cycle's studs), darkens the groove, starts the session and emits `cycling_started`.
  - `func wants_pointer(cursor_global: Vector2) -> bool`: true when not cycling and the cursor is within `BALL_RADIUS` of the ball, or when cycling and the cursor is within `ZONE_RADIUS` of an ACTIVE zone.
  - `func stop_cycling() -> void`: ends a running cycle without `cycle_completed`, sets the zones to IDLE, darkens the groove, returns the ball to the start and ends the session.
  - `func advance(delta: float, cursor_global: Vector2) -> void`: `_process` calls it with `get_global_mouse_position()`; tests call it directly.
  - `func try_score_zone(zone: CyclingZone) -> bool`, `func is_cycling() -> bool`, `func is_tracking() -> bool`, `func get_ball_global_position() -> Vector2`, `func get_current_result() -> CycleResult`.
- Scene: `CyclingTechnique` (Node2D, `technique_data_input` left null) holds:
  - `%CyclingGroove`;
  - `%CyclingPath2D`, holding `%PathFollow2D` (rotates false, loop false), which holds `%MadraBall` (an `input_pickable` Area2D with a `CircleShape2D` of radius 29.5);
  - `%BallRing`: `LacquerStripRect`, strip `lacquer_cyc_ball_rings_ai.png`, frame 80x80;
  - `%BallSprite`: `LacquerStripRect`, strip `lacquer_cyc_ball_strip_ai.png`, frame 60x60.

  Zones are instanced under `%CyclingPath2D`. Remove `PathLine`, `PathGlowLine`, `AutoCycleToggle`, the shader material and the `FloatingText` use.
- `advance()` order:
  1. The swirl clock always runs; the swirl frame is `floori(clock × 10) % 8`.
  2. Not cycling: the ball sits at the start with ring frame 0, and nothing else happens.
  3. Cycling: add `delta` to elapsed; `progress_ratio = 0.5 - 0.5 × cos(PI × min(elapsed / duration, 1))`.
  4. Draw the ball and ring at the `PathFollow2D` global position snapped to even px (`(p / 2).round() × 2`).
  5. Tracking is the cursor within `BALL_RADIUS` of the drawn centre. Ring frame 1 while tracking; the ring is hidden otherwise.
  6. While tracking, the Madra timer adds `delta` and, while it is at least `MADRA_PARTICLE_INTERVAL`, subtracts it. Below the cap each step calls `ResourceManager.add_madra(base_madra_per_cycle × 0.08 / cycle_duration, true)`; if it added more than 0, add that to `madra_added` and emit `madra_particle_requested`.
  7. Each open zone is ACTIVE while the ball (true position) is within `BALL_RADIUS + ZONE_RADIUS` (49.5 px), and turns SPENT when it leaves ACTIVE unscored.
  8. Light the groove up to the drawn ball's path length.
  9. Update the session with elapsed time and the Madra added over the last `RATE_WINDOW`.
  10. At the end, any zone still open turns SPENT. End the session, emit `cycle_completed(result)`, and start the next cycle when `auto_cycle` is on.
- Scoring: `try_score_zone()` succeeds only while cycling on an ACTIVE zone. The tier comes from the ball-to-zone distance. It calls `CultivationManager.add_core_density_xp(xp)`, counts the result, sets the zone's state and emits `zone_scored`.
- Wiring: `%MadraBall.input_event` (a left press) calls `start_cycle()`; `zone.zone_clicked` calls `try_score_zone()`.

- [ ] **Step 1: Write the failing tests.**
  - **Fixture.** A fresh save (25 Madra, cap 100). Instance `cycling_technique.tscn` at (0, 0), `set_process(false)`, then `setup(load(smooth_flow.tres))`. A `_run(seconds, fps, track)` helper calls `advance(1.0 / fps, technique.get_ball_global_position() if track else Vector2(-9999, -9999))`.
  - **Cycle lifecycle:**
    - `test_zones_show_between_cycles`: four zones, all visible and IDLE.
    - `test_start_only_from_ready`.
    - `test_cycle_completes_with_a_result`: 15 s at 60 FPS without tracking. One `cycle_completed`, whose result has `madra_added == 0`, `zones_total == 4` and `zones_scored == 0`. All zones are SPENT, and the technique is not cycling.
  - **Madra:**
    - `test_tracking_draws_madra_quietly`: 1 s at 60 FPS while tracking gives 12 `madra_particle_requested`. Madra is about 25 + 12 × 1.0667, and `LogManager.message_logged` is not emitted.
    - `test_madra_steps_carry_their_remainder`: at 30, 60 and 144 FPS, 1 s of tracking gives 12 pellets each (the old timer reset gives 10 at 30 FPS).
    - `test_no_madra_or_pellets_at_the_cap`: `set_madra(100.0)`; 1 s of tracking gives 0 pellets, and Madra stays 100.
    - `test_cap_reached_mid_cycle` (Review Focus 2): `set_madra(98.0)`; 1 s of tracking gives 2 pellets, and `is_equal_approx(get_current_result().madra_added, 2.0)`.
  - **Zones and scoring:**
    - `test_zone_states_follow_the_ball`: step until zone 0 is ACTIVE, then keep stepping unscored until it turns SPENT.
    - `test_scoring_an_active_zone_uses_the_tier_rule`:
      - step until zone 0 is ACTIVE, and note the ball-to-zone distance `d`;
      - `try_score_zone(zone)` is true;
      - the state is `state_for_tier(tier_for_distance(d))`;
      - `zone_scored` is emitted, the XP counts, and the result shows one scored zone.
    - `test_inactive_or_scored_zones_ignore_clicks`: false before a cycle, and false a second time after a score.
    - `test_studs_stay_until_the_next_start`: score a zone, finish the cycle, and the zone keeps its stud. `start_cycle()` sets it back to IDLE.
    - `test_pointer_over_the_ready_ball_and_active_zones`: `wants_pointer()` is true at the ready ball's centre and false 40 px away. During a cycle it is true over an ACTIVE zone and false over the ball.
  - **Ending, switching and auto:**
    - `test_switching_technique_mid_cycle_ends_quietly`: after 1 s, `setup(foundation)` gives no `cycle_completed`, the technique is not cycling, and `CyclingManager.is_cycle_running()` is false.
    - `test_stop_resets_zones` (Review Focus 5): run until a zone is SPENT, then `stop_cycling()`. All zones are IDLE, `%CyclingGroove.get_lit_count() == 0`, and the ball is back at the start.
    - `test_auto_chains_cycles`: with `auto_cycle = true`, run 15 s plus one frame. One `cycle_completed`, and the technique is cycling again.
    - `test_a_frame_hitch_spends_skipped_zones` (Review Focus 1): `advance(16.0, far)` completes the cycle with all zones SPENT.
  - **Drawing and the snapshot:**
    - `test_ball_is_drawn_on_even_px`: every frame of 2 s, `%BallSprite.global_position` has even x and y.
    - `test_session_snapshot_follows_the_cycle`: at 6 s, `get_cycle_progress()` is about 0.4; after the end, not running.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Rebuild both scenes and scripts.** Delete `_print_cycle_stats`, `click_timings`, `_update_madra_ball_shader`, `set_technique_data` (callers use `setup`) and the `cycling_zone.gdshader` use.
- [ ] **Step 4: Run** `test_cycling_technique.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(cycling): rebuild the technique with stepped, snapped play`.

### Task 15: The cycling board (`CyclingView`)

**Skills:** `godot-prompter:godot-ui`, `godot-prompter:hud-system`, `godot-prompter:scene-organization`

**Files:**
- Modify: `scenes/cycling/cycling_view/cycling_view.gd`, `cycling_view.tscn` (rebuilt)
- Delete:
  - `scenes/cycling/cycling_resource_panel/` (whole folder) and `scenes/cycling/cycling_tab_panel/`;
  - `scenes/cycling/cycling_technique_slot/` and `scenes/ui/flying_particle/`;
  - `assets/shaders/{madra_ball,cycling_zone,path_pulse,core_density_fill}.gdshader` and their `.uid` files;
  - `assets/styleboxes/cycling/`.
- Test: `tests/integration/test_cycling_view.gd` (new)

**Interfaces:**
- Consumes: Tasks 6, 7, 8, 10 and 14.
- Produces:
  - `class_name CyclingView extends Control` and `var cultivator_plate: CultivatorPlate = null` (set by `MainView` in Task 16).
  - Copy: `const READY_FIRST`, `READY_AGAIN`, `CYCLING_FORMAT = "Cycling · %d / %d s"`, `FOLLOW_SUFFIX = " · follow the ball"`, `MADRA_FULL`, `MADRA_FULL_ZONES`, `AUTO_ON_TEXT`, `AUTO_OFF_TEXT`.
  - Effects: `const FLOATER_LIFT: float = 56.0`, `const MADRA_PELLET_FLIGHT: float = 0.6`, `const MADRA_PELLET_SPREAD: float = 60.0`, `const XP_PELLET_FLIGHT: float = 0.55`, `const XP_PELLET_SPREAD: float = 40.0`.
  - `static func status_line(cycled_before: bool, running: bool, elapsed: float, duration: float, tracking: bool, madra_full: bool, has_zones: bool) -> String`.
  - `func get_status_text() -> String`, `func get_result_text() -> String`.
- Scene. The root fills the screen with mouse IGNORE and the lacquer theme. Its children, in screen px:
  - `%Board`: TextureRect `lacquer_cyc_board_ai.png` at (680, 24), mouse PASS.
  - `%ActionLabel`: `LabelLacquerDetail` at (710, 40).
  - `%TitleLabel`: `LabelLacquerPanelTitle` at (710, 60).
  - `%EscLabel`: `LabelLacquerHotkey` "Esc", right-aligned in (1114, 45)–(1174, 63).
  - `%CloseButton`: TextureButton at (1182, 40), 28x28, `close` normal and `close_hover` hover.
  - `%FigureBox`: Control at (710, 104), 500x832, mouse PASS. It holds `%Body` (TextureRect, the carved figure at (0, 0)) and `%CyclingTechnique` at (−70, −24).
  - `%StatusLabel`: `LabelLacquerName` at (710, 954), 368 wide, ellipsis.
  - `%ResultText`: `RichTextLacquer` at (710, 996), 500x18.
  - `%AutoToggle`: TextureButton at (1090, 946), toggle mode, `cyc_auto` normal and `cyc_auto_on` pressed. It holds `%AutoLabel` (`LabelLacquerDetail`, centred across 120) and `%AutoHover` (the frame overlay with `frame_hover.tres`).
  - `%EffectsLayer`: Control, full rect, mouse IGNORE.
- Behaviour:
  - **On show.** Set the action label from `ActionManager.get_current_action().action_name` and the title from the technique. Clear the result line and `cycled_before`, and turn on the technique's processing.
  - **On hide.** Turn processing off and hide every floater.
  - **Each frame.** The status label shows `status_line(...)`. `madra_full` is `ResourceManager.get_madra() >= CultivationManager.get_max_madra()`. Floaters are placed at `zone centre − (even(width / 2), FLOATER_LIFT + rise)`. `%FigureBox.mouse_default_cursor_shape` is `CURSOR_POINTING_HAND` while `wants_pointer(get_global_mouse_position())` is true, and `CURSOR_ARROW` otherwise.
  - **`madra_particle_requested`.** Instance `madra_pellet.tscn` into `%EffectsLayer`, launched to `cultivator_plate.get_madra_orb_global_position()`. Skip it when `cultivator_plate` is null.
  - **`zone_scored`.** Pop the zone's `LacquerFloater` with "%s +%d XP" in `tier_color`. Send `pellet_count(tier)` pellets with the tier texture to the Core orb, each with a ±7 px offset, a duration of 0.55 + 0.03k and a spread of 40 + 10k.
  - **`cycle_completed`.** Show `ResultText` with `decimal_bbcode(result.result_line())`, call `LogManager.log_message("[color=cyan]%s[/color]" % result.log_line())`, and set `cycled_before`.
  - **`CyclingManager.equipped_technique_changed`.** Call `setup()`, rebuild one floater per zone (instanced from `lacquer_floater.tscn`), and clear the result line.
  - **Auto toggle.** Sets `auto_cycle`, the label text, `LACQUER_CREAM` on and `LACQUER_TAN` off, and moves the label 2 px down while on.
  - **Close and stop.** `%CloseButton.pressed` calls `ActionManager.stop_action()`. Keep `ActionManager.stop_cycling` → `stop_cycling()`. `_ready` keeps `_load_equipped_technique()` and its fallback.

- [ ] **Step 1: Write the failing tests.**
  - **Fixture.** A fresh save with `smooth_flow` unlocked and equipped. Add a `cultivator_plate.tscn` and the view, set `view.cultivator_plate`, show the view, and drive the technique with `advance()`.
  - `test_status_line_copy`:

    | `status_line(...)` arguments | Result |
    |---|---|
    | `false, false, 0, 15, false, false, true` | `READY_FIRST` |
    | `true, false, ...` | `READY_AGAIN` |
    | `true, true, 9.4, 15, true, false, true` | "Cycling · 9 / 15 s" |
    | the same, not tracking | "Cycling · 9 / 15 s · follow the ball" |
    | running and full, with zones | `MADRA_FULL_ZONES` |
    | running and full, no zones | `MADRA_FULL` |
  - `test_board_layout`: `%Board.position == (680, 24)`, `%FigureBox` at (710, 104) and 500x832. The mouse filters are PASS (Board, FigureBox), IGNORE (root, EffectsLayer) and STOP (CloseButton). Every node position is even.
  - `test_title_follows_the_equipped_technique`: equipping Torrential Flow sets the title to "Torrential Flow".
  - `test_cycle_end_writes_the_result_and_one_log_line`: one full untracked cycle. `get_result_text()` is "Last cycle · +0 Madra · 0 / 4 zones", with exactly one `message_logged`, "[color=cyan]Cycle · +0 Madra · 0 / 4 zones[/color]".
  - `test_madra_pellets_fly_from_the_ball`: 0.2 s of tracking puts 2 `MadraPellet` children in `%EffectsLayer`.
  - `test_scoring_pops_the_zone_floater_and_pellets`: score zone 0. Its floater is visible with "<TIER> +<xp> XP" and `tier_color`, and `pellet_count(tier)` more pellets carry the tier texture.
  - `test_auto_toggle_sets_auto_cycle`: pressing it sets `auto_cycle` and the label to "Auto · on".
  - `test_reopening_starts_clean` (Review Focus 5): score a zone, hide and show the view. The result text is empty, no floater is visible, and the zones are IDLE.
  - `test_close_stops_the_action`: with the cycling action selected, `%CloseButton.pressed.emit()` leaves another action current.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Rebuild the scene and script.** Run the file. Expected: PASS. Commit `feat(cycling): rebuild the cycling view as the lacquer board`.
- [ ] **Step 4: Delete the old pieces** listed under Files. Grep the deleted class names and paths in `scenes/`, `scripts/`, `singletons/`, `tests/` and `assets/themes/`: expect no hits, apart from the `CyclingTabContainer` variant in `pixel_theme.tres` (it stays; backlog P1). Run the full suite. Expected: PASS. Commit `refactor(cycling): delete the old cycling panels, particles and shaders`.

### Task 16: Cycling mode on the main view

**Skills:** `godot-prompter:state-machine`, `godot-prompter:input-handling`, `godot-prompter:godot-testing`

**Files:**
- Modify: `scenes/main/main_game/main_game.tscn`: `unique_name_in_owner = true` on `CultivatorPlate`, `ZonePanel`, `Dock` and `ZoneView/SubViewportContainer/SubViewport`
- Modify: `scenes/ui/main_view/main_view.gd`, `scenes/ui/main_view/states/cycling_view_state.gd`
- Test: `tests/unit/test_cycling_mode.gd` (new), `tests/unit/test_view_state_hud_positions.gd` (three tests change)

**Interfaces:**
- Consumes: Task 12's `set_techniques_mode`, Task 15's `CyclingView`.
- Produces on `MainView`:
  - `@onready var cultivator_plate: CultivatorPlate = %CultivatorPlate`;
  - `@onready var zone_panel: ZonePanel = %ZonePanel`;
  - `@onready var dock: Control = %Dock`;
  - `@onready var zone_map_viewport: SubViewport = %SubViewport`;
  - `func set_cycling_mode(on: bool) -> void`: null-safe for each reference. It calls `zone_panel.set_techniques_mode(on)`, sets `dock.visible = not on` and `zone_map_viewport.gui_disable_input = on`.
  - `_ready()` sets `cultivator_plate` on the cycling view when `cycling_view is CyclingView`.
- `CyclingViewState`:
  - `enter()` calls `set_cycling_mode(true)`, shows `cycling_view` and blocks the full log as `BookViewState._block_full_log()` does. `exit()` reverses all three.
  - It no longer touches `grey_background` or the HUD boards.
  - `_on_start_cycling()` pushes only `if not scene_root.state_stack.has(self)`.
  - Its doc comments describe the new behaviour.

- [ ] **Step 1: Write the failing tests.**
  - **`test_cycling_mode.gd` fixture.** `MainView.new()` (autofree, never in the tree). Assign `zone_panel` (a real `zone_panel.tscn`, added with `add_child_autofree`), `dock` (a plain Control), `zone_map_viewport` (`SubViewport.new()`), `cycling_view` (a plain Control), `goals_panel`, and `log_window` (a real `log_window.tscn` instance so the block can be read). Assign `scene_root` on the state.
    - `test_cycling_mode_on_and_off`: on → techniques mode, the dock hidden, map input disabled; off → all three back.
    - `test_cycling_state_keeps_the_boards`: `enter()` leaves Goals and the log visible, shows `cycling_view` and blocks the full log; `exit()` reverses that.
    - `test_start_cycling_twice_pushes_once`: `_on_start_cycling(null)` twice; the state is on the stack once.
    - `test_a_disabled_map_viewport_takes_no_clicks`:
      - add a `SubViewport` holding a Node whose `_input` counts events;
      - set `gui_disable_input = true` and `push_input` a left press: the count is 0;
      - with it false, the count is 1.

      This pins the engine behaviour the map switch relies on. If it fails, the fallback is the container's `mouse_filter = IGNORE`: change `set_cycling_mode` and this test together.
  - **`test_view_state_hud_positions.gd`:**
    - `test_cycling_hides_the_boards` becomes `test_cycling_keeps_the_boards`. It uses the book helper, renamed `_assert_overlay_keeps_boards`.
    - In `test_overlay_restores_a_board_that_was_hidden` and `test_boards_stay_hidden_until_the_last_overlay_closes`, replace `CyclingViewState` with a `FakeCoveringState` fixture whose `enter()` calls `scene_root.hide_hud_boards(self)` and whose `exit()` calls `release_hud_boards(self)`.
    - Update the file's header comment.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, including the unique names in `main_game.tscn`.
- [ ] **Step 4: Run both files, then the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `feat(ui): open cycling in the map gap with the zone furniture up`.

### Task 17: Docs

**Skills:** none (docs only)

**Files:**
- `docs/cycling/CYCLING.md`: player experience, architecture (the new trees and signals), visual feedback, the Resources tab gone, Bugs (move fixed ones out), Work Remaining. Correct the two stale lines (the `equipped_technique_changed` listener; the cycling card's presenter).
- `docs/STYLE_GUIDE.md`: delete rows C1–C11 and the Cycling open questions C-Q1 to C-Q8; record G3's answer (tiers brass, cream, tan; pellets in the tier colours) and F6's partial promotion; update §13's counts table.
- `docs/zones/ZONES.md`: the chest's techniques mode, the cycling tray, NEW on the cycling card after an unlock, and the map's input while cycling.
- `docs/infrastructure/MAIN_VIEW.md`: cycling has no backdrop, keeps the HUD boards and blocks the full log; the dock hides; the new `MainView` references and `set_cycling_mode`.
- `docs/infrastructure/PERSISTENCE.md`: the two seen-technique fields.
- `docs/UI_STYLING.md`: the cycling pieces, `LacquerFloater`'s new home, and that it uses a 16 px `RichTextLacquer`, not `LabelLacquerFloater`.
- `docs/testing/TESTING.md`: the new test files in the coverage map; drop the stale "`GreyBackground` untested" line.
- `CLAUDE.md`: the View Architecture sentences on `CyclingViewState`, the HUD boards and `GreyBackground`; the cycling entry in Game Systems; the shader count (19 → 15) and list.
- `docs/superpowers/README.md`: a row for this spec and plan.
- The spec: an "As built" note listing any deviation.
- Also fix the comment at `scenes/zones/zone_transition/zone_transition.gd:4-7` that still mentions cycling.

- [ ] **Step 1: Make the edits.** Follow docs/README.md's rule: delete fixed items rather than striking them through.
- [ ] **Step 2: Check the links.** `grep -rn "cycling_resource_panel\|CyclingTabPanel\|FlyingParticle\|MapFloater" docs CLAUDE.md` leaves only historical specs and plans.
- [ ] **Step 3: Commit.** `docs(cycling): describe the lacquer cycling view`.

### Task 18: Full suite and visual check

**Skills:** `godot-prompter:godot-debugging`

- [ ] **Step 1: Run the full suite.** `"$GODOT" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`. Expected: no failing tests.
- [ ] **Step 2: Run the game at 1920x1080 and play it.** `"/c/Program Files (x86)/Godot/Godot_v4.7.2-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn`. Open Wilderness Cycling and play one Smooth Flow cycle: track the ball, click each zone, switch technique mid-cycle, toggle Auto, and close with Esc and with the ×. Confirm each of these:
  - **The board and furniture.** The board is in the map gap, the cabinet fills, and the chest lists the techniques. The dock is hidden, and a click on the visible map beside the board does nothing.
  - **The ball and groove.** The ball's clicks work through the board, and the groove lights blue behind the ball.
  - **Zones and pellets.** Zones show between cycles and keep their studs until the next start. Pellets fly into the cabinet's orbs.
  - **The text.** The result line and one log line appear per cycle, and the Now tray shows the cycle.
- [ ] **Step 3: Check a capture against the style guide.** Capture a 1920x1080 screenshot mid-cycle. Check it against the style guide §12 checklist and the mock (`#demo=1&t=9&bar=0` in the mock gives the same moment). Note any deviation in the spec's "As built" note.
- [ ] **Step 4: Commit any fixes the check needed**, one logical fix per commit.
