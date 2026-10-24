# Unlock System

Last updated: 2026-10-22

## Overview

Content gating is built on one resource class, `UnlockConditionData`: a named predicate over game state (event fired, Core Density level, Madra, item owned, and so on). It is consumed in two ways:

- **Latched.** `UnlockManager` sweeps every condition registered in `resources/unlocks/unlock_condition_list.tres` whenever relevant state changes. A condition that evaluates true is recorded permanently in the save and announced with `condition_unlocked`. Zones (their map state) and zone actions gate on this latched set.
- **Live.** Quest steps, adventure encounter eligibility, and encounter choice requirements call `UnlockConditionData.evaluate()` directly every time they check. Live checks don't need registration and never latch.

## Player Experience

1. **Zone actions appear.** Spirit Valley starts with a single action, "Talk to the [INTERVENER]". More cards appear in the zone chest's activity list as their conditions latch, each with a NEW seal until it is hovered or used, and a latched action never disappears again. When the zone's first idle action unlocks while nothing runs, it starts on its own.
2. **Zone hexes unlock.** A zone whose `chart_conditions` haven't latched is UNCHARTED: a dark veil with a "?" glyph. A charted zone whose `zone_unlock_conditions` haven't latched is LOCKED: a veil with a padlock, a plate naming the blocker, and a popover with the full requirement (clicking shakes the lock). Once the conditions latch, the veil gives way to the zone's tile with a hairline rim, and a dotted route leads to it. Today only the dev demo zones use these states; Test Zone is gated too but hidden on the map.
3. **Encounter choices gray out.** A choice whose `requirements` fail is disabled. A choice whose `completion_condition` holds is disabled and shows its `completed_label`. Example: "Mark down the location" becomes "✓ Location noted".
4. **Encounters disappear.** An encounter whose `unlock_conditions` don't match is never placed on generated maps. The Refugee Camp only appears while the map is owned and the merchant is undiscovered.

## Architecture

```
UnlockManager (autoload #5, singletons/unlock_manager/unlock_manager.gd)
  @export unlock_condition_list: UnlockConditionList
        = preload("res://resources/unlocks/unlock_condition_list.tres")
  live_save_data.unlock_progression.unlocked_condition_ids   (latched ids)
  sweeps on: EventManager.event_triggered
             CultivationManager.advancement_stage_changed
             CultivationManager.core_density_level_updated
             ResourceManager.madra_changed
             ResourceManager.gold_changed
  emits:     condition_unlocked(condition_id: String)

condition_unlocked listeners:
  ZonePanel._on_condition_unlocked      → rebuild the zone chest's activity list
  ZoneTilemap._on_condition_unlocked    → rebuild the map: zones, fog, hex states, routes, plates
  ActionManager._on_condition_unlocked  → nothing running: start the zone's first idle action ("Started …")
  QuestManager._on_condition_unlocked   → re-check active condition steps
```

### Latched vs live evaluation

| | Latched | Live |
|---|---|---|
| API | `UnlockManager.are_unlock_conditions_met(conditions)` / `is_condition_unlocked(condition_id)` | `UnlockConditionData.evaluate()` |
| Registration in `unlock_condition_list.tres` | Required. An unregistered id never latches. | Not needed |
| Keyed by | `condition_id` string only | The resource's own fields |
| Can turn false again | No | Yes |
| Consumers | `ZoneManager.get_available_actions()` (zone and action gates); `ZoneManager.get_zone_map_state()` (`chart_conditions` → UNCHARTED, `zone_unlock_conditions` → LOCKED), which `ZoneTilemap` and `MapMarkers` draw | `QuestManager` condition steps; `AdventureEncounter.is_eligible()` (map generation); `EncounterChoice.evaluate_requirements()` / `is_completed()` (encounter panel); the Goals board's step figure (`get_current_value()` / `get_target_value()`) |

Consequences:

- Latched gates never re-lock. "Return to the [INTERVENER]" (NPC 2) stays visible after Madra drops below 100.
- An empty `unlock_conditions` array counts as met in `are_unlock_conditions_met()`.
- `force_unlock_condition()` writes to the latched set only. A forced `EVENT_TRIGGERED` condition shows its zone actions, but quest event steps and live checks still see the event as unfired.

## Data Model

### UnlockConditionData (`scripts/resource_definitions/unlocks/unlock_condition_data.gd`)

| Field | Type | Default | Description |
|---|---|---|---|
| `condition_id` | `String` | `""` | Unique id. This is the key in the latched set. |
| `condition_type` | `ConditionType` | `CULTIVATION_STAGE` | What to evaluate |
| `target_value` | `Variant` | `null` | Comparison target (number, enum int, event id, or item id) |
| `comparison_op` | `String` | `">="` | One of `>=`, `>`, `<=`, `<`, `==`, `!=`. Any other value, including `""`, makes comparison types return `false`. |
| `optional_params` | `Dictionary` | `{}` | Type-specific parameters (see below) |

`evaluate() -> bool` dispatches on `condition_type`:

| # | ConditionType | Evaluates | Params / notes |
|---|---|---|---|
| 0 | `CULTIVATION_STAGE` | `CultivationManager.get_current_advancement_stage()` `op` `target_value` | Target is an `AdvancementStage` int (FOUNDATION 0, COPPER 1, IRON 2, JADE 3, SILVER 4) |
| 1 | `CULTIVATION_LEVEL` | `CultivationManager.get_core_density_level()` (float) `op` `target_value` | |
| 2 | `ZONE_UNLOCKED` | Always `false`, with `Log.warn("… not yet implemented")` | Not implemented |
| 3 | `ADVENTURE_COMPLETED` | Always `false`, with `Log.warn` | Not implemented |
| 4 | `EVENT_TRIGGERED` | `EventManager.has_event_triggered(target_value)` | `comparison_op` is ignored |
| 5 | `ITEM_OWNED` | `InventoryManager.has_item(str(target_value))` | Matches `item_id` across materials (qty > 0), the equipment grid, equipped gear, equipped accessories, quest items (qty > 0), and consumables (qty > 0). `comparison_op` is ignored. |
| 6 | `RESOURCE_AMOUNT` | `ResourceManager.get_madra()` or `get_gold()` `op` `target_value` | `optional_params.resource_type` is `"madra"` (default) or `"gold"`. Any other value compares against 0.0. |
| 7 | `ATTRIBUTE_VALUE` | `CharacterManager.get_total_attributes_data().get_attribute(type)` `op` `target_value` | `optional_params.attribute_type` is an `AttributeType` int (default `STRENGTH`). Uses total attributes (base plus bonuses). |

Progress getters, which the Goals board reads to show `current / target` under a quest step:

| Method | Returns |
|---|---|
| `is_measurable() -> bool` | True for `RESOURCE_AMOUNT` and `CULTIVATION_LEVEL` |
| `get_current_value() -> float` | The value `evaluate()` compares: Madra or gold, or the Core Density level. 0.0 when not measurable |
| `get_target_value() -> float` | `target_value` as a number. 0.0 when not measurable or not numeric |

### UnlockConditionList (`scripts/resource_definitions/unlocks/unlock_condition_list.gd`)

| Field | Type | Description |
|---|---|---|
| `list` | `Array[UnlockConditionData]` | The registry that UnlockManager sweeps |

### UnlockProgressionData (`singletons/persistence_manager/unlock_progression_data.gd`)

| Field | Type | Description |
|---|---|---|
| `unlocked_condition_ids` | `Array[String]` | Latched condition ids, in unlock order |

Stored as `SaveGameData.unlock_progression`. `reset()` replaces it with a fresh instance.

## Core Systems

### UnlockManager API

| Member | Description |
|---|---|
| `signal condition_unlocked(condition_id: String)` | Emitted once per newly latched id. Also emitted with `""` on init and on save reset so that listeners refresh. |
| `are_unlock_conditions_met(unlock_conditions: Array[UnlockConditionData]) -> bool` | True if every condition's id is latched |
| `is_condition_unlocked(condition_id: String) -> bool` | Latched-set membership |
| `force_unlock_condition(condition_id: String) -> void` | Dev-only. Latches the id and emits `condition_unlocked`. Idempotent. |

### Sweep

```
<listened signal>
  → _evaluate_all_conditions()
      for condition in unlock_condition_list.list:
          skip if is_condition_unlocked(condition.condition_id)
          if condition.evaluate():
              _unlock_condition(id): append to unlocked_condition_ids,
                                     condition_unlocked.emit(id),
                                     Log.info("UnlockManager: Condition permanently unlocked: …")
```

UnlockManager does **not** listen to `InventoryManager.inventory_changed`, `CharacterManager.base_attribute_changed`, or `CultivationManager.core_density_xp_updated`. A registered `ITEM_OWNED` or `ATTRIBUTE_VALUE` condition therefore latches on the next Madra, Gold, Core Density level, stage, or event signal after it becomes true.

### Boot and save reset

- `_ready()` binds the save. If `unlock_progression` is null it creates one and logs `Log.critical`. It then calls `_initialize_from_save()`, which rebinds and emits `condition_unlocked("")`, and connects the sweep signals.
- The first sweep at boot happens when ResourceManager (autoload #6) emits its initial `madra_changed` and `gold_changed`. QuestManager connects later (#17), so it misses `condition_unlocked` emissions from that boot sweep.
- On `save_data_reset`, `_initialize_from_save()` rebinds and emits `condition_unlocked("")`. ResourceManager then re-emits Madra and Gold, which triggers a sweep.

### Example gate flow (first NPC talk)

```
Click "Talk to the [INTERVENER]" (celestial_intervener_dialogue_1, max_completions 1)
→ Dialogic plays celestial_intervener_introduction_1 @ label dialogue_1
→ DialogueManager.dialogue_ended → ActionManager.stop_action(true)
→ success_effects[0]: TriggerEventEffectData → EventManager.trigger_event("celestial_intervener_dialogue_1")
→ UnlockManager sweep → condition celestial_intervener_dialogue_1 latches → condition_unlocked
     ZonePanel:     "Wilderness Cycling" appears under Cultivate, with a NEW seal
     ZoneManager:   Test Zone unlocks (it stays hidden on the map at (-1, 0) unless the dev panel shows hidden zones)
→ success_effects[1]: StartQuestEffectData → QuestManager.start_quest("q_fill_core")
```

### Dev tooling

The dev panel opens with Ctrl+Shift+D. It fills a dropdown with every `condition_id` in `unlock_condition_list.list`. "Apply" calls `UnlockManager.force_unlock_condition(id)` and logs `[DEV] Force-triggered condition '<id>'`.

## Integration Points

| System | Connection |
|---|---|
| ZoneManager | `get_available_actions()` drops a zone's actions if `zone_unlock_conditions` aren't latched, and drops any action whose `unlock_conditions` aren't latched. It also filters actions by `max_completions`. |
| ZoneManager map states | `get_zone_map_state()` reads a zone's `chart_conditions` (UNCHARTED until latched) and `zone_unlock_conditions` (LOCKED until latched) the latched way |
| ZoneTilemap / MapMarkers | Redraw zones, fog tiers, veils, routes, plates and glyphs on `condition_unlocked` |
| ZonePanel | Rebuilds the activity list on `condition_unlocked` |
| ActionManager | On `condition_unlocked` with nothing running, starts the zone's first idle action and logs "Started <name>" |
| GoalsPanel | Shows `current / target` for a quest step whose conditions are all measurable |
| QuestManager | Re-checks condition steps on `condition_unlocked`. See [QUESTS.md](../progression/QUESTS.md). |
| EventManager | Sweep trigger. Read live by `EVENT_TRIGGERED`. See [EVENTS.md](EVENTS.md). |
| Adventure map generator | `AdventureEncounter.is_eligible()` filters `encounter_quotas` before placement (anchors, fillers, filler fallback). It always returns true in the editor. |
| EncounterInfoPanel | `EncounterChoice.evaluate_requirements()` and `is_completed()` set each button's disabled state and label |
| CultivationManager / ResourceManager | Sweep triggers and evaluation sources |
| InventoryManager / CharacterManager | Evaluation sources only (not sweep triggers) |
| DevPanel | `force_unlock_condition()` |

## Existing Content

### Registered conditions (`unlock_condition_list.tres`, in list order)

| # | condition_id | Type | Target / params | Op | Consumed by |
|---|---|---|---|---|---|
| 1 | `celestial_intervener_dialogue_1` | EVENT_TRIGGERED | `"celestial_intervener_dialogue_1"` | `""` (ignored) | `wilderness_cycling_action.unlock_conditions`; `test_zone.zone_unlock_conditions` |
| 2 | `test_attribute_requirement_unlock_data` | ATTRIBUTE_VALUE | 20.0, `attribute_type` 1 (BODY) | `>=` (default) | `test_trap_encounter.tres` choice `requirements`. That encounter is not placed by any adventure, so the condition is effectively unused. |
| 3 | `q_fill_core_madra_full` | RESOURCE_AMOUNT | 100.0, `resource_type` `"madra"` | `>=` (default) | `q_fill_core` step `reach_max_madra`; `celestial_intervener_dialogue_2.unlock_conditions` |
| 4 | `q_fill_core_completed` | EVENT_TRIGGERED | `"q_fill_core_completed"` | `""` | `spirit_valley_adventure_action` (action id `shallow_woods_adventure_action`); `spring_forest_foraging_action` (action id `sprint_forest_foraging_action`) |
| 5 | `q_first_steps_enemy_defeated` | EVENT_TRIGGERED | `"q_first_steps_enemy_defeated"` | `""` | `celestial_intervener_dialogue_3.unlock_conditions` |
| 6 | `q_reach_cd_10` | CULTIVATION_LEVEL | 10 | `>=` | `q_reach_core_density_10` step `reach_cd_10`; `celestial_intervener_dialogue_4.unlock_conditions` |
| 7 | `aura_well_discovered` | EVENT_TRIGGERED | `"aura_well_discovered"` | `"=="` (ignored) | `aura_well_training.unlock_conditions`; `aura_well_encounter` "Mark down the location" `requirements` (`false`) and `completion_condition` |
| 8 | `merchant_discovered` | EVENT_TRIGGERED | `"merchant_discovered"` | `"=="` (ignored) | `spirit_valley_merchant.unlock_conditions` |

### Unregistered (inline) conditions

These are evaluated live only.

| Owner | condition_id | Type | Target | Expected |
|---|---|---|---|---|
| `refugee_camp_encounter.tres` `unlock_conditions` | `refugee_camp_map_owned` | ITEM_OWNED | `"refugee_camp_map"` | `true` |
| `refugee_camp_encounter.tres` `unlock_conditions` | `merchant_discovered` (inline duplicate of #8) | EVENT_TRIGGERED | `"merchant_discovered"` | `false` |

### Gates by consumer

| Gate | Conditions |
|---|---|
| Spirit Valley zone (`SpiritValley`, tile (0,0)) | None (always unlocked) |
| Test Zone (`TestZone`, tile (-1, 0) west of Spirit Valley, hidden on the map, no description, no actions) | `celestial_intervener_dialogue_1` |
| Dev demo zones (`AdvancementZoneDemo` locked, `UnchartedZoneDemo` uncharted; dev toggle only) | `dev_demo_never_unlocked` (`resources/zones/dev/dev_never_unlocked_condition.tres`), deliberately **not** registered, so it never latches |
| Talk to the [INTERVENER] (`celestial_intervener_dialogue_1`, max 1) | None |
| Wilderness Cycling (`wilderness_cycling_action`) | `celestial_intervener_dialogue_1` |
| Return to the [INTERVENER] (`celestial_intervener_dialogue_2`, max 1) | `q_fill_core_madra_full` |
| The Shallow Woods (`shallow_woods_adventure_action`) | `q_fill_core_completed` |
| Spring Forest Foraging (`sprint_forest_foraging_action`) | `q_fill_core_completed` |
| Return to the [INTERVENER] (`celestial_intervener_dialogue_3`, max 1) | `q_first_steps_enemy_defeated` |
| Return to the [INTERVENER] (`celestial_intervener_dialogue_4`, max 1) | `q_reach_cd_10` |
| Aura Well (`aura_well_training`) | `aura_well_discovered` |
| Traveling Merchant (`spirit_valley_merchant`) | `merchant_discovered` |
| Refugee Camp encounter (map generation) | Map owned = true AND `merchant_discovered` = false (live) |
| Aura Well "Mark down the location" choice | `aura_well_discovered` = false (live). It shows as completed once the condition is true. |

## Key Files

| File | Purpose |
|---|---|
| `singletons/unlock_manager/unlock_manager.gd` | Sweep, latch, signal, dev force-unlock |
| `scripts/resource_definitions/unlocks/unlock_condition_data.gd` | Condition definition and `evaluate()` |
| `scripts/resource_definitions/unlocks/unlock_condition_list.gd` | Registry class |
| `singletons/persistence_manager/unlock_progression_data.gd` | Saved latched ids |
| `resources/unlocks/unlock_condition_list.tres` | The registry |
| `resources/unlocks/*.tres` | Registered conditions (8) |
| `singletons/zone_manager/zone_manager.gd` | `get_available_actions()` latched gating |
| `scenes/zones/zone_tilemap/zone_tilemap.gd` | Map rebuild on unlock: veils, fog tiers and routes |
| `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd` | `unlock_conditions` / `is_eligible()` |
| `scripts/resource_definitions/adventure/choices/encounter_choice.gd` | `requirements` / `completion_condition` |
| `scenes/ui/dev_panel/dev_panel.gd` | Force-unlock dropdown |

## Tests

| File | Covers |
|---|---|
| `tests/unit/test_unlock_manager.gd` | `force_unlock_condition` adds the id, is idempotent, and emits `condition_unlocked` |
| `tests/unit/test_unlock_condition_item_owned.gd` | `ITEM_OWNED` is false when the item is missing and true after awarding a quest item |
| `tests/unit/test_encounter_choice.gd` | `requirements` with expected true, false, and mixed values; `is_completed()` |
| `tests/unit/test_adventure_encounter.gd` | `is_eligible()` with no conditions, with an event required, and with expected `false` |
| `tests/unit/test_adventure_map_generator.gd` | An ineligible encounter is skipped during placement |
| `tests/integration/test_aura_well_discovery_unlock.gd` | Aura Well action is hidden until `aura_well_discovered` fires, then visible (via `ZoneManager.get_available_actions`) |
| `tests/integration/test_beat_3b_merchant_unlock.gd` | NPC 4 gated on CD 10; Merchant gated on `merchant_discovered`; Refugee Camp eligibility before and after discovery |
| `tests/unit/test_unlock_condition_progress.gd` | `is_measurable()` and the current and target values for `RESOURCE_AMOUNT` and `CULTIVATION_LEVEL`; event conditions are not measurable |
| `tests/unit/test_zone_map_state.gd` | Chart and unlock conditions turning into the UNCHARTED, LOCKED, CURRENT and OPEN map states |
| `tests/integration/test_idle_action_resolution.gd` | The first idle unlock auto-starts; the save reset's empty `condition_unlocked("")` does not |

Untested: the sweep itself (`_evaluate_all_conditions`), `CULTIVATION_STAGE`, `ATTRIBUTE_VALUE`, comparison operators other than `>=`, and a data check that every gate's condition is registered.

## Work Remaining

### Bugs

- `[MEDIUM]` Dev-panel force-unlock splits latched and live state. Forcing an `EVENT_TRIGGERED` condition shows its gated actions without recording the event, so quest event steps and live checks still treat the event as unfired. This can soft-lock quests (see [QUESTS.md](../progression/QUESTS.md) Work Remaining). For `EVENT_TRIGGERED` conditions the dev action should call `EventManager.trigger_event(target_value)` instead.

### Missing Functionality

- `[MEDIUM]` `ZONE_UNLOCKED` and `ADVENTURE_COMPLETED` always return `false` and `Log.warn` on every evaluation. Registering either would log a warning on every sweep, which happens at least once per second while at the Aura Well. Planned Beats 7–8 (Guardian, Advancement Zone) need one of these, or a dedicated event.
- `[MEDIUM]` The sweep doesn't listen to `InventoryManager.inventory_changed` or `CharacterManager.base_attribute_changed`. Registered `ITEM_OWNED` and `ATTRIBUTE_VALUE` conditions latch late, and quest steps that use them only re-check on unrelated triggers.
- `[LOW]` No conditions are registered yet for the breakthrough and Copper gates (`CULTIVATION_LEVEL ≥ 100`, `CULTIVATION_STAGE ≥ COPPER`), although the evaluation code supports both.
- `[LOW]` `ITEM_OWNED` behaves differently in the two modes: it latches when registered but reverts in live checks once the item is gone. This is harmless today because the Refugee Camp Map is never consumed.

### Content

- `[LOW]` `test_attribute_requirement_unlock_data` (BODY ≥ 20) is registered, so it is evaluated on every sweep, but only the unplaced `test_trap_encounter.tres` uses it. Remove it from the registry or move it to test fixtures.
- `[LOW]` `refugee_camp_encounter.tres` defines its own inline `merchant_discovered` condition instead of referencing `resources/unlocks/merchant_discovered.tres`.

### Performance

- `[LOW]` `_evaluate_all_conditions()` evaluates every registered condition on every listened signal. `madra_changed` fires on every Aura Well tick (1 s), during cycling, and on adventure spending. With 8 conditions this is cheap, but at scale the sweep should be filtered by the signal's relevant condition types.

### Tech Debt

- `[LOW]` The public `UnlockManager.are_unlock_conditions_met()` has no `##` doc comment.
- `[LOW]` `comparison_op` is never validated. Event conditions are authored with `""` or `"=="` (both ignored), but an empty or unknown op on a comparison type silently evaluates `false`.
- `[LOW]` Mismatched ext_resource UIDs fall back to the path, and Godot warns on load. `q_first_steps_enemy_defeated.tres` (header `uid://bqfsendefeat01`) is referenced as `uid://d1vxkodelucwu`, and `q_reach_cd_10.tres` (header `uid://bqreachcd10001`) as `uid://i2xnqd3pem53`. `merchant_discovered.tres` uses the hand-written `uid://bunlock_mrch_discov`.
- `[LOW]` No data-validation test ensures that every condition used by a zone or action gate is registered. An unregistered gate hides its action forever.
