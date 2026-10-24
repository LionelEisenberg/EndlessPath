# Event System

## Overview

`EventManager` is a persistent store of one-shot story flags. An event is a bare string id. Triggering it records the id permanently in the save and emits `event_triggered` once. Firing the same id again does nothing, and no API un-triggers an event.

EventManager is **not** a general pub/sub bus. It has one signal, it deduplicates, and everything it records is persisted. Systems use events to say "this moment happened". Gates read those moments through [unlock conditions](UNLOCKS.md) and [quest steps](../progression/QUESTS.md).

## Player Experience

Players never see events directly. They see what events unlock:

1. The first talk with the Celestial Intervener (`celestial_intervener_dialogue_1`) makes Wilderness Cycling appear and unlocks the Test Zone (hidden on the map).
2. Returning to the Intervener (`celestial_intervener_dialogue_2/3/4`) advances the current quest.
3. Winning any combat for the first time (`q_first_steps_enemy_defeated`) reveals the next "Return to the [INTERVENER]" action.
4. Choosing "Mark down the location" at an Aura Well (`aura_well_discovered`) adds the Aura Well training action and grays that choice on every later Aura Well tile.
5. Approaching the Refugee Camp (`merchant_discovered`) adds the Traveling Merchant action and removes the camp from future maps.

## Architecture

```
EventManager (autoload #3, singletons/event_manager/event_manager.gd)
  live_save_data: SaveGameData → event_progression: EventProgressionData
  signal event_triggered(event_id: String)

Producers                                   Consumers (connection order)
  TriggerEventEffectData.process()  ──┐       1. UnlockManager (full condition sweep)
  AdventureCombat (hardcoded id)    ──┼──►    2. QuestManager (quest steps)
  tests                             ──┘     Live readers: UnlockConditionData.EVENT_TRIGGERED
                                              (EventManager.has_event_triggered)
```

## Data Model

### EventProgressionData (`singletons/persistence_manager/event_progression_data.gd`)

| Field | Type | Description |
|---|---|---|
| `triggered_events` | `Array[String]` | Every event id ever triggered, in firing order |

Stored as `SaveGameData.event_progression`. `SaveGameData.reset()` replaces it with a fresh instance.

## Core Systems

### API

| Member | Description |
|---|---|
| `signal event_triggered(event_id: String)` | Emitted once per id, on the first trigger only |
| `trigger_event(event_id: String) -> void` | If `event_id` is not already in `triggered_events`, appends it and emits `event_triggered`. Otherwise does nothing. |
| `has_event_triggered(event_id: String) -> bool` | Membership check |
| `live_save_data: SaveGameData` | Bound in `_ready()`. A lambda rebinds it on `PersistenceManager.save_data_reset`. |

Neither method guards against a null `live_save_data`.

### Flow

```
Zone action stops / quest completes / encounter choice resolves
  → TriggerEventEffectData.process()
      → EventManager.trigger_event("some_id")        (does nothing if already fired)
          → event_progression.triggered_events.append("some_id")
          → event_triggered.emit("some_id")
              1. UnlockManager sweeps every condition
                   EVENT_TRIGGERED conditions targeting "some_id" latch
                   → condition_unlocked → ZonePanel / ZoneTilemap refresh,
                                          ActionManager may start a first idle action,
                                          QuestManager re-checks condition steps
              2. QuestManager receives "some_id"
                   event steps whose completion_event_id == "some_id" advance;
                   condition steps are re-evaluated too
```

UnlockManager connects in autoload #5 and QuestManager in #17, so conditions latch before QuestManager sees the raw event. Effects inside one array run in order, so an event fired by an earlier effect is fully processed, including any cascade, before the next effect runs.

### Producers

| Producer | Where |
|---|---|
| `TriggerEventEffectData` | Zone action `success_effects`, quest `completion_effects`, and encounter choice `success_effects`. This is the standard path. See [EFFECTS.md](EFFECTS.md). |
| `AdventureCombat` | Calls `EventManager.trigger_event("q_first_steps_enemy_defeated")` whenever an enemy's health reaches 0, before emitting `trigger_combat_end(true, gold)`. Only the first call has any effect. |

Dialogic timelines do not fire events. `Dialogic.signal_event` is not connected. Events tied to dialogue fire from the NPC action's `success_effects` after the timeline ends. See [DIALOGUE.md](DIALOGUE.md).

## Integration Points

| System | Connection |
|---|---|
| UnlockManager | Full condition sweep on every `event_triggered`. `EVENT_TRIGGERED` conditions call `has_event_triggered(target_value)`. |
| QuestManager | Event steps match `completion_event_id` against the firing event. `start_quest()`'s retroactive pass uses `has_event_triggered()`. |
| AdventureEncounter / EncounterChoice | Inline or shared `EVENT_TRIGGERED` conditions are evaluated live for map eligibility and choice state |
| PersistenceManager | `SaveGameData.event_progression`, autosaved every 5 s to `user://save.tres` |
| AdventureCombat | Hardcoded producer of `q_first_steps_enemy_defeated` |

## Existing Content

Every event id the game can fire:

| Event id | Fired by | Consumed by |
|---|---|---|
| `celestial_intervener_dialogue_1` | `resources/effects/trigger_event/celestial_intervener_dialogue_1.tres`, in `celestial_intervener_dialogue_1.success_effects` (NPC 1) | Condition `celestial_intervener_dialogue_1`, which gates Wilderness Cycling and the Test Zone |
| `celestial_intervener_dialogue_2` | Inline `TriggerEventEffectData` in `celestial_intervener_dialogue_2.success_effects` (NPC 2) | `q_fill_core` step `return_to_npc` |
| `q_fill_core_completed` | Inline in `q_fill_core.completion_effects` | Condition `q_fill_core_completed`, which gates The Shallow Woods and Spring Forest Foraging |
| `q_first_steps_enemy_defeated` | `AdventureCombat`, when an enemy's health reaches 0 (code) | `q_first_steps` step `defeat_enemy`; condition `q_first_steps_enemy_defeated`, which gates NPC 3 |
| `celestial_intervener_dialogue_3` | Inline in `celestial_intervener_dialogue_3.success_effects` (NPC 3) | `q_first_steps` step `return_to_npc` |
| `celestial_intervener_dialogue_4` | Inline in `celestial_intervener_dialogue_4.success_effects` (NPC 4) | `q_reach_core_density_10` step `return_to_npc` |
| `aura_well_discovered` | Inline in `aura_well_encounter.tres`, choice "Mark down the location" | Condition `aura_well_discovered`: gates the Aura Well training action, is the Mark choice's `requirements` (expected `false`), and is its `completion_condition` |
| `merchant_discovered` | Inline in `refugee_camp_encounter.tres`, choice "Approach the camp" | Condition `merchant_discovered`, which gates the Traveling Merchant action; an inline duplicate condition in the camp's `unlock_conditions` (expected `false`) |

Tests fire throwaway ids such as `eel_dialogue_done` and `spring_forest_visited` against fresh `SaveGameData` instances. Those ids never appear in content.

Naming conventions (same id for an event and the condition that wraps it, `q_<quest>_` prefixes, NPC action id = event id) are in [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md).

## Key Files

| File | Purpose |
|---|---|
| `singletons/event_manager/event_manager.gd` | Event flag store and signal |
| `singletons/persistence_manager/event_progression_data.gd` | Saved triggered-event list |
| `scripts/resource_definitions/effects/trigger_event_effect_data.gd` | Effect that fires an event |
| `scenes/combat/adventure_combat/adventure_combat.gd` | Hardcoded `q_first_steps_enemy_defeated` producer |

Tests: EventManager has no test file of its own; `tests/unit/test_quest_manager.gd` and `tests/integration/test_beat_3b_merchant_unlock.gd`, among others named after what they check, exercise it; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Missing Functionality

- `[MEDIUM]` Several moments that the planned beats need have no events: boss defeated, elite defeated, adventure completed, Core Density milestones, stage advanced. `AdventureTilemap.boss_defeated` exists as a signal but fires no event. Data-only option: put a `TriggerEventEffectData` in a boss or elite `CombatChoice.success_effects`, which `AdventureTilemap.handle_combat_result()` already processes on victory.
- `[LOW]` The dev panel has no "fire event" action. It can only force-latch conditions (`UnlockManager.force_unlock_condition`), which doesn't record the event, so quest event steps and live condition checks still see it as unfired. See [UNLOCKS.md](UNLOCKS.md).

### Tech Debt

- `[MEDIUM]` Event ids are magic strings repeated across `.tres` files and code. A typo silently breaks a chain. Add a data-validation test: every `completion_event_id`, and every `EVENT_TRIGGERED` condition `target_value`, must match a `TriggerEventEffectData.event_id` somewhere in `resources/` or a known code producer.
- `[LOW]` `adventure_combat.gd` hardcodes the quest-scoped id `"q_first_steps_enemy_defeated"` inside generic combat code. Every victory calls it, even though only the first call matters. A generic `enemy_defeated` event, or effects on the encounter, would decouple combat from Beat 2.
- `[LOW]` `trigger_event()` and `has_event_triggered()` dereference `live_save_data` without a null check. Tests set `EventManager.live_save_data = null` in `after_each`. The class also has no `##` doc comment.
