# Empty Palm & Power Font Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Empty Palm as the main Pure Madra DPS with a built-in cast-interrupt, and Power Font as a heavy-commit finisher that wipes all enemy buffs. Spec: [docs/superpowers/specs/2026-04-20-empty-palm-power-font-redesign-design.md](../specs/2026-04-20-empty-palm-power-font-redesign-design.md).

**Architecture:** Add two new `CombatEffectData.EffectType` values — `CANCEL_CAST` and `STRIP_BUFFS` — that dispatch through the existing `CombatEffectManager.process_effect` pipeline. Cast cancellation gets a new public method on `CombatAbilityInstance` plus a helper on `CombatAbilityManager`. Buff stripping reuses the existing `CombatBuffManager` via a new `strip_all_buffs()` method. Each ability's `.tres` resource gets a second effect entry so existing ability execution naturally applies both damage and the rider effect. An enemy cast-bar UI is added to `CombatantInfoPanel` so the interrupt window is visible to the player.

**Tech Stack:** Godot 4.6, GDScript, GUT v9.6.0 for tests.

**Bottom-up build order:** enum → data class methods → manager helpers → effect dispatch → ability data → UI → integration tests. Each task ends in a commit.

**Running tests (reused in every task):**
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/<file>.gd -gexit
```
Full suite (unit + integration):
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
If class names don't resolve, pre-import once:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

---

## File Structure

**New files:**
- `tests/unit/test_combat_ability_instance_cancel.gd` — cancel_cast behavior
- `tests/unit/test_combat_buff_manager_strip.gd` — strip_all_buffs behavior
- `tests/unit/test_combat_effect_types.gd` — new effect type dispatch
- `tests/integration/test_empty_palm_interrupt.gd` — end-to-end interrupt flow
- `tests/integration/test_power_font_buff_strip.gd` — end-to-end buff wipe flow
- `scenes/ui/combat/combatant_info_panel/enemy_cast_bar.tscn` + `.gd` — enemy cast-progress UI

**Modified files:**
- `scripts/resource_definitions/combat/combat_effect_data.gd` — add `CANCEL_CAST`, `STRIP_BUFFS` to `EffectType` enum
- `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd` — add `cancel_cast()` + `cast_cancelled` signal
- `scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd` — add `cancel_current_cast()` helper
- `scenes/combat/combatant/combat_buff_manager/combat_buff_manager.gd` — add `strip_all_buffs()`
- `scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd` — route new effect types
- `scenes/ui/combat/combatant_info_panel/combatant_info_panel.tscn` + `.gd` — embed enemy cast bar
- `resources/abilities/empty_palm.tres` — new values + second effect
- `resources/abilities/power_font.tres` — new values + second effect

**Not modified (intentionally):**
- Path tree nodes under `resources/path_progression/pure_madra/` — ability IDs and path graph are unchanged.
- `resources/abilities/ability_list.tres` — abilities keep their IDs.

---

### Task 1: Add `CANCEL_CAST` and `STRIP_BUFFS` to `CombatEffectData.EffectType`

**Files:**
- Modify: `scripts/resource_definitions/combat/combat_effect_data.gd:12-16`
- Test: `tests/unit/test_combat_damage.gd:217-221` (enum value test)

- [ ] **Step 1: Write the failing enum-value test.**

Open `tests/unit/test_combat_damage.gd`. Find `test_effect_type_enum_values()`:

```gdscript
func test_effect_type_enum_values() -> void:
	assert_eq(CombatEffectData.EffectType.DAMAGE, 0)
	assert_eq(CombatEffectData.EffectType.HEAL, 1)
	assert_eq(CombatEffectData.EffectType.BUFF, 2)
```

Replace it with:
```gdscript
func test_effect_type_enum_values() -> void:
	assert_eq(CombatEffectData.EffectType.DAMAGE, 0)
	assert_eq(CombatEffectData.EffectType.HEAL, 1)
	assert_eq(CombatEffectData.EffectType.BUFF, 2)
	assert_eq(CombatEffectData.EffectType.CANCEL_CAST, 3)
	assert_eq(CombatEffectData.EffectType.STRIP_BUFFS, 4)
```

- [ ] **Step 2: Run the test to confirm it fails.**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat_damage.gd -gexit
```
Expected: test fails with "Invalid get index 'CANCEL_CAST'" (or similar parse error).

- [ ] **Step 3: Edit the enum in `combat_effect_data.gd`.**

Change lines 12–16 in `scripts/resource_definitions/combat/combat_effect_data.gd` from:
```gdscript
enum EffectType {
	DAMAGE, ## Deal damage to target
	HEAL, ## Restore health to target
	BUFF, ## Apply a buff or debuff
}
```
to:
```gdscript
enum EffectType {
	DAMAGE, ## Deal damage to target
	HEAL, ## Restore health to target
	BUFF, ## Apply a buff or debuff
	CANCEL_CAST, ## Cancel target's current cast if any
	STRIP_BUFFS, ## Remove all active buffs on target
}
```

- [ ] **Step 4: Run the test to confirm it passes.**

Run the same command. Expected: all tests in the file pass.

- [ ] **Step 5: Commit.**

```bash
git add scripts/resource_definitions/combat/combat_effect_data.gd tests/unit/test_combat_damage.gd
git commit -m "feat(combat): add CANCEL_CAST and STRIP_BUFFS effect types"
```

---

### Task 2: Add `cancel_cast()` and `cast_cancelled` signal to `CombatAbilityInstance`

**Files:**
- Modify: `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd`
- Create: `tests/unit/test_combat_ability_instance_cancel.gd`

- [ ] **Step 1: Write the failing tests.**

Create `tests/unit/test_combat_ability_instance_cancel.gd`:
```gdscript
extends GutTest

## Tests for CombatAbilityInstance.cancel_cast() behavior.
## Verifies mid-cast cancellation, signal emission, and post-cancel cooldown.

var _ability_data: AbilityData
var _owner: Node  # Stand-in; we only need owner.combatant_data for logging
var _instance: CombatAbilityInstance

func before_each() -> void:
	_ability_data = AbilityData.new()
	_ability_data.ability_id = "test_cast"
	_ability_data.ability_name = "Test Cast"
	_ability_data.cast_time = 2.0
	_ability_data.base_cooldown = 5.0

	# Owner is only referenced in logs; a bare Node works as a stand-in.
	_owner = Node.new()
	_owner.set_meta("combatant_data", {"character_name": "Tester"})
	add_child_autofree(_owner)

	_instance = CombatAbilityInstance.new(_ability_data, _owner)
	add_child_autofree(_instance)

func test_cancel_cast_while_casting_stops_timer() -> void:
	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	_instance.cancel_cast()
	assert_false(_instance.is_casting, "is_casting should be false after cancel")
	assert_true(_instance.cast_timer.is_stopped(), "cast_timer should be stopped")

func test_cancel_cast_emits_signal() -> void:
	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	watch_signals(_instance)
	_instance.cancel_cast()
	assert_signal_emitted(_instance, "cast_cancelled",
		"cast_cancelled signal should fire on successful cancel")

func test_cancel_cast_starts_cooldown() -> void:
	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	_instance.cancel_cast()
	assert_false(_instance.cooldown_timer.is_stopped(),
		"cooldown_timer should start after cancel to prevent re-cast spam")

func test_cancel_cast_when_not_casting_is_noop() -> void:
	# Not casting, cooldown already stopped
	_instance.is_casting = false
	_instance.cooldown_timer.stop()
	watch_signals(_instance)
	_instance.cancel_cast()
	assert_signal_not_emitted(_instance, "cast_cancelled",
		"cast_cancelled should NOT fire when no cast in progress")
	assert_true(_instance.cooldown_timer.is_stopped(),
		"cooldown should remain untouched when no cast to cancel")
```

**Note:** `CombatAbilityInstance._init` stores `owner_combatant` for log strings only — the tests use a bare `Node` with a meta field so signal/timer behavior can be validated in isolation. If `_init` touches `owner_combatant.combatant_data` directly, adjust the stand-in accordingly when it fails.

- [ ] **Step 2: Run tests to confirm they fail.**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat_ability_instance_cancel.gd -gexit
```
Expected: all tests fail because `cancel_cast()` and `cast_cancelled` don't exist.

- [ ] **Step 3: Add the signal and method.**

In `scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd`, add the signal after line 41 (alongside `cast_finished`):
```gdscript
signal cast_cancelled(instance: CombatAbilityInstance)
```

Add a new public method in the `PUBLIC API` section (after `execute_ability()`, before `INTERNAL LOGIC`):
```gdscript
## Cancels an in-progress cast. Stops the cast timer, resets casting state,
## starts the ability's cooldown, and emits cast_cancelled.
## No-op if not currently casting.
func cancel_cast() -> void:
	if not is_casting:
		return

	is_casting = false
	cast_timer.stop()
	_current_target = null
	_start_cooldown(ability_data.base_cooldown)
	cast_cancelled.emit(self)
	Log.info("CombatAbilityInstance: Cancelled cast of %s" % ability_data.ability_name)
```

- [ ] **Step 4: Run tests to confirm they pass.**

Run the same command as Step 2. Expected: 4/4 pass.

- [ ] **Step 5: Commit.**

```bash
git add scenes/combat/combatant/combat_ability_manager/combat_ability_instance.gd tests/unit/test_combat_ability_instance_cancel.gd
git commit -m "feat(combat): add cancel_cast() method and cast_cancelled signal"
```

---

### Task 3: Add `cancel_current_cast()` helper to `CombatAbilityManager`

**Why:** External effects (like Empty Palm's CANCEL_CAST rider) need a way to cancel whatever the target is currently casting, without knowing which specific ability instance is the one active.

**Files:**
- Modify: `scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd`
- Test: extend `tests/unit/test_combat_ability_instance_cancel.gd` (or add a new file; keep in one file for cohesion)

- [ ] **Step 1: Write the failing test.**

Append to `tests/unit/test_combat_ability_instance_cancel.gd`:
```gdscript
# ---- CombatAbilityManager.cancel_current_cast() ----

func test_manager_cancel_current_cast_cancels_casting_instance() -> void:
	var manager := CombatAbilityManager.new()
	add_child_autofree(manager)
	# Directly populate abilities array to bypass setup() data dependency
	manager.abilities = [_instance]

	_instance.is_casting = true
	_instance.cast_timer.start(2.0)
	watch_signals(_instance)

	var cancelled: bool = manager.cancel_current_cast()

	assert_true(cancelled, "cancel_current_cast should return true when a cast was cancelled")
	assert_false(_instance.is_casting, "casting instance should be cancelled")
	assert_signal_emitted(_instance, "cast_cancelled")

func test_manager_cancel_current_cast_noop_when_nothing_casting() -> void:
	var manager := CombatAbilityManager.new()
	add_child_autofree(manager)
	manager.abilities = [_instance]

	_instance.is_casting = false
	var cancelled: bool = manager.cancel_current_cast()
	assert_false(cancelled, "cancel_current_cast should return false when nothing is casting")
```

- [ ] **Step 2: Run tests to confirm they fail.**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat_ability_instance_cancel.gd -gexit
```
Expected: new tests fail (`cancel_current_cast` not defined).

- [ ] **Step 3: Add the helper.**

In `scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd`, add a new public method after `is_casting()`:
```gdscript
## Cancels the currently-casting ability if one exists. Returns true if a cast
## was cancelled, false otherwise. Used by external effects (e.g. Empty Palm's
## CANCEL_CAST rider) to interrupt the target mid-cast.
func cancel_current_cast() -> bool:
	for ability: CombatAbilityInstance in abilities:
		if ability.is_casting:
			ability.cancel_cast()
			return true
	return false
```

- [ ] **Step 4: Run tests to confirm they pass.**

Run the same command as Step 2. Expected: all tests in the file pass.

- [ ] **Step 5: Commit.**

```bash
git add scenes/combat/combatant/combat_ability_manager/combat_ability_manager.gd tests/unit/test_combat_ability_instance_cancel.gd
git commit -m "feat(combat): add cancel_current_cast helper on CombatAbilityManager"
```

---

### Task 4: Add `strip_all_buffs()` to `CombatBuffManager`

**Files:**
- Modify: `scenes/combat/combatant/combat_buff_manager/combat_buff_manager.gd`
- Create: `tests/unit/test_combat_buff_manager_strip.gd`

- [ ] **Step 1: Write the failing tests.**

Create `tests/unit/test_combat_buff_manager_strip.gd`:
```gdscript
extends GutTest

## Tests for CombatBuffManager.strip_all_buffs() — mid-combat buff wipe.

var _manager: CombatBuffManager

func before_each() -> void:
	_manager = CombatBuffManager.new()
	add_child_autofree(_manager)

func _make_buff(buff_id: String) -> BuffEffectData:
	var b := BuffEffectData.new()
	b.buff_id = buff_id
	b.effect_name = buff_id
	b.duration = 10.0
	b.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	return b

func test_strip_all_buffs_removes_every_buff() -> void:
	_manager.apply_buff(_make_buff("buff_a"))
	_manager.apply_buff(_make_buff("buff_b"))
	_manager.apply_buff(_make_buff("buff_c"))
	assert_eq(_manager.active_buffs.size(), 3)

	_manager.strip_all_buffs()
	assert_eq(_manager.active_buffs.size(), 0,
		"All active buffs should be removed")

func test_strip_all_buffs_emits_removed_per_buff() -> void:
	_manager.apply_buff(_make_buff("buff_a"))
	_manager.apply_buff(_make_buff("buff_b"))
	watch_signals(_manager)

	_manager.strip_all_buffs()

	assert_signal_emit_count(_manager, "buff_removed", 2,
		"buff_removed should emit once per stripped buff")

func test_strip_all_buffs_with_no_buffs_is_noop() -> void:
	watch_signals(_manager)
	_manager.strip_all_buffs()
	assert_signal_emit_count(_manager, "buff_removed", 0)
	assert_eq(_manager.active_buffs.size(), 0)

func test_strip_all_buffs_stops_dot_timer() -> void:
	var dot := BuffEffectData.new()
	dot.buff_id = "test_dot"
	dot.effect_name = "Test DoT"
	dot.duration = 10.0
	dot.buff_type = BuffEffectData.BuffType.DAMAGE_OVER_TIME
	dot.dot_damage_per_tick = 5.0
	_manager.apply_buff(dot)
	assert_false(_manager._dot_timer.is_stopped(),
		"DoT timer should run while a DoT buff is active")

	_manager.strip_all_buffs()
	assert_true(_manager._dot_timer.is_stopped(),
		"DoT timer should stop once all DoT buffs are stripped")
```

- [ ] **Step 2: Run tests to confirm they fail.**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat_buff_manager_strip.gd -gexit
```
Expected: all tests fail (method doesn't exist).

- [ ] **Step 3: Add the method.**

In `scenes/combat/combatant/combat_buff_manager/combat_buff_manager.gd`, add a new public method in the `PUBLIC API - Buff Application` section (after `clear_all_buffs()`):
```gdscript
## Strips every active buff from this combatant as a mid-combat operation.
## Emits buff_removed for each buff removed and stops the DoT timer if no
## DoT buffs remain. Different from clear_all_buffs(), which is for combat end.
func strip_all_buffs() -> void:
	if active_buffs.is_empty():
		return

	var to_remove: Array[ActiveBuff] = active_buffs.duplicate()
	for buff in to_remove:
		_remove_buff(buff)
	Log.info("CombatBuffManager: Stripped %d buffs" % to_remove.size())
```

**Note:** `_remove_buff()` already emits `buff_removed` and stops the DoT timer when no DoT buffs remain, so this method doesn't need to duplicate that logic.

- [ ] **Step 4: Run tests to confirm they pass.**

Run the same command as Step 2. Expected: 4/4 pass.

- [ ] **Step 5: Commit.**

```bash
git add scenes/combat/combatant/combat_buff_manager/combat_buff_manager.gd tests/unit/test_combat_buff_manager_strip.gd
git commit -m "feat(combat): add strip_all_buffs for mid-combat buff wipe"
```

---

### Task 5: Route `CANCEL_CAST` and `STRIP_BUFFS` in `CombatEffectManager.process_effect`

**Files:**
- Modify: `scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd`
- Create: `tests/unit/test_combat_effect_types.gd`

- [ ] **Step 1: Write the failing tests.**

Create `tests/unit/test_combat_effect_types.gd`:
```gdscript
extends GutTest

## Tests that CombatEffectManager routes CANCEL_CAST and STRIP_BUFFS
## effects to the correct target-side managers.

var _target_node: CombatantNode
var _effect_manager: CombatEffectManager
var _ability_manager: CombatAbilityManager
var _buff_manager: CombatBuffManager
var _source_attributes: CharacterAttributesData

func before_each() -> void:
	_target_node = CombatantNode.new()
	add_child_autofree(_target_node)

	# Stub the managers the effect manager reaches into
	_ability_manager = CombatAbilityManager.new()
	_buff_manager = CombatBuffManager.new()
	_target_node.add_child(_ability_manager)
	_target_node.add_child(_buff_manager)
	_target_node.ability_manager = _ability_manager
	_target_node.buff_manager = _buff_manager
	# vitals_manager is queried for non-cancel/strip paths; stub enough to not crash
	var vitals := VitalsManager.new()
	_target_node.add_child(vitals)
	_target_node.vitals_manager = vitals

	_effect_manager = CombatEffectManager.new()
	add_child_autofree(_effect_manager)
	_effect_manager.setup(_target_node)

	_source_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)

func test_cancel_cast_effect_calls_cancel_current_cast() -> void:
	# Fake a casting ability on the target
	var ability_data := AbilityData.new()
	ability_data.ability_id = "dummy"
	ability_data.cast_time = 2.0
	var ability_instance := CombatAbilityInstance.new(ability_data, _target_node)
	_ability_manager.add_child(ability_instance)
	_ability_manager.abilities = [ability_instance]
	ability_instance.is_casting = true
	ability_instance.cast_timer.start(2.0)

	var cancel_effect := CombatEffectData.new()
	cancel_effect.effect_type = CombatEffectData.EffectType.CANCEL_CAST
	cancel_effect.effect_name = "Test Cancel"

	_effect_manager.process_effect(cancel_effect, _source_attributes, 1.0)

	assert_false(ability_instance.is_casting,
		"Target's casting ability should be cancelled by CANCEL_CAST effect")

func test_cancel_cast_effect_noop_when_target_not_casting() -> void:
	var cancel_effect := CombatEffectData.new()
	cancel_effect.effect_type = CombatEffectData.EffectType.CANCEL_CAST

	# No abilities casting — should not crash, no side effects
	_effect_manager.process_effect(cancel_effect, _source_attributes, 1.0)
	pass_test("CANCEL_CAST no-ops safely when nothing is casting")

func test_strip_buffs_effect_removes_active_buffs() -> void:
	var b := BuffEffectData.new()
	b.buff_id = "pre_existing"
	b.effect_name = "Pre"
	b.duration = 10.0
	b.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	_buff_manager.apply_buff(b)
	assert_eq(_buff_manager.active_buffs.size(), 1)

	var strip_effect := CombatEffectData.new()
	strip_effect.effect_type = CombatEffectData.EffectType.STRIP_BUFFS
	strip_effect.effect_name = "Test Strip"

	_effect_manager.process_effect(strip_effect, _source_attributes, 1.0)

	assert_eq(_buff_manager.active_buffs.size(), 0,
		"STRIP_BUFFS effect should remove all active buffs on the target")
```

- [ ] **Step 2: Run tests to confirm they fail.**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_combat_effect_types.gd -gexit
```
Expected: tests fail (match statement has no case for new types).

- [ ] **Step 3: Extend `process_effect` to handle new types.**

> **Note on `owner_combatant`:** `CombatEffectManager` lives as a child of a `CombatantNode`, and `CombatantNode.receive_effect()` dispatches into its *own* effect manager. So inside `process_effect`, `owner_combatant` is always the **target** (the combatant receiving the effect), and `source_attributes` belongs to the caster. When the player's Empty Palm is applied to an enemy, the enemy's effect manager runs the `CANCEL_CAST` case and `owner_combatant` resolves to the enemy — which is what we want to cancel.

In `scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd`, extend the `match effect.effect_type` block inside `process_effect()` (after the existing `BUFF` case, before the closing `pass`):

```gdscript
		CombatEffectData.EffectType.CANCEL_CAST:
			# owner_combatant here = the target of this effect (see note above).
			# Cancel the target's in-progress cast if any.
			if owner_combatant.ability_manager:
				var cancelled: bool = owner_combatant.ability_manager.cancel_current_cast()
				if cancelled:
					Log.info("CombatEffectManager: %s's cast was cancelled by %s" % [
						owner_combatant.combatant_data.character_name, effect.effect_name])
					if LogManager:
						LogManager.log_message("[b]%s[/b]'s cast was [color=cyan]interrupted[/color]!" % owner_combatant.combatant_data.character_name)
			else:
				Log.error("CombatEffectManager: Cannot cancel cast - missing ability_manager")

		CombatEffectData.EffectType.STRIP_BUFFS:
			# owner_combatant here = the target of this effect (see note above).
			# Strip all buffs currently on the target.
			if owner_combatant.buff_manager:
				owner_combatant.buff_manager.strip_all_buffs()
				Log.info("CombatEffectManager: %s's buffs stripped by %s" % [
					owner_combatant.combatant_data.character_name, effect.effect_name])
				if LogManager:
					LogManager.log_message("[b]%s[/b]'s buffs were [color=cyan]stripped[/color]!" % owner_combatant.combatant_data.character_name)
			else:
				Log.error("CombatEffectManager: Cannot strip buffs - missing buff_manager")
```

**Note:** If the existing `match` ends without an explicit default, simply append the two new `case` blocks. The `combatant_data.character_name` lookup matches the style used in the existing `DAMAGE` case.

- [ ] **Step 4: Run tests to confirm they pass.**

Run the same command as Step 2. Expected: 3/3 pass.

If the test setup fails during `before_each` because `CombatantNode` / `VitalsManager` require additional wiring (for instance, `combatant_data` being non-null), stub the minimum state the `process_effect` logs read. Do not alter production code to accommodate test stubs — extend the stubbing in the test.

- [ ] **Step 5: Commit.**

```bash
git add scenes/combat/combatant/combat_effect_manager/combat_effect_manager.gd tests/unit/test_combat_effect_types.gd
git commit -m "feat(combat): route CANCEL_CAST and STRIP_BUFFS effects"
```

---

### Task 6: Rebalance `empty_palm.tres` (new values + CANCEL_CAST rider)

**Files:**
- Modify: `resources/abilities/empty_palm.tres`

- [ ] **Step 1: Inspect the current file.**

Open `resources/abilities/empty_palm.tres`. Current contents assign:
- `madra_cost = 12.0`
- `stamina_cost = 3.0`
- `base_cooldown = 3.0`
- single damage effect: `base_value = 10.0, agility_scaling = 0.3, spirit_scaling = 1.0`

- [ ] **Step 2: Replace the file contents with the redesigned version.**

Overwrite `resources/abilities/empty_palm.tres` with:

```tres
[gd_resource type="Resource" script_class="AbilityData" format=3 uid="uid://4ddominxr0ph"]

[ext_resource type="Script" uid="uid://bnd52oeyddekj" path="res://scripts/resource_definitions/combat/combat_effect_data.gd" id="1_lurdt"]
[ext_resource type="Script" uid="uid://cmwib0b1jyoa8" path="res://scripts/resource_definitions/abilities/ability_data.gd" id="2_34div"]
[ext_resource type="Texture2D" uid="uid://djrbdgn6s8xmq" path="res://assets/sprites/abilities/empty_palm.png" id="2_gtwq6"]

[sub_resource type="Resource" id="Resource_damage"]
script = ExtResource("1_lurdt")
effect_type = 0
effect_name = "Empty Palm Strike"
base_value = 15.0
agility_scaling = 0.3
spirit_scaling = 1.0
damage_type = 1
metadata/_custom_type_script = "uid://bnd52oeyddekj"

[sub_resource type="Resource" id="Resource_cancel"]
script = ExtResource("1_lurdt")
effect_type = 3
effect_name = "Disrupting Palm"
metadata/_custom_type_script = "uid://bnd52oeyddekj"

[resource]
script = ExtResource("2_34div")
ability_id = "empty_palm"
ability_name = "Empty Palm"
description = "A focused Pure Madra strike. Cancels the target's current cast if any."
icon = ExtResource("2_gtwq6")
madra_type = 1
ability_source = 1
madra_cost = 8.0
base_cooldown = 3.0
cast_time = 0.0
effects = Array[ExtResource("1_lurdt")]([SubResource("Resource_damage"), SubResource("Resource_cancel")])
metadata/_custom_type_script = "uid://cmwib0b1jyoa8"
```

**Key changes vs. original:**
- `madra_cost`: 12 → 8
- `stamina_cost`: 3 → removed (not in the redesigned spec)
- `cast_time`: implicit default → explicit 0.0
- `base_cooldown`: unchanged at 3.0
- Damage effect `base_value`: 10 → 15, `damage_type = 1` (SPIRIT) set explicitly
- Damage effect gains `effect_name` so log lines read cleanly
- **New second effect:** `effect_type = 3` (CANCEL_CAST)

- [ ] **Step 3: Open the project in the editor once to bake UIDs.**

Godot silently generates `.tres` UIDs on first import. If the `SubResource` IDs collide with cached UIDs, reimport by launching the editor for ~5 seconds and closing:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . --editor
```
Close the editor. Then confirm the file still parses:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
No errors about `empty_palm.tres` should appear.

- [ ] **Step 4: Smoke-check by running the whole test suite.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
All previously-passing tests should continue to pass. No behavior test exists for this resource yet — Task 9 covers the integration test.

- [ ] **Step 5: Commit.**

```bash
git add resources/abilities/empty_palm.tres
git commit -m "feat(abilities): rebalance Empty Palm as interrupt-capable main DPS

- Madra cost 12 -> 8, base damage 10 -> 15
- Instant cast (cast_time 0), CD unchanged at 3s
- New CANCEL_CAST effect rider cancels target's current cast"
```

---

### Task 7: Rebalance `power_font.tres` (new values + STRIP_BUFFS rider)

**Files:**
- Modify: `resources/abilities/power_font.tres`

- [ ] **Step 1: Inspect the current file.**

Current contents:
- `madra_cost = 20.0`
- `base_cooldown = 15.0`
- `cast_time = 3.0`
- single damage effect: `base_value = 30.0, spirit_scaling = 1.5, foundation_scaling = 0.5, damage_type = 1` (SPIRIT)

- [ ] **Step 2: Replace the file contents.**

Overwrite `resources/abilities/power_font.tres` with:
```tres
[gd_resource type="Resource" script_class="AbilityData" format=3 uid="uid://c6kj8se7d887c"]

[ext_resource type="Script" uid="uid://bnd52oeyddekj" path="res://scripts/resource_definitions/combat/combat_effect_data.gd" id="1_ys7rd"]
[ext_resource type="Texture2D" uid="uid://dppmky4a5xje" path="res://assets/sprites/abilities/power_font.png" id="2_1ymsf"]
[ext_resource type="Script" uid="uid://cmwib0b1jyoa8" path="res://scripts/resource_definitions/abilities/ability_data.gd" id="2_6gbj8"]

[sub_resource type="Resource" id="Resource_damage"]
script = ExtResource("1_ys7rd")
effect_type = 0
effect_name = "Sundering Font"
base_value = 30.0
spirit_scaling = 1.5
foundation_scaling = 0.5
damage_type = 1
metadata/_custom_type_script = "uid://bnd52oeyddekj"

[sub_resource type="Resource" id="Resource_strip"]
script = ExtResource("1_ys7rd")
effect_type = 4
effect_name = "Sunder All Buffs"
metadata/_custom_type_script = "uid://bnd52oeyddekj"

[resource]
script = ExtResource("2_6gbj8")
ability_id = "power_font"
ability_name = "Power Font"
description = "Channel your body's Madra and release it in a cleansing wave — heavy damage and wipes every buff on the target."
icon = ExtResource("2_1ymsf")
madra_type = 1
ability_source = 1
madra_cost = 30.0
base_cooldown = 25.0
cast_time = 3.0
effects = Array[ExtResource("1_ys7rd")]([SubResource("Resource_damage"), SubResource("Resource_strip")])
metadata/_custom_type_script = "uid://cmwib0b1jyoa8"
```

**Key changes vs. original:**
- `madra_cost`: 20 → 30
- `base_cooldown`: 15 → 25
- Damage effect gains `effect_name` ("Sundering Font")
- **New second effect:** `effect_type = 4` (STRIP_BUFFS)
- Base damage and scalings unchanged (30 base, spi 1.5, fnd 0.5)

- [ ] **Step 3: Reimport.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```
No errors about `power_font.tres` should appear.

- [ ] **Step 4: Smoke-check the test suite.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
All previously-passing tests continue to pass.

- [ ] **Step 5: Commit.**

```bash
git add resources/abilities/power_font.tres
git commit -m "feat(abilities): rebalance Power Font as buff-stripping finisher

- Madra cost 20 -> 30, CD 15s -> 25s, cast time unchanged (3s)
- Base damage and scalings unchanged
- New STRIP_BUFFS effect rider wipes every buff on the target"
```

---

### Task 8: Add enemy cast-bar UI to `CombatantInfoPanel`

**Why:** Empty Palm's interrupt rider is only readable if the player sees the enemy's cast. Without a visible cast bar on the enemy panel, canceling a cast is invisible and frustrating.

**Files:**
- Modify: `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd`
- Modify: `scenes/ui/combat/combatant_info_panel/combatant_info_panel.tscn`

- [ ] **Step 1: Open the info panel scene in the Godot editor.**

Open the project and open `scenes/ui/combat/combatant_info_panel/combatant_info_panel.tscn`. You will add a `ProgressBar` and a `Label` under the existing layout, between `BuffContainer` and `AbilitiesPanel`.

- [ ] **Step 2: Add cast-bar nodes to the scene tree.**

Under the root `CombatantInfoPanel`'s main `VBoxContainer` (or wherever `BuffContainer` and `AbilitiesPanel` currently live — check the existing `.tscn` structure), add a new `VBoxContainer` named `CastBarContainer` with a unique name (`%CastBarContainer`). Inside it:
- `ProgressBar` node named `CastProgressBar` (unique name: `%CastProgressBar`). Min 0, max 1, initial value 0.
- `Label` named `CastNameLabel` (unique name: `%CastNameLabel`). Empty text by default.

Set `CastBarContainer.visible = false` by default.

Save the scene.

- [ ] **Step 3: Write the new handlers in `combatant_info_panel.gd`.**

In `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd`, add new `@onready` fields near the other `@onready` references (around line 15):
```gdscript
@onready var cast_bar_container: VBoxContainer = %CastBarContainer
@onready var cast_progress_bar: ProgressBar = %CastProgressBar
@onready var cast_name_label: Label = %CastNameLabel
```

Extend `setup_abilities()` (around line 107) so it connects cast signals from each registered instance. Inside the existing loop that iterates `ability_manager.abilities`, after `_register_ability(ability_instance)`, add:
```gdscript
		_connect_cast_signals(ability_instance)
```

Then add a private helper and handlers (place them in a new section, below the ABILITY HANDLERS section):
```gdscript
#-----------------------------------------------------------------------------
# CAST BAR HANDLERS
#-----------------------------------------------------------------------------

func _connect_cast_signals(instance: CombatAbilityInstance) -> void:
	if not instance.cast_started.is_connected(_on_cast_started):
		instance.cast_started.connect(_on_cast_started)
	if not instance.cast_updated.is_connected(_on_cast_updated):
		instance.cast_updated.connect(_on_cast_updated)
	if not instance.cast_finished.is_connected(_on_cast_finished):
		instance.cast_finished.connect(_on_cast_finished)
	if not instance.cast_cancelled.is_connected(_on_cast_cancelled):
		instance.cast_cancelled.connect(_on_cast_cancelled)

func _on_cast_started(instance: CombatAbilityInstance, duration: float) -> void:
	cast_bar_container.visible = true
	cast_progress_bar.max_value = duration
	cast_progress_bar.value = 0.0
	cast_name_label.text = instance.ability_data.ability_name

func _on_cast_updated(_instance: CombatAbilityInstance, time_left: float) -> void:
	cast_progress_bar.value = cast_progress_bar.max_value - time_left

func _on_cast_finished(_instance: CombatAbilityInstance) -> void:
	cast_bar_container.visible = false
	cast_progress_bar.value = 0.0
	cast_name_label.text = ""

func _on_cast_cancelled(_instance: CombatAbilityInstance) -> void:
	# TODO: VFX pass — shatter animation goes here. For now, hide immediately.
	cast_bar_container.visible = false
	cast_progress_bar.value = 0.0
	cast_name_label.text = ""
```

- [ ] **Step 4: Wire existing `_on_ability_manager_exiting` cleanup (optional safety).**

Signal connections auto-break when the `CombatAbilityInstance` nodes are freed. No additional cleanup is strictly required, but if the existing panel tracks ability instances in a list (review `abilities_panel.gd` for the reference), match the same pattern.

- [ ] **Step 5: Smoke-test in-game.**

Run the game:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```
Enter an adventure combat. When an enemy starts casting, the cast bar on their info panel should appear and fill over the cast duration. When the cast completes or is cancelled, the bar hides.

**Expected:** Enemy cast bar is visible during enemy casts. Cancelling via Empty Palm (next task) will verify the cancel path.

- [ ] **Step 6: Commit.**

```bash
git add scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd scenes/ui/combat/combatant_info_panel/combatant_info_panel.tscn
git commit -m "feat(combat-ui): show enemy cast progress in CombatantInfoPanel"
```

**Note on VFX:** Per the spec, the cancel-cast rider still needs a feedback pass (screen-shake + SFX + cast-bar shatter). That asset work is tracked separately — this task ships the structural UI only. The `TODO` comment in `_on_cast_cancelled` marks the handoff.

---

### Task 9: Integration test — Empty Palm interrupts enemy cast

**Files:**
- Create: `tests/integration/test_empty_palm_interrupt.gd`

- [ ] **Step 1: Write the integration test.**

Create `tests/integration/test_empty_palm_interrupt.gd`:
```gdscript
extends GutTest

## Integration test: Empty Palm's CANCEL_CAST effect cancels an enemy cast.
## Uses the real combat effect pipeline end-to-end.

const EMPTY_PALM_PATH := "res://resources/abilities/empty_palm.tres"

var _target: CombatantNode
var _source_attributes: CharacterAttributesData

func before_each() -> void:
	_target = CombatantNode.new()
	add_child_autofree(_target)

	var ability_manager := CombatAbilityManager.new()
	var buff_manager := CombatBuffManager.new()
	var effect_manager := CombatEffectManager.new()
	var vitals_manager := VitalsManager.new()
	_target.add_child(ability_manager)
	_target.add_child(buff_manager)
	_target.add_child(effect_manager)
	_target.add_child(vitals_manager)
	_target.ability_manager = ability_manager
	_target.buff_manager = buff_manager
	_target.effect_manager = effect_manager
	_target.vitals_manager = vitals_manager

	# Give the target a dummy long-cast ability and simulate mid-cast
	var long_cast_data := AbilityData.new()
	long_cast_data.ability_id = "enemy_long_cast"
	long_cast_data.ability_name = "Enemy Long Cast"
	long_cast_data.cast_time = 3.0
	long_cast_data.base_cooldown = 5.0
	var long_cast := CombatAbilityInstance.new(long_cast_data, _target)
	ability_manager.add_child(long_cast)
	ability_manager.abilities = [long_cast]
	long_cast.is_casting = true
	long_cast.cast_timer.start(3.0)

	# Attach minimal combatant_data so log strings work
	var combatant_data := CombatantData.new()
	combatant_data.character_name = "Enemy"
	combatant_data.attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_target.combatant_data = combatant_data
	vitals_manager.character_attributes_data = combatant_data.attributes
	vitals_manager.initialize_current_values()
	effect_manager.setup(_target)

	_source_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 15.0, 10.0, 10.0, 10.0)

func test_empty_palm_applied_to_casting_target_cancels_cast() -> void:
	var ability: AbilityData = load(EMPTY_PALM_PATH)
	assert_not_null(ability, "empty_palm.tres must load")

	# Apply each of Empty Palm's effects to the target
	for effect in ability.effects:
		_target.receive_effect(effect, _source_attributes, 1.0)

	var long_cast: CombatAbilityInstance = _target.ability_manager.abilities[0]
	assert_false(long_cast.is_casting,
		"Target's cast should be cancelled after Empty Palm's effects apply")
	assert_false(_target.vitals_manager.current_health == _target.vitals_manager.max_health,
		"Target should also have taken damage from Empty Palm")

func test_empty_palm_applied_to_noncasting_target_only_damages() -> void:
	var long_cast: CombatAbilityInstance = _target.ability_manager.abilities[0]
	long_cast.is_casting = false
	long_cast.cast_timer.stop()

	var starting_health: float = _target.vitals_manager.current_health
	var ability: AbilityData = load(EMPTY_PALM_PATH)
	for effect in ability.effects:
		_target.receive_effect(effect, _source_attributes, 1.0)

	assert_lt(_target.vitals_manager.current_health, starting_health,
		"Target should take damage even when not casting")
```

- [ ] **Step 2: Run and iterate.**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_empty_palm_interrupt.gd -gexit
```
Expected: 2/2 pass.

If setup fails because `CombatantData` requires additional fields (e.g. `abilities: Array[AbilityData]`), inspect `scripts/resource_definitions/combatants/combatant_data.gd` and add the minimum stubs. Do not change production code to fit the test.

- [ ] **Step 3: Commit.**

```bash
git add tests/integration/test_empty_palm_interrupt.gd
git commit -m "test(combat): integration test for Empty Palm cancelling enemy cast"
```

---

### Task 10: Integration test — Power Font strips all enemy buffs

**Files:**
- Create: `tests/integration/test_power_font_buff_strip.gd`

- [ ] **Step 1: Write the integration test.**

Create `tests/integration/test_power_font_buff_strip.gd`:
```gdscript
extends GutTest

## Integration test: Power Font's STRIP_BUFFS effect removes every active buff
## on the target while still dealing damage.

const POWER_FONT_PATH := "res://resources/abilities/power_font.tres"

var _target: CombatantNode
var _source_attributes: CharacterAttributesData

func before_each() -> void:
	_target = CombatantNode.new()
	add_child_autofree(_target)

	var ability_manager := CombatAbilityManager.new()
	var buff_manager := CombatBuffManager.new()
	var effect_manager := CombatEffectManager.new()
	var vitals_manager := VitalsManager.new()
	_target.add_child(ability_manager)
	_target.add_child(buff_manager)
	_target.add_child(effect_manager)
	_target.add_child(vitals_manager)
	_target.ability_manager = ability_manager
	_target.buff_manager = buff_manager
	_target.effect_manager = effect_manager
	_target.vitals_manager = vitals_manager

	var combatant_data := CombatantData.new()
	combatant_data.character_name = "Dummy"
	combatant_data.attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0)
	_target.combatant_data = combatant_data
	vitals_manager.character_attributes_data = combatant_data.attributes
	vitals_manager.initialize_current_values()
	effect_manager.setup(_target)

	_source_attributes = CharacterAttributesData.new(10.0, 10.0, 10.0, 10.0, 20.0, 10.0, 10.0, 10.0)

	# Seed two buffs on the target
	var b1 := BuffEffectData.new()
	b1.buff_id = "power_buff"
	b1.effect_name = "Power Buff"
	b1.duration = 30.0
	b1.buff_type = BuffEffectData.BuffType.OUTGOING_DAMAGE_MODIFIER
	b1.damage_multiplier = 2.0
	buff_manager.apply_buff(b1)

	var b2 := BuffEffectData.new()
	b2.buff_id = "armor_buff"
	b2.effect_name = "Armor Buff"
	b2.duration = 30.0
	b2.buff_type = BuffEffectData.BuffType.ATTRIBUTE_MODIFIER_MULTIPLICATIVE
	b2.attribute_modifiers = {CharacterAttributesData.AttributeType.RESILIENCE: 2.0}
	buff_manager.apply_buff(b2)

	assert_eq(buff_manager.active_buffs.size(), 2, "setup: 2 buffs seeded")

func test_power_font_strips_all_buffs_and_deals_damage() -> void:
	var ability: AbilityData = load(POWER_FONT_PATH)
	assert_not_null(ability, "power_font.tres must load")

	var starting_health: float = _target.vitals_manager.current_health

	for effect in ability.effects:
		_target.receive_effect(effect, _source_attributes, 1.0)

	assert_eq(_target.buff_manager.active_buffs.size(), 0,
		"Power Font should strip all buffs from the target")
	assert_lt(_target.vitals_manager.current_health, starting_health,
		"Power Font should deal damage in addition to stripping buffs")

func test_power_font_on_unbuffed_target_only_damages() -> void:
	_target.buff_manager.strip_all_buffs()  # Clear the setup buffs
	assert_eq(_target.buff_manager.active_buffs.size(), 0)

	var starting_health: float = _target.vitals_manager.current_health
	var ability: AbilityData = load(POWER_FONT_PATH)
	for effect in ability.effects:
		_target.receive_effect(effect, _source_attributes, 1.0)

	assert_lt(_target.vitals_manager.current_health, starting_health,
		"Power Font should still deal damage when no buffs to strip")
```

- [ ] **Step 2: Run and iterate.**

Run:
```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_power_font_buff_strip.gd -gexit
```
Expected: 2/2 pass.

- [ ] **Step 3: Commit.**

```bash
git add tests/integration/test_power_font_buff_strip.gd
git commit -m "test(combat): integration test for Power Font buff-strip + damage"
```

---

### Task 11: Full-suite regression + in-game smoke

**Files:** (none modified)

- [ ] **Step 1: Run the full test suite.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
Expected: all tests pass. If any previously-passing test fails, investigate — a regression landed somewhere.

- [ ] **Step 2: Smoke-test in the running game.**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Verify interactively:
1. Equip Empty Palm and Power Font (both should show new description text).
2. Enter an adventure combat where the enemy casts (any cast-time ability).
3. Fire Empty Palm while the enemy is mid-cast → enemy cast bar vanishes, combat log shows "interrupted!".
4. Apply a buff to an enemy (via any mechanism that does so), then channel Power Font → buff icons disappear on hit.
5. Both abilities still deal damage.

If any step fails, debug in isolation — check signal connections, effect routing, or `.tres` effect arrays. Re-run the test suite after any fix to catch regressions.

- [ ] **Step 3: No commit unless fixes were made.**

This task produces a verification result, not code. If you made fixes during the smoke test, commit each as its own focused commit with a descriptive message.

---

## Self-Review Summary

Spec coverage pass — every spec requirement maps to a task:

| Spec requirement | Task |
|---|---|
| Empty Palm: Madra 8, CD 3s, cast 0s | Task 6 |
| Empty Palm: base 15 Spirit, spi 1.0 / agi 0.3 | Task 6 |
| Empty Palm: cancel target's cast on hit | Task 1, 2, 3, 5, 6, 9 |
| Power Font: Madra 30, CD 25s, cast 3s | Task 7 |
| Power Font: base 30 Spirit, spi 1.5 / fnd 0.5 | Task 7 |
| Power Font: strip all buffs on target | Task 1, 4, 5, 7, 10 |
| Cast cancellation infrastructure | Task 2, 3 |
| Mid-combat buff strip | Task 4 |
| CANCEL_CAST + STRIP_BUFFS effect types | Task 1, 5 |
| Enemy cast bar UI (Empty Palm clarity prereq) | Task 8 |
| Madra regen validation (open issue in spec) | Deferred to playtest — removed from plan per review |

Out-of-scope callouts from the spec (correctly omitted from plan):
- Path-tree upgrade nodes
- VFX/SFX asset creation (structure marked with `TODO` in Task 8)
- Stacking for non-DoT buffs (spec defers to separate enemy-design work)
- Enemy cast bar on player side — unchanged, only enemy panels need the bar

No placeholders, unused types, or unresolved TODOs in task code. Method names are consistent across tasks (`cancel_cast`, `cancel_current_cast`, `strip_all_buffs`).
