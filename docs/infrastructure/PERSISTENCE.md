# Persistence System

## Overview

PersistenceManager handles save/load lifecycle for all game state. It loads `user://save.tres` on boot and auto-saves periodically. All other managers bind to a shared `live_save_data` reference.

## Save Flow
- PersistenceManager loads `user://save.tres` on boot
- If `reset_save_data = true` (current default), immediately resets to fresh save
- `SaveTimer` (in `main_game.tscn`) auto-saves via `ResourceSaver.save()` on each timeout — currently uses Godot's default Timer interval of 1 second (no `wait_time` set in scene)
- `save_data_reset` signal causes all managers to re-bind their `live_save_data` reference

## Manager Access Pattern

Every singleton follows the same pattern:
1. In `_ready()`, grabs a **reference** to `PersistenceManager.save_game_data` via `live_save_data = PersistenceManager.save_game_data`
2. Connects to `PersistenceManager.save_data_reset` to re-grab the reference when save data is reset

Since `SaveGameData` extends `Resource` (a Godot Object), `live_save_data` is a **shared reference** — all managers point to the same instance in memory. When ResourceManager writes `live_save_data.madra = 50`, every other manager sees the same value. No copying, no syncing needed.

| Manager | SaveGameData Fields |
|---------|---------------------|
| ResourceManager | `madra`, `gold` |
| CultivationManager | `core_density_xp`, `core_density_level`, `current_advancement_stage` |
| InventoryManager | `inventory` |
| CharacterManager | `character_attributes` |
| UnlockManager | `unlocked_game_systems`, `unlock_progression` |
| EventManager | `event_progression` |
| ZoneManager | `current_selected_zone_id`, `zone_progression_data` |
| PathManager | `current_path_id`, `path_node_purchases`, `path_points` |
| CyclingView (not singleton) | `current_cycling_technique_name` |

## SaveGameData Schema

All fields are `@export` properties on `SaveGameData` (extends Resource), persisted to `user://save.tres`.

| Field | Type | Default | Manager |
|-------|------|---------|---------|
| `madra` | `float` | 25.0 | ResourceManager |
| `gold` | `float` | 0.0 | ResourceManager |
| `core_density_xp` | `float` | 0.0 | CultivationManager |
| `core_density_level` | `float` | 0.0 | CultivationManager |
| `current_advancement_stage` | `AdvancementStage` | `FOUNDATION` | CultivationManager |
| `unlocked_game_systems` | `Array[GameSystem]` | `[ZONE, CYCLING]` | UnlockManager |
| `unlock_progression` | `UnlockProgressionData` | `new()` | UnlockManager |
| `event_progression` | `EventProgressionData` | `new()` | EventManager |
| `current_selected_zone_id` | `String` | `""` | ZoneManager |
| `zone_progression_data` | `Dictionary[String, ZoneProgressionData]` | `{}` | ZoneManager |
| `inventory` | `InventoryData` | `new()` | InventoryManager |
| `character_attributes` | `CharacterAttributesData` | `new()` (all 10.0) | CharacterManager |
| `current_path_id` | `String` | `""` | PathManager |
| `path_node_purchases` | `Dictionary[String, int]` | `{}` | PathManager |
| `path_points` | `int` | `0` | PathManager |
| `current_cycling_technique_name` | `String` | `"Foundation Technique"` | CyclingView |

**Sub-resource contents:**
- `InventoryData` — `materials` (Dictionary), `equipment` (Dictionary slot→ItemInstanceData), `equipped_gear` (Dictionary EquipmentSlot→ItemInstanceData)
- `UnlockProgressionData` — `unlocked_condition_ids` (Array[String])
- `EventProgressionData` — `triggered_events` (Array[String])
- `ZoneProgressionData` — `action_completion_count` (Dictionary[String, int]), `forage_active` (bool), `forage_start_time` (float)
- `CharacterAttributesData` — 8 float attributes (STRENGTH, BODY, AGILITY, SPIRIT, FOUNDATION, CONTROL, RESILIENCE, WILLPOWER)

## Autoload Order
1. PersistenceManager → 2. CultivationManager → 3. EventManager → 4. CharacterManager → 5. UnlockManager → 6. ResourceManager → 7. ZoneManager → 8. ActionManager → 9. InventoryManager → 10. Dialogic → 11. DialogueManager → 12. PlayerManager → 13. LogManager → 14. PathManager

## Key Files

| File | Purpose |
|------|---------|
| `singletons/persistence_manager/persistence_manager.gd` | Save/load lifecycle |
| `singletons/persistence_manager/save_game_data.gd` | Full save schema |

## Work Remaining

### Bugs

- ~~`[HIGH]` `reset_state()` vs `_reset_state()` naming mismatch~~ *(Fixed in PR #3)*
- ~~`[MEDIUM]` `save_game_data._to_string():107` references `inventory.items.size()`~~ *(Fixed in PR #3)*

### Missing Functionality

- `[MEDIUM]` `reset_save_data = true` is the default — every boot wipes save data. Should be `false` by default; the reset functionality should be part of a developer tools suite (debug menu with save reset, state manipulation, etc.) rather than a boot-time export flag
- `[LOW]` No save versioning — if SaveGameData fields change between versions, old save files break with no migration path

### Tech Debt

- `[MEDIUM]` Remove `unlocked_game_systems: Array[GameSystem]` from SaveGameData — dead field, part of GameSystem removal tracked in [UNLOCKS.md](UNLOCKS.md). Also clean up references in `_to_string()` and `_reset_state()`
- ~~`[MEDIUM]` `SaveTimer` has no `wait_time` set~~ *(Fixed in PR #6 — set to 5s)*
- `[LOW]` `_to_string()` formatting will need updating after GameSystem removal and `inventory.items` fix
