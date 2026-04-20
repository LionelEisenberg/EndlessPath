# Unlock System

## Overview

The unlock system gates features and content using `UnlockConditionData` — a persistent flag system that evaluates conditions (events triggered, attributes reached, resources accumulated) and unlocks zones, actions, and other content.

## UnlockConditionData (content gates)
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

### Trigger Signals
UnlockManager listens to and re-evaluates on:
- `EventManager.event_triggered`
- `CultivationManager.advancement_stage_changed`
- `CultivationManager.core_density_level_updated`
- `ResourceManager.madra_changed`
- `ResourceManager.gold_changed`

## Typical Unlock Flow

Example: Spirit Valley NPC dialogue unlocks new zones and actions.

```
1. Player clicks "Talk to the Celestial Intervener" (NPC_DIALOGUE action, max_completions=1)
2. Dialogic plays "celestial_intervener_introduction_1" timeline
3. Dialogue ends → ActionManager.stop_action(true) → _process_completion_effects()
4. TriggerEventEffectData.process()
   → EventManager.trigger_event("celestial_intervener_dialogue_1")
5. EventManager emits event_triggered
   → UnlockManager._evaluate_all_conditions()
6. Condition "celestial_intervener_dialogue_1" (EVENT_TRIGGERED) evaluates true
   → appended to save_data.unlock_progression.unlocked_condition_ids
   → condition_unlocked signal emitted
7. ZoneTilemap._on_condition_unlocked() → refreshes tiles
   → Test Zone tile changes from locked to unlocked
8. ZoneInfoPanel rebuilds
   → "Wilderness Cycling" and "Spring Forest Foraging" actions appear
9. AwardItemEffectData gives the player a Dagger
10. StartQuestEffectData starts `q_fill_core`
```

The key pattern: **game action → EffectData triggers event → UnlockManager re-evaluates → UI refreshes**. Zones and actions each have their own `unlock_conditions` arrays that reference conditions from the global `unlock_condition_list.tres`.

## Existing Content

### Unlock Conditions
1. `celestial_intervener_dialogue_1` — EVENT_TRIGGERED, unlocks Test Zone + Wilderness Cycling + Spring Forest Foraging (PR #32 renamed from `wandering_spirit_dialogue_1`)
2. `test_attribute_requirement_unlock_data` — ATTRIBUTE_VALUE, requires BODY >= 20
3. `q_fill_core_madra_full` — MADRA_AMOUNT, used by the "Fill Your Core" quest step (PR #28)
4. `q_fill_core_completed` — EVENT_TRIGGERED, marks the "Fill Your Core" quest complete (PR #28); gates Dialogue Part 2 and The Shallow Woods adventure
5. `q_first_steps_enemy_defeated` — EVENT_TRIGGERED, fires when the player wins their first Shallow Woods combat (PR #32); gates Dialogue Part 3
6. `q_reach_cd_10` — CULTIVATION_LEVEL >= 10, used by the "Reach Core Density 10" quest step (PR #32)

## Key Files

| File | Purpose |
|------|---------|
| `singletons/unlock_manager/unlock_manager.gd` | Feature gating |
| `scripts/resource_definitions/unlocks/unlock_condition_data.gd` | Condition evaluation |

## Work Remaining

### Missing Functionality

- `[LOW]` ZONE_UNLOCKED, ADVENTURE_COMPLETED, ITEM_OWNED condition types return false — implement when needed for content gating

### Performance

- `[LOW]` `_evaluate_all_conditions()` does a full sweep of every condition on every signal (Madra change, Gold change, XP tick, etc.). Fine with 2 conditions, but at scale with continuous Madra generation from cycling, this fires every frame. Consider filtering by condition type based on which signal fired

### Tech Debt

- `[LOW]` Duplicate `_compare_values()` function in both `UnlockConditionData` and `UnlockManager` — extract to a shared utility
