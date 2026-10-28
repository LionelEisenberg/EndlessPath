# Effects (EffectData)

## Overview

`EffectData` is the game's world-side "do something" primitive. It is an abstract `Resource` with a `process()` method. Subclasses award resources, items, attributes, or path points, fire [events](EVENTS.md), start [quests](../progression/QUESTS.md), or change vitals. Effects are authored in `.tres` files, usually as inline sub-resources inside the action, quest, encounter, or item that owns them. Each owner keeps them in an `Array[EffectData]`, and runners call `process()` on each entry in order.

This hierarchy is separate from combat effects: `CombatEffectData` / `BuffEffectData` (see [COMBAT.md](../combat/COMBAT.md)) and `PathNodeEffectData` (see [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md)). Each of the three has its own `EffectType` enum.

## Player Experience

The player experiences effects as the results of their actions:

1. Finishing a conversation with the Celestial Intervener unlocks new actions (events) and starts or advances a quest (toast).
2. Completing **First Steps Out** grants a path point. Completing **Harden Your Core** puts the Refugee Camp Map in the inventory, logged as "Obtained 1x Refugee Camp Map".
3. Training at the Aura Well adds 1.5 Madra every second and +1 Spirit each time a training level is crossed.
4. Resting at an Aura Well restores HP and Madra in proportion to BODY and FOUNDATION.
5. Defeating a Ravenous Dreadbeast elite can drop a Dreadbeast Tooth Necklace (25%).
6. Using a Crude Scale or Barely Coalesced Scale consumable restores 20 Madra.

## Architecture

```
EffectData (@abstract, Resource)                 scripts/resource_definitions/effects/effect_data.gd
├── TriggerEventEffectData                       trigger_event_effect_data.gd
├── AwardResourceEffectData                      award_resource_effect_data.gd
├── AwardItemEffectData                          award_item_effect_data.gd
├── AwardLootTableEffectData                     award_loot_table_effect_data.gd
├── StartQuestEffectData                         start_quest_effect_data.gd
├── AwardAttributeEffectData                     award_attribute_effect_data.gd
├── AwardPathPointEffectData                     award_path_point_effect_data.gd
└── ChangeVitalsEffectData                       change_vitals_effect_data.gd
```

Execution is synchronous and context-free. `process()` takes no arguments; `AdventureTilemap`'s effect runner has a `# TODO: Pass context if needed`. Effects reach global state through autoloads. An effect that fires an event finishes its whole cascade (UnlockManager latch, quest advances, UI refresh) before the next effect in the array runs.

### Owners and runners

| Owner field | Runner | When it runs |
|---|---|---|
| `ZoneActionData.success_effects` / `failure_effects` | `ActionManager` | When the current action stops: `stop_action(successful)`, or when `select_action()` replaces it (which counts as success). NPC dialogue stops on `DialogueManager.dialogue_ended`; the Merchant stops when the player leaves the shop; adventures stop with `false` on time-out. |
| `TrainingActionData.effects_per_tick` | `ActionManager`'s training timer | Every `tick_interval_seconds` while the training action is selected |
| `TrainingActionData.effects_on_level` | Same | Once for each training level crossed. `TrainingPresenter` and the Now strip also read the first `AwardAttributeEffectData` here for "each level +1 Spirit" and "Lv n → n+1 · +1 Spirit". |
| `QuestData.completion_effects` | `QuestManager` | After the last step advances, before `quest_completed` |
| `EncounterChoice.success_effects` | `AdventureTilemap.select_choice()` (plain choices), or `AdventureTilemap` when the timeline ends (`DialogueChoice`) | Choice picked, or its timeline ended |
| `CombatChoice.success_effects` / `failure_effects` | `AdventureTilemap.handle_combat_result()` | Combat won (after gold is added) or lost |
| `ConsumableDefinitionData.effects` | `ConsumableDefinitionData.use()`, called from `InventoryManager.use_consumable()` | Consumable used. Its tooltip lines render each effect's `describe()`. |

## Data Model

### EffectData (base)

| Member | Type | Description |
|---|---|---|
| `effect_type` | `EffectType` (export) | Informational. Nothing dispatches on it; the only reader is `TriggerEventEffectData._to_string()`. |
| `process() -> void` | abstract | Apply the effect |
| `_to_string() -> String` | abstract | Debug representation |
| `describe() -> String` | virtual | Player-facing text for tooltips. Defaults to `_to_string()`; only `ChangeVitalsEffectData` overrides it. |

`EffectType`: `NONE` 0, `TRIGGER_EVENT` 1, `AWARD_RESOURCE` 2, `AWARD_ITEM` 3, `AWARD_LOOT_TABLE` 4, `START_QUEST` 5, `AWARD_ATTRIBUTE` 6, `AWARD_PATH_POINT` 7, `CHANGE_VITALS` 8.

Four subclasses set `effect_type` in `_init()`: StartQuest, AwardAttribute, AwardPathPoint, and ChangeVitals. The other four rely on the value stored in the `.tres`, so inline sub-resources that omit it report `NONE`.

### TriggerEventEffectData

| Field | Type | Default |
|---|---|---|
| `event_id` | `String` | `""` |

`process()`: with no EventManager → `Log.error`. With a non-empty `event_id` → `Log.info` and `EventManager.trigger_event(event_id)` (which does nothing if the event already fired). With an empty id → `Log.error`.

### AwardResourceEffectData

| Field | Type | Default |
|---|---|---|
| `resource_type` | `ResourceManager.ResourceType` (`MADRA` 0, `GOLD` 1) | `MADRA` |
| `amount` | `float` | `0.0` |
| `quiet` | `bool` | `false`. True skips the player-facing log line (the Aura Well trickle) |

`process()`: `ResourceManager.award_resource(resource_type, amount, quiet)` → `add_madra()` or `add_gold()`. A Madra gain stops at the stage max (Foundation 100 + 5 × Core Density level, Copper 600 + 10 × level), and a pool already above it is kept: `add_madra()` never lowers it. Unless the award is quiet, a Madra award logs `Gained <N> Madra` with the amount actually added, only when that is at least 1, and a gold award logs `Gained <N> Gold`.

### AwardItemEffectData

| Field | Type | Default |
|---|---|---|
| `item` | `ItemDefinitionData` | `null` |
| `quantity` | `int` | `1` |

`process()`: `InventoryManager.award_items(item, quantity)`. That routes by `item_type` (material, equipment, quest item, consumable) and logs "Looted …" or "Obtained …". There is no null-item guard.

### AwardLootTableEffectData

| Field | Type | Default |
|---|---|---|
| `loot_table` | `LootTable` | `null` |

`process()`: a null table → `Log.error`. Otherwise `loot_table.roll_loot()` returns `{ItemDefinitionData: quantity}`, and each entry is passed to `InventoryManager.award_items()`. An empty roll logs and returns.

### StartQuestEffectData

| Field | Type | Default |
|---|---|---|
| `quest_id` | `String` | `""` |

`process()`: an empty id → `push_error("StartQuestEffectData: empty quest_id")`. A missing QuestManager → `Log.error`. Otherwise `QuestManager.start_quest(quest_id)`, which handles unknown, active, and completed ids.

### AwardAttributeEffectData

| Field | Type | Default |
|---|---|---|
| `attribute_type` | `CharacterAttributesData.AttributeType` | `STRENGTH` (0) |
| `amount` | `float` | `1.0` |

`process()`: `CharacterManager.add_base_attribute(attribute_type, amount)`. The base attribute change is permanent.

### AwardPathPointEffectData

| Field | Type | Default |
|---|---|---|
| `amount` | `int` | `1` |

`process()`: `amount ≤ 0` does nothing, which guards against malformed `.tres`. A missing PathManager → `Log.error`. Otherwise `PathManager.add_points(amount)`, which emits `points_changed`.

### ChangeVitalsEffectData

| Field | Type | Default | Description |
|---|---|---|---|
| `health_change` | `float` | `0.0` | Flat HP |
| `stamina_change` | `float` | `0.0` | Flat stamina (never scaled) |
| `madra_change` | `float` | `0.0` | Flat Madra |
| `body_hp_multiplier` | `float` | `0.0` | Adds BODY × multiplier to HP |
| `foundation_madra_multiplier` | `float` | `0.0` | Adds FOUNDATION × multiplier to Madra |

- `get_final_health_change()` = `health_change + body_hp_multiplier × BODY`
- `get_final_madra_change()` = `madra_change + foundation_madra_multiplier × FOUNDATION`
- `get_final_stamina_change()` = `stamina_change`

Attributes come from `CharacterManager.get_total_attributes_data()`.

`process()`: `PlayerManager.vitals_manager.apply_vitals_change(health, stamina, madra)`. Without a vitals manager → `Log.error`.

`describe()` joins the non-zero parts, for example "+20 Madra", "+15 Health", or "+500% Body as Health". Whole numbers print without ".0". It returns "No effect" when every part is zero.

## Integration Points

| System | Connection |
|---|---|
| ActionManager | Runs zone action success and failure effects and training tick and level effects |
| QuestManager | Runs `completion_effects`; target of `StartQuestEffectData` |
| AdventureTilemap | Runs encounter and combat choice effects |
| InventoryManager | Target of item and loot-table effects; consumables run their effects through `use()` |
| EventManager | Target of `TriggerEventEffectData` |
| ResourceManager / CharacterManager / PathManager / PlayerManager | Targets of the award and vitals effects |
| Item tooltips | `ConsumableDefinitionData`'s tooltip lines call `describe()` |
| TrainingPresenter / NowStrip | Read `AwardAttributeEffectData` from `effects_on_level` for the level reward text; `TrainingActionData.get_madra_per_second()` reads the MADRA `AwardResourceEffectData` in `effects_per_tick` for the rate |

## Existing Content

Every authored effect instance:

| Owner | Effect | Values |
|---|---|---|
| `resources/effects/trigger_event/celestial_intervener_dialogue_1.tres` (in NPC 1 `success_effects[0]`) | TriggerEvent | `celestial_intervener_dialogue_1` |
| `celestial_intervener_dialogue_1.tres` (NPC 1) `success_effects[1]` (inline) | StartQuest | `q_fill_core` |
| `celestial_intervener_dialogue_2.tres` (NPC 2) | TriggerEvent → StartQuest | `celestial_intervener_dialogue_2` → `q_first_steps` |
| `celestial_intervener_dialogue_3.tres` (NPC 3) | TriggerEvent → StartQuest | `celestial_intervener_dialogue_3` → `q_reach_core_density_10` |
| `celestial_intervener_dialogue_4.tres` (NPC 4) | TriggerEvent | `celestial_intervener_dialogue_4` |
| `q_fill_core.tres` `completion_effects` | TriggerEvent | `q_fill_core_completed` |
| `q_first_steps.tres` `completion_effects` | AwardPathPoint | `amount` 1 |
| `q_reach_core_density_10.tres` `completion_effects` | AwardItem | `refugee_camp_map` × 1 |
| `aura_well_madra_trickle_effect.tres` (Aura Well `effects_per_tick`) | AwardResource | MADRA, 1.5, quiet |
| `aura_well_spirit_award_effect.tres` (Aura Well `effects_on_level`) | AwardAttribute | SPIRIT (3), 1.0 |
| `aura_well_encounter.tres` "Rest" choice | ChangeVitals | `body_hp_multiplier` 5.0, `foundation_madra_multiplier` 2.0 (+50 HP and +20 Madra at the default 10 BODY / 10 FOUNDATION) |
| `aura_well_encounter.tres` "Mark down the location" choice | ChangeVitals (same sub-resource as Rest) → TriggerEvent | `aura_well_discovered` |
| `refugee_camp_encounter.tres` "Approach the camp" choice | TriggerEvent | `merchant_discovered` |
| `ravenous_dreadbeast_encounter.tres` "Attack the Dreadbeast" (`CombatChoice.success_effects`) | AwardLootTable | Inline table: `dreadbeast_tooth_necklace`, `drop_chance` 0.25 |
| `resources/items/consumables/crude_scale.tres` | ChangeVitals | `madra_change` 20.0 (`cooldown_seconds` 10.0) |
| `resources/items/consumables/barely_coalesced_scale.tres` | ChangeVitals | `madra_change` 20.0 (`cooldown_seconds` 10.0) |
| `test_rest_encounter.tres`, `test_trap_encounter.tres`, `test_treasure_encounter.tres` | ChangeVitals / AwardLootTable | Test encounters that no `AdventureData` places |
| `resources/effects/award_resource/award_madra_5_effect_data.tres` | AwardResource | MADRA, 5.0. Not referenced anywhere. |

Authoring conventions:

- One-off effects are inline sub-resources. Promote an effect to its own `.tres` only when several owners reuse it.
- In NPC `success_effects`, put `TriggerEventEffectData` before `StartQuestEffectData` so the current quest completes before the next one starts. See [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](../progression/QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md).

## Key Files

| File | Purpose |
|---|---|
| `scripts/resource_definitions/effects/effect_data.gd` | Abstract base and `EffectType` |
| `scripts/resource_definitions/effects/*.gd` | The eight subclasses |
| `singletons/action_manager/action_manager.gd` | Zone action and training effect runner |
| `singletons/quest_manager/quest_manager.gd` | Quest completion effect runner |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | Encounter and combat choice effect runner |
| `scripts/resource_definitions/items/consumable_definition_data.gd` | Consumable effect runner and tooltip lines |
| `resources/effects/` | The two standalone effect files |

Tests: `tests/unit/test_*_effect_data.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Bugs

- `[LOW]` `AwardItemEffectData.process()` has no null guard. A null `item` reaches `InventoryManager.award_items()`, which emits `item_awarded(null, …)` and then dereferences `item.item_type`.

### Missing Functionality

- `[MEDIUM]` Effects receive no context: `process()` takes no source, target, or combatant. Effects that target a specific combatant, or scale with the source, would require an API change.
- `[MEDIUM]` No effect can advance the cultivation stage, change Core Density or unlock a zone. The Tribulation (Beat 9) does not use one: `TribulationView` calls `CultivationManager.advance_to_next_stage()` or `lose_core_density_levels()` itself the moment the run ends. An action's `success_effects` and `failure_effects` run in `stop_action()`, when the player presses Continue, so closing the game on the result panel would have skipped the penalty (`tribulation_view.gd:480-501`).
- `[LOW]` Only `ChangeVitalsEffectData` overrides `describe()`. Any other effect shown in a tooltip, for example a consumable that awards a resource, would display the multi-line debug `_to_string()` text.

### Content

- `[LOW]` `resources/effects/award_resource/award_madra_5_effect_data.tres` is orphaned.

### Tech Debt

- `[LOW]` `effect_type` is informational and inconsistent. TriggerEvent, AwardResource, AwardItem, and AwardLootTable don't set it in `_init()`. As a result the inline triggers in `aura_well_encounter.tres` and `refugee_camp_encounter.tres`, and the AwardItem in `q_reach_core_density_10.tres`, report `NONE`. Either set it in every `_init()` or drop the field.
- `[LOW]` Error reporting is inconsistent: `StartQuestEffectData` uses `push_error` for a bad id, while the other effects use `Log.error`.
- `[LOW]` Three unrelated hierarchies share the word "effect": `EffectData`, `CombatEffectData`, and `PathNodeEffectData`, each with its own `EffectType` enum. Docs and code reviews should say which one they mean.
