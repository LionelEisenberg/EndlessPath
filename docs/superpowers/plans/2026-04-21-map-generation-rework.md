# Map Generation Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `AdventureMapGenerator` with a quota-keyed algorithm that specifies encounter counts per encounter resource, keeps rest/treasure tiles away from origin with guaranteed fillers on path, adds branching via extra graph edges, validates configs up front, and cannot infinite-loop on over-specified fillers.

**Architecture:** Data-driven: each `AdventureEncounter` declares its own placement strategy (`ANCHOR`/`FILLER`), distance constraints, and critical-path requirements. `AdventureData` replaces paired pool+count fields with a single `Array[EncounterQuota]`. Generator runs four phases (scatter anchors → MST + extra edges → fill path tiles → validate critical paths w/ regeneration) with upfront `validate()` gating.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.6.0 for tests. Custom `HexagonTileMapLayer` addon for hex math (`cube_distance`, `cube_linedraw`).

**Spec:** [docs/superpowers/specs/2026-04-21-map-generation-rework-design.md](../specs/2026-04-21-map-generation-rework-design.md)

---

## Task order and file impact

| # | Task | Files touched |
|---|------|---------------|
| 1 | `AdventureEncounter` schema + `is_eligible()` | encounter script + new test |
| 2 | `EncounterQuota` resource | new script + new test |
| 3 | `AdventureData` additions (non-breaking) + `validate()` | data script + new test |
| 4 | Migrate shipped content to populate new fields (keep old fields intact) | 1 new `.tres`, 4 modified `.tres` |
| 5 | Rewrite `AdventureMapGenerator` (all 4 phases) + migrate filter test | generator + existing filter test + new generator test |
| 6 | Remove old fields and dead code | encounter script, data script, generator, `shallow_woods.tres` |

Each task is independently committable; the game remains playable after each.

---

## Task 1: `AdventureEncounter` schema + `is_eligible()`

**Files:**
- Modify: `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd`
- Create: `tests/unit/test_adventure_encounter.gd`

- [ ] **Step 1: Write failing test for placement enum defaults and `is_eligible`**

Create `tests/unit/test_adventure_encounter.gd`:

```gdscript
extends GutTest

## Covers new schema fields (Placement, min_distance_from_origin,
## min_fillers_on_path) and the is_eligible() helper.

const TEST_EVENT: String = "test_adv_encounter_event"

func before_each() -> void:
    PersistenceManager.save_game_data = SaveGameData.new()
    PersistenceManager.save_data_reset.emit()

func test_defaults() -> void:
    var enc := AdventureEncounter.new()
    assert_eq(enc.placement, AdventureEncounter.Placement.FILLER, "placement defaults to FILLER")
    assert_eq(enc.min_distance_from_origin, 0, "min_distance_from_origin defaults to 0")
    assert_eq(enc.min_fillers_on_path, 0, "min_fillers_on_path defaults to 0")

func test_is_eligible_with_no_conditions() -> void:
    var enc := AdventureEncounter.new()
    assert_true(enc.is_eligible(), "encounter with no unlock_conditions is always eligible")

func test_is_eligible_blocks_when_event_required_but_not_fired() -> void:
    var cond := UnlockConditionData.new()
    cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
    cond.target_value = TEST_EVENT
    var enc := AdventureEncounter.new()
    enc.unlock_conditions = {cond: true}
    assert_false(enc.is_eligible(), "encounter should be ineligible before event fires")

func test_is_eligible_passes_when_event_required_and_fired() -> void:
    EventManager.trigger_event(TEST_EVENT)
    var cond := UnlockConditionData.new()
    cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
    cond.target_value = TEST_EVENT
    var enc := AdventureEncounter.new()
    enc.unlock_conditions = {cond: true}
    assert_true(enc.is_eligible(), "encounter should be eligible once event fires")

func test_is_eligible_respects_expected_false() -> void:
    var cond := UnlockConditionData.new()
    cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
    cond.target_value = "never_fired_event_for_enc_test"
    var enc := AdventureEncounter.new()
    # Require the event to NOT have fired.
    enc.unlock_conditions = {cond: false}
    assert_true(enc.is_eligible(), "expected=false condition passes when event has not fired")

    EventManager.trigger_event("never_fired_event_for_enc_test")
    assert_false(enc.is_eligible(), "expected=false condition fails after event fires")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gselect=test_adventure_encounter.gd -gexit
```

Expected: parse errors on `AdventureEncounter.Placement`, `placement`, `min_distance_from_origin`, `min_fillers_on_path`, and `is_eligible`.

- [ ] **Step 3: Add enum and fields to `AdventureEncounter`**

Edit `scripts/resource_definitions/adventure/encounters/adventure_encounter.gd`. Inside the `ENUMS` section below `EncounterType`, add:

```gdscript
enum Placement {
    ANCHOR, # Scattered first with sparse_factor + min_distance_from_origin
    FILLER, # Placed on NoOp path tiles after MST is built
}
```

Inside `EXPORTED PROPERTIES`, below the existing `unlock_conditions` declaration, add:

```gdscript
## Placement strategy used by the map generator.
@export var placement: Placement = Placement.FILLER

## Minimum hex distance from origin for placement. 0 = no constraint.
@export var min_distance_from_origin: int = 0

## Minimum number of FILLER-placement encounters that must sit on the
## shortest path from origin to this tile. 0 = no constraint.
@export var min_fillers_on_path: int = 0
```

- [ ] **Step 4: Add `is_eligible()` method**

Append to `adventure_encounter.gd` (after `_to_string`):

```gdscript
#-----------------------------------------------------------------------------
# ELIGIBILITY
#-----------------------------------------------------------------------------

## Returns true when all unlock_conditions evaluate to their expected bool.
## Encounters with no unlock_conditions are always eligible.
func is_eligible() -> bool:
    for condition in unlock_conditions:
        if condition.evaluate() != unlock_conditions[condition]:
            return false
    return true
```

- [ ] **Step 5: Run test to verify it passes**

Run the same command as Step 2.

Expected: all 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/adventure/encounters/adventure_encounter.gd tests/unit/test_adventure_encounter.gd
git commit -m "feat(adventure): add Placement enum and is_eligible to AdventureEncounter"
```

---

## Task 2: `EncounterQuota` resource

**Files:**
- Create: `scripts/resource_definitions/adventure/encounter_quota.gd`
- Create: `tests/unit/test_encounter_quota.gd`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_encounter_quota.gd`:

```gdscript
extends GutTest

func test_defaults() -> void:
    var quota := EncounterQuota.new()
    assert_null(quota.encounter, "encounter defaults to null")
    assert_eq(quota.count, 1, "count defaults to 1")

func test_holds_encounter_reference() -> void:
    var enc := AdventureEncounter.new()
    enc.encounter_id = "test_quota_enc"
    var quota := EncounterQuota.new()
    quota.encounter = enc
    quota.count = 3
    assert_eq(quota.encounter.encounter_id, "test_quota_enc")
    assert_eq(quota.count, 3)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gselect=test_encounter_quota.gd -gexit
```

Expected: parse error — `EncounterQuota` class not found.

- [ ] **Step 3: Create the resource**

Create `scripts/resource_definitions/adventure/encounter_quota.gd`:

```gdscript
class_name EncounterQuota
extends Resource

## Specifies how many instances of a specific AdventureEncounter
## should be placed in a generated adventure map.

@export var encounter: AdventureEncounter
@export var count: int = 1
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2.

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/resource_definitions/adventure/encounter_quota.gd tests/unit/test_encounter_quota.gd
git commit -m "feat(adventure): add EncounterQuota resource"
```

---

## Task 3: `AdventureData` additions + `validate()`

**Files:**
- Modify: `scripts/resource_definitions/adventure/adventure_data.gd`
- Create: `tests/unit/test_adventure_data.gd`

New fields are additive — old fields remain untouched so existing `shallow_woods.tres` continues loading and the current generator keeps working until Task 5.

- [ ] **Step 1: Write failing tests**

Create `tests/unit/test_adventure_data.gd`:

```gdscript
extends GutTest

## Covers AdventureData validate() — each error branch + the happy path.

func _make_anchor(id: String, min_dist: int = 0, min_fillers: int = 0) -> AdventureEncounter:
    var enc := AdventureEncounter.new()
    enc.encounter_id = id
    enc.placement = AdventureEncounter.Placement.ANCHOR
    enc.min_distance_from_origin = min_dist
    enc.min_fillers_on_path = min_fillers
    return enc

func _make_filler(id: String) -> AdventureEncounter:
    var enc := AdventureEncounter.new()
    enc.encounter_id = id
    enc.placement = AdventureEncounter.Placement.FILLER
    return enc

func _make_quota(enc: AdventureEncounter, count: int) -> EncounterQuota:
    var q := EncounterQuota.new()
    q.encounter = enc
    q.count = count
    return q

func _make_valid_data() -> AdventureData:
    var data := AdventureData.new()
    data.max_distance_from_start = 6
    data.sparse_factor = 2
    data.boss_encounter = _make_anchor("boss", 5)
    data.encounter_quotas = [
        _make_quota(_make_anchor("rest", 3, 1), 1),
        _make_quota(_make_filler("combat"), 3),
    ]
    return data

func test_valid_config_returns_empty_errors() -> void:
    var data := _make_valid_data()
    assert_eq(data.validate(), [], "well-formed config should produce no errors")

func test_missing_boss_is_error() -> void:
    var data := _make_valid_data()
    data.boss_encounter = null
    var errors := data.validate()
    assert_true(errors.size() >= 1)
    assert_string_contains(errors[0], "boss_encounter")

func test_boss_without_anchor_placement_is_error() -> void:
    var data := _make_valid_data()
    data.boss_encounter.placement = AdventureEncounter.Placement.FILLER
    var errors := data.validate()
    assert_true(errors.any(func(e): return e.contains("ANCHOR")))

func test_null_encounter_in_quota_is_error() -> void:
    var data := _make_valid_data()
    var bad := EncounterQuota.new()
    bad.count = 1
    data.encounter_quotas.append(bad)
    var errors := data.validate()
    assert_true(errors.any(func(e): return e.contains("null encounter")))

func test_non_positive_count_is_error() -> void:
    var data := _make_valid_data()
    data.encounter_quotas[0].count = 0
    var errors := data.validate()
    assert_true(errors.any(func(e): return e.contains("non-positive count")))

func test_min_distance_exceeds_max_is_error() -> void:
    var data := _make_valid_data()
    data.encounter_quotas[0].encounter.min_distance_from_origin = 10 # > max_distance_from_start = 6
    var errors := data.validate()
    assert_true(errors.any(func(e): return e.contains("exceeds max_distance_from_start")))

func test_min_fillers_without_filler_quota_is_error() -> void:
    var data := AdventureData.new()
    data.max_distance_from_start = 6
    data.sparse_factor = 2
    data.boss_encounter = _make_anchor("boss", 5)
    # Anchor requires fillers on path, but no FILLER quota present.
    data.encounter_quotas = [
        _make_quota(_make_anchor("rest_needs_filler", 3, 1), 1),
    ]
    var errors := data.validate()
    assert_true(errors.any(func(e): return e.contains("no FILLER entries")))

func test_filler_quota_below_required_count_is_error() -> void:
    var data := AdventureData.new()
    data.max_distance_from_start = 6
    data.sparse_factor = 2
    data.boss_encounter = _make_anchor("boss", 5)
    # Rest requires 3 fillers on path; filler quota totals 2.
    data.encounter_quotas = [
        _make_quota(_make_anchor("rest_requires_3", 3, 3), 1),
        _make_quota(_make_filler("combat"), 2),
    ]
    var errors := data.validate()
    assert_true(errors.any(func(e): return e.contains("only")))

func test_shipped_adventures_validate() -> void:
    var dir := DirAccess.open("res://resources/adventure/data/")
    assert_not_null(dir, "res://resources/adventure/data/ should exist")
    dir.list_dir_begin()
    var file_name := dir.get_next()
    var any_loaded := false
    while file_name != "":
        if file_name.ends_with(".tres"):
            any_loaded = true
            var data: AdventureData = load("res://resources/adventure/data/" + file_name)
            assert_not_null(data, "failed to load %s" % file_name)
            var errors := data.validate()
            assert_eq(errors, [], "%s produced errors: %s" % [file_name, errors])
        file_name = dir.get_next()
    dir.list_dir_end()
    assert_true(any_loaded, "expected at least one adventure .tres to exist")
```

> **Note:** `test_shipped_adventures_validate` will fail until Task 4 migrates `shallow_woods.tres` to the new schema. That's expected. The remaining eight tests should pass after Step 3 here.

- [ ] **Step 2: Run tests to verify failures**

Run:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gselect=test_adventure_data.gd -gexit
```

Expected: parse errors — `validate`, `encounter_quotas`, `num_extra_edges` not yet defined.

- [ ] **Step 3: Add new exports and `validate()`**

Edit `scripts/resource_definitions/adventure/adventure_data.gd`. Below the existing `num_path_encounters` line (inside `@export_group("Encounter Parameters")`), add:

```gdscript
## Number of non-MST edges added for path branching. 0 = pure MST.
@export var num_extra_edges: int = 2

## Per-encounter instance counts used by the new generator.
## Replaces special_encounter_pool / path_encounter_pool / num_special_tiles / num_path_encounters.
@export var encounter_quotas: Array[EncounterQuota] = []
```

Append to the end of the file:

```gdscript
#-----------------------------------------------------------------------------
# VALIDATION
#-----------------------------------------------------------------------------

## Returns a list of human-readable config errors. Empty array = valid.
## Called by AdventureMapGenerator before generation; also run by the
## test suite against every shipped .tres.
func validate() -> Array[String]:
    var errors: Array[String] = []

    if boss_encounter == null:
        errors.append("boss_encounter is not set")
    elif boss_encounter.placement != AdventureEncounter.Placement.ANCHOR:
        errors.append("boss_encounter must have placement = ANCHOR")
    elif boss_encounter.min_distance_from_origin > max_distance_from_start:
        errors.append("boss_encounter.min_distance_from_origin exceeds max_distance_from_start")

    var has_filler_quota: bool = false
    var total_filler_count: int = 0

    for i in range(encounter_quotas.size()):
        var quota: EncounterQuota = encounter_quotas[i]
        if quota == null or quota.encounter == null:
            errors.append("encounter_quotas[%d] has null encounter" % i)
            continue
        if quota.count <= 0:
            errors.append("encounter_quotas[%d] (%s) has non-positive count" % [i, quota.encounter.encounter_id])
            continue
        if quota.encounter.min_distance_from_origin > max_distance_from_start:
            errors.append("%s.min_distance_from_origin exceeds max_distance_from_start" % quota.encounter.encounter_id)
        if quota.encounter.placement == AdventureEncounter.Placement.FILLER:
            has_filler_quota = true
            total_filler_count += quota.count

    for quota in encounter_quotas:
        if quota == null or quota.encounter == null:
            continue
        if quota.encounter.min_fillers_on_path > 0:
            if not has_filler_quota:
                errors.append("encounter %s requires fillers on path but quotas contain no FILLER entries" % quota.encounter.encounter_id)
            elif total_filler_count < quota.encounter.min_fillers_on_path:
                errors.append("encounter %s requires %d fillers on path but only %d are quota'd" % [
                    quota.encounter.encounter_id,
                    quota.encounter.min_fillers_on_path,
                    total_filler_count,
                ])

    return errors
```

- [ ] **Step 4: Run tests — expect 8 of 9 pass**

Same command as Step 2.

Expected: 8 passing. `test_shipped_adventures_validate` fails because `shallow_woods.tres` has no `encounter_quotas` yet. Task 4 will fix that.

- [ ] **Step 5: Commit**

```bash
git add scripts/resource_definitions/adventure/adventure_data.gd tests/unit/test_adventure_data.gd
git commit -m "feat(adventure): add encounter_quotas and validate() to AdventureData"
```

---

## Task 4: Migrate shipped content

**Files:**
- Create: `resources/adventure/encounters/combat_encounters/amorphous_spirit_boss.tres`
- Modify: `resources/adventure/encounters/combat_encounters/amorphous_spirit_encounter.tres`
- Modify: `resources/adventure/encounters/combat_encounters/starving_dreadbeast_encounter.tres`
- Modify: `resources/adventure/encounters/special_encounters/aura_well_encounter.tres`
- Modify: `resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres`
- Modify: `resources/adventure/data/shallow_woods.tres`

The old generator still runs after this task — we leave the old pool fields (`special_encounter_pool`, `path_encounter_pool`, `num_path_encounters`) intact and populate new fields alongside. Task 5 swaps the generator; Task 6 deletes the old fields.

- [ ] **Step 1: Create `amorphous_spirit_boss.tres`**

Copy `resources/adventure/encounters/combat_encounters/amorphous_spirit_encounter.tres` contents and adapt. Create `resources/adventure/encounters/combat_encounters/amorphous_spirit_boss.tres`:

```
[gd_resource type="Resource" script_class="AdventureEncounter" format=3]

[ext_resource type="Script" uid="uid://c1b11mq3a2qya" path="res://scripts/resource_definitions/adventure/choices/encounter_choice.gd" id="1_qdmh0"]
[ext_resource type="Script" uid="uid://hbo1w3358rom" path="res://scripts/resource_definitions/combat/combatant_data.gd" id="2_bhcea"]
[ext_resource type="Resource" uid="uid://b4jn343ifh3vd" path="res://resources/combat/combatant_data/amorphous_spirit.tres" id="3_7ovbm"]
[ext_resource type="Script" uid="uid://cpq8eacgl1537" path="res://scripts/resource_definitions/adventure/choices/combat_choice.gd" id="6_b3sbp"]
[ext_resource type="Script" uid="uid://cs335nesm7wfr" path="res://scripts/resource_definitions/adventure/encounters/adventure_encounter.gd" id="7_sptof"]

[sub_resource type="Resource" id="Resource_boss_choice"]
script = ExtResource("6_b3sbp")
enemy_pool = Array[ExtResource("2_bhcea")]([ExtResource("3_7ovbm")])
is_boss = true
label = "Confront the Boss"
metadata/_custom_type_script = "uid://cpq8eacgl1537"

[resource]
script = ExtResource("7_sptof")
encounter_id = "amorphous_spirit_boss"
encounter_name = "Elder Amorphous Spirit"
description = "A larger, more coherent spirit looms before you. This one will not yield easily."
text_description_completed = "With the elder spirit dispelled, the woods feel quieter."
choices = Array[ExtResource("1_qdmh0")]([SubResource("Resource_boss_choice")])
encounter_type = 2
placement = 0
min_distance_from_origin = 5
metadata/_custom_type_script = "uid://cs335nesm7wfr"
```

Notes:
- `encounter_type = 2` is `COMBAT_BOSS`.
- `placement = 0` is `Placement.ANCHOR` (enum value).
- `is_boss = true` on the choice enables boss combat framing in existing code.
- No explicit `uid://...` in the gd_resource header; Godot will generate one on first import. The `chore(import)` sidecar step is handled at commit time.

- [ ] **Step 2: Add placement fields to the filler and anchor encounters**

Edit `resources/adventure/encounters/combat_encounters/amorphous_spirit_encounter.tres`. In the `[resource]` block (after `encounter_type = 0`), add:

```
placement = 1
min_distance_from_origin = 0
min_fillers_on_path = 0
```

`placement = 1` is `Placement.FILLER`.

Edit `resources/adventure/encounters/combat_encounters/starving_dreadbeast_encounter.tres`. Add the same three lines to its `[resource]` block.

Edit `resources/adventure/encounters/special_encounters/aura_well_encounter.tres`. In the `[resource]` block, after `encounter_type = 4`, add:

```
placement = 0
min_distance_from_origin = 3
min_fillers_on_path = 1
```

Edit `resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres`. Same three lines (placement = 0, min_distance_from_origin = 3, min_fillers_on_path = 1) added after its encounter_type line.

- [ ] **Step 3: Migrate `shallow_woods.tres`**

Replace contents of `resources/adventure/data/shallow_woods.tres` with:

```
[gd_resource type="Resource" script_class="AdventureData" format=3 uid="uid://b2erw55qd1wh7"]

[ext_resource type="Script" uid="uid://cs335nesm7wfr" path="res://scripts/resource_definitions/adventure/encounters/adventure_encounter.gd" id="6_mnoah"]
[ext_resource type="Resource" uid="uid://c7s6suad328qd" path="res://resources/adventure/encounters/combat_encounters/amorphous_spirit_encounter.tres" id="7_r4hwa"]
[ext_resource type="Script" uid="uid://b4nlsemiwg2h6" path="res://scripts/resource_definitions/adventure/adventure_data.gd" id="8_2dkfl"]
[ext_resource type="Resource" uid="uid://dquwaod5rj70m" path="res://resources/adventure/encounters/combat_encounters/starving_dreadbeast_encounter.tres" id="8_pkd7m"]
[ext_resource type="Resource" uid="uid://c6sihdrapbcl" path="res://resources/adventure/encounters/special_encounters/aura_well_encounter.tres" id="9_aurawell"]
[ext_resource type="Resource" uid="uid://bdtjfqv318ovi" path="res://resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres" id="10_refcamp"]
[ext_resource type="Resource" path="res://resources/adventure/encounters/combat_encounters/amorphous_spirit_boss.tres" id="11_boss"]
[ext_resource type="Script" path="res://scripts/resource_definitions/adventure/encounter_quota.gd" id="12_quota"]

[sub_resource type="Resource" id="Resource_quota_aura"]
script = ExtResource("12_quota")
encounter = ExtResource("9_aurawell")
count = 1

[sub_resource type="Resource" id="Resource_quota_refugee"]
script = ExtResource("12_quota")
encounter = ExtResource("10_refcamp")
count = 1

[sub_resource type="Resource" id="Resource_quota_dreadbeast"]
script = ExtResource("12_quota")
encounter = ExtResource("8_pkd7m")
count = 3

[sub_resource type="Resource" id="Resource_quota_amorphous"]
script = ExtResource("12_quota")
encounter = ExtResource("7_r4hwa")
count = 4

[resource]
script = ExtResource("8_2dkfl")
adventure_id = "shallow_woods"
adventure_name = "The Shallow Woods"
num_path_encounters = 8
num_extra_edges = 2
boss_encounter = ExtResource("11_boss")
special_encounter_pool = Array[ExtResource("6_mnoah")]([ExtResource("9_aurawell"), ExtResource("10_refcamp")])
path_encounter_pool = Array[ExtResource("6_mnoah")]([ExtResource("8_pkd7m"), ExtResource("7_r4hwa")])
encounter_quotas = Array[ExtResource("12_quota")]([
    SubResource("Resource_quota_aura"),
    SubResource("Resource_quota_refugee"),
    SubResource("Resource_quota_dreadbeast"),
    SubResource("Resource_quota_amorphous"),
])
metadata/_custom_type_script = "uid://b4nlsemiwg2h6"
```

Notes:
- Old `special_encounter_pool` and `path_encounter_pool` remain for Task 5 compatibility; they're removed in Task 6.
- Boss now points to the new `amorphous_spirit_boss.tres` instead of the filler variant.

- [ ] **Step 4: Import assets (refreshes `.uid` sidecars for new `.tres`)**

Run:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: import completes without errors. A new `.uid` sidecar appears for `amorphous_spirit_boss.tres`.

- [ ] **Step 5: Run tests to verify shipped-data test now passes**

Run:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gselect=test_adventure_data.gd -gexit
```

Expected: all 9 tests pass, including `test_shipped_adventures_validate`.

- [ ] **Step 6: Commit**

```bash
git add resources/adventure/encounters/combat_encounters/amorphous_spirit_boss.tres \
        resources/adventure/encounters/combat_encounters/amorphous_spirit_boss.tres.uid \
        resources/adventure/encounters/combat_encounters/amorphous_spirit_encounter.tres \
        resources/adventure/encounters/combat_encounters/starving_dreadbeast_encounter.tres \
        resources/adventure/encounters/special_encounters/aura_well_encounter.tres \
        resources/adventure/encounters/special_encounters/refugee_camp_encounter.tres \
        resources/adventure/data/shallow_woods.tres
git commit -m "feat(adventure): migrate Shallow Woods and encounters to quota schema"
```

> If `.uid` files weren't regenerated, skip them in the `git add`; the import step should have created them but on some CI setups they appear later.

---

## Task 5: Rewrite `AdventureMapGenerator`

**Files:**
- Modify: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` (full rewrite)
- Modify: `tests/unit/test_adventure_map_generator_filter.gd` (migrate to `is_eligible()`)
- Create: `tests/unit/test_adventure_map_generator.gd`

- [ ] **Step 1: Write the new generator test**

Create `tests/unit/test_adventure_map_generator.gd`:

```gdscript
extends GutTest

## Integration-ish tests for the new AdventureMapGenerator. Uses a bare
## HexagonTileMapLayer instance for hex math — no actual tiles are painted.

const GENERATOR_SCRIPT := preload("res://scenes/adventure/adventure_tilemap/adventure_map_generator.gd")
const TILEMAP_SCENE := preload("res://scenes/tilemaps/hexagon_tile_map_layer.tscn")

func _make_tilemap() -> HexagonTileMapLayer:
    var tm: HexagonTileMapLayer = TILEMAP_SCENE.instantiate()
    add_child_autofree(tm)
    return tm

func _make_encounter(id: String, placement: AdventureEncounter.Placement, min_dist: int = 0, min_fillers: int = 0) -> AdventureEncounter:
    var enc := AdventureEncounter.new()
    enc.encounter_id = id
    enc.placement = placement
    enc.min_distance_from_origin = min_dist
    enc.min_fillers_on_path = min_fillers
    return enc

func _make_quota(enc: AdventureEncounter, count: int) -> EncounterQuota:
    var q := EncounterQuota.new()
    q.encounter = enc
    q.count = count
    return q

func _make_data() -> AdventureData:
    var data := AdventureData.new()
    data.max_distance_from_start = 6
    data.sparse_factor = 2
    data.num_extra_edges = 2
    data.boss_encounter = _make_encounter("boss", AdventureEncounter.Placement.ANCHOR, 5)
    data.encounter_quotas = [
        _make_quota(_make_encounter("rest", AdventureEncounter.Placement.ANCHOR, 3, 1), 1),
        _make_quota(_make_encounter("combat", AdventureEncounter.Placement.FILLER), 4),
    ]
    return data

func _run_generation(data: AdventureData) -> Dictionary:
    var gen = GENERATOR_SCRIPT.new()
    add_child_autofree(gen)
    gen.set_adventure_data(data)
    gen.set_tile_map(_make_tilemap())
    return gen.generate_adventure_map()

func test_invalid_config_returns_empty_map() -> void:
    var data := _make_data()
    data.boss_encounter = null
    var tiles := _run_generation(data)
    assert_eq(tiles.size(), 0, "invalid config should yield an empty map")

func test_anchors_respect_min_distance_from_origin() -> void:
    var data := _make_data()
    for trial in 50:
        var tiles := _run_generation(data)
        var rest_coord: Vector3i = Vector3i.ZERO
        var rest_found := false
        for coord in tiles.keys():
            if tiles[coord].encounter_id == "rest":
                rest_coord = coord
                rest_found = true
                break
        assert_true(rest_found, "trial %d: rest anchor missing" % trial)
        var tilemap := _make_tilemap()
        var distance: int = tilemap.cube_distance(Vector3i.ZERO, rest_coord)
        assert_gte(distance, 3, "trial %d: rest placed at distance %d, expected >= 3" % [trial, distance])

func test_anchors_respect_sparse_factor() -> void:
    var data := _make_data()
    for trial in 50:
        var tiles := _run_generation(data)
        var tilemap := _make_tilemap()
        var anchor_coords: Array[Vector3i] = []
        for coord in tiles.keys():
            var enc: AdventureEncounter = tiles[coord]
            if enc == null: continue
            if enc.placement == AdventureEncounter.Placement.ANCHOR:
                anchor_coords.append(coord)
        for i in range(anchor_coords.size()):
            assert_gte(tilemap.cube_distance(Vector3i.ZERO, anchor_coords[i]), data.sparse_factor,
                "trial %d: anchor too close to origin" % trial)
            for j in range(i + 1, anchor_coords.size()):
                var d: int = tilemap.cube_distance(anchor_coords[i], anchor_coords[j])
                assert_gte(d, data.sparse_factor,
                    "trial %d: anchors %s and %s within sparse_factor" % [trial, anchor_coords[i], anchor_coords[j]])

func test_boss_is_at_farthest_anchor() -> void:
    var data := _make_data()
    for trial in 20:
        var tiles := _run_generation(data)
        var tilemap := _make_tilemap()
        var boss_coord: Vector3i = Vector3i.ZERO
        var boss_distance: int = -1
        var max_anchor_distance: int = -1
        for coord in tiles.keys():
            var enc: AdventureEncounter = tiles[coord]
            if enc == null: continue
            if enc.encounter_id == "boss":
                boss_coord = coord
                boss_distance = tilemap.cube_distance(Vector3i.ZERO, coord)
            elif enc.placement == AdventureEncounter.Placement.ANCHOR:
                max_anchor_distance = max(max_anchor_distance, tilemap.cube_distance(Vector3i.ZERO, coord))
        assert_gte(boss_distance, max_anchor_distance,
            "trial %d: boss at distance %d but another anchor is at %d" % [trial, boss_distance, max_anchor_distance])

func test_extra_edges_add_branching() -> void:
    # With num_extra_edges = 2, the total edge count should exceed the MST
    # size (anchor_count - 1) by 2 when anchors are spread enough.
    var data := _make_data()
    data.num_extra_edges = 2
    var found_branching := false
    for trial in 20:
        var tiles := _run_generation(data)
        var anchor_count: int = 0
        for enc in tiles.values():
            if enc != null and enc.placement == AdventureEncounter.Placement.ANCHOR:
                anchor_count += 1
        var degree: Dictionary = {}
        for coord in tiles.keys():
            for off in _neighbor_offsets():
                if (coord + off) in tiles:
                    degree[coord] = degree.get(coord, 0) + 1
        var degree_3_or_more: int = 0
        for v in degree.values():
            if v >= 3:
                degree_3_or_more += 1
        if degree_3_or_more > 0:
            found_branching = true
            break
    assert_true(found_branching, "expected at least one trial to produce a tile with degree >= 3 via extra edges")

func _neighbor_offsets() -> Array[Vector3i]:
    return [
        Vector3i(+1, -1, 0), Vector3i(-1, +1, 0),
        Vector3i(+1, 0, -1), Vector3i(-1, 0, +1),
        Vector3i(0, +1, -1), Vector3i(0, -1, +1),
    ]

func test_quota_counts_are_respected() -> void:
    var data := _make_data()
    var tiles := _run_generation(data)
    var counts: Dictionary = {"rest": 0, "combat": 0, "boss": 0}
    for enc in tiles.values():
        if enc.encounter_id in counts:
            counts[enc.encounter_id] += 1
    assert_eq(counts["rest"], 1)
    assert_eq(counts["combat"], 4)
    assert_eq(counts["boss"], 1)

func test_ineligible_encounter_is_skipped() -> void:
    PersistenceManager.save_game_data = SaveGameData.new()
    PersistenceManager.save_data_reset.emit()
    var data := _make_data()
    var cond := UnlockConditionData.new()
    cond.condition_type = UnlockConditionData.ConditionType.EVENT_TRIGGERED
    cond.target_value = "never_fires_generator_test"
    data.encounter_quotas[1].encounter.unlock_conditions = {cond: true}
    var tiles := _run_generation(data)
    for enc in tiles.values():
        assert_ne(enc.encounter_id, "combat", "ineligible combat should not be placed")

func test_no_infinite_loop_on_oversized_filler_quota() -> void:
    var data := _make_data()
    data.max_distance_from_start = 2
    data.boss_encounter.min_distance_from_origin = 2
    data.encounter_quotas[1].count = 500 # deliberately unreachable
    # This call must terminate; if it hangs, the test runner will time out.
    var tiles := _run_generation(data)
    assert_gt(tiles.size(), 0, "generator should still produce some map")

func test_min_fillers_on_path_guaranteed() -> void:
    var data := _make_data()
    for trial in 50:
        var tiles := _run_generation(data)
        var rest_coord: Vector3i = Vector3i.ZERO
        for coord in tiles.keys():
            if tiles[coord].encounter_id == "rest":
                rest_coord = coord
                break
        # BFS from origin across the generated graph.
        var path: Array = _bfs_path(tiles, Vector3i.ZERO, rest_coord)
        assert_false(path.is_empty(), "trial %d: no path from origin to rest" % trial)
        var fillers_on_path: int = 0
        for coord in path:
            if coord == Vector3i.ZERO or coord == rest_coord:
                continue
            if tiles[coord].placement == AdventureEncounter.Placement.FILLER:
                fillers_on_path += 1
        assert_gte(fillers_on_path, 1, "trial %d: path from origin to rest had no filler" % trial)

func _bfs_path(tiles: Dictionary, start: Vector3i, goal: Vector3i) -> Array:
    var neighbors_offsets: Array[Vector3i] = [
        Vector3i(+1, -1, 0), Vector3i(-1, +1, 0),
        Vector3i(+1, 0, -1), Vector3i(-1, 0, +1),
        Vector3i(0, +1, -1), Vector3i(0, -1, +1),
    ]
    var came_from: Dictionary = {start: null}
    var frontier: Array = [start]
    while not frontier.is_empty():
        var current: Vector3i = frontier.pop_front()
        if current == goal:
            var path: Array = []
            var node = goal
            while node != null:
                path.push_front(node)
                node = came_from[node]
            return path
        for off in neighbors_offsets:
            var next: Vector3i = current + off
            if next in tiles and not (next in came_from):
                came_from[next] = current
                frontier.append(next)
    return []
```

- [ ] **Step 2: Run tests to verify failures**

Run:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gselect=test_adventure_map_generator.gd -gexit
```

Expected: tests fail — generator has old behavior; no `encounter_quotas`-driven placement yet.

- [ ] **Step 3: Replace the generator body**

Overwrite `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` with:

```gdscript
class_name AdventureMapGenerator
extends Node

const MAX_PLACEMENT_ATTEMPTS: int = 100
const MAX_REGENERATION_ATTEMPTS: int = 5

const NEIGHBOR_OFFSETS: Array[Vector3i] = [
    Vector3i(+1, -1, 0), Vector3i(-1, +1, 0),
    Vector3i(+1, 0, -1), Vector3i(-1, 0, +1),
    Vector3i(0, +1, -1), Vector3i(0, -1, +1),
]

var adventure_data: AdventureData
var tile_map: HexagonTileMapLayer

var all_map_tiles: Dictionary[Vector3i, AdventureEncounter] = {}

## Sets the adventure_data used for generation.
func set_adventure_data(p_adventure_data: AdventureData) -> void:
    adventure_data = p_adventure_data

## Sets the tile map layer to be used.
func set_tile_map(tm: HexagonTileMapLayer) -> void:
    tile_map = tm

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Generates a full adventure map. Returns the coord->encounter dictionary,
## or an empty dictionary if validation fails.
func generate_adventure_map() -> Dictionary[Vector3i, AdventureEncounter]:
    if adventure_data == null:
        Log.error("AdventureMapGenerator: adventure_data is not set")
        return {}
    if tile_map == null:
        Log.error("AdventureMapGenerator: tile_map is not set")
        return {}

    var errors: Array[String] = adventure_data.validate()
    if errors.size() > 0:
        for err in errors:
            Log.error("AdventureMapGenerator: %s" % err)
        return {}

    for attempt in MAX_REGENERATION_ATTEMPTS:
        all_map_tiles = {}
        all_map_tiles[Vector3i.ZERO] = NoOpEncounter.new()

        _place_anchors()
        _generate_paths()
        _place_fillers()

        if _validate_critical_paths():
            return all_map_tiles

        Log.warn("AdventureMapGenerator: critical-path check failed, regenerating (attempt %d)" % (attempt + 1))

    Log.error("AdventureMapGenerator: exhausted regeneration attempts, returning best-effort map")
    return all_map_tiles

#-----------------------------------------------------------------------------
# PHASE 1 — SCATTER ANCHORS
#-----------------------------------------------------------------------------

func _place_anchors() -> void:
    for quota in adventure_data.encounter_quotas:
        if quota == null or quota.encounter == null:
            continue
        if quota.encounter.placement != AdventureEncounter.Placement.ANCHOR:
            continue
        if not quota.encounter.is_eligible():
            Log.info("AdventureMapGenerator: skipping %s — unlock_conditions not met" % quota.encounter.encounter_id)
            continue
        for i in quota.count:
            _place_single_anchor(quota.encounter)

    # Boss always placed last at the farthest anchor-valid coord found.
    if adventure_data.boss_encounter != null:
        _place_boss()

func _place_single_anchor(encounter: AdventureEncounter) -> void:
    for attempt in MAX_PLACEMENT_ATTEMPTS:
        var coord := _random_cube_coord(adventure_data.max_distance_from_start)
        if tile_map.cube_distance(Vector3i.ZERO, coord) > adventure_data.max_distance_from_start:
            continue
        if tile_map.cube_distance(Vector3i.ZERO, coord) < encounter.min_distance_from_origin:
            continue
        if _violates_sparse_factor(coord):
            continue
        all_map_tiles[coord] = encounter
        return
    Log.warn("AdventureMapGenerator: could not place anchor %s after %d attempts" % [encounter.encounter_id, MAX_PLACEMENT_ATTEMPTS])

func _place_boss() -> void:
    var boss := adventure_data.boss_encounter
    var best_coord: Vector3i = Vector3i.ZERO
    var best_distance: int = -1
    for attempt in MAX_PLACEMENT_ATTEMPTS:
        var coord := _random_cube_coord(adventure_data.max_distance_from_start)
        if tile_map.cube_distance(Vector3i.ZERO, coord) > adventure_data.max_distance_from_start:
            continue
        if tile_map.cube_distance(Vector3i.ZERO, coord) < boss.min_distance_from_origin:
            continue
        if _violates_sparse_factor(coord):
            continue
        var d: int = tile_map.cube_distance(Vector3i.ZERO, coord)
        if d > best_distance:
            best_distance = d
            best_coord = coord
    if best_distance >= 0:
        all_map_tiles[best_coord] = boss
    else:
        Log.warn("AdventureMapGenerator: could not place boss %s" % boss.encounter_id)

func _random_cube_coord(radius: int) -> Vector3i:
    var q := randi_range(-radius, radius)
    var r := randi_range(-radius, radius)
    return Vector3i(q, r, -q - r)

func _violates_sparse_factor(coord: Vector3i) -> bool:
    if tile_map.cube_distance(Vector3i.ZERO, coord) < adventure_data.sparse_factor:
        return true
    for existing in all_map_tiles.keys():
        if existing == Vector3i.ZERO:
            continue
        if tile_map.cube_distance(existing, coord) < adventure_data.sparse_factor:
            return true
    return false

#-----------------------------------------------------------------------------
# PHASE 2 — MST + EXTRA EDGES
#-----------------------------------------------------------------------------

func _generate_paths() -> void:
    var anchors: Array[Vector3i] = all_map_tiles.keys().duplicate()

    var mst_edges: Array = []
    var in_tree: Array[Vector3i] = [Vector3i.ZERO]
    var remaining: Array[Vector3i] = anchors.filter(func(c): return c != Vector3i.ZERO)

    while not remaining.is_empty():
        var best_from: Vector3i
        var best_to: Vector3i
        var best_dist: int = 1 << 30
        for a in in_tree:
            for b in remaining:
                var d: int = tile_map.cube_distance(a, b)
                if d < best_dist:
                    best_dist = d
                    best_from = a
                    best_to = b
        if best_dist == 1 << 30:
            break
        mst_edges.append([best_from, best_to])
        in_tree.append(best_to)
        remaining.erase(best_to)

    for edge in mst_edges:
        _stamp_line(edge[0], edge[1])

    # Extra edges — shortest non-tree edges between any two anchors.
    var candidate_edges: Array = []
    for i in range(anchors.size()):
        for j in range(i + 1, anchors.size()):
            var a: Vector3i = anchors[i]
            var b: Vector3i = anchors[j]
            if _edge_in_mst(mst_edges, a, b):
                continue
            candidate_edges.append({"a": a, "b": b, "dist": tile_map.cube_distance(a, b)})
    candidate_edges.sort_custom(func(x, y): return x.dist < y.dist)

    var added: int = 0
    for c in candidate_edges:
        if added >= adventure_data.num_extra_edges:
            break
        _stamp_line(c.a, c.b)
        added += 1

func _edge_in_mst(mst_edges: Array, a: Vector3i, b: Vector3i) -> bool:
    for e in mst_edges:
        if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
            return true
    return false

func _stamp_line(from: Vector3i, to: Vector3i) -> void:
    for coord in tile_map.cube_linedraw(from, to):
        if not coord in all_map_tiles:
            all_map_tiles[coord] = NoOpEncounter.new()

#-----------------------------------------------------------------------------
# PHASE 3 — PLACE FILLERS
#-----------------------------------------------------------------------------

func _place_fillers() -> void:
    for quota in adventure_data.encounter_quotas:
        if quota == null or quota.encounter == null:
            continue
        if quota.encounter.placement != AdventureEncounter.Placement.FILLER:
            continue
        if not quota.encounter.is_eligible():
            Log.info("AdventureMapGenerator: skipping filler %s — unlock_conditions not met" % quota.encounter.encounter_id)
            continue
        var placed: int = 0
        while placed < quota.count:
            var noop_coords: Array[Vector3i] = _collect_noop_coords()
            if noop_coords.is_empty():
                Log.warn("AdventureMapGenerator: filler quota %s exceeds available NoOp tiles (placed %d of %d)" % [quota.encounter.encounter_id, placed, quota.count])
                break
            var pick: Vector3i = noop_coords[randi_range(0, noop_coords.size() - 1)]
            all_map_tiles[pick] = quota.encounter
            placed += 1

func _collect_noop_coords() -> Array[Vector3i]:
    var result: Array[Vector3i] = []
    for coord in all_map_tiles.keys():
        if coord == Vector3i.ZERO:
            continue
        if all_map_tiles[coord] is NoOpEncounter:
            result.append(coord)
    return result

#-----------------------------------------------------------------------------
# PHASE 4 — CRITICAL-PATH CHECK
#-----------------------------------------------------------------------------

## Returns true if every encounter with min_fillers_on_path > 0 has enough
## fillers on its shortest path from origin. Mutates all_map_tiles to promote
## NoOp tiles to combat fillers where possible. Returns false if unable to
## satisfy (caller should regenerate).
func _validate_critical_paths() -> bool:
    for coord in all_map_tiles.keys():
        var enc: AdventureEncounter = all_map_tiles[coord]
        if enc == null or enc.min_fillers_on_path <= 0:
            continue
        var path: Array[Vector3i] = _bfs_path(Vector3i.ZERO, coord)
        if path.is_empty():
            return false
        var filler_count: int = 0
        var noops_on_path: Array[Vector3i] = []
        for p in path:
            if p == Vector3i.ZERO or p == coord:
                continue
            var enc_on_path: AdventureEncounter = all_map_tiles[p]
            if enc_on_path is NoOpEncounter:
                noops_on_path.append(p)
            elif enc_on_path.placement == AdventureEncounter.Placement.FILLER:
                filler_count += 1
        var deficit: int = enc.min_fillers_on_path - filler_count
        if deficit <= 0:
            continue
        if deficit > noops_on_path.size():
            return false
        var promote_pool: AdventureEncounter = _find_eligible_filler_encounter()
        if promote_pool == null:
            return false
        for i in deficit:
            all_map_tiles[noops_on_path[i]] = promote_pool
    return true

func _find_eligible_filler_encounter() -> AdventureEncounter:
    # Prefer COMBAT_REGULAR; fall back to any eligible FILLER.
    var fallback: AdventureEncounter = null
    for quota in adventure_data.encounter_quotas:
        if quota == null or quota.encounter == null:
            continue
        if quota.encounter.placement != AdventureEncounter.Placement.FILLER:
            continue
        if not quota.encounter.is_eligible():
            continue
        if quota.encounter.encounter_type == AdventureEncounter.EncounterType.COMBAT_REGULAR:
            return quota.encounter
        if fallback == null:
            fallback = quota.encounter
    return fallback

func _bfs_path(start: Vector3i, goal: Vector3i) -> Array[Vector3i]:
    var came_from: Dictionary = {start: null}
    var frontier: Array[Vector3i] = [start]
    while not frontier.is_empty():
        var current: Vector3i = frontier.pop_front()
        if current == goal:
            var path: Array[Vector3i] = []
            var node = goal
            while node != null:
                path.push_front(node)
                node = came_from[node]
            return path
        for off in NEIGHBOR_OFFSETS:
            var next: Vector3i = current + off
            if next in all_map_tiles and not (next in came_from):
                came_from[next] = current
                frontier.append(next)
    return []
```

- [ ] **Step 4: Delete the superseded filter test**

`tests/unit/test_adventure_map_generator_filter.gd` tested `_build_eligible_special_pool` on the generator — that method no longer exists. The eligibility behavior is now tested comprehensively by `tests/unit/test_adventure_encounter.gd` (Task 1), so the filter test is redundant.

Delete the file:

```bash
git rm tests/unit/test_adventure_map_generator_filter.gd
```

- [ ] **Step 5: Run the full unit suite**

Run:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: all tests pass, including the 6 new generator tests and the migrated filter test.

- [ ] **Step 6: Smoke-test via the editor (manual)**

Open the project:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --path . scenes/main/main_game/main_game.tscn
```

From Zone 1, start a Shallow Woods adventure. Confirm:
- Map generates without crashes.
- Encounters appear on tiles (rest, refugee camp, combats, boss at far point).
- No rest site adjacent to origin.

- [ ] **Step 7: Commit**

```bash
git add scenes/adventure/adventure_tilemap/adventure_map_generator.gd \
        tests/unit/test_adventure_map_generator.gd
git commit -m "feat(adventure): rewrite map generator with quota-keyed algorithm"
```

> The `git rm` from Step 4 already staged the filter test deletion, so the commit includes it automatically.

---

## Task 6: Remove old fields and dead code

**Files:**
- Modify: `scripts/resource_definitions/adventure/adventure_data.gd`
- Modify: `resources/adventure/data/shallow_woods.tres`
- Modify: `scenes/adventure/adventure_tilemap/adventure_map_generator.gd`

- [ ] **Step 1: Remove old fields from `AdventureData`**

Edit `scripts/resource_definitions/adventure/adventure_data.gd`. Delete:

```gdscript
@export var num_special_tiles: int = 5
@export var num_path_encounters: int = 5
@export var special_encounter_pool: Array[AdventureEncounter]
@export var path_encounter_pool: Array[AdventureEncounter]
```

Also delete the now-empty `@export_group("Placement Parameters")` label if it is. Keep `max_distance_from_start` and `sparse_factor`.

- [ ] **Step 2: Remove dead `num_combats_in_map` from the generator**

Edit `scenes/adventure/adventure_tilemap/adventure_map_generator.gd` and delete the line:

```gdscript
var num_combats_in_map : int = 0
```

(It was dead in the old generator; the new one reimplemented without reintroducing it.)

- [ ] **Step 3: Strip old fields from `shallow_woods.tres`**

Edit `resources/adventure/data/shallow_woods.tres`:
- Remove the `special_encounter_pool = ...` line.
- Remove the `path_encounter_pool = ...` line.
- Remove the `num_path_encounters = 8` line.
- Remove the `ext_resource` entries (`id="6_mnoah"`, `id="7_r4hwa"`, `id="8_pkd7m"`, `id="9_aurawell"`, `id="10_refcamp"`) **only if** they are no longer referenced elsewhere in the file. After the pool-line removals, the encounter `ExtResource` references remain live through the `[sub_resource]` `EncounterQuota` entries and the `boss_encounter` field — keep those.

After edits, the file should reference: boss_encounter (via `id="11_boss"`), the 4 EncounterQuota subresources, and indirectly the 4 encounters via the quotas.

- [ ] **Step 4: Re-import and run tests**

Run in parallel:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: import completes cleanly; all tests pass.

- [ ] **Step 5: Smoke-test the game once more**

Open the editor:

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --path . scenes/main/main_game/main_game.tscn
```

Start a Shallow Woods adventure. Confirm the map still generates and plays normally.

- [ ] **Step 6: Commit**

```bash
git add scripts/resource_definitions/adventure/adventure_data.gd \
        scenes/adventure/adventure_tilemap/adventure_map_generator.gd \
        resources/adventure/data/shallow_woods.tres
git commit -m "chore(adventure): remove legacy pool fields and dead code"
```

---

## Post-plan verification

After all six tasks:

- All unit and integration tests pass.
- Shallow Woods adventures generate maps that: have exactly 1 boss at the farthest tile, no rest within hex-distance 3 of origin, at least one filler combat on every path from origin to a rest, and 2 extra graph edges providing branching choice.
- `AdventureMapGenerator` has no infinite-loop paths.
- `AdventureData.validate()` runs at generation time and is covered by a test that loads every shipped `.tres`.

---

## Self-review notes

- **Spec coverage:** All 10 spec sections have tasks (schema → 1-2, validation → 3, algorithm → 5, content migration → 4, cleanup → 6; out-of-scope sections correctly skipped).
- **No placeholders** — every step contains complete code or exact commands.
- **Type consistency:** `Placement.ANCHOR = 0`, `Placement.FILLER = 1` used consistently across `.tres` files and script. `EncounterQuota.encounter` and `EncounterQuota.count` names used consistently.
- **Game remains playable after every task.** Tasks 1-4 are additive; Task 5 swaps the generator while content supports both schemas; Task 6 removes old fields once nothing reads them.
