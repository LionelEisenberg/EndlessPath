# Tilemap Visual Overhaul Design Spec

> **Status:** DESIGN · awaiting implementation plan
> **Scope:** Visual polish for `ZoneTilemap` and `AdventureTilemap`
> **Non-structural:** No changes to tile data structures, hex coordinates, pathfinding, encounter resource classes, or zone data

## Overview

Redesign the visual presentation of both tile maps (zone view and adventure view) to feel more alive, readable, and responsive. The current maps are functional but flat — tiles render from a tileset with swapped variants, encounter icons are basic overlays, and the only ambient polish is a green pulse shader on the selected zone. This overhaul layers atmosphere (vignette, mist, spirit motes), clarity (tile state languages, encounter icon frames), and feedback (hover, pathfind preview, current-tile aura) onto the existing architecture without touching the data model.

The aesthetic direction is **Spirit Atmosphere**: moody, ethereal, heavy vignette, drifting mist, spirit motes, full-body auras on key tiles. Builds directly on the existing 12-layer parallax Spirit Valley background and the `pulse_node.gdshader`.

The motion target is **Balanced Juice**: hover scales tiles +4%, click spawns ring bursts, selected tiles have a 2.5s breathing pulse, eased camera transitions with slight overshoot, 40-60ms hit-stop on major reveals, screen shake reserved for rare dramatic moments (boss reveals, zone unlocks).

## Goals

- **Atmosphere** — the maps should feel like living cultivation realms, not static grids
- **Readability** — tile states (visited / current / revealed / hidden / hover-target) and encounter types (combat / elite / boss / rest / treasure / unknown) must be distinguishable at a glance without reading any text
- **Responsive feedback** — every interaction (hover, click, pathfind preview, tile reveal) produces visual feedback within 1-2 frames of input
- **Boss climax** — adventure boss tiles must visually register as the climactic moment of the run
- **Zero data-structure changes** — everything lives in new scenes, shaders, particle systems, and node children of the existing tilemap layers

## Non-Goals

- No new encounter types
- No new zone types (only Spirit Valley and Test Zone exist; per-biome theming is explicitly out of scope until more zones are added)
- No pathfinding algorithm changes
- No map generation changes (MST algorithm in `adventure_map_generator.gd` is untouched)
- No rework of the camera controller scripts — only new tween code using them
- No audio/SFX — this spec is purely visual (audio is a separate future pass)
- No changes to the Combat view — only the tilemap (exploration) side of the adventure view

## Aesthetic Direction: Spirit Atmosphere

| Element | Treatment |
|---------|-----------|
| Palette | Cool base (#0a0e1a → #14101f), cyan spirit highlights (#80c0ff, #c0e4ff), warm accents (#ff9040, #ffc870) for the player/treasure, red/orange for boss |
| Lighting | Heavy radial vignette; map edges fade to black. Bright elements bloom and feel like light sources in darkness |
| Motion | Slow ambient drift (mist), medium-pace pulses (spirit motes, neighbor tiles), fast micro-interactions (hover, click burst). Nothing rushed. |
| Textures | Existing parallax art untouched. Tile base textures reused. Polish is layered on top through shaders, particles, sprites — never by re-painting tiles |

## Zone View · Target State

### New visual layers (top to bottom in z-order)

1. **Parallax background** (existing, kept) — 12 layers in `zone_view_background.tscn`
2. **Ambient mist layer** (new) — 2-3 large (200-300px) blurred sprites with slow 14-16s ease-in-out `Tween` drift animations. Rendered on a dedicated `CanvasLayer` behind the tilemap but in front of the parallax.
3. **Zone tilemap** (existing, kept) — `HexagonTileMapLayer` with existing tile variants
4. **Glowing path lines** (new) — `Line2D` children of `ZoneTilemap`, one per pair of adjacent unlocked zones. Gradient stroke (transparent → cyan → transparent), soft glow via texture or shader. Adjacency is derived at runtime from the hex-grid neighbors of each zone's `tilemap_location` (`HexagonTileMapLayer` exposes `get_surrounding_cells()`) — any two zones whose `tilemap_location` values are hex-neighbors get a path between them. No new data or explicit adjacency graph needed.
5. **Current zone aura** (new, replaces existing thin `PulseNode` line) — a `Sprite2D` with a soft radial glow texture + `ShaderMaterial` that breathes brightness ±15% on a 2.5s loop. Follows the selected zone position.
6. **Hover glow** (new) — ephemeral `Sprite2D` that appears on mouse-over a hex cell, scales the cell 1.04, and adds an inner glow. Driven by `hexagon_tile_map_layer.gd` input code (extend existing `_input` to detect `MOUSE_MOTION`).
7. **Locked zone silhouettes** (new rendering for existing locked tiles) — locked zones still use the existing `LOCKED_SOURCE_ID` variant but now display a centered "?" glyph (a `Label` child per locked tile, with a serif font + drop shadow). Glyph font and color live in the existing pixel theme.
8. **Character** (existing, kept) — `CharacterBody2D` with 8-directional walk cycles
9. **Spirit motes** (new) — `GPUParticles2D` node with 40-60 small quad particles (3px white/cyan and 3px warm yellow), random drift velocities, 2.5s lifetime loop, gentle sine-wave alpha. Two emitters (cyan + warm) as siblings on a `CanvasLayer` between the tilemap and the vignette.
10. **Vignette shader** (new) — full-viewport `ColorRect` on a top `CanvasLayer` with a radial-gradient fragment shader, darkening outside a configurable radius. Shader parameters: `vignette_radius` (default 0.5), `vignette_softness` (0.4), `vignette_color` (black). Stretches with viewport.

### Interactions

| Input | Response |
|-------|----------|
| Mouse motion over an unlocked zone | Hover glow appears, tile scales 1.04, inner cyan glow, cursor changes to pointer |
| Mouse motion over a locked zone | No hover response (stays dim) |
| Click unlocked zone | Existing selection logic runs. Selected-zone aura tweens from the old selected position to the new one over 0.4s using `Tween` with `TRANS_CUBIC` / `EASE_OUT`. Camera tweens to the new zone center with a slight overshoot (0.5s `TRANS_BACK` `EASE_OUT`). One-shot ring burst particle emitter fires at the new selected zone. |
| Click locked zone | Brief "denied" shake of the "?" glyph (±3px for 0.15s) |
| Zone unlock event (from `UnlockManager.condition_unlocked`) | Locked silhouette fades out over 0.5s, new zone variant fades in, glowing path line draws itself from the nearest unlocked neighbor with a 0.8s flow animation. Camera briefly pulls to frame the new zone. |

## Adventure View · Target State

### New visual layers (top to bottom in z-order)

1. **Background** — currently uses default Godot viewport clear color. Replace with the same Spirit Atmosphere gradient (`ColorRect` with a vertical gradient shader: deep blue/purple top, near-black bottom) as a background layer. This gives every adventure a consistent base regardless of generation seed.
2. **Ambient mist layer** (new) — same pattern as zone view: 3 large blurred sprites, slow drift.
3. **Fog-of-war shader layer** (new) — a `Sprite2D` or `ColorRect` the size of the full map bounds, with a shader that darkens the map radially from the player position plus known-visited tile positions. Implemented as a fragment shader taking an array of Vector2 "clear" positions; anywhere not within `clear_radius` of a cleared position is darkened. Gradient falloff creates the soft fog edge.
4. **Adventure full tilemap** (existing, kept) — `AdventureFullMap` hidden layer for pathfinding
5. **Adventure visible tilemap** (existing, kept) — `AdventureVisibleMap` renders visited + revealed-neighbor tiles using existing variants
6. **Tile state overlay layer** (new `CanvasItem`) — per-tile `Sprite2D` children for hover/target/current-tile-aura effects. This layer handles all non-tileset visual polish on tiles.
7. **Encounter icon layer** (existing `AdventureHighlightMap`, augmented) — replaces the simple single-sprite-per-tile overlays with new encounter icon sprites. Each icon is a `Sprite2D` (or packed scene) with distinct color palette, glyph, and frame. Boss tiles get a large ornamental ring child. See Encounter Icon Language section.
8. **Path preview layer** (new) — `Line2D` node that renders the pathfind result between current tile and hovered target. Stroke is a flowing gradient (shader-driven, cycling `UV.x` offset). Updates on mouse motion.
9. **Character / player marker** (existing, visual upgrade) — the existing `CharacterBody2D` stays, but gains an additive glow `Sprite2D` child (warm gold orb) with a 2s breathing pulse tween. Draws above tiles.
10. **Spirit motes** (new) — same particle system as zone view, adjusted to the adventure view viewport
11. **Vignette shader** (new, same asset as zone view)
12. **Stamina UI** (existing, restyle) — existing stamina display gets Spirit-themed stylebox: cyan gradient bar, `PanelStamina` theme variant with dark translucent background and cyan border

### Tile State Language

All five states are visually distinct without reading text or labels:

| State | Base color | Border | Effects | When |
|-------|-----------|--------|---------|------|
| **Hidden** | Near-black (#0a0f1a) | Dashed, dim cyan | 0.5 α, behind fog shader | Tile exists in full map but not adjacent to a visited tile |
| **Reveal** | Mid-blue (#2d4164) | Solid bright cyan 1.5px | Border brightness pulse 2s loop (replaces existing dark-red `PulseNode`) | Tile is adjacent to a visited tile, clickable |
| **Visited** | Dim desaturated blue | Muted | Saturation 0.5, brightness 0.75 | Player has moved onto this tile previously |
| **Current** | Bright cyan (#64b4f0) | White 2px | Full-body aura, 2.5s breathing pulse | The tile the player is currently on |
| **Hover-target** | Brightest cyan (#a0e0ff) | White 2px | Scale 1.05, inner bloom | Mouse is hovering a revealed tile |

**Implementation note:** Tile state visuals are rendered as sprite overlays *on top of* the existing tile variants, not by adding new variants. This means:
- The `AdventureVisibleMap` continues to use existing `YELLOW_TILE_VARIANT_ID` (now just "revealed baseline")
- A new child `Node2D` (`TileStateOverlay`) contains `Sprite2D` children positioned at tile world coordinates
- State transitions are pure Tween animations on overlay properties — no tilemap `set_cell` calls needed for state changes
- The existing `_visited_tile_dictionary` and `_highlight_tile_dictionary` drive which overlays exist

### Encounter Icon Language

Six distinct color/frame languages, rendered as `Sprite2D` children of the highlight map at tile centers. Each is a packed scene (`encounter_icon.tscn`) instanced with a type-specific configuration.

| Type | Color | Glyph | Frame size | Effects |
|------|-------|-------|------------|---------|
| `COMBAT_REGULAR` | Red (#d88070) | Crossed blades | 34px circle | Inner glow, 0.5 α when visited |
| `COMBAT_AMBUSH` | Red (#d88070) | Crossed blades (same as regular) | 34px circle | Visually identical to regular combat; the "ambush" twist is revealed only when you enter the tile (preserves the surprise) |
| `COMBAT_ELITE` | Violet (#e080e0) | Four-point star | 38px circle | Inner glow + slightly brighter border |
| `COMBAT_BOSS` | Orange/gold (#ffb050) | Ornamental sigil | 56px circle | Rotating dashed outer ring (20s loop), 1.8s breathing pulse, bloom shadow, 0.95→1.08 scale animation |
| `REST_SITE` | Green (#8cf0a8) | Shrine glyph | 34px circle | Calm inner glow |
| `TREASURE` | Gold (#ffdc78) | Diamond/gem | 34px circle | Warm inner glow, subtle sparkle particle (1 particle every 0.5s from center) |
| `TRAP` | Red-orange (#dc6428) | Warning glyph | 34px circle | **Hidden on reveal-neighbor tiles — no icon shown until the tile is visited.** Appears only on the visited-tile state, as a "gotcha" reveal |
| Unrevealed / mystery | Violet (#9068c8) | Question mark | 34px circle | Used for the existing `UNKNOWN_OVERLAY_SOURCE_ID` case — matches the current game's mystery-icon behavior for tiles whose type is intentionally hidden by the map generator |
| `NONE` | No icon | — | — | Tile rendered with no overlay glyph |

**Visited icon state:** When a tile becomes visited, its encounter icon becomes 0.4 α with saturation 0.3 via shader or CanvasItem modulate. This preserves the map history without overpowering the live tiles.

**Glyphs:** Use Unicode glyphs rendered via `Label` with a serif font from the existing pixel theme, OR import simple SVG/PNG glyph sprites into `assets/sprites/adventure/encounter_glyphs/`. Recommendation: glyph sprites for consistent cross-platform rendering. Each glyph is a single 32×32 or 48×48 PNG (48 for boss).

### Interactions

| Input | Response |
|-------|----------|
| Mouse motion over a revealed tile | Tile transitions from `Reveal` state to `Hover-target` state (scale 1.05, brighter modulate) via 0.08s tween. Path preview line draws from current tile through intermediate tiles to hover-target using existing `cube_pathfind()`. |
| Mouse leaves a revealed tile | Transitions back to `Reveal` state. Path preview clears. |
| Click a revealed tile | Existing movement logic runs. A ring burst particle emitter fires at the target tile. Hit-stop (`Engine.time_scale = 0.25` for 0.05s) when a new boss/elite encounter is revealed. |
| Player reaches a new tile | Tile reveal animation: the new `Reveal`-state tiles appear with a 0.3s fade-in + scale-from-0.85 tween, staggered by 0.05s per tile so the "view expands" outward. Mist in the direction of the new tiles subtly drifts inward. Fog-of-war shader updates its `clear_positions` uniform. |
| First time a boss is revealed (by moving adjacent) | 0.15s hit-stop + 150ms screen flash (cyan→white→none) + camera push toward boss tile. Boss icon fades in over 0.4s with a scale overshoot (0.8→1.1→1.0). Only happens once per run. |

## Technical Architecture

### New files

```
assets/shaders/
  vignette.gdshader              (new) — radial gradient darkening
  fog_of_war.gdshader             (new) — per-tile-position reveal mask
  tile_aura.gdshader              (new) — full-body glow for current tile
  flowing_path.gdshader           (new) — animated gradient stroke for path preview

assets/sprites/adventure/encounter_glyphs/
  combat.png                      (new)
  elite.png                       (new)
  boss.png                        (new)
  rest.png                        (new)
  treasure.png                    (new)
  trap.png                        (new)
  unknown.png                     (new) — optional, may reuse existing icon

scenes/zones/zone_atmosphere/
  zone_atmosphere.tscn            (new) — CanvasLayer containing mist sprites,
                                          mote particles, and vignette ColorRect
  zone_atmosphere.gd              (new) — manages mist drift tweens

scenes/adventure/adventure_atmosphere/
  adventure_atmosphere.tscn       (new) — same pattern as zone_atmosphere
  adventure_atmosphere.gd         (new)

scenes/adventure/tile_state_overlay/
  tile_state_overlay.tscn         (new) — Node2D managing per-tile visual
                                          overlay sprites keyed by cube coord
  tile_state_overlay.gd           (new) — pool & tween overlay sprites for
                                          state transitions

scenes/adventure/encounter_icon/
  encounter_icon.tscn             (new) — packed scene with Sprite2D glyph,
                                          optional ornamental ring child,
                                          optional particle emitter child
  encounter_icon.gd               (new) — configure_for_type(encounter_type)
                                          applies color, frame, effects

scenes/adventure/path_preview/
  path_preview.tscn               (new) — Line2D with flowing gradient shader
  path_preview.gd                 (new) — update_path(from_cube, to_cube)

scenes/zones/glowing_path/
  glowing_path.tscn               (new) — Line2D for zone connections
  glowing_path.gd                 (new)

tests/unit/test_tile_state_overlay.gd     (new)
tests/unit/test_encounter_icon_config.gd  (new)
```

### Modified files

```
scenes/zones/zone_tilemap/zone_tilemap.gd          — instance ZoneAtmosphere,
                                                     replace selected_zone_pulse_node
                                                     with aura sprite, add hover
                                                     handling, add glowing_path
                                                     connections, add camera ease tween
scenes/zones/zone_tilemap/zone_tilemap.tscn        — add ZoneAtmosphere child,
                                                     add TileStateOverlay child
scenes/tilemaps/hexagon_tile_map_layer.gd         — extend _input() to detect
                                                     MOUSE_MOTION and emit
                                                     tile_hovered(coord) signal
scenes/adventure/adventure_tilemap/adventure_tilemap.gd
                                                   — replace pulse-node spawning
                                                     with TileStateOverlay calls,
                                                     replace hardcoded source-id
                                                     overlay logic with
                                                     EncounterIcon instancing,
                                                     add PathPreview, add
                                                     fog_of_war shader uniforms
                                                     update on visit, add reveal
                                                     animation staggering
scenes/adventure/adventure_tilemap/adventure_tilemap.tscn
                                                   — add AdventureAtmosphere,
                                                     TileStateOverlay, PathPreview,
                                                     FogOfWar rect children
assets/themes/pixel_theme.tres                    — add PanelStamina stylebox,
                                                     confirm existing typography
                                                     works for "?" glyph font
scripts/resource_definitions/adventure/encounters/adventure_encounter.gd
                                                   — add getter `get_icon_type() ->
                                                     StringName` returning the
                                                     visual type key (no new data —
                                                     derived from existing
                                                     encounter_type enum)
```

### Camera transition tweens

Both views already have `CameraZoomController` with smooth `slerp` zoom. For eased position transitions (`camera.position` tweens on zone switch / adventure movement targets), we create a new tween per transition:

```gdscript
# Inside zone_tilemap.gd selection handler
var tween := create_tween()
tween.set_trans(Tween.TRANS_BACK)  # subtle overshoot
tween.set_ease(Tween.EASE_OUT)
tween.tween_property(camera, "position", new_zone_world_pos, 0.5)
```

No new controller scripts needed. Existing zoom/pan/clamp controllers are left alone.

### Fog-of-war shader interface

```glsl
shader_type canvas_item;

uniform vec2 clear_positions[64];
uniform int clear_count;
uniform float clear_radius : hint_range(0.0, 500.0) = 120.0;
uniform float clear_softness : hint_range(0.0, 1.0) = 0.4;
uniform vec4 fog_color : source_color = vec4(0.02, 0.03, 0.08, 0.85);

void fragment() {
    vec2 world = (SCREEN_UV - 0.5) * SCREEN_SIZE + CAMERA_OFFSET;
    float min_dist = 9999.0;
    for (int i = 0; i < clear_count; i++) {
        min_dist = min(min_dist, distance(world, clear_positions[i]));
    }
    float mask = smoothstep(clear_radius, clear_radius * (1.0 + clear_softness), min_dist);
    COLOR = vec4(fog_color.rgb, fog_color.a * mask);
}
```

**Constraint:** GLSL uniform arrays in Godot 4.6 must have a compile-time-fixed size, so we hard-code the cap at 64 `clear_positions`. Current adventure maps generated by `adventure_map_generator.gd` average ~20 tiles total, so 64 is ~3× headroom. Implementation will validate at runtime and log a warning (via `LogManager`) if the visited count approaches the cap. When we eventually exceed 64, the fallback is (a) render visibility to a half-resolution `SubViewport` texture and sample it in the fog shader, or (b) filter `clear_positions` to only those within camera bounds. Both fallbacks are single-file changes — we'll revisit when needed, not pre-emptively.

### Spirit mote particles

`GPUParticles2D` is the right node for this. Existing `FlyingParticle` (used in `zone_transition.gd`) is a per-instance `Node2D` — different use case, keep that for the Madra drain animation. Mote particles need to render 40-60 quads without per-particle overhead.

Configuration (per emitter, with two emitter instances for cyan + warm variants):
- `amount`: 30
- `lifetime`: 3.0s
- `preprocess`: 3.0 (no blank start)
- Material: `ParticleProcessMaterial` with random velocity in a box, sine-wave alpha over lifetime (via `ALPHA_CURVE`), and small size randomness
- Texture: 4×4 white circle, modulated by particle color
- Modulate: cyan emitter = `Color(0.75, 0.85, 1.0, 0.9)`, warm emitter = `Color(1.0, 0.88, 0.5, 0.9)`

## Performance Considerations

- **Particle count**: 60 mote particles + 30 mist sprites is trivial for GPU particles. No concern.
- **Vignette shader**: single full-screen `ColorRect` with a ~10-line fragment shader. Cheap.
- **Fog-of-war shader**: loop up to 64 clear positions per fragment. At 1920×1080 = 2M fragments × 64 = 130M operations per frame. On integrated GPUs this could cost ~3-5ms. Mitigation: render fog at half resolution to a viewport, then upscale. Not needed unless profiling shows a hit.
- **Tile state overlay sprites**: max visible tiles on screen at any zoom ≈ 40. 40 `Sprite2D` children with tweens is trivial.
- **Path preview `Line2D`**: only active during hover, max 15 segments. Trivial.
- **Boss rotating ring**: single `Sprite2D` with a continuous property tween. Cheap.

**Profile target:** 60fps on the existing dev machine while viewing either map at normal zoom. If any element exceeds 0.5ms frame cost in profiling, it gets iterated on before ship.

## Testing

### GUT unit tests

- `tests/unit/test_encounter_icon_config.gd`
  - Given each `EncounterType` enum value, `encounter_icon.configure_for_type()` produces the expected color modulate, glyph texture, and frame size
  - Boss config enables the ornamental ring child
  - Treasure config enables the sparkle particle emitter
  - `NONE` config returns early with the node hidden
- `tests/unit/test_tile_state_overlay.gd`
  - `add_tile(cube, state)` creates exactly one overlay sprite
  - `transition_tile(cube, new_state)` tweens the overlay without creating a duplicate
  - `remove_tile(cube)` frees the overlay
  - `clear_all()` removes every overlay

### Manual smoke tests

After implementation, manually verify in order:
1. Zone view loads with vignette visible, mist drifting, motes present
2. Selected zone has a visible breathing aura (not the thin pulse line)
3. Hovering an unlocked zone scales + glows
4. Hovering a locked zone does nothing
5. Clicking a zone transitions the camera with visible overshoot + ring burst
6. Locked zones show "?" silhouettes
7. Glowing path lines connect unlocked zones
8. Starting an adventure transitions to the adventure view with the existing Madra drain animation, then the new vignette/mist/motes kick in
9. Adventure view shows the new tile states clearly (visited is dim, current has aura, revealed-neighbors pulse)
10. Every encounter type renders with its own color/glyph, instantly distinguishable
11. Boss tile is obviously "the boss" — larger, ornamental ring, breathing
12. Hovering a revealed tile draws the path preview line
13. Moving onto a new tile triggers reveal animation for new neighbors (staggered fade-in)
14. First boss sighting triggers the hit-stop + flash + camera push
15. Fog-of-war darkens regions beyond the visited radius and updates smoothly as you explore
16. 60fps holds during ambient state, hover, and movement on both views

## Build Order

The feature breaks into small independent pieces that can be implemented in this order. Each item below is a loose grouping — the actual plan step breakdown happens in the planning phase.

1. **Shared atmosphere scene** — vignette shader, mist layer, mote particles as a reusable packed scene, dropped into both views first to get the visual baseline right
2. **Zone view polish** — camera ease tweens, hover glow, current-zone aura (replacing pulse node), glowing path connections, locked silhouettes
3. **Tile state overlay system** — the per-tile `Sprite2D` pool in adventure view, covering all 5 states, replacing the existing `PulseNode` spawning
4. **Encounter icon scene** — `encounter_icon.tscn` with type configuration, replacing the hardcoded source-id overlay logic in `adventure_tilemap.gd`
5. **Fog-of-war shader** — new shader + uniform update in `_mark_tile_visited()` callback
6. **Path preview** — `Line2D` with flowing gradient shader, wired to `tile_hovered` signal from `hexagon_tile_map_layer.gd`
7. **Reveal & boss animations** — tile reveal stagger, boss hit-stop + flash + camera push on first sighting
8. **Stamina UI restyle** — `PanelStamina` theme variant and layout tweak
9. **Tests + manual smoke pass** — add the GUT unit tests, run through the manual checklist, profile for any frame-time regressions

## Open Questions / Decisions Deferred

- **Glyph source**: Unicode serif glyphs vs PNG sprites — default plan uses PNG sprites; if art is hard to source, fall back to Unicode for the first pass and swap later
- **Fog-of-war performance**: the loop-over-clear-positions shader is simple but scales O(N) in clear positions per fragment. If the maximum map size grows beyond ~60 tiles, revisit using a rendered visibility mask texture instead
- **Audio pass**: explicitly out of scope here; a future spec will cover SFX for hover / click / reveal / boss sighting / zone unlock

## Appendix: Reference to Mockups

Design mockups generated during brainstorming are preserved at:
- `.superpowers/brainstorm/59377-1776132913/content/01-aesthetic-direction.html` — aesthetic comparison
- `.superpowers/brainstorm/59377-1776132913/content/02-motion-intensity.html` — motion spectrum
- `.superpowers/brainstorm/59377-1776132913/content/03-zone-view-target.html` — zone view annotated target
- `.superpowers/brainstorm/59377-1776132913/content/04-adventure-view-target.html` — adventure view annotated target, encounter icon language, tile state language
