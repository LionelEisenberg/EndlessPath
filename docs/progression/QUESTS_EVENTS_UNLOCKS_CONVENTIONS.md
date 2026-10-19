# Quests, Events, and Unlock Conditions: Authoring Conventions

Last updated: 2026-10-18

> A one-page reference for choosing a primitive and wiring a story beat. For mechanics, see [QUESTS.md](QUESTS.md), [EVENTS.md](../infrastructure/EVENTS.md), [UNLOCKS.md](../infrastructure/UNLOCKS.md), and [EFFECTS.md](../infrastructure/EFFECTS.md).

## The three primitives

| Primitive | What it is | Where it lives | Lifetime |
|---|---|---|---|
| **Event** | A one-shot "this happened" string id | `EventManager`. Fired by `TriggerEventEffectData` or code. | Fires once and is saved forever. Firing it again does nothing. |
| **Unlock condition** | A named predicate (`UnlockConditionData`) over events, levels, resources, attributes, or items | `resources/unlocks/*.tres`, plus inline sub-resources | **Latched** once registered in `unlock_condition_list.tres` and true. **Live** when a consumer calls `evaluate()`. |
| **Quest step** | One stage of a linear quest | `QuestStepData` inside `resources/quests/q_*.tres` | Advances once, on its event **or** when all of its conditions are true |

Events are signals; conditions are predicates. Zone tiles and zone actions gate only on **latched** conditions. Quest steps, encounter eligibility, and choice requirements evaluate conditions **live**.

## Decision tree

```
A moment happens in the game.
│
├─ 1. Fire an event: TriggerEventEffectData in the owning action, quest, or choice
│     (code only when no effect array exists, e.g. AdventureCombat).
│
├─ 2. Will a zone, zone action, or other latched consumer gate on it?
│     YES → add an EVENT_TRIGGERED UnlockConditionData with the same id
│           and register it in unlock_condition_list.tres.
│     NO  → no wrapper is needed. Live consumers can use an inline condition.
│
└─ 3. Will a quest step advance on it?
      ├─ a one-shot moment             → completion_event_id = "<event id>"
      └─ a state predicate (Madra, CD, attribute, item)
                                       → completion_conditions = [<condition>]
                                         (no event; register it so condition_unlocked re-checks the step)
```

## Rules

1. **Pattern B: chains live on NPC actions.** A quest never references another quest. The NPC action that completes quest N also starts quest N+1, with its `success_effects` in the order `TriggerEvent` (completes N and runs N's `completion_effects`) then `StartQuest(N+1)`. A quest's own `completion_effects` hold only its rewards.
2. **Gate each "return" NPC on whatever completes the previous step.** An event step only matches an event that fires *while that step is current*, and QuestManager never re-checks a step after advancing. If an event can fire early, its step becomes uncompletable.
3. **One criterion per step.** If a step sets both, the event wins; if it sets neither, the step auto-advances. QuestManager reports both cases with `push_error` at boot.
4. **Register every condition that a zone or action gates on.** An unregistered condition never latches, so the action stays hidden forever. Register condition steps too, so the step is re-checked when the condition flips.
5. **Inline one-off effects and conditions** as sub-resources. Promote them to their own `.tres` only when several owners share them. Don't duplicate a registered condition inline: reference the file.
6. **Add new quests to `resources/quests/quest_list.tres`**, and register new timelines in `project.godot` `[dialogic] directories/dtl_directory` (the Dialogic editor does this).
7. **Let Godot assign UIDs.** Hand-written or copied UIDs force a fallback to the path and a load warning.

## Naming

- An event and the condition that wraps it share **one id**, for example `aura_well_discovered` for both.
- Quest-scoped ids take the quest id as a prefix: `q_fill_core_madra_full`, `q_fill_core_completed`, `q_first_steps_enemy_defeated`. The CD condition is the exception: `q_reach_cd_10` belongs to `q_reach_core_density_10`.
- An NPC dialogue action's `action_id` equals the event it fires, and both match the Dialogic label: `celestial_intervener_dialogue_N` with label `dialogue_N`.
- Quest ids are `q_<snake_case>`. Step ids are descriptive and unique within the quest (`reach_max_madra`, `return_to_npc`).

## Examples from the Foundation chain

| Moment / state | Event | Condition | Why |
|---|---|---|---|
| NPC 1 talked | `celestial_intervener_dialogue_1` | `celestial_intervener_dialogue_1` (EVENT_TRIGGERED, registered) | Wilderness Cycling and the Test Zone tile gate on it |
| Madra reaches 100 | *(none: a state)* | `q_fill_core_madra_full` (RESOURCE_AMOUNT ≥ 100, registered) | Quest step and NPC 2 visibility share one predicate |
| NPC 2 talked | `celestial_intervener_dialogue_2` | *(none)* | Only `q_fill_core` step 1 consumes it |
| `q_fill_core` completes | `q_fill_core_completed` (from `completion_effects`) | `q_fill_core_completed` (registered) | Adventure and Foraging gate on it |
| First combat won | `q_first_steps_enemy_defeated` (code, `AdventureCombat`) | `q_first_steps_enemy_defeated` (registered) | Quest step 0 advances on the event; NPC 3 gates on the condition |
| NPC 3 / NPC 4 talked | `celestial_intervener_dialogue_3` / `_4` | *(none)* | Only the quests' `return_to_npc` steps consume them |
| Core Density reaches 10 | *(none: a state)* | `q_reach_cd_10` (CULTIVATION_LEVEL ≥ 10, registered) | Quest step 0 and NPC 4 visibility |
| Aura Well "Mark down the location" | `aura_well_discovered` | `aura_well_discovered` (registered) | Gates the training action (latched). Also the choice's `requirements` (expected `false`) and `completion_condition` (live). |
| Refugee Camp approached | `merchant_discovered` | `merchant_discovered` (registered) | Gates the Merchant action (latched). The camp's own `unlock_conditions` use an inline copy (expected `false`). |
| Player owns the map | *(none: a state)* | `refugee_camp_map_owned` (ITEM_OWNED, inline, unregistered) | Only map generation reads it, live, so registration isn't needed |

## Common pitfalls

1. **Gate action never appears.** The condition isn't registered in `unlock_condition_list.tres`.
2. **Quest stuck on a "return" step.** Its event fired before the step became current, for example because the NPC was reachable too early. The dev panel's force-unlock causes the same thing.
3. **Quest condition step lags.** The condition is unregistered or of a type UnlockManager doesn't sweep on (`ITEM_OWNED`, `ATTRIBUTE_VALUE` only latch on the next Madra, Gold, CD, stage, or event signal), so the step waits for an unrelated trigger.
4. **Comparison condition always false.** `comparison_op` is empty or misspelled. Event and item conditions ignore the op; numeric conditions don't.
5. **Dev force-unlock doesn't fire the event.** Latched gates open, but quest event steps and live checks still see the event as unfired.
6. **`ZONE_UNLOCKED` / `ADVENTURE_COMPLETED`.** Both always return `false` and log a warning on every evaluation. Use an event instead.
