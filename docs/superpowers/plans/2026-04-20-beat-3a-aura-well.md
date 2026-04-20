# Beat 3a — Aura Well Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Beat 3a of the Foundation playthrough — the Aura Well is a special adventure encounter that lets the player rest and, on first visit, unlocks an Aura Well training zone action in Zone 1 that passively drips madra and grants Spirit attribute over time.

**Architecture:** Extend two existing resource classes (`UnlockConditionData.negate` for "available only while locked" choice gating; `ChangeVitalsEffectData` with body/foundation multipliers so Rest scales with character stats). Rename the existing `spirit_well_*` training resources to `aura_well_*`. Add the encounter resource + wiring into `shallow_woods.tres`.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.6.0. All data-driven via `.tres` resources.

**Spec:** [docs/superpowers/specs/2026-04-20-beat-3a-aura-well-design.md](../specs/2026-04-20-beat-3a-aura-well-design.md)

---

## File Structure

**Script changes (extend existing):**
- `scripts/resource_definitions/unlocks/unlock_condition_data.gd` — add `negate` field + refactor `evaluate()`.
- `scripts/resource_definitions/effects/change_vitals_effect_data.gd` — add `body_hp_multiplier`, `foundation_madra_multiplier` fields + expose pure-function getters for testability.

**New resources:**
- `resources/unlocks/aura_well_discovered.tres` — `EVENT_TRIGGERED` condition, `negate = false`.
- `resources/unlocks/aura_well_not_yet_discovered.tres` — `EVENT_TRIGGERED` condition, `negate = true`.
- `resources/adventure/encounters/special_encounters/aura_well_encounter.tres` — the encounter with two inline choices.

**Renamed resources (file move + internal id update):**
- `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres` → `aura_well_training_action.tres`
- `resources/zones/spirit_valley_zone/zone_actions/spirit_well_madra_trickle_effect.tres` → `aura_well_madra_trickle_effect.tres`
- `resources/zones/spirit_valley_zone/zone_actions/spirit_well_spirit_award_effect.tres` → `aura_well_spirit_award_effect.tres`

**Files referencing renamed resources (path/id updates):**
- `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`
- `resources/adventure/data/shallow_woods.tres` (add special pool wiring)
- `tests/unit/test_zone_progression_data.gd` (update `"spirit_well_training"` → `"aura_well_training"`)

**New test files:**
- `tests/unit/test_unlock_condition_negate.gd`
- `tests/unit/test_change_vitals_effect_data.gd`
- `tests/integration/test_aura_well_discovery_unlock.gd`

---

## Testing harness notes

- Tests extend `GutTest`.
- Run a single test: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_unlock_condition_negate.gd -gexit`
- Run all tests: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`
- To reset EventManager state in tests:
  ```gdscript
  func before_each() -> void:
      PersistenceManager.save_game_data = SaveGameData.new()
      PersistenceManager.save_data_reset.emit()
  ```
- `PlayerManager.vitals_manager` is null in unit tests — `ChangeVitalsEffectData.process()` already null-guards and logs. Tests assert on pure-function getters (added in Task 2), not on `process()` side effects.

---

## Task 1: Add `negate` field to `UnlockConditionData`

**Files:**
- Test: `tests/unit/test_unlock_condition_negate.gd` (create)
- Modify: `scripts/resource_definitions/unlocks/unlock_condition_data.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_unlock_condition_negate.gd`:

```gdscript
extends GutTest

func before_each() -> void:
    PersistenceManager.save_game_data = SaveGameData.new()
    PersistenceManager.save_data_reset.emit()

func _make_event_condition(event_id: String, negate: bool) -> UnlockConditionData:
    var c := UnlockConditionData.new()
    c.condition_id = "test_" + event_id
    c.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
    c.target_value = event_id
    c.negate = negate
    return c

func test_negate_false_returns_raw_result() -> void:
    var c: UnlockConditionData = _make_event_condition("e1", false)
    assert_false(c.evaluate(), "Event not triggered yet -> false")

    EventManager.trigger_event("e1")
    assert_true(c.evaluate(), "Event triggered -> true")

func test_negate_true_inverts_result() -> void:
    var c: UnlockConditionData = _make_event_condition("e2", true)
    assert_true(c.evaluate(), "Event not triggered yet, negated -> true")

    EventManager.trigger_event("e2")
    assert_false(c.evaluate(), "Event triggered, negated -> false")

func test_negate_defaults_to_false() -> void:
    var c := UnlockConditionData.new()
    assert_false(c.negate, "negate must default to false for backwards compatibility")
```

- [ ] **Step 2: Run test and verify it fails**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_unlock_condition_negate.gd -gexit
```

Expected: FAIL — `c.negate` property doesn't exist yet (test_negate_defaults_to_false fails first on property access; the other two may error out trying to set `negate`).

- [ ] **Step 3: Add `negate` field and refactor `evaluate()`**

Modify `scripts/resource_definitions/unlocks/unlock_condition_data.gd`:

Add field right after the other `@export` fields (around line 21):

```gdscript
@export var negate: bool = false
```

Replace the existing `evaluate()` function with:

```gdscript
func evaluate() -> bool:
    var result: bool = _evaluate_raw()
    return not result if negate else result

func _evaluate_raw() -> bool:
    # Evaluates condition against current game state via manager queries
    match condition_type:
        ConditionType.CULTIVATION_STAGE:
            var current_stage = CultivationManager.get_current_advancement_stage()
            return _compare_values(current_stage, target_value, comparison_op)

        ConditionType.CULTIVATION_LEVEL:
            var current_level = CultivationManager.get_core_density_level()
            return _compare_values(current_level, target_value, comparison_op)

        ConditionType.ZONE_UNLOCKED:
            Log.warn("UnlockConditionData: ZONE_UNLOCKED not yet implemented")
            return false

        ConditionType.ADVENTURE_COMPLETED:
            Log.warn("UnlockConditionData: ADVENTURE_COMPLETED not yet implemented")
            return false

        ConditionType.EVENT_TRIGGERED:
            if not EventManager:
                Log.error("UnlockConditionData: EventManager is not initialized")
                return false
            else:
                return EventManager.has_event_triggered(target_value)

        ConditionType.ITEM_OWNED:
            Log.warn("UnlockConditionData: ITEM_OWNED not yet implemented")
            return false

        ConditionType.RESOURCE_AMOUNT:
            var resource_type = optional_params.get("resource_type", "madra")
            var current_amount = 0.0
            if resource_type == "madra":
                current_amount = ResourceManager.get_madra()
            elif resource_type == "gold":
                current_amount = ResourceManager.get_gold()
            return _compare_values(current_amount, target_value, comparison_op)

        ConditionType.ATTRIBUTE_VALUE:
            var attribute_type: AttributeType = optional_params.get("attribute_type", AttributeType.STRENGTH)
            var current_value = CharacterManager.get_total_attributes_data().get_attribute(attribute_type)
            return _compare_values(current_value, target_value, comparison_op)

    return false
```

(Body of `_evaluate_raw()` is the existing body of `evaluate()`, unchanged.)

- [ ] **Step 4: Run test and verify it passes**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_unlock_condition_negate.gd -gexit
```

Expected: PASS (all 3 tests).

- [ ] **Step 5: Run the full test suite to confirm no regressions**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: All previously-passing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/unlocks/unlock_condition_data.gd tests/unit/test_unlock_condition_negate.gd
git commit -m "feat(unlocks): add negate flag to UnlockConditionData"
```

---

## Task 2: Add attribute multipliers to `ChangeVitalsEffectData`

**Files:**
- Test: `tests/unit/test_change_vitals_effect_data.gd` (create)
- Modify: `scripts/resource_definitions/effects/change_vitals_effect_data.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_change_vitals_effect_data.gd`:

```gdscript
extends GutTest

## Tests the pure-function getters on ChangeVitalsEffectData that compute
## final health/madra/stamina changes, including attribute-scaled contributions.
## Getters are used by process() when applying vitals changes — this avoids
## requiring a live VitalsManager in unit tests.

const AttributeType = CharacterAttributesData.AttributeType

var _effect: ChangeVitalsEffectData
var _original_save: SaveGameData

func before_each() -> void:
    _original_save = PersistenceManager.save_game_data
    PersistenceManager.save_game_data = SaveGameData.new()
    PersistenceManager.save_data_reset.emit()
    _effect = ChangeVitalsEffectData.new()

func after_each() -> void:
    PersistenceManager.save_game_data = _original_save
    PersistenceManager.save_data_reset.emit()

## Overwrites base attributes directly so `CharacterManager.get_total_attributes_data()`
## (which rebuilds from live_save_data + bonuses each call) reads these values.
func _set_attrs(body: float, foundation: float) -> void:
    var attrs: CharacterAttributesData = PersistenceManager.save_game_data.character_attributes
    attrs.attributes[AttributeType.BODY] = body
    attrs.attributes[AttributeType.FOUNDATION] = foundation

func test_flat_values_with_zero_multipliers() -> void:
    _set_attrs(10.0, 10.0)
    _effect.health_change = 5.0
    _effect.madra_change = 3.0
    _effect.stamina_change = 2.0
    _effect.body_hp_multiplier = 0.0
    _effect.foundation_madra_multiplier = 0.0

    assert_eq(_effect.get_final_health_change(), 5.0)
    assert_eq(_effect.get_final_madra_change(), 3.0)
    assert_eq(_effect.get_final_stamina_change(), 2.0)

func test_body_multiplier_scales_health() -> void:
    _set_attrs(10.0, 0.0)
    _effect.health_change = 0.0
    _effect.body_hp_multiplier = 5.0

    # 0 flat + 5 * BODY(10) = 50
    assert_eq(_effect.get_final_health_change(), 50.0)

func test_foundation_multiplier_scales_madra() -> void:
    _set_attrs(0.0, 10.0)
    _effect.madra_change = 0.0
    _effect.foundation_madra_multiplier = 2.0

    # 0 flat + 2 * FOUNDATION(10) = 20
    assert_eq(_effect.get_final_madra_change(), 20.0)

func test_flat_and_multiplier_combine() -> void:
    _set_attrs(4.0, 3.0)
    _effect.health_change = 2.0
    _effect.madra_change = 1.0
    _effect.body_hp_multiplier = 5.0
    _effect.foundation_madra_multiplier = 2.0

    # health: 2 + 5*4 = 22
    # madra:  1 + 2*3 = 7
    assert_eq(_effect.get_final_health_change(), 22.0)
    assert_eq(_effect.get_final_madra_change(), 7.0)

func test_stamina_is_never_scaled() -> void:
    _set_attrs(100.0, 100.0)
    _effect.stamina_change = 3.0
    assert_eq(_effect.get_final_stamina_change(), 3.0)

func test_multipliers_default_to_zero() -> void:
    assert_eq(_effect.body_hp_multiplier, 0.0)
    assert_eq(_effect.foundation_madra_multiplier, 0.0)
```

- [ ] **Step 2: Run test and verify it fails**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_change_vitals_effect_data.gd -gexit
```

Expected: FAIL — `body_hp_multiplier`, `foundation_madra_multiplier`, and `get_final_*` methods don't exist yet.

- [ ] **Step 3: Add multipliers and pure-function getters**

Replace the entire contents of `scripts/resource_definitions/effects/change_vitals_effect_data.gd` with:

```gdscript
class_name ChangeVitalsEffectData
extends EffectData

const AttributeType = CharacterAttributesData.AttributeType

@export var health_change: float = 0.0
@export var stamina_change: float = 0.0
@export var madra_change: float = 0.0

## Multiplies the character's BODY attribute and adds the result to health_change.
## Defaults to 0.0 so existing flat-value resources behave identically.
@export var body_hp_multiplier: float = 0.0

## Multiplies the character's FOUNDATION attribute and adds the result to madra_change.
## Defaults to 0.0 so existing flat-value resources behave identically.
@export var foundation_madra_multiplier: float = 0.0

func get_final_health_change() -> float:
    var body: float = CharacterManager.get_total_attributes_data().get_attribute(AttributeType.BODY)
    return health_change + body_hp_multiplier * body

func get_final_madra_change() -> float:
    var foundation: float = CharacterManager.get_total_attributes_data().get_attribute(AttributeType.FOUNDATION)
    return madra_change + foundation_madra_multiplier * foundation

func get_final_stamina_change() -> float:
    return stamina_change

func process() -> void:
    if PlayerManager.vitals_manager:
        PlayerManager.vitals_manager.apply_vitals_change(
            get_final_health_change(),
            get_final_stamina_change(),
            get_final_madra_change(),
        )
    else:
        Log.error("ChangeVitalsEffectData: No vitals manager found")

func _to_string() -> String:
    return "ChangeVitalsEffectData: {\n HealthChanged: %s, \n StaminaChanged: %s, \n MadraChanged: %s, \n BodyHPMul: %s, \n FoundationMadraMul: %s }" % [
        health_change, stamina_change, madra_change, body_hp_multiplier, foundation_madra_multiplier
    ]
```

- [ ] **Step 4: Run test and verify it passes**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_change_vitals_effect_data.gd -gexit
```

Expected: PASS (6 tests).

- [ ] **Step 5: Run full suite to confirm no regressions**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/effects/change_vitals_effect_data.gd tests/unit/test_change_vitals_effect_data.gd
git commit -m "feat(effects): add BODY/FOUNDATION multipliers to ChangeVitalsEffectData"
```

---

## Task 3: Rename `spirit_well_*` resources to `aura_well_*`

**Files:**
- Rename: `resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres` → `aura_well_training_action.tres`
- Rename: `resources/zones/spirit_valley_zone/zone_actions/spirit_well_madra_trickle_effect.tres` → `aura_well_madra_trickle_effect.tres`
- Rename: `resources/zones/spirit_valley_zone/zone_actions/spirit_well_spirit_award_effect.tres` → `aura_well_spirit_award_effect.tres`
- Modify: `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`
- Modify: `tests/unit/test_zone_progression_data.gd`

No .uid sidecar files exist for these resources (verified via glob), and the .tres files have no embedded `uid://` on their `[gd_resource]` line — so simple file renames plus path updates are sufficient.

- [ ] **Step 1: Rename the three .tres files**

```bash
git mv resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres \
        resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres
git mv resources/zones/spirit_valley_zone/zone_actions/spirit_well_madra_trickle_effect.tres \
        resources/zones/spirit_valley_zone/zone_actions/aura_well_madra_trickle_effect.tres
git mv resources/zones/spirit_valley_zone/zone_actions/spirit_well_spirit_award_effect.tres \
        resources/zones/spirit_valley_zone/zone_actions/aura_well_spirit_award_effect.tres
```

- [ ] **Step 2: Update internal fields and ExtResource paths in `aura_well_training_action.tres`**

Edit `resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres`:

Change the two ExtResource path lines (currently pointing at `spirit_well_*`):

```
[ext_resource type="Resource" path="res://resources/zones/spirit_valley_zone/zone_actions/aura_well_madra_trickle_effect.tres" id="5_madratk"]
[ext_resource type="Resource" path="res://resources/zones/spirit_valley_zone/zone_actions/aura_well_spirit_award_effect.tres" id="6_spiraw"]
```

Change the `action_id`, `action_name`, and `description` fields:

```
action_id = "aura_well_training"
action_name = "Aura Well"
description = "Sit at the Aura Well. Let the valley's aura steep into your bones."
```

- [ ] **Step 3: Update path reference in `spirit_valley_zone.tres`**

Edit `resources/zones/spirit_valley_zone/spirit_valley_zone.tres`. Change the line:

```
[ext_resource type="Resource" path="res://resources/zones/spirit_valley_zone/zone_actions/spirit_well_training_action.tres" id="7_spwtrain"]
```

to:

```
[ext_resource type="Resource" path="res://resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres" id="7_spwtrain"]
```

The `id="7_spwtrain"` can stay — it's only a local-scope id within the file. The `all_actions` array reference `ExtResource("7_spwtrain")` still resolves correctly.

- [ ] **Step 4: Update `tests/unit/test_zone_progression_data.gd`**

Replace every occurrence of `"spirit_well_training"` with `"aura_well_training"` in the file (9 occurrences on lines 9, 10, 15, 22, 45, 47, 50, 51, 52).

Use `Edit` with `replace_all = true` and `old_string = "spirit_well_training"`, `new_string = "aura_well_training"` to change them in one call.

- [ ] **Step 5: Confirm no stale references remain**

```bash
grep -r "spirit_well" --include="*.gd" --include="*.tres" .
```

Expected: **No matches** outside of `docs/` (old plans/specs are fine to keep as historical).

If any match is found outside `docs/`, update it to `aura_well` equivalently.

- [ ] **Step 6: Re-import the project to update Godot's cache**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: Clean import, no errors.

- [ ] **Step 7: Run the full test suite**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: All tests pass, including the updated `test_zone_progression_data.gd`.

- [ ] **Step 8: Commit**

```bash
git add resources/zones/spirit_valley_zone/ tests/unit/test_zone_progression_data.gd
git commit -m "refactor(zones): rename spirit_well -> aura_well training resources"
```

---

## Task 4: Create unlock-condition resources

**Files:**
- Create: `resources/unlocks/aura_well_discovered.tres`
- Create: `resources/unlocks/aura_well_not_yet_discovered.tres`

- [ ] **Step 1: Create `aura_well_discovered.tres`**

Create `resources/unlocks/aura_well_discovered.tres`:

```
[gd_resource type="Resource" script_class="UnlockConditionData" load_steps=2 format=3]

[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="1_unlock"]

[resource]
script = ExtResource("1_unlock")
condition_id = "aura_well_discovered"
condition_type = 4
target_value = "aura_well_discovered"
comparison_op = "=="
negate = false
metadata/_custom_type_script = "uid://bk5wuop0jogg4"
```

(`condition_type = 4` is `EVENT_TRIGGERED` per the enum order in `unlock_condition_data.gd`.)

- [ ] **Step 2: Create `aura_well_not_yet_discovered.tres`**

Create `resources/unlocks/aura_well_not_yet_discovered.tres`:

```
[gd_resource type="Resource" script_class="UnlockConditionData" load_steps=2 format=3]

[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="1_unlock"]

[resource]
script = ExtResource("1_unlock")
condition_id = "aura_well_not_yet_discovered"
condition_type = 4
target_value = "aura_well_discovered"
comparison_op = "=="
negate = true
metadata/_custom_type_script = "uid://bk5wuop0jogg4"
```

(Same `target_value` as discovered — the only difference is `negate = true`.)

- [ ] **Step 3: Verify resources load cleanly**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: No import errors.

- [ ] **Step 4: Commit**

```bash
git add resources/unlocks/aura_well_discovered.tres resources/unlocks/aura_well_not_yet_discovered.tres
git commit -m "feat(unlocks): add aura_well discovery conditions"
```

---

## Task 5: Wire the discovered condition into the Aura Well training action

**Files:**
- Modify: `resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres`
- Test: `tests/integration/test_aura_well_discovery_unlock.gd` (create)

- [ ] **Step 1: Write the failing integration test**

Create `tests/integration/test_aura_well_discovery_unlock.gd`:

```gdscript
extends GutTest

## Integration test: before the aura_well_discovered event fires, the Aura Well
## training action must NOT be in the available actions list for Spirit Valley.
## After the event fires, it must BE available.

const ZONE_ID: String = "SpiritValley"
const ACTION_ID: String = "aura_well_training"
const DISCOVERY_EVENT: String = "aura_well_discovered"

func before_each() -> void:
    PersistenceManager.save_game_data = SaveGameData.new()
    PersistenceManager.save_data_reset.emit()

func _has_aura_well_action() -> bool:
    var actions: Array = ZoneManager.get_available_actions(ZONE_ID)
    for a in actions:
        if a.action_id == ACTION_ID:
            return true
    return false

func test_aura_well_action_hidden_before_discovery() -> void:
    assert_false(_has_aura_well_action(), "Aura Well training must be gated before discovery event")

func test_aura_well_action_visible_after_discovery() -> void:
    EventManager.trigger_event(DISCOVERY_EVENT)
    assert_true(_has_aura_well_action(), "Aura Well training must be available after discovery event")
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_aura_well_discovery_unlock.gd -gexit
```

Expected: `test_aura_well_action_hidden_before_discovery` FAILS — the action currently has no unlock conditions, so it's always available.

- [ ] **Step 3: Wire the discovered condition into the training action**

Edit `resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres`.

Currently the file has no reference to `UnlockConditionData`. Add two new ExtResource lines in the header block (after the existing ExtResource lines, before `[resource]`):

```
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="7_ucd"]
[ext_resource type="Resource" path="res://resources/unlocks/aura_well_discovered.tres" id="8_discovered"]
```

In the `[resource]` block, replace:

```
unlock_conditions = []
```

with:

```
unlock_conditions = Array[ExtResource("7_ucd")]([ExtResource("8_discovered")])
```

The typed-array pattern matches existing usage — see `resources/zones/spirit_valley_zone/zone_actions/spirit_valley_adventure_action.tres` line 17 for a reference example.

- [ ] **Step 4: Re-import project**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: Clean import.

- [ ] **Step 5: Run the integration test and verify it passes**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_aura_well_discovery_unlock.gd -gexit
```

Expected: Both tests PASS.

- [ ] **Step 6: Run full suite**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add resources/zones/spirit_valley_zone/zone_actions/aura_well_training_action.tres tests/integration/test_aura_well_discovery_unlock.gd
git commit -m "feat(zones): gate aura_well training on discovered event"
```

---

## Task 6: Create the Aura Well encounter resource

**Files:**
- Create directory: `resources/adventure/encounters/special_encounters/`
- Create: `resources/adventure/encounters/special_encounters/aura_well_encounter.tres`

- [ ] **Step 1: Create the encounter resource**

Create `resources/adventure/encounters/special_encounters/aura_well_encounter.tres`. (No UID in the header — Godot will assign one at import time; path-based references resolve fine.)

```
[gd_resource type="Resource" script_class="AdventureEncounter" load_steps=9 format=3]

[ext_resource type="Script" uid="uid://cs335nesm7wfr" path="res://scripts/resource_definitions/adventure/encounters/adventure_encounter.gd" id="1_encounter"]
[ext_resource type="Script" uid="uid://c1b11mq3a2qya" path="res://scripts/resource_definitions/adventure/choices/encounter_choice.gd" id="2_choice"]
[ext_resource type="Script" uid="uid://cokj5uweh63tg" path="res://scripts/resource_definitions/effects/effect_data.gd" id="3_effect"]
[ext_resource type="Script" uid="uid://cesx0glx57xs4" path="res://scripts/resource_definitions/effects/change_vitals_effect_data.gd" id="4_vitals"]
[ext_resource type="Script" uid="uid://bk5wuop0jogg4" path="res://scripts/resource_definitions/unlocks/unlock_condition_data.gd" id="5_ucd"]
[ext_resource type="Script" path="res://scripts/resource_definitions/effects/trigger_event_effect_data.gd" id="6_trigger"]
[ext_resource type="Resource" path="res://resources/unlocks/aura_well_not_yet_discovered.tres" id="7_notyet"]

[sub_resource type="Resource" id="Resource_rest_effect"]
script = ExtResource("4_vitals")
health_change = 0.0
stamina_change = 0.0
madra_change = 0.0
body_hp_multiplier = 5.0
foundation_madra_multiplier = 2.0
metadata/_custom_type_script = "uid://cesx0glx57xs4"

[sub_resource type="Resource" id="Resource_trigger_event"]
script = ExtResource("6_trigger")
event_id = "aura_well_discovered"

[sub_resource type="Resource" id="Resource_rest_choice"]
script = ExtResource("2_choice")
label = "Rest"
tooltip = "Draw on the well's aura to restore yourself."
requirements = Array[ExtResource("5_ucd")]([])
success_effects = Array[ExtResource("3_effect")]([SubResource("Resource_rest_effect")])
failure_effects = Array[ExtResource("3_effect")]([])

[sub_resource type="Resource" id="Resource_mark_choice"]
script = ExtResource("2_choice")
label = "Mark down the location"
tooltip = "Commit the well's site to memory so you can find your way back."
requirements = Array[ExtResource("5_ucd")]([ExtResource("7_notyet")])
success_effects = Array[ExtResource("3_effect")]([SubResource("Resource_rest_effect"), SubResource("Resource_trigger_event")])
failure_effects = Array[ExtResource("3_effect")]([])

[resource]
script = ExtResource("1_encounter")
encounter_id = "aura_well"
encounter_name = "Aura Well"
description = "A spring of pale light wells up between the roots. The air here is thick with aura."
text_description_completed = "The aura here still thrums. You could rest, or continue on."
choices = Array[ExtResource("2_choice")]([SubResource("Resource_rest_choice"), SubResource("Resource_mark_choice")])
encounter_type = 4
metadata/_custom_type_script = "uid://cs335nesm7wfr"
```

(`encounter_type = 4` is `REST_SITE` — reuses the existing icon per spec.)

- [ ] **Step 2: Verify `trigger_event_effect_data.gd` has an `event_id` field**

Read `scripts/resource_definitions/effects/trigger_event_effect_data.gd`. Confirm it has an `@export var event_id: String` (or equivalent). If the field name differs, update the `event_id = "aura_well_discovered"` line in the encounter resource above to match.

- [ ] **Step 3: Re-import and confirm resource loads**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: Clean import.

- [ ] **Step 4: Commit**

```bash
git add resources/adventure/encounters/special_encounters/
git commit -m "feat(adventure): add aura_well encounter with rest/mark choices"
```

---

## Task 7: Wire the encounter into `shallow_woods.tres`

**Files:**
- Modify: `resources/adventure/data/shallow_woods.tres`

- [ ] **Step 1: Add ExtResource reference and populate special pool**

Edit `resources/adventure/data/shallow_woods.tres`.

Add a new ExtResource line alongside the existing ones (before `[sub_resource ...]`):

```
[ext_resource type="Resource" path="res://resources/adventure/encounters/special_encounters/aura_well_encounter.tres" id="9_aurawell"]
```

(No `uid=` attribute — resolves by path. If Godot later auto-adds one at import, that's fine.)

In the `[resource]` block, add two new fields (place them near `path_encounter_pool`):

```
num_special_tiles = 1
special_encounter_pool = Array[ExtResource("6_mnoah")]([ExtResource("9_aurawell")])
```

(`ExtResource("6_mnoah")` is the `AdventureEncounter` script reference already declared in the file — it's the typing for the array. Confirm by reading the file first; the typing id may differ.)

- [ ] **Step 2: Re-import project**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: Clean import.

- [ ] **Step 3: Run full suite**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add resources/adventure/data/shallow_woods.tres
git commit -m "feat(adventure): place aura_well in shallow_woods special pool"
```

---

## Task 8: Manual playtest verification

Not a code task — a verification gate before handing the feature off. Run the game and walk through the player flow.

- [ ] **Step 1: Launch the game**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

- [ ] **Step 2: Confirm Aura Well zone action is hidden in Zone 1 on a fresh save**

Start a new game (if needed, delete `user://save.tres` first, or use the in-game new-game flow). In Spirit Valley, confirm there is NO "Aura Well" zone-action button.

- [ ] **Step 3: Enter a `shallow_woods` adventure and reach the Aura Well tile**

You may need to play through normally to unlock adventures. When on an adventure map, look for the special tile (rest-site icon). Walk onto it.

- [ ] **Step 4: Confirm both choices show on first visit**

- "Rest" button — available.
- "Mark down the location" button — available.

- [ ] **Step 5: Pick "Mark down the location"**

- HP and Madra should visibly increase (by `5 × BODY` and `2 × FOUNDATION` respectively — confirm the bars move).
- Return to Zone 1. Confirm an **"Aura Well"** zone-action button now appears.

- [ ] **Step 6: Re-enter an adventure and revisit the Aura Well**

- On the tile, the "Mark down the location" button must be **grayed / unavailable** (requirement unmet — condition evaluates to `false` once negated).
- "Rest" remains selectable.

- [ ] **Step 7: Select the Aura Well zone action in Zone 1**

- Training should tick. Madra bar should climb by `+1.5` per tick.
- After 60 ticks (~60s), Spirit attribute should increment by 1 in the character sheet.

- [ ] **Step 8: Note any UX issues to follow up on**

Beat 3a is considered shipped when Steps 2-7 all behave correctly. Open follow-up tasks for any UX issues (e.g., if "Mark" being grayed feels wrong, revisit the full-hide follow-up listed in the spec).

---

## Self-Review Notes

- **Spec coverage:** §1 goal (player flow) covered by Tasks 5–8. §3.1 (negate) → Task 1. §3.2 (multipliers) → Task 2. §4.1 (renames) → Task 3. §4.2 (unlock conditions) → Task 4. §4.3 (encounter + choices) → Task 6. §4.4 (map wiring) → Task 7. §5 (tests) → covered by TDD steps in Tasks 1, 2, 5 (unit + integration).
- **Out of scope (per spec §6):** Beat 3b, FOUNDATION_PLAYTHROUGH doc corrections, dedicated `AURA_WELL` icon type, `hide_when_unavailable` full-hide flag. Not planned here.
- **Placeholder check:** No TBD/TODO in the plan; every step shows actual code or an exact command.
- **Type consistency:** `body_hp_multiplier`, `foundation_madra_multiplier`, `get_final_health_change()`, `get_final_madra_change()`, `get_final_stamina_change()` are introduced in Task 2 and used consistently in Tasks 2 and 6. `UnlockConditionData.negate` introduced in Task 1 and referenced in Task 4. Encounter field names (`encounter_id`, `encounter_name`, `description`, `text_description_completed`, `choices`, `encounter_type`) match `adventure_encounter.gd` exactly.
