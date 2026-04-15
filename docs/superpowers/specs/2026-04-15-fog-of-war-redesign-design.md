# Adventure Fog of War Redesign

> **Status:** Approved for implementation

## Overview

Today's adventure-map fog of war reveals visited tiles' neighbors with their full encounter information visible — combat icons, treasure chests, rest sites, etc. all show up immediately. This eliminates the sense of exploration: the player knows exactly what's around them at all times and never has to commit to walking into the unknown.

This spec redesigns the fog of war so that **revealed neighbors stay mysterious** until the player physically visits them. The boss is the only exception — once revealed, it's clearly visible so the player has a long-term goal.

## Goals

1. Players don't know what type of encounter is on a tile until they visit it
2. Boss tiles are the exception — visible as boss as soon as they're revealed
3. Visited tiles get a clear "completed" indicator after the player moves away
4. The visual treatment matches the moody/cultivation atmosphere (smoke veil + question mark)

## Non-goals

- Replacing the existing screen-space fog shader (`fog_of_war.gdshader`) — it stays as the deep-fog layer for fully unrevealed tiles
- Changing how reveal range works (still 6 hex neighbors of visited tiles)
- Adding new encounter types or changing pathfinding behavior
- Fade-in/fade-out polish for the fog veil transitions (deferred)

## Tile state machine

Every adventure tile is in exactly one state at a time:

| State | When | Visuals |
|---|---|---|
| **Hidden** | Tile is far from all visited tiles. Outside the screen-space fog clear radius. | Covered by `fog_of_war.gdshader` deep darkness. The forest tile is technically rendered but invisible behind the fog. |
| **Revealed** | Tile is a neighbor of a visited tile (in `_highlight_tile_dictionary` with type `VISIBLE_NEIGHBOUR`), and is NOT a boss. | Screen-space fog clears (existing behavior). Forest art is visible underneath. An animated **smoke veil** sprite + a centered **question mark** icon are drawn on top, hiding the encounter type. |
| **Revealed (boss exception)** | Same as Revealed, but the encounter type is `COMBAT_BOSS`. | Screen-space fog clears. **No** smoke veil, **no** question mark. The boss encounter icon is shown directly. The existing `_play_boss_reveal()` dramatic sequence (camera push, screen flash, hit-stop) still triggers on first reveal. |
| **Currently here** | `coord == _current_tile` and the tile is in `_visited_tile_dictionary`. | Screen-space fog clears. Forest art visible. Encounter icon at full opacity (or no icon for NoOp tiles). Encounter info panel may be active. |
| **Completed** | Tile is in `_visited_tile_dictionary` and `coord != _current_tile`. | Screen-space fog clears. Forest art visible. Encounter icon at ~0.45 alpha (faded), with a small green checkmark badge in the bottom-right. NoOp tiles get no marker — they look like regular forest. |

## New components

### 1. Smoke spritesheet pack script

**Path:** `scenes/adventure/scripts/pack_smoke_spritesheet.py`

A one-shot Python script (re-runnable) that:
1. Reads the 25 source frames from `assets/Black smoke/blackSmoke{NN}.png` (00–24)
2. Resizes each frame to 164×190 (matches the project's hex tile bounds, mild aspect squish on the amorphous smoke is acceptable)
3. Packs them into a 5×5 grid (820×950 total)
4. Writes the output to `assets/sprites/atmosphere/smoke_veil_spritesheet.png`

Style mirrors the existing `pack_hex_atlas.py` script (LANCZOS resize, no quantization since smoke gradients should stay smooth). Frame N maps to grid cell `(N % 5, N // 5)`.

### 2. FogVeilSprite class

**Files:**
- `scenes/adventure/fog_veil_sprite.gd` — `class_name FogVeilSprite extends Sprite2D`
- `scenes/adventure/fog_veil_sprite.tscn` — packed scene with sprite + question mark child

**Responsibilities:**
- Renders the smoke spritesheet using `hframes=5, vframes=5`
- Cycles frames in `_process` at a configurable FPS
- Has a child `QuestionMark: Sprite2D` using `question_mark.png`, centered on the hex, z-indexed above the smoke layer

**Exports:**
- `@export_range(1.0, 30.0, 0.5) var animation_fps: float = 6.0` — slow ethereal drift, tunable in the inspector

**On `_ready`:** picks a random starting frame so adjacent veils don't sync visually (same trick the atmosphere mist sprites use).

**Public API:** none beyond Sprite2D's built-ins. Show/hide via `visible`, position via `global_position`. The animation runs autonomously.

### 3. Extended EncounterIcon — completed state

**File:** `scenes/adventure/encounter_icon/encounter_icon.gd`

**New public method:**
```gdscript
## Marks this icon as completed (faded look + green checkmark badge).
## Used when the player has visited and moved on from an encounter tile.
func set_completed(completed: bool) -> void
```

**Behavior:**
- `completed = true`: drops `_frame.modulate.a` and `_glyph.modulate.a` to ~0.45, shows the `_checkmark` child sprite
- `completed = false`: restores the configured opacities, hides the checkmark

**Scene change:** add a new `Checkmark: Sprite2D` child to `encounter_icon.tscn`, using `assets/sprites/adventure/encounter_glyphs/checkmark.png`, positioned bottom-right of the encounter icon (offset roughly `(28, 28)` from center), `unique_name_in_owner = true`, `visible = false` initially.

**Note on `set_visited`:** the existing `set_visited(visited: bool)` method dims the entire icon to alpha 0.45 when visited. Once `set_completed` exists, `set_visited` becomes redundant for the new fog-of-war flow — `_update_visible_map` will use `set_completed` instead. We keep `set_visited` in place to avoid breaking the trap-encounter reveal logic (`if not _is_visited: return false` for trap tiles), but adventure_tilemap.gd will only call `set_completed` from the new state-update loop.

## adventure_tilemap.gd changes

### New state

```gdscript
@onready var _fog_veil_container: Node2D = %FogVeilContainer
var _fog_veil_sprites: Dictionary[Vector3i, FogVeilSprite] = {}
const FogVeilSpriteScene := preload("res://scenes/adventure/fog_veil_sprite.tscn")
```

### New scene node

A new `FogVeilContainer: Node2D` is added to `adventure_tilemap.tscn`, positioned between the tilemap layers and the encounter icon container in the z-order. Approximate `z_index = 4` (above the visible_map tiles which sit at the layer's default, below the encounter icon container at z 6).

### `_update_visible_map()` rewrite

Pseudocode:

```
visible_map.clear()
highlight_map.clear()

# Don't clear fog veils up front — we diff them below

build visible_coords from visited + revealed (current logic preserved)

# 1. Render the forest tile under every visible coord
for each coord in visible_coords:
    visible_map.set_cell_with_source_and_variant(
        FOREST_ATLAS_SOURCE_ID, 0,
        full_map.cube_to_map(coord),
        _get_random_forest_atlas_coords(coord),
    )

# 2. Encounter icons for visited tiles (current + completed)
#    NoOp tiles get no icon at all.
for each coord in visited_tile_dictionary:
    encounter = _encounter_tile_dictionary[coord]
    if encounter is NoOpEncounter:
        despawn encounter icon if present
        continue
    spawn or update encounter icon for coord
    icon.set_completed(coord != _current_tile)

# 3. Revealed neighbors — fog veils, except boss
revealed_coords = highlight_tile_dictionary keys with type VISIBLE_NEIGHBOUR
for each coord in revealed_coords:
    encounter = _encounter_tile_dictionary[coord]
    if encounter and encounter.encounter_type == COMBAT_BOSS:
        despawn fog veil if present
        spawn or update encounter icon (set_completed false)
    else:
        despawn encounter icon if present  # in case it was previously a boss-revealed tile somehow
        spawn fog veil at coord if not already present
        position the sprite at full_map.cube_to_local(coord) + full_map.position

# 4. Despawn fog veils whose coord is no longer revealed-and-not-boss
for coord in _fog_veil_sprites.keys() snapshot:
    if coord in visited_tile_dictionary or coord not in revealed_coords or encounter_at(coord) is COMBAT_BOSS:
        free + erase fog veil
```

### Encounter icon spawn helper

The current `_update_cell_highlight(coord)` function instantiates an `EncounterIcon` if missing and configures it. Refactor slightly:
- Extract the spawn logic into `_spawn_or_get_encounter_icon(coord) -> EncounterIcon`
- Call it from both the visited-loop and the boss-revealed-branch
- The encounter icon dictionary key remains the cube coord

### `stop_adventure()` cleanup

Add fog veil cleanup alongside the existing encounter icon cleanup:
```gdscript
for sprite in _fog_veil_sprites.values():
    sprite.queue_free()
_fog_veil_sprites.clear()
```

## Existing systems untouched

- **`fog_of_war.gdshader`** — keep as-is. Still clears holes around visited + revealed coords. The smoke veil sprites sit on top of cleared fog regions.
- **`HexHoverSelector`** — keep as-is. Hover ring works on any visited or revealed tile (current behavior).
- **`_animate_reveal_stagger()`** — keep as-is. Still triggers when new neighbors get revealed; encounter icons get the stagger animation when revealed (which now only applies to boss icons since other types are hidden under fog veils).
- **`_play_boss_reveal()`** — keep as-is. Still triggers on first boss reveal.
- **Path preview, click-to-walk, fog-of-war uniform updates** — keep as-is. Players can still click any visited or revealed tile to walk there.
- **`HexagonTileMapLayer.set_cell_with_source_and_variant`** — keep the new optional `atlas_coords` parameter from the previous PR.

## File summary

**New:**
- `scenes/adventure/scripts/pack_smoke_spritesheet.py`
- `assets/sprites/atmosphere/smoke_veil_spritesheet.png` (generated by the script)
- `scenes/adventure/fog_veil_sprite.gd`
- `scenes/adventure/fog_veil_sprite.tscn`

**Already moved (out of band):**
- `assets/checkmark.png` → `assets/sprites/adventure/encounter_glyphs/checkmark.png`
- `assets/question_mark.png` → `assets/sprites/adventure/encounter_glyphs/question_mark.png`

**Modified:**
- `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn` — add `FogVeilContainer` node
- `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` — fog veil management, new completion state for encounter icons
- `scenes/adventure/encounter_icon/encounter_icon.gd` — new `set_completed()` method
- `scenes/adventure/encounter_icon/encounter_icon.tscn` — add Checkmark child sprite

**Unchanged:**
- `assets/shaders/fog_of_war.gdshader`
- `scenes/tilemaps/hex_hover_selector.*`
- All zone tilemap files
- All encounter type glyph PNGs

## Out of scope (deferred)

- Smooth fade-out animation when smoke clears as a tile transitions revealed → visited. The current sharp transition is acceptable; polish can be added later if it feels jarring.
- Animated reveal-in animation for newly-spawned smoke veils (could fade in over the existing reveal stagger). Default is to use the existing stagger behavior, no extra animation per veil.
- Hover behavior tweaks for fogged tiles. The existing path preview and hex selector ring already work on revealed tiles and that behavior is preserved.
- Pre-planning a multi-step path through fog beyond what `cube_pathfind` already provides.
- Replacing or deprecating `EncounterIcon.set_visited()`. The trap-encounter logic still uses it; we leave it alone.

## Acceptance criteria

1. Walking onto a tile reveals its 6 neighbors but their type stays hidden behind smoke + question mark
2. Boss tiles are visible as boss (no smoke, no question mark) as soon as they're revealed
3. Walking onto a tile that was previously fogged shows the encounter icon at full opacity and triggers the encounter normally
4. Walking away from a visited encounter tile shows the icon dimmed + checkmark badge in the bottom-right
5. NoOp tiles get no completion marker (they look like normal forest after visiting)
6. The fog veil sprites animate with a subtle smoke drift, each starting at a random frame (no synchronized swirling)
7. All existing GUT tests still pass
8. No GDScript parse/compile errors on `--headless --import`
