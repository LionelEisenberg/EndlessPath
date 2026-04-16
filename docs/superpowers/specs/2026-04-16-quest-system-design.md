# Quest System — Design

**Date:** 2026-04-16
**Status:** Design approved, ready for implementation planning

## Summary

Introduce a **Quest system** to EndlessPath whose sole purpose is to show the player *what to do next*, narratively. Quests are linear multi-step markers surfaced by a small always-visible panel at the MainGame level. They ride on top of the existing event/effect/unlock infrastructure — a quest step is a *subscription* to an event or unlock condition, not new gameplay logic.

Quests are **not** RPG-style fetch quests ("kill 10 wolves"). They are narrative signposts: "Talk to the Wisened Dirt Eel", "Visit the Spring Forest", "Reach the Copper stage". They are typically given by dialogue.

## Goals

- Tell the player what to do next without interrupting them
- Fully data-driven: authoring a quest = creating a `.tres` resource
- Reuse `EventManager`, `UnlockConditionData`, and the `EffectData` chain — no parallel state machine
- Support the common case (single event) trivially; support conditional cases via existing `UnlockConditionData`

## Non-goals

- Quest branching / choice-based outcomes (deferred)
- Failure / abandon flow (quests cannot fail)
- Timed quests
- Quest log search/filtering UI
- Step-level rewards (rewards attach to the underlying dialogue/action effects or to the quest as a whole)

---

## Existing systems this rides on

| System | Role |
|---|---|
| `EventManager` | Sole source of truth for "did X happen". Emits `event_triggered(event_id)`. Persisted in `SaveGameData.event_progression`. |
| `UnlockConditionData` | Reusable predicate resource (cultivation stage, event triggered, resource amount, attribute value, etc.). Has `evaluate() -> bool`. |
| `EffectData` + subclasses | Effect chain: `TriggerEventEffectData`, `AwardItemEffectData`, etc. Called from `ZoneActionData.success_effects` after dialogue/action completes. |
| `NpcDialogueActionData` | Already chains: zone action → Dialogic timeline → on-end effects. A quest is typically **started from** one of these chains. |
| `LogWindow` | UI pattern we're cloning for `QuestWindow` — floating `PanelContainer` in `main_game.tscn`, always-visible title bar, collapse button. |
| `SaveGameData` | Where `QuestProgressionData` gets added alongside existing `event_progression`, `unlock_progression`, etc. |

---

## Data model

### `QuestData` (new, `scripts/resource_definitions/quests/quest_data.gd`)

```
class_name QuestData
extends Resource

@export var quest_id: String = ""                       # unique id
@export var quest_name: String = ""                     # shown in panel
@export var description: String = ""                    # flavor, unused by core UI
@export var steps: Array[QuestStepData] = []
@export var completion_effects: Array[EffectData] = []  # fire when last step completes
```

### `QuestStepData` (new, `scripts/resource_definitions/quests/quest_step_data.gd`)

```
class_name QuestStepData
extends Resource

@export var step_id: String = ""                                     # unique within the quest
@export var description: String = ""                                 # shown in panel as current step
@export var completion_event_id: String = ""                         # preferred simple case
@export var completion_conditions: Array[UnlockConditionData] = []   # complex case
```

**Completion rule:**
- If `completion_event_id` is non-empty, step advances when `EventManager.event_triggered` fires with that id.
- Else if `completion_conditions` is non-empty, step advances when **all** conditions return true. Conditions are re-evaluated on every `EventManager.event_triggered` signal (any event). Conditions that depend on non-event state — cultivation level, resource amount, attribute value — advance only when *some* event fires. This is intentional: if a state change needs to complete a quest step, the system responsible for that state change should fire an event (e.g., `CultivationManager` should trigger an event on stage advancement).
- If both are set, it's a data authoring error: `QuestManager` logs an error at catalog-load time (in `_ready()`) and treats the step as event-only at runtime.
- If neither is set, same catalog-load error; runtime treats the step as immediately-complete (so the dev sees a quest that instantly finishes — an obvious signal to fix the data).

### `QuestProgressionData` (new, `singletons/persistence_manager/quest_progression_data.gd` — matches `event_progression_data.gd`, `unlock_progression_data.gd`, `zone_progression_data.gd` locations)

```
class_name QuestProgressionData
extends Resource

@export var active_quests: Dictionary[String, int] = {}   # quest_id -> current step index
@export var completed_quest_ids: Array[String] = []       # persisted
```

Added to `SaveGameData` in a new `QUEST MANAGER` section; included in `reset()`.

**Note on completed quests:** All completed quests persist in the panel forever for now. We may revisit pruning once real quests accumulate.

---

## Effects

### `StartQuestEffectData` (new, `scripts/resource_definitions/effects/start_quest_effect_data.gd`)

```
class_name StartQuestEffectData
extends EffectData

@export var quest_id: String = ""

func process() -> void:
    QuestManager.start_quest(quest_id)
```

Adds a new entry to `EffectData.EffectType`:

```
enum EffectType {
    NONE,
    TRIGGER_EVENT,
    AWARD_RESOURCE,
    AWARD_ITEM,
    AWARD_LOOT_TABLE,
    START_QUEST,   # new
}
```

Quests are started by listing a `StartQuestEffectData` in a `ZoneActionData.success_effects` array — the same way `TriggerEventEffectData` and `AwardItemEffectData` are used today.

### Cleanup: remove `QUEST_GIVER` from `ZoneActionData.ActionType`

The enum in `scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd` currently reserves a `QUEST_GIVER` value:

```
enum ActionType {
    FORAGE,
    ADVENTURE,
    NPC_DIALOGUE,
    MERCHANT,
    TRAIN_STATS,
    CYCLING,
    ZONE_EVENT,
    QUEST_GIVER   # remove
}
```

It was reserved in anticipation of a quest system, but this design routes quest-giving through the existing `NpcDialogueActionData` (or any other action type) via `StartQuestEffectData` in `success_effects`. A dedicated action type is unnecessary.

Remove `QUEST_GIVER` from the enum as part of Pass 1. Verified: no `.tres` files reference `action_type = 7`. Two non-code references exist and must be updated alongside the enum removal:
- `scenes/zones/zone_action_button/zone_action_button.gd:13-15` — comment listing unhandled action types (just drop the `QUEST_GIVER` mention)
- `docs/zones/ZONES.md` — two rows/bullets list `QUEST_GIVER` as unhandled; remove them

Removing a trailing enum value is otherwise safe: no other value's int changes.

---

## Singleton: `QuestManager`

Location: `singletons/quest_manager/quest_manager.gd`
Autoload name: `QuestManager`
Autoload order: after `EventManager`, `UnlockManager`, `PersistenceManager`.

### Responsibilities

- Load all `QuestData` `.tres` files from `resources/quests/` into a catalog at boot (mirrors `ZoneManager` pattern)
- Own `active_quests` + `completed_quest_ids` (delegates to `PersistenceManager.save_game_data.quest_progression`)
- Listen to `EventManager.event_triggered`
- On event fire: for each active quest, check if the current step's `completion_event_id` matches OR the current step's `completion_conditions` all evaluate true → advance
- On `start_quest(quest_id)`: add to active list, run a retroactive auto-complete loop (evaluate each step in order, advance past any already-satisfied step, stop at first unsatisfied or when all are complete)
- When the final step advances: fire `completion_effects`, remove from active, append to `completed_quest_ids`, emit `quest_completed`

### Public API

```
signal quest_started(quest_id: String)
signal quest_step_advanced(quest_id: String, new_step_index: int)
signal quest_completed(quest_id: String)

func start_quest(quest_id: String) -> void
func has_active_quest(quest_id: String) -> bool
func has_completed_quest(quest_id: String) -> bool
func get_active_quest_ids() -> Array[String]
func get_completed_quest_ids() -> Array[String]
func get_current_step_index(quest_id: String) -> int
func get_quest_data(quest_id: String) -> QuestData
```

### Save integration

- `SaveGameData.quest_progression: QuestProgressionData`
- `save_data_reset` is reconnected in `_ready()` (same pattern `EventManager` uses)
- Load is passive: `QuestManager` never "re-runs" active quests on load; the step index is authoritative

---

## UI

Pass 2 deliverables. All scenes live alongside existing UI:

### `QuestWindow` — `scenes/ui/quest_window/`

- `PanelContainer`, mounted in `main_game.tscn` next to `LogWindow`
- **Non-draggable**, anchored to the default position (left of the zone-action panel)
- Title bar always visible: `"Quests"` label + expand button (`▼`/`▲`) + badge dot
- Collapsed by default; click expand → scrollable content panel
- Content = vertical list of `QuestEntry` rows
- Active quests sorted above completed; within each group, insertion order
- Subscribes to `QuestManager` signals → rebuilds list + shows badge
- Opening the panel clears the badge

### `QuestEntry` — `scenes/ui/quest_window/quest_entry/`

Sub-scene for one row. Configured by `QuestWindow`:

- `QuestData` reference
- `state`: `ACTIVE` or `COMPLETED`
- `step_index` (active state only)

Display:
- **Active:** `quest_name` (bold) + current step `description` below (muted label variant)
- **Completed:** `quest_name` (struck-through / grayed) + `"✓ Complete"`

### `QuestToast` — `scenes/ui/quest_toast/`

- Separate `PanelContainer`, mounted in `main_game.tscn`, anchored top-center
- Single-line message:
  - `quest_started` → `"Quest Started: <quest_name>"`
  - `quest_step_advanced` → `"Quest Updated: <next step description>"`
  - `quest_completed` → `"Quest Complete: <quest_name>"`
- Animation: fade+slide in (~0.2s), hold (~2.5s), fade out (~0.4s). **Starting values** — tune in polish.
- Queue-based: new toasts enqueue if one is visible; play sequentially
- Independent of panel open/closed state

### Badge behavior

- Any `QuestManager` signal → `QuestWindow` shows a small dot on the title bar
- Expanding the panel clears the dot
- Session-only; not persisted

---

## Edge cases

| Case | Behavior |
|---|---|
| `start_quest(id)` on already-active quest | No-op + `Log.warn` |
| `start_quest(id)` on already-completed quest | No-op + `Log.warn` |
| Quest with zero steps | Immediately completes on start (fires `completion_effects`) |
| Step with both `completion_event_id` and `completion_conditions` | Load-time `Log.error`; runtime treats as event-only |
| Step with neither set | Load-time `Log.error`; runtime auto-advances |
| `StartQuestEffectData.quest_id` unknown | `Log.error` in `process()`, no crash |
| Save loaded with an active quest whose `QuestData` was deleted | `Log.warn`, drop from active list |
| Condition-based step becomes unsatisfied after being satisfied | Ignored — steps only advance forward |
| Quest completes while panel is collapsed | Badge appears, toast fires, completed entry visible on next expand |
| Multiple toasts in the same frame | Queue and play sequentially |
| Panel is already expanded when a quest updates | Live refresh; badge not shown (already visible) |

---

## 5-component evaluation

- **Clarity** ✓ — panel + toast together mean the player always knows what to do next
- **Motivation** ✓ — completion grants effects (via `completion_effects`); narrative arc visible
- **Response** N/A — no real-time input loop in the quest layer itself
- **Satisfaction** ✓ — two feedback channels on advance (toast + badge); completion effects add a third via existing systems (inventory popup, resource change, etc.)
- **Fit** ⚠ — toast visual + audio must match pixel theme. Flag for Pass 2 polish; will use existing theme variants, not inline overrides

---

## Testing

### Pass 1 — GUT unit tests

**`tests/unit/test_quest_manager.gd`:**
- `start_quest` adds to active list and emits `quest_started`
- `start_quest` on unknown id logs error, no crash
- `start_quest` on already-active quest is a no-op
- `start_quest` on already-completed quest is a no-op
- Step advances when its `completion_event_id` is triggered
- Step advances when all its `completion_conditions` evaluate true on an `event_triggered` fire
- Retroactive: starting a quest whose first step's event already fired advances past it on start
- Retroactive: quest with all steps already satisfied completes instantly
- Last-step advance fires `completion_effects`, removes from active, appends to `completed_quest_ids`, emits `quest_completed`
- `quest_step_advanced` emits with correct `(quest_id, new_step_index)`

**`tests/unit/test_start_quest_effect.gd`:**
- `process()` calls `QuestManager.start_quest(quest_id)`

**Save/load (follow existing persistence test pattern):**
- Active quest with step index N persists; loads with same index
- `completed_quest_ids` persists and round-trips

### Pass 2 — manual playtest

- Author a test quest with 3 steps gated on events
- Trigger via a dialogue's `success_effects`
- Verify: panel updates, toast fires, badge appears, completion effects fire, save/load preserves state

No UI unit tests (consistent with rest of project).

---

## Pass split (implementation)

### Pass 1 — Backend

Scope:
- `QuestData`, `QuestStepData`
- `QuestProgressionData` + wire into `SaveGameData`
- `StartQuestEffectData` + `EffectType.START_QUEST` enum entry
- `QuestManager` singleton (autoload)
- Remove `QUEST_GIVER` from `ZoneActionData.ActionType`
- GUT tests

**Deliverable:** a fully functional quest system with no UI. Verifiable via tests + authoring a sample quest and running the game with debug logging.

### Pass 2 — UI

Scope:
- `QuestEntry` sub-scene
- `QuestWindow` (LogWindow-clone pattern, non-draggable)
- `QuestToast` + queue
- Badge dot behavior
- Mount both in `main_game.tscn`

**Rollout order within Pass 2:**
1. `QuestEntry` (static preview with test data)
2. `QuestWindow` shell (frame + collapse/expand)
3. Wire to `QuestManager` signals
4. `QuestToast` + queue
5. Badge dot

---

## Open questions

None blocking implementation. Revisit after first real quest chain is authored:
- Pruning old completed quests
- Toast audio/timing polish values
- Whether a zone-specific hint ("Go to: Spring Forest") should appear in step descriptions by convention
