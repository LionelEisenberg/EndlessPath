# Stat Modifier Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every bonus to a player stat goes through one modifier layer that `CharacterManager` owns. Gear is its first source, and the max Health, Stamina and Madra formulas live in one place. Nothing the player sees changes.

**Architecture:**
- A `StatModifierStack` holds named sources, each a `Callable` returning `Array[StatModifierData]`. It folds them at read time as `(base + Σflat) × (1 + Σpercent)`.
- `CharacterManager.get_stat()` applies the attribute modifiers to the save's base, then the derived formula on `CharacterAttributesData`, then the derived-stat modifiers.
- The player's `VitalsManager` and `ResourceManager` read `get_stat()`. Enemies use the formulas on their own attributes.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1.

**Spec:** `docs/superpowers/specs/2026-10-29-stat-modifier-layer-design.md`

## Global Constraints

- **Stacking:** `(base + sum of FLAT values) × (1 + sum of PERCENT values)`. A PERCENT `value` of `0.1` is +10%. No clamp, no OVERRIDE.
- **Order:** attribute modifiers, then the derived formula over the total attributes, then the derived-stat modifiers.
- **Formulas:** `HEALTH_PER_BODY = 10.0`, `STAMINA_PER_BODY = 5.0`, `MADRA_PER_FOUNDATION = 10.0`.
- **Character sheet text stays exactly:** "Max Health = Body × 10", "Max Stamina = Body × 5", "Max Madra = Foundation × 10".
- **No save format change;** no `.tres` changes.
- **Coding standards (CLAUDE.md):**
  - explicit return types;
  - public functions have no `_` and carry `##` docs;
  - class variables are typed;
  - no `print()`;
  - never touch `addons/`.
- **No living-doc edits:** the PR carries the spec's "Docs to update" list.
- **Test one file:** `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/unit/<file>.gd -gexit`. After adding a new `class_name` script, run `--headless --import` once first.
- **Commits:** conventional, specific files staged, `.uid` files of new scripts included, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- **A save reset while gear is equipped in the new save.** A `stats_changed` listener reading totals during the reset must see the new save's gear, not the old one's. The test is in Task 3.
- **Gear placed in a save with no inventory signal** (a loaded save, a dev preset, a test that writes `equipped_gear` directly). The totals and a newly built player `VitalsManager` include it at once. The test is in Task 3.
- **A source whose owner was freed:** its invalid `Callable` is skipped without errors. The test is in Task 1.
- **An attribute bonus and a derived bonus together.** Body +4 from gear, plus a MAX_HEALTH source of +20 flat and +10%, gives (14 × 10 + 20) × 1.1 = 176. The test is in Task 3.
- **The player's modifiers leaking into an enemy:** an enemy `VitalsManager` with Body 10 keeps 100 max Health while a MAX_HEALTH source is set. The test is in Task 3.

---

### Task 1: Modifier data and stack

**Files:**
- Create: `scripts/resource_definitions/character/stat_modifier_data.gd`
- Create: `singletons/character_manager/stat_modifier_stack.gd`
- Test: `tests/unit/test_stat_modifier_stack.gd` (new; covers both classes)

**Interfaces:**
- Produces:
  - `class_name StatModifierData extends Resource`:
    - `enum Stat { STRENGTH, BODY, AGILITY, SPIRIT, FOUNDATION, CONTROL, RESILIENCE, WILLPOWER, MAX_HEALTH, MAX_STAMINA, MAX_MADRA }`
    - `enum Kind { FLAT, PERCENT }`
    - `@export var stat: Stat`, `@export var kind: Kind = Kind.FLAT`, `@export var value: float = 0.0`
    - `_init(p_stat: Stat = Stat.STRENGTH, p_kind: Kind = Kind.FLAT, p_value: float = 0.0)`
    - `static func for_attribute(attribute: CharacterAttributesData.AttributeType) -> Stat`
    - `static func attribute_of(stat: Stat) -> int` (returns −1 for a derived vital)
  - `class_name StatModifierStack extends RefCounted`:
    - `set_source(source: StringName, provider: Callable) -> void`
    - `remove_source(source: StringName) -> void`
    - `apply(stat: StatModifierData.Stat, base: float) -> float`

- [ ] **Step 1: Write the failing tests**

```gdscript
const Stat = StatModifierData.Stat
const Kind = StatModifierData.Kind

func test_every_attribute_has_a_stat_of_the_same_name() -> void:
	for attribute: int in CharacterAttributesData.AttributeType.values():
		var stat: int = StatModifierData.for_attribute(attribute)
		assert_eq(Stat.keys()[stat], CharacterAttributesData.AttributeType.keys()[attribute])
		assert_eq(StatModifierData.attribute_of(stat), attribute)

func test_derived_vitals_are_not_attributes() -> void:
	for stat: int in [Stat.MAX_HEALTH, Stat.MAX_STAMINA, Stat.MAX_MADRA]:
		assert_eq(StatModifierData.attribute_of(stat), -1)

func test_no_sources_returns_the_base() -> void:            # apply(BODY, 10.0) == 10.0
func test_flat_modifiers_add() -> void:                     # +3, +2 on BODY -> 15.0
func test_percent_modifiers_add_before_applying() -> void:  # +0.1, +0.1 on BODY, base 10 -> 12.0 (not 12.1)
func test_flat_applies_before_percent() -> void:            # +5 flat, +0.2 percent, base 10 -> 18.0
func test_modifiers_for_other_stats_are_ignored() -> void:  # +5 on SPIRIT, apply(BODY, 10) -> 10.0
func test_sources_stack() -> void:                          # &"a" +2, &"b" +3 -> 15.0
func test_setting_a_source_again_replaces_it() -> void:     # &"a" +2 then &"a" +7 -> 17.0
func test_remove_source() -> void:                          # back to 10.0
func test_providers_are_asked_at_read_time() -> void:       # provider reads a test var; change the var, apply sees it
func test_a_freed_providers_source_is_skipped() -> void:    # provider bound to a freed Node's method -> 10.0, no error
```

Build each provider as a lambda returning a typed `Array[StatModifierData]`. For the freed case, use a small inner `class Owner extends Node` with a `modifiers()` method. Free it with `free()` before calling `apply`.

- [ ] **Step 2: Run them to verify they fail**

Run the test-one-file command for `test_stat_modifier_stack.gd`. Expected: a parse failure, because `StatModifierData` is not defined (the runner reports the script ran no tests).

- [ ] **Step 3: Implement both classes**

- `for_attribute` and `attribute_of` map by name: `Stat[AttributeType.keys()[attribute]]` and `AttributeType.get(Stat.keys()[stat], -1)`.
- `StatModifierStack` keeps a typed `Dictionary[StringName, Callable]`.
- `apply` skips a provider when `not provider.is_valid()`, sums FLAT and PERCENT separately for the matching `stat`, and returns `(base + flat) * (1.0 + percent)`.

- [ ] **Step 4: Import, then run the tests to verify they pass**

Run `--headless --import`, then the test command. Expected: all pass.

- [ ] **Step 5: Commit**

`feat(character): add a stat modifier stack`

---

### Task 2: One home for the derived vitals

**Files:**
- Modify: `scripts/resource_definitions/character/character_attributes_data.gd`
- Modify: `scenes/combat/combatant/vitals_manager/vitals_manager.gd`
- Modify: `scenes/character/character_view.gd`, the `ATTRIBUTE_DETAILS` formulas and the comment above it
- Modify: `scenes/adventure/adventure_chest/expedition_page/expedition_page.gd`, `tests/integration/test_expedition_page.gd` (comments naming `max_health_for()`)
- Test: `tests/unit/test_character_attributes_data.gd`, `tests/unit/test_fight_rules.gd`, `tests/integration/test_dev_hooks.gd`

**Interfaces:**
- Produces on `CharacterAttributesData`:
  - `const HEALTH_PER_BODY: float = 10.0`
  - `const STAMINA_PER_BODY: float = 5.0`
  - `const MADRA_PER_FOUNDATION: float = 10.0`
  - `get_max_health() -> float`
  - `get_max_stamina() -> float`
  - `get_max_madra() -> float` (existing; now uses the constant)
- Removes: `VitalsManager.max_health_for()`, `_get_max_health()`, `_get_max_stamina()`, `_get_max_madra()`.

- [ ] **Step 1: Write the failing tests**

In `test_character_attributes_data.gd`:
- `test_get_max_health_is_body_times_ten`: Body 12 gives 120.0.
- `test_get_max_stamina_is_body_times_five`: Body 12 gives 60.0.

In `test_fight_rules.gd`, replace every `VitalsManager.max_health_for(attributes)` with `attributes.get_max_health()`; the asserted values are unchanged.

In `test_dev_hooks.gd`, replace `VitalsManager.max_health_for(CharacterManager.get_total_attributes_data())` with `CharacterManager.get_total_attributes_data().get_max_health()`.

- [ ] **Step 2: Run them to verify they fail**

Expected: errors because `get_max_health` / `get_max_stamina` do not exist.

- [ ] **Step 3: Implement**

- Add the constants and getters.
- `VitalsManager._update_combat_max()` sets the three maxima from `character_attributes_data.get_max_health()` / `get_max_stamina()` / `get_max_madra()`.
- In `ATTRIBUTE_DETAILS`, build the three formula strings from the constants. Try a constant expression first (`"Max Health = Body × %d" % CharacterAttributesData.HEALTH_PER_BODY`). If the analyzer rejects it, turn `ATTRIBUTE_DETAILS` into a `static var`.
- Point the two comments at `CharacterAttributesData.get_max_health()`.

- [ ] **Step 4: Run the tests**

Run `test_character_attributes_data.gd`, `test_fight_rules.gd`, `tests/integration/test_dev_hooks.gd`, `tests/integration/test_character_book.gd` (it asserts the three sheet lines) and `tests/unit/test_player_vitals_manager.gd`. Expected: all pass.

- [ ] **Step 5: Commit**

`refactor(character): give the derived vitals one home`

---

### Task 3: Gear onto the layer

**Files:**
- Modify: `scripts/resource_definitions/items/equipment/equipment_definition_data.gd`
- Modify: `singletons/character_manager/character_manager.gd`
- Modify: `scenes/combat/combatant/vitals_manager/vitals_manager.gd`
- Modify: `singletons/resource_manager/resource_manager.gd`, `get_adventure_madra_capacity()`
- Modify: `scenes/zones/zone_action_button/presenters/adventure_presenter.gd` (signal rename)
- Test: `tests/unit/test_equipment.gd`, `tests/unit/test_character_manager.gd`, `tests/unit/test_player_vitals_manager.gd`, `tests/integration/test_dev_hooks.gd` (its hook-count check moves to `stats_changed`)

**Interfaces:**
- Consumes: Task 1's `StatModifierData` and `StatModifierStack`; Task 2's `CharacterAttributesData` getters.
- Produces:
  - `EquipmentDefinitionData.get_stat_modifiers() -> Array[StatModifierData]`: one FLAT modifier per `attribute_bonuses` entry.
  - `CharacterManager.get_stat(stat: StatModifierData.Stat) -> float`
  - `CharacterManager.set_modifier_source(source: StringName, provider: Callable) -> void`
  - `CharacterManager.remove_modifier_source(source: StringName) -> void`
  - `signal stats_changed`, which replaces `total_attributes_changed`.
  - `get_total_attributes_data()` keeps its signature.

- [ ] **Step 1: Write the failing tests**

`test_equipment.gd`:
- `test_get_stat_modifiers_turns_bonuses_into_flat_modifiers`: `{BODY: 4.0, RESILIENCE: 2.0}` gives two FLAT modifiers, `(Stat.BODY, 4.0)` and `(Stat.RESILIENCE, 2.0)`, in either order.
- An empty dictionary gives an empty array.

`test_character_manager.gd`:
- Rename the four signal tests from `total_attributes_changed` to `stats_changed`.
- `test_get_stat_reads_base_plus_gear`: robes `{BODY: 4}` set directly in `equipped_gear`. `get_stat(Stat.BODY) == 14.0` and `get_stat(Stat.MAX_HEALTH) == 140.0`.
- `test_a_source_can_raise_a_derived_vital_directly`: a source with MAX_HEALTH +20 flat. `get_stat(Stat.MAX_HEALTH) == 120.0` and `get_stat(Stat.BODY) == 10.0`.
- `test_attribute_and_derived_bonuses_combine_in_order`: gear Body +4, plus a source with MAX_HEALTH +20 flat and +0.1 percent, gives `get_stat(Stat.MAX_HEALTH) == 176.0`.
- `test_setting_and_removing_a_source_emits_stats_changed`: emit count 1 for each call.
- `test_removing_a_source_restores_the_value`.
- `test_a_listener_during_save_reset_sees_the_new_saves_gear`:
  - The current save has robes `{BODY: 4}` equipped.
  - A second `SaveGameData` has no gear.
  - Connect a lambda to `stats_changed` that records `get_stat(Stat.BODY)`.
  - Swap `PersistenceManager.save_game_data` to the second save and emit `save_data_reset`.
  - The recorded value is `10.0`.

  This test fails on the current code, which records 14.0 through `InventoryManager`'s stale save.

Remove a source in `after_each` (`CharacterManager.remove_modifier_source(&"test")`).

`test_player_vitals_manager.gd`:
- Rename the signal where it is named.
- `test_a_max_health_source_reaches_the_players_vitals`: a source with MAX_HEALTH +20 gives `_vitals.max_health == 120.0`.
- `test_gear_already_in_the_save_counts_at_once`:
  - Write the robes into `equipped_gear` with no signal.
  - Build a new `VitalsManager` with `is_player`.
  - Its `max_health` is 140.0.
- `test_an_enemys_vitals_ignore_player_modifiers`:
  - Set a MAX_HEALTH +20 source.
  - A non-player `VitalsManager` with `character_attributes_data = CharacterAttributesData.new()` has `max_health == 100.0`.

`test_dev_hooks.gd`: the "old manager's hook went with it" check counts `CharacterManager.stats_changed.get_connections()`.

- [ ] **Step 2: Run them to verify they fail**

Expected:
- errors for the missing `get_stat`, `set_modifier_source`, `get_stat_modifiers` and `stats_changed`;
- the reset test fails with 14.0.

- [ ] **Step 3: Implement**

`EquipmentDefinitionData.get_stat_modifiers()`: map each key through `StatModifierData.for_attribute`.

`CharacterManager`:
- `var _modifiers: StatModifierStack = StatModifierStack.new()`. Register `&"gear"` → `_gear_modifiers` in `_ready`.
- `_gear_modifiers()` walks `live_save_data.inventory.equipped_gear` and `equipped_accessories`. It returns `[]` when the save or its inventory is null.
- `get_stat()`:
  - for an attribute: the base from `live_save_data.character_attributes`;
  - for MAX_HEALTH / MAX_STAMINA / MAX_MADRA: the matching getter on `get_total_attributes_data()`;
  - then `_modifiers.apply(stat, base)`.
- `get_total_attributes_data()` builds `CharacterAttributesData.new(...)` from `get_stat(StatModifierData.for_attribute(a))` for the eight attributes in enum order.
- Delete the eight getters, `_get_attribute_bonuses()`, `_get_equipment_bonuses()` and `_bonus_from_instance()`.
- Rename the signal and its emits, and update its doc comment to list the four triggers.

`VitalsManager`:
- the player connects `stats_changed` to `_on_stats_changed()`;
- `_on_stats_changed()` sets `max_health`, `max_stamina` and `max_madra` from `CharacterManager.get_stat(...)`;
- the player path no longer touches `character_attributes_data`.

`ResourceManager.get_adventure_madra_capacity()` returns `CharacterManager.get_stat(StatModifierData.Stat.MAX_MADRA)`.

`AdventurePresenter`: rename the signal and its handler.

- [ ] **Step 4: Run the tests**

Run the four test files above, plus `tests/unit/test_resource_manager.gd`, `tests/integration/test_adventure_flow.gd` and `tests/integration/test_adventure_view_frame.gd`. Expected: all pass.

- [ ] **Step 5: Commit**

`refactor(character): move gear onto the modifier layer`

---

### Task 4: Verify and open the PR

- [ ] **Step 1: Run the full suite**

`powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`. Expected: all pass. Rerun any failure in one process before investigating.

- [ ] **Step 2: Check `git diff main --stat`**

No living docs, `.import` or `project.godot` changes.

- [ ] **Step 3: Push and open the PR**

- **Title:** `feat(character): stat modifier layer and derived vitals`
- **Body:**
  - covers the gear fix, the layer, and the decision table (linking the spec);
  - ends with `## Docs to update` copied from the spec.
