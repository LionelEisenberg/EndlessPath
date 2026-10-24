# Dialogue (DialogueManager + Dialogic)

Last updated: 2026-10-23

## Overview

Narrative dialogue runs on the **Dialogic** addon (`addons/dialogic/`, version `2.0-Alpha-19 (Godot 4.4+)`, autoloaded as `Dialogic`). The game wraps it in the thin `DialogueManager` autoload, which starts a timeline (optionally jumping to a label) and re-broadcasts Dialogic's `timeline_ended` as `dialogue_ended`.

Timelines don't call into the game. Gameplay consequences such as events, quest starts, and unlocks come from the [EffectData](EFFECTS.md) attached to whatever started the dialogue. The caller runs those effects after `dialogue_ended`.

All authored dialogue today is the Celestial Intervener's four-part conversation in Spirit Valley: one timeline file with four labels.

## Player Experience

1. In Spirit Valley the player clicks an NPC dialogue zone action, for example "Talk to the [INTERVENER]".
2. A dark translucent backdrop covers the screen. The Intervener's portrait joins at center, and a 650×150 visual-novel textbox at the bottom reveals text at `letter_speed` 0.01.
3. The player advances lines with Enter, left click, Space, X, or gamepad A (`dialogic_default_action`). Text reveal is skippable after 0.1 s.
4. The portrait leaves and the timeline ends. The zone action's effects then run: new actions may appear, a quest toast may play, and the action disappears if `max_completions` is reached.

## Architecture

```
DialogueManager (autoload #11, singletons/dialogue_manager/dialogue_manager.gd)
  signal dialogue_started(timeline_name: String)     — no listeners
  signal dialogue_ended                              — one-shot listeners: ActionManager, AdventureTilemap
  var current_timeline_name: String                  — set on start, cleared on end; no readers
  start_timeline(timeline_name, label_or_idx = "") → Dialogic.start(...)
  _on_timeline_ended()  ← Dialogic.timeline_ended

Dialogic (autoload #10, uid://ds2q0uclmolvu → addons/dialogic/Core/DialogicGameHandler.gd)
  Dialogic.start(timeline, label) loads the default style's layout scene, then start_timeline()
  timeline names resolve through ProjectSettings [dialogic] directories/dtl_directory
```

### Callers

| Caller | Starts | On `dialogue_ended` |
|---|---|---|
| `ActionManager._execute_dialogue_action(NpcDialogueActionData)` | `DialogueManager.start_timeline(dialogue_timeline_name, dialogue_timeline_label_jump)`, after connecting `dialogue_ended → stop_action` with `CONNECT_ONE_SHOT` | `stop_action(true)`: increments zone progression for the action id (which can emit `ZoneManager.action_completed`), runs `success_effects` in order, then clears the current action |
| `AdventureTilemap.select_choice(DialogueChoice)` | `DialogueManager.start_timeline(choice.timeline_name)` (no label) and connects `_on_dialogue_ended` with `CONNECT_ONE_SHOT` | Runs `choice.success_effects`, then `_complete_current_tile(summary)` |

No authored encounter uses `DialogueChoice` yet.

## Data Model

### NpcDialogueActionData (`scripts/resource_definitions/zones/zone_action_data/npc_dialogue_action_data/npc_dialogue_action_data.gd`)

Extends `ZoneActionData`, with `action_type = NPC_DIALOGUE` (2) set in each `.tres`.

| Field | Type | Description |
|---|---|---|
| `dialogue_timeline_name` | `String` | Dialogic timeline name (key in `dtl_directory`) |
| `dialogue_timeline_label_jump` | `String` | Label to start at; `""` starts at the top |
| *(inherited)* `action_id`, `action_name`, `description`, `unlock_conditions`, `max_completions`, `success_effects`, `failure_effects` | | See [ZONES.md](../zones/ZONES.md) |

### DialogueChoice (`scripts/resource_definitions/adventure/choices/dialogue_choice.gd`)

Extends `EncounterChoice`.

| Field | Type | Description |
|---|---|---|
| `timeline_name` | `String` | Timeline to play. Label jumps are not supported. |

### DialogueManager API

| Member | Description |
|---|---|
| `start_timeline(timeline_name: String, label_or_idx: Variant = "") -> void` | Logs, calls `Dialogic.start()`, marks the triggering input as handled, emits `dialogue_started`, and stores `current_timeline_name` |
| `signal dialogue_started(timeline_name: String)` | Emitted after `Dialogic.start()`. Nothing listens. |
| `signal dialogue_ended` | Re-emits `Dialogic.timeline_ended` |
| `current_timeline_name: String` | Bookkeeping only |

## Dialogic Setup

### Project settings (`project.godot` `[dialogic]`)

| Setting | Value |
|---|---|
| `directories/dch_directory` | `celestial_intervener`, `wisened_dirt_eel` |
| `directories/dtl_directory` | `celestial_intervener_introduction_1` → `res://assets/dialogue/timelines/celestial_intervener_introduction_1.dtl` |
| `layout/default_style` | `res://assets/dialogue/styles/default_style.tres` |
| `extensions_folder` | `res://addons/dialogic_additions`. The folder does not exist. |
| `text/letter_speed` | 0.01 |
| `text/initial_text_reveal_skippable` / `text_reveal_skip_delay` | true / 0.1 |
| `text/advance_delay` / `autoadvance_per_character_delay` | 0.1 / 0.1 |
| `choices/autofocus_first` / `choices/delay` | true / 0.2 |
| `save/autosave_delay` | 60.0 |
| `glossary/default_case_sensitive` | true |
| Input `dialogic_default_action` | Enter, left mouse button, Space, X, joypad button 0 |

A new timeline must be registered in `dtl_directory` before `start_timeline()` can find it by name. The Dialogic editor registers timelines automatically. If a timeline fails to load, Dialogic prints an error and returns without emitting `timeline_ended`.

### Style (`assets/dialogue/styles/default_style.tres`, `DialogicStyle` "default_style")

Base layout: `default_layout_base.tscn`. Layers, in `layer_list` order:

| Layer | Scene | Overrides |
|---|---|---|
| Custom background | `assets/dialogue/styles/dialogue_backgrounds/dialogic_background.tscn` | `BackgroundLayer` (script `custom_background_layer.gd`, an empty `DialogicLayoutLayer`) containing a full-rect `DialogicNode_BackgroundHolder` ColorRect, `Color(0.176, 0.176, 0.176, 0.827)`, mouse ignore |
| Full background | `Layer_FullBackground/full_background_layer.tscn` | `disabled = true` |
| VN portraits | `Layer_VN_Portraits/vn_portrait_layer.tscn` | — |
| Full advance input | `Layer_Input/full_advance_input_layer.tscn` | — |
| VN textbox | `Layer_VN_Textbox/vn_textbox_layer.tscn` | `box_size` 650×150, `box_margin_bottom` 20 |
| Glossary popup | `Layer_Glossary/glossary_popup_layer.tscn` | — |
| VN choices | `Layer_VN_Choices/vn_choice_layer.tscn` | — |
| Text input | `Layer_TextInput/text_input_layer.tscn` | — |
| History | `Layer_History/history_layer.tscn` | — |

## Core Flows

### NPC dialogue zone action

```
ZoneActionButton click
  → ActionManager.select_action(npc_action)
      stops any current action (running its success_effects)
      → _execute_dialogue_action()
          DialogueManager.dialogue_ended.connect(stop_action, CONNECT_ONE_SHOT)
          DialogueManager.start_timeline("celestial_intervener_introduction_1", "dialogue_N")
              → Dialogic.start() → style layout → jump to label "dialogue_N"
  … player advances through lines … [end_timeline]
  → Dialogic.timeline_ended → DialogueManager.dialogue_ended
  → ActionManager.stop_action(true)
      → ZoneManager.increment_zone_progression_for_action(action_id)
           (count >= max_completions → action_completed → ZonePanel rebuild: the card goes)
      → success_effects in order, e.g. TriggerEvent("celestial_intervener_dialogue_N") → StartQuest(...)
      → the zone's idle action resumes ("Resumed <name>")
```

### How timelines reach game state

Timelines contain only `label`, `join`, `leave`, text lines, and `[end_timeline]`. No Dialogic `[signal]` events or variables are used, and `Dialogic.signal_event` is not connected anywhere. Everything that should happen because of a conversation lives in the owning action's `success_effects`. Because effects run on dialogue end, a mid-dialogue choice cannot branch gameplay today.

## Integration Points

| System | Connection |
|---|---|
| ActionManager | Runs NPC dialogue actions and applies their effects on `dialogue_ended` |
| ZoneManager | Counts completions; `max_completions = 1` makes each Intervener talk one-shot |
| UnlockManager | Each Intervener action after the first is gated by a latched condition. See [UNLOCKS.md](UNLOCKS.md). |
| EventManager / QuestManager | The effects fire `celestial_intervener_dialogue_N` events and start quests. See [EVENTS.md](EVENTS.md) and [QUESTS.md](../progression/QUESTS.md). |
| AdventureTilemap | `DialogueChoice` path; supported but unused |

## Existing Content

### Characters (`assets/dialogue/characters/`)

| Id | `display_name` | Portrait | Scale / offset | Used by |
|---|---|---|---|---|
| `celestial_intervener` | "Intervener [Celestial]" | "Normal Portrait" → `celestial_intervener.png` | 0.75 / (-550, 0) | All four timeline labels |
| `wisened_dirt_eel` | "Wisened Dirt Eel" | "NormalPortrait" → `wisened_dirt_eel.png` | 0.2 / (-450, 0) | Nothing. It is a leftover from the pre-rename NPC. |

The Intervener's character description names the character **Ashe**, one of the celestial interveners. Interveners are ascended warriors who make sure the most promising cultivators of each iteration and world reach the heavens. The name color is dark blue, `Color(0.097, 0, 0.672)`.

### Timeline `celestial_intervener_introduction_1.dtl`

Each label joins the Intervener at center, plays two lines, leaves, and ends with `[end_timeline]`.

| Label | Played by (zone action) | Content |
|---|---|---|
| `dialogue_1` | `celestial_intervener_dialogue_1`, "Talk to the [INTERVENER]" | The Intervener pulled the player out of a "[TIMELINE ALTERING EVENT]" just in time. The player's core is running dry, so they should cycle somewhere safe and come back when "all plumped up". |
| `dialogue_2` | `celestial_intervener_dialogue_2`, "Return to the [INTERVENER]" | The player now has Madra to defend themselves. They should go into the woods and fight a "[DREADBEAST]" or "[REMNANT]". |
| `dialogue_3` | `celestial_intervener_dialogue_3`, "Return to the [INTERVENER]" | The Intervener hopes the spirits weren't too much trouble. "[REPORT REQUESTED]". Time is short: strengthen your core "with that fancy new cycling technique" and report back. |
| `dialogue_4` | `celestial_intervener_dialogue_4`, "Return to the [INTERVENER]" | The core is humming. Before slipping away, the Intervener hands over a map to a refugee camp in the woods, where a merchant will trade gear for coin. |

### NPC dialogue zone actions (Spirit Valley)

| action_id | `action_name` | Label | Gate | `max_completions` | `success_effects` |
|---|---|---|---|---|---|
| `celestial_intervener_dialogue_1` | Talk to the [INTERVENER] | `dialogue_1` | None | 1 | TriggerEvent `celestial_intervener_dialogue_1`, StartQuest `q_fill_core` |
| `celestial_intervener_dialogue_2` | Return to the [INTERVENER] | `dialogue_2` | `q_fill_core_madra_full` | 1 | TriggerEvent `celestial_intervener_dialogue_2`, StartQuest `q_first_steps` |
| `celestial_intervener_dialogue_3` | Return to the [INTERVENER] | `dialogue_3` | `q_first_steps_enemy_defeated` | 1 | TriggerEvent `celestial_intervener_dialogue_3`, StartQuest `q_reach_core_density_10` |
| `celestial_intervener_dialogue_4` | Return to the [INTERVENER] | `dialogue_4` | `q_reach_cd_10` | 1 | TriggerEvent `celestial_intervener_dialogue_4` |

Action descriptions, shown on the action card:
- NPC 1: "As you get your bearings, a being of impossible power (and beauty) is waiting for you."
- NPC 2: "With your core now full, talk to the imposing figure."
- NPC 3: "Having bloodied your hands in battle, you return to the [INTERVENER] for advice."
- NPC 4: "Your core is tempered. Report back to the [INTERVENER] before they leave."

## Key Files

| File | Purpose |
|---|---|
| `singletons/dialogue_manager/dialogue_manager.gd` | Dialogic wrapper |
| `scripts/resource_definitions/zones/zone_action_data/npc_dialogue_action_data/npc_dialogue_action_data.gd` | NPC dialogue zone action data |
| `scripts/resource_definitions/adventure/choices/dialogue_choice.gd` | Encounter choice that plays a timeline |
| `singletons/action_manager/action_manager.gd` | `_execute_dialogue_action()` / `_stop_dialogue_action()` |
| `scenes/adventure/adventure_tilemap/adventure_tilemap.gd` | `DialogueChoice` handling |
| `assets/dialogue/timelines/celestial_intervener_introduction_1.dtl` | The only timeline |
| `assets/dialogue/characters/celestial_intervener/celestial_intervener.dch` / `.png` | Intervener character and portrait |
| `assets/dialogue/characters/wisened_dirt_eel/wisened_dirt_eel.dch` / `.png` | Unused character |
| `assets/dialogue/styles/default_style.tres` | Layout style |
| `assets/dialogue/styles/dialogue_backgrounds/dialogic_background.tscn`, `custom_background_layer.gd` | Dim backdrop layer |
| `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_{1..4}.tres` | NPC actions |

## Tests

No tests cover DialogueManager, the Dialogic setup, or the dialogue-end → effects path. Integration tests skip the dialogue and fire the NPC events directly, for example `test_beat_3b_merchant_unlock.gd` triggers `celestial_intervener_dialogue_4`.

## Work Remaining

### Bugs

- `[MEDIUM]` Malformed BBCode in `dialogue_1`, line 2: `[color=blue][CORE][color]`. The closing tag is `[color]` instead of `[/color]`, so the color tag is never closed.
- `[LOW]` If a timeline name is wrong, Dialogic prints an error and never emits `timeline_ended`. The NPC action then never stops: its effects never run and `ActionManager.current_action` stays set until the player selects another action. A misspelled label raises no error at all; `Jump.jump_to_label()` falls back to the current index, and what plays next is unverified. Nothing validates `dialogue_timeline_label_jump` against the timeline.

### Missing Functionality

- `[MEDIUM]` Timelines have no route into game state: no `Dialogic.signal_event` handling and no shared variables. Branching conversations, choices with consequences, and mid-dialogue rewards can't be authored. Every effect runs on dialogue end, in the same way regardless of what was said.
- `[LOW]` `DialogueChoice` only takes a timeline name, not a label, so encounter dialogue can't share a timeline file the way the NPC actions do. No authored encounter uses `DialogueChoice` yet.
- `[LOW]` `start_timeline()` doesn't guard against a timeline that is already running.

### Content

- `[HIGH]` The Intervener is the only speaking character and leaves after `dialogue_4`. No dialogue exists for the Refugee Camp, the Merchant, Beats 4–10, or the breakthrough. The Merchant has a shop (Beat 4) but no dialogue.
- `[MEDIUM]` Player-facing text is full of bracketed placeholders: "[INTERVENER]" in four action names and two action descriptions, the display name "Intervener [Celestial]", and "[TIMELINE ALTERING EVENT]", "[CORE]", "[DREADBEAST]", "[REMNANT]", and "[REPORT REQUESTED]" in the timeline.
- `[LOW]` The copy needs an editorial pass. `dialogue_3` contains the typo "suprise". The `refugee_camp_map` item's `from_source` says "Old Vesh, in the broken shrine", but the Intervener hands over the map in `dialogue_4`.

### Tech Debt

- `[LOW]` `wisened_dirt_eel.dch` and its portrait are registered in `dch_directory` but no timeline uses them.
- `[LOW]` `extensions_folder` points at `res://addons/dialogic_additions`, which doesn't exist.
- `[LOW]` DialogueManager has dead surface (`dialogue_started` has no listeners and `current_timeline_name` has no readers) and no class `##` doc comment.
- `[LOW]` Dialogic is pinned to a pre-release, `2.0-Alpha-19`. Upgrading needs a check of the style layers and `start()` and label-jump behavior.
