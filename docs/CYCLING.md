# Cycling System

## Overview

Cycling is the Foundation-stage mini-game and primary resource generation mechanic. The player follows a Madra Ball along a path on a body diagram, keeping their mouse cursor inside the ball to generate Madra. Along the path, inflection points (Cycling Zones) appear — clicking them with precise timing awards Core Density XP.

## Player Experience

1. Player selects a Cycling action from a zone, pushing the `CyclingViewState`
2. A body diagram background appears with a Madra Ball at the start of a `Path2D`
3. Player clicks **Start Cycling** — the ball begins traveling the path over `cycle_duration` seconds
4. Player tracks the ball with their cursor — time inside the ball determines `mouse_tracking_accuracy` (0.0-1.0)
5. **Cycling Zones** (Area2D nodes) light up as the ball passes through them:
   - Click while the ball is inside a zone to earn Core Density XP
   - Timing quality: **PERFECT** (< 0.3 distance ratio, 15 XP), **GOOD** (< 0.7, 10 XP), **OK** (5 XP)
   - Floating text displays the result; zone dims after use
6. At cycle end: `madra_earned = base_madra_per_cycle * mouse_tracking_accuracy`
7. Madra is capped by the current advancement stage's max (`100 + 5 * core_density_level` for Foundation)
8. If **Auto Cycle** is toggled on, a new cycle starts immediately

Pressing Escape exits cycling via `ActionManager.stop_action()`. Interrupted cycles award nothing.

## Architecture

```
CyclingView (Control)                         — cycling_view.gd
  Panel
    TextureRect (background)
      CyclingBackground (body diagram)
        CyclingTechnique (Node2D)             — cycling_technique.gd
          PathLine (Line2D)                   — baked path visual
          StartCyclingButton (Button)
          AutoCycleToggle (TextureButton)
          CyclingPath2D (Path2D)
            PathFollow2D
              MadraBall (Area2D)
            CyclingZone1..N (Area2D)          — cycling_zone.gd, created at runtime
      CyclingResourcePanel (MarginContainer)  — cycling_resource_panel.gd
      CyclingTechniqueSelector (PanelContainer) — cycling_technique_selector.gd
```

Cycling Zones are created dynamically by `_create_cycling_zones()` from `CyclingZoneData` entries. The ball animation uses a `Tween` on `PathFollow2D.progress_ratio` (an older `AnimationPlayer` in the scene is unused).

## Data Model

### CyclingTechniqueData
| Field | Type | Description |
|-------|------|-------------|
| `technique_name` | `String` | Display name, also the save key |
| `path_curve` | `Curve2D` | Bezier path the ball follows |
| `cycle_duration` | `float` | Seconds per cycle (default 10.0) |
| `base_madra_per_cycle` | `float` | Madra at perfect accuracy (default 25.0) |
| `cycling_zones` | `Array[CyclingZoneData]` | Zone descriptors |

### CyclingZoneData
| Field | Type | Description |
|-------|------|-------------|
| `position` | `Vector2` | World position relative to CyclingPath2D |
| `timing_window_ratio` | `float` | **Defined but never read** — radius is hardcoded to 20 |
| `perfect_xp` | `int` | XP for PERFECT hit (default 15) |
| `good_xp` | `int` | XP for GOOD hit (default 10) |
| `ok_xp` | `int` | XP for OK hit (default 5) |

### CyclingActionData (extends ZoneActionData)
| Field | Type | Description |
|-------|------|-------------|
| `madra_multiplier` | `float` | **Defined but never applied** |
| `cycle_duration_modifier` | `float` | **Defined but never applied** |
| `xp_multiplier` | `float` | **Defined but never applied** |
| `madra_cost_per_cycle` | `float` | **Defined but never applied** |

### AdvancementStageResource
| Field | Type | Description |
|-------|------|-------------|
| `stage_name` | `String` | e.g., "Foundation" |
| `stage_id` | `CultivationManager.AdvancementStage` | Enum value |
| `core_density_base_xp_cost` | `float` | Base XP to level up (default 10.0) |
| `core_xp_scaling_factor` | `float` | Exponential scaling per level (1.02 for Foundation) |
| `max_madra_base` | `float` | Madra cap at level 0 (100.0) |
| `max_madra_per_core_density_level` | `float` | Cap increase per level (5.0) |
| `next_stage` | `AdvancementStageResource` | Linked list (currently null) |

## Core Logic

### Madra Generation
- Each `_process(delta)` frame checks if the mouse is inside `MadraBall`'s `CircleShape2D`
- Accumulates `time_mouse_in_ball`; ratio = `time_mouse_in_ball / elapsed_cycle_time`
- At cycle end: `madra_earned = base_madra_per_cycle * mouse_tracking_accuracy`
- Passed to `ResourceManager.add_madra()`, which clamps to the stage's max

### Core Density XP
- Awarded per zone click via `CultivationManager.add_core_density_xp(xp_reward)`
- XP for level N = `base_xp_cost * scaling_factor^(N-1)` — gentle exponential curve
- Multi-level-up supported in a single call via a `while` loop

### Technique Selection
- `CyclingTechniqueSelector` shows a grid of technique slots with an info panel
- Selecting a technique emits `technique_change_request` up to `CyclingView`
- Technique name is saved to `PersistenceManager.save_game_data.current_cycling_technique_name`
- Loaded by string name lookup on startup (falls back to first technique if not found)

## Signals

| Signal | Source | Listeners |
|--------|--------|-----------|
| `cycling_started` | CyclingTechnique | CyclingResourcePanel |
| `cycle_completed(madra, accuracy)` | CyclingTechnique | CyclingResourcePanel |
| `zone_clicked(zone, zone_data)` | CyclingZone | CyclingTechnique |
| `current_technique_changed(data)` | CyclingView | CyclingTechnique, CyclingResourcePanel |
| `technique_change_request(data)` | CyclingTechniqueSelector | CyclingView |
| `open_technique_selector` | CyclingResourcePanel | CyclingView |
| `start_cycling` / `stop_cycling` | ActionManager | CyclingViewState, MainView |

## Resource Panel UI

- **MadraCircle** — `ProgressShaderRect` driven by `current_madra / max_madra`, smooth lerp animation
- **CoreDensityRect** — `ProgressShaderRect` driven by `core_density_level / 100.0`
- **XP Progress Bar** — standard Godot ProgressBar for XP within current level
- **Technique info** — name and base madra per cycle
- **Stage info** — current stage name + next stage (currently shows "(MAX)" due to null `next_stage`)

## Integration Points

| System | Connection |
|--------|------------|
| `ResourceManager` | `add_madra()` on cycle end; `madra_changed` signal updates resource panel |
| `CultivationManager` | `add_core_density_xp()` on zone click; signals update level/XP display |
| `ActionManager` | `start_cycling` / `stop_cycling` signals control view lifecycle |
| `PersistenceManager` | Technique name saved/loaded; Madra and XP persisted via SaveGameData |
| `LogManager` | Cycle stats logged on completion |

## Existing Content

| Resource | Details |
|----------|---------|
| Foundation Technique | 10s cycle, 25 madra/cycle, 3 zones |
| Test Foundation Technique | 5s cycle, 25 madra/cycle, 0 zones |
| Foundation Stage | base XP 10, scaling 1.02, max madra 100 + 5/level |

Both techniques share the same `Curve2D` (`new_curve_2d.tres` at project root).

## Key Files

| File | Purpose |
|------|---------|
| `scenes/cycling/cycling_view/cycling_view.gd` | Top-level orchestrator |
| `scenes/cycling/cycling_technique/cycling_technique.gd` | Core cycling logic (state, mouse tracking, zones) |
| `scenes/cycling/cycling_technique/cycling_zone.gd` | Individual inflection point |
| `scenes/cycling/cycling_resource_panel/cycling_resource_panel.gd` | Resource display UI |
| `scenes/cycling/cycling_resource_panel/progress_shader_rect.gd` | Animated shader progress widget |
| `scenes/cycling/cycling_technique_selector/cycling_technique_selector.gd` | Technique picker |
| `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd` | Technique data class |
| `scripts/resource_definitions/cycling/cycling_technique/cycling_zone_data.gd` | Zone data class |
| `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd` | Stage progression data |

## Known Issues

- `CyclingZoneData.timing_window_ratio` is exported but never read — zone radius is hardcoded to 20
- `CyclingActionData` fields (madra_multiplier, xp_multiplier, etc.) are defined but never applied to cycling logic
- `AutoCycleToggle` uses the same texture for on/off states — no visual distinction
- `ProgressShaderRect._ready()` validation always fails (checks string in Array[Dictionary])
- `CyclingTechniqueSelector` calls `slot.set_selected()` but the method is named `_set_selected()` — runtime error
- Foundation stage's `next_stage` is null, so resource panel permanently shows "(MAX)"
- Only Foundation stage has an `AdvancementStageResource` — no Copper/Iron/Jade/Silver resources exist
- `attempt_breakthrough()` in CultivationManager is a stub (returns immediately)
- Shared `Curve2D` between both techniques at project root — should be split/relocated
