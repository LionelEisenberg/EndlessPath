# Merchant map goal (#146) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Once NPC 4 hands over the Refugee Camp Map, the Goals board says what it is for: find the refugee camp in the Shallow Woods, where the Traveling Merchant waits.

**Architecture:** Content first: one new quest (`q_find_the_camp`) that NPC 4's talk starts after its event (Pattern B), with one condition step (the map owned + `merchant_discovered`) and a 50 gold reward; the map-owned condition promoted to a registered `.tres`. One board rule in `GoalsPanel`: while the quest row shows, the Breakthrough row's list of missing requirements folds away, leaving its name and stars. New copy on the map item. The story route splits `beat_3b` so a new `find_the_camp` preset can stop between the map and the camp.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** the issue (#146) with the approved canvas's answers ([comment](https://github.com/LionelEisenberg/EndlessPath/issues/146#issuecomment-6713227378), [canvas](https://claude.ai/artifact/4xup48jc5BqQPHmHfMR1CB)).

## Approved on the canvas

Lionel approved the "Merchant goal" canvas on 2026-11-07 ("yes new quest is good"), with one change: the quest pays 50 gold.
- **Find the Camp**, new: NPC 4 starts it after its event. One step, "Find the refugee camp in the Shallow Woods": the map owned + the camp approached (`merchant_discovered`). Description: "The [INTERVENER]'s map leads to a refugee camp in the Shallow Woods. A merchant there trades gear for gold." Reward: 50 gold (a starting value; #111 is paused).
- **It ends at the camp.** No step at the shop.
- **The board:** while a quest row shows, the Breakthrough row folds to its name and stars; its list returns when the quest ends. "Face the Tribulation" and "<Stage> reached" are one line and are not a list: they stay.
- **NPC 4's lines and card stay.** The camp is not marked on the run's map.
- **The map's Journal entry:** filed under Find the Camp (the quest needs it), then Find the Camp, DONE. From "the [INTERVENER], in Spirit Valley"; description "A hand-drawn map to a camp of refugees hidden in the Shallow Woods."
- **Route and presets:** `beat_3b` splits: new `beat_3b_map` "The map" (Core Density 20, NPC 4's talk), then `beat_3b` "Merchant unlocked" (approach the camp). New preset `find_the_camp` through `beat_3b_map`. `merchant_open` keeps `beat_3b`.

## Global Constraints

- Kept ids stay: `q_reach_core_density_10`, `celestial_intervener_dialogue_4`, `merchant_discovered`, `refugee_camp`, every beat and preset id.
- No quest reward refills Madra or Health (`test_home_madra_sources.gd`, `test_home_health_sources.gd` walk every effect).
- Every condition a quest step uses is registered (`test_every_condition_a_step_or_npc_uses_is_registered`).
- No save version step: a new quest moves no kept quest's steps. No enum value is appended.
- New `.tres` files carry no hand-written UID; references to them are path-only.
- No text is cut off; UI stays in the `.tscn`, the script only sets visibility.
- No living docs in this branch (`docs/inventory/ITEMS.md` does not list the map's copy); the PR ends with `## Docs to update`.
- Shared with #142: `story_route.tres` (its `beat_2`, this `beat_3b`), `test_story_route.gd`, `test_save_presets.gd`, `unlock_condition_list.tres` (one line: the second to merge keeps both entries).

## Review Focus

1. **The step's order of events.** NPC 4's effects run `TriggerEvent` (Harden Your Core completes, the map is awarded) before `StartQuest`, so the map is owned when the quest starts and its retroactive check stops on `merchant_discovered`. The camp only places while the map is owned, so `merchant_discovered` can't fire early.
2. **A save past NPC 4 with the camp unfound** has no quest: its board shows the full Breakthrough row, and the camp still places on its runs.
3. **The fold follows the quest row,** whether the quest or the milestone changed last (`_on_quest_changed` reruns only `_update_quest()`).

### Task 1: The quest and its condition

**Files:** `resources/unlocks/refugee_camp_map_owned.tres` (new), `resources/unlocks/unlock_condition_list.tres`, `resources/adventure/encounters/shallow_woods/special_encounters/refugee_camp_encounter.tres`, `resources/quests/q_find_the_camp.tres` (new), `resources/quests/quest_list.tres`, `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_4.tres`, `tests/integration/test_foundation_quest_chain.gd`, `tests/integration/test_beat_3b_merchant_unlock.gd`.

- [ ] Test first: NPC 4's chain case starts `q_find_the_camp`; a new test plays NPC 4's talk, checks the quest is on its step, fires `merchant_discovered`, and checks the quest completes with +50 gold and no Madra or Health.
- [ ] `refugee_camp_map_owned.tres`: ITEM_OWNED `refugee_camp_map`, registered. The camp encounter references it instead of its inline copy (rule 5).
- [ ] `q_find_the_camp.tres`: one step `find_camp` with both conditions; `AwardResourceEffectData` gold 50. Added to `quest_list.tres` after Harden Your Core.
- [ ] NPC 4: a `StartQuestEffectData` after its `TriggerEventEffectData`.

### Task 2: The map's copy and Journal link

**Files:** `resources/items/quest_items/refugee_camp_map.tres`, `tests/unit/test_quest_item_link.gd`, `tests/integration/test_journal_page.gd`.

- [ ] Test: the map belongs to Find the Camp while it runs and once done; to Harden Your Core on a save that never started it.
- [ ] `from_source` "the [INTERVENER], in Spirit Valley"; the new description.

### Task 3: The Breakthrough row folds under a quest

**Files:** `scenes/ui/goals_panel/goals_panel.gd`, `tests/integration/test_goals_panel.gd`.

- [ ] Tests: with a quest and a missing list, the list hides and the name and stars show; the board is 202 px with one-line rows; the list returns when the quest completes; "Face the Tribulation" stays under a quest. `test_npc_4_hands_the_board_to_the_breakthrough` plays NPC 4's real effects: Find the Camp shows over the folded row.
- [ ] `_update_milestone()` records whether the row shows a list; `_fit_rows()` shows the list only while no quest row shows, then fits the height.

### Task 4: Route and preset

**Files:** `resources/dev/story_route.tres`, `resources/dev/save_presets/find_the_camp.tres` (new), `tests/integration/test_save_presets.gd`.

- [ ] `beat_3b_map` "The map" (Core Density 20, NPC 4's talk; reached when `celestial_intervener_dialogue_4`) before `beat_3b` "Merchant unlocked" (the camp).
- [ ] Preset `find_the_camp` ("Find the Camp", "The map in hand. Find the Camp sends you to the refugee camp in the Shallow Woods.") through `beat_3b_map`. Test: it starts with the map owned, Find the Camp on its step, the merchant closed.

### Task 5: Wrap

- [ ] `tests/run_tests.ps1` green; the issue's Done-when checks on `-- --save=user://dev/runs/merchant-map-goal.tres`, including two pre-change saves; PR with `## Docs to update`.

## What was built differently

(Filled in after the build.)
