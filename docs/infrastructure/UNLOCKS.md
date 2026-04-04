# Unlock System

## Overview

The unlock system gates features and content using two mechanisms: a broad GameSystem enum for major feature visibility, and a granular UnlockConditionData system for individual content gates (zones, actions, items).

## Mechanism A: GameSystem Enum (broad feature gates)
- `UnlockManager.unlocked_game_systems` array in SaveGameData
- Default: `[ZONE, CYCLING]`
- `unlock_game_system(system)` appends and emits `game_systems_updated`
- `is_game_system_unlocked()` exists but nothing reads it to hide/show UI

## Mechanism B: UnlockConditionData (content gates)
- Persistent flag system — once unlocked, never re-evaluated
- Conditions stored in `unlock_condition_list.tres` (global registry)
- On any relevant signal, `_evaluate_all_conditions()` runs through all conditions
- Satisfied conditions are appended to `save_data.unlock_progression.unlocked_condition_ids`
- Signal: `condition_unlocked(condition_id)`

### UnlockConditionData Types
| Type | Implemented | Evaluates |
|------|-------------|-----------|
| `ADVANCEMENT_STAGE` | Yes | `CultivationManager.get_advancement_stage() >= target` |
| `CORE_DENSITY_LEVEL` | Yes | `CultivationManager.get_core_density_level() >= target` |
| `MADRA_AMOUNT` | Yes | `ResourceManager.get_madra() >= target` |
| `GOLD_AMOUNT` | Yes | `ResourceManager.get_gold() >= target` |
| `EVENT_TRIGGERED` | Yes | `EventManager.has_event_triggered(target_value)` |
| `ZONE_UNLOCKED` | No | Returns false |
| `ADVENTURE_COMPLETED` | No | Returns false |
| `ATTRIBUTE_VALUE` | Yes | `CharacterManager.get_total_attributes_data().get_attribute(type) >= target` |
| `ITEM_OWNED` | No | Returns false |
| `GAME_SYSTEM_UNLOCKED` | No | Returns false |

### Trigger Signals
UnlockManager listens to and re-evaluates on:
- `EventManager.event_triggered`
- `CultivationManager.advancement_stage_changed`
- `CultivationManager.core_density_level_updated`
- `ResourceManager.madra_changed`
- `ResourceManager.gold_changed`

## Existing Content

### Unlock Conditions
1. `initial_spirit_valley_dialogue_1` — EVENT_TRIGGERED, unlocks Test Zone + Mountain Top Cycling + Foraging
2. `test_attribute_requirement_unlock_data` — ATTRIBUTE_VALUE, requires BODY >= 20

## Key Files

| File | Purpose |
|------|---------|
| `singletons/unlock_manager/unlock_manager.gd` | Feature gating |
| `scripts/resource_definitions/unlocks/unlock_condition_data.gd` | Condition evaluation |

## Known Issues

- GameSystem unlock mechanism disconnected from UI visibility — `is_game_system_unlocked()` exists but nothing reads it
- ZONE_UNLOCKED, ADVENTURE_COMPLETED, ITEM_OWNED, GAME_SYSTEM_UNLOCKED condition types unimplemented (return false)
