# Map Preview Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an editor-only `@tool` scene that previews adventure map generation directly inside the Godot 2D editor viewport.

**Architecture:** Standalone `.tscn` + `@tool` `.gd` at `scenes/tools/` + `scripts/tools/`. The tool instantiates `AdventureMapGenerator` against a child `HexagonTileMapLayer` and spawns `EncounterIcon` nodes for each non-NoOp tile. Two supporting refactors: factor the forest-atlas variant picker into a shared static helper (so both `AdventureTilemap` and `MapPreview` use it), and make `AdventureMapGenerator` `@tool`-safe by swapping its `Log.*` calls for `push_error` / `push_warning`.

**Tech Stack:** Godot 4.6, GDScript, `@tool`, `@export_tool_button` (Godot 4.4+), GUT 9.6.0 for unit tests, existing `HexagonTileMapLayer` addon (already `@tool`), existing `EncounterIcon.tscn`.

**Reference spec:** `docs/superpowers/specs/2026-04-23-map-preview-tool-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `scripts/utils/hex_forest_atlas.gd` | **new** | Static helper: deterministic `Vector3i` cube coord → `Vector2i` atlas cell. |
| `tests/unit/test_hex_forest_atlas.gd` | **new** | GUT unit tests for the helper. |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | **modified** | Remove local `_get_random_forest_atlas_coords` + constants; call `HexForestAtlas.pick(coord)` instead. |
| `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` | **modified** | Add `@tool`; swap `Log.error/warn/info` for `push_error` / `push_warning` / drop. |
| `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd` | **modified** | `is_eligible()` returns `true` at editor time (bypasses autoload-dependent `UnlockConditionData.evaluate()`). |
| `scripts/tools/map_preview.gd` | **new** | `@tool` script driving the preview: exports, generate button, render, clear. |
| `scenes/tools/map_preview.tscn` | **new** | Preview scene: `Node2D` root + `PreviewTileMap` + `EncounterIconContainer` + `OriginMarker` + `StatsLabel`. |

Directories to create: `scripts/tools/`, `scenes/tools/`. Both are new — no existing sibling conventions to match.

---

## Task 1: Extract `HexForestAtlas` static helper (TDD)

**Files:**
- Create: `scripts/utils/hex_forest_atlas.gd`
- Create: `tests/unit/test_hex_forest_atlas.gd`

The existing variant picker lives inside `AdventureTilemap` as a private method. Extracting it into a static helper lets the new preview tool reuse the same deterministic `coord → atlas cell` mapping without pulling in any scene dependencies. This task is a pure refactor and is fully unit-testable.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_hex_forest_atlas.gd`:

```gdscript
extends GutTest

## Unit tests for HexForestAtlas static helper.

const HEX_FOREST_ATLAS := preload("res://scripts/utils/hex_forest_atlas.gd")

func test_pick_is_deterministic_for_same_coord() -> void:
	var a: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(1, 2, -3))
	var b: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(1, 2, -3))
	assert_eq(a, b, "pick() must return the same cell for the same coord")

func test_pick_returns_cell_within_atlas_bounds() -> void:
	for q in range(-5, 6):
		for r in range(-5, 6):
			var cell: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(q, r, -q - r))
			assert_true(cell.x >= 0 and cell.x < HEX_FOREST_ATLAS.FOREST_ATLAS_COLS,
				"cell.x=%d out of range for coord (%d,%d)" % [cell.x, q, r])
			# 23 variants in a 6-wide grid → rows 0..3 (row 3 is partial: cols 0..4).
			assert_true(cell.y >= 0 and cell.y <= 3,
				"cell.y=%d out of range for coord (%d,%d)" % [cell.y, q, r])

func test_pick_distributes_across_multiple_variants() -> void:
	var uniques: Dictionary = {}
	for q in range(-5, 6):
		for r in range(-5, 6):
			var cell: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(q, r, -q - r))
			uniques[cell] = true
	assert_gt(uniques.size(), 5,
		"pick() should produce a reasonable spread, got only %d unique cells" % uniques.size())

func test_pick_index_stays_within_variant_count() -> void:
	# The underlying idx must be < FOREST_VARIANT_COUNT (23) for every coord.
	# We verify indirectly: any cell returned should be representable as
	# idx = cell.y * FOREST_ATLAS_COLS + cell.x, and idx < 23.
	for q in range(-10, 11):
		for r in range(-10, 11):
			var cell: Vector2i = HEX_FOREST_ATLAS.pick(Vector3i(q, r, -q - r))
			var idx: int = cell.y * HEX_FOREST_ATLAS.FOREST_ATLAS_COLS + cell.x
			assert_lt(idx, HEX_FOREST_ATLAS.FOREST_VARIANT_COUNT,
				"idx=%d exceeds FOREST_VARIANT_COUNT for coord (%d,%d)" % [idx, q, r])
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_hex_forest_atlas.gd -gexit
```

Expected: FAIL. Godot will report a parse error or "script not found" because `scripts/utils/hex_forest_atlas.gd` does not exist yet.

- [ ] **Step 3: Create the helper**

Create `scripts/utils/hex_forest_atlas.gd`:

```gdscript
class_name HexForestAtlas

## Deterministic variant picker for the shared hex forest atlas.
## Multiple Hex_Forest_NN variants are packed into a single
## TileSetAtlasSource backed by hex_forest_atlas.png. Both the in-game
## adventure tilemap and editor-only preview tools map a cube coord to
## the same atlas cell so the same tile always shows the same variant
## across re-renders, fog reveals, and adventure restarts.
##
## Keep FOREST_ATLAS_COLS and FOREST_VARIANT_COUNT in sync with
## ATLAS_COLS in pack_hex_atlas.py and the asset itself.

const FOREST_ATLAS_COLS: int = 6
const FOREST_VARIANT_COUNT: int = 23

## Returns the atlas (col, row) for the given cube coord. Hashes the
## coord, takes posmod by the variant count to handle negative hash
## values, then splits into (col, row) for the FOREST_ATLAS_COLS-wide
## grid.
static func pick(coord: Vector3i) -> Vector2i:
	var idx: int = posmod(hash(coord), FOREST_VARIANT_COUNT)
	@warning_ignore("integer_division")
	return Vector2i(idx % FOREST_ATLAS_COLS, idx / FOREST_ATLAS_COLS)
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_hex_forest_atlas.gd -gexit
```

Expected: 4 tests pass, 0 fail.

If you get a "class_name HexForestAtlas not recognized" error, run an import first:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
then rerun the test command.

- [ ] **Step 5: Switch `AdventureTilemap` to use the new helper**

Open `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`.

Remove these two lines from the constant block (around lines 44-45):

```gdscript
const FOREST_ATLAS_COLS := 6
const FOREST_VARIANT_COUNT := 23
```

Keep `const FOREST_ATLAS_SOURCE_ID := 8` — that's a TileSet source id, not an atlas layout constant.

Also update the surrounding comment block (around lines 37-42) — since the constants moved, the "Keep these constants in sync" line should point to the new location. Replace:

```gdscript
# Forest atlas (shared with ZoneTilemap). Multiple Hex_Forest_NN variants
# are packed into a single TileSetAtlasSource (sources/8) backed by
# hex_forest_atlas.png. Adventure tiles pick a deterministic-random cell
# per cube coord via _get_random_forest_atlas_coords() so the same tile
# always shows the same variant across re-renders. Keep these constants
# in sync with ZoneTilemap.FOREST_* and ATLAS_COLS in pack_hex_atlas.py.
const FOREST_ATLAS_SOURCE_ID := 8
const FOREST_ATLAS_COLS := 6
const FOREST_VARIANT_COUNT := 23
```

with:

```gdscript
# Forest atlas source id — variants are picked via HexForestAtlas.pick().
# Keep in sync with ZoneTilemap.FOREST_ATLAS_SOURCE_ID.
const FOREST_ATLAS_SOURCE_ID := 8
```

Delete the private helper (lines 682-691):

```gdscript
## Returns a deterministic forest atlas cell for the given cube coord.
## The same coord always returns the same variant, so the map looks
## consistent across re-renders, fog reveals, and adventure restarts
## (when the same map seed is used). Hashes the coord, takes posmod by
## the variant count to handle negative hash values, then splits into
## (col, row) for the FOREST_ATLAS_COLS-wide grid.
func _get_random_forest_atlas_coords(coord: Vector3i) -> Vector2i:
	var idx := posmod(hash(coord), FOREST_VARIANT_COUNT)
	@warning_ignore("integer_division")
	return Vector2i(idx % FOREST_ATLAS_COLS, idx / FOREST_ATLAS_COLS)
```

Update the one caller (line 733). Replace:

```gdscript
		visible_map.set_cell_with_source_and_variant(FOREST_ATLAS_SOURCE_ID, 0, full_map.cube_to_map(coord), _get_random_forest_atlas_coords(coord))
```

with:

```gdscript
		visible_map.set_cell_with_source_and_variant(FOREST_ATLAS_SOURCE_ID, 0, full_map.cube_to_map(coord), HexForestAtlas.pick(coord))
```

- [ ] **Step 6: Re-run the full unit + integration test suite**

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass, including the 4 new `test_hex_forest_atlas.gd` tests and the pre-existing `test_adventure_map_generator.gd` tests (unchanged behavior since the refactor doesn't alter output).

- [ ] **Step 7: Commit**

```bash
git add scripts/utils/hex_forest_atlas.gd tests/unit/test_hex_forest_atlas.gd scenes/adventure/adventure_tilemap/adventure_tilemap.gd
git commit -m "refactor(adventure): extract HexForestAtlas static helper

Moves the deterministic cube-coord → forest-atlas-cell mapping out of
AdventureTilemap into a shared static helper so editor-only preview
tools can reuse it without dragging in scene dependencies."
```

---

## Task 2: Make `AdventureMapGenerator` `@tool`-safe

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`

Current state: the generator calls `Log.error/warn/info` on error paths. `Log` is an autoload singleton that isn't instantiated at editor time, so running the generator in a `@tool` context would throw `"Invalid access to property or key 'error' on a base object of type 'Nil'"`. Fix: add `@tool` at the top of the file and swap logging to Godot built-ins that work in both contexts. No behavior change for the running game — pure logging swap. Existing tests do not assert on logging calls, so they continue to pass unchanged.

- [ ] **Step 1: Verify existing tests pass before the refactor**

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_adventure_map_generator.gd -gexit
```

Expected: all tests in `test_adventure_map_generator.gd` pass. Record the count (e.g. "9 passed, 0 failed") — you'll re-check this number after the refactor.

- [ ] **Step 2: Add `@tool` to the generator**

Open `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`. The current line 1 is `class_name AdventureMapGenerator`.

Prepend a line so the file starts with:

```gdscript
@tool
class_name AdventureMapGenerator
extends Node
```

- [ ] **Step 3: Replace `Log.error` calls with `push_error`**

Still in the same file. Find every `Log.error(` call and replace with `push_error(`. There are 4 of them:

Line ~34:
```gdscript
	if adventure_data == null:
		Log.error("AdventureMapGenerator: adventure_data is not set")
```
→
```gdscript
	if adventure_data == null:
		push_error("AdventureMapGenerator: adventure_data is not set")
```

Line ~37:
```gdscript
	if tile_map == null:
		Log.error("AdventureMapGenerator: tile_map is not set")
```
→
```gdscript
	if tile_map == null:
		push_error("AdventureMapGenerator: tile_map is not set")
```

Line ~43:
```gdscript
		for err in errors:
			Log.error("AdventureMapGenerator: %s" % err)
```
→
```gdscript
		for err in errors:
			push_error("AdventureMapGenerator: %s" % err)
```

Line ~59:
```gdscript
	Log.error("AdventureMapGenerator: exhausted regeneration attempts, returning best-effort map")
```
→
```gdscript
	push_error("AdventureMapGenerator: exhausted regeneration attempts, returning best-effort map")
```

- [ ] **Step 4: Replace `Log.warn` calls with `push_warning`**

Find every `Log.warn(` and replace with `push_warning(`. There are 3 of them:

Line ~57:
```gdscript
		Log.warn("AdventureMapGenerator: critical-path check failed, regenerating (attempt %d)" % (attempt + 1))
```
→
```gdscript
		push_warning("AdventureMapGenerator: critical-path check failed, regenerating (attempt %d)" % (attempt + 1))
```

Line ~93:
```gdscript
	Log.warn("AdventureMapGenerator: could not place anchor %s after %d attempts" % [encounter.encounter_id, MAX_PLACEMENT_ATTEMPTS])
```
→
```gdscript
	push_warning("AdventureMapGenerator: could not place anchor %s after %d attempts" % [encounter.encounter_id, MAX_PLACEMENT_ATTEMPTS])
```

Line ~114:
```gdscript
		Log.warn("AdventureMapGenerator: could not place boss %s" % boss.encounter_id)
```
→
```gdscript
		push_warning("AdventureMapGenerator: could not place boss %s" % boss.encounter_id)
```

Line ~208:
```gdscript
			Log.warn("AdventureMapGenerator: filler quota %s exceeds available NoOp tiles (placed %d of %d)" % [quota.encounter.encounter_id, placed, quota.count])
```
→
```gdscript
			push_warning("AdventureMapGenerator: filler quota %s exceeds available NoOp tiles (placed %d of %d)" % [quota.encounter.encounter_id, placed, quota.count])
```

- [ ] **Step 5: Remove `Log.info` calls**

`Log.info` is used for verbose informational "skipping encounter X — unlock_conditions not met" messages. These are not useful in the editor (spam) and not load-bearing for debugging (the generator's output already reflects the skip). Remove both.

Line ~73: delete this block:
```gdscript
		if not quota.encounter.is_eligible():
			Log.info("AdventureMapGenerator: skipping %s — unlock_conditions not met" % quota.encounter.encounter_id)
			continue
```
→
```gdscript
		if not quota.encounter.is_eligible():
			continue
```

Line ~202: delete this block:
```gdscript
		if not quota.encounter.is_eligible():
			Log.info("AdventureMapGenerator: skipping filler %s — unlock_conditions not met" % quota.encounter.encounter_id)
			continue
```
→
```gdscript
		if not quota.encounter.is_eligible():
			continue
```

- [ ] **Step 6: Confirm no `Log.` references remain in the file**

Use Grep:
```
Grep pattern "Log\." in scenes/adventure/adventure_tilemap/adventure_map_generator.gd
```

Expected: zero matches. If any remain, swap them using the same rules (`Log.error` → `push_error`, `Log.warn` → `push_warning`, `Log.info` → delete).

- [ ] **Step 7: Re-run the generator tests to verify no regressions**

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_adventure_map_generator.gd -gexit
```

Expected: same pass count as Step 1. If the count differs or any test fails, revert the changes and investigate — do not proceed to Task 3.

- [ ] **Step 8: Run the full suite**

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_map_generator.gd
git commit -m "refactor(adventure): make AdventureMapGenerator @tool-safe

Swaps Log.error/warn for push_error/push_warning and drops Log.info
spam, so the generator can run inside editor-only @tool scenes.
No behavior change for the running game."
```

---

## Task 3: Make `AdventureEncounter.is_eligible()` `@tool`-safe

**Files:**
- Modify: `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd`

The generator calls `encounter.is_eligible()` for every quota entry before placement. `is_eligible()` walks `unlock_conditions` and calls `UnlockConditionData.evaluate()`, which dispatches into autoloads (`CultivationManager`, `EventManager`, `InventoryManager`, `ResourceManager`, `CharacterManager`). At editor time those autoloads are not instantiated, so `evaluate()` throws on null access.

The `shallow_woods.tres` adventure contains a gated encounter (`refugee_camp_encounter`) with `unlock_conditions = {refugee_camp_map_owned: true, merchant_discovered: false}`. Previewing it at edit time will crash without this fix.

**Design choice:** at edit time, return `true` (treat every encounter as eligible). This is the semantically correct behavior for the preview — the designer wants to see the full potential map layout, not the subset visible to the current player state. Runtime behavior is unchanged.

GUT runs with `--headless`, not `--editor`, so `Engine.is_editor_hint()` is `false` during tests — existing tests cover the runtime branch and don't need modification. The edit-time branch is verified manually via Task 4's preview generation.

- [ ] **Step 1: Modify `is_eligible()`**

Open `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd` and replace the current `is_eligible()` function (around lines 91-95):

```gdscript
## Returns true when all unlock_conditions evaluate to their expected bool.
## Encounters with no unlock_conditions are always eligible.
func is_eligible() -> bool:
	for condition in unlock_conditions:
		if condition.evaluate() != unlock_conditions[condition]:
			return false
	return true
```

with:

```gdscript
## Returns true when all unlock_conditions evaluate to their expected bool.
## Encounters with no unlock_conditions are always eligible.
##
## At editor time (@tool context), returns true unconditionally —
## UnlockConditionData.evaluate() depends on autoloads that aren't
## instantiated in the editor. Preview tools want the full potential
## map anyway, not the subset visible to the current player state.
func is_eligible() -> bool:
	if Engine.is_editor_hint():
		return true
	for condition in unlock_conditions:
		if condition.evaluate() != unlock_conditions[condition]:
			return false
	return true
```

- [ ] **Step 2: Run the full test suite**

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass. `Engine.is_editor_hint()` is `false` in `--headless` GUT runs, so the runtime branch is exercised exactly as before.

- [ ] **Step 3: Commit**

```bash
git add scripts/resource_definitions/adventure/encounters/adventure_encounter.gd
git commit -m "refactor(adventure): guard is_eligible() at edit time

Returns true unconditionally inside @tool contexts so editor preview
tools can walk encounter quotas without accessing runtime autoloads
via UnlockConditionData.evaluate(). Runtime behavior unchanged."
```

---

## Task 4: Build the `MapPreview` `@tool` scene + script

**Files:**
- Create: `scripts/tools/map_preview.gd`
- Create: `scenes/tools/map_preview.tscn`

Tasks 1, 2, and 3 have made the foundation safe. Now we build the actual preview.

No automated tests in this task — `@tool` scenes are exercised by opening them in the editor and observing the viewport, which is not something GUT can drive. Verification is manual and scripted at the end of this task.

- [ ] **Step 1: Create `scripts/tools/map_preview.gd`**

Full content:

```gdscript
@tool
class_name MapPreview
extends Node2D

## Editor-only tool for previewing adventure map generation.
## Open scenes/tools/map_preview.tscn in the Godot editor, drop an
## AdventureData.tres into the adventure_data slot, then press the
## Generate button in the inspector. The generated map is rendered in
## the 2D editor viewport using the same forest tileset and encounter
## glyphs as the in-game adventure view.
##
## Seed = 0  → fresh random layout on each press.
## Seed != 0 → deterministic (same seed + same data = same map).

const ENCOUNTER_ICON_SCENE: PackedScene = preload("res://scenes/adventure/encounter_icon/encounter_icon.tscn")

# Forest tileset source id (matches AdventureTilemap.FOREST_ATLAS_SOURCE_ID).
const FOREST_ATLAS_SOURCE_ID: int = 8

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _preview_tile_map: HexagonTileMapLayer = %PreviewTileMap
@onready var _icon_container: Node2D = %EncounterIconContainer
# OriginMarker is a Node2D wrapper; its Label child renders the "START" text.
# Typing the ref as Node2D lets us assign `position` directly on the wrapper.
@onready var _origin_marker: Node2D = %OriginMarker
@onready var _stats_label: Label = %StatsLabel

#-----------------------------------------------------------------------------
# EXPORTS
#-----------------------------------------------------------------------------

## The adventure config to preview. Drag a .tres here.
@export var adventure_data: AdventureData

## 0 = random every press; non-zero = deterministic.
@export var seed_value: int = 0

@export_tool_button("Generate", "Play") var generate_button: Callable = _generate
@export_tool_button("Clear", "Remove") var clear_button: Callable = _clear

#-----------------------------------------------------------------------------
# GENERATE
#-----------------------------------------------------------------------------

func _generate() -> void:
	if not Engine.is_editor_hint():
		return
	if adventure_data == null:
		push_warning("MapPreview: no adventure_data set")
		return

	var errors: Array[String] = adventure_data.validate()
	if errors.size() > 0:
		for err in errors:
			push_error("MapPreview: %s" % err)
		return

	if seed_value == 0:
		randomize()
	else:
		seed(seed_value)

	var generator := AdventureMapGenerator.new()
	generator.set_adventure_data(adventure_data)
	generator.set_tile_map(_preview_tile_map)
	var tiles: Dictionary[Vector3i, AdventureEncounter] = generator.generate_adventure_map()

	if tiles.is_empty():
		push_warning("MapPreview: generator returned empty map")
		return

	_render(tiles)
	_update_stats_label(tiles)

#-----------------------------------------------------------------------------
# CLEAR
#-----------------------------------------------------------------------------

func _clear() -> void:
	if not Engine.is_editor_hint():
		return
	_preview_tile_map.clear()
	for child in _icon_container.get_children():
		child.queue_free()
	_origin_marker.visible = false
	_stats_label.text = ""

#-----------------------------------------------------------------------------
# RENDER
#-----------------------------------------------------------------------------

func _render(tiles: Dictionary[Vector3i, AdventureEncounter]) -> void:
	# Clear previous frame
	_preview_tile_map.clear()
	for child in _icon_container.get_children():
		child.queue_free()

	# Paint base tiles
	for coord in tiles.keys():
		_preview_tile_map.set_cell_with_source_and_variant(
			FOREST_ATLAS_SOURCE_ID,
			0,
			_preview_tile_map.cube_to_map(coord),
			HexForestAtlas.pick(coord),
		)

	# Show origin marker at Vector2.ZERO (which is cube_to_local(Vector3i.ZERO)
	# for a correctly-configured HexagonTileMapLayer at position 0,0).
	_origin_marker.position = _preview_tile_map.cube_to_local(Vector3i.ZERO)
	_origin_marker.visible = true

	# Spawn encounter icons for every non-NoOp tile
	for coord in tiles.keys():
		var encounter: AdventureEncounter = tiles[coord]
		if encounter is NoOpEncounter:
			continue
		if encounter.encounter_type == AdventureEncounter.EncounterType.NONE:
			continue
		var icon: EncounterIcon = ENCOUNTER_ICON_SCENE.instantiate()
		_icon_container.add_child(icon)
		icon.position = _preview_tile_map.cube_to_local(coord)
		# EncounterIcon has @onready node refs — in @tool context, call after
		# add_child so _ready has fired. configure_for_type() is the public
		# entry point used by AdventureTilemap.
		icon.configure_for_type(encounter.encounter_type)

#-----------------------------------------------------------------------------
# STATS
#-----------------------------------------------------------------------------

func _update_stats_label(tiles: Dictionary[Vector3i, AdventureEncounter]) -> void:
	var total: int = tiles.size()
	var counts: Dictionary[String, int] = {
		"combat": 0,
		"elite": 0,
		"boss": 0,
		"rest": 0,
		"treasure": 0,
		"trap": 0,
		"noop": 0,
	}
	for coord in tiles.keys():
		var enc: AdventureEncounter = tiles[coord]
		if enc is NoOpEncounter:
			counts["noop"] += 1
			continue
		match enc.encounter_type:
			AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
				counts["combat"] += 1
			AdventureEncounter.EncounterType.COMBAT_ELITE:
				counts["elite"] += 1
			AdventureEncounter.EncounterType.COMBAT_BOSS:
				counts["boss"] += 1
			AdventureEncounter.EncounterType.REST_SITE:
				counts["rest"] += 1
			AdventureEncounter.EncounterType.TREASURE:
				counts["treasure"] += 1
			AdventureEncounter.EncounterType.TRAP:
				counts["trap"] += 1

	_stats_label.text = "%d tiles · %d combat · %d elite · %d boss · %d rest · %d treasure · %d trap · %d walk · seed: %d" % [
		total,
		counts["combat"],
		counts["elite"],
		counts["boss"],
		counts["rest"],
		counts["treasure"],
		counts["trap"],
		counts["noop"],
		seed_value,
	]
```

- [ ] **Step 2: Create the preview scene**

Create `scenes/tools/map_preview.tscn` via the editor (do not hand-write the `.tscn` — UIDs need to be real). Procedure:

1. Open Godot editor.
2. File → New Scene → Other Node → `Node2D`. Rename root to `MapPreview`.
3. In the Inspector, attach the new script `res://scripts/tools/map_preview.gd`. (Godot will detect `@tool` and run it.)
4. Add child nodes:
   - Instance `res://scenes/tilemaps/hexagon_tile_map_layer.tscn` as child. Rename it `PreviewTileMap`. In Inspector → Node tab, enable "Access as Unique Name" (`%PreviewTileMap`).
   - Add child `Node2D`, name it `EncounterIconContainer`, enable unique access. Set `z_index = 6` (so icons paint over tiles).
   - Add child `Node2D`, name it `OriginMarker`, enable unique access. Set `visible = false` (the script toggles it on after generation). `Node2D` is required because the script assigns `position` on this node — `Label` extends `Control`, not `Node2D`, so a bare `Label` here would fail the `@onready var _origin_marker: Node2D = %OriginMarker` assignment at scene load. Under `OriginMarker`, add a `Label` child (just `Label`, not unique — `unique_name_in_owner` stays on the Node2D parent). On the Label child, set `text = "START"`, `offset_left = -30.0`, `offset_top = -12.0` (so the label sits visually over the origin hex), and `theme_override_colors/font_color = Color(1, 0.9, 0.3)` (gold).
   - Add a `CanvasLayer` child named `UiLayer` with `layer = 1`.
     - Inside it, add a `Label` named `StatsLabel`. Enable unique access. Set `offset_left = 16`, `offset_top = 16`, `text = ""`, `theme_override_colors/font_color = Color(1, 1, 1)`. This keeps the stats readable over tiles regardless of camera zoom.
5. File → Save Scene → `res://scenes/tools/map_preview.tscn`.

The resulting tree should look like:

```
MapPreview (Node2D, script = map_preview.gd)
├── PreviewTileMap (HexagonTileMapLayer, instanced, unique)
├── EncounterIconContainer (Node2D, unique, z_index=6)
├── OriginMarker (Node2D, unique, visible=false)
│   └── Label (text="START", offset (-30, -12), gold)
└── UiLayer (CanvasLayer, layer=1)
    └── StatsLabel (Label, unique, anchored top-left)
```

- [ ] **Step 3: Smoke test — open the scene**

With `scenes/tools/map_preview.tscn` open in the editor, confirm:
- No errors in the Output panel.
- The Inspector shows `Adventure Data`, `Seed Value` (int, default 0), a `Generate` button, and a `Clear` button.

If you see `"Cannot access 'HexForestAtlas'"` or similar, re-import the project:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

- [ ] **Step 4: Manual verification — generate Shallow Woods**

Steps the user performs in-editor:

1. Drag `res://resources/adventure/data/shallow_woods.tres` into the `Adventure Data` slot in the Inspector.
2. Leave `Seed Value = 0`.
3. Press **Generate** in the Inspector.
4. Confirm in the 2D viewport:
   - A cluster of hex tiles renders with varied forest textures.
   - A gold "START" label appears at the origin hex.
   - One boss icon appears at the farthest tile (animated skull).
   - Two rest icons appear (aura well + refugee camp).
   - Multiple combat icons appear on the path tiles.
5. Confirm the `StatsLabel` overlay shows a reasonable line, e.g.:
   `"15 tiles · 7 combat · 0 elite · 1 boss · 2 rest · 0 treasure · 0 trap · 5 walk · seed: 0"`

- [ ] **Step 5: Manual verification — seed reproducibility**

1. Set `Seed Value = 42`, press **Generate**. Note the layout (take a screenshot or eyeball the anchor positions).
2. Press **Generate** again with the same seed. Confirm the layout is **identical**.
3. Change the seed to `43`, press **Generate**. Confirm the layout differs.
4. Set the seed back to `0`, press **Generate** twice. Confirm each press produces a **different** layout.

- [ ] **Step 6: Manual verification — Clear button**

1. Press **Clear**.
2. Confirm: tilemap goes empty, all encounter icons disappear, "START" label hides, stats label goes blank.

- [ ] **Step 7: Manual verification — empty / invalid data paths**

1. Clear the `Adventure Data` slot (right-click → clear, or set to <null>).
2. Press **Generate**. Confirm a `push_warning("MapPreview: no adventure_data set")` message appears in the Output panel and no tiles are drawn.
3. Create a broken AdventureData: duplicate `shallow_woods.tres` to a scratch copy, open it, delete the `boss_encounter` field. Drop it in the slot.
4. Press **Generate**. Confirm `push_error` messages appear in Output listing the validation failures (e.g. "boss_encounter is not set") and no tiles are drawn.
5. Delete the scratch copy.

- [ ] **Step 8: Icon-rendering check (risk from spec)**

The spec flagged a risk: `EncounterIcon` is not `@tool` and may mis-render in edit-time context, particularly the boss's animated spritesheet. In the generated Shallow Woods map:

1. Observe the boss icon. If it renders as an animated skull cycling through 7 frames, you're done — no action needed.
2. If the boss icon renders as a single static frame (frame 0 only), that's acceptable — the preview still communicates "boss is here" clearly. No action needed.
3. If the boss icon fails to render at all (missing texture, invisible, or spew of errors), add `@tool` to the top of `scenes/adventure/encounter_icon/encounter_icon.gd` and re-test. Do not take this step unless the icon is actually broken — adding `@tool` to a runtime script has real risk of breaking the running game.

- [ ] **Step 9: Full test suite regression check**

Nothing in Task 3 should affect runtime behavior, but sanity-check anyway.

Run:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass.

- [ ] **Step 10: In-game smoke test**

Launch the game and play through a Shallow Woods adventure. Confirm:
- Adventure map still generates correctly at runtime.
- Encounter icons still render with animations (boss breathing).
- No new errors or warnings in the Output panel on adventure start.

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Navigate to Spirit Valley → trigger q_fill_core_completed → start Shallow Woods adventure. Walk one tile. Verify visuals match pre-refactor behavior.

- [ ] **Step 11: Commit**

```bash
git add scripts/tools/map_preview.gd scenes/tools/map_preview.tscn
git commit -m "feat(tools): add map preview @tool scene

Editor-only @tool scene that renders AdventureMapGenerator output
in the 2D editor viewport. Drop an AdventureData.tres in the
inspector, press Generate, see the full map with encounter icons.
Supports deterministic replay via a seed field."
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| G1: drop .tres, press button, see map | Task 4 Step 4 |
| G2: deterministic seed | Task 4 Step 1 (seed logic), Step 5 (verification) |
| G3: visual fidelity via real tileset + icons | Task 4 Step 1 (PreviewTileMap + EncounterIcon), Step 4 (verify visuals) |
| G4: zero impact on shipping game | Task 2 (pure logging swap), Task 3 (edit-time guard only), Task 4 Step 9 (regression), Step 10 (in-game smoke) |
| G5: structured for future option-B overlays | Scene has dedicated `EncounterIconContainer`; additional containers (MST edges, distance labels) can slot in alongside without touching `_generate`. Noted in spec; no task needed in this plan. |
| NG1-NG5: non-goals | None require tasks by definition. |
| `@tool`-safety refactor of generator | Task 2 |
| `@tool`-safety of is_eligible() dependency chain | Task 3 |
| Factor `HexForestAtlas` | Task 1 |
| `OriginMarker` | Task 4 Step 2 (scene), Step 1 (script sets position + visibility) |
| Stats label | Task 4 Step 1 (`_update_stats_label`), Step 4 (verify string) |
| Manual verification loop | Task 4 Steps 4-7 |
| Risk: `EncounterIcon` edit-time rendering | Task 4 Step 8 |

**Placeholder scan:** No `TBD` / `TODO` / `handle edge cases` / `similar to` in the plan.

**Type consistency:** `HexForestAtlas.pick(coord)` signature is used identically in Task 1 helper, Task 1 Step 5 caller, and Task 3 script. `AdventureMapGenerator.set_adventure_data` / `set_tile_map` / `generate_adventure_map` match the existing generator API verified in source. `EncounterIcon.configure_for_type(int)` matches the existing public method verified at `encounter_icon.gd:51`.

**Gaps:** None identified.
