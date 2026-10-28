# Quest System

## Overview

Quests are linear, multi-step narrative signposts that tell the player what to do next. They hold no gameplay logic of their own: each step subscribes to an event ([EventManager](../infrastructure/EVENTS.md)) or to a set of [`UnlockConditionData`](../infrastructure/UNLOCKS.md) predicates. When the last step advances, the quest's `completion_effects` fire through the [EffectData](../infrastructure/EFFECTS.md) chain.

- `QuestManager` (autoload, last in load order) owns active and completed quest state, stored in `SaveGameData.quest_progression`.
- Quests are started by `StartQuestEffectData`, which today sits only in NPC dialogue zone actions' `success_effects`.
- Quests cannot fail, branch, be abandoned, or time out.
- The player sees quests through the `GoalsPanel` (the lacquer Goals board, which shows the first active quest's current step) and `QuestToast` (a top-center popup).
- Three quests are authored, all part of the Foundation beat chain. See [FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md).

## Player Experience

1. At first launch no quest is active, and the Goals board under the cultivator cabinet is hidden: its Breakthrough milestone waits for NPC 4, the end of the Intervener's chain ([FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md), Beat 3b).
2. Talking to the Celestial Intervener for the first time starts **Awaken Your Core**. A toast reads "Quest Started: Awaken Your Core", and the Goals board appears with its quest row alone: the quest name, the current step ("Fill your Madra by cycling") and, because that step completes on a measurable condition, a figure on the name row (`25 / 100`) that follows Madra.
3. Each time a step advances, a toast shows "Quest Updated: <next step description>" and the row shows the new step. On completion the toast reads "Quest Complete: <quest name>", and the quest's rewards apply (a path point, an item, or an event that unlocks new zone actions).
4. Back-to-back updates queue and play one after another, about 3.1 s each.
5. **Harden Your Core** completes at NPC 4, and no quest is active after it. The same talk puts the Breakthrough milestone ("Raise Core Density to 100") on the board in the quest row's place. Completed quests are not listed anywhere.

The board is shared with the adventure view, which leaves it where the zone view hangs it, under the vitals cabinet; the merchant shop and the Tribulation hide it, cycling leaves it showing beside its board, and the menu books leave it under their backdrop. At Core Density 100 its milestone reads "Face the Tribulation", and after a pass "Copper reached".

## Architecture

```
QuestManager (autoload #17, singletons/quest_manager/quest_manager.gd)
  _quest_catalog: QuestList        ← preload("res://resources/quests/quest_list.tres")
  _quests_by_id: Dictionary[String, QuestData]
  _live_save_data: SaveGameData    → quest_progression: QuestProgressionData
  listens:  EventManager.event_triggered      → advances event steps
            UnlockManager.condition_unlocked  → re-checks condition steps
            PersistenceManager.save_data_reset → rebinds and prunes
  emits:    quest_started / quest_step_advanced / quest_completed

MainView (scenes/main/main_game/main_game.tscn)
  GoalsPanel (Control, z_index 1)           — scenes/ui/goals_panel/goals_panel.gd
  QuestToast (PanelContainer, z_index 10)   — scenes/ui/quest_toast/quest_toast.gd
```

## Data Model

### QuestData (`scripts/resource_definitions/quests/quest_data.gd`)

| Field | Type | Description |
|---|---|---|
| `quest_id` | `String` | Unique id; key in `QuestList` index and save data |
| `quest_name` | `String` | Shown on the Goals board and in toasts |
| `description` | `String` (multiline) | Flavor text. Only the Journal shows it, on the quest of a quest item |
| `steps` | `Array[QuestStepData]` | Ordered steps; zero steps = completes on start |
| `completion_effects` | `Array[EffectData]` | Processed in order when the last step advances |

### QuestStepData (`scripts/resource_definitions/quests/quest_step_data.gd`)

| Field | Type | Description |
|---|---|---|
| `step_id` | `String` | Unique within the quest (used in validation logs) |
| `description` | `String` | Shown as the active step text and in "Quest Updated" toasts |
| `completion_event_id` | `String` | Event-based step: advances when this event fires |
| `completion_conditions` | `Array[UnlockConditionData]` | Condition-based step: advances when **all** evaluate true |

Set exactly one of `completion_event_id` / `completion_conditions`. If both are set, the event takes precedence. If neither is set, the step auto-advances. QuestManager reports both cases with `push_error` at boot.

A step's progress figure, which the Goals board and the Journal print, comes from the step itself:
- `get_measured_condition() -> UnlockConditionData`: the first completion condition, when the step completes on conditions alone and every one of them `is_measurable()` (RESOURCE_AMOUNT or CULTIVATION_LEVEL); `null` otherwise.
- `get_progress_text(finished: bool = false) -> String`: that condition's `get_current_value()` / `get_target_value()` as whole numbers rounded down (`"25 / 100"`), or `""` when nothing is measured. With `finished`, the current value reads as the target (`"100 / 100"`).

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
| `get_all_quests() -> Array[QuestData]` | Every quest in the catalog, in catalog order |
| `get_quest_id_for_item(item: ItemDefinitionData) -> String` | The quest a quest item belongs to, for the Journal, or `""`. First a quest that needs it (a step with an `ITEM_OWNED` condition on its `item_id`), an active one before a completed one; else the quest whose `completion_effects` award it (`AwardItemEffectData`). Only started quests (active or completed) count, in catalog order |

### Boot (`_ready`)

1. Indexes `quest_list.tres` by `quest_id` and skips null entries and entries with empty ids.
2. Validates the catalog: `push_error` for null steps and for steps that have both or neither completion criteria. It never modifies data.
3. Binds `_live_save_data` and connects `save_data_reset`, `EventManager.event_triggered`, and `UnlockManager.condition_unlocked`.
4. Drops active entries whose id is not in the catalog (`Log.warn`). Completed ids are kept.

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
      zero steps           → complete the quest
      else                 → retroactive pass
```

The retroactive pass walks forward while the current step is already satisfied. An event step is satisfied if `EventManager.has_event_triggered(completion_event_id)`. A condition step is satisfied if every condition's `evaluate()` returns true. A step with no criteria is always satisfied. The pass stops at the first unsatisfied step or when the quest completes.

### Step advancement

```
EventManager.event_triggered(event_id)
  → for each active quest (copied list)
        try to advance it with event_id

UnlockManager.condition_unlocked(condition_id)
  → for each active quest
        try to advance it with no event        # only condition steps can pass

try to advance → is the current step satisfied by triggering_event_id?
    event step     → step.completion_event_id == triggering_event_id
    no criteria    → true
    condition step → every cond.evaluate() is true (evaluated live, not from the latched set)
  → advance the step
        index + 1 >= steps.size() → complete the quest
        else store index, Log.info, quest_step_advanced.emit
```

Rules that follow from this code:

- Each trigger advances a quest by at most one step. The newly current step is not re-checked until the next `event_triggered` or `condition_unlocked`.
- An event step only matches an event that fires **while that step is current**. If its event already fired earlier, the step can never complete, because EventManager never re-fires an event. Only `start_quest()` consults event history.
- Condition steps are evaluated live, so the conditions do not need to be registered in `unlock_condition_list.tres`. However, the step is only re-checked on an event or a `condition_unlocked` signal, and unregistered conditions never emit `condition_unlocked`. Any event re-checks condition steps.
- UnlockManager is connected to `event_triggered` before QuestManager. For a single event, conditions latch and QuestManager's `condition_unlocked` handler runs first, then its `event_triggered` handler runs.

### Completion

Completion erases the quest from `active_quests` and appends it to `completed_quest_ids`. It then logs, processes each non-null `completion_effects` entry in order, and emits `quest_completed`. Completion effects can fire events that cascade into UnlockManager and other quests. The completed quest has already left the active list, so its own events cannot re-advance it.

### Chaining quests (Pattern B)

Quests never reference other quests. The NPC dialogue action that completes quest N also starts quest N+1. Its `success_effects` list a `TriggerEventEffectData` first, which completes quest N and runs that quest's own `completion_effects`, followed by a `StartQuestEffectData`. See [QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md](QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md).

### Persistence

Quest state lives in `SaveGameData.quest_progression` and is written with the rest of the save to `user://save.tres`. The `SaveTimer` in `main_game.tscn` autosaves every 5 s. Only ids and step indices persist. Quest definitions always come from the current catalog. On `save_data_reset`, QuestManager rebinds to the new save and prunes unknown active quests. See [PERSISTENCE.md](../infrastructure/PERSISTENCE.md).

## Quest UI

### GoalsPanel (`scenes/ui/goals_panel/goals_panel.tscn`, class `GoalsPanel`)

The lacquer Goals board (kit §5.2), which replaced the old collapsible quest tracker in the map-first zone view. `theme = lacquer_theme.tres`, `mouse_filter` STOP while it shows a goal and IGNORE while it has none.

```
GoalsPanel (Control, 440 wide)
  Cords %                       the two cords it hangs from (a 20 px strip, CORDS_HEIGHT, above the body)
  Board % (VBoxContainer)       BoardTop % / BoardMid (tiled) / BoardBottom: slices of lacquer_goals_ai.png
  TitleLabel % "Goals"          LabelLacquerPanelTitle
  Rows % (VBoxContainer)
    QuestRow %                  MarginContainer: IconSlot (QuestIcon) + TextColumn (NameRow: QuestNameLabel %, QuestFigure % with QuestFigureLabel %; QuestStepLabel %)
    Divider %
    MilestoneRow %              MarginContainer: IconSlot (MilestoneIcon) + TextColumn (MilestoneNameLabel % "Breakthrough", MilestoneTextLabel %, ProgressRow: MilestoneRod % (LacquerRod, steps 138), MilestoneFigureLabel %)
```

- Instanced under `MainView` in `main_game.tscn` with z_index 1. `ZoneViewState` hangs it at (24, 276), under the cultivator cabinet, on 24 px cords (`lacquer_goals_cords_ai.png`) that reach 4 px above its root to the cabinet's rings. `AdventureViewState` leaves it there, cords showing, because the adventure's vitals cabinet stands where the cultivator cabinet does. The merchant shop and the Tribulation hide it; cycling leaves it showing beside its board, and the menu books leave it showing under their backdrop ([MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md#hud-boards)).
- **Quest row:** the first id of `QuestManager.get_active_quest_ids()`, its `quest_name` and the current step's `description` (both wrap in the row's 358 px, the name before the figure, which stays at the right of its first line). The `current / target` figure is the step's `QuestStepData.get_progress_text()` (see the data model above), so it shows only for a step that completes on measurable conditions alone.
- **Milestone row:** hidden until the current stage's `breakthrough_goal_condition` (`CultivationManager.get_breakthrough_goal_condition()`) has latched, which the board hears through `UnlockManager.condition_unlocked`. Foundation's is `celestial_intervener_dialogue_4`, NPC 4's talk; Copper names none, so its row always shows. Then "Breakthrough", in three states, checked in this order. With no next stage (Copper) it reads "<Stage> reached" on a full jade rod, with no figure. With the core full (`CultivationManager.is_core_full()`) it reads "Face the Tribulation" on a full rod, with `cap / cap` ("100 / 100"). Otherwise it reads "Raise Core Density to <cap>" (`CultivationManager.get_core_density_cap()`, 100 in Foundation), with the rod and the figure at `level / cap`. Core Density stops at the cap, and a save past it loads at it, so the figure never passes it.
- The divider shows only between the two rows. With one row hidden the other moves into its place, and the board hugs its rows: 220 px tall with both, 150 with the milestone alone and 146 with the quest alone (the least the board art's top and bottom slices take), when every text is one line. With neither row, on a fresh save before its first quest, the board hides its art, title and cords and lets clicks through to the map. Its root stays visible, since `MainView` hides and restores the root under the overlays.
- **No text is cut off.** The quest's name and step and the milestone's name and line wrap in 358 px (a `wrap_pad.tres` pad under the 15/18 lines), and the rows are containers, so a wrapped line pushes what is under it down and the board, cut into a top, a tiled middle and a bottom slice, grows by it. Each row is an even number of px tall (a name's lines are 20 px, a detail line's 18), so the board is too. The row heights are re-fitted after every text change, so the board takes its height back when the text shortens.
- It re-reads on `quest_started`, `quest_step_advanced`, `quest_completed`, `PersistenceManager.save_data_reset`, `CultivationManager.core_density_level_updated`, `CultivationManager.advancement_stage_changed` (the breakthrough), and `ResourceManager.madra_changed` / `gold_changed` (for a RESOURCE_AMOUNT figure). `refresh()` is public and does nothing before the board is ready.
- Only the first active quest shows; completed quests are not listed.

### QuestToast (`scenes/ui/quest_toast/quest_toast.tscn`, class `QuestToast`)

- `PanelContainer` (quest_toast.tres) with a centered `MessageLabel` (`LabelBody`). In `main_game.tscn` it is anchored top-center at 350×60, 28 px from the top, with z_index 10.
- Messages are "Quest Started: <quest_name>", "Quest Updated: <new step description>" (or "Quest Updated" if the index is invalid), and "Quest Complete: <quest_name>".
- Animation: a 0.2 s fade-in with a 20 px slide (`FADE_IN_DURATION`, `SLIDE_OFFSET_PX`), a 2.5 s hold (`HOLD_DURATION`), and a 0.4 s fade-out (`FADE_OUT_DURATION`). Messages queue in `_queue` and play sequentially. `show_message(text)` is public.
- Editor preview: `preview_message` plays once and skips signal wiring.

### Inventory Journal tab

The inventory's Journal tab lists quest **items** such as the Refugee Camp Map, each with the quest `get_quest_id_for_item()` gives it: its name, a DONE seal once it is finished or the step the player is on, its description as flavour text, and its steps reached so far with their `get_progress_text()` figures. See [INVENTORY.md](../inventory/INVENTORY.md).

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

Quest `description` values, which only the Journal shows (on a quest item's quest):
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
| `scenes/ui/goals_panel/goals_panel.gd` / `.tscn` | Goals board (quest step and Breakthrough milestone) |
| `scenes/ui/quest_toast/quest_toast.gd` / `.tscn` | Toast popup |
| `assets/styleboxes/ui/quest_toast.tres` | Toast stylebox |

Tests: `tests/unit/test_quest_*.gd` and `tests/integration/test_goals_panel.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Bugs

- `[MEDIUM]` Steps are not re-checked after advancing. Advancing stores the new index but never evaluates the new step. An event step whose event already fired can never complete, and a condition step that is already true waits for an unrelated trigger. Normal Foundation play avoids this, but the dev panel can soft-lock a quest. For example, triggering `celestial_intervener_dialogue_3` from the Story tab while `q_first_steps` is still on step 0 records the event, so when step 0 completes, step 1 waits for an event that has already fired, can never complete, and the path point is never awarded. Fix: run the retroactive pass after every advance and once per active quest at the end of `_ready()`.

### Missing Functionality

- `[MEDIUM]` The catalog is maintained by hand. A quest `.tres` that is missing from `quest_list.tres` is unknown at runtime, and `start_quest` only reports it with `push_error`. The design spec called for scanning `resources/quests/`. Either scan the folder or add a test that every `resources/quests/q_*.tres` is listed.
- `[LOW]` Only the first active quest shows. The Goals board has one quest row, so a second active quest (none today) would be invisible until the first completes, and completed quests are not listed anywhere.
- `[LOW]` `QuestData.description` shows only in the Journal, on the quest of a quest item, so a quest with no quest item never shows it.

### Content

- `[HIGH]` No quest exists after `q_reach_core_density_10`. Once the map is awarded, the Refugee Camp search, the Merchant, and the Tribulation have no quest on the Goals board (only its Breakthrough milestone, which reads "Face the Tribulation" at Core Density 100). Beat 5 ([FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md)) plans an optional `q_first_elite`, but it is not authored.
- `[MEDIUM]` Player-facing quest text contains the placeholder "[INTERVENER]": all three "Return to the Celestial [INTERVENER]" steps and the `q_reach_core_density_10` description. The Goals board, QuestToast and the Journal use plain Labels, so the brackets render literally.
- `[MEDIUM]` The `reach_cd_10` step doesn't tell the player how to gain Core Density. The Foundational Technique has no cycling zones and yields 0 CD XP, so the player must buy Pure Core Awakening and equip Smooth Flow first. Only the dialogue hints at this.

### UI

- `[LOW]` On a fresh save the Goals board stays hidden until the first dialogue starts a quest, so the first objective ("talk to the Intervener") is never written down.

### Tech Debt

- `[LOW]` Mismatched ext_resource UIDs fall back to the path, and Godot warns each time one is loaded. `quest_list.tres` references `q_first_steps.tres` as `uid://bqfirststeps01`, but the file header is `uid://d1mcp5rsmbbwu`. `main_game.tscn` references `quest_toast.tscn` as `uid://crqcxy8168ohk`, but the header is `uid://b1quest1toast1`.
- `[LOW]` Several quest resources use hand-written UIDs instead of Godot-generated ones: `uid://bquest1list00`, `uid://bqreachcdq001`, `uid://b1quest1toast1`, `uid://quest_toast_01`.
