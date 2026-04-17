# Foundation Beat 1 (Awakening) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the first playable beat end-to-end. Player starts Spirit Valley with only the NPC action available. Talking to the NPC unlocks Cycling, starts the `q_fill_core` quest, and cycling to max Madra + returning to the NPC completes the quest and unlocks Adventure.

**Architecture:** Purely data-driven — the game already has the singletons (QuestManager, UnlockManager, ResourceManager, EventManager, ZoneManager), the resource classes (QuestData, UnlockConditionData, NpcDialogueActionData, StartQuestEffectData, TriggerEventEffectData), and the first NPC dialogue action. This plan:

0. Renames existing Spirit Valley content to the final identifiers (`wandering_spirit_*`, `wilderness_cycling_action`, `spirit_valley_adventure_action`) and removes `mountain_top_cycling_action` from the scope entirely.
1. Adds one QuestManager behavior: listen to `UnlockManager.condition_unlocked` and re-evaluate active quests' condition-based steps. This lets quests advance on state predicates (resource amounts, attributes, levels) without each state manager having to know about quest semantics.
2. Authors the `q_fill_core` quest as a `.tres` resource with all one-off effects **inlined as sub-resources** (no proliferating effect files).
3. Authors a second NPC zone action (return-talk) with a new Dialogic timeline.
4. Gates remaining zone actions so the Beat 1 flow is the only path forward.

**Architecture decisions that propagate to later beats:**

- **Quest steps default to condition-based where a state predicate fits; event-based where only a one-shot semantic moment fits.** Step 1 ("filled madra") is a state predicate → condition. Step 2 ("talked to NPC") is a one-shot → event.
- **Condition IDs are quest-scoped** (e.g. `q_fill_core_madra_full`, not `madra_full`). Each quest's conditions are independent; no collision when future quests reuse the same predicate shape.
- **One-off effects live as inline `[sub_resource ...]` blocks** in their parent `.tres`. Promote to a separate file only when reused across multiple parents. This keeps `resources/effects/` from ballooning as the remaining 9 beats land.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.6.0 for tests, Dialogic for dialogue timelines.

**Reference spec:** [`docs/progression/FOUNDATION_PLAYTHROUGH.md`](../../progression/FOUNDATION_PLAYTHROUGH.md) § Beat 1 — Awakening.

**Test command (single file):**
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

**Test command (full suite):**
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

**Godot import (after authoring new `.tres` files or renames):**
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

---

## Naming map (applied in Task 0)

| Old | New |
|---|---|
| action id `initial_spirit_valley_dialogue_1` | `wandering_spirit_dialogue_1` |
| action id `initial_spirit_valley_dialogue_2` (new file) | `wandering_spirit_dialogue_2` |
| event id `initial_spirit_valley_dialogue_1` | `wandering_spirit_dialogue_1` |
| event id `initial_spirit_valley_dialogue_2` | `wandering_spirit_dialogue_2` |
| condition id `initial_spirit_valley_dialogue_1` | `wandering_spirit_dialogue_1` |
| Dialogic timeline `spirit_valley` (+ `.dtl` file) | `wandering_spirit_1` |
| Dialogic timeline `spirit_valley_return` (new) | `wandering_spirit_2` |
| action id `basic_room_cycling_action` | `wilderness_cycling_action` (display: "Wilderness Cycling") |
| action id `test_adventure_action_data` | `spirit_valley_adventure_action` |
| `mountain_top_cycling_action` | **removed entirely** |

Display names (`action_name`) on the two NPC dialogues are left as-is ("Talk to the Wisened Dirt Eel" / "Return to the Wisened Dirt Eel") — placeholder flavor copy, orthogonal to the id rename.

---

## File Structure

**New files (created by later tasks):**

| File | Responsibility |
|---|---|
| `resources/quests/q_fill_core.tres` | QuestData: two-step quest. Completion effect is an inline TriggerEvent sub-resource. |
| `resources/unlocks/q_fill_core_madra_full.tres` | UnlockConditionData: RESOURCE_AMOUNT ≥ 100 on madra. Gates quest step 1 AND NPC 2 visibility. |
| `resources/unlocks/q_fill_core_completed.tres` | UnlockConditionData: EVENT_TRIGGERED on `q_fill_core_completed`. Gates Adventure + Foraging. |
| `resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_2.tres` | NpcDialogueActionData: return-talk. TriggerEvent success-effect is an inline sub-resource. |
| `assets/dialogue/timelines/wandering_spirit_2.dtl` | Dialogic timeline for NPC 2 (minimal placeholder copy). |

**Files renamed by Task 0:**

| From | To |
|---|---|
| `resources/zones/spirit_valley_zone/zone_actions/initial_spirit_valley_dialogue_1.tres` | `resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_1.tres` |
| `resources/effects/trigger_event/initial_spirit_valley_dialogue_1_trigger_event_effect.tres` | `resources/effects/trigger_event/wandering_spirit_dialogue_1_trigger_event_effect.tres` |
| `resources/unlocks/initial_spirit_valley_dialogue_1.tres` | `resources/unlocks/wandering_spirit_dialogue_1.tres` |
| `resources/zones/spirit_valley_zone/zone_actions/basic_room_cycling_action.tres` | `resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres` |
| `resources/zones/spirit_valley_zone/zone_actions/test_adventure_action_data.tres` | `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres` |
| `assets/dialogue/timelines/spirit_valley.dtl` | `assets/dialogue/timelines/wandering_spirit_1.dtl` |

**Files removed by Task 0:**

- `resources/zones/spirit_valley_zone/zone_actions/mountain_top_cycling_action.tres` (+ `.uid` sidecar)

**Modified files (by later tasks):**

| File | Change |
|---|---|
| `singletons/quest_manager/quest_manager.gd` | Listen to `UnlockManager.condition_unlocked` in `_ready`; handler iterates active quests and re-evaluates condition-based steps. |
| `tests/unit/test_quest_manager.gd` | Add GUT test covering the new listener. |
| `resources/quests/quest_list.tres` | Add `q_fill_core` to the `quests` array. |
| `resources/unlocks/unlock_condition_list.tres` | Add both new unlock conditions to `list` (and update path for renamed `wandering_spirit_dialogue_1` if the editor didn't auto-repath). |
| `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` | Remove mountain_top ref; add NPC 2. |
| `resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_1.tres` | Append an inline StartQuest sub-resource to `success_effects`. |
| `resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres` | Set `unlock_conditions` to `[wandering_spirit_dialogue_1]`. |
| `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres` | Set `unlock_conditions` to `[q_fill_core_completed]`. |
| `resources/zones/spirit_valley_zone/zone_actions/spring_forest_foraging_action.tres` | Temp Beat 1 gate: `unlock_conditions = [q_fill_core_completed]`. Revisit in later beat plans. |

**Notes:**
- The existing NPC 1 action currently awards a dagger (`AwardItemEffectData`, inline sub-resource). That's legacy placeholder content — leave it alone; Beat 2 is where first-loot is designed.
- `.tres` files with `script_class` metadata auto-generate `.uid` sidecars on import. Don't hand-author `.uid` files.
- External `.tres` references use both `uid://...` and `path="res://..."`. The UID stays stable across renames; if a path reference goes stale, Godot falls back to the UID. We still update path strings for clarity.

---

## Task 0: Rename + remove prep

Rename existing Spirit Valley content to final identifiers and delete `mountain_top_cycling_action`. No behavior change — this is a pure refactor that later tasks build on top of.

**Files affected:** listed in the Naming map above.

- [ ] **Step 1: Rename NPC 1 action file and update its internals**

Move the file and its UID sidecar:

```bash
git mv resources/zones/spirit_valley_zone/zone_actions/initial_spirit_valley_dialogue_1.tres resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_1.tres
git mv resources/zones/spirit_valley_zone/zone_actions/initial_spirit_valley_dialogue_1.tres.uid resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_1.tres.uid
```

(If the `.uid` sidecar doesn't exist yet, skip its `git mv` — Godot will regenerate on import.)

Then edit `wandering_spirit_dialogue_1.tres` internals:
- `action_id`: `"initial_spirit_valley_dialogue_1"` → `"wandering_spirit_dialogue_1"`
- `dialogue_timeline_name`: `"spirit_valley"` → `"wandering_spirit_1"`
- Leave `action_name` and `description` unchanged (display-only).

- [ ] **Step 2: Rename NPC 1 trigger-event effect file and update its internals**

```bash
git mv resources/effects/trigger_event/initial_spirit_valley_dialogue_1_trigger_event_effect.tres resources/effects/trigger_event/wandering_spirit_dialogue_1_trigger_event_effect.tres
git mv resources/effects/trigger_event/initial_spirit_valley_dialogue_1_trigger_event_effect.tres.uid resources/effects/trigger_event/wandering_spirit_dialogue_1_trigger_event_effect.tres.uid 2>/dev/null || true
```

Then edit the renamed file:
- `event_id`: `"initial_spirit_valley_dialogue_1"` → `"wandering_spirit_dialogue_1"`

- [ ] **Step 3: Rename NPC 1 unlock condition file and update its internals**

```bash
git mv resources/unlocks/initial_spirit_valley_dialogue_1.tres resources/unlocks/wandering_spirit_dialogue_1.tres
git mv resources/unlocks/initial_spirit_valley_dialogue_1.tres.uid resources/unlocks/wandering_spirit_dialogue_1.tres.uid 2>/dev/null || true
```

Then edit the renamed file:
- `condition_id`: `"initial_spirit_valley_dialogue_1"` → `"wandering_spirit_dialogue_1"`
- `target_value`: `"initial_spirit_valley_dialogue_1"` → `"wandering_spirit_dialogue_1"` (the condition's target is the event_id it watches for)

- [ ] **Step 4: Rename Dialogic timeline file**

```bash
git mv assets/dialogue/timelines/spirit_valley.dtl assets/dialogue/timelines/wandering_spirit_1.dtl
git mv assets/dialogue/timelines/spirit_valley.dtl.uid assets/dialogue/timelines/wandering_spirit_1.dtl.uid 2>/dev/null || true
```

No internal changes needed — Dialogic timelines identify themselves via filename.

- [ ] **Step 5: Rename cycling action file and update its internals**

```bash
git mv resources/zones/spirit_valley_zone/zone_actions/basic_room_cycling_action.tres resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres
git mv resources/zones/spirit_valley_zone/zone_actions/basic_room_cycling_action.tres.uid resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres.uid 2>/dev/null || true
```

Then edit the renamed file:
- `action_id`: `"basic_room_cycling_action"` → `"wilderness_cycling_action"`
- `action_name`: `"Cycling Room"` → `"Wilderness Cycling"`
- `description`: `"Cycle in your Room"` → `"Cycle in the wilderness"`

- [ ] **Step 6: Rename adventure action file and update its internals**

```bash
git mv resources/zones/spirit_valley_zone/zone_actions/test_adventure_action_data.tres resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres
git mv resources/zones/spirit_valley_zone/zone_actions/test_adventure_action_data.tres.uid resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres.uid 2>/dev/null || true
```

Then edit the renamed file:
- `action_id`: `"test_adventure_action_data"` → `"spirit_valley_adventure_action"`
- Leave `action_name` and `description` as-is for now (flavor copy — rename later when we decide on final names).

- [ ] **Step 7: Remove `mountain_top_cycling_action`**

```bash
git rm resources/zones/spirit_valley_zone/zone_actions/mountain_top_cycling_action.tres
git rm resources/zones/spirit_valley_zone/zone_actions/mountain_top_cycling_action.tres.uid 2>/dev/null || true
```

- [ ] **Step 8: Update `spirit_valley_zone.tres`**

Open `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` in the Godot editor (recommended — it tracks UID references and auto-updates paths). Verify:
- `all_actions` still contains: cycling (renamed), NPC 1 (renamed), foraging, adventure (renamed) — **4 items, not 5**.
- The mountain_top reference is gone.
- Path strings reflect the renames.

If the editor hasn't auto-updated paths, hand-edit the `ext_resource` lines and the `all_actions` array. The file should read approximately:

```
[gd_resource type="Resource" script_class="ZoneData" load_steps=9 format=3 uid="uid://bh1wsc1wrvc80"]

[ext_resource type="Script" uid="uid://cv640mljv33xk" path="res://scripts/resource_definitions/zones/zone_action_data/zone_action_data.gd" id="1_gfpen"]
[ext_resource type="Resource" uid="uid://c36o44atngp5e" path="res://resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_1.tres" id="2_4l7yp"]
[ext_resource type="Resource" uid="uid://cfbgjcfudlc3i" path="res://resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres" id="2_8fv6p"]
[ext_resource type="Texture2D" uid="uid://bmt3ti63lgbi5" path="res://64.png" id="2_ym136"]
[ext_resource type="Resource" uid="uid://bpiixpcykyiti" path="res://resources/zones/spirit_valley_zone/zone_actions/spring_forest_foraging_action.tres" id="3_4l7yp"]
[ext_resource type="Script" uid="uid://culb0p88pnexb" path="res://scripts/resource_definitions/zones/zone_data/zone_data.gd" id="5_owjyk"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="6_4wd7e"]
[ext_resource type="Resource" uid="uid://bbpx8ls6tj2u" path="res://resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres" id="6_owjyk"]

[resource]
script = ExtResource("5_owjyk")
zone_name = "Spirit Valley"
zone_id = "SpiritValley"
description = "Deep at the heart of the world lies Spirit Valley..."
icon = ExtResource("2_ym136")
all_actions = Array[ExtResource("1_gfpen")]([ExtResource("2_8fv6p"), ExtResource("2_4l7yp"), ExtResource("3_4l7yp"), ExtResource("6_owjyk")])
metadata/_custom_type_script = "uid://culb0p88pnexb"
```

(Preserve the full original `description` — it's abbreviated above for readability.)

- [ ] **Step 9: Update `unlock_condition_list.tres`**

Open in the Godot editor. Verify the renamed `wandering_spirit_dialogue_1.tres` reference still points at the right file (the UID is stable, so this usually auto-heals). If hand-editing, ensure:

```
[ext_resource type="Resource" uid="uid://2ojw7sl0d3lp" path="res://resources/unlocks/wandering_spirit_dialogue_1.tres" id="2_tsp8q"]
```

(Other `list` entries untouched at this point — Task 2 adds the two new conditions.)

- [ ] **Step 10: Run import and verify no stale references**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Scan the output for errors like "Resource file not found" or "Invalid UID". If any appear, track down the stale reference — typically a `path="res://..."` string in another `.tres` that needs updating.

Run the full test suite to confirm nothing broke:

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass.

- [ ] **Step 11: Launch the game briefly and verify nothing is visibly broken**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Expected: game loads, Spirit Valley shows the same zone actions as before EXCEPT `mountain_top_cycling_action` which is gone. Talking to NPC 1 still plays the timeline (now called `wandering_spirit_1`). No console errors.

- [ ] **Step 12: Commit**

```bash
git add -A resources/zones/spirit_valley_zone/ resources/effects/trigger_event/ resources/unlocks/ assets/dialogue/timelines/
git commit -m "refactor(zones): rename Spirit Valley content to final identifiers

Prep for Foundation Beat 1 implementation. Pure rename — no behavior
change.

  initial_spirit_valley_dialogue_1 -> wandering_spirit_dialogue_1
  Dialogic timeline: spirit_valley -> wandering_spirit_1
  basic_room_cycling_action -> wilderness_cycling_action
  test_adventure_action_data -> spirit_valley_adventure_action
  mountain_top_cycling_action: removed

Display names (action_name, description) on the NPC actions kept as
placeholder copy. Display name + description on the cycling action
updated to match (\"Wilderness Cycling\" / \"Cycle in the wilderness\").

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 1: QuestManager listens to `UnlockManager.condition_unlocked`

Add one signal listener to QuestManager so condition-based quest steps advance when UnlockManager flags their conditions as newly unlocked. **TDD.**

**Files:**
- Modify: `singletons/quest_manager/quest_manager.gd`
- Modify: `tests/unit/test_quest_manager.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/test_quest_manager.gd`. The test injects a condition-based quest into the manager's catalog, starts it, fires `condition_unlocked` manually, and asserts the quest completes.

```gdscript
func test_condition_unlocked_advances_condition_based_step() -> void:
    PersistenceManager.save_game_data = SaveGameData.new()
    PersistenceManager.save_data_reset.emit()

    # A condition that will evaluate true once madra >= 1 (simple threshold).
    var test_condition := UnlockConditionData.new()
    test_condition.condition_id = "test_madra_geq_1"
    test_condition.condition_type = UnlockConditionData.ConditionType.RESOURCE_AMOUNT
    test_condition.target_value = 1.0
    test_condition.comparison_op = ">="
    test_condition.optional_params = {"resource_type": "madra"}

    # Single-step quest whose step completes on that condition.
    var test_step := QuestStepData.new()
    test_step.step_id = "reach_madra_1"
    test_step.completion_conditions = [test_condition] as Array[UnlockConditionData]

    var test_quest := QuestData.new()
    test_quest.quest_id = "test_condition_listener_quest"
    test_quest.steps = [test_step] as Array[QuestStepData]

    # Inject into QuestManager's catalog for the duration of this test.
    QuestManager._quests_by_id[test_quest.quest_id] = test_quest

    # Reset madra so retroactive_advance doesn't auto-complete on start.
    ResourceManager.set_madra(0.0)
    QuestManager.start_quest(test_quest.quest_id)
    assert_true(QuestManager.has_active_quest(test_quest.quest_id),
        "Quest should be active after start (madra=0, condition not yet met)")

    # Bring madra up, then manually fire the signal the new listener handles.
    ResourceManager.set_madra(5.0)
    UnlockManager.condition_unlocked.emit("test_madra_geq_1")

    assert_false(QuestManager.has_active_quest(test_quest.quest_id),
        "Quest should complete after condition_unlocked fires and condition evaluates true")
    assert_true(QuestManager.has_completed_quest(test_quest.quest_id),
        "Quest should be recorded as completed")

    # Cleanup — remove the test quest from the catalog so it doesn't leak.
    QuestManager._quests_by_id.erase(test_quest.quest_id)
```

- [ ] **Step 2: Run the test to verify it fails**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_quest_manager.gd -gexit
```

Expected: FAIL on the `has_active_quest == false` assertion — without the listener, the signal does nothing.

- [ ] **Step 3: Add the listener to QuestManager**

Edit `singletons/quest_manager/quest_manager.gd`. In `_ready`, after the existing `EventManager.event_triggered.connect(...)` block, add:

```gdscript
	if UnlockManager:
		UnlockManager.condition_unlocked.connect(_on_condition_unlocked)
	else:
		Log.critical("QuestManager: UnlockManager not available on ready!")
```

Add the new handler near the existing `_on_event_triggered`:

```gdscript
## Re-evaluates condition-based steps when UnlockManager reports a newly
## unlocked condition. Quest steps that match (via their completion_conditions
## evaluating true) will advance. Event-based steps are untouched — they only
## advance through _on_event_triggered.
func _on_condition_unlocked(_condition_id: String) -> void:
	# Iterate over a copy since advancement may complete a quest and mutate active_quests.
	var active_ids: Array[String] = get_active_quest_ids()
	for quest_id: String in active_ids:
		# Empty triggering_event_id — only condition-based steps will be satisfied.
		_try_advance_step(quest_id, "")
```

- [ ] **Step 4: Run the test to verify it passes**

Re-run the test command. Expected: all tests in `test_quest_manager.gd` PASS.

- [ ] **Step 5: Run the full suite for regressions**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add singletons/quest_manager/quest_manager.gd tests/unit/test_quest_manager.gd
git commit -m "feat(quests): advance condition-based steps on condition_unlocked

QuestManager now listens to UnlockManager.condition_unlocked and
re-evaluates active quests' condition-based steps. This lets quests
use state predicates (RESOURCE_AMOUNT, ATTRIBUTE_VALUE, etc.) without
each state manager having to know about quest semantics.

Foundation Beat 1 uses this for q_fill_core step 1 (reach max Madra).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Author the two new unlock conditions

Two `UnlockConditionData` resources. `q_fill_core_madra_full` is a state predicate used by BOTH quest step 1 and NPC 2 visibility — sharing is fine because "player has once filled their core" is a permanent historical fact.

**Files:**
- Create: `resources/unlocks/q_fill_core_madra_full.tres`
- Create: `resources/unlocks/q_fill_core_completed.tres`
- Modify: `resources/unlocks/unlock_condition_list.tres`

- [ ] **Step 1: Create `q_fill_core_madra_full.tres`**

```
[gd_resource type="Resource" script_class="UnlockConditionData" load_steps=2 format=3 uid="uid://bqfcmadrafull01"]

[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="1_qfcm1"]

[resource]
script = ExtResource("1_qfcm1")
condition_id = "q_fill_core_madra_full"
condition_type = 6
target_value = 100.0
comparison_op = ">="
optional_params = {
"resource_type": "madra"
}
metadata/_custom_type_script = "uid://bk5wuop0jogg4"
```

`condition_type = 6` is `RESOURCE_AMOUNT` (enum order: CULTIVATION_STAGE=0, CULTIVATION_LEVEL=1, ZONE_UNLOCKED=2, ADVENTURE_COMPLETED=3, EVENT_TRIGGERED=4, ITEM_OWNED=5, RESOURCE_AMOUNT=6, ATTRIBUTE_VALUE=7, GAME_SYSTEM_UNLOCKED=8).

`target_value = 100.0` is Foundation's starting max Madra. Because starter cycling (pre-Keystone #1) grants Madra only — not Core Density XP — max Madra stays at 100 throughout Beat 1.

- [ ] **Step 2: Create `q_fill_core_completed.tres`**

```
[gd_resource type="Resource" script_class="UnlockConditionData" load_steps=2 format=3 uid="uid://bqfillcorecomp1"]

[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="1_qfc01"]

[resource]
script = ExtResource("1_qfc01")
condition_id = "q_fill_core_completed"
condition_type = 4
target_value = "q_fill_core_completed"
comparison_op = ""
metadata/_custom_type_script = "uid://bk5wuop0jogg4"
```

`condition_type = 4` is `EVENT_TRIGGERED`.

- [ ] **Step 3: Import**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

- [ ] **Step 4: Register both in `unlock_condition_list.tres`**

Open in the Godot editor. Add both new resources to the `list` array. If hand-editing:

```
[gd_resource type="Resource" script_class="UnlockConditionList" load_steps=7 format=3 uid="uid://chaqu7ri6ewe1"]

[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="1_aq0o0"]
[ext_resource type="Script" uid="uid://dskgt7ri3i7p3" path="res://scripts/resource_definitions/unlocks/unlock_condition_list.gd" id="2_2uato"]
[ext_resource type="Resource" uid="uid://2ojw7sl0d3lp" path="res://resources/unlocks/wandering_spirit_dialogue_1.tres" id="2_tsp8q"]
[ext_resource type="Resource" uid="uid://l11ly74pkjay" path="res://resources/unlocks/test_attribute_requirement_unlock_data.tres" id="3_pa8gf"]
[ext_resource type="Resource" uid="uid://bqfcmadrafull01" path="res://resources/unlocks/q_fill_core_madra_full.tres" id="4_qfcm1"]
[ext_resource type="Resource" uid="uid://bqfillcorecomp1" path="res://resources/unlocks/q_fill_core_completed.tres" id="5_qfc01"]

[resource]
script = ExtResource("2_2uato")
list = Array[ExtResource("1_aq0o0")]([ExtResource("2_tsp8q"), ExtResource("3_pa8gf"), ExtResource("4_qfcm1"), ExtResource("5_qfc01")])
metadata/_custom_type_script = "uid://dskgt7ri3i7p3"
```

- [ ] **Step 5: Commit**

```bash
git add resources/unlocks/q_fill_core_madra_full.tres resources/unlocks/q_fill_core_madra_full.tres.uid resources/unlocks/q_fill_core_completed.tres resources/unlocks/q_fill_core_completed.tres.uid resources/unlocks/unlock_condition_list.tres
git commit -m "feat(unlocks): add q_fill_core_madra_full and q_fill_core_completed conditions

Quest-scoped unlock conditions for Foundation Beat 1. madra_full is a
RESOURCE_AMOUNT state predicate gating quest step 1 and NPC 2
visibility; completed is an EVENT_TRIGGERED latch gating Adventure and
the temp-gated Foraging action.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Author the `q_fill_core` quest (mixed conditions + event)

Two-step quest: step 1 condition-based (reach max Madra, via `q_fill_core_madra_full`), step 2 event-based (return to NPC, fires on `wandering_spirit_dialogue_2` event). Completion fires `q_fill_core_completed` via an inline TriggerEvent sub-resource.

**Files:**
- Create: `resources/quests/q_fill_core.tres`
- Modify: `resources/quests/quest_list.tres`

- [ ] **Step 1: Create `q_fill_core.tres`**

```
[gd_resource type="Resource" script_class="QuestData" load_steps=7 format=3 uid="uid://bqfillcore0001"]

[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="1_qfc01"]
[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_data.gd" id="2_qfc02"]
[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_step_data.gd" id="3_qfc03"]
[ext_resource type="Script" uid="uid://cc0ky7w2fsg10" path="res://scripts/resource_definitions/effects/trigger_event_effect_data.gd" id="4_qfc04"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="5_qfc05"]
[ext_resource type="Resource" uid="uid://bqfcmadrafull01" path="res://resources/unlocks/q_fill_core_madra_full.tres" id="6_qfc06"]

[sub_resource type="Resource" id="Resource_step1"]
script = ExtResource("3_qfc03")
step_id = "reach_max_madra"
description = "Fill your Madra by cycling"
completion_event_id = ""
completion_conditions = Array[ExtResource("5_qfc05")]([ExtResource("6_qfc06")])
metadata/_custom_type_script = "res://scripts/resource_definitions/quests/quest_step_data.gd"

[sub_resource type="Resource" id="Resource_step2"]
script = ExtResource("3_qfc03")
step_id = "return_to_npc"
description = "Return to the NPC"
completion_event_id = "wandering_spirit_dialogue_2"
completion_conditions = Array[ExtResource("5_qfc05")]([])
metadata/_custom_type_script = "res://scripts/resource_definitions/quests/quest_step_data.gd"

[sub_resource type="Resource" id="Resource_completion_trigger"]
script = ExtResource("4_qfc04")
event_id = "q_fill_core_completed"
effect_type = 1
metadata/_custom_type_script = "uid://cc0ky7w2fsg10"

[resource]
script = ExtResource("2_qfc02")
quest_id = "q_fill_core"
quest_name = "Awaken Your Core"
description = "Fill your Madra core and return to speak with the stranger."
steps = Array[Resource]([SubResource("Resource_step1"), SubResource("Resource_step2")])
completion_effects = Array[ExtResource("1_qfc01")]([SubResource("Resource_completion_trigger")])
metadata/_custom_type_script = "res://scripts/resource_definitions/quests/quest_data.gd"
```

- [ ] **Step 2: Import**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

- [ ] **Step 3: Register in `quest_list.tres`**

Open in the Godot editor. Add `q_fill_core.tres` to `quests`. If hand-editing:

```
[gd_resource type="Resource" script_class="QuestList" load_steps=4 format=3 uid="uid://bquest1listzz"]

[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_list.gd" id="1"]
[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_data.gd" id="2_qfc02"]
[ext_resource type="Resource" uid="uid://bqfillcore0001" path="res://resources/quests/q_fill_core.tres" id="3_qfc01"]

[resource]
script = ExtResource("1")
quests = Array[ExtResource("2_qfc02")]([ExtResource("3_qfc01")])
```

- [ ] **Step 4: Run the full test suite**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass, no `push_error` lines from `QuestManager._validate_catalog()`.

- [ ] **Step 5: Commit**

```bash
git add resources/quests/q_fill_core.tres resources/quests/q_fill_core.tres.uid resources/quests/quest_list.tres
git commit -m "feat(quests): add q_fill_core quest for Foundation Beat 1

Two-step quest:
  step 1: reach max Madra (condition: q_fill_core_madra_full)
  step 2: return to the NPC (event: wandering_spirit_dialogue_2)
Completion fires q_fill_core_completed via inline TriggerEvent
sub-resource, which gates the Adventure zone action.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Wire NPC 1 to start the quest (inline StartQuest sub-resource)

Append an inline StartQuest sub-resource to NPC 1's `success_effects`.

**Files:**
- Modify: `resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_1.tres`

- [ ] **Step 1: Append the inline StartQuest sub-resource**

Open in the Godot editor (recommended — the file mixes ExtResource + SubResource entries). Add a new StartQuestEffectData inline with `quest_id = "q_fill_core"`, and append it to the `success_effects` array.

If hand-editing, the modified file:

```
[gd_resource type="Resource" script_class="NpcDialogueActionData" format=3 uid="uid://c36o44atngp5e"]

[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="1_nm6h2"]
[ext_resource type="Script" uid="uid://10xqk22j564o" path="res://scripts/resource_definitions/zones/zone_action_data/npc_dialogue_action_data/npc_dialogue_action_data.gd" id="2_nm6h2"]
[ext_resource type="Resource" uid="uid://c701iqcrdgc7x" path="res://resources/effects/trigger_event/wandering_spirit_dialogue_1_trigger_event_effect.tres" id="2_ur7gj"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="3_ur7gj"]
[ext_resource type="Resource" uid="uid://bwpoorfeekkiu" path="res://resources/items/test_items/dagger.tres" id="4_pwpfl"]
[ext_resource type="Script" uid="uid://dbbopeowutwja" path="res://scripts/resource_definitions/effects/award_item_effect_data.gd" id="5_3o3qq"]
[ext_resource type="Script" path="res://scripts/resource_definitions/effects/start_quest_effect_data.gd" id="6_sqfc1"]

[sub_resource type="Resource" id="Resource_8j4wv"]
script = ExtResource("5_3o3qq")
item = ExtResource("4_pwpfl")
metadata/_custom_type_script = "uid://dbbopeowutwja"

[sub_resource type="Resource" id="Resource_start_quest"]
script = ExtResource("6_sqfc1")
effect_type = 5
quest_id = "q_fill_core"

[resource]
script = ExtResource("2_nm6h2")
dialogue_timeline_name = "wandering_spirit_1"
action_id = "wandering_spirit_dialogue_1"
action_name = "Talk to the Wisened Dirt Eel"
action_type = 2
description = "Talk to the Wisened Dirt Eel"
max_completions = 1
success_effects = Array[ExtResource("1_nm6h2")]([ExtResource("2_ur7gj"), SubResource("Resource_8j4wv"), SubResource("Resource_start_quest")])
metadata/_custom_type_script = "uid://10xqk22j564o"
```

Key additions vs the post-Task-0 file:
- New ExtResource id `6_sqfc1` → the `start_quest_effect_data.gd` script.
- New SubResource `Resource_start_quest` → inline StartQuest with `quest_id = "q_fill_core"` and `effect_type = 5` (START_QUEST).
- `success_effects` array grows to 3 entries.

- [ ] **Step 2: Commit**

```bash
git add resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_1.tres
git commit -m "feat(quests): wire q_fill_core start into NPC 1 dialogue

First wandering-spirit talk now starts q_fill_core (inline StartQuest
sub-resource) in addition to its existing trigger-event and
dagger-award effects.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Author NPC 2, its Dialogic timeline, and register it in the zone

Second zone action gated by `q_fill_core_madra_full` (sharing the same condition as quest step 1). TriggerEvent success-effect is an inline sub-resource.

**Files:**
- Create: `assets/dialogue/timelines/wandering_spirit_2.dtl`
- Create: `resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_2.tres`
- Modify: `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`

- [ ] **Step 1: Create the placeholder Dialogic timeline**

Create `assets/dialogue/timelines/wandering_spirit_2.dtl`:

```
[style=default]
The stranger nods as you approach. "Your core stirs. That is the first step. Now you must test yourself beyond this refuge — go and see what the world has become."
```

(One-line placeholder. If the renamed `wandering_spirit_1.dtl` uses different Dialogic syntax, mirror that format.)

- [ ] **Step 2: Create the NPC 2 zone action (with inline TriggerEvent)**

Create `resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_2.tres`:

```
[gd_resource type="Resource" script_class="NpcDialogueActionData" load_steps=6 format=3 uid="uid://cnpc2zact001"]

[ext_resource type="Script" uid="uid://10xqk22j564o" path="res://scripts/resource_definitions/zones/zone_action_data/npc_dialogue_action_data/npc_dialogue_action_data.gd" id="1_npc2a"]
[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="2_npc2a"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="3_npc2a"]
[ext_resource type="Script" uid="uid://cc0ky7w2fsg10" path="res://scripts/resource_definitions/effects/trigger_event_effect_data.gd" id="4_npc2a"]
[ext_resource type="Resource" uid="uid://bqfcmadrafull01" path="res://resources/unlocks/q_fill_core_madra_full.tres" id="5_npc2a"]

[sub_resource type="Resource" id="Resource_trigger_dialogue_2"]
script = ExtResource("4_npc2a")
event_id = "wandering_spirit_dialogue_2"
effect_type = 1
metadata/_custom_type_script = "uid://cc0ky7w2fsg10"

[resource]
script = ExtResource("1_npc2a")
dialogue_timeline_name = "wandering_spirit_2"
action_id = "wandering_spirit_dialogue_2"
action_name = "Return to the Wisened Dirt Eel"
action_type = 2
description = "Speak with the stranger again now that your core is full."
unlock_conditions = Array[ExtResource("3_npc2a")]([ExtResource("5_npc2a")])
max_completions = 1
success_effects = Array[ExtResource("2_npc2a")]([SubResource("Resource_trigger_dialogue_2")])
metadata/_custom_type_script = "uid://10xqk22j564o"
```

- [ ] **Step 3: Register NPC 2 in Spirit Valley**

Open `resources/zones/spirit_valley_zone/spirit_valley_zone.tres` in the Godot editor. Add `wandering_spirit_dialogue_2.tres` to the `all_actions` array. If hand-editing, add a new `ext_resource`:

```
[ext_resource type="Resource" uid="uid://cnpc2zact001" path="res://resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_2.tres" id="7_npc2z"]
```

…and the `all_actions` array becomes (5 entries — cycling, NPC 1, foraging, adventure, NPC 2):

```
all_actions = Array[ExtResource("1_gfpen")]([ExtResource("2_8fv6p"), ExtResource("2_4l7yp"), ExtResource("3_4l7yp"), ExtResource("6_owjyk"), ExtResource("7_npc2z")])
```

- [ ] **Step 4: Import**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

- [ ] **Step 5: Commit**

```bash
git add assets/dialogue/timelines/wandering_spirit_2.dtl assets/dialogue/timelines/wandering_spirit_2.dtl.uid resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_2.tres resources/zones/spirit_valley_zone/zone_actions/wandering_spirit_dialogue_2.tres.uid resources/zones/spirit_valley_zone/spirit_valley_zone.tres
git commit -m "feat(zones): add return-talk NPC action for Foundation Beat 1

Second wandering-spirit dialogue gated by q_fill_core_madra_full
(shared with quest step 1 — both semantics are 'player has once
filled their core'). Success effect is an inline TriggerEvent
sub-resource firing wandering_spirit_dialogue_2, which advances
q_fill_core step 2 and (via quest completion) triggers
q_fill_core_completed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Gate the three remaining zone actions

Add `unlock_conditions` to the non-NPC-1 zone actions so the Beat 1 starting state shows only the first NPC. Three `.tres` edits (cycling, adventure, foraging — mountain_top is gone), one commit.

**Files:**
- Modify: `resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres`
- Modify: `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres`
- Modify: `resources/zones/spirit_valley_zone/zone_actions/spring_forest_foraging_action.tres`

- [ ] **Step 1: Gate Wilderness Cycling behind NPC 1 talk**

Edit `wilderness_cycling_action.tres`:

```
[gd_resource type="Resource" script_class="CyclingActionData" load_steps=4 format=3 uid="uid://cfbgjcfudlc3i"]

[ext_resource type="Script" uid="uid://q70uw6l2p5qw" path="res://scripts/resource_definitions/zones/zone_action_data/cycling_action_data/cycling_action_data.gd" id="1_ptrbs"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="2_sl167"]
[ext_resource type="Resource" uid="uid://2ojw7sl0d3lp" path="res://resources/unlocks/wandering_spirit_dialogue_1.tres" id="3_npc1t"]

[resource]
script = ExtResource("1_ptrbs")
action_id = "wilderness_cycling_action"
action_name = "Wilderness Cycling"
action_type = 5
description = "Cycle in the wilderness"
unlock_conditions = Array[ExtResource("2_sl167")]([ExtResource("3_npc1t")])
metadata/_custom_type_script = "uid://q70uw6l2p5qw"
```

- [ ] **Step 2: Gate Adventure behind quest completion**

Edit `spirit_valley_adventure_action.tres`:

```
[gd_resource type="Resource" script_class="AdventureActionData" load_steps=7 format=3 uid="uid://bbpx8ls6tj2u"]

[ext_resource type="Script" uid="uid://cmmqjph50wohc" path="res://scripts/resource_definitions/zones/zone_action_data/adventure_action_data/adventure_action_data.gd" id="1_bedlk"]
[ext_resource type="Resource" uid="uid://b2erw55qd1wh7" path="res://resources/adventure/data/test_adventure_data.tres" id="1_v40qa"]
[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="2_8ideb"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="2_v40qa"]
[ext_resource type="Resource" uid="uid://vauqsrr78ccw" path="res://resources/effects/award_resource/award_madra_5_effect_data.tres" id="5_udarr"]
[ext_resource type="Resource" uid="uid://bqfillcorecomp1" path="res://resources/unlocks/q_fill_core_completed.tres" id="6_qfcgt"]

[resource]
script = ExtResource("1_bedlk")
adventure_data = ExtResource("1_v40qa")
time_limit_seconds = 300
action_id = "spirit_valley_adventure_action"
action_name = "Fight the Baddies!"
action_type = 1
description = "Come with me, Fight the Baddies"
unlock_conditions = Array[ExtResource("2_v40qa")]([ExtResource("6_qfcgt")])
success_effects = Array[ExtResource("2_8ideb")]([ExtResource("5_udarr")])
metadata/_custom_type_script = "uid://cmmqjph50wohc"
```

- [ ] **Step 3: Temp-gate Foraging behind quest completion**

Open `spring_forest_foraging_action.tres` in the Godot editor, set `unlock_conditions` to `[q_fill_core_completed.tres]`, preserve all other existing fields. This is a **temporary** gate — Foraging's real unlock belongs in whichever later beat introduces it.

- [ ] **Step 4: Verify the starting state**

Launch the Godot editor, delete the existing save, start a new game. Only the NPC 1 action should be visible in the Spirit Valley action list. If any other action is visible, re-check the unlock_conditions arrays.

- [ ] **Step 5: Commit**

```bash
git add resources/zones/spirit_valley_zone/zone_actions/wilderness_cycling_action.tres resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres resources/zones/spirit_valley_zone/zone_actions/spring_forest_foraging_action.tres
git commit -m "feat(zones): gate Spirit Valley actions for Foundation Beat 1

Beat 1 initial state: only Talk-to-NPC-1 visible. Wilderness Cycling
unlocks on NPC 1 talk; Adventure + Foraging unlock on q_fill_core
completion. Foraging uses q_fill_core_completed as a TEMPORARY gate —
real unlock belongs in a later beat plan.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Full playtest and verification

Manual end-to-end test of Beat 1. No code changes.

- [ ] **Step 1: Reset save and launch the game**

Delete any existing `user://save.tres`:
- Windows: `del "%APPDATA%\Godot\app_userdata\EndlessPath\save.tres"` (adjust project folder name if different)

Launch:
```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

- [ ] **Step 2: Verify Beat 1 flow**

- [ ] Starting Spirit Valley view shows exactly one zone action: **Talk to the Wisened Dirt Eel**.
- [ ] Wilderness Cycling, Adventure, Foraging, return-talk NPC are all NOT visible.
- [ ] Click NPC 1 → `wandering_spirit_1` timeline plays → returns to zone view.
- [ ] Wilderness Cycling is now visible.
- [ ] Quest tracker shows `q_fill_core` active with step 1 ("Fill your Madra by cycling").
- [ ] Cycling a few times fills the Madra bar. On reaching max:
  - Return-talk NPC becomes visible.
  - Quest step advances to 2 ("Return to the NPC").
- [ ] Click return-talk NPC → `wandering_spirit_2` timeline plays → returns to zone view.
- [ ] Quest completes.
- [ ] Adventure now visible (Foraging also becomes visible — expected, due to temp gate).
- [ ] Close the game, relaunch — all unlocks persist.

- [ ] **Step 3: If anything fails, debug and fix**

Common failure modes:

| Symptom | Likely cause | Fix |
|---|---|---|
| NPC 1 click does nothing new (quest doesn't start) | StartQuest sub-resource not in NPC 1's `success_effects`, or `effect_type` wrong | Re-check Task 4 |
| NPC 1 dialogue doesn't play | `dialogue_timeline_name` still says `spirit_valley` instead of `wandering_spirit_1` | Re-check Task 0 Step 1 |
| Cycling never unlocks after NPC 1 talk | Wilderness Cycling's `unlock_conditions` missing, or the renamed trigger-event effect isn't wired | Re-check Task 6 Step 1 + Task 0 Steps 1-3 |
| Madra reaching max does nothing | QuestManager listener missing, or `q_fill_core_madra_full` not in `unlock_condition_list.tres` | Re-run `test_quest_manager` suite; check Task 2 Step 4 |
| NPC 2 never appears | `q_fill_core_madra_full.tres` reference wrong in NPC 2's `unlock_conditions` | Re-check Task 5 Step 2 |
| Quest completes but Adventure stays hidden | Quest's inline completion TriggerEvent wrong, or Adventure's condition missing | Re-check Task 3 and Task 6 Step 2 |

- [ ] **Step 4: Push the branch**

If any debug edits landed during Step 3, commit them first. Then:

```bash
git push
```

---

## Out of scope (explicit non-goals)

- **NPC 1 dagger award.** Existing `AwardItemEffectData` on NPC 1 gives the player a dagger. Beat 1 design doesn't require it; Beat 2 is where first-loot is designed. Leave it.
- **Display-name rewrites.** "Wisened Dirt Eel" on NPC 1/2 and "Fight the Baddies!" on the adventure action are placeholder flavor. Rename when we decide on final names.
- **Madra bar UI gating.** The Madra bar is currently visible from the first frame. Beat 1 spec says NPC 1 "unlocks Madra bar UI," but since the bar is already in the HUD, no change is needed now. Future UX pass.
- **Real copy for the Dialogic timelines.** Placeholder text in `wandering_spirit_2.dtl` (and whatever is currently in `wandering_spirit_1.dtl`) — polish later.
- **Tuning `q_fill_core` step 1 difficulty.** Target: "2-4 cycles to fill Madra" (Section 3 Q-1 in the playthrough plan). This plan uses whatever values the current `CyclingManager` gives — tuning is a separate playtest pass.
- **Real unlock conditions for Foraging.** Task 6 uses `q_fill_core_completed` as a placeholder. Real unlock belongs in the plan for whichever later beat introduces it.
- **Quest UI polish.** Beat 1 relies on the existing quest tracker UI merged on main.

---

## Self-Review

**Spec coverage check** (against `docs/progression/FOUNDATION_PLAYTHROUGH.md` § Beat 1):

- [x] "Zone 1 initial state: one zone action available: Talk to [NPC]" → Task 6 gates all three remaining non-NPC-1 actions (after mountain_top removed in Task 0).
- [x] "Talk to NPC (first time) → Unlocks: Madra bar, Cycling zone action. Quest starts: q_fill_core" → Task 4 wires quest start into NPC 1; Task 6 Step 1 gates Wilderness Cycling behind the renamed NPC-1 trigger event. (Madra bar noted out-of-scope.)
- [x] "Quest step 1: Reach max Madra" → Task 3 step 1 (condition-based), Task 1 QuestManager listener, Task 2 `q_fill_core_madra_full` condition.
- [x] "Quest step 2: Return to [NPC]" → Task 3 step 2 (event-based) + Task 5 NPC 2 action firing the `wandering_spirit_dialogue_2` event.
- [x] "Player cycles 2-4 sessions" → Tuning noted out-of-scope; cycling works with current CyclingManager values.
- [x] "Talk to NPC (second time) → quest completes. Unlocks: Adventure" → Task 5 NPC 2 fires event → Task 3 step 2 advances → quest completes → Task 3 inline completion TriggerEvent fires `q_fill_core_completed` → Task 6 Step 2 gate unlocks Adventure.

**Placeholder check:**
- No "TBD" / "TODO" / "fill in details" inside task bodies.
- `.uid` values in new `.tres` files are invented strings; Godot will accept them or reassign on first import.
- `effect_type = 5` for StartQuest is explicit (EffectData.EffectType: NONE=0, TRIGGER_EVENT=1, AWARD_RESOURCE=2, AWARD_ITEM=3, AWARD_LOOT_TABLE=4, START_QUEST=5).
- `condition_type = 6` for RESOURCE_AMOUNT is explicit.

**Type consistency:**
- `q_fill_core` used as quest_id throughout (Tasks 3, 4).
- `q_fill_core_madra_full` used as condition_id in quest step 1 and NPC 2 unlock_conditions (Tasks 2, 3, 5).
- `q_fill_core_completed` used as event_id + condition_id consistently (Tasks 2, 3, 6).
- `wandering_spirit_dialogue_1` / `wandering_spirit_dialogue_2` used as action_id + event_id + (dialogue_1 only) condition_id consistently across Tasks 0, 3, 4, 5.
- Dialogic timeline names `wandering_spirit_1` / `wandering_spirit_2` consistent across Tasks 0, 4, 5.
- `wilderness_cycling_action` used as action_id + filename consistently (Tasks 0, 6).
- `spirit_valley_adventure_action` used as action_id + filename consistently (Tasks 0, 6).

**Task count:** 8 tasks (including Task 0 rename/removal prep), 0 new effect `.tres` files, 1 new signal listener in QuestManager.

Self-review complete. Plan is ready to execute.
