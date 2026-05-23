# Map Preview Tool — Design Spec

**Date**: 2026-04-23
**Scope**: Editor-only `@tool` scene for previewing adventure map generation without launching the game.

## Summary

A standalone Godot `@tool` scene (`scenes/tools/map_preview.tscn`) that lets the designer drag an `AdventureData.tres` into the inspector, press **Generate**, and see the fully generated hex map — tiles and encounter icons — rendered directly in the 2D editor viewport. Deterministic reproduction via a seed field. Reuses the existing `AdventureMapGenerator`, `HexagonTileMapLayer`, and `EncounterIcon` scenes with no gameplay (no movement, no fog, no combat).

## Problem

Today, seeing what a generated map looks like requires:

1. Edit `AdventureData.tres` (e.g. tweak `num_extra_edges` or quota counts).
2. Launch the game (`F5` in editor).
3. Navigate to the zone that exposes the adventure.
4. Start the adventure.
5. Manually walk the character tile by tile to clear fog-of-war and reveal the full map.

This is a slow, high-friction loop — especially when iterating on numerical parameters (`sparse_factor`, `max_distance_from_start`, `num_extra_edges`) that have subtle effects best judged visually. The loop is also polluted by unrelated game state (zone unlocks, Madra cost gate, stamina budget).

## Goals

- **G1** — Drop an `AdventureData.tres`, press one button, see the full generated map in the Godot editor.
- **G2** — Reproduce a specific generation via a seed field (non-zero seed = deterministic; zero = fresh random each press).
- **G3** — Visual fidelity matches the in-game map (same forest tileset, same `EncounterIcon` glyphs).
- **G4** — Zero impact on the shipping game: no autoload dependencies at editor time, no runtime behavior change to the generator.
- **G5** — Structured so future overlays (MST edge lines, distance-from-origin labels, anchor-vs-filler tinting) can be layered in without rewriting the core.

## Non-Goals

- **NG1** — Gameplay simulation. No movement, no combat, no fog-of-war, no encounter resolution.
- **NG2** — Adventure authoring UI. The tool consumes existing `.tres` files; it does not create or edit them.
- **NG3** — Statistical analysis (generate N maps, aggregate stats). Deferred — would be a separate follow-up tool.
- **NG4** — Live regeneration on inspector edits. Explicit button only (keystroke-time regen causes flicker when editing nested quota arrays).
- **NG5** — Running inside the existing `adventure_tilemap.tscn`. That scene stays pure-runtime.

## Architecture

### Scene layout

```
MapPreview (Node2D, @tool)                    — scripts/tools/map_preview.gd
  PreviewTileMap (HexagonTileMapLayer)        — instanced from scenes/tilemaps/hexagon_tile_map_layer.tscn
  EncounterIconContainer (Node2D, z=6)        — parents spawned EncounterIcon instances
  OriginMarker (Node2D wrapper + Label child) — small "START" marker at Vector2.ZERO
  StatsLabel (Label)                          — one-line summary, CanvasLayer overlay top-left
```

No `Camera2D` — in a `@tool` scene opened in the editor, Godot's 2D editor viewport uses its own camera (Camera2D.current is ignored at edit time). The user frames the map with standard editor pan/zoom (`F` to focus selection, mouse wheel to zoom). The scene's content sits at `Vector2.ZERO` so "frame view" is always the same gesture.

### Rejected alternatives

- **Editor plugin dock (`addons/map_preview/`)** — Overkill. Requires `EditorPlugin` scaffolding, custom dock UI, and registration in `project.godot`. No payoff for single-dev use.
- **`@tool` on `adventure_tilemap.tscn`** — Dangerous. Mixes runtime scene with edit-time behavior; every existing method would need an `if Engine.is_editor_hint()` guard; regressions in the running game become likely.

### Exported properties (`map_preview.gd`)

| Field | Type | Default | Notes |
|---|---|---|---|
| `adventure_data` | `AdventureData` | `null` | Drag a `.tres` here. |
| `seed` | `int` | `0` | `0` = fresh random on each press; non-zero = deterministic. |
| `generate_button` | `Callable` (via `@export_tool_button`) | — | Runs `_generate()`. |
| `clear_button` | `Callable` (via `@export_tool_button`) | — | Wipes the tilemap and all icons. |

`@export_tool_button` is the Godot 4.4+ pattern for putting an invokable button directly in the inspector. Example:

```gdscript
@export_tool_button("Generate", "Play") var generate_button: Callable = _generate
@export_tool_button("Clear", "Remove") var clear_button: Callable = _clear
```

## Detailed Behavior

### `_generate()` flow

```
1. Guard: if not Engine.is_editor_hint(): return
2. Validate inputs
   - If adventure_data == null → push_warning("MapPreview: no adventure_data set"); return
   - errors = adventure_data.validate()
   - If errors.size() > 0 → push_error for each, return
3. Seed RNG
   - If seed == 0: randomize()
   - Else: seed(seed)
4. Generate
   - gen = AdventureMapGenerator.new()
   - gen.set_adventure_data(adventure_data)
   - gen.set_tile_map(preview_tile_map)
   - tiles: Dictionary[Vector3i, AdventureEncounter] = gen.generate_adventure_map()
   - If tiles.is_empty() → push_warning("MapPreview: generator returned empty map"); return
5. Render (see section below)
6. Update stats label
```

### Rendering

`_render(tiles: Dictionary[Vector3i, AdventureEncounter])`:

1. **Clear previous state**
   - `preview_tile_map.clear()`
   - Free every child of `EncounterIconContainer`.
2. **Paint base tiles**
   - For each `coord` in `tiles`: `preview_tile_map.set_cell_with_source_and_variant(FOREST_ATLAS_SOURCE_ID, 0, preview_tile_map.cube_to_map(coord), HexForestAtlas.pick(coord))`.
   - `HexForestAtlas.pick(coord)` is a static helper at `scripts/utils/hex_forest_atlas.gd` extracted from `AdventureTilemap._get_random_forest_atlas_coords()`. Same deterministic-by-coord hash, shared call site.
3. **Position origin marker**
   - Show the pre-placed `OriginMarker` node at world position `Vector2.ZERO` (where `cube_to_local(Vector3i.ZERO)` lands, which is the scene origin). Set `visible = true`. The marker is a `Node2D` wrapper with a `Label` child reading "START" — the wrapper is what the script positions, and the Label child is offset slightly negative so the text sits visually over the origin hex. It only needs to exist so the designer can tell the origin apart from anchor tiles at a glance.
4. **Spawn encounter icons**
   - For each `coord` whose encounter is not `NoOpEncounter` (including the boss):
     - Instance `EncounterIcon.tscn`, add to `EncounterIconContainer`.
     - Position at `preview_tile_map.cube_to_local(coord)`.
     - Configure with `encounter.encounter_type`, treating the tile as visited + not-completed so the icon renders fully lit.

The designer frames the view using the editor's standard 2D navigation (`F` to focus, wheel to zoom). No in-scene camera framing step.

### Stats label

Single-line summary, top-left anchor, updated after every `_generate()`:

```
15 tiles · 4 combat · 2 elite · 1 boss · 1 rest · 2 treasure · seed: 42
```

Breakdown is computed by bucketing the `tiles` dict by `AdventureEncounter.encounter_type` (plus a separate `boss` count for `boss_encounter`). Regeneration attempts are not currently exposed by the generator — out of scope for this pass (see Open Questions).

### `_clear()` flow

Wipes tilemap cells, frees icons, hides the origin marker, blanks the stats label. No generation runs.

## `@tool`-safety refactor to `AdventureMapGenerator`

The generator currently calls `Log.error/warn/info`. `Log` is an autoload and isn't available at editor time, so the tool would crash on any error path. Fix:

1. Add `@tool` to the top of `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`.
2. Replace:
   - `Log.error(msg)` → `push_error(msg)`
   - `Log.warn(msg)` → `push_warning(msg)`
   - `Log.info(msg)` → drop (these are verbose informational messages about eligibility skips; they don't carry debugging value worth preserving).

`push_error` and `push_warning` are Godot built-ins that work identically at editor and runtime — they route to the Output / Debugger panels. Existing unit tests (`tests/unit/test_adventure_map_generator.gd`) don't assert on `Log.*` calls, so this is a pure logging swap with no test impact.

`NoOpEncounter` is a plain `Resource` with no autoload deps. `HexagonTileMapLayer` is already `@tool` (addon). No other editor-safety work required.

## Future hooks (option B — algorithm overlays)

The scene is structured so these can be added later as optional child containers without touching `_generate()` or the generator:

- **MST edges** — `MstEdgeContainer` holding `Line2D` nodes between anchor pairs. Would require the generator to expose its `mst_edges` (currently local to `_generate_paths()`).
- **Distance labels** — `DistanceLabelContainer` with a `Label` per coord showing `cube_distance(Vector3i.ZERO, coord)`.
- **Anchor/filler tinting** — overlay semi-transparent color rects on tiles, keyed by encounter placement type.

These overlays would be gated behind additional `@export var show_mst_edges: bool` flags on the preview script. Out of scope for this spec — listed here to validate that the core architecture accommodates them.

## Files changed / added

| File | Action | Purpose |
|---|---|---|
| `scenes/tools/map_preview.tscn` | **new** | The preview scene (nodes + default layout). |
| `scripts/tools/map_preview.gd` | **new** | `@tool` script on the scene root; exports, generate, render, clear. |
| `scripts/utils/hex_forest_atlas.gd` | **new** | Shared helper: `static func pick(coord: Vector3i) -> Vector2i`. Used by both `AdventureTilemap` and `MapPreview`. |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | **modified** | Swap inline variant-picker for `HexForestAtlas.pick(coord)` call. |
| `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` | **modified** | Add `@tool`; swap `Log.*` calls for `push_error` / `push_warning`. |

## Testing

**Manual verification loop** (the tool is the test for itself):

1. Open `scenes/tools/map_preview.tscn` in the Godot editor.
2. Drag `resources/adventure/data/shallow_woods.tres` into the `adventure_data` slot.
3. Press **Generate** — verify:
   - Hex tiles render with forest variants.
   - Origin cell has the grey overlay marker.
   - Boss icon appears at the farthest anchor.
   - 2 rest icons (aura well, refugee camp) appear at anchor distance.
   - Combat icons fill the path tiles.
   - Stats label matches expected counts (1 boss, 7 combat, 2 rest, 0 treasure for shallow_woods).
4. Set `seed = 42`, press Generate twice — verify identical layouts.
5. Set `seed = 0`, press Generate three times — verify different layouts.
6. Press **Clear** — verify tilemap empties, icons disappear, stats label blanks.
7. Clear the `adventure_data` slot, press Generate — verify a push_warning appears in the Output panel and no crash.

**Automated tests** — no new GUT tests required. The `@tool`-safety refactor to the generator is covered by existing `test_adventure_map_generator.gd` tests, which continue to pass because behavior is unchanged (only log calls swapped).

## Open Questions / Risks

- **Regeneration attempt count** — the generator's up-to-5-attempt retry loop isn't exposed via its return value. The stats label can't show "regen attempts: N" without a small generator change. Deferring: either add a `last_regen_attempts: int` field on the generator later, or live without it.
- **`@export_tool_button` availability** — confirmed present in Godot 4.4+. Project is on 4.6, so supported.
- **Icon-rendering fidelity at edit time** — `EncounterIcon` is not `@tool`. Spawning it in the editor may skip its `_ready()` logic or mis-render animations (boss skull anim in particular). If this surfaces during build, the mitigation is to either `@tool` the icon scene or use a simplified static `TextureRect` in the preview keyed by `encounter_type`. Flag during implementation.
