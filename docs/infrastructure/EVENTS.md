# Event System

## Overview

`EventManager` is a one-shot narrative event tracker. Events are triggered permanently (never un-triggered) and serve as flags for the unlock system and content gating.

## API

- `trigger_event(event_id)` — records permanently, emits `event_triggered`
- `has_event_triggered(event_id) -> bool` — membership check

## Flow

```
1. Game action completes (e.g., NPC dialogue ends)
2. TriggerEventEffectData.process()
   → EventManager.trigger_event("initial_spirit_valley_dialogue_1")
3. EventManager appends ID to save_data.event_progression.triggered_events
4. EventManager emits event_triggered signal
5. UnlockManager._evaluate_all_conditions() runs
6. Any UnlockConditionData with type EVENT_TRIGGERED matching that ID evaluates true
```

Event IDs are bare strings — the same literal string must match exactly between the `TriggerEventEffectData` `.tres` (which fires the event) and the `UnlockConditionData` `.tres` (which checks for it). No constants file or enum links them — a typo in either place silently breaks the unlock chain.

## Key Files

| File | Purpose |
|------|---------|
| `singletons/event_manager/event_manager.gd` | Narrative event tracking |

## Work Remaining

### Tech Debt

- `[LOW]` Event IDs are magic strings with no central registry — scattered across `.tres` files. A typo silently breaks the event→unlock chain. Quick fix: create a `const` file or `enum` that both `TriggerEventEffectData` and `UnlockConditionData` reference, so mismatches are caught at author time
