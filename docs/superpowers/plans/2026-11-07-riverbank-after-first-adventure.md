# Riverbank Training after the first adventure (#142) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Riverbank Training no longer opens with the adventure at NPC 2's talk, before anything has hurt the player. First Steps Out becomes the first adventure: coming back from it, however the run ended, sends the player to NPC 3, and that talk completes First Steps Out, whose reward opens the river while the talk starts Temper Your Body. This mirrors Awaken Your Spirit, whose end opens the woods.

**Architecture:** Content and one event. First Steps Out's first step completes on a new event, `q_first_steps_adventure_ended`, which `AdventureView.stop_adventure()` fires as any run ends. NPC 3's talk gates on its registered condition. First Steps Out's `completion_effects` fire `riverbank_training_opened`, whose registered condition is the river's one unlock condition. A save version step keeps old saves whole. The "Head out?" board's Health lines point at the Intervener until the river opens.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** the issue (#142) with the answers recorded on it; canvas "Riverbank Training after the first fight" (https://claude.ai/artifact/Nc3dHqU4WctS3KJDA9uecc).

## Answers

- **When the river opens:** when First Steps Out completes, at NPC 3's talk (Lionel: "the quest that ... beat an enemy should also be the quest that ... makes riverbank training available", then "the quest that currently happens when you come back from your first adventure, whether you win or lose ... should as a reward give you riverbank training and start a quest to get strength up. Just like it does for [Madra]").
- **First Steps Out is about the first adventure, not a won fight.** Its first step, "Venture into the Shallow Woods", completes as the first run ends: won, lost, timed out, left by Exit. So a player sent home at 0 Health meets NPC 3 at once and gets the river from the talk. A lost fight opens nothing by itself.
- **Nothing beyond the NEW seal** on the river's card.
- **Old saves keep what they had** through a version step (8 when written; claimed at merge).
- **"Head out?" before the river opens:** "Below half. Return to the [INTERVENER] to heal it.", "Below half. Return to the [INTERVENER] to heal Health; cycling refills Madra.", and at 0 Health "The first hit that lands ends the run. Return to the [INTERVENER] to heal it." Once the river is open, #104's lines.
- **Route and presets follow play:** the route's First Steps Out beat fires the new event before NPC 3's talk; `adventure_open` has no river, every later preset does. No preset file changes.

## Tasks

### Task 1: the events and conditions
- [x] `resources/unlocks/q_first_steps_adventure_ended.tres` and `riverbank_training_opened.tres`, EVENT_TRIGGERED, each sharing its event's id, both registered in `unlock_condition_list.tres`.
- [x] `q_first_steps.tres`: step `first_adventure`, "Venture into the Shallow Woods", on `q_first_steps_adventure_ended`; `completion_effects` gain a TriggerEvent of `riverbank_training_opened` beside the path point.
- [x] `celestial_intervener_dialogue_3.tres` gates on `q_first_steps_adventure_ended` (and NPC 2's talk, as before).
- [x] `body_refining_action.tres` gates on `riverbank_training_opened`.

### Task 2: the run's end fires the event
- [x] `AdventureView.stop_adventure()` fires `q_first_steps_adventure_ended` when a run was on (the same `run_is_on` the play stats read), so a stop during the start's zoom ends no adventure. `q_first_steps_enemy_defeated` still fires on a win in `AdventureCombat`; nothing gates on it now.
- [x] Test: `tests/integration/test_riverbank_training_unlock.gd`, each way a run ends opens NPC 3 and not the river; a stop before the run starts fires nothing.

### Task 3: route, presets, tests that pinned the old moment
- [x] `story_route.tres`: `beat_2_adventure_ended` after `beat_2_enemy_defeated`.
- [x] `test_body_refining_content.gd` (the river's condition, registered, fired by First Steps Out's end), `test_zone_panel.gd` (the NEW seal test force-unlocks the new condition), `test_save_presets.gd` (`adventure_open` without the river, every later preset with it), and the chain tests that fired the win to reach NPC 3 (`test_foundation_quest_chain.gd`, `test_beat_3b_merchant_unlock.gd`, `test_goals_panel.gd`).

### Task 4: the "Head out?" lines
- [x] `AdventureConfirmBoard.advice_text()` names Riverbank Training only once its unlock conditions are met; before, the `*_BEFORE_RIVER` lines. Test in `test_adventure_confirm.gd`.

### Task 5: old saves (version 8)
- [x] `SaveGameData._migrate_to_v8()`: `q_fill_core_completed` latched → latch `riverbank_training_opened` (the save had the river); `q_first_steps_enemy_defeated` latched → latch `q_first_steps_adventure_ended` (the save could talk to NPC 3). Tests in `test_save_migration.gd`.

### Task 6: checks
- [x] `tests/run_tests.ps1` green.
- [x] Done-when checks in the game on `user://dev/runs/riverbank-unlock-after-first-fight.tres` (scratch driver, gitignored).

## Built differently from the issue

- The issue proposed opening the river as the first fight ends, however it ends, through a `first_fight_ended` event fired at every fight's end. Lionel chose First Steps Out's end instead, and made the quest's first step the first adventure rather than a won fight. So no fight-end event exists, `AdventureCombat` is untouched, and NPC 3 follows any first run, a lost one included: no player is stranded at 0 Health, since the talk is one click away.
- The issue kept NPC 3's gate on a won fight (#109's Decided). It now gates on the first adventure's end, at Lionel's word.
- The "Head out?" board's copy changes (the issue listed it as conditional).
- The version step covers NPC 3's gate as well as the river.
- The canvas's board 1 draws an intermediate version (a won fight shuts the river until NPC 3; a lost fight opens it). The final rule is the one above.
