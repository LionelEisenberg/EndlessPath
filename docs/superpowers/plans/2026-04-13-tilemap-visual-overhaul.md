# Tilemap Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Layer atmosphere (vignette, mist, spirit motes), tile-state clarity, and dramatic encounter icon presentation onto both `ZoneTilemap` and `AdventureTilemap` without changing data structures or pathfinding.

**Architecture:** Two new packed scenes (`ZoneAtmosphere`, `AdventureAtmosphere`) drop a vignette ColorRect, a mist Node2D, and GPUParticles2D mote emitters into each view. A new `TileStateOverlay` Node2D pools `Sprite2D` overlays per cube coordinate to render the 5 tile states (hidden / reveal / visited / current / hover-target). A new `EncounterIcon` packed scene replaces the hardcoded source-id overlay logic in `_update_cell_highlight()` with type-configured glyph + frame instances. A `FogOfWar` shader darkens unexplored regions, a `PathPreview` Line2D shows hover pathfinding, and dramatic moments (boss reveal, zone unlock) get hit-stop + screen flash + camera push.

**Tech Stack:** Godot 4.6, GDScript, GUT 9.6.0, custom canvas_item shaders, GPUParticles2D, Tween animations.

**Spec:** `docs/superpowers/specs/2026-04-13-tilemap-visual-overhaul-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `assets/shaders/vignette.gdshader` | Create | Radial gradient darkening shader |
| `assets/shaders/fog_of_war.gdshader` | Create | Per-position reveal mask shader |
| `assets/shaders/tile_aura.gdshader` | Create | Soft full-body glow shader for current tile |
| `assets/shaders/flowing_path.gdshader` | Create | Animated gradient stroke for path preview |
| `assets/sprites/adventure/encounter_glyphs/combat.png` | Create | Crossed blades glyph (32×32) |
| `assets/sprites/adventure/encounter_glyphs/elite.png` | Create | Four-point star glyph (32×32) |
| `assets/sprites/adventure/encounter_glyphs/boss.png` | Create | Ornamental sigil glyph (48×48) |
| `assets/sprites/adventure/encounter_glyphs/rest.png` | Create | Shrine glyph (32×32) |
| `assets/sprites/adventure/encounter_glyphs/treasure.png` | Create | Diamond/gem glyph (32×32) |
| `assets/sprites/adventure/encounter_glyphs/trap.png` | Create | Warning glyph (32×32) |
| `assets/sprites/adventure/encounter_glyphs/unknown.png` | Create | Question mark glyph (32×32) |
| `assets/sprites/atmosphere/mote_particle.png` | Create | 4×4 white circle for spirit mote particles |
| `assets/sprites/atmosphere/mist_blob.png` | Create | 256×256 soft white blob, 50% alpha |
| `assets/sprites/atmosphere/aura_glow.png` | Create | 256×256 soft radial gradient |
| `scenes/atmosphere/zone_atmosphere.tscn` | Create | CanvasLayer with vignette + mist + motes |
| `scenes/atmosphere/zone_atmosphere.gd` | Create | Mist drift Tween manager |
| `scenes/atmosphere/adventure_atmosphere.tscn` | Create | Same shape as zone_atmosphere |
| `scenes/atmosphere/adventure_atmosphere.gd` | Create | Mist drift Tween manager |
| `scenes/adventure/tile_state_overlay/tile_state_overlay.tscn` | Create | Node2D root for overlay sprite pool |
| `scenes/adventure/tile_state_overlay/tile_state_overlay.gd` | Create | Pool, transition, and free overlay sprites by cube coordinate |
| `scenes/adventure/encounter_icon/encounter_icon.tscn` | Create | Sprite2D + frame + optional ornamental ring + sparkle particles |
| `scenes/adventure/encounter_icon/encounter_icon.gd` | Create | `configure_for_type(encounter_type)` applies glyph, color, frame, effects |
| `scenes/adventure/path_preview/path_preview.tscn` | Create | Line2D with flowing_path shader material |
| `scenes/adventure/path_preview/path_preview.gd` | Create | `update_path(from_cube, to_cube)` |
| `scenes/zones/glowing_path/glowing_path.tscn` | Create | Line2D with flowing_path shader material |
| `scenes/zones/glowing_path/glowing_path.gd` | Create | Connect two zone world positions with a glowing line |
| `scenes/zones/locked_zone_glyph/locked_zone_glyph.tscn` | Create | Label "?" glyph centered on hex |
| `tests/unit/test_tile_state_overlay.gd` | Create | GUT tests for overlay pool/transition/clear |
| `tests/unit/test_encounter_icon_config.gd` | Create | GUT tests for `configure_for_type()` |
| `scenes/tilemaps/hexagon_tile_map_layer.gd` | Modify | Add `tile_hovered(coord)` signal driven by MOUSE_MOTION |
| `scenes/zones/zone_tilemap/zone_tilemap.gd` | Modify | Hover handler, current-zone aura, eased camera tween, glowing path generation, locked glyph instantiation |
| `scenes/zones/zone_tilemap/zone_tilemap.tscn` | Modify | Add ZoneAtmosphere child, AuraSprite child, GlowingPathContainer Node2D, LockedGlyphContainer Node2D |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | Modify | Replace `_update_visible_map()` PulseNode spawning with TileStateOverlay; replace `_update_cell_highlight()` with EncounterIcon instancing; add fog uniform updates; add reveal stagger; add boss-reveal dramatic moment; wire path preview |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn` | Modify | Add AdventureAtmosphere, TileStateOverlay, PathPreview, FogOfWarRect, EncounterIconContainer children |
| `assets/themes/pixel_theme.tres` | Modify | Add `PanelStamina` stylebox, `LockedGlyph` Label variant |
| `scenes/adventure/adventure_view/adventure_view.tscn` | Modify | Apply PanelStamina theme variant to existing stamina display |

---

### Task 1: Create the vignette shader

**Files:**
- Create: `assets/shaders/vignette.gdshader`

- [ ] **Step 1: Write the shader file**

Create `assets/shaders/vignette.gdshader` with:

```glsl
shader_type canvas_item;

// How far from screen center the vignette starts (0.0 = center, 1.0 = corner)
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.55;

// How soft the falloff is (higher = softer edge)
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.4;

// Color the edges fade to (default near-black with slight blue tint)
uniform vec4 vignette_color : source_color = vec4(0.0, 0.01, 0.04, 1.0);

void fragment() {
	// Distance from center (0,0) to corner (~0.707) in UV space
	float dist = distance(SCREEN_UV, vec2(0.5));

	// Map dist into 0 (clear) → 1 (full vignette) using radius and softness
	float mask = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);

	// Blend toward vignette color by mask
	COLOR = vec4(vignette_color.rgb, vignette_color.a * mask);
}
```

- [ ] **Step 2: Verify shader parses by opening the project**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: no shader compile errors in stderr (warnings about `.import` regeneration are fine).

- [ ] **Step 3: Commit**

```bash
git add assets/shaders/vignette.gdshader
git commit -m "feat(ui): add vignette canvas_item shader for tilemap atmosphere"
```

---

### Task 2: Create atmosphere art assets

**Files:**
- Create: `assets/sprites/atmosphere/mote_particle.png`
- Create: `assets/sprites/atmosphere/mist_blob.png`
- Create: `assets/sprites/atmosphere/aura_glow.png`

- [ ] **Step 1: Create the asset directory and three placeholder PNGs**

These three PNGs are simple primitives that can be authored in any image editor (Aseprite preferred since it's already in use, GIMP also installed). Required specs:

| File | Size | Content |
|------|------|---------|
| `mote_particle.png` | 4×4 | Solid white circle, soft 1-pixel edge falloff, transparent background |
| `mist_blob.png` | 256×256 | Pure white radial gradient from full-opaque center to fully transparent edge, no hard edge |
| `aura_glow.png` | 256×256 | Same as mist_blob but slightly tighter falloff (use radial gradient with center alpha 1.0 → edge alpha 0.0, gamma 1.5) |

Use `gimp` from the command line if doing this scriptably (verify with `gimp --version`). All three are pure white — they get tinted at runtime via `Sprite2D.modulate` and `GPUParticles2D` color ramps.

After creating, place them at:
- `assets/sprites/atmosphere/mote_particle.png`
- `assets/sprites/atmosphere/mist_blob.png`
- `assets/sprites/atmosphere/aura_glow.png`

- [ ] **Step 2: Re-import to register UIDs**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: three new `.import` files generated alongside the PNGs.

- [ ] **Step 3: Commit**

```bash
git add assets/sprites/atmosphere/
git commit -m "feat(ui): add atmosphere primitive sprites (mote, mist, aura glow)"
```

---

### Task 3: Create the ZoneAtmosphere packed scene and script

**Files:**
- Create: `scenes/atmosphere/zone_atmosphere.gd`
- Create: `scenes/atmosphere/zone_atmosphere.tscn`

- [ ] **Step 1: Write the script**

Create `scenes/atmosphere/zone_atmosphere.gd`:

```gdscript
class_name ZoneAtmosphere
extends CanvasLayer

## ZoneAtmosphere
## Drops vignette + drifting mist + spirit motes onto a view.
## Drop this scene as a child of a Node2D root (e.g. ZoneTilemap or AdventureTilemap).

@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC

const MIST_DRIFT_RANGE := Vector2(60, 40)
const MIST_DRIFT_DURATION := 14.0

func _ready() -> void:
	_start_mist_drift(_mist_a, 0.0)
	_start_mist_drift(_mist_b, MIST_DRIFT_DURATION * 0.33)
	_start_mist_drift(_mist_c, MIST_DRIFT_DURATION * 0.66)

func _start_mist_drift(mist: Sprite2D, delay: float) -> void:
	if not mist:
		return
	var origin := mist.position
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(mist, "position", origin + MIST_DRIFT_RANGE, MIST_DRIFT_DURATION * 0.5)
	tween.tween_property(mist, "position", origin, MIST_DRIFT_DURATION * 0.5)
```

- [ ] **Step 2: Build the scene in the Godot editor**

Open the project in the Godot editor and create a new scene at `scenes/atmosphere/zone_atmosphere.tscn` with this node tree. Save with `Ctrl+S` so UIDs are generated automatically.

```
ZoneAtmosphere (CanvasLayer, layer = 5)
├── MistContainer (Node2D)
│   ├── MistA (Sprite2D) — texture: mist_blob.png, modulate: Color(0.59, 0.71, 0.90, 0.18), scale: 4, position: (-200, 100), unique_name_in_owner: true
│   ├── MistB (Sprite2D) — texture: mist_blob.png, modulate: Color(0.45, 0.55, 0.78, 0.16), scale: 5, position: (400, 300), unique_name_in_owner: true
│   └── MistC (Sprite2D) — texture: mist_blob.png, modulate: Color(0.62, 0.50, 0.78, 0.14), scale: 4.5, position: (1200, 500), unique_name_in_owner: true
├── MoteParticlesCyan (GPUParticles2D)
│   - amount: 30, lifetime: 3.5, preprocess: 3.5, explosiveness: 0.0, randomness: 0.5
│   - texture: mote_particle.png
│   - process_material: ParticleProcessMaterial — emission_shape: Box, emission_box_extents: (1100, 700, 1)
│       - direction: (0, -1), spread: 180, gravity: (0, -3)
│       - initial_velocity_min: 4, initial_velocity_max: 14
│       - scale_min: 0.6, scale_max: 1.4
│       - color: Color(0.75, 0.86, 1.0, 0.85)
│       - alpha_curve: bell-shaped Curve (0.0 → 0, 0.5 → 1, 1.0 → 0)
├── MoteParticlesWarm (GPUParticles2D) — duplicate of cyan, change:
│       - color: Color(1.0, 0.85, 0.45, 0.85)
│       - amount: 12 (warm motes are rarer)
└── VignetteRect (ColorRect)
    - layout: anchors full rect (preset Full Rect)
    - color: Color(1, 1, 1, 1)
    - material: new ShaderMaterial → shader: vignette.gdshader
    - shader_parameter/vignette_radius: 0.55
    - shader_parameter/vignette_softness: 0.4
    - shader_parameter/vignette_color: Color(0.0, 0.01, 0.04, 1.0)
```

Attach the script `scenes/atmosphere/zone_atmosphere.gd` to the root `ZoneAtmosphere` node. Save the scene.

- [ ] **Step 3: Verify the scene parses**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
Expected: scene imports cleanly, no errors.

- [ ] **Step 4: Commit**

```bash
git add scenes/atmosphere/zone_atmosphere.gd scenes/atmosphere/zone_atmosphere.tscn
git commit -m "feat(ui): add ZoneAtmosphere scene (vignette + mist + motes)"
```

---

### Task 4: Add ZoneAtmosphere to the zone tilemap scene

**Files:**
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.tscn`

- [ ] **Step 1: Open zone_tilemap.tscn in the Godot editor**

Open `scenes/zones/zone_tilemap/zone_tilemap.tscn`.

- [ ] **Step 2: Instance ZoneAtmosphere as a child of the root**

Right-click the `ZoneTilemap` root → Instantiate Child Scene → pick `scenes/atmosphere/zone_atmosphere.tscn`. The ZoneAtmosphere should appear as a child of the root node. Save with `Ctrl+S`.

- [ ] **Step 3: Smoke-test by running the game**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```
Expected: zone view loads with visible vignette darkening at edges, mist sprites slowly drifting, cyan/warm spirit motes drifting across the screen. No errors in console.

- [ ] **Step 4: Commit**

```bash
git add scenes/zones/zone_tilemap/zone_tilemap.tscn
git commit -m "feat(ui): add ZoneAtmosphere to zone tilemap scene"
```

---

### Task 5: Create AdventureAtmosphere and add it to the adventure tilemap

**Files:**
- Create: `scenes/atmosphere/adventure_atmosphere.gd`
- Create: `scenes/atmosphere/adventure_atmosphere.tscn`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`

- [ ] **Step 1: Write the script**

Create `scenes/atmosphere/adventure_atmosphere.gd`:

```gdscript
class_name AdventureAtmosphere
extends CanvasLayer

## AdventureAtmosphere
## Same as ZoneAtmosphere but tuned for adventure view: slightly tighter
## vignette, fewer mist sprites, motes weighted toward cyan.

@onready var _mist_a: Sprite2D = %MistA
@onready var _mist_b: Sprite2D = %MistB
@onready var _mist_c: Sprite2D = %MistC

const MIST_DRIFT_RANGE := Vector2(50, 30)
const MIST_DRIFT_DURATION := 12.0

func _ready() -> void:
	_start_mist_drift(_mist_a, 0.0)
	_start_mist_drift(_mist_b, MIST_DRIFT_DURATION * 0.4)
	_start_mist_drift(_mist_c, MIST_DRIFT_DURATION * 0.7)

func _start_mist_drift(mist: Sprite2D, delay: float) -> void:
	if not mist:
		return
	var origin := mist.position
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(mist, "position", origin + MIST_DRIFT_RANGE, MIST_DRIFT_DURATION * 0.5)
	tween.tween_property(mist, "position", origin, MIST_DRIFT_DURATION * 0.5)
```

- [ ] **Step 2: Build adventure_atmosphere.tscn in the editor**

Identical structure to `zone_atmosphere.tscn` but with these tweaks on the VignetteRect:
- `vignette_radius`: 0.5 (tighter — more darkness)
- `vignette_softness`: 0.35
- `vignette_color`: Color(0.0, 0.005, 0.025, 1.0) (slightly darker)

And on the particles:
- `MoteParticlesCyan` amount: 25
- `MoteParticlesWarm` amount: 8

Attach `scenes/atmosphere/adventure_atmosphere.gd`. Save as `scenes/atmosphere/adventure_atmosphere.tscn`.

- [ ] **Step 3: Instance AdventureAtmosphere into adventure_tilemap.tscn**

Open `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`. Right-click the `AdventureTilemap` root → Instantiate Child Scene → `scenes/atmosphere/adventure_atmosphere.tscn`. Save.

- [ ] **Step 4: Smoke-test**

Launch the game, start an adventure (use Spirit Valley → adventure action), and verify the adventure view has vignette + mist + motes. Existing fog/encounter visuals should still work as before.

- [ ] **Step 5: Commit**

```bash
git add scenes/atmosphere/adventure_atmosphere.gd \
  scenes/atmosphere/adventure_atmosphere.tscn \
  scenes/adventure/adventure_tilemap/adventure_tilemap.tscn
git commit -m "feat(ui): add AdventureAtmosphere to adventure tilemap scene"
```

---

### Task 6: Add `tile_hovered` signal to the hexagon tile map wrapper

**Files:**
- Modify: `scenes/tilemaps/hexagon_tile_map_layer.gd`

- [ ] **Step 1: Add the signal and motion handler**

Replace the existing `_input` function in `scenes/tilemaps/hexagon_tile_map_layer.gd`:

```gdscript
@tool
extends HexagonTileMapLayer

signal tile_clicked(tile_coord: Vector2i)
signal tile_hovered(tile_coord: Vector2i)
signal tile_unhovered()

const HEX_TILE_OFFSET: Vector2 = Vector2(-82, -95)

var _last_hovered_coord: Vector2i = Vector2i(-9999, -9999)

func set_cell_with_source_and_variant(source_id : int, variant_id: int, cell_coords: Vector2) -> void:
	set_cell(cell_coords, source_id, Vector2i(0, 0), variant_id)
	_draw_debug()
	pathfinding_generate_points()

func _ready() -> void:
	if position != HEX_TILE_OFFSET:
		Log.warn("HexagonalTileMapLayer: TileMapLayer is not in the right position, it won't look right!")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile_coord := local_to_map(get_local_mouse_position())
		if get_cell_source_id(tile_coord) != -1:
			tile_clicked.emit(tile_coord)
	elif event is InputEventMouseMotion:
		var tile_coord := local_to_map(get_local_mouse_position())
		if get_cell_source_id(tile_coord) != -1:
			if tile_coord != _last_hovered_coord:
				_last_hovered_coord = tile_coord
				tile_hovered.emit(tile_coord)
		else:
			if _last_hovered_coord != Vector2i(-9999, -9999):
				_last_hovered_coord = Vector2i(-9999, -9999)
				tile_unhovered.emit()

func cube_pathfind(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var from_id := pathfinding_get_point_id(cube_to_map(from))
	var to_id := pathfinding_get_point_id(cube_to_map(to))

	var path := astar.get_id_path(from_id, to_id)
	var cube_path : Array[Vector3i] = []

	for point_id in path:
		cube_path.append(local_to_cube(astar.get_point_position(point_id)))

	return cube_path
```

- [ ] **Step 2: Smoke-test with a temporary print listener**

Temporarily add this in `zone_tilemap.gd::_ready()` after the `tile_clicked` connection:
```gdscript
tile_map.tile_hovered.connect(func(c): Log.info("HOVER: %s" % c))
```
Run the game, hover the zone tiles, watch the log. Remove the temporary line after verification.

- [ ] **Step 3: Commit**

```bash
git add scenes/tilemaps/hexagon_tile_map_layer.gd
git commit -m "feat(ui): emit tile_hovered/tile_unhovered from HexagonTileMapLayer"
```

---

### Task 7: Add hover glow to zone tiles

**Files:**
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd`
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.tscn`

- [ ] **Step 1: Add a HoverSprite child to zone_tilemap.tscn**

Open `scenes/zones/zone_tilemap/zone_tilemap.tscn` in the editor.

Add a new child of the root `ZoneTilemap`:
- `HoverSprite` (Sprite2D)
  - texture: `assets/sprites/atmosphere/aura_glow.png`
  - modulate: `Color(0.55, 0.78, 1.0, 0.55)`
  - scale: `Vector2(0.55, 0.55)`
  - z_index: 5
  - visible: false (starts hidden)
  - unique_name_in_owner: true

Save the scene.

- [ ] **Step 2: Add hover handler to zone_tilemap.gd**

In `scenes/zones/zone_tilemap/zone_tilemap.gd`, add `%HoverSprite` to the `@onready` declarations near the top:

```gdscript
@onready var _hover_sprite: Sprite2D = %HoverSprite
```

In `_ready()`, after the existing `tile_clicked.connect(_on_zone_tile_clicked)` line, add:

```gdscript
tile_map.tile_hovered.connect(_on_zone_tile_hovered)
tile_map.tile_unhovered.connect(_on_zone_tile_unhovered)
```

Add these new private functions to the file (in the SIGNAL HANDLERS section near the bottom):

```gdscript
func _on_zone_tile_hovered(tile_coord: Vector2i) -> void:
	var zone_data := get_zone_at_tile(tile_coord)
	if not zone_data:
		_hover_sprite.visible = false
		return
	if not UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
		_hover_sprite.visible = false
		return
	if zone_data == selected_zone:
		_hover_sprite.visible = false
		return
	_hover_sprite.global_position = tile_map.map_to_local(tile_coord) + tile_map.position
	_hover_sprite.visible = true

func _on_zone_tile_unhovered() -> void:
	_hover_sprite.visible = false
```

- [ ] **Step 3: Smoke-test hover glow**

Run the game. Mouse over an unlocked zone tile — a soft cyan glow sprite should appear under the tile. Mouse over the selected zone or a locked zone — the glow should not appear. Mouse off the tilemap — the glow should disappear.

- [ ] **Step 4: Commit**

```bash
git add scenes/zones/zone_tilemap/zone_tilemap.gd \
  scenes/zones/zone_tilemap/zone_tilemap.tscn
git commit -m "feat(ui): add hover glow to zone tiles"
```

---

### Task 8: Replace the selected zone PulseNode with a breathing aura sprite

**Files:**
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.tscn`
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd`

- [ ] **Step 1: Add an AuraSprite to the scene and remove the PulseNode**

Open `zone_tilemap.tscn`. Delete the existing `PulseNode` child. Add a new child of root:
- `AuraSprite` (Sprite2D)
  - texture: `assets/sprites/atmosphere/aura_glow.png`
  - modulate: `Color(0.42, 0.78, 1.0, 0.85)`
  - scale: `Vector2(0.85, 0.85)`
  - z_index: 4
  - unique_name_in_owner: true

Save the scene.

- [ ] **Step 2: Update zone_tilemap.gd to use AuraSprite + breathing tween**

In `scenes/zones/zone_tilemap/zone_tilemap.gd`, replace:
```gdscript
@onready var selected_zone_pulse_node: Line2D = %PulseNode
```
with:
```gdscript
@onready var _aura_sprite: Sprite2D = %AuraSprite

var _aura_breath_tween: Tween
```

Replace the body of `_move_character_to_tile_coord()`:
```gdscript
func _move_character_to_tile_coord(tile_coord: Vector2i) -> void:
	var world_pos := tile_map.map_to_local(tile_coord) + tile_map.position
	_move_character_to_position(world_pos)
	_aura_sprite.global_position = world_pos
	_start_aura_breathing()

func _start_aura_breathing() -> void:
	if _aura_breath_tween and _aura_breath_tween.is_valid():
		_aura_breath_tween.kill()
	_aura_breath_tween = create_tween()
	_aura_breath_tween.set_loops()
	_aura_breath_tween.set_trans(Tween.TRANS_SINE)
	_aura_breath_tween.set_ease(Tween.EASE_IN_OUT)
	_aura_breath_tween.tween_property(_aura_sprite, "scale", Vector2(0.95, 0.95), 1.25)
	_aura_breath_tween.tween_property(_aura_sprite, "scale", Vector2(0.85, 0.85), 1.25)
```

- [ ] **Step 3: Smoke-test**

Run the game. The selected zone should have a soft pulsing aura breathing in/out instead of the green Line2D outline. Click another zone — the aura should follow.

- [ ] **Step 4: Commit**

```bash
git add scenes/zones/zone_tilemap/zone_tilemap.gd \
  scenes/zones/zone_tilemap/zone_tilemap.tscn
git commit -m "feat(ui): replace zone PulseNode with breathing aura sprite"
```

---

### Task 9: Eased camera tween on zone selection

**Files:**
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd`

- [ ] **Step 1: Add eased camera tween in _on_zone_tile_clicked**

In `scenes/zones/zone_tilemap/zone_tilemap.gd`, add a new constant near the top with the other constants:
```gdscript
const CAMERA_EASE_DURATION := 0.5
```

Add a new helper function in the PRIVATE METHODS section (above `_on_zone_tile_clicked`):
```gdscript
func _ease_camera_to(world_pos: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_camera, "position", world_pos, CAMERA_EASE_DURATION)
```

In `_on_zone_tile_clicked()`, after the line `_move_character_to_tile_coord(tile_coord)`, add:
```gdscript
	_ease_camera_to(tile_map.map_to_local(tile_coord) + tile_map.position)
```

- [ ] **Step 2: Smoke-test**

Run the game. Click between zones. The camera should ease toward the new zone with a slight overshoot (TRANS_BACK / EASE_OUT) over half a second.

- [ ] **Step 3: Commit**

```bash
git add scenes/zones/zone_tilemap/zone_tilemap.gd
git commit -m "feat(ui): ease camera to selected zone with overshoot"
```

---

### Task 10: Add locked zone "?" silhouettes

**Files:**
- Create: `scenes/zones/locked_zone_glyph/locked_zone_glyph.tscn`
- Modify: `assets/themes/pixel_theme.tres`
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd`
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.tscn`

- [ ] **Step 1: Add the LockedGlyph theme variant**

In the Godot editor, open `assets/themes/pixel_theme.tres`. Add a new Label theme variant:
- Type: `Label`
- Variant name: `LockedGlyph`
- font_size: 48
- font_color: `Color(0.43, 0.51, 0.65, 0.7)`
- font_outline_color: `Color(0, 0, 0, 0.95)`
- font_outline_size: 4

Save the theme.

- [ ] **Step 2: Build the locked_zone_glyph scene**

Create a new scene at `scenes/zones/locked_zone_glyph/locked_zone_glyph.tscn`:
```
LockedZoneGlyph (Label)
- text: "?"
- theme: pixel_theme.tres
- theme_type_variation: "LockedGlyph"
- horizontal_alignment: 1 (Center)
- vertical_alignment: 1 (Center)
- size: (96, 96)
- pivot_offset: (48, 48)
- mouse_filter: Ignore
```

Save.

- [ ] **Step 3: Add a LockedGlyphContainer to zone_tilemap.tscn**

Open `zone_tilemap.tscn`. Add a Node2D child of the root:
- `LockedGlyphContainer` (Node2D)
  - z_index: 3
  - unique_name_in_owner: true

Save.

- [ ] **Step 4: Spawn glyphs from zone_tilemap.gd for locked zones**

In `scenes/zones/zone_tilemap/zone_tilemap.gd`, add at the top with the other constants:
```gdscript
const LockedZoneGlyphScene := preload("res://scenes/zones/locked_zone_glyph/locked_zone_glyph.tscn")
```

Add a new `@onready`:
```gdscript
@onready var _locked_glyph_container: Node2D = %LockedGlyphContainer
```

Add a new helper function in PRIVATE METHODS:
```gdscript
func _refresh_locked_glyphs() -> void:
	for child in _locked_glyph_container.get_children():
		child.queue_free()
	for zone_data in ZoneManager.get_all_zones():
		if UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
			continue
		var glyph := LockedZoneGlyphScene.instantiate() as Label
		_locked_glyph_container.add_child(glyph)
		var world_pos := tile_map.map_to_local(zone_data.tilemap_location) + tile_map.position
		glyph.position = world_pos - Vector2(glyph.size.x * 0.5, glyph.size.y * 0.5)
```

In `_ready()`, after `set_all_zones_in_tile_map()`, add:
```gdscript
	_refresh_locked_glyphs()
```

In `_on_condition_unlocked()`, after the existing `set_all_zones_in_tile_map()` call, add:
```gdscript
	_refresh_locked_glyphs()
```

- [ ] **Step 5: Smoke-test**

Run the game. Locked zones should display a centered "?" glyph in dim cyan over the locked tile variant. After unlocking a zone in-game (via `UnlockManager`), its glyph should disappear.

- [ ] **Step 6: Commit**

```bash
git add scenes/zones/locked_zone_glyph/ \
  scenes/zones/zone_tilemap/zone_tilemap.gd \
  scenes/zones/zone_tilemap/zone_tilemap.tscn \
  assets/themes/pixel_theme.tres
git commit -m "feat(ui): show ? silhouettes on locked zones"
```

---

### Task 11: Glowing path lines between adjacent unlocked zones

**Files:**
- Create: `assets/shaders/flowing_path.gdshader`
- Create: `scenes/zones/glowing_path/glowing_path.gd`
- Create: `scenes/zones/glowing_path/glowing_path.tscn`
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.gd`
- Modify: `scenes/zones/zone_tilemap/zone_tilemap.tscn`

- [ ] **Step 1: Create the flowing path shader**

Create `assets/shaders/flowing_path.gdshader`:

```glsl
shader_type canvas_item;

uniform vec4 stroke_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform float scroll_speed : hint_range(0.0, 4.0) = 1.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	// Sample the Line2D's gradient (its base alpha) — gives us the soft falloff perpendicular to the line
	vec4 base := texture(TEXTURE, UV);

	// Animate brightness along the line via UV.x scrolling
	float wave := sin((UV.x - TIME * scroll_speed) * 6.2831);
	float bright := 1.0 - pulse_strength + (wave * 0.5 + 0.5) * pulse_strength;

	COLOR = vec4(stroke_color.rgb * bright, base.a * stroke_color.a);
}
```

- [ ] **Step 2: Create the glowing path script**

Create `scenes/zones/glowing_path/glowing_path.gd`:

```gdscript
class_name GlowingPath
extends Line2D

## Renders a glowing animated line between two world points.

func setup(from: Vector2, to: Vector2) -> void:
	clear_points()
	add_point(from)
	add_point(to)
```

- [ ] **Step 3: Build the scene**

Create a new scene at `scenes/zones/glowing_path/glowing_path.tscn`:
```
GlowingPath (Line2D)
- script: glowing_path.gd
- width: 6.0
- default_color: Color(0.55, 0.78, 1.0, 1.0)
- begin_cap_mode: Round
- end_cap_mode: Round
- joint_mode: Round
- gradient: new Gradient with two stops:
    0.0 → Color(0.55, 0.78, 1.0, 0.0)
    0.5 → Color(0.55, 0.78, 1.0, 1.0)
    1.0 → Color(0.55, 0.78, 1.0, 0.0)
- material: new ShaderMaterial → flowing_path.gdshader
    - stroke_color: Color(0.55, 0.78, 1.0, 0.85)
    - scroll_speed: 0.7
    - pulse_strength: 0.35
```

Save.

- [ ] **Step 4: Add a GlowingPathContainer to zone_tilemap.tscn**

Open `zone_tilemap.tscn`. Add a Node2D child of root:
- `GlowingPathContainer` (Node2D)
  - z_index: 1
  - unique_name_in_owner: true

Save.

- [ ] **Step 5: Generate glowing paths in zone_tilemap.gd**

In `scenes/zones/zone_tilemap/zone_tilemap.gd`, add at the top with the other constants:
```gdscript
const GlowingPathScene := preload("res://scenes/zones/glowing_path/glowing_path.tscn")
```

Add the onready ref:
```gdscript
@onready var _glowing_path_container: Node2D = %GlowingPathContainer
```

Add a helper function in PRIVATE METHODS:
```gdscript
func _refresh_glowing_paths() -> void:
	for child in _glowing_path_container.get_children():
		child.queue_free()

	var unlocked_zones: Array[ZoneData] = []
	for zone_data in ZoneManager.get_all_zones():
		if UnlockManager.are_unlock_conditions_met(zone_data.zone_unlock_conditions):
			unlocked_zones.append(zone_data)

	# Build set of unlocked tile coords for fast lookup
	var unlocked_coords := {}
	for zone_data in unlocked_zones:
		unlocked_coords[zone_data.tilemap_location] = zone_data

	# For each unlocked zone, draw a path to each unlocked hex-neighbor
	# (hex-neighbor offsets for axial / offset coords used by HexagonTileMapLayer)
	var seen := {}
	for zone_data in unlocked_zones:
		var coord := zone_data.tilemap_location
		for neighbor_coord in tile_map.get_surrounding_cells(coord):
			if not unlocked_coords.has(neighbor_coord):
				continue
			# Avoid drawing both A→B and B→A
			var pair_key := str(min(coord.x, neighbor_coord.x)) + "_" + str(min(coord.y, neighbor_coord.y)) + "_" + str(max(coord.x, neighbor_coord.x)) + "_" + str(max(coord.y, neighbor_coord.y))
			if seen.has(pair_key):
				continue
			seen[pair_key] = true

			var from_world := tile_map.map_to_local(coord) + tile_map.position
			var to_world := tile_map.map_to_local(neighbor_coord) + tile_map.position
			var path := GlowingPathScene.instantiate() as GlowingPath
			_glowing_path_container.add_child(path)
			path.setup(from_world, to_world)
```

In `_ready()`, after `_refresh_locked_glyphs()`, add:
```gdscript
	_refresh_glowing_paths()
```

In `_on_condition_unlocked()`, after `_refresh_locked_glyphs()`, add:
```gdscript
	_refresh_glowing_paths()
```

- [ ] **Step 6: Smoke-test**

Run the game. Glowing cyan lines should connect each pair of adjacent unlocked zones, with a flowing brightness animation along the line. Locked zones should not be connected.

- [ ] **Step 7: Commit**

```bash
git add assets/shaders/flowing_path.gdshader \
  scenes/zones/glowing_path/ \
  scenes/zones/zone_tilemap/zone_tilemap.gd \
  scenes/zones/zone_tilemap/zone_tilemap.tscn
git commit -m "feat(ui): add glowing path lines between adjacent unlocked zones"
```

---

### Task 12: Create TileStateOverlay scene + script + tests

**Files:**
- Create: `assets/shaders/tile_aura.gdshader`
- Create: `scenes/adventure/tile_state_overlay/tile_state_overlay.gd`
- Create: `scenes/adventure/tile_state_overlay/tile_state_overlay.tscn`
- Create: `tests/unit/test_tile_state_overlay.gd`

- [ ] **Step 1: Create the tile_aura shader**

Create `assets/shaders/tile_aura.gdshader`:

```glsl
shader_type canvas_item;

uniform vec4 aura_color : source_color = vec4(0.6, 0.84, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.6;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 base := texture(TEXTURE, UV);
	float wave := (sin(TIME * pulse_speed) + 1.0) * 0.5;
	float pulse := pulse_min + wave * (1.0 - pulse_min);
	COLOR = vec4(aura_color.rgb * pulse, base.a * aura_color.a);
}
```

- [ ] **Step 2: Write the script**

Create `scenes/adventure/tile_state_overlay/tile_state_overlay.gd`:

```gdscript
class_name TileStateOverlay
extends Node2D

## TileStateOverlay
## Pools Sprite2D overlays per cube coordinate to render the 5 tile states
## (HIDDEN, REVEAL, VISITED, CURRENT, HOVER_TARGET) as visual layers above
## the existing AdventureVisibleMap tilemap. State transitions are animated
## via Tweens. No tilemap data is touched.

enum TileState {
	HIDDEN,
	REVEAL,
	VISITED,
	CURRENT,
	HOVER_TARGET,
}

const _AURA_TEXTURE := preload("res://assets/sprites/atmosphere/aura_glow.png")

var _overlays: Dictionary[Vector3i, Sprite2D] = {}
var _states: Dictionary[Vector3i, int] = {}

## Sets the state of a tile at the given cube coordinate.
## Creates the overlay if it does not exist.
## world_pos is the tile center in the parent's local coordinate space.
func set_tile_state(cube: Vector3i, state: int, world_pos: Vector2) -> void:
	var sprite := _overlays.get(cube)
	if sprite == null:
		sprite = _make_sprite()
		_overlays[cube] = sprite
		add_child(sprite)
	sprite.position = world_pos
	_apply_state(sprite, state)
	_states[cube] = state

## Removes the overlay at the given cube coordinate.
func remove_tile(cube: Vector3i) -> void:
	var sprite := _overlays.get(cube)
	if sprite == null:
		return
	sprite.queue_free()
	_overlays.erase(cube)
	_states.erase(cube)

## Removes all overlays.
func clear_all() -> void:
	for sprite in _overlays.values():
		sprite.queue_free()
	_overlays.clear()
	_states.clear()

## Returns the current state for a tile, or -1 if not tracked.
func get_state(cube: Vector3i) -> int:
	return _states.get(cube, -1)

## Returns the number of tracked overlays. Used by tests.
func get_overlay_count() -> int:
	return _overlays.size()

func _make_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _AURA_TEXTURE
	sprite.scale = Vector2(0.55, 0.55)
	sprite.modulate = Color(1, 1, 1, 0)
	return sprite

func _apply_state(sprite: Sprite2D, state: int) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	match state:
		TileState.HIDDEN:
			tween.tween_property(sprite, "modulate", Color(0.1, 0.13, 0.22, 0.5), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.15)
		TileState.REVEAL:
			tween.tween_property(sprite, "modulate", Color(0.55, 0.71, 0.95, 0.7), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.15)
		TileState.VISITED:
			tween.tween_property(sprite, "modulate", Color(0.35, 0.45, 0.62, 0.45), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.15)
		TileState.CURRENT:
			tween.tween_property(sprite, "modulate", Color(0.7, 0.88, 1.0, 0.95), 0.15)
			tween.tween_property(sprite, "scale", Vector2(0.85, 0.85), 0.15)
		TileState.HOVER_TARGET:
			tween.tween_property(sprite, "modulate", Color(0.85, 0.95, 1.0, 1.0), 0.08)
			tween.tween_property(sprite, "scale", Vector2(0.65, 0.65), 0.08)
```

- [ ] **Step 3: Build the scene**

Create a new scene at `scenes/adventure/tile_state_overlay/tile_state_overlay.tscn`:
```
TileStateOverlay (Node2D)
- script: tile_state_overlay.gd
- z_index: 5
```
Save.

- [ ] **Step 4: Write failing tests**

Create `tests/unit/test_tile_state_overlay.gd`:

```gdscript
extends GutTest

## Unit tests for TileStateOverlay
## Tests pool / transition / clear behavior

const TileStateOverlayScene := preload("res://scenes/adventure/tile_state_overlay/tile_state_overlay.tscn")

var overlay: TileStateOverlay

func before_each() -> void:
	overlay = TileStateOverlayScene.instantiate()
	add_child_autofree(overlay)

func test_starts_empty() -> void:
	assert_eq(overlay.get_overlay_count(), 0)

func test_set_tile_state_creates_overlay() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(100, 100))
	assert_eq(overlay.get_overlay_count(), 1)
	assert_eq(overlay.get_state(Vector3i(0, 0, 0)), TileStateOverlay.TileState.REVEAL)

func test_set_tile_state_does_not_create_duplicate() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(100, 100))
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.CURRENT, Vector2(100, 100))
	assert_eq(overlay.get_overlay_count(), 1)
	assert_eq(overlay.get_state(Vector3i(0, 0, 0)), TileStateOverlay.TileState.CURRENT)

func test_set_tile_state_creates_distinct_for_different_coords() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(0, 0))
	overlay.set_tile_state(Vector3i(1, -1, 0), TileStateOverlay.TileState.REVEAL, Vector2(64, 0))
	overlay.set_tile_state(Vector3i(2, -2, 0), TileStateOverlay.TileState.HOVER_TARGET, Vector2(128, 0))
	assert_eq(overlay.get_overlay_count(), 3)

func test_remove_tile_frees_sprite() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(0, 0))
	overlay.set_tile_state(Vector3i(1, -1, 0), TileStateOverlay.TileState.REVEAL, Vector2(64, 0))
	overlay.remove_tile(Vector3i(0, 0, 0))
	assert_eq(overlay.get_overlay_count(), 1)
	assert_eq(overlay.get_state(Vector3i(0, 0, 0)), -1)
	assert_eq(overlay.get_state(Vector3i(1, -1, 0)), TileStateOverlay.TileState.REVEAL)

func test_clear_all_removes_everything() -> void:
	overlay.set_tile_state(Vector3i(0, 0, 0), TileStateOverlay.TileState.REVEAL, Vector2(0, 0))
	overlay.set_tile_state(Vector3i(1, -1, 0), TileStateOverlay.TileState.REVEAL, Vector2(64, 0))
	overlay.set_tile_state(Vector3i(2, -2, 0), TileStateOverlay.TileState.CURRENT, Vector2(128, 0))
	overlay.clear_all()
	assert_eq(overlay.get_overlay_count(), 0)

func test_remove_nonexistent_tile_is_safe() -> void:
	overlay.remove_tile(Vector3i(99, 99, -198))
	assert_eq(overlay.get_overlay_count(), 0)
```

- [ ] **Step 5: Run tests**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_tile_state_overlay.gd -gexit
```
Expected: all 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add assets/shaders/tile_aura.gdshader \
  scenes/adventure/tile_state_overlay/ \
  tests/unit/test_tile_state_overlay.gd
git commit -m "feat(adventure): add TileStateOverlay scene + tests"
```

---

### Task 13: Wire TileStateOverlay into adventure_tilemap

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`

- [ ] **Step 1: Add TileStateOverlay child to the scene**

Open `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn` in the editor. Right-click root → Instantiate Child Scene → `scenes/adventure/tile_state_overlay/tile_state_overlay.tscn`. Set `unique_name_in_owner = true`. Save.

- [ ] **Step 2: Replace pulse-node spawning with TileStateOverlay calls**

In `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, add to the NODE REFERENCES section:

```gdscript
@onready var _tile_state_overlay: TileStateOverlay = %TileStateOverlay
```

Replace the body of `_update_visible_map()` (lines 350-374 in the original file) with:

```gdscript
func _update_visible_map() -> void:
	visible_map.clear()
	highlight_map.clear()
	_tile_state_overlay.clear_all()

	var visible_coords := _visited_tile_dictionary.keys()
	for highlight_coord in _highlight_tile_dictionary.keys():
		if _highlight_tile_dictionary[highlight_coord] == HighlightType.VISIBLE_NEIGHBOUR:
			visible_coords.append(highlight_coord)
			var world_pos := full_map.cube_to_local(highlight_coord) + full_map.position
			_tile_state_overlay.set_tile_state(highlight_coord, TileStateOverlay.TileState.REVEAL, world_pos)

	for coord in visible_coords:
		if not _encounter_tile_dictionary[coord] is NoOpEncounter:
			visible_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, YELLOW_TILE_VARIANT_ID, full_map.cube_to_map(coord))
			_update_cell_highlight(coord)
		else:
			visible_map.set_cell_with_source_and_variant(BASE_TILE_SOURCE_ID, WHITE_TILE_VARIANT_ID, full_map.cube_to_map(coord))

	# Visited tiles get the VISITED state, current tile overrides with CURRENT
	for coord in _visited_tile_dictionary.keys():
		var world_pos := full_map.cube_to_local(coord) + full_map.position
		_tile_state_overlay.set_tile_state(coord, TileStateOverlay.TileState.VISITED, world_pos)

	if _visited_tile_dictionary.has(_current_tile):
		var world_pos := full_map.cube_to_local(_current_tile) + full_map.position
		_tile_state_overlay.set_tile_state(_current_tile, TileStateOverlay.TileState.CURRENT, world_pos)
```

- [ ] **Step 3: Smoke-test**

Run the game, start an adventure. Visited tiles should show dim blue overlay sprites. Reveal-neighbor tiles should show brighter cyan overlays. The current tile should have a brighter, larger aura. The old PulseNode dark-red pulses should no longer appear.

- [ ] **Step 4: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_tilemap.gd \
  scenes/adventure/adventure_tilemap/adventure_tilemap.tscn
git commit -m "feat(adventure): replace PulseNodes with TileStateOverlay"
```

---

### Task 14: Create EncounterIcon scene + script + tests

**Files:**
- Create: `assets/sprites/adventure/encounter_glyphs/*.png` (covered in Task 2's pattern, see step 1)
- Create: `scenes/adventure/encounter_icon/encounter_icon.gd`
- Create: `scenes/adventure/encounter_icon/encounter_icon.tscn`
- Create: `tests/unit/test_encounter_icon_config.gd`

- [ ] **Step 1: Create the seven glyph sprites**

Create the directory `assets/sprites/adventure/encounter_glyphs/` and place seven PNGs. Each is a single white-on-transparent glyph that gets tinted at runtime via `Sprite2D.modulate`. Sizes:

| File | Size | Glyph |
|------|------|-------|
| `combat.png` | 32×32 | Crossed blades (X with thick strokes) |
| `elite.png` | 32×32 | Four-point star |
| `boss.png` | 48×48 | Ornamental sigil (e.g., fleur-de-lis or stylized seal) |
| `rest.png` | 32×32 | Shrine/tent silhouette |
| `treasure.png` | 32×32 | Diamond/gem shape |
| `trap.png` | 32×32 | Warning triangle with `!` |
| `unknown.png` | 32×32 | Question mark |

These should be authored in Aseprite or GIMP. Pure white pixels with hard edges (or 1px AA), transparent background.

Re-import:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

- [ ] **Step 2: Write the script**

Create `scenes/adventure/encounter_icon/encounter_icon.gd`:

```gdscript
class_name EncounterIcon
extends Node2D

## EncounterIcon
## Renders an encounter glyph + frame at a tile center. Per-type configuration
## sets glyph texture, modulate color, frame size, and optional dramatic
## extras (boss ornamental ring, treasure sparkle).

@onready var _frame: Sprite2D = %Frame
@onready var _glyph: Sprite2D = %Glyph
@onready var _ornamental_ring: Sprite2D = %OrnamentalRing

const _GLYPH_COMBAT := preload("res://assets/sprites/adventure/encounter_glyphs/combat.png")
const _GLYPH_ELITE := preload("res://assets/sprites/adventure/encounter_glyphs/elite.png")
const _GLYPH_BOSS := preload("res://assets/sprites/adventure/encounter_glyphs/boss.png")
const _GLYPH_REST := preload("res://assets/sprites/adventure/encounter_glyphs/rest.png")
const _GLYPH_TREASURE := preload("res://assets/sprites/adventure/encounter_glyphs/treasure.png")
const _GLYPH_TRAP := preload("res://assets/sprites/adventure/encounter_glyphs/trap.png")
const _GLYPH_UNKNOWN := preload("res://assets/sprites/adventure/encounter_glyphs/unknown.png")

var _is_visited: bool = false
var _current_type: int = -1

## Configures this icon to display the given encounter type.
## Returns false if the type should render no icon (NONE / unconfigured).
func configure_for_type(encounter_type: int) -> bool:
	_current_type = encounter_type
	_ornamental_ring.visible = false
	_frame.scale = Vector2(1, 1)
	_glyph.scale = Vector2(1, 1)

	match encounter_type:
		AdventureEncounter.EncounterType.COMBAT_REGULAR, AdventureEncounter.EncounterType.COMBAT_AMBUSH:
			_glyph.texture = _GLYPH_COMBAT
			_glyph.modulate = Color(0.85, 0.51, 0.44, 1.0)
			_frame.modulate = Color(0.55, 0.13, 0.13, 0.7)
			return true
		AdventureEncounter.EncounterType.COMBAT_ELITE:
			_glyph.texture = _GLYPH_ELITE
			_glyph.modulate = Color(0.88, 0.5, 0.88, 1.0)
			_frame.modulate = Color(0.4, 0.1, 0.45, 0.78)
			_frame.scale = Vector2(1.12, 1.12)
			return true
		AdventureEncounter.EncounterType.COMBAT_BOSS:
			_glyph.texture = _GLYPH_BOSS
			_glyph.modulate = Color(1.0, 0.94, 0.75, 1.0)
			_frame.modulate = Color(0.94, 0.31, 0.16, 0.95)
			_frame.scale = Vector2(1.65, 1.65)
			_glyph.scale = Vector2(1.5, 1.5)
			_ornamental_ring.visible = true
			return true
		AdventureEncounter.EncounterType.REST_SITE:
			_glyph.texture = _GLYPH_REST
			_glyph.modulate = Color(0.55, 0.94, 0.65, 1.0)
			_frame.modulate = Color(0.08, 0.39, 0.24, 0.7)
			return true
		AdventureEncounter.EncounterType.TREASURE:
			_glyph.texture = _GLYPH_TREASURE
			_glyph.modulate = Color(1.0, 0.86, 0.31, 1.0)
			_frame.modulate = Color(0.63, 0.35, 0.0, 0.78)
			return true
		AdventureEncounter.EncounterType.TRAP:
			# Traps are hidden until visited
			if not _is_visited:
				return false
			_glyph.texture = _GLYPH_TRAP
			_glyph.modulate = Color(0.86, 0.39, 0.16, 1.0)
			_frame.modulate = Color(0.31, 0.0, 0.0, 0.78)
			return true
		AdventureEncounter.EncounterType.NONE:
			return false
		_:
			# Fallback: mystery icon
			_glyph.texture = _GLYPH_UNKNOWN
			_glyph.modulate = Color(0.71, 0.59, 0.94, 1.0)
			_frame.modulate = Color(0.24, 0.12, 0.47, 0.78)
			return true

## Marks this icon as visited (dimmed/desaturated, traps revealed).
func set_visited(visited: bool) -> void:
	_is_visited = visited
	if visited:
		modulate = Color(1, 1, 1, 0.45)
	else:
		modulate = Color(1, 1, 1, 1.0)
	# Re-run config so traps get revealed
	if _current_type != -1:
		configure_for_type(_current_type)

## Returns the current configured type (used by tests).
func get_configured_type() -> int:
	return _current_type
```

- [ ] **Step 3: Build the scene**

Create a new scene at `scenes/adventure/encounter_icon/encounter_icon.tscn`:
```
EncounterIcon (Node2D)
- script: encounter_icon.gd
- z_index: 6
├── Frame (Sprite2D)
    - texture: assets/sprites/atmosphere/aura_glow.png
    - scale: (0.18, 0.18)
    - modulate: Color(1, 1, 1, 0.7)
    - unique_name_in_owner: true
├── Glyph (Sprite2D)
    - texture: combat.png (placeholder, overwritten by configure_for_type)
    - scale: (1, 1)
    - unique_name_in_owner: true
└── OrnamentalRing (Sprite2D)
    - texture: assets/sprites/atmosphere/aura_glow.png
    - scale: (0.42, 0.42)
    - modulate: Color(1.0, 0.71, 0.31, 0.6)
    - visible: false
    - unique_name_in_owner: true
```

Save.

- [ ] **Step 4: Write failing tests**

Create `tests/unit/test_encounter_icon_config.gd`:

```gdscript
extends GutTest

## Unit tests for EncounterIcon.configure_for_type()

const EncounterIconScene := preload("res://scenes/adventure/encounter_icon/encounter_icon.tscn")

var icon: EncounterIcon

func before_each() -> void:
	icon = EncounterIconScene.instantiate()
	add_child_autofree(icon)
	# Force _ready by simulating a frame
	await get_tree().process_frame

func test_configure_combat_returns_true() -> void:
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	assert_true(result)
	assert_eq(icon.get_configured_type(), AdventureEncounter.EncounterType.COMBAT_REGULAR)

func test_configure_ambush_uses_combat_visuals() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	var combat_color := icon._glyph.modulate
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_AMBUSH)
	assert_eq(icon._glyph.modulate, combat_color, "ambush should look identical to regular combat")

func test_configure_elite_returns_true() -> void:
	assert_true(icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_ELITE))

func test_configure_boss_enables_ornamental_ring() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_BOSS)
	assert_true(icon._ornamental_ring.visible)
	assert_almost_eq(icon._frame.scale.x, 1.65, 0.01)

func test_configure_rest_returns_true() -> void:
	assert_true(icon.configure_for_type(AdventureEncounter.EncounterType.REST_SITE))

func test_configure_treasure_returns_true() -> void:
	assert_true(icon.configure_for_type(AdventureEncounter.EncounterType.TREASURE))

func test_configure_trap_unvisited_returns_false() -> void:
	icon.set_visited(false)
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.TRAP)
	assert_false(result, "trap should be hidden until visited")

func test_configure_trap_visited_returns_true() -> void:
	icon.set_visited(true)
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.TRAP)
	assert_true(result, "trap should be visible once visited")

func test_configure_none_returns_false() -> void:
	var result := icon.configure_for_type(AdventureEncounter.EncounterType.NONE)
	assert_false(result)

func test_configure_resets_ornamental_ring_for_non_boss() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_BOSS)
	assert_true(icon._ornamental_ring.visible)
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	assert_false(icon._ornamental_ring.visible)

func test_set_visited_dims_modulate() -> void:
	icon.configure_for_type(AdventureEncounter.EncounterType.COMBAT_REGULAR)
	icon.set_visited(true)
	assert_almost_eq(icon.modulate.a, 0.45, 0.01)
```

- [ ] **Step 5: Run tests**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_encounter_icon_config.gd -gexit
```
Expected: all 11 tests pass.

- [ ] **Step 6: Commit**

```bash
git add assets/sprites/adventure/encounter_glyphs/ \
  scenes/adventure/encounter_icon/ \
  tests/unit/test_encounter_icon_config.gd
git commit -m "feat(adventure): add EncounterIcon scene + per-type config tests"
```

---

### Task 15: Boss icon ornamental ring rotation + breathing pulse

**Files:**
- Modify: `scenes/adventure/encounter_icon/encounter_icon.gd`

- [ ] **Step 1: Add the boss animation when configured**

In `scenes/adventure/encounter_icon/encounter_icon.gd`, add a new state var near the top:

```gdscript
var _boss_tween: Tween
```

Add a new helper function to the file:

```gdscript
func _start_boss_animation() -> void:
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.set_loops()
	_boss_tween.set_parallel(true)
	# Ring rotation
	_boss_tween.tween_property(_ornamental_ring, "rotation", TAU, 20.0).set_trans(Tween.TRANS_LINEAR)
	# Breathing pulse on the frame scale
	var breathe := create_tween()
	breathe.set_loops()
	breathe.set_trans(Tween.TRANS_SINE)
	breathe.set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(_frame, "scale", Vector2(1.78, 1.78), 0.9)
	breathe.tween_property(_frame, "scale", Vector2(1.65, 1.65), 0.9)

func _stop_boss_animation() -> void:
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_ornamental_ring.rotation = 0.0
```

In the `match` statement inside `configure_for_type`, in the `COMBAT_BOSS` branch, after `_ornamental_ring.visible = true`, add:
```gdscript
			_start_boss_animation()
```

In every other non-boss branch (and at the top of the function), call `_stop_boss_animation()` so switching away from a boss tile cleans up. The cleanest place is at the top, before the `match`:
```gdscript
	_stop_boss_animation()
```
Add this immediately after the existing `_ornamental_ring.visible = false` reset line.

- [ ] **Step 2: Re-run encounter icon tests**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gtest=test_encounter_icon_config.gd -gexit
```
Expected: all 11 tests still pass (no logic changed, only animation hooks).

- [ ] **Step 3: Commit**

```bash
git add scenes/adventure/encounter_icon/encounter_icon.gd
git commit -m "feat(adventure): boss icon ornamental ring rotation + breathing pulse"
```

---

### Task 16: Wire EncounterIcon into adventure_tilemap, replace _update_cell_highlight

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`

- [ ] **Step 1: Add an EncounterIconContainer to the scene**

Open `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`. Add a Node2D child of the root:
- `EncounterIconContainer` (Node2D)
  - z_index: 6
  - unique_name_in_owner: true

Save.

- [ ] **Step 2: Replace `_update_cell_highlight` with EncounterIcon instancing**

In `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, add the preload near the top with other class-level constants:

```gdscript
const EncounterIconScene := preload("res://scenes/adventure/encounter_icon/encounter_icon.tscn")
```

Add the onready ref in NODE REFERENCES:
```gdscript
@onready var _encounter_icon_container: Node2D = %EncounterIconContainer

var _encounter_icons: Dictionary[Vector3i, EncounterIcon] = {}
```

Replace the entire body of `_update_cell_highlight()` with:

```gdscript
func _update_cell_highlight(coord: Vector3i) -> void:
	var encounter: AdventureEncounter = _encounter_tile_dictionary[coord]
	if not encounter:
		return

	var icon: EncounterIcon = _encounter_icons.get(coord)
	if icon == null:
		icon = EncounterIconScene.instantiate()
		_encounter_icon_container.add_child(icon)
		_encounter_icons[coord] = icon

	icon.position = full_map.cube_to_local(coord) + full_map.position
	icon.set_visited(_visited_tile_dictionary.has(coord))
	var should_show := icon.configure_for_type(encounter.encounter_type)
	icon.visible = should_show
```

Update `_update_visible_map` to clean up encounter icons that are no longer visible. At the start of `_update_visible_map`, after `_tile_state_overlay.clear_all()`, add:

```gdscript
	for icon in _encounter_icons.values():
		icon.queue_free()
	_encounter_icons.clear()
```

Update `stop_adventure()` to also clear the icons. Find the existing `stop_adventure()` function and add this line before `_visitation_queue.clear()`:

```gdscript
	for icon in _encounter_icons.values():
		icon.queue_free()
	_encounter_icons.clear()
```

- [ ] **Step 3: Smoke-test**

Run the game, start an adventure. Each encounter type should show its distinct glyph + colored frame: combat (red blades), elite (violet star), boss (gold ornamental sigil with rotating ring), rest (green shrine), treasure (gold gem). Visited tiles should have dimmed icons. Trap tiles should not show an icon until you walk onto them.

- [ ] **Step 4: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_tilemap.gd \
  scenes/adventure/adventure_tilemap/adventure_tilemap.tscn
git commit -m "feat(adventure): replace cell highlight overlays with EncounterIcon"
```

---

### Task 17: Fog-of-war shader and integration

**Files:**
- Create: `assets/shaders/fog_of_war.gdshader`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`

- [ ] **Step 1: Create the shader**

Create `assets/shaders/fog_of_war.gdshader`:

```glsl
shader_type canvas_item;

const int MAX_CLEAR_POSITIONS = 64;

uniform vec2 clear_positions[MAX_CLEAR_POSITIONS];
uniform int clear_count = 0;
uniform float clear_radius : hint_range(0.0, 800.0) = 180.0;
uniform float clear_softness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 fog_color : source_color = vec4(0.02, 0.03, 0.08, 0.85);

void fragment() {
	// Convert SCREEN_UV → world (canvas_item space)
	vec2 world_pos := (SCREEN_UV * SCREEN_PIXEL_SIZE * vec2(1.0 / SCREEN_PIXEL_SIZE.x, 1.0 / SCREEN_PIXEL_SIZE.y));
	// Better: pass world position directly via a uniform offset, but for a screen-space shader this is fine
	world_pos = SCREEN_UV / SCREEN_PIXEL_SIZE;

	float min_dist := 99999.0;
	for (int i := 0; i < MAX_CLEAR_POSITIONS; i++) {
		if (i >= clear_count) {
			break;
		}
		min_dist = min(min_dist, distance(world_pos, clear_positions[i]));
	}

	float mask := smoothstep(clear_radius, clear_radius * (1.0 + clear_softness), min_dist);
	COLOR = vec4(fog_color.rgb, fog_color.a * mask);
}
```

> **Note:** Screen-to-world conversion in a canvas_item shader is approximate — the simple version above samples in screen pixels and works well enough when the camera is roughly centered. If the fog visibly drifts when panning, switch to passing `clear_positions` already in screen space (i.e. transform them in GDScript before passing the uniform). Implementer should test this and apply that fix if needed.

- [ ] **Step 2: Add a FogOfWarRect to the scene**

Open `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`. Add a CanvasLayer child of the root (so the rect renders at full screen regardless of camera):

```
FogLayer (CanvasLayer, layer = 4)
└── FogOfWarRect (ColorRect)
    - layout: anchors full rect (Full Rect preset)
    - color: Color(1, 1, 1, 1)
    - material: new ShaderMaterial → fog_of_war.gdshader
    - shader_parameter/clear_count: 0
    - shader_parameter/clear_radius: 180.0
    - shader_parameter/clear_softness: 0.5
    - shader_parameter/fog_color: Color(0.02, 0.03, 0.08, 0.85)
    - unique_name_in_owner: true
```

Save.

- [ ] **Step 3: Update fog uniforms when tiles are visited**

In `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, add the onready in NODE REFERENCES:

```gdscript
@onready var _fog_rect: ColorRect = %FogOfWarRect
```

Add a constant near the top:
```gdscript
const FOG_MAX_CLEAR_POSITIONS = 64
```

Add a new helper function in PRIVATE METHODS:
```gdscript
func _update_fog_uniforms() -> void:
	if not _fog_rect or not _fog_rect.material:
		return
	var positions: Array[Vector2] = []
	# Convert each visited tile's WORLD position to SCREEN space for the shader
	var camera := get_viewport().get_camera_2d()
	for coord in _visited_tile_dictionary.keys():
		var world_pos := full_map.cube_to_local(coord) + full_map.position
		var screen_pos: Vector2
		if camera:
			screen_pos = (world_pos - camera.global_position) * camera.zoom + Vector2(get_viewport_rect().size) * 0.5
		else:
			screen_pos = world_pos
		positions.append(screen_pos)
		if positions.size() >= FOG_MAX_CLEAR_POSITIONS:
			Log.warn("AdventureTilemap: fog clear positions reached cap (%d)" % FOG_MAX_CLEAR_POSITIONS)
			break

	# Pad to cap (shader uniform array is fixed-size)
	while positions.size() < FOG_MAX_CLEAR_POSITIONS:
		positions.append(Vector2(-9999, -9999))

	_fog_rect.material.set_shader_parameter("clear_positions", positions)
	_fog_rect.material.set_shader_parameter("clear_count", min(_visited_tile_dictionary.size() + _highlight_tile_dictionary.size(), FOG_MAX_CLEAR_POSITIONS))
```

In `_mark_tile_visited()`, at the end (after `_update_visible_map()`), add:
```gdscript
	_update_fog_uniforms()
```

In `_process(delta)` (add the function if it doesn't exist), update each frame so fog stays in sync with camera pan/zoom:
```gdscript
func _process(_delta: float) -> void:
	_update_fog_uniforms()
```

- [ ] **Step 4: Smoke-test**

Run the game, start an adventure. The map should be heavily darkened by fog except in a soft circle around each visited or revealed-neighbor tile. As you walk, the fog should clear ahead of you. Pan the camera — fog cleared regions should follow the tiles, not stay glued to the screen.

- [ ] **Step 5: Commit**

```bash
git add assets/shaders/fog_of_war.gdshader \
  scenes/adventure/adventure_tilemap/adventure_tilemap.gd \
  scenes/adventure/adventure_tilemap/adventure_tilemap.tscn
git commit -m "feat(adventure): add fog-of-war shader with per-tile reveal"
```

---

### Task 18: Path preview Line2D + flowing shader binding

**Files:**
- Create: `scenes/adventure/path_preview/path_preview.gd`
- Create: `scenes/adventure/path_preview/path_preview.tscn`

- [ ] **Step 1: Write the script**

Create `scenes/adventure/path_preview/path_preview.gd`:

```gdscript
class_name PathPreview
extends Line2D

## PathPreview
## Renders a flowing animated line from the player's current tile through
## intermediate tiles to a hover-target tile. Uses the flowing_path shader.

func show_path(world_points: Array[Vector2]) -> void:
	clear_points()
	for p in world_points:
		add_point(p)
	visible = world_points.size() >= 2

func clear_path() -> void:
	clear_points()
	visible = false
```

- [ ] **Step 2: Build the scene**

Create a new scene at `scenes/adventure/path_preview/path_preview.tscn`:
```
PathPreview (Line2D)
- script: path_preview.gd
- width: 5.0
- default_color: Color(0.55, 0.78, 1.0, 0.85)
- begin_cap_mode: Round
- end_cap_mode: Round
- joint_mode: Round
- visible: false
- z_index: 7
- gradient: new Gradient with three stops:
    0.0 → Color(0.55, 0.78, 1.0, 0.0)
    0.5 → Color(0.78, 0.9, 1.0, 1.0)
    1.0 → Color(0.55, 0.78, 1.0, 0.0)
- material: new ShaderMaterial → flowing_path.gdshader
    - stroke_color: Color(0.78, 0.9, 1.0, 0.95)
    - scroll_speed: 1.5
    - pulse_strength: 0.5
```

Save.

- [ ] **Step 3: Commit**

```bash
git add scenes/adventure/path_preview/
git commit -m "feat(adventure): add PathPreview scene with flowing line shader"
```

---

### Task 19: Wire path preview to tile_hovered in adventure_tilemap

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`

- [ ] **Step 1: Instance PathPreview as a child of the root**

Open `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`. Right-click root → Instantiate Child Scene → `scenes/adventure/path_preview/path_preview.tscn`. Set `unique_name_in_owner = true`. Save.

- [ ] **Step 2: Wire hover signals to path preview**

In `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, add to NODE REFERENCES:

```gdscript
@onready var _path_preview: PathPreview = %PathPreview
```

In `_ready()`, after the existing `visible_map.tile_clicked.connect(_on_tile_clicked)` connection, add:
```gdscript
	visible_map.tile_hovered.connect(_on_tile_hovered)
	visible_map.tile_unhovered.connect(_on_tile_unhovered)
```

Add new private functions in the SIGNAL HANDLERS section:
```gdscript
func _on_tile_hovered(tile_coord: Vector2i) -> void:
	if _is_movement_locked:
		return
	var target_cube := visible_map.map_to_cube(tile_coord)
	if not _visited_tile_dictionary.has(target_cube) and not _highlight_tile_dictionary.has(target_cube):
		_path_preview.clear_path()
		# Apply HOVER_TARGET state if this tile has an overlay
		return

	# Compute path from current tile to hover target
	var path := visible_map.cube_pathfind(_current_tile, target_cube)
	var world_points: Array[Vector2] = []
	for cube in path:
		var world_pos := full_map.cube_to_local(cube) + full_map.position
		world_points.append(world_pos)
	_path_preview.show_path(world_points)

	# Highlight target tile
	if _tile_state_overlay.get_state(target_cube) != TileStateOverlay.TileState.CURRENT:
		_tile_state_overlay.set_tile_state(target_cube, TileStateOverlay.TileState.HOVER_TARGET, full_map.cube_to_local(target_cube) + full_map.position)

func _on_tile_unhovered() -> void:
	_path_preview.clear_path()
	# Reset overlays — call _update_visible_map to restore proper states
	_update_visible_map()
```

- [ ] **Step 3: Smoke-test**

Run the game, start an adventure. Hover over a revealed tile — a flowing cyan line should appear from your current tile through intermediate tiles to the target. Mouse off — the line should disappear and tile states return to normal.

- [ ] **Step 4: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_tilemap.gd \
  scenes/adventure/adventure_tilemap/adventure_tilemap.tscn
git commit -m "feat(adventure): wire path preview to hover signals"
```

---

### Task 20: Tile reveal stagger animation

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`

- [ ] **Step 1: Track newly-revealed tiles in _mark_tile_visited**

In `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, modify `_mark_tile_visited()` to capture the diff of new highlight tiles before regenerating:

```gdscript
func _mark_tile_visited(coord: Vector3i) -> void:
	var previous_highlights := _highlight_tile_dictionary.keys()
	_visited_tile_dictionary[coord] = true
	_highlight_tile_dictionary.clear()

	for c in _visited_tile_dictionary.keys():
		for neighbour in full_map.cube_neighbors(c):
			if neighbour in _encounter_tile_dictionary.keys() and neighbour not in _visited_tile_dictionary.keys():
				_highlight_tile_dictionary[neighbour] = HighlightType.VISIBLE_NEIGHBOUR

	# Find newly-revealed neighbors (in new highlights but not old)
	var newly_revealed: Array[Vector3i] = []
	for c in _highlight_tile_dictionary.keys():
		if not previous_highlights.has(c):
			newly_revealed.append(c)

	_update_visible_map()
	_update_fog_uniforms()
	_animate_reveal_stagger(newly_revealed)
```

Add the helper function:
```gdscript
func _animate_reveal_stagger(coords: Array[Vector3i]) -> void:
	var delay := 0.0
	for cube in coords:
		var icon: EncounterIcon = _encounter_icons.get(cube)
		if icon:
			icon.scale = Vector2(0.3, 0.3)
			icon.modulate.a = 0.0
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_interval(delay)
			tween.chain().tween_property(icon, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(icon, "modulate:a", 1.0, 0.3)
		delay += 0.05
```

- [ ] **Step 2: Smoke-test**

Run the game, start an adventure, walk forward. Each newly-revealed tile's encounter icon should pop in with a slight overshoot, staggered by 50ms per tile so the reveal sweeps outward instead of all appearing at once.

- [ ] **Step 3: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_tilemap.gd
git commit -m "feat(adventure): stagger tile reveal animation on visit"
```

---

### Task 21: Boss reveal hit-stop + flash + camera push

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`
- Modify: `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`

- [ ] **Step 1: Add a BossFlashRect to the scene**

Open `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`. Add a CanvasLayer child:
```
BossFlashLayer (CanvasLayer, layer = 10)
└── BossFlashRect (ColorRect)
    - layout: anchors full rect
    - color: Color(0.55, 0.78, 1.0, 0.0)
    - mouse_filter: Ignore
    - unique_name_in_owner: true
```
Save.

- [ ] **Step 2: Detect boss reveal and trigger the dramatic moment**

In `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, add to NODE REFERENCES:
```gdscript
@onready var _boss_flash_rect: ColorRect = %BossFlashRect

var _boss_revealed: bool = false
```

In `start_adventure()`, after `_current_tile = Vector3i.ZERO`, add:
```gdscript
	_boss_revealed = false
```

Modify `_animate_reveal_stagger` to check for boss tiles:
```gdscript
func _animate_reveal_stagger(coords: Array[Vector3i]) -> void:
	var delay := 0.0
	for cube in coords:
		var icon: EncounterIcon = _encounter_icons.get(cube)
		if icon:
			icon.scale = Vector2(0.3, 0.3)
			icon.modulate.a = 0.0
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_interval(delay)
			tween.chain().tween_property(icon, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(icon, "modulate:a", 1.0, 0.3)

		# Boss-tile dramatic reveal (only the first time)
		if not _boss_revealed:
			var encounter: AdventureEncounter = _encounter_tile_dictionary.get(cube)
			if encounter and encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_BOSS:
				_boss_revealed = true
				_play_boss_reveal(cube)

		delay += 0.05

func _play_boss_reveal(boss_cube: Vector3i) -> void:
	# Hit-stop
	Engine.time_scale = 0.25
	get_tree().create_timer(0.15 * 0.25).timeout.connect(func(): Engine.time_scale = 1.0)

	# Screen flash
	_boss_flash_rect.color = Color(0.55, 0.78, 1.0, 0.6)
	var flash_tween := create_tween()
	flash_tween.tween_property(_boss_flash_rect, "color:a", 0.0, 0.4)

	# Camera push toward boss
	var camera := get_viewport().get_camera_2d()
	if camera:
		var boss_world := full_map.cube_to_local(boss_cube) + full_map.position
		var current_pos := camera.global_position
		var push_target := current_pos.lerp(boss_world, 0.45)
		var push_tween := create_tween()
		push_tween.set_trans(Tween.TRANS_CUBIC)
		push_tween.set_ease(Tween.EASE_OUT)
		push_tween.tween_property(camera, "global_position", push_target, 0.5)
		push_tween.tween_property(camera, "global_position", current_pos, 0.7)
```

- [ ] **Step 2: Smoke-test**

Run the game, start an adventure with a boss tile within reach. Walk until the boss tile is revealed (becomes a neighbor of a visited tile). The first time it's revealed: time should slow briefly, the screen should flash cyan, the camera should push toward the boss tile and ease back. Subsequent visits should not re-trigger the effect.

- [ ] **Step 3: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_tilemap.gd \
  scenes/adventure/adventure_tilemap/adventure_tilemap.tscn
git commit -m "feat(adventure): boss reveal hit-stop + flash + camera push"
```

---

### Task 22: Stamina UI restyle (PanelStamina theme variant)

**Files:**
- Modify: `assets/themes/pixel_theme.tres`
- Modify: `scenes/adventure/adventure_view/adventure_view.tscn` (or wherever the stamina display is)

- [ ] **Step 1: Locate the existing stamina display node**

Search for the stamina UI node:
```bash
grep -r "stamina" '/c/Users/lione/Documents/Godot Games/RealProjects/EndlessPath/.claude/worktrees/stupefied-tesla/scenes/adventure/' -l
```
Identify the scene file containing the stamina label/bar. Likely candidates: `adventure_view.tscn`, or a child UI scene.

- [ ] **Step 2: Add the PanelStamina stylebox to pixel_theme.tres**

In the Godot editor, open `assets/themes/pixel_theme.tres`. Add a new Panel theme variant:
- Type: `PanelContainer`
- Variant name: `PanelStamina`
- Stylebox: new `StyleBoxFlat`
  - bg_color: `Color(0.04, 0.06, 0.11, 0.85)`
  - border_color: `Color(0.55, 0.71, 0.86, 0.4)`
  - border_width_left/top/right/bottom: 1
  - corner_radius_top_left/top_right/bottom_left/bottom_right: 4
  - content_margin_left/top/right/bottom: 8

Save the theme.

- [ ] **Step 3: Apply the variant to the stamina display**

In whichever scene contains the stamina display, set `theme_type_variation = "PanelStamina"` on the wrapping `PanelContainer`. If the display isn't currently inside a `PanelContainer`, wrap it in one.

- [ ] **Step 4: Smoke-test**

Run the game, start an adventure. The stamina display should have a dark translucent panel with a soft cyan border.

- [ ] **Step 5: Commit**

```bash
git add assets/themes/pixel_theme.tres scenes/adventure/
git commit -m "feat(ui): restyle stamina display with Spirit-themed PanelStamina variant"
```

---

### Task 23: Run full test suite + manual smoke test

**Files:**
- None (verification only)

- [ ] **Step 1: Run all unit tests**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all tests pass. The two new test files (`test_tile_state_overlay.gd`, `test_encounter_icon_config.gd`) must be in the output. Pre-existing tests must not regress.

- [ ] **Step 2: Manual smoke test — zone view**

Launch the game:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Verify in order:
1. ☐ Vignette visible at edges of the zone view
2. ☐ Mist drifts slowly in the background
3. ☐ Cyan + warm spirit motes drift across the map
4. ☐ Selected zone has a breathing aura (replaces old green Line2D)
5. ☐ Hovering an unlocked, non-selected zone makes a soft glow appear
6. ☐ Hovering the selected or a locked zone produces no hover glow
7. ☐ Locked zones display a dim "?" glyph
8. ☐ Glowing animated cyan lines connect adjacent unlocked zones
9. ☐ Clicking a zone tweens the camera with overshoot (TRANS_BACK)

- [ ] **Step 3: Manual smoke test — adventure view**

Start an adventure in the zone view. Verify in order:
1. ☐ Adventure view has vignette + mist + motes (atmosphere matches zone view)
2. ☐ Visited tiles have dim blue overlay sprites
3. ☐ Reveal-neighbor tiles have brighter cyan overlays
4. ☐ Current tile has a brighter, larger breathing aura
5. ☐ Each encounter type renders distinctly: combat (red blades), elite (violet star), boss (gold ornamental sigil with rotating ring), rest (green shrine), treasure (gold gem)
6. ☐ Boss icon has a continuously rotating ornamental ring + breathing pulse
7. ☐ Visited encounter icons are dimmed
8. ☐ Trap tiles do NOT show an icon until walked onto
9. ☐ Hovering a revealed tile draws a flowing cyan path line from current tile to target
10. ☐ Hovering also brightens the target tile overlay
11. ☐ Mouse off → path line disappears, target tile reverts
12. ☐ Walking onto a new tile triggers a staggered reveal animation for new neighbors (icons pop in over ~150-300ms)
13. ☐ First time a boss is revealed: brief hit-stop + cyan screen flash + camera pushes toward boss and eases back
14. ☐ Fog-of-war darkens the map outside the visited radius and stays correct as you pan/zoom
15. ☐ Stamina display has the new dark + cyan PanelStamina styling
16. ☐ Frame rate stays ≥ 60fps during ambient and movement (check Godot debugger or a quick eyeball test)

- [ ] **Step 4: If any item fails, file a fix as a follow-up task**

If any checklist item fails, do not mark this task done. File a fix and re-run the relevant smoke test. Only commit a "verification complete" empty marker once everything passes.

- [ ] **Step 5: Final commit (verification marker, only if everything passed)**

```bash
git commit --allow-empty -m "test(ui): tilemap visual overhaul smoke + unit verification complete"
```

---

## Self-Review Notes

- **Spec coverage:** Each section of the spec maps to at least one task: atmosphere (T1-T5), zone polish (T6-T11), tile state overlay (T12-T13), encounter icons (T14-T16), fog (T17), path preview (T18-T19), reveal/boss animations (T20-T21), stamina (T22), verification (T23).
- **No placeholders:** Every code-touching step contains the actual code. Tasks that depend on art assets (T2, T14) describe the assets concretely and let the implementer author them in any tool.
- **Type consistency:** `TileStateOverlay.TileState.X` enum members are used identically across T12, T13, T19. `EncounterIcon.configure_for_type()` and `set_visited()` signatures match across T14, T15, T16. `_tile_state_overlay`, `_encounter_icons`, `_path_preview`, `_fog_rect`, `_boss_flash_rect` member names are consistent everywhere they appear.
- **Scope:** 23 tasks, each ~10-30 minutes of focused work. The plan can be paused after any task and the build will still launch — every task ends with a commit and a smoke test.
