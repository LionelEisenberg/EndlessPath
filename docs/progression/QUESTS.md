# Quest System

Last updated: 2026-10-18

## Overview

Quests are linear, multi-step narrative signposts that tell the player what to do next. They hold no gameplay logic of their own: each step subscribes to an event ([EventManager](../infrastructure/EVENTS.md)) or to a set of [`UnlockConditionData`](../infrastructure/UNLOCKS.md) predicates. When the last step advances, the quest's `completion_effects` fire through the [EffectData](../infrastructure/EFFECTS.md) chain.

- `QuestManager` (autoload, last in load order) owns active and completed quest state, stored in `SaveGameData.quest_progression`.
- Quests are started by `StartQuestEffectData`, which today sits only in NPC dialogue zone actions' `success_effects`.
- Quests cannot fail, branch, be abandoned, or time out.
- The player sees quests through `QuestWindow` (a collapsible tracker) and `QuestToast` (a top-center popup).
- Three quests are authored, all part of the Foundation beat chain. See [FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md).

## Player Experience

1. At first launch the quest tracker is collapsed: a "Quests" title bar with a ▼ button. The list is empty, and expanding it shows "No active quests."
2. Talking to the Celestial Intervener for the first time starts **Awaken Your Core**. A toast reads "Quest Started: Awaken Your Core" and an orange dot appears on the collapsed tracker's title bar.
3. Expanding the tracker (▲) clears the dot. Each active quest shows its name and current step description. Completed quests are listed below with "✓ Complete" and are not visually dimmed.
4. Each time a step advances, a toast shows "Quest Updated: <next step description>". On completion the toast reads "Quest Complete: <quest name>", and the quest's rewards apply (a path point, an item, or an event that unlocks new zone actions).
5. Back-to-back updates queue and play one after another, about 3.1 s each.
6. After **Harden Your Core** completes, no quest is active. The tracker lists the three completed quests.

## Architecture

```
QuestManager (autoload #17, singletons/quest_manager/quest_manager.gd)
  _quest_catalog: QuestList        ← preload("res://resources/quests/quest_list.tres")
  _quests_by_id: Dictionary[String, QuestData]
  _live_save_data: SaveGameData    → quest_progression: QuestProgressionData
  listens:  EventManager.event_triggered      → _on_event_triggered(event_id)
            UnlockManager.condition_unlocked  → _on_condition_unlocked(condition_id)
            PersistenceManager.save_data_reset → _on_save_data_reset()
  emits:    quest_started / quest_step_advanced / quest_completed

MainView (scenes/main/main_game/main_game.tscn)
  QuestWindow (PanelContainer, z_index 1)   — scenes/ui/quest_window/quest_window.gd
    QuestEntry × N (VBoxContainer)          — scenes/ui/quest_window/quest_entry/quest_entry.gd
  QuestToast (PanelContainer, z_index 10)   — scenes/ui/quest_toast/quest_toast.gd
```

## Data Model

### QuestData (`scripts/resource_definitions/quests/quest_data.gd`)

| Field | Type | Description |
|---|---|---|
| `quest_id` | `String` | Unique id; key in `QuestList` index and save data |
| `quest_name` | `String` | Shown in `QuestEntry` and toasts |
| `description` | `String` (multiline) | Flavor text; **not displayed anywhere** |
| `steps` | `Array[QuestStepData]` | Ordered steps; zero steps = completes on start |
| `completion_effects` | `Array[EffectData]` | Processed in order when the last step advances |

### QuestStepData (`scripts/resource_definitions/quests/quest_step_data.gd`)

| Field | Type | Description |
|---|---|---|
| `step_id` | `String` | Unique within the quest (used in validation logs) |
| `description` | `String` | Shown as the active step text and in "Quest Updated" toasts |
| `completion_event_id` | `String` | Event-based step: advances when this event fires |
| `completion_conditions` | `Array[UnlockConditionData]` | Condition-based step: advances when **all** evaluate true |

Set exactly one of `completion_event_id` / `completion_conditions`. If both are set, the event takes precedence. If neither is set, the step auto-advances. `_validate_catalog()` reports both cases with `push_error` at boot.

### QuestList (`scripts/resource_definitions/quests/quest_list.gd`)

| Field | Type | Description |
|---|---|---|
| `quests` | `Array[QuestData]` | The catalog. A quest that is not in `resources/quests/quest_list.tres` does not exist to `QuestManager`. |

### QuestProgressionData (`singletons/persistence_manager/quest_progression_data.gd`)

| Field | Type | Description |
|---|---|---|
| `active_quests` | `Dictionary[String, int]` | `quest_id` → current 0-based step index (insertion order = start order) |
| `completed_quest_ids` | `Array[String]` | Completion order |

Stored as `SaveGameData.quest_progression`. `SaveGameData.reset()` replaces it with a fresh instance.

## Core Systems

### Public API

| Member | Description |
|---|---|
| `signal quest_started(quest_id: String)` | Emitted after the quest is added to `active_quests`, **before** the retroactive pass |
| `signal quest_step_advanced(quest_id: String, new_step_index: int)` | Emitted when a quest moves to a non-final step. Not emitted for the final advance, which emits `quest_completed` instead. |
| `signal quest_completed(quest_id: String)` | Emitted after `completion_effects` have been processed |
| `start_quest(quest_id: String) -> void` | Starts a quest (see below) |
| `has_active_quest(quest_id: String) -> bool` | Membership in `active_quests` |
| `has_completed_quest(quest_id: String) -> bool` | Membership in `completed_quest_ids` |
| `get_active_quest_ids() -> Array[String]` | Copy, in start order |
| `get_completed_quest_ids() -> Array[String]` | Copy, in completion order |
| `get_current_step_index(quest_id: String) -> int` | Step index, or `-1` if not active |
| `get_quest_data(quest_id: String) -> QuestData` | Catalog lookup, or `null` |

### Boot (`_ready`)

1. `_build_catalog_index()` indexes `quest_list.tres` by `quest_id` and skips null entries and entries with empty ids.
2. `_validate_catalog()` calls `push_error` for null steps and for steps that have both or neither completion criteria. It never modifies data.
3. Binds `_live_save_data` and connects `save_data_reset`, `EventManager.event_triggered`, and `UnlockManager.condition_unlocked`.
4. `_prune_unknown_active_quests()` drops active entries whose id is not in the catalog (`Log.warn`). Completed ids are kept.

QuestManager does not re-check active steps at boot or on load. The saved step index is authoritative.

### Starting a quest

```
StartQuestEffectData.process()
  → QuestManager.start_quest(quest_id)
      no save bound        → return silently
      unknown id           → push_error("unknown quest_id …"), return
      already active       → Log.warn, return
      already completed    → Log.warn, return
      active_quests[quest_id] = 0 → quest_started.emit
      zero steps           → _complete_quest()
      else                 → _retroactive_advance()
```

`_retroactive_advance()` walks forward while the current step is already satisfied. An event step is satisfied if `EventManager.has_event_triggered(completion_event_id)`. A condition step is satisfied if every condition's `evaluate()` returns true. A step with no criteria is always satisfied. The pass stops at the first unsatisfied step or when the quest completes.

### Step advancement

```
EventManager.event_triggered(event_id)
  → _on_event_triggered(event_id): for each active quest (copied list)
        _try_advance_step(quest_id, event_id)

UnlockManager.condition_unlocked(condition_id)
  → _on_condition_unlocked(_): for each active quest
        _try_advance_step(quest_id, "")        # only condition steps can pass

_try_advance_step → _is_step_satisfied(step, triggering_event_id)
    event step     → step.completion_event_id == triggering_event_id
    no criteria    → true
    condition step → every cond.evaluate() is true (evaluated live, not from the latched set)
  → _advance_step(quest_id)
        index + 1 >= steps.size() → _complete_quest()
        else store index, Log.info, quest_step_advanced.emit
```

Rules that follow from this code:

- Each trigger advances a quest by at most one step. The newly current step is not re-checked until the next `event_triggered` or `condition_unlocked`.
- An event step only matches an event that fires **while that step is current**. If its event already fired earlier, the step can never complete, because EventManager never re-fires an event. Only `start_quest()` consults event history.
- Condition steps are evaluated live, so the conditions do not need to be registered in `unlock_condition_list.tres`. However, the step is only re-checked on an event or a `condition_unlocked` signal, and unregistered conditions never emit `condition_unlocked`. Any event re-checks condition steps.
- UnlockManager is connected to `event_triggered` before QuestManager. For a single event, conditions latch and `_on_condition_unlocked` runs first, then `_on_event_triggered` runs.

### Completion

`_complete_quest()` erases the quest from `active_quests` and appends it to `completed_quest_ids`. It then logs, processes each non-null `completion_effects` entry in order, and emits `quest_completed`. Completion effects can fire events that cascade into UnlockManager and other quests. The completed quest has already left the active list, so its own events cannot re-advance it.

### Chaining quests (Pattern B)

Quests never reference other quests. The NPC dialogue action that completes quest N also starts quest N+1. Its `success_effects` list a `TriggerEventEffectData` first, which completes quest N and runs that quest's own `completion_effects`, followed by a `StartQuestEffectData`. See [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md).

### Persistence

Quest state lives in `SaveGameData.quest_progression` and is written with the rest of the save to `user://save.tres`. The `SaveTimer` in `main_game.tscn` autosaves every 5 s. Only ids and step indices persist. Quest definitions always come from the current catalog. On `save_data_reset`, QuestManager rebinds to the new save and prunes unknown active quests. See [PERSISTENCE.md](../infrastructure/PERSISTENCE.md).

## Quest UI

### QuestWindow (`scenes/ui/quest_window/quest_window.tscn`, class `QuestWindow`)

```
QuestWindow (PanelContainer, min 320×0, mouse_filter IGNORE, StyleBoxEmpty)
  VBoxContainer
    TitleBar %TitleBar (PanelContainer, quest_titlebar.tres)
      HBoxContainer
        TitleLabel ("Quests", LabelHeading + font_size 20 override)
        BadgeDot %BadgeDot (ColorRect 10×10, Color(0.95, 0.55, 0.2))
        Spacer
        CollapseButton %CollapseButton (flat Button, "▼"/"▲")
    ContentPanel %ContentPanel (PanelContainer, quest_window.tres, min height 200, clip_contents)
      ScrollContainer
        EntriesContainer %EntriesContainer (VBoxContainer, separation 8)
          EmptyLabel %EmptyLabel ("No active quests.", LabelBodySmall)
```

- Instanced under `MainView` in `main_game.tscn` with z_index 1. It is anchored with offsets 1147–1467 px horizontally, and its top edge sits 28 px below the top of the 1080 px viewport. It is non-draggable.
- Starts collapsed (`preview_start_expanded = false`). `toggle_collapse()` (public) flips the content panel and clears the badge when the panel opens.
- On `quest_started`, `quest_step_advanced`, or `quest_completed`, the whole list is rebuilt. Active quests appear first in start order, then completed quests in completion order. The badge dot shows if the window is collapsed.
- `EmptyLabel` shows only when there are no active **and** no completed quests.
- Editor preview: when `preview_active_quests` / `preview_completed_quests` are non-empty, the scene renders them and skips QuestManager wiring.

### QuestEntry (`scenes/ui/quest_window/quest_entry/quest_entry.tscn`, class `QuestEntry`)

- `VBoxContainer` (min height 48) with `TitleLabel` (`LabelBody`) and `DetailLabel` (`LabelBodySmall`, autowrap).
- `enum State { ACTIVE, COMPLETED }`. `populate(quest, state, step_index)` sets the title to `quest_name`. For ACTIVE the detail is the current step's `description`. For COMPLETED it is "✓ Complete" and the code sets `self_modulate` alpha to 0.55, but that has no visible effect (see Work Remaining). A null quest renders "(unknown quest)".
- Preview exports: `preview_quest`, `preview_state`, `preview_step_index`.

### QuestToast (`scenes/ui/quest_toast/quest_toast.tscn`, class `QuestToast`)

- `PanelContainer` (quest_toast.tres) with a centered `MessageLabel` (`LabelBody`). In `main_game.tscn` it is anchored top-center at 350×60, 28 px from the top, with z_index 10.
- Messages are "Quest Started: <quest_name>", "Quest Updated: <new step description>" (or "Quest Updated" if the index is invalid), and "Quest Complete: <quest_name>".
- Animation: a 0.2 s fade-in with a 20 px slide (`FADE_IN_DURATION`, `SLIDE_OFFSET_PX`), a 2.5 s hold (`HOLD_DURATION`), and a 0.4 s fade-out (`FADE_OUT_DURATION`). Messages queue in `_queue` and play sequentially. `show_message(text)` is public.
- Editor preview: `preview_message` plays once and skips signal wiring.

### Inventory Journal tab

The inventory's Quest Items ("Journal") tab lists quest **items** such as the Refugee Camp Map. It does not read QuestManager. See [INVENTORY.md](../inventory/INVENTORY.md).

## Integration Points

| System | Connection |
|---|---|
| EventManager | `event_triggered` advances event steps. `has_event_triggered()` drives the retroactive pass. See [EVENTS.md](../infrastructure/EVENTS.md). |
| UnlockManager / UnlockConditionData | `condition_unlocked` re-checks condition steps. Conditions are evaluated live with `evaluate()`. See [UNLOCKS.md](../infrastructure/UNLOCKS.md). |
| EffectData | `StartQuestEffectData` starts quests. `completion_effects` run on completion. See [EFFECTS.md](../infrastructure/EFFECTS.md). |
| ActionManager / NpcDialogueActionData | NPC `success_effects` fire the "return to NPC" events and start the next quest after the dialogue ends |
| AdventureCombat | Fires `q_first_steps_enemy_defeated` on every enemy death |
| PersistenceManager | `SaveGameData.quest_progression`. `save_data_reset` triggers a rebind and prune. |
| PathManager / InventoryManager | Targets of the current completion rewards (`AwardPathPointEffectData`, `AwardItemEffectData`) |

## Existing Content

### Quests (`resources/quests/`, catalog order)

| quest_id | quest_name | Started by | Completion effects |
|---|---|---|---|
| `q_fill_core` | Awaken Your Core | `celestial_intervener_dialogue_1.success_effects` | `TriggerEventEffectData("q_fill_core_completed")`, which unlocks The Shallow Woods and Spring Forest Foraging |
| `q_first_steps` | First Steps Out | `celestial_intervener_dialogue_2.success_effects` | `AwardPathPointEffectData(amount = 1)` |
| `q_reach_core_density_10` | Harden Your Core | `celestial_intervener_dialogue_3.success_effects` | `AwardItemEffectData(refugee_camp_map, quantity 1)` |

Quest `description` values, which are not displayed:
- `q_fill_core`: "Fill your Madra core and return to speak with the stranger."
- `q_first_steps`: "Venture into the wilderness and test your strength."
- `q_reach_core_density_10`: "Deepen your cultivation. Raise your Core Density to level 10, then report back to the Celestial [INTERVENER]."

### Steps

| Quest | # | step_id | Description (player-facing) | Completes on |
|---|---|---|---|---|
| `q_fill_core` | 0 | `reach_max_madra` | Fill your Madra by cycling | Condition `q_fill_core_madra_full` (RESOURCE_AMOUNT, madra ≥ 100.0) |
| `q_fill_core` | 1 | `return_to_npc` | Return to the Celestial [INTERVENER] | Event `celestial_intervener_dialogue_2` |
| `q_first_steps` | 0 | `defeat_enemy` | Defeat an enemy in combat | Event `q_first_steps_enemy_defeated` |
| `q_first_steps` | 1 | `return_to_npc` | Return to the Celestial [INTERVENER] | Event `celestial_intervener_dialogue_3` |
| `q_reach_core_density_10` | 0 | `reach_cd_10` | Reach Core Density level 10 | Condition `q_reach_cd_10` (CULTIVATION_LEVEL ≥ 10) |
| `q_reach_core_density_10` | 1 | `return_to_npc` | Return to the Celestial [INTERVENER] | Event `celestial_intervener_dialogue_4` |

Every "return" step is completed by an NPC action that only becomes visible once the previous step's condition or event has latched. This ordering keeps the "event already fired" limitation from triggering in normal play.

### Authoring a quest

1. Create `resources/quests/q_<name>.tres` (`QuestData`) with inline `QuestStepData` sub-resources. Put one-off completion effects inline as sub-resources too.
2. Add it to `resources/quests/quest_list.tres`.
3. Give every step exactly one criterion. Register any condition a zone action also gates on in `unlock_condition_list.tres`.
4. Start it from an action's `success_effects` with a `StartQuestEffectData`. Place it after any `TriggerEventEffectData` in the same array.
5. Make sure the event for each event step can only fire after the previous step completes.

## Key Files

| File | Purpose |
|---|---|
| `singletons/quest_manager/quest_manager.gd` | Quest state machine, signals, validation |
| `scripts/resource_definitions/quests/quest_data.gd` | `QuestData` |
| `scripts/resource_definitions/quests/quest_step_data.gd` | `QuestStepData` |
| `scripts/resource_definitions/quests/quest_list.gd` | `QuestList` catalog class |
| `singletons/persistence_manager/quest_progression_data.gd` | Saved quest state |
| `scripts/resource_definitions/effects/start_quest_effect_data.gd` | Effect that starts a quest |
| `resources/quests/quest_list.tres` | The catalog |
| `resources/quests/q_fill_core.tres`, `q_first_steps.tres`, `q_reach_core_density_10.tres` | Authored quests |
| `scenes/ui/quest_window/quest_window.gd` / `.tscn` | Tracker panel |
| `scenes/ui/quest_window/quest_entry/quest_entry.gd` / `.tscn` | Tracker row |
| `scenes/ui/quest_toast/quest_toast.gd` / `.tscn` | Toast popup |
| `assets/styleboxes/ui/quest_window.tres`, `quest_titlebar.tres`, `quest_toast.tres` | Quest UI styleboxes |

## Tests

| File | Covers |
|---|---|
| `tests/unit/test_quest_manager.gd` | Start guards (unknown, active, completed); event and condition advancement; partial conditions; retroactive pass; completion effects, signal, and order; zero-step quests; pruning; both and neither validation errors; the `condition_unlocked` listener |
| `tests/unit/test_quest_progression_persistence.gd` | `QuestProgressionData` round-trip through `ResourceSaver`; `reset()` clears it |
| `tests/unit/test_start_quest_effect_data.gd` | `process()` starts the quest; empty `quest_id` causes `push_error` |
| `tests/integration/test_beat_3b_merchant_unlock.gd` | Real catalog: `q_reach_core_density_10` CD-10 advance, NPC 4 gate, map award, refugee-camp eligibility, Merchant unlock |

Untested: QuestWindow and QuestToast behavior; the Beat 1 → Beat 2 → Beat 3 chain with real data (only Beat 3b has an integration test); a data check that every authored `completion_event_id` has a producer.

## Work Remaining

### Bugs

- `[MEDIUM]` Steps are not re-checked after advancing. `_advance_step()` stores the new index but never evaluates the new step. An event step whose event already fired can never complete, and a condition step that is already true waits for an unrelated trigger. Normal Foundation play avoids this, but the dev panel can soft-lock a quest. For example, force-unlocking `q_first_steps_enemy_defeated` reveals NPC 3. Talking to NPC 3 fires `celestial_intervener_dialogue_3` while `q_first_steps` is still on step 0, so step 1 can never complete and the path point is never awarded. Fix: call `_retroactive_advance()` after every advance and once per active quest at the end of `_ready()`.
- `[LOW]` Completed quests are not dimmed. `QuestEntry.populate()` sets `self_modulate` on the `VBoxContainer`, but `self_modulate` does not propagate to the child Labels and the container draws nothing. Use `modulate` or a muted Label variant.

### Missing Functionality

- `[MEDIUM]` The catalog is maintained by hand. A quest `.tres` that is missing from `quest_list.tres` is unknown at runtime, and `start_quest` only reports it with `push_error`. The design spec called for scanning `resources/quests/`. Either scan the folder or add a test that every `resources/quests/q_*.tres` is listed.
- `[LOW]` There is no per-step progress readout. Condition steps show static text such as "Reach Core Density level 10" with no current value.
- `[LOW]` `QuestData.description` is authored but never displayed.
- `[LOW]` Completed quests accumulate in QuestWindow forever. There is no pruning or collapsing of a "completed" group.
- `[LOW]` Quest items have no link back to a quest. The Journal tab's wax seal is always "active". The comments in `quest_item_definition_data.gd`, `journal_row.gd`, and `quest_journal_card.gd` that say "until a QuestManager exists" are stale.

### Content

- `[HIGH]` No quest exists after `q_reach_core_density_10`. Once the map is awarded, the Refugee Camp search, the Merchant, and the eventual breakthrough have no tracker guidance. Beats 4–10 ([FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md)) plan `q_first_elite`, `q_tribulation_guardian`, and `q_breakthrough_seek`, but none are authored.
- `[MEDIUM]` Player-facing quest text contains the placeholder "[INTERVENER]": all three "Return to the Celestial [INTERVENER]" steps and the `q_reach_core_density_10` description. QuestEntry and QuestToast use plain Labels, so the brackets render literally.
- `[MEDIUM]` The `reach_cd_10` step doesn't tell the player how to gain Core Density. The Foundational Technique has no cycling zones and yields 0 CD XP, so the player must buy Pure Core Awakening and equip Smooth Flow first. Only the dialogue hints at this.

### UI

- `[LOW]` QuestWindow `TitleLabel` adds `theme_override_font_sizes/font_size = 20` on top of `LabelHeading`, and `CollapseButton` has inline font color and size overrides. Check them against [UI_STYLING.md](../UI_STYLING.md).
- `[LOW]` The tracker starts collapsed and the first quest only announces itself with a 3 s toast and a 10 px dot. Consider auto-expanding the tracker the first time a quest starts.

### Tech Debt

- `[LOW]` Mismatched ext_resource UIDs fall back to the path, and Godot warns each time one is loaded. `quest_list.tres` references `q_first_steps.tres` as `uid://bqfirststeps01`, but the file header is `uid://d1mcp5rsmbbwu`. `main_game.tscn` references `quest_toast.tscn` as `uid://crqcxy8168ohk`, but the header is `uid://b1quest1toast1`.
- `[LOW]` Several quest resources use hand-written UIDs instead of Godot-generated ones: `uid://bquest1list00`, `uid://bqreachcdq001`, `uid://b1quest1win1`, `uid://b1quest1entry1`, `uid://b1quest1toast1`, `uid://quest_window_01`, `uid://quest_titlebar_01`, `uid://quest_toast_01`.
