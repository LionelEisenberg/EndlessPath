# Quests, Events, and Unlock Conditions — Authoring Conventions

> One-page reference for when to use which primitive. Written after Beat 1 exposed the dual-pattern confusion between `completion_event_id` and `completion_conditions` on quest steps.

## The three primitives

| Primitive | What it is | Where it lives | Lifetime |
|---|---|---|---|
| **Event** | One-shot signal that something happened. Just a string id. | `EventManager` | Fires once, persists forever via `has_event_triggered` |
| **Unlock Condition** | Named, latching predicate over game state. Can wrap events, resource amounts, cultivation levels, attributes, item ownership, etc. | `UnlockManager` catalog (`resources/unlocks/unlock_condition_list.tres`) | Once true, stays true in save data |
| **Quest Step** | A stage of a quest. Advances when either a specific event fires *or* all its conditions evaluate true. | `QuestStepData` inside a `QuestData.tres` | Advances once, then the quest moves to the next step |

**Events are signals. Unlock conditions are predicates consumed by gates.** Quest steps can consume *either* events or conditions directly. Everything else (zone actions, UI, etc.) consumes conditions only.

## Decision tree

```
Something is happening in the game and I want to react to it.
│
├─ 1. Fire an event. Always. One line: `EventManager.trigger_event("moment_id")`.
│     Cost is near-zero. Events are cheap and future-proof.
│
├─ 2. Will any NON-quest consumer gate on this moment?
│     (e.g., zone action unlock_conditions, UI visibility, another
│      condition set combining multiple predicates)
│
│     YES → Register an UnlockConditionData.
│           `condition_type = EVENT_TRIGGERED, target_value = "moment_id"`
│           Add it to `unlock_condition_list.tres`. Consumers reference the condition.
│
│     NO  → Skip the wrapper. Only the quest step references the event directly.
│
└─ 3. Will a quest step advance on this moment?
      │
      ├─ Only this one moment matters for advancement
      │    → Quest step uses `completion_event_id = "moment_id"`. Done.
      │
      └─ Advancement depends on state predicates (madra amount, CD level,
         attribute value), not a one-shot moment
           → Don't fire an event. Use an UnlockConditionData of the
             appropriate type (RESOURCE_AMOUNT, CULTIVATION_LEVEL, etc.) in
             `completion_conditions`. QuestManager re-evaluates on
             `condition_unlocked`.
```

## Rule of thumb in one line

> **Always fire an event for moments. Wrap in an unlock condition only when something other than a quest step also needs to gate on the moment. Use state-predicate unlock conditions directly for non-moment checks (resource amounts, levels, etc.).**

## Examples from Foundation Beat 1

| Moment / state | Event | Unlock Condition | Why the condition (if any) |
|---|---|---|---|
| NPC 1 talked | `celestial_intervener_dialogue_1` | `celestial_intervener_dialogue_1` (EVENT_TRIGGERED) | Wilderness Cycling's `unlock_conditions` gates on it |
| NPC 2 talked | `celestial_intervener_dialogue_2` | *(none)* | Only used as `q_fill_core` step 2's `completion_event_id`. No other consumer. |
| Madra reaches 100 | *(none — it's a state, not a moment)* | `q_fill_core_madra_full` (RESOURCE_AMOUNT ≥ 100) | Both quest step 1 and NPC 2 visibility use the same state predicate |
| `q_fill_core` completes | `q_fill_core_completed` | `q_fill_core_completed` (EVENT_TRIGGERED) | Adventure + Foraging gate on it |

## Examples from Foundation Beat 2

| Moment / state | Event | Unlock Condition | Why |
|---|---|---|---|
| Enemy defeated in combat | `q_first_steps_enemy_defeated` | `q_first_steps_enemy_defeated` (EVENT_TRIGGERED) | Quest step 1 advances on it AND NPC 3 visibility gates on it |
| NPC 3 talked | `celestial_intervener_dialogue_3` | *(none)* | Only quest step 2 consumes it |
| CD level reaches 10 | *(none — it's a state)* | `q_reach_cd_10` (CULTIVATION_LEVEL ≥ 10) | Quest step advances on state predicate |

## Naming convention

Use the **same string id** for the event and its wrapping unlock condition when both exist. Reduces cognitive load — author sees `celestial_intervener_dialogue_1` and knows both the event and the condition are named that.

For quest-scoped conditions (particularly state predicates that apply to one specific quest), prefix with the quest id: `q_fill_core_madra_full`, `q_first_steps_enemy_defeated`. Prevents collision when future quests want a similar predicate with different thresholds.

## Common pitfalls

1. **Forgetting to register a condition when you need to gate a zone action.** If your new action has `unlock_conditions` referencing a condition id that isn't in `unlock_condition_list.tres`, UnlockManager will never flag it as met. Symptom: action stays invisible forever.
2. **Registering a condition nothing references.** Dead weight. Delete.
3. **Using `completion_event_id` AND `completion_conditions` on the same step.** QuestManager will log a validation error at boot — use exactly one.
4. **Firing an event that nothing consumes.** Cheap to fire, so this is fine as future-proofing, but don't invent events that can't plausibly matter.

## Why the dual pattern exists

The flexibility to use `completion_event_id` directly saves authoring a wrapper condition when only a quest step consumes the moment. It's an optimization for the common case where a quest-internal beat doesn't need to gate anything else. If the rules ever feel burdensome, the system can be collapsed (see `docs/superpowers/specs/` for the "Fix A" proposal) — but for now, both patterns coexist intentionally.
