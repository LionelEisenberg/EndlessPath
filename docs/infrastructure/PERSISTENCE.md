# Persistence System

## Overview

PersistenceManager handles save/load lifecycle for all game state. It loads `user://save.tres` on boot and auto-saves periodically. All other managers bind to a shared `live_save_data` reference.

## Save Flow
- PersistenceManager loads `user://save.tres` on boot
- `SaveTimer` auto-saves periodically via `ResourceSaver.save()`
- `save_data_reset` signal causes all managers to re-bind their `live_save_data` reference

## SaveGameData Fields
| Field | Type | Default |
|-------|------|---------|
| `madra` | `float` | 25.0 |
| `gold` | `float` | 0.0 |
| `core_density_xp` | `float` | 0.0 |
| `core_density_level` | `float` | 0.0 |
| `current_advancement_stage` | `AdvancementStage` | `FOUNDATION` |
| `unlocked_game_systems` | `Array[GameSystem]` | `[ZONE, CYCLING]` |
| `character_attributes` | `CharacterAttributesData` | All 10.0 |

## Current Development State
- `reset_save_data = true` in PersistenceManager — wipes save on every boot
- `_reset_state()` naming mismatch — called as `reset_state()` but defined with underscore prefix

## Autoload Order
1. PersistenceManager → 2. CultivationManager → 3. EventManager → 4. CharacterManager → 5. UnlockManager → 6. ResourceManager → 7. ZoneManager → 8. ActionManager → 9. InventoryManager → 10. Dialogic → 11. DialogueManager → 12. PlayerManager → 13. LogManager

## Key Files

| File | Purpose |
|------|---------|
| `singletons/persistence_manager/persistence_manager.gd` | Save/load lifecycle |
| `singletons/persistence_manager/save_game_data.gd` | Full save schema |

## Known Issues

- `reset_state()` vs `_reset_state()` naming mismatch — save reset silently fails or crashes
- `reset_save_data = true` default means no persistence across sessions (dev flag)
- `save_game_data._to_string()` references non-existent `inventory.items` — runtime error in debug
- Double signal connections in view state machine (MainView + state subclasses both connect)
