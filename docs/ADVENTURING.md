# Adventuring System

## Overview

Adventuring is a roguelite-style exploration mode where the player navigates a procedurally generated hex grid map. The grid contains encounter nodes connected by walkable paths, with fog-of-war revealing tiles as the player moves. Each encounter presents choices (fight, rest, collect treasure, dialogue). A countdown timer limits the run, movement costs Stamina, and defeating the boss at the furthest node completes the adventure.

## Player Experience

1. Player selects an Adventure action from a zone
2. Adventure view replaces the zone view; a hex map generates procedurally
3. Player starts at the origin tile, with only immediate neighbors visible
4. Clicking a revealed tile pathfinds and moves the character (costs 5 Stamina per step)
5. Reaching an encounter tile opens the `EncounterInfoPanel` with choices
6. Choosing combat switches to the combat view; other choices apply effects immediately
7. Completed tiles show their post-completion text; player can move through freely
8. Defeating the boss tile triggers `ActionManager.stop_action(true)` — adventure success
9. Running out of stamina, losing combat, or timer expiry ends the run as a failure

## Architecture

```
AdventureView (Control)                         — adventure_view.gd
  TilemapView (Control)
    SubViewportContainer (1920x1080)
      Background (Sprite2D)
      SubViewport
        AdventureTilemap (Node2D)               — adventure_tilemap.gd
          AdventureFullMap (HexagonTileMapLayer)    — structural ghost tiles
          AdventureVisibleMap (HexagonTileMapLayer) — fog-of-war revealed
          AdventureHighlightMap (HexagonTileMapLayer) — encounter type overlays
          CharacterBody2D + Camera2D
          CanvasLayer
            EncounterInfoPanel                  — encounter_info_panel.gd
  CombatView (Control, hidden)
    SubViewport
      AdventureCombat                           — adventure_combat.gd
  PlayerInfoPanel (CombatantInfoPanel)
  TimerPanel                                    — timer_panel.gd
```

### Three-Layer Tilemap

| Layer | Node | Purpose |
|-------|------|---------|
| `full_map` | AdventureFullMap | All tiles as transparent ghosts (structural) |
| `visible_map` | AdventureVisibleMap | Fog-of-war revealed: yellow = encounter, white = path |
| `highlight_map` | AdventureHighlightMap | Encounter type overlay icons (source IDs 3-7) |

Pathfinding runs on `AdventureVisibleMap` only — players can only click revealed tiles.

## Map Generation

File: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`

Generation runs in 4 phases:

### Phase 1 — Place Special Tiles
- Scatters `num_special_tiles` coordinates using random cube coords `(q, r, s=-q-r)`
- Rejects tiles outside `max_distance_from_start` or too close to existing tiles (`sparse_factor`)
- Up to 100 attempts per tile placement

### Phase 2 — Assign Encounters
- Each special tile gets a random encounter from `special_encounter_pool`
- The tile **furthest from origin** becomes the boss encounter

### Phase 3 — Generate MST Paths (Prim's Algorithm)
- Connects all special tiles via Minimum Spanning Tree
- Draws hex lines (`cube_linedraw`) between connected nodes
- Intermediate tiles become `NoOpEncounter` walk-through paths
- Guarantees all special nodes are reachable from start

### Phase 4 — Assign Path Encounters
- Promotes `num_path_encounters` random NoOp path tiles to encounters from `path_encounter_pool`

## Data Model

### AdventureData (map configuration)
| Field | Type | Description |
|-------|------|-------------|
| `adventure_id` | `String` | Unique identifier |
| `num_special_tiles` | `int` | Encounter nodes to scatter |
| `max_distance_from_start` | `int` | Bounding hex radius |
| `sparse_factor` | `int` | Minimum spacing between special tiles |
| `num_path_encounters` | `int` | NoOp tiles promoted to encounters |
| `boss_encounter` | `AdventureEncounter` | Placed at furthest tile |
| `special_encounter_pool` | `Array[AdventureEncounter]` | Pool for special tiles |
| `path_encounter_pool` | `Array[AdventureEncounter]` | Pool for promoted path tiles |

### AdventureActionData (extends ZoneActionData)
| Field | Type | Description |
|-------|------|-------------|
| `adventure_data` | `AdventureData` | Map config |
| `time_limit_seconds` | `int` | Run timer (default 10, test uses 300) |
| `gold_multiplier` | `float` | Multiplier for combat gold rewards |
| `stamina_regen_modifier` | `float` | Stamina regen rate multiplier |
| `experience_multiplier` | `float` | **Defined but unused** |
| `difficulty_modifier` | `float` | **Defined but unused** |
| `cooldown_seconds` | `float` | **Defined but unenforced** |
| `daily_limit` | `int` | **Defined but unenforced** |

### AdventureEncounter
| Field | Type | Description |
|-------|------|-------------|
| `encounter_id` | `String` | Unique ID |
| `encounter_name` | `String` | Display name |
| `description` | `String` | Shown before completion |
| `text_description_completed` | `String` | Shown after completion |
| `choices` | `Array[EncounterChoice]` | Available player choices |
| `encounter_type` | `EncounterType` | Visual overlay category |

**EncounterType enum:** `COMBAT_REGULAR`, `COMBAT_AMBUSH`, `COMBAT_BOSS`, `COMBAT_ELITE`, `REST_SITE`, `TRAP`, `TREASURE`, `NONE`

### Choice Types

| Class | Extra Fields | Behavior |
|-------|-------------|----------|
| `EncounterChoice` (base) | `requirements`, `success_effects`, `failure_effects` | Applies effects directly |
| `CombatChoice` | `enemy_pool`, `is_boss`, `gold_multiplier` | Triggers combat view |
| `DialogueChoice` | `timeline_name` | Starts Dialogic timeline |

### World Effect System (separate from Combat effects)
| Class | Action |
|-------|--------|
| `AwardResourceEffectData` | Calls `ResourceManager.award_resource()` |
| `AwardItemEffectData` | Calls `InventoryManager.award_items()` |
| `AwardLootTableEffectData` | Rolls loot table, awards items |
| `ChangeVitalsEffectData` | Modifies health/stamina/mana via PlayerManager |
| `TriggerEventEffectData` | Fires a narrative event via EventManager |

## Encounter Flow

```
1. Tile clicked → HexagonTileMapLayer.tile_clicked(coord)
2. Pathfind from current to target → AStar2D via addon
3. Move character step by step (5 stamina per step, speed scales with queue length)
4. On arrival at encounter tile:
   - NoOpEncounter or already visited → auto-continue
   - Has choices → show EncounterInfoPanel, lock movement
5. Player selects choice:
   - CombatChoice → emit start_combat, switch to combat view
   - DialogueChoice → start Dialogic timeline, complete on end
   - Base choice → apply success_effects, complete tile
6. Tile completed → mark visited, update fog-of-war, unlock movement
```

## Fog-of-War

`_update_visible_map()` clears and rebuilds all three tilemaps each time:
- Visited tiles + their unvisited neighbors are rendered
- Encounter nodes get yellow tiles; NoOp paths get white tiles
- Encounter type icons rendered on the highlight layer
- Unvisited neighbors get a `PulseNode` (Line2D with pulsing shader) as a beacon

## Timer

`TimerPanel` wraps a `Timer` + `RichTextLabel` showing `"Time Left: MM:SS"`. Timer timeout triggers `ActionManager.stop_action(false)` — treated as failed adventure. If `time_limit_seconds` is 0 in the data, it defaults to 10 seconds.

## Integration Points

| System | Connection |
|--------|------------|
| Combat | `CombatChoice` triggers combat; result feeds back for loot/gold |
| ActionManager | `start_adventure` / `stop_adventure` signals control lifecycle |
| ResourceManager | Gold awarded on combat victory |
| PlayerManager | VitalsManager tracks health/stamina; stamina regen set on start |
| InventoryManager | Loot tables rolled on encounter success effects |
| DialogueManager | `DialogueChoice` starts timelines |
| ZoneManager | Zone change cancels active adventure |

## Existing Content

One adventure exists: `test_adventure_data.tres` with default parameters (5 special tiles, distance 6, sparse factor 2). One combat encounter with a test enemy. One boss encounter. The Spirit Valley zone has a test adventure action with 300-second time limit.

## Key Files

| File | Purpose |
|------|---------|
| `scenes/adventure/adventure_view/adventure_view.gd` | Top-level controller, view switching, timer |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | Map state, movement, encounter logic |
| `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` | Procedural hex map generation |
| `scenes/adventure/adventure_tilemap/encounter_info_panel.gd` | Encounter UI display |
| `scenes/adventure/adventure_tilemap/encounter_choice_button.gd` | Choice button with requirements |
| `scenes/adventure/adventure_view/timer_panel.gd` | Countdown timer |
| `scripts/resource_definitions/adventure/adventure_data.gd` | Map generation parameters |
| `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd` | Encounter base class |
| `scripts/resource_definitions/adventure/choices/combat_choice.gd` | Combat initiator |
| `scripts/resource_definitions/adventure/choices/dialogue_choice.gd` | Dialogue initiator |
| `scenes/tilemaps/hexagon_tile_map_layer.gd` | Project hex extension (click handling) |

## Known Issues

- Two debug buttons in `adventure_view.tscn` — one with `TODO: Remove this temporary debug button`
- `_assign_path_tiles` can loop forever if `num_path_encounters` exceeds available NoOp tiles
- `num_combats_in_map` declared in generator but never read or written
- No stamina UI feedback when movement is blocked — just a silent return
- `MOVEMENT_STAMINA_COST` is a constant (5.0) — no per-tile or stat-based variation
- `EncounterType.TRAP` falls through to unknown overlay; no dedicated trap icon
- Boss placement is distance-based, not explicit — ties broken by last-wins
- `experience_multiplier` and `difficulty_modifier` on AdventureActionData are unused
- `cooldown_seconds` and `daily_limit` are defined but unenforced
- `AdventureViewState.handle_input()` is a no-op — no escape/back navigation in adventure
