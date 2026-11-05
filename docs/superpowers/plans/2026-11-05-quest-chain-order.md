# Intervener Chain Order Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each return visit of the Celestial Intervener (NPCs 2, 3 and 4) shows only after the talk before it, so the chain can't open out of order once kills pay Core Density (#90).

**Architecture:** Data only. Each return NPC's `unlock_conditions` gains the previous NPC's EVENT_TRIGGERED condition, beside its own gate. NPC 2's and NPC 3's events get new condition files, registered in `unlock_condition_list.tres` so they latch (NPC 1's and NPC 4's exist). Old saves latch the new conditions with no new code: every save binding ends with `ResourceManager._update_resources()` emitting `madra_changed`, after `EventManager` and `UnlockManager` have re-bound (autoload order), and `UnlockManager` sweeps every registered condition on it. A test pins that; only if it fails does the chunk add a load-time sweep.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** Issue #88 ("Gate each Intervener return on the talk before it"); the stats rework plan's phase 6, Task 6.1 (`docs/superpowers/plans/2026-11-04-stats-rework.md`); the merge rules in tracking issue #85.

## Global Constraints

- The NPC actions change in `unlock_conditions` only. Effects, descriptions and dialogue stay.
- Pattern B and every event id other content gates on stay as they are.
- No save schema change, so no version step. The PR says so.
- The unlock and NPC files are edited by hand. The known UID mismatches stay as they are (#109 fixes them): NPC 3 references `q_first_steps_enemy_defeated.tres` as `uid://d1vxkodelucwu` (header `uid://bqfsendefeat01`), and NPC 4 references `q_reach_cd_10.tres` as `uid://i2xnqd3pem53` (header `uid://bqreachcd10001`). Any editor UID rewrite is committed alone.
- New condition files follow `celestial_intervener_dialogue_4.tres`: no `uid` in the header and a path-only `ext_resource` wherever they are referenced, so nothing carries a hand-written UID (conventions, rule 7).
- No living doc is edited; the PR ends with `## Docs to update`.

## Review Focus

1. **An old save past a talk, loaded from a file.** The new condition latches on the load's sweep, and the next NPC shows at once. Pinned by Task 2's old-save test, through `PersistenceManager.open_save_file()`.
2. **The NPC's own goal met first** (Madra 100, the first win, Core Density 10). The NPC stays hidden until the previous talk. Pinned by Task 2's table test.
3. **"Harden Your Core" started at Core Density 10.** It waits on NPC 4's talk instead of completing at once. Pinned by Task 2's table test (the NPC 4 case) and the Beat 3b flow test.
4. **The story route and every preset.** They play the talks in order already (talk 1, Madra 100, talk 2, the win, talk 3, Core Density 10, talk 4), so they still build. Pinned by the existing `test_story_route.gd` and `test_save_presets.gd`.
5. **The dev panel's Story tab on a locked NPC.** It names every unmet id, the previous talk's now among them. No test pins the order; the names follow each array's order (own gate first, then the talk).

---

### Task 1: Gate NPCs 2 to 4 on the previous talk

**Files:**
- Create: `resources/unlocks/celestial_intervener_dialogue_2.tres`, `resources/unlocks/celestial_intervener_dialogue_3.tres`
- Modify: `resources/unlocks/unlock_condition_list.tres`
- Modify: `resources/zones/spirit_valley_zone/zone_actions/celestial_intervener_dialogue_2.tres`, `_3.tres`, `_4.tres`
- Modify: `tests/integration/test_beat_3b_merchant_unlock.gd`
- Test: `tests/integration/test_foundation_quest_chain.gd` (new)

**Interfaces:**
- Produces: registered conditions `celestial_intervener_dialogue_2` and `celestial_intervener_dialogue_3` (EVENT_TRIGGERED, `target_value` the event of the same name, `comparison_op` `""`), appended to the registry after `celestial_intervener_dialogue_4`.

- [ ] **Step 1: Write the failing chain test.** `test_no_return_npc_shows_before_the_one_before_it`, a table over NPCs 2 to 4. Each case starts from a fresh save in Spirit Valley, completes the NPCs before the previous one (with their own gates met through `DevCommands`), meets the NPC's own gate early, asserts the NPC is not in `ZoneManager.get_available_actions("SpiritValley")`, completes the previous NPC with `DevCommands.complete_action()`, and asserts it shows:

  | NPC | Played first | Own gate met early | Previous NPC completed |
  |---|---|---|---|
  | 2 | nothing | `set_madra(100.0)` | NPC 1 |
  | 3 | NPC 1, `set_madra(100.0)` | `trigger_event("q_first_steps_enemy_defeated")` | NPC 2 |
  | 4 | NPC 1, Madra 100, NPC 2, the win | `reach_core_density(10)` | NPC 3 |

  The NPC 4 case also asserts "Harden Your Core" (`q_reach_core_density_10`) is active at step 1 (`return_to_npc`) and not completed. Assert messages name the NPC.

- [ ] **Step 2: Run it and see the NPC 2 and NPC 4 cases fail** (each NPC shows on its own gate alone; NPC 3's own gate can't be met early in play, but the test meets it through the event).

  Run: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_foundation_quest_chain.gd -gexit`

- [ ] **Step 3: Create the two condition files** as copies of `celestial_intervener_dialogue_4.tres` with the id and target changed; register both in `unlock_condition_list.tres` (path-only `ext_resource`, appended to `list`).

- [ ] **Step 4: Gate the NPCs.** Append to each NPC's `unlock_conditions`, after its own gate, the previous NPC's condition: NPC 2 `celestial_intervener_dialogue_1.tres` (its header UID `uid://2ojw7sl0d3lp` is correct, so the reference carries it), NPC 3 and NPC 4 the new files (path-only).

- [ ] **Step 5: Update the Beat 3b flow test.** It plays NPCs 1 to 3 before reaching Core Density 10 (completing NPC 3 starts the quest it checks) and asserts NPC 4 stays hidden until NPC 3's talk.

- [ ] **Step 6: Run both files and see them pass.**

- [ ] **Step 7: Commit** the conditions, registry, NPC files and both tests: `feat(quests): gate each Intervener return on the talk before it`.

### Task 2: Old saves latch the new gates at load

**Files:**
- Test: `tests/integration/test_foundation_quest_chain.gd`
- Modify, only if the test fails: `singletons/unlock_manager/unlock_manager.gd` plus the hook that runs once every manager has re-bound

- [ ] **Step 1: Write the old-save test.** `test_an_old_save_past_npc_3_shows_npc_4_on_load`: play NPCs 1 to 3 and reach Core Density 10, then remove `celestial_intervener_dialogue_2` and `celestial_intervener_dialogue_3` from the latched ids, as a save written before they were registered holds them. Write the save to a `user://` temp file, bind a fresh save, then `PersistenceManager.open_save_file(<temp file>)`. Assert both conditions latched and NPC 4 is available. `after_each()` binds the original save and path back and deletes the temp file.

- [ ] **Step 2: Run it.** Expected: PASS with no code change (the sweep on ResourceManager's `madra_changed` latches them). If it fails, add a sweep that runs once every manager has re-bound (not in `UnlockManager._initialize_from_save()`, since ResourceManager and InventoryManager re-bind after it), and record it under "Built differently" below.

- [ ] **Step 3: Commit** the test: `test(quests): pin old saves latching the new gates at load`.

### Task 3: Verify and open the PR

- [ ] **Step 1:** `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1` passes; a failure is confirmed in one process before acting on it.
- [ ] **Step 2:** Run the issue's "Done when" checks in the game on `-- --save=user://dev/runs/quest-chain-order.tres` and from the presets they name, plus the old-save check on a save written before this change.
- [ ] **Step 3:** Open the PR closing #88, with the checks Lionel runs and `## Docs to update`: `ZONES.md`, `UNLOCKS.md`, `DIALOGUE.md`, `QUESTS_EVENTS_UNLOCKS_CONVENTIONS.md`, `QUESTS.md`, `FOUNDATION_PLAYTHROUGH.md`, and this plan's row in `docs/superpowers/README.md`.

## Built differently

- **The old-save test passed with no new code**, so the chunk adds no load-time sweep. The test landed in Task 1's commit, beside the chain test in the same file.
- **"Harden Your Core" has its own test**, `test_harden_your_core_started_at_core_density_10_waits_on_npc_4`, instead of a case in the table: it tries to talk to NPC 4 before NPC 3 (refused), then checks the quest NPC 3 starts waits on step 1. Without the try it passed on the old data too, since nothing talked to NPC 4.
- **The Beat 3b flow test** plays NPCs 1 to 3 before Core Density 10 and drops nothing else. It does not re-check that NPC 4 waits for NPC 3's talk, which the chain test owns.
